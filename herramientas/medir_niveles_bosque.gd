extends "res://herramientas/escenario_base.gd"
## RENDIMIENTO DE LOS TRES NIVELES DE BOSQUE (26/11/2026): llamadas de dibujo, objetos, primitivas y fotogramas por segundo con la cámara del juego quieta sobre la jugadora,
## en la entrada y en el claro con más cosas (la cabaña en BosqueCabana, el campamento en BosqueGen02, el primer puzle en BosqueGen01), con la escena exportada.
## NECESITA VENTANA (no --headless); sin vsync (--disable-vsync) para no medir el tope del monitor:
##   godot --path . --disable-vsync --script res://herramientas/medir_niveles_bosque.gd
const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const NIVELES: Array = ["BosqueGen01", "BosqueGen02", "BosqueCabana"]


func _escenario() -> void:
	root.get_window().size = Vector2i(1600, 900)
	var lista: Array = NIVELES
	for a in OS.get_cmdline_user_args():
		if a.begins_with("niveles="):         # p. ej. `-- niveles=Bosque_02,Bosque_01_v01` para comparar con los hechos a mano (solo se mide la entrada)
			lista = a.substr(8).split(",")
	for n in lista:
		await _nivel(n)


func _mapa_de(nombre: String) -> Dictionary:
	var texto: String = FileAccess.get_file_as_string(Exportador.ruta_mapa(nombre))
	var par: Dictionary = Exportador._tipar(Exportador.parametros_de(texto))
	return Generador.new().generar(par, Exportador.retoques_de(texto), Exportador.enlaces_de(texto), Exportador.puzles_de(texto), Exportador.movidos_de(texto),
		Exportador.anadidos_de(texto), Exportador.apariciones_de(texto))


func _nivel(nombre: String) -> void:
	var generado: bool = not Exportador.parametros_de(FileAccess.get_file_as_string(Exportador.ruta_mapa(nombre))).is_empty()
	var m: Dictionary = _mapa_de(nombre) if generado else {"inicio": Vector2i(-1, -1), "salas": [], "cabana": {}, "puzles": {}}
	Flags.nuevo()
	Estado.nuevo()
	var t0: int = Time.get_ticks_msec()
	await cargar(Exportador.ruta_escena(nombre), false)
	var carga_ms: int = Time.get_ticks_msec() - t0
	if maqueta == null:
		return
	var sitios: Array = [["entrada", m["inicio"] if generado else celda_jugador()]]
	for s in m["salas"]:
		if String(s["rol"]) == "campamento":
			sitios.append(["campamento", _suelo_de(s["rect"])])
	if not (m["cabana"] as Dictionary).is_empty():
		sitios.append(["cabaña", (m["cabana"]["c"] as Vector2i) + Vector2i(-1, 2)])
	var puzles: Array = (m["puzles"] as Dictionary).keys()
	if not puzles.is_empty():
		for s in m["salas"]:
			if int(s["id"]) == int(puzles[0]):
				sitios.append(["puzle", _suelo_de(s["rect"])])
	for s2 in sitios:
		colocar_jugador(s2[1])
		await avanzar(90)
		var llamadas: Array = []
		var objetos: Array = []
		var prim: Array = []
		var t_ini: int = Time.get_ticks_usec()
		var n: int = 180
		for i in range(n):
			await process_frame
			llamadas.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			objetos.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
			prim.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		var seg: float = float(Time.get_ticks_usec() - t_ini) / 1.0e6
		print("RENDIMIENTO %s · %s %s: %d llamadas de dibujo · %d objetos · %.0f mil primitivas · %.1f fps · carga %d ms · %d lotes" % [nombre, s2[0], str(s2[1]), roundi(_media(llamadas)),
			roundi(_media(objetos)), _media(prim) / 1000.0, float(n) / maxf(seg, 0.001), carga_ms, int(maqueta._n_lotes)])
	maqueta.get_parent().remove_child(maqueta)
	maqueta.queue_free()
	maqueta = null
	await avanzar(5)


func _media(a: Array) -> float:
	var s: float = 0.0
	for v in a:
		s += float(v)
	return s / maxf(float(a.size()), 1.0)


func _suelo_de(r: Rect2i) -> Vector2i:
	var centro: Vector2 = Vector2(r.position) + Vector2(r.size) * 0.5
	var mejor: Vector2i = Vector2i(-1, -1)
	var dm: float = INF
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if Terreno3D.pisable(Vector2i(x, y), 0, true, 1, false) and Vector2(x + 0.5, y + 0.5).distance_to(centro) < dm:
				dm = Vector2(x + 0.5, y + 0.5).distance_to(centro)
				mejor = Vector2i(x, y)
	return mejor
