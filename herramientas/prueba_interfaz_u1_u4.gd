extends "res://herramientas/escenario_base.gd"
## GAMEFEEL, TAREA U (31/10; U1 grimorio · U2 muerte y reaparición · U3 misiones · U4 tienda y oro): la interfaz que faltaba se oye y se ve. Nada cambia reglas.
##   U1  spellbook.gd: abrir/cerrar con tween (escala 0,96 → 1 y fundido, 0,15 s); grimorio.gd: `sello_no` en los dos rechazos mudos, `pagina` (−14 dB) al deshacer, `barrido` al vaciar.
##   U2  jugador_3d.gd: el golpe que mata también llama a `Sensacion3D.dano_recibido`; pantalla_muerte.gd suena `muerte` (−8); `reaparecer` suena y abre una viñeta clara 0,6 s.
##   U3  mision_hud.gd + misiones.gd: `logro_pista` al activar, `objetivo_cumplido` al avanzar y `mision_completada` al completar; la línea entra deslizándose y destella.
##   U4  bosque_3d.gd: `comprar` / `no_puedes` en la tienda; `moneda` con el oro de cofres (puzle.gd, bosque_01_3d.gd) y de misiones.
## Los sonidos se miran con `Sfx.REGISTRAR` / `ULTIMOS` (headless no se oye nada); entre dos sonidos iguales se espera más que la veda de 70 ms.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_interfaz_u1_u4.gd


func _pausa() -> void:
	OS.delay_msec(Sfx.VEDA_MS + 40)                    # la veda cuenta con el reloj de pared
	await avanzar(1)


func _ultimo(nombre: String) -> Dictionary:
	for i in range(Sfx.ULTIMOS.size() - 1, -1, -1):
		if String(Sfx.ULTIMOS[i]["nombre"]) == nombre:
			return Sfx.ULTIMOS[i]
	return {}


func _db(nombre: String) -> float:
	return float(_ultimo(nombre).get("db", 99.0))


func _escenario() -> void:
	Sfx.REGISTRAR = true
	Sfx.AJUSTES.clear()
	Sfx.vaciar_registro()
	Sensacion3D.ACTIVA = true

	# --- El catálogo ---
	_ok("0 «muerte» baja a −8 dB", is_equal_approx(float(Sfx.CATALOGO["muerte"]["db"]), -8.0))
	_ok("0 «barrido» y «reaparecer» (−14 dB) están en el catálogo", Sfx.CATALOGO.has("barrido") and Sfx.CATALOGO.has("reaparecer") and is_equal_approx(float(Sfx.CATALOGO["reaparecer"]["db"]), -14.0))
	_ok("0 y sus .wav existen", ResourceLoader.exists(Sfx.CARPETA + "barrido.wav") and ResourceLoader.exists(Sfx.CARPETA + "reaparecer.wav"))

	await _u1_libro()
	await _u3_misiones()
	await _u4_tienda_y_oro()
	await _u1_u2_con_escena()
	Sensacion3D.ACTIVA = true
	Repertoire.reset_to_p0()
	Sfx.AJUSTES.clear()
	Sfx.REGISTRAR = false


# ---------------------------------------------------------------------------------------------------------------------
#  U1 · el libro abre y cierra con tween
# ---------------------------------------------------------------------------------------------------------------------

func _u1_libro() -> void:
	Repertoire.libro = "bosque"
	var libro: Control = load("res://presentacion/ui/spellbook.gd").new()
	libro.size = Vector2(1280.0, 720.0)
	libro.process_mode = Node.PROCESS_MODE_ALWAYS             # como en la escena
	root.add_child(libro)
	await avanzar(2)
	_ok("1 cerrado: invisible", not libro.visible and not libro.is_open)

	libro.call("_open")
	_ok("1 abrir: visible y abierto", libro.visible and libro.is_open)
	var tw: Variant = libro.get("_tw_libro")
	_ok("1 abrir: hay un tween vivo", tw is Tween and (tw as Tween).is_valid() and (tw as Tween).is_running())
	_ok("1 abrir: parte de escala 0,96 y transparente", is_equal_approx(libro.scale.x, libro.ESCALA_LIBRO_CERRADO) and is_equal_approx(libro.modulate.a, 0.0), "%s a=%s" % [libro.scale, libro.modulate.a])
	await avanzar(2)
	_ok("1 abrir: a media animación ya ha crecido y se ve algo", libro.scale.x > libro.ESCALA_LIBRO_CERRADO and libro.modulate.a > 0.0, "%s a=%.2f" % [libro.scale, libro.modulate.a])
	await avanzar(int(ceil(libro.T_LIBRO_S * 30.0)) + 4)
	_ok("1 abrir: acaba en escala 1 y opaco", is_equal_approx(libro.scale.x, 1.0) and is_equal_approx(libro.modulate.a, 1.0), "%s a=%.2f" % [libro.scale, libro.modulate.a])
	_ok("1 y el tween ya no corre", not ((libro.get("_tw_libro") as Tween).is_running() if libro.get("_tw_libro") != null else false))

	libro.call("_close")
	_ok("1 cerrar: is_open false pero sigue visible mientras se funde", not libro.is_open and libro.visible)
	tw = libro.get("_tw_libro")
	_ok("1 cerrar: hay un tween vivo", tw is Tween and (tw as Tween).is_valid() and (tw as Tween).is_running())
	await avanzar(int(ceil(libro.T_LIBRO_S * 30.0)) + 4)
	_ok("1 cerrar: al acabar queda invisible y listo para la próxima (escala 1, opaco)", not libro.visible and is_equal_approx(libro.scale.x, 1.0) and is_equal_approx(libro.modulate.a, 1.0), "%s a=%.2f" % [libro.scale, libro.modulate.a])
	get_root().get_tree().paused = false

	# Reabrir a mitad de un cierre no deja el libro oculto por el callback viejo.
	libro.call("_open")
	await avanzar(int(ceil(libro.T_LIBRO_S * 30.0)) + 3)
	libro.call("_close")
	await avanzar(1)
	libro.call("_open")
	await avanzar(int(ceil(libro.T_LIBRO_S * 30.0)) + 4)
	_ok("1 abrir en pleno cierre: el libro queda visible y opaco", libro.visible and libro.is_open and is_equal_approx(libro.modulate.a, 1.0), "visible=%s a=%.2f" % [libro.visible, libro.modulate.a])
	libro.call("_close")
	await avanzar(int(ceil(libro.T_LIBRO_S * 30.0)) + 4)
	get_root().get_tree().paused = false

	# Sensacion3D.ACTIVA = false: de golpe, sin tween (el sonido de abrir/cerrar no depende de esto).
	Sensacion3D.ACTIVA = false
	libro.call("_open")
	_ok("1 ACTIVA=false: abre de golpe, sin tween, escala 1 y opaco", libro.visible and libro.get("_tw_libro") == null and is_equal_approx(libro.scale.x, 1.0) and is_equal_approx(libro.modulate.a, 1.0))
	libro.call("_close")
	_ok("1 ACTIVA=false: cierra de golpe, sin tween", not libro.visible and not libro.is_open and libro.get("_tw_libro") == null)
	get_root().get_tree().paused = false
	Sensacion3D.ACTIVA = true
	libro.queue_free()
	await avanzar(2)


# ---------------------------------------------------------------------------------------------------------------------
#  U3 · misiones
# ---------------------------------------------------------------------------------------------------------------------

func _u3_misiones() -> void:
	Misiones.nuevo()
	Estado.nuevo()
	var hud := MisionHud.new()
	root.add_child(hud)
	await avanzar(2)
	var m: Misiones = Misiones.i()
	m.definir({"id": "u3", "titulo": "Prueba U3", "tipo": "principal", "objetivos": ["Uno", "Dos"], "recompensa": {"oro": 12}})
	Sfx.vaciar_registro()
	var oro0: int = Estado.i().oro

	await _pausa()
	m.activar("u3")
	_ok("3 activar: suena logro_pista", Sfx.veces("logro_pista") == 1, str(Sfx.CONTEO))
	_ok("3 activar: la línea se ve con su texto", hud.visible and hud.text.contains("Prueba U3"), hud.text)
	var tw: Variant = hud.get("_tw")
	_ok("3 activar: tween vivo de la línea", tw is Tween and (tw as Tween).is_valid() and (tw as Tween).is_running())
	_ok("3 activar: la línea parte desplazada a la izquierda y destellando (>1)", hud.position.x < MisionHud.POS.x - 1.0 and hud.modulate.r > 1.2, "%s %s" % [hud.position, hud.modulate])
	await avanzar(int(ceil(MisionHud.T_DESTELLO_S * 30.0)) + 4)
	_ok("3 activar: llega a su sitio y recupera su color", hud.position.is_equal_approx(MisionHud.POS) and hud.modulate.is_equal_approx(Color.WHITE), "%s %s" % [hud.position, hud.modulate])
	_ok("3 activar: no suena el acierto ni la moneda", Sfx.veces("mision_completada") == 0 and Sfx.veces("moneda") == 0)

	await _pausa()
	m.objetivo_hecho("u3", 0)
	_ok("3 objetivo: suena objetivo_cumplido", Sfx.veces("objetivo_cumplido") == 1, str(Sfx.CONTEO))
	tw = hud.get("_tw")
	_ok("3 objetivo: la línea vuelve a entrar con tween", tw is Tween and (tw as Tween).is_running())
	_ok("3 objetivo: aún no suena el acierto", Sfx.veces("mision_completada") == 0)
	await avanzar(int(ceil(MisionHud.T_DESTELLO_S * 30.0)) + 4)

	await _pausa()
	m.objetivo_hecho("u3", 1)
	_ok("3 completar: suena mision_completada", Sfx.veces("mision_completada") == 1, str(Sfx.CONTEO))
	_ok("3 completar: el último objetivo solo reproduce el cierre", Sfx.veces("objetivo_cumplido") == 1 and Sfx.veces("logro_pista") == 1, str(Sfx.CONTEO))
	_ok("3 completar: la recompensa en oro suena moneda y se paga igual", Sfx.veces("moneda") == 1 and Estado.i().oro == oro0 + 12, "oro %d -> %d" % [oro0, Estado.i().oro])
	tw = hud.get("_tw")
	_ok("3 completar: tween vivo", tw is Tween and (tw as Tween).is_valid())
	await avanzar(int(ceil(MisionHud.T_DESTELLO_S * 30.0)) + 4)

	# Completar a mano una misión sin objetivos.
	m.definir({"id": "u3b", "titulo": "Sin objetivos", "estado": "activa"})
	await _pausa()
	m.completar("u3b")
	_ok("3 completar a mano: mision_completada de nuevo", Sfx.veces("mision_completada") == 2, str(Sfx.CONTEO))

	# ACTIVA = false: sonidos sí, tweens no.
	Sensacion3D.ACTIVA = false
	m.definir({"id": "u3c", "titulo": "Sin sensación", "objetivos": ["A", "B"]})
	Sfx.vaciar_registro()
	await _pausa()
	m.activar("u3c")
	hud.position = MisionHud.POS
	_ok("3 ACTIVA=false: activar suena logro_pista", Sfx.veces("logro_pista") == 1)
	_ok("3 ACTIVA=false: sin tween ni deslizamiento ni destello", hud.get("_tw") == null and hud.position.is_equal_approx(MisionHud.POS) and hud.modulate.is_equal_approx(Color.WHITE), "%s %s" % [hud.position, hud.modulate])
	await _pausa()
	m.objetivo_hecho("u3c", 0)
	_ok("3 ACTIVA=false: el objetivo suena objetivo_cumplido", Sfx.veces("objetivo_cumplido") == 1)
	await _pausa()
	m.objetivo_hecho("u3c", 1)
	_ok("3 ACTIVA=false: completar suena mision_completada", Sfx.veces("mision_completada") == 1)
	_ok("3 ACTIVA=false: sigue sin tween", hud.get("_tw") == null)
	Sensacion3D.ACTIVA = true
	hud.queue_free()
	Misiones.nuevo()
	await avanzar(2)


# ---------------------------------------------------------------------------------------------------------------------
#  U4 · tienda y oro
# ---------------------------------------------------------------------------------------------------------------------

func _u4_tienda_y_oro() -> void:
	Repertoire.set_active(Repertoire.P0_ELEMENTS, PackedStringArray(["flecha"]))     # sin «barrera»: la tienda la vende
	var b := Bosque3D.new()
	Estado.nuevo()
	var e: Estado = Estado.i()
	Sfx.vaciar_registro()

	e.oro = Bosque3D.PRECIO_BARRERA - 7
	await _pausa()
	b._comprar_barrera()
	_ok("4 sin oro: suena no_puedes (−14 dB)", Sfx.veces("no_puedes") == 1 and is_equal_approx(_db("no_puedes"), Bosque3D.DB_NO_PUEDES), str(Sfx.CONTEO))
	_ok("4 sin oro: no suena comprar y el oro queda intacto", Sfx.veces("comprar") == 0 and e.oro == Bosque3D.PRECIO_BARRERA - 7, str(e.oro))
	_ok("4 sin oro: la barrera no se compra", not b._barrera_comprada and not Repertoire.sigil_active("barrera"))

	e.oro = Bosque3D.PRECIO_BARRERA + 50
	await _pausa()
	b._comprar_barrera()
	_ok("4 con oro: suena comprar", Sfx.veces("comprar") == 1 and is_equal_approx(_db("comprar"), float(Sfx.CATALOGO["comprar"]["db"])), str(Sfx.CONTEO))
	_ok("4 con oro: el oro baja exactamente el precio", e.oro == 50, str(e.oro))
	_ok("4 con oro: la barrera es tuya", b._barrera_comprada and Repertoire.sigil_active("barrera"))
	_ok("4 con oro: no suena no_puedes de más", Sfx.veces("no_puedes") == 1)

	await _pausa()
	b._comprar_barrera()
	_ok("4 ya comprada: suena no_puedes y el oro no cambia", Sfx.veces("no_puedes") == 2 and e.oro == 50 and Sfx.veces("comprar") == 1, "%s oro %d" % [str(Sfx.CONTEO), e.oro])
	b.free()

	# Oro de un cofre del Puzle3D (da=oro).
	e.oro = 5
	Sfx.vaciar_registro()
	var cofre := Puzle3D.CofrePuzle.new()
	cofre.da = [{"que": "oro", "n": 25}]
	await _pausa()
	var dado: Array = cofre.dar_botin()
	_ok("4 cofre de puzle: suena moneda y da el mismo oro", Sfx.veces("moneda") == 1 and e.oro == 30 and dado.size() == 1, "%s oro %d" % [str(Sfx.CONTEO), e.oro])
	cofre.free()

	# Oro de un cofre de las ramas del Bosque 01.
	e.oro = 0
	Sfx.vaciar_registro()
	var b01: Node = load("res://escenas/bosque_01_3d.gd").new()
	await _pausa()
	b01.call("_dar_botin", 2)                                # cofre_03: 40 de oro y una poción
	_ok("4 cofre del Bosque 01: suena moneda y da el mismo oro", Sfx.veces("moneda") == 1 and e.oro == 40, "%s oro %d" % [str(Sfx.CONTEO), e.oro])
	b01.free()

	# La recompensa de una misión ya se midió en la sección 3 (moneda + 12 de oro). Aquí, sin oro en la recompensa no suena.
	var mm: Misiones = Misiones.nuevo()
	mm.definir({"id": "u4", "titulo": "Sin oro", "estado": "activa", "recompensa": {"items": {}}})
	Sfx.vaciar_registro()
	mm.completar("u4")
	_ok("4 misión sin oro: no suena moneda", Sfx.veces("moneda") == 0)

	# Con ACTIVA = false los sonidos de tienda y oro suenan igual.
	Sensacion3D.ACTIVA = false
	Repertoire.set_active(Repertoire.P0_ELEMENTS, PackedStringArray(["flecha"]))
	var b2 := Bosque3D.new()
	e.oro = 100
	Sfx.vaciar_registro()
	await _pausa()
	b2._comprar_barrera()
	_ok("4 ACTIVA=false: comprar suena y el oro baja lo mismo", Sfx.veces("comprar") == 1 and e.oro == 100 - Bosque3D.PRECIO_BARRERA, "oro %d" % e.oro)
	await _pausa()
	b2._comprar_barrera()
	_ok("4 ACTIVA=false: no_puedes suena", Sfx.veces("no_puedes") == 1)
	b2.free()
	Sensacion3D.ACTIVA = true
	Repertoire.reset_to_p0()
	Misiones.nuevo()


# ---------------------------------------------------------------------------------------------------------------------
#  U1 (grimorio) y U2 (muerte y reaparición) con la escena de verdad
# ---------------------------------------------------------------------------------------------------------------------

func _u1_u2_con_escena() -> void:
	Estado.nuevo()
	Repertoire.activate_all()
	Repertoire.aim_with_mouse = false
	await cargar()
	_ok("2 hay lanzador y jugador", lanzador != null and jugador != null)
	if lanzador == null or jugador == null:
		return
	Sfx.REGISTRAR = true
	Sfx.AJUSTES.clear()
	Repertoire.activate_all()                                  # el nivel fija su repertorio y el modo de apuntar al cargar: se vuelve a lo que esta prueba necesita
	Repertoire.aim_with_mouse = false                          # sin ratón el sector manda y «flecha» solo vale en plano
	lanzador.clear_sequence()

	# ---- U1 · los dos rechazos mudos ----
	Sfx.vaciar_registro()
	await _pausa()
	lanzador.add_gesture([PackedVector2Array([Vector2(0, 0), Vector2(5, 0)])], Vector2(1, 0))
	_ok("1 trazo demasiado corto: suena sello_no", Sfx.veces("sello_no") == 1, str(Sfx.CONTEO))
	Sfx.vaciar_registro()
	await _pausa()
	lanzador.clear_sequence()
	lanzador.add_sigil(Vector2(0, 1), "flecha")                 # «flecha» solo vale en plano; hacia abajo (y = 1) no
	_ok("1 sello que no vale hacia ahí: suena sello_no", Sfx.veces("sello_no") == 1, str(Sfx.CONTEO))
	_ok("1 y no se añadió el sello", lanzador.sigils_used() == 0)
	Sfx.vaciar_registro()
	await _pausa()
	lanzador.add_sigil(Vector2(1, 0), "flecha")                 # hacia un lado sí: sin rechazo
	_ok("1 un sello que vale: no suena sello_no", Sfx.veces("sello_no") == 0 and lanzador.sigils_used() == 1, str(Sfx.CONTEO))

	# ---- U1 · deshacer y vaciar ----
	lanzador.clear_sequence()
	lanzador.place_element("fuego")
	Sfx.vaciar_registro()
	await _pausa()
	lanzador.undo_last()
	_ok("1 deshacer: suena pagina a −14 dB", Sfx.veces("pagina") == 1 and is_equal_approx(_db("pagina"), Grimorio.DB_DESHACER) and is_equal_approx(Grimorio.DB_DESHACER, -14.0), str(Sfx.ULTIMOS))
	await _pausa()
	lanzador.undo_last()
	_ok("1 deshacer sin nada que deshacer: no suena", Sfx.veces("pagina") == 1)
	lanzador.place_element("agua")
	lanzador.add_sigil(Vector2(1, 0), "flecha")
	Sfx.vaciar_registro()
	await _pausa()
	lanzador.clear_sequence()
	_ok("1 vaciar: suena el barrido", Sfx.veces("barrido") == 1 and is_equal_approx(_db("barrido"), Grimorio.DB_VACIAR), str(Sfx.CONTEO))
	_ok("1 y la página queda vacía", lanzador.sigils_used() == 0 and lanzador.current_element_data() == null)
	await _pausa()
	lanzador.clear_sequence()
	_ok("1 vaciar lo ya vacío: no suena", Sfx.veces("barrido") == 1)

	# ---- U2 · morir ----
	var pm: PantallaMuerte = jugador.pantalla_muerte
	_ok("2 el jugador tiene pantalla de muerte", pm != null)
	if pm == null:
		return
	await avanzar_s(0.5)
	jugador.set("_t_inv", 0.0)
	Sfx.vaciar_registro()
	await _pausa()
	var dano0: int = int(Sensacion3D.cuenta["dano"])
	var rea0: int = int(Sensacion3D.cuenta["reaparece"])
	jugador.recibir_dano(100000)
	_ok("2 el golpe letal mata", bool(jugador.muerto))
	_ok("2 la rama letal llamó a Sensacion3D.dano_recibido (+1 en la cuenta)", int(Sensacion3D.cuenta["dano"]) == dano0 + 1, "%d -> %d" % [dano0, int(Sensacion3D.cuenta["dano"])])
	var capa_d: CanvasLayer = jugador.get_meta("vineta_dano") if jugador.has_meta("vineta_dano") else null
	_ok("2 existe la viñeta roja de la jugadora", capa_d != null and is_instance_valid(capa_d))
	if capa_d != null:
		var mat_d: ShaderMaterial = (capa_d.get_node("R") as ColorRect).material as ShaderMaterial
		_ok("2 la viñeta roja está encendida y NO la esconde la pantalla de muerte", capa_d.visible and float(mat_d.get_shader_parameter("fuerza")) > 0.2, "visible=%s fuerza=%s" % [capa_d.visible, mat_d.get_shader_parameter("fuerza")])
	_ok("2 la pantalla de muerte sale (fundido)", pm.activa and pm.fase == "fundido", pm.fase)
	_ok("2 suena «muerte» a −8 dB, una vez", Sfx.veces("muerte") == 1 and is_equal_approx(_db("muerte"), -8.0), str(Sfx.ULTIMOS))
	_ok("2 el golpe de la jugadora suena (dano_jugadora)", Sfx.veces("dano_jugadora") == 1, str(Sfx.CONTEO))
	_ok("2 aún no ha reaparecido: ni sonido ni viñeta clara", Sfx.veces("reaparecer") == 0 and int(Sensacion3D.cuenta["reaparece"]) == rea0)

	# ---- U2 · reaparecer ----
	var t0: float = reloj.t
	while bool(jugador.muerto) and reloj.t - t0 < 8.0:
		await process_frame
	_ok("2 reaparece", not bool(jugador.muerto), "tras %.1f s" % (reloj.t - t0))
	_ok("2 suena «reaparecer» (−14 dB), una vez", Sfx.veces("reaparecer") == 1 and is_equal_approx(_db("reaparecer"), -14.0), str(Sfx.CONTEO))
	_ok("2 la cuenta de viñetas claras sube 1", int(Sensacion3D.cuenta["reaparece"]) == rea0 + 1)
	var capa_c: CanvasLayer = jugador.get_meta("vineta_reaparece") if jugador.has_meta("vineta_reaparece") else null
	_ok("2 existe la viñeta clara", capa_c != null and is_instance_valid(capa_c))
	if capa_c != null:
		var mat_c: ShaderMaterial = (capa_c.get_node("R") as ColorRect).material as ShaderMaterial
		var tw_c: Variant = capa_c.get_meta("tw")
		_ok("2 la viñeta clara está activa, con tween vivo y abriéndose (apertura < 1)", capa_c.visible and tw_c is Tween and (tw_c as Tween).is_valid() and float(mat_c.get_shader_parameter("apertura")) < 1.0, "visible=%s apertura=%s" % [capa_c.visible, mat_c.get_shader_parameter("apertura")])
		var c: Color = mat_c.get_shader_parameter("color")
		_ok("2 y es CLARA (la roja de daño es oscura)", c.r > 0.8 and c.g > 0.8 and c.b > 0.8, str(c))
		await avanzar_s(Sensacion3D.T_VINETA_REAPARECER + 0.2)
		_ok("2 a los 0,6 s la viñeta clara se apaga", not capa_c.visible, "visible=%s apertura=%s" % [capa_c.visible, mat_c.get_shader_parameter("apertura")])
		_ok("2 y el 0,6 s es el de Sensacion3D.T_VINETA_REAPARECER", is_equal_approx(Sensacion3D.T_VINETA_REAPARECER, 0.6))
	await avanzar_s(1.0)
	_ok("2 la pantalla de muerte ya se apagó", not pm.activa)

	# ---- U2 · con Sensacion3D.ACTIVA = false: sonidos sí, viñetas no ----
	Sensacion3D.ACTIVA = false
	jugador.set("_t_inv", 0.0)
	Sfx.vaciar_registro()
	await _pausa()
	dano0 = int(Sensacion3D.cuenta["dano"])
	rea0 = int(Sensacion3D.cuenta["reaparece"])
	jugador.recibir_dano(100000)
	_ok("2 ACTIVA=false: muere y suena «muerte»", bool(jugador.muerto) and Sfx.veces("muerte") == 1, str(Sfx.CONTEO))
	_ok("2 ACTIVA=false: sin viñeta de daño nueva", int(Sensacion3D.cuenta["dano"]) == dano0)
	t0 = reloj.t
	while bool(jugador.muerto) and reloj.t - t0 < 8.0:
		await process_frame
	_ok("2 ACTIVA=false: reaparece y suena «reaparecer»", not bool(jugador.muerto) and Sfx.veces("reaparecer") == 1, str(Sfx.CONTEO))
	_ok("2 ACTIVA=false: sin viñeta clara nueva", int(Sensacion3D.cuenta["reaparece"]) == rea0)
	Sensacion3D.ACTIVA = true
