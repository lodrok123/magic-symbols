extends "res://herramientas/escenario_base.gd"
## Integración focalizada con un cofre legendario de un nivel real.
func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar("res://escenas/PruebaCueva.tscn", true)
	if maqueta == null or jugador == null:
		_ok("carga cueva", false)
		return
	var puzles := maqueta.get_node("Puzles") as Puzle3D
	var tesoro := puzles.nodo("tesoro") as Puzle3D.CofrePuzle
	var receptor := puzles.nodo("ante_cofre") as ReceptorPulso3D
	receptor.activar()
	colocar_jugador(Vector2i(13, 14))
	await avanzar_s(0.2)
	var tam: float = float(maqueta.get("_tam_camara"))
	var estado_libro: String = jugador.pj.libro_estado()
	_ok("arranca ceremonia real", tesoro.abrir())
	var seq: CeremoniaCofre3D = tesoro.secuencia
	var inicio: float = reloj.t
	var espera_desde: float = -1.0
	var plano_fijo := Transform3D.IDENTITY
	var verifico_espera := false
	var hubo_pagina := false
	var hubo_vuelo := false
	var mira_al_cofre := true
	var pagina_legible := false
	var libro_sobre_personaje := false
	while not seq.hecha and reloj.t - inicio < 8:
		await process_frame
		if seq.esperando_input:
			if espera_desde < 0:
				espera_desde = reloj.t
				plano_fijo = seq._cam.global_transform
			elif reloj.t - espera_desde > 0.75:
				_ok("espera con camara inmovil y control bloqueado", seq._cam.global_transform.is_equal_approx(plano_fijo) and jugador.bloqueado and not seq.hecha)
				verifico_espera = true
				var aceptar := InputEventKey.new()
				aceptar.keycode = KEY_E
				aceptar.pressed = true
				Input.parse_input_event(aceptar)
				await process_frame
				aceptar = InputEventKey.new()
				aceptar.keycode = KEY_E
				Input.parse_input_event(aceptar)
				_ok("input real continua", not seq.esperando_input)
		hubo_pagina = hubo_pagina or (seq._libro != null and seq._libro.inscripcion != null)
		hubo_vuelo = hubo_vuelo or seq.fase == "vuelo"
		var hacia_cofre: Vector3 = tesoro.global_position - jugador.pj.global_position
		hacia_cofre.y = 0
		mira_al_cofre = mira_al_cofre and jugador.pj.global_basis.z.normalized().dot(hacia_cofre.normalized()) > 0.99
		if seq._libro != null and seq._libro.apertura > 0.95 and seq._cam != null:
			var normal: Vector3 = seq._libro.pagina.global_basis.y.normalized()
			pagina_legible = pagina_legible or normal.dot(seq._cam.global_basis.z.normalized()) > 0.4
			libro_sobre_personaje = libro_sobre_personaje or (seq._libro.global_position - jugador.global_position - Vector3.UP).dot(seq._cam.global_basis.y) > 0.2
	_ok("personaje mira al cofre durante toda la ceremonia", mira_al_cofre)
	_ok("presentacion espera confirmacion explicita", verifico_espera)
	_ok("libro tridimensional y vuelo presentes", hubo_pagina and hubo_vuelo)
	_ok("pagina orientada hacia la camara del nivel", pagina_legible)
	_ok("libro encuadrado sobre la posicion final del personaje", libro_sobre_personaje)
	_ok("termina tras confirmar", seq.hecha and reloj.t - inicio < 8)
	_ok("cofre y runa concordantes", tesoro.es_abierto and Repertoire.sigil_active(tesoro.glifo) and Flags.i().tiene(tesoro.flag_abierto))
	_ok("restaura libro de equipo", jugador.pj.libro_valido() and jugador.pj.libro_estado() == estado_libro)
	_ok("restaura camara y control", absf(float(maqueta.get("_tam_camara")) - tam) < 0.01 and not jugador.bloqueado and not jugador.animacion_externa)
	_ok("no repite apertura", not tesoro.abrir())
