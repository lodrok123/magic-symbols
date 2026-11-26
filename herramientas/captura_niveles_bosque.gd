extends "res://herramientas/escenario_base.gd"
## CAPTURAS DE LOS TRES NIVELES DE BOSQUE (26/11/2026). Carga cada nivel exportado por herramientas/generar_niveles_bosque.gd con la maqueta y hace, por nivel:
## una vista general CENITAL del mapa entero y varias fotos con la cámara del juego (la entrada, un claro con puzle, el vado del río, el campamento, la salida, la cabaña
## desde dos sitios). NECESITA VENTANA (no --headless); la ventana se abre y se cierra sola:
##   godot --path . --script res://herramientas/captura_niveles_bosque.gd [-- nivel=BosqueCabana] [-- solo=cabana_a,cabana_b]
## Salida: docs/capturas/niveles_bosque_2026-11-26/<Nivel>_<foto>.png. Lo que se lee del mapa (claros, cabaña…) se regenera con el generador desde el propio .txt.

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const DIR: String = "res://docs/capturas/niveles_bosque_2026-11-26"
const NIVELES: Array = ["BosqueGen01", "BosqueGen02", "BosqueCabana"]
const S: float = 2.3

var _dir: String = ""
var _solo: Array = []


func _escenario() -> void:
	var nivel: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("nivel="):
			nivel = a.substr(6)
		elif a.begins_with("solo="):
			_solo = a.substr(5).split(",")
	_dir = ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = Vector2i(1600, 900)
	for n in NIVELES:
		if nivel == "" or nivel == n:
			await _nivel(n)


func _quiero(foto: String) -> bool:
	return _solo.is_empty() or _solo.has(foto)


## El mapa tal como lo regenera el generador desde su .txt (con sus retoques, movidos, añadidos…).
func _mapa_de(nombre: String) -> Dictionary:
	var texto: String = FileAccess.get_file_as_string(Exportador.ruta_mapa(nombre))
	var par: Dictionary = Exportador._tipar(Exportador.parametros_de(texto))
	return Generador.new().generar(par, Exportador.retoques_de(texto), Exportador.enlaces_de(texto), Exportador.puzles_de(texto), Exportador.movidos_de(texto),
		Exportador.anadidos_de(texto), Exportador.apariciones_de(texto))


func _nivel(nombre: String) -> void:
	var m: Dictionary = _mapa_de(nombre)
	Flags.nuevo()
	Estado.nuevo()
	await cargar(Exportador.ruta_escena(nombre), false)
	if maqueta == null:
		return
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	# Los enemigos fuera: las fotos son del paisaje.
	for g in (maqueta.get("_goblins") as Array):
		if is_instance_valid(g):
			(g as Node3D).visible = false
	root.get_window().size = Vector2i(1600, 900)
	await avanzar(10)
	var filas: PackedStringArray = m["filas"]
	if _quiero("arriba"):
		await _general(Rect2i(0, 0, int(m["ancho"]), int(m["alto"])), 2000, "%s/%s_arriba.png" % [_dir, nombre])
		root.get_window().size = Vector2i(1600, 900)
		await avanzar(10)
	var sitios: Array = []
	sitios.append(["entrada", m["inicio"]])
	# un claro con puzle (el primero por cercanía) y otro más
	var con_puzle: Array = (m["puzles"] as Dictionary).keys()
	var salas: Dictionary = {}
	for s in m["salas"]:
		salas[int(s["id"])] = s
	con_puzle.sort_custom(func(a, b) -> bool: return int(salas[a]["dist"]) < int(salas[b]["dist"]))
	if con_puzle.size() > 0:
		sitios.append(["puzle_a", _suelo_cerca(filas, salas[con_puzle[0]]["rect"])])
	if con_puzle.size() > 3:
		sitios.append(["puzle_b", _suelo_cerca(filas, salas[con_puzle[3]]["rect"])])
	var vado: Vector2i = _vado(filas)
	if vado.x >= 0:
		sitios.append(["rio", vado])
	for s in m["salas"]:
		if String(s["rol"]) == "campamento":
			sitios.append(["campamento", _suelo_cerca(filas, s["rect"])])
	for o in m["objetos"]:
		if String(o["tipo"]) == "salida" and String(o["id"]) != "a_salida_1":
			sitios.append(["salida", _vecina_libre(filas, o["c"])])
	var cab: Dictionary = m["cabana"]
	if not cab.is_empty():
		var c: Vector2i = cab["c"]
		sitios.append(["cabana_a", c + Vector2i(-1, 2)])          # delante, a la izquierda de la puerta (la guardabosques a la derecha)
		sitios.append(["cabana_b", c + Vector2i(2, 2)])           # por el costado de la leña y los barriles
		sitios.append(["cabana_c", c + Vector2i(-3, 1)])          # por el costado del huerto y la carreta
		sitios.append(["cabana_lejos", c + Vector2i(0, 4)])       # la misma cámara del juego pero con el zoom ×2,4 (solo para REVISAR escala y orientación: el juego no aleja tanto)
	for s in sitios:
		var c: Vector2i = s[1]
		if not _quiero(String(s[0])) or c.x < 0:
			continue
		colocar_jugador(c)
		await avanzar(80)
		var lejos: Camera3D = null
		if String(s[0]) == "cabana_lejos":
			# La cámara del juego, con su misma inclinación y encuadre, pero con el zoom ×2,4 (otra cámara ortogonal copiada de la suya).
			var cj: Camera3D = maqueta.get("_camara") as Camera3D
			lejos = Camera3D.new()
			lejos.projection = Camera3D.PROJECTION_ORTHOGONAL
			lejos.size = cj.size * 2.4
			lejos.near = cj.near
			lejos.far = cj.far
			maqueta.add_child(lejos)
			lejos.global_transform = cj.global_transform
			lejos.current = true
			await avanzar(8)
		var f: String = "%s/%s_%s.png" % [_dir, nombre, s[0]]
		root.get_viewport().get_texture().get_image().save_png(f)
		if lejos != null:
			lejos.queue_free()
		print("captura: ", f, " jugadora en ", c)
	if not cab.is_empty() and _quiero("cabana_cenital"):
		var c2: Vector2i = cab["c"]
		await _general(Rect2i(c2.x - 9, c2.y - 7, 19, 15), 1500, "%s/%s_cabana_cenital.png" % [_dir, nombre])
	maqueta.get_parent().remove_child(maqueta)
	maqueta.queue_free()
	maqueta = null
	await avanzar(5)


func _suelo_cerca(filas: PackedStringArray, r: Rect2i) -> Vector2i:
	var centro: Vector2 = Vector2(r.position) + Vector2(r.size) * 0.5
	var mejor: Vector2i = Vector2i(-1, -1)
	var dm: float = INF
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if ".,gv".contains(filas[y][x]) and not maqueta._bloqueadas.has(Vector2i(x, y)) and Vector2(x + 0.5, y + 0.5).distance_to(centro) < dm:
				dm = Vector2(x + 0.5, y + 0.5).distance_to(centro)
				mejor = Vector2i(x, y)
	return mejor


func _vecina_libre(filas: PackedStringArray, c: Vector2i) -> Vector2i:
	for d in [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		var q: Vector2i = c + d
		if ".,gvR".contains(filas[q.y][q.x]) and not maqueta._bloqueadas.has(q):
			return q
	return c


## Una casilla de vado `R` pegada al agua `~`.
func _vado(filas: PackedStringArray) -> Vector2i:
	for y in range(3, filas.size() - 3):
		for x in range(3, filas[y].length() - 3):
			if filas[y][x] == "R" and (filas[y][x - 1] == "~" or filas[y][x + 1] == "~" or filas[y - 1][x] == "~" or filas[y + 1][x] == "~"):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _general(r: Rect2i, ancho_px: int, ruta: String) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 400.0
	maqueta.add_child(cam)
	var alto_px: int = clampi(int(round(float(ancho_px) * float(r.size.y) / float(r.size.x))), 500, 1800)
	root.get_window().size = Vector2i(ancho_px, alto_px)
	cam.size = float(r.size.y) * S * maxf(1.0, (float(ancho_px) / float(alto_px)) / (float(r.size.x) / float(r.size.y)))
	var centro := Vector3((float(r.position.x) + float(r.size.x) * 0.5) * S, 0.0, (float(r.position.y) + float(r.size.y) * 0.5) * S)
	cam.transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3(0, 0, -1)), centro + Vector3(0, 120, 0))
	cam.current = true
	await avanzar(25)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ruta)
	print("captura: ", ruta, " ", img.get_size())
	cam.queue_free()
