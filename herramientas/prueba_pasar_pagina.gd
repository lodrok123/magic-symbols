extends SceneTree
## TAREA L (2/11, docs/REVISION_GAMEFEEL_30-10.md §10): LA MANO PASA LA PÁGINA. Va sobre el libro real (`spellbook.gd`) y el lanzador real (`Lanzador3D`), con la entrada real (`_input`).
##   1  la página NO cambia al pulsar: cambia con la hoja plegada (CAMBIA_AL_CERRAR) y no antes; `paginas_bucle` suena al empezar, `pagina` al terminar
##   2  la mano pasa por LEVANTADA y PINZA, y acaba sin pose forzada y, quieta, en REPOSO
##   3  la hoja llega a scale.x ≈ HOJA_MIN y vuelve a 1; la mano no se aplasta con ella; todo en <= T_PASAR_MAX
##   4  un trazo iniciado durante la animación se encola y se aplica al terminar
##   5  dos pulsaciones seguidas encadenan dos cambios (sin solaparse)
##   6  CAMBIA_AL_CERRAR = false: la página cambia al final
##   7  Sensacion3D.ACTIVA = false y PASAR_PAGINA_ANIMADO = false: instantáneo, con `pagina`
##   8  cerrar el libro a media animación deja elegida la página pedida
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_pasar_pagina.gd

var _fallos: int = 0
var _comprobaciones: int = 0
var libro: Control
var lanz: Lanzador3D


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _tecla(n: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_1 + n
	ev.physical_keycode = KEY_1 + n
	ev.pressed = true
	libro.call("_input", ev)


func _boton(pos: Vector2, pulsado: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pulsado
	ev.position = pos
	libro.call("_input", ev)


func _mover(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	libro.call("_input", ev)


## Un fotograma; la veda del sonido (reloj de pared) no es lo que se prueba.
func _fotograma() -> void:
	Sfx._ultima.clear()
	await process_frame


func _fotogramas(n: int) -> void:
	for _i in range(n):
		await _fotograma()


func _initialize() -> void:
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, false)      # esta prueba mide el dibujo de VfxElemento3D / ConjuroVfx3D; con el toy de serie (fuego y agua) se callan y lo cubre prueba_vfx_en_juego
	await process_frame
	Sfx.REGISTRAR = true
	Sensacion3D.ACTIVA = true
	Repertoire.reset_to_p0()
	Repertoire.libro = "bosque"
	lanz = Lanzador3D.new()
	root.add_child(lanz)
	libro = load("res://presentacion/ui/spellbook.gd").new()
	libro.size = Vector2(1280.0, 720.0)
	libro.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(libro)
	await process_frame
	await _preparar()

	await _s1_s3()
	await _s4_cola()
	await _s5_cadena()
	await _s6_al_final()
	await _s7_instantaneo()
	await _s8_cerrar()

	print("COMPROBACIONES: %d" % _comprobaciones)
	print("FALLOS: %d" % _fallos)
	Sensacion3D.ACTIVA = true
	libro.set("PASAR_PAGINA_ANIMADO", true)
	Sfx.REGISTRAR = false
	quit(1 if _fallos > 0 else 0)


func _preparar() -> void:
	lanz.select_page(0)
	if not libro.is_open:
		libro.call("_open")
	await _fotogramas(8)                                  # el fundido de abrir (0,15 s) acaba


func _esperar_fin(max_f: int = 40) -> int:
	var n: int = 0
	while libro.call("pasando_pagina") and n < max_f:
		await _fotograma()
		n += 1
	return n


func _s1_s3() -> void:
	var mano: ManoPluma2D = libro.get("mano")
	_ok("0 hay mano 3D (o 2D) y el libro está abierto", mano != null and libro.is_open, str(mano))
	Sfx.vaciar_registro()
	var antes_poses: Dictionary = mano.poses_vistas.duplicate()
	_tecla(1)
	_ok("1 al pulsar empieza la animación y la página NO ha cambiado", libro.call("pasando_pagina") and lanz.page == 0)
	_ok("1 `paginas_bucle` suena al empezar y `pagina` aún no", Sfx.veces("paginas_bucle") == 1 and Sfx.veces("pagina") == 0)
	var cambio_f: int = -1
	var n: int = 0
	var min_x: float = 9.0
	var min_mano: float = 9.0
	var pose_pinza: bool = false
	var pose_lev: bool = false
	var pagina_antes_de_plegar: bool = true
	while libro.call("pasando_pagina") and n < 40:
		await _fotograma()
		n += 1
		min_x = minf(min_x, libro.scale.x)
		min_mano = minf(min_mano, mano.scale.x * libro.scale.x)
		pose_pinza = pose_pinza or mano.pose == ManoPluma2D.Pose.PINZA
		pose_lev = pose_lev or mano.pose == ManoPluma2D.Pose.LEVANTADA
		if cambio_f < 0 and lanz.page == 1:
			cambio_f = n
			pagina_antes_de_plegar = libro.hoja_min_visto <= libro.HOJA_MIN + 0.005      # el cambio llega cuando la hoja ya se ha plegado del todo
	var dur: float = float(n) / 30.0
	_ok("3 duración %.2f s (%d fotogramas a 30 fps) <= T_PASAR_MAX %.2f" % [dur, n, libro.T_PASAR_MAX], dur <= libro.T_PASAR_MAX + 1.0 / 30.0 and n > 3)
	_ok("1 la página cambia durante la animación, con la hoja plegada (fotograma %d), no antes" % cambio_f, cambio_f > 1 and cambio_f < n and pagina_antes_de_plegar)
	_ok("1 al terminar: página 1 y `pagina` suena una vez", lanz.page == 1 and Sfx.veces("pagina") == 1 and Sfx.veces("paginas_bucle") == 1)
	_ok("1 el bucle se corta al terminar (no queda reproductor)", libro.get("_pasar_bucle") == null)
	_ok("3 la hoja llega a scale.x ≈ %.2f (mínimo visto %.3f)" % [libro.HOJA_MIN, libro.hoja_min_visto], absf(libro.hoja_min_visto - libro.HOJA_MIN) < 0.005)
	_ok("3 …y vuelve a 1 (escala %s) con el pivote en el centro" % str(libro.scale), is_equal_approx(libro.scale.x, 1.0) and is_equal_approx(libro.scale.y, 1.0) and libro.pivot_offset.is_equal_approx(libro.size * 0.5))
	_ok("3 la mano no se aplasta con la hoja (ancho efectivo mínimo %.2f)" % min_mano, min_mano > 0.95)
	_ok("2 la mano pasó por LEVANTADA y por PINZA", pose_lev and pose_pinza and int(mano.poses_vistas.get(ManoPluma2D.Pose.PINZA, 0)) > int(antes_poses.get(ManoPluma2D.Pose.PINZA, 0)))
	_ok("2 sin pose forzada al acabar y la escala de la mano restaurada", mano.pose_forzada == -1 and mano.scale.is_equal_approx(Vector2.ONE) and mano.pose != ManoPluma2D.Pose.PINZA)
	await _fotogramas(75)                                # 2,5 s quieta
	_ok("2 la mano vuelve a REPOSO (pose %s)" % ManoPluma2D.nombre_pose(mano.pose), mano.pose == ManoPluma2D.Pose.REPOSO)


func _s4_cola() -> void:
	lanz.select_page(0)
	libro.set("pending_strokes", [])
	var c: Vector2 = libro.call("_center")
	_tecla(2)
	await _fotogramas(2)
	_ok("4 (animando) la página 2 aún no está", libro.call("pasando_pagina") and lanz.page == 0)
	_boton(c, true)
	for i in range(1, 6):
		_mover(c + Vector2(30.0 * i, 0.0))
	_boton(c + Vector2(150.0, 0.0), false)
	_ok("4 un trazo durante la animación no escribe todavía (encolado)", (libro.pending_strokes as Array).is_empty() and not libro.is_drawing and (libro.get("_cola_raton") as Array).size() >= 7)
	await _esperar_fin()
	_ok("4 al terminar: página 2 y el trazo está aplicado (%d trazos)" % (libro.pending_strokes as Array).size(), lanz.page == 2 and (libro.pending_strokes as Array).size() == 1 and (libro.get("_cola_raton") as Array).is_empty())
	var puntos: int = ((libro.pending_strokes as Array)[0] as PackedVector2Array).size() if (libro.pending_strokes as Array).size() == 1 else 0
	# El trazo recto rectifica en vivo (2 puntos para una recta): lo que importa es que empieza y acaba donde el ratón.
	var tr: PackedVector2Array = (libro.pending_strokes as Array)[0] if (libro.pending_strokes as Array).size() == 1 else PackedVector2Array()
	_ok("4 …entero (%d puntos, de %s a %s)" % [puntos, str(tr[0] if tr.size() > 0 else Vector2.ZERO), str(tr[tr.size() - 1] if tr.size() > 0 else Vector2.ZERO)], tr.size() >= 2 and tr[0].distance_to(c) < 5.0 and tr[tr.size() - 1].distance_to(c + Vector2(150.0, 0.0)) < 25.0)
	libro.set("pending_strokes", [])
	libro.set("gesture_countdown", 0.0)


func _s5_cadena() -> void:
	lanz.select_page(0)
	Sfx.vaciar_registro()
	_tecla(1)
	await _fotogramas(2)
	_tecla(2)                                              # durante la primera
	_ok("5 la segunda pulsación se encadena (no se aplica ya)", (libro.get("_pasar_pend") as Array).size() == 1 and lanz.page == 0)
	var n: int = 0
	var vio_1: bool = false
	while libro.call("pasando_pagina") and n < 60:
		await _fotograma()
		n += 1
		vio_1 = vio_1 or lanz.page == 1
	_ok("5 pasa por la página 1 y acaba en la 2 (%d fotogramas = %.2f s)" % [n, float(n) / 30.0], vio_1 and lanz.page == 2 and n <= 2 * 14 + 1)
	_ok("5 dos `pagina` y dos `paginas_bucle`", Sfx.veces("pagina") == 2 and Sfx.veces("paginas_bucle") == 2, "%d / %d" % [Sfx.veces("pagina"), Sfx.veces("paginas_bucle")])
	await _fotogramas(3)


func _s6_al_final() -> void:
	lanz.select_page(0)
	libro.set("CAMBIA_AL_CERRAR", false)
	_tecla(1)
	var antes_fin: bool = true
	while libro.call("pasando_pagina"):
		await _fotograma()
		if libro.call("pasando_pagina") and lanz.page != 0:
			antes_fin = false
	_ok("6 CAMBIA_AL_CERRAR = false: la página solo cambia al final", antes_fin and lanz.page == 1)
	libro.set("CAMBIA_AL_CERRAR", true)


func _s7_instantaneo() -> void:
	lanz.select_page(0)
	Sensacion3D.ACTIVA = false
	Sfx.vaciar_registro()
	Sfx._ultima.clear()
	_tecla(2)
	_ok("7 ACTIVA = false: instantáneo, con `pagina`, sin bucle", not libro.call("pasando_pagina") and lanz.page == 2 and Sfx.veces("pagina") == 1 and Sfx.veces("paginas_bucle") == 0)
	Sensacion3D.ACTIVA = true
	await _fotogramas(3)
	lanz.select_page(0)
	libro.set("PASAR_PAGINA_ANIMADO", false)
	Sfx.vaciar_registro()
	Sfx._ultima.clear()
	_tecla(1)
	_ok("7 PASAR_PAGINA_ANIMADO = false: como hoy (instantáneo + `pagina`)", not libro.call("pasando_pagina") and lanz.page == 1 and Sfx.veces("pagina") == 1 and Sfx.veces("paginas_bucle") == 0 and is_equal_approx(libro.scale.x, 1.0))
	libro.set("PASAR_PAGINA_ANIMADO", true)
	await _fotogramas(3)
	lanz.select_page(1)
	Sfx.vaciar_registro()
	Sfx._ultima.clear()
	_tecla(1)
	_ok("7 pulsar la página en la que ya estás: instantáneo (no hay hoja que pasar)", not libro.call("pasando_pagina") and Sfx.veces("pagina") == 1)


func _s8_cerrar() -> void:
	lanz.select_page(0)
	await _fotogramas(3)
	_tecla(2)
	await _fotogramas(2)
	_ok("8 (animando) la página aún no ha cambiado", libro.call("pasando_pagina") and lanz.page == 0)
	libro.call("_close")
	_ok("8 cerrar a media animación: la página pedida queda elegida y todo restaurado", not libro.call("pasando_pagina") and lanz.page == 2 and is_equal_approx(libro.scale.x, libro.scale.y) and libro.get("_pasar_bucle") == null)
	await _fotogramas(10)
	_ok("8 …y sigue cerrada sin errores (escala 1, invisible)", not libro.visible and is_equal_approx(libro.scale.x, 1.0))
