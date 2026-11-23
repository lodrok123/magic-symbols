extends SceneTree
## Prueba de recursos reales, restauración e integración de entrega única.
var fallos := 0

func ok(bien: bool, texto: String) -> void:
	print(("OK " if bien else "FALLO ") + texto)
	if not bien:
		fallos += 1

func _initialize() -> void:
	await process_frame
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.size = 7.0
	cam.h_offset = 0.3
	cam.v_offset = -0.2
	cam.position = Vector3(3, 3, 5)
	cam.look_at(Vector3(0, 1, 0))
	cam.current = true
	for calidad: String in ["comun", "epico", "legendario"]:
		var ruta: String = "res://arte/piezas/cofre%s.tscn" % ("" if calidad == "comun" else "_" + calidad)
		var cofre: Node3D = (load(ruta) as PackedScene).instantiate()
		root.add_child(cofre)
		var c := Cofre3D.en(cofre)
		ok(c != null and c.calidad == calidad, "control real " + calidad)
		ok(c.estrellas.estrellas.size() == int(CofreEstrellas3D.NUMERO[calidad]), "estrellas " + calidad)
		if calidad != "comun":
			var s := SecuenciaCofreLegendario3D.new()
			s.modo_prueba = true
			s.calidad = calidad
			root.add_child(s)
			var entregas := [0]
			s.recompensa_lista.connect(func() -> void: entregas[0] += 1)
			ok(s.iniciar(cofre, c, null, "raido" if calidad == "legendario" else ""), "inicia " + calidad)
			s.set_process(false)
			var inicio_orbita: Transform3D = s._pose_orbita(0.0)
			var fin_orbita: Transform3D = s._pose_orbita(1.0)
			var medio_orbita: Transform3D = s._pose_orbita(0.5)
			ok(inicio_orbita.is_equal_approx(s._cam_inicio), "orbita empieza sin salto " + calidad)
			ok(medio_orbita.origin.distance_to(inicio_orbita.origin.lerp(fin_orbita.origin, 0.5)) > 0.15, "recorrido curvo alrededor del personaje " + calidad)
			var v0: Vector3 = inicio_orbita.origin - s._orbita_centro
			var v1: Vector3 = fin_orbita.origin - s._orbita_centro
			var giro: float = absf(rad_to_deg(wrapf(atan2(v1.x, v1.z) - atan2(v0.x, v0.z), -PI, PI)))
			ok(giro > 30 and giro < 90, "cambia el angulo de vista alrededor del personaje " + calidad)
			for i in 80:
				s._process(0.1)
			ok(s.esperando_input and not s.hecha, "espera input sin cierre automatico " + calidad)
			var tiempo_fijo: float = s.t
			var plano: Transform3D = s._cam.global_transform
			var zoom_fijo: float = s._cam.size
			var camara_juego: Transform3D = cam.global_transform
			cam.position += Vector3(2, 1, 0)
			for i in 30:
				s._process(0.1)
			ok(s._cam.global_transform.is_equal_approx(plano) and is_equal_approx(s._cam.size, zoom_fijo) and is_equal_approx(s.t, tiempo_fijo), "plano inmovil aunque se mueva la camara de juego " + calidad)
			ok(plano.origin.distance_to(camara_juego.origin) > 0.1, "travelling desplaza la camara " + calidad)
			cam.global_transform = camara_juego
			var retenida := InputEventKey.new()
			retenida.keycode = KEY_E
			retenida.pressed = true
			retenida.echo = true
			s._input(retenida)
			ok(s.esperando_input, "tecla mantenida no cierra " + calidad)
			var pulsacion := InputEventKey.new()
			pulsacion.keycode = KEY_ENTER
			pulsacion.pressed = true
			if s._lamina != null:
				# 23/11: con la ficha de la runa a medias escribirse, la 1.ª pulsación la completa de golpe y NO continúa.
				ok(not s._lamina.texto_completo(), "la ficha de la runa se esta escribiendo " + calidad)
				s._input(pulsacion)
				ok(s._lamina.texto_completo() and s.esperando_input, "la 1a pulsacion completa el texto de la ficha sin continuar " + calidad)
			s._input(pulsacion)
			ok(not s.esperando_input, "pulsacion nueva continua " + calidad)
			for i in 16:
				s._process(0.1)
			if calidad == "legendario":
				ok(s._libro != null and s._libro.inscripcion != null, "runa llega a pagina 3D tras confirmar")
			for i in 20:
				s._process(0.1)
			ok(s.escrito and entregas[0] == 1, "entrega una vez " + calidad)
			s.saltar()
			s.saltar()
			ok(entregas[0] == 1 and s.hecha and c.esta_abierto(), "salto idempotente " + calidad)
			ok(is_equal_approx(cam.size, 7.0) and is_equal_approx(cam.h_offset, 0.3) and is_equal_approx(cam.v_offset, -0.2), "restaura camara " + calidad)
			ok(not c.gesto_externo, "libera gesto " + calidad)
			s.free()
		cofre.free()
	# Interrupción antes de que la tapa termine: conserva el cierre de progreso.
	var pieza := (load("res://arte/piezas/cofre_legendario.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(pieza)
	var seq := SecuenciaCofreLegendario3D.new()
	seq.modo_prueba = true
	root.add_child(seq)
	var veces := [0]
	seq.recompensa_lista.connect(func() -> void: veces[0] += 1)
	seq.iniciar(pieza, Cofre3D.en(pieza), null, "raido")
	seq.cancelar()
	seq.cancelar()
	ok(veces[0] == 1 and seq.hecha, "cancelacion no duplica recompensa")
	seq.free()
	pieza.free()
	for nivel in [1, 2, 3]:
		var libro := LibroCeremonia3D.new()
		root.add_child(libro)
		libro.preparar(nivel)
		libro.poner_apertura(1.0)
		ok(libro.pagina != null and is_equal_approx(libro.apertura, 1.0), "libro articulado nivel %d" % nivel)
		libro.free()
	# Libro del personaje: entrada desde cinto y desde mano, sin perder su estado.
	var pj := Pj3D.new()
	root.add_child(pj)
	pj.cargar("jugadora_base")
	pj.set_alto(1.0)
	pj.position = Vector3(0, 0, 1.0)
	var cofre_repetido := (load("res://arte/piezas/cofre_legendario.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(cofre_repetido)
	var control_repetido := Cofre3D.en(cofre_repetido)
	for repeticion in 2:
		control_repetido.cerrar()
		pj.mirar(Vector3.RIGHT, 1.0)
		var ceremonia := SecuenciaCofreLegendario3D.new()
		ceremonia.modo_prueba = true
		ceremonia.pj_explicito = pj
		root.add_child(ceremonia)
		ceremonia.iniciar(cofre_repetido, control_repetido, null, "raido")
		ceremonia.set_process(false)
		var hacia_cofre: Vector3 = (cofre_repetido.global_position - pj.global_position).normalized()
		ok(pj.global_basis.z.normalized().dot(hacia_cofre) > 0.999, "mira al cofre al iniciar apertura %d" % repeticion)
		for i in 70:
			ceremonia._process(0.1)
		ok(ceremonia.esperando_input and pj.global_basis.z.normalized().dot(hacia_cofre) > 0.999, "mantiene orientacion al cofre durante orbita y presentacion %d" % repeticion)
		ceremonia.cancelar()
		ceremonia.free()
	cofre_repetido.free()
	for en_mano: bool in [false, true]:
		pj.libro_en_manos(en_mano, 0.0)
		pj.libro_asentar()
		var previo: String = pj.libro_estado()
		ok(pj.iniciar_ceremonia_libro(), "cesion del libro " + previo)
		ok(not pj.iniciar_ceremonia_libro(), "rechaza segunda cesion")
		if pj._libro != null:
			ok(not pj._libro.visible, "libro de mano oculto durante ceremonia")
		pj.terminar_ceremonia_libro()
		ok(pj.libro_estado() == previo and pj.libro_valido(), "restaura estado del libro " + previo)
		if pj._libro != null:
			ok(pj._libro.visible, "restaura visibilidad de mano")
	pj.libro_en_manos(false, 0)
	pj.libro_asentar()
	pj.free()
	# Integración con CofrePuzle: el evento visual no concede botín dos veces.
	Estado.nuevo()
	Flags.nuevo()
	var mundo := Node3D.new()
	root.add_child(mundo)
	var tesoro := Puzle3D.CofrePuzle.new()
	mundo.add_child(tesoro)
	tesoro.modelo = (load("res://arte/piezas/cofre_epico.tscn") as PackedScene).instantiate()
	tesoro.add_child(tesoro.modelo)
	tesoro.ctrl = Cofre3D.en(tesoro.modelo)
	tesoro.calidad = "epico"
	tesoro.es_cerrado = true
	tesoro.flag_abierto = "prueba.cofre.integrado"
	tesoro.da = [{"que": "oro", "n": 3}]
	ok(tesoro.abrir() and not tesoro.abrir(), "interaccion real rechaza doble apertura")
	tesoro.secuencia.saltable = true
	tesoro.secuencia.saltar()
	ok(Estado.i().oro == 3 and Flags.i().tiene(tesoro.flag_abierto) and tesoro.es_abierto, "botin y flag reales concordantes al saltar")
	ok(not tesoro.abrir() and Estado.i().oro == 3, "cofre consumido no repite botin")
	mundo.free()
	await process_frame
	print("FALLOS: %d" % fallos)
	quit(1 if fallos > 0 else 0)
