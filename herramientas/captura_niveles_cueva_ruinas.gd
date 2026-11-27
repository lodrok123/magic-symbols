extends "res://herramientas/escenario_base.gd"
## CAPTURAS DE LOS NIVELES DE REVISIÓN DE ASSETS (27/11/2026): RuinasPrueba, RuinasPruebaMuestrario, CuevaPrueba, CuevaPruebaLostCave (herramientas/generar_niveles_cueva_ruinas.gd). Por nivel:
##   · `<Nivel>_arriba.jpg`   el mapa entero visto desde arriba;
##   · `<Nivel>_puzles.jpg`    una HOJA de contacto con una foto de cada sala de puzle hecha con la cámara del juego (la jugadora a dos tercios de la plantilla, miniaturas de 640 × 360 en rejilla de 3 columnas);
##   · `<Nivel>_muestrario_<n>.jpg`  una HOJA por sala muestrario: la cámara del juego con el zoom × `ZOOM_MUESTRARIO` recorre la sala en trozos (miniaturas de 640 × 360). Los ids no se leen en la miniatura: se leen en el juego.
##   (Son JPG, calidad 0,85, para no pasar de ~30 MB entre todas.)
## NECESITA VENTANA (no --headless); la ventana se abre y se cierra sola:
##   godot --path . --script res://herramientas/captura_niveles_cueva_ruinas.gd [-- nivel=CuevaPrueba] [-- solo=arriba,puzles,muestrarios] [-- sueltas]
##   `sueltas`: guarda también las fotos sueltas de cada sala de puzle en `user://capturas_sueltas/` (fuera del repositorio; si no, solo la hoja).
## Salida: docs/capturas/cueva_ruinas_2026-11-27/. Lo que se lee del mapa se regenera con el generador desde el propio .txt.

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const Catalogo = preload("res://herramientas/generador_mapas/catalogo_puzles.gd")
const DIR: String = "res://docs/capturas/cueva_ruinas_2026-11-27"
const NIVELES: Array = ["RuinasPrueba", "RuinasPruebaMuestrario", "CuevaPrueba", "CuevaPruebaLostCave"]
const S: float = 2.3
const ZOOM_PUZLE: float = 1.5            ## las fotos de las salas de puzle: la cámara del juego con el zoom × 1,35 (se ve entera la plantilla, que mide hasta 11 casillas de alto)
const ZOOM_MUESTRARIO: float = 2.6       ## la cámara del juego con el zoom × 2,6 (cabe un trozo de unas 12 × 8 casillas)
const MINIATURA: Vector2i = Vector2i(640, 360)
const CALIDAD_JPG: float = 0.85
const COLUMNAS_HOJA: int = 3

var _dir: String = ""
var _solo: Array = []
var _sueltas: bool = false
var _luz_foto: OmniLight3D = null          ## luz extra de las fotos de cueva
var _dir_sueltas: String = ""            ## las fotos sueltas van a `user://capturas_sueltas` (son intermedios para mirar: no al repositorio)


func _escenario() -> void:
	var nivel: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("nivel="):
			nivel = a.substr(6)
		elif a.begins_with("solo="):
			_solo = a.substr(5).split(",")
		elif a == "sueltas":
			_sueltas = true
	_dir = ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(_dir)
	_dir_sueltas = ProjectSettings.globalize_path("user://capturas_sueltas")
	DirAccess.make_dir_recursive_absolute(_dir_sueltas)
	root.get_window().size = Vector2i(1600, 900)
	for n in NIVELES:
		if nivel == "" or nivel == n:
			await _nivel(n)


## Coloca la jugadora y, en la cueva, la luz de las fotos encima de ella.
func _poner(c: Vector2i) -> void:
	colocar_jugador(c)
	if _luz_foto != null and is_instance_valid(_luz_foto):
		_luz_foto.global_position = Terreno3D.centro_de(c, 5.0)


func _quiero(que: String) -> bool:
	return _solo.is_empty() or _solo.has(que)


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
	for g in (maqueta.get("_goblins") as Array):
		if is_instance_valid(g):
			(g as Node3D).visible = false
	root.get_window().size = Vector2i(1600, 900)
	await avanzar(10)
	var filas: PackedStringArray = m["filas"]
	# En la cueva (casi a oscuras por diseño) las fotos llevan una luz extra que sigue a la jugadora: es solo para MIRAR las salas, no cambia el nivel.
	_luz_foto = null
	if String(maqueta.get("estilo")) == "cueva":
		_luz_foto = OmniLight3D.new()
		_luz_foto.light_color = Color(1.0, 0.95, 0.85)
		_luz_foto.light_energy = 2.2
		_luz_foto.omni_range = 38.0
		_luz_foto.light_specular = 0.0
		_luz_foto.shadow_enabled = false
		maqueta.add_child(_luz_foto)
	var salas: Dictionary = {}
	for s in m["salas"]:
		salas[int(s["id"])] = s
	if _quiero("arriba"):
		await _general(Rect2i(0, 0, int(m["ancho"]), int(m["alto"])), 2000, "%s/%s_arriba.jpg" % [_dir, nombre])
		root.get_window().size = Vector2i(1600, 900)
		await avanzar(10)
	# Las salas de puzle (no muestrario), en orden de cercanía a la entrada.
	var con_puzle: Array = (m["puzles"] as Dictionary).keys()
	con_puzle.sort_custom(func(a, b) -> bool: return int(salas[a]["dist"]) < int(salas[b]["dist"]))
	if _quiero("puzles"):
		var fotos: Array = []
		var n: int = 0
		for sid in con_puzle:
			var cid: String = String((m["puzles"] as Dictionary)[sid])
			if cid.begins_with("muestrario_"):
				continue
			n += 1
			var r: Rect2i = salas[sid]["rect"]
			# La jugadora a la entrada de la plantilla (la fila de abajo, al medio), para que la cámara del juego vea el puzle; si no se sabe, el suelo más cercano al centro de la sala.
			var c: Vector2i = _entrada_plantilla(m, salas[sid], cid, filas)
			if c.x < 0:
				c = _suelo_cerca(filas, r)
			if c.x < 0:
				continue
			_poner(c)
			await avanzar(70)
			var cj: Camera3D = maqueta.get("_camara") as Camera3D
			var amplia := Camera3D.new()
			amplia.projection = Camera3D.PROJECTION_ORTHOGONAL
			amplia.size = cj.size * ZOOM_PUZLE
			amplia.near = cj.near
			amplia.far = cj.far
			maqueta.add_child(amplia)
			amplia.global_transform = cj.global_transform
			amplia.current = true
			await avanzar(8)
			var img: Image = root.get_viewport().get_texture().get_image()
			amplia.queue_free()
			if _sueltas:
				img.save_png("%s/%s_puzle_%02d_%s.png" % [_dir_sueltas, nombre, n, cid])
			var mini: Image = img.duplicate()
			mini.resize(MINIATURA.x, MINIATURA.y, Image.INTERPOLATE_LANCZOS)
			fotos.append([mini, cid])
			print("foto de sala: ", cid, " jugadora en ", c)
		_hoja(fotos, "%s/%s_puzles.jpg" % [_dir, nombre])
	if _quiero("muestrarios"):
		var k: int = 0
		for sid in con_puzle:
			var cid: String = String((m["puzles"] as Dictionary)[sid])
			if not cid.begins_with("muestrario_"):
				continue
			k += 1
			await _muestrario(nombre, cid, k, filas, m)
	maqueta.get_parent().remove_child(maqueta)
	maqueta.queue_free()
	maqueta = null
	await avanzar(5)


## La sala muestrario: la pieza `muestrario` del mapa dice dónde empieza y qué tamaño tiene; se recorre en trozos con la cámara del juego ampliada.
func _muestrario(nombre: String, cid: String, k: int, filas: PackedStringArray, m: Dictionary) -> void:
	var pieza: Array = []
	for l in m["lineas"]:
		var t: PackedStringArray = String(l).substr(1).strip_edges().split(" ", false)
		if t.size() >= 5 and t[0] == "pieza" and t[2] == "muestrario" and t[1].begins_with("cat") and cid != "" and _de_plantilla(m, t[1], cid):
			pieza = Array(t)
	if pieza.is_empty():
		return
	var x0: int = int(pieza[3])
	var y0: int = int(pieza[4])
	var ancho: int = 12
	var alto: int = 8
	for i in range(5, pieza.size()):
		if String(pieza[i]).begins_with("ancho="):
			ancho = String(pieza[i]).substr(6).to_int()
		elif String(pieza[i]).begins_with("alto="):
			alto = String(pieza[i]).substr(5).to_int()
	var cj: Camera3D = maqueta.get("_camara") as Camera3D
	var lejos := Camera3D.new()
	lejos.projection = Camera3D.PROJECTION_ORTHOGONAL
	lejos.size = cj.size * ZOOM_MUESTRARIO
	lejos.near = cj.near
	lejos.far = cj.far
	maqueta.add_child(lejos)
	# Cuántos trozos: la cámara cubre (alto en casillas) ≈ lejos.size / (S · sin inclinación); se recorre en columnas y filas con un poco de solape.
	var cubre_x: float = lejos.size * 16.0 / 9.0 / S
	var cubre_y: float = lejos.size / S / maxf(0.5, absf(sin(deg_to_rad(maqueta.get("_incl") if maqueta.get("_incl") != null else 60.0))))
	var cols: int = maxi(1, int(ceil(float(ancho) / (cubre_x * 0.9))))
	var fils: int = maxi(1, int(ceil(float(alto) / (cubre_y * 0.9))))
	print("muestrario %s: %d x %d casillas, trozos %d x %d (cubre %.1f x %.1f)" % [cid, ancho, alto, cols, fils, cubre_x, cubre_y])
	var j: int = 0
	var trozos: Array = []
	for fy in range(fils):
		for fx in range(cols):
			var cx: int = x0 + int((float(fx) + 0.5) * float(ancho) / float(cols))
			var cy: int = y0 + int((float(fy) + 0.5) * float(alto) / float(fils))
			_poner(_suelo_junto(Vector2i(cx, cy), filas))
			await avanzar(70)
			lejos.global_transform = cj.global_transform
			lejos.current = true
			await avanzar(10)
			j += 1
			var tr: Image = root.get_viewport().get_texture().get_image()
			tr.resize(MINIATURA.x, MINIATURA.y, Image.INTERPOLATE_LANCZOS)
			trozos.append([tr, "%s %d" % [cid, j]])
	_hoja(trozos, "%s/%s_muestrario_%d.jpg" % [_dir, nombre, k], cols)
	if _sueltas:
		# Tres fotos a tamaño completo con la cámara del juego (zoom × 1,2) para MIRAR la escala, los rótulos y el material (intermedios: van a user://capturas_sueltas).
		lejos.size = cj.size * 1.2
		var puntos: Array = [Vector2i(x0 + 5, y0 + 4), Vector2i(x0 + ancho / 2, y0 + alto / 2), Vector2i(x0 + ancho - 5, y0 + alto - 4)]
		for q in range(puntos.size()):
			_poner(_suelo_junto(puntos[q], filas))
			await avanzar(70)
			lejos.global_transform = cj.global_transform
			lejos.current = true
			await avanzar(10)
			root.get_viewport().get_texture().get_image().save_png("%s/%s_mu%d_%d.png" % [_dir_sueltas, nombre, k, q + 1])
	lejos.queue_free()


## Dónde va la jugadora para ver un puzle: la fila de entrada de la plantilla (la de abajo), al medio. La esquina de la plantilla se saca de su primera pieza (como `catalogo_jugar.gd`).
func _entrada_plantilla(m: Dictionary, sala: Dictionary, cid: String, filas: PackedStringArray) -> Vector2i:
	var e: Dictionary = Catalogo.todos().get(cid, {})
	if e.is_empty() or not sala.has("inst"):
		return Vector2i(-1, -1)
	var inst: String = String(sala["inst"]) + "_"
	var origen: Vector2i = Vector2i(-1, -1)
	for l in (e["lineas"] as Array):
		var t: PackedStringArray = String(l).substr(1).strip_edges().split(" ", false)
		if t.size() < 5 or t[0] != "pieza" or not t[3].is_valid_int() or not t[4].is_valid_int():
			continue
		for l2 in m["lineas"]:
			var u: PackedStringArray = String(l2).substr(1).strip_edges().split(" ", false)
			if u.size() >= 5 and u[0] == "pieza" and u[1] == inst + t[1]:
				origen = Vector2i(u[3].to_int() - t[3].to_int(), u[4].to_int() - t[4].to_int())
				break
		if origen.x >= 0:
			break
	if origen.x < 0:
		return Vector2i(-1, -1)
	var meta: Vector2i = origen + Vector2i(int(e["ancho"]) / 2, int(e["alto"]) * 2 / 3)          # a dos tercios de la plantilla hacia abajo: la cámara (oblicua) encuadra todo el puzle
	return _suelo_junto(meta, filas)


func _de_plantilla(m: Dictionary, id_pieza: String, cid: String) -> bool:
	# `cat3_muestra` → la sala del puzle `cid` es la que tiene esa instancia: se mira en `; puzles`.
	for s in m["salas"]:
		if s.has("inst") and String(s.get("catalogo", "")) == cid and id_pieza.begins_with(String(s["inst"]) + "_"):
			return true
	return false


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


func _suelo_junto(c: Vector2i, filas: PackedStringArray) -> Vector2i:
	for r in range(0, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q: Vector2i = c + Vector2i(dx, dy)
				if q.y >= 0 and q.y < filas.size() and q.x >= 0 and q.x < filas[q.y].length() and ".,gvR".contains(filas[q.y][q.x]) and Terreno3D.pisable(q, 0, true, 1, false):
					return q
	return c


## La hoja de contacto: las miniaturas en rejilla, con el nombre de la plantilla escrito encima (cada una en su recuadro).
func _hoja(fotos: Array, ruta: String, columnas: int = COLUMNAS_HOJA) -> void:
	if fotos.is_empty():
		return
	var filas_h: int = int(ceil(float(fotos.size()) / float(columnas)))
	var hoja: Image = Image.create(MINIATURA.x * columnas, MINIATURA.y * filas_h, false, Image.FORMAT_RGB8)
	hoja.fill(Color(0.05, 0.05, 0.07))
	for i in range(fotos.size()):
		var mini: Image = (fotos[i][0] as Image)
		mini.convert(Image.FORMAT_RGB8)
		hoja.blit_rect(mini, Rect2i(Vector2i.ZERO, MINIATURA), Vector2i((i % columnas) * MINIATURA.x, (i / columnas) * MINIATURA.y))
	hoja.save_jpg(ruta, CALIDAD_JPG)
	var nombres: PackedStringArray = PackedStringArray()
	for i in range(fotos.size()):
		nombres.append("%d=%s" % [i + 1, String(fotos[i][1])])
	print("hoja: ", ruta, " (de izquierda a derecha y de arriba abajo) ", ", ".join(nombres))


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
	img.save_jpg(ruta, CALIDAD_JPG)
	print("captura: ", ruta, " ", img.get_size())
	cam.queue_free()
