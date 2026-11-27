extends "res://herramientas/escenario_base.gd"
## CAPTURAS COMPARADAS DE LA CÁMARA A 45º (27/11/2026, PRUEBA de Pablo): tres niveles (un bosque generado, unas ruinas y una cueva), dos puntos por nivel
## (la entrada y la sala del primer puzle) y tres variantes de cámara desde el MISMO punto:
##   A  _incl 60, zoom 6,0   (lo de antes)
##   B  _incl 45, zoom 6,0
##   C  _incl 45, zoom 7,3   (compensa parte del suelo en profundidad que se pierde: a 60º se ven 6/sin30 = 12 u; a 45º, 6/sin45 = 8,5 u)
## Se cambia `_incl` y el tamaño en caliente (`_tam_camara`, `_camara.size`) y se vuelve a colocar la cámara. No se toca ningún nivel ni constante.
## NECESITA VENTANA (no --headless); se abre y se cierra sola:
##   Godot_v4.7.2-stable_win64.exe --path . --script res://herramientas/captura_camara_45.gd [-- nivel=CuevaPrueba]
## Salida: docs/capturas/camara_45_2026-11-27/<nivel>_<punto>_A60.png, _B45.png, _C45_zoom73.png. Imprime también el zoom que se VE (la cámara por salas
## puede recortarlo en una sala pequeña) y el brillo medio de cada foto.

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const DIR: String = "res://docs/capturas/camara_45_2026-11-27"
const NIVELES: Array = ["BosqueGen01", "RuinasPrueba", "CuevaPrueba"]
## [sufijo del archivo, inclinación desde la vertical, zoom]
const VARIANTES: Array = [["A60", 60.0, 6.0], ["B45", 45.0, 6.0], ["C45_zoom73", 45.0, 7.3]]

var _dir: String = ""


func _escenario() -> void:
	var solo: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("nivel="):
			solo = a.substr(6)
	_dir = ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = Vector2i(1600, 900)
	for n in NIVELES:
		if solo == "" or solo == n:
			await _nivel(n)


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
		print("NO CARGA el nivel ", nombre)
		return
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	for g in (maqueta.get("_goblins") as Array):
		if is_instance_valid(g):
			(g as Node3D).visible = false
	root.get_window().size = Vector2i(1600, 900)
	await avanzar(10)
	var filas: PackedStringArray = m["filas"]
	var sitios: Array = [["entrada", m["inicio"]]]
	var salas: Dictionary = {}
	for s in m["salas"]:
		salas[int(s["id"])] = s
	var con_puzle: Array = (m["puzles"] as Dictionary).keys()
	con_puzle.sort_custom(func(a, b) -> bool: return int(salas[a]["dist"]) < int(salas[b]["dist"]))
	if con_puzle.size() > 0:
		sitios.append(["puzle", _suelo_cerca(filas, salas[con_puzle[0]]["rect"])])
	for s in sitios:
		var c: Vector2i = s[1]
		if c.x < 0:
			print("sin sitio para ", nombre, " ", s[0])
			continue
		colocar_jugador(c)
		await avanzar(80)
		for v in VARIANTES:
			maqueta.set("_incl", float(v[1]))
			maqueta.set("_tam_camara", float(v[2]))
			(maqueta.get("_camara") as Camera3D).size = float(v[2])
			maqueta.set("_camara_salto", true)              # la cámara de salas salta al sitio, sin deslizarse desde la variante anterior
			maqueta.call("_colocar_camara")
			await avanzar(40)
			var img: Image = root.get_viewport().get_texture().get_image()
			var ruta: String = "%s/%s_%s_%s.png" % [_dir, nombre, s[0], v[0]]
			img.save_png(ruta)
			print("captura: %s  casilla %s  zoom pedido %.1f, zoom visto %.2f, brillo %.3f" % [ruta.get_file(), str(c), float(v[2]), float(maqueta.call("zoom_vista")), _brillo(img)])
	maqueta.set("_incl", 60.0)
	maqueta.get_parent().remove_child(maqueta)
	maqueta.queue_free()
	maqueta = null
	await avanzar(5)


func _brillo(img: Image) -> float:
	var suma: float = 0.0
	var n: int = 0
	for y in range(0, img.get_height(), 20):
		for x in range(0, img.get_width(), 20):
			suma += img.get_pixel(x, y).get_luminance()
			n += 1
	return suma / maxf(1.0, float(n))


func _suelo_cerca(filas: PackedStringArray, r: Rect2i) -> Vector2i:
	var centro: Vector2 = Vector2(r.position) + Vector2(r.size) * 0.5
	var mejor: Vector2i = Vector2i(-1, -1)
	var dm: float = INF
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if ".,gvR".contains(filas[y][x]) and Terreno3D.pisable(Vector2i(x, y), 0, true, 1, false) and Vector2(x + 0.5, y + 0.5).distance_to(centro) < dm:
				dm = Vector2(x + 0.5, y + 0.5).distance_to(centro)
				mejor = Vector2i(x, y)
	return mejor
