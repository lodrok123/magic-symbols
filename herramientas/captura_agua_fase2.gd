extends SceneTree

## CAPTURAS CON VENTANA del agua «toy», FASE 2 (bola corregida, salpicadura en pared y haz). Necesita ventana (sin --headless) y no espera clics:
##   godot --path . --script res://herramientas/captura_agua_fase2.gd -- docs/capturas/comparativa_vfx/godot_agua/fase2 [todo | bola | pared | suelo | haz | corte | secuencia | hoja]
## Saca: bola quieta y en vuelo (juego, cercana, horizontal), salpicadura en pared y suelo, haz (lado, juego, cercana), 4 fotogramas del corte y la secuencia del haz a 12 fps.
## Los «antes» salen de docs/capturas/comparativa_vfx/godot_agua/fase1 (ya hechos); la hoja_resumen los junta con los «después» y con las referencias de Pablo.

const TAM: Vector2i = Vector2i(1280, 720)
const CELDA: int = 320
const F1: String = "res://docs/capturas/comparativa_vfx/godot_agua/fase1/"
const REF_HAZ: String = "res://docs/capturas/comparativa_vfx/referencia_agua/ref_agua_haz_a.png"
const REF_BOLA: String = "res://docs/capturas/comparativa_vfx/referencia_agua/ref_agua_bola_ola_pilar_a.png"

var _dir: String = "docs/capturas/comparativa_vfx/godot_agua/fase2"
var _lab: Node3D = null
var _hojas: Dictionary = {}


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var que: String = "todo"
	if a.size() > 0:
		_dir = a[0]
	if a.size() > 1:
		que = a[1]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir.path_join("frames"))
	root.get_window().size = TAM
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_lab = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_lab)
	_lab.set("_panel_visible", false)
	_lab.call("poner_elemento", "agua")
	_lab.call("poner_camara", 1)
	await _seg(0.8)
	if que in ["todo", "bola"]:
		await _quieta()
		await _vuelo()
	if que in ["todo", "pared"]:
		await _pared()
	if que in ["todo", "suelo"]:
		await _suelo()
	if que in ["todo", "haz"]:
		await _haz()
	if que in ["todo", "corte"]:
		await _corte()
	if que in ["todo", "secuencia"]:
		await _secuencia()
	_hoja_resumen()
	print("CAPTURAS en " + _dir)
	quit()


func _seg(s: float) -> void:
	await create_timer(s).timeout


func _cam(desde: Vector3, mira: Vector3) -> void:
	_lab.set("camara_fija", {"desde": desde, "mira": mira})


func _limpiar() -> void:
	_lab.call("limpiar")
	await _seg(0.35)


func _still(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre + ".png"))
	print("still " + nombre)


func _cap(hoja: String, nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var lado: int = mini(img.get_width(), img.get_height())
	var cuadro: Image = img.get_region(Rect2i((img.get_width() - lado) / 2, 0, lado, lado))
	cuadro.save_png(_dir.path_join("frames").path_join(nombre + ".png"))
	if not _hojas.has(hoja):
		_hojas[hoja] = []
	(_hojas[hoja] as Array).append(cuadro)
	print("captura " + nombre)


func _cuadro_de_archivo(ruta: String) -> Image:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(ruta))
	if img == null:
		return null
	var lado: int = mini(img.get_width(), img.get_height())
	return img.get_region(Rect2i((img.get_width() - lado) / 2, 0, lado, lado))


func _fila(h: Image, ims: Array, fila: int, y0: int) -> void:
	for i in ims.size():
		if ims[i] == null:
			continue
		var im: Image = (ims[i] as Image).duplicate()
		im.convert(Image.FORMAT_RGB8)
		im.resize(CELDA, CELDA, Image.INTERPOLATE_LANCZOS)
		h.blit_rect(im, Rect2i(0, 0, CELDA, CELDA), Vector2i(i * CELDA, y0 + fila * CELDA))


func _hoja_resumen() -> void:
	var antes_bola: Array = [_cuadro_de_archivo(F1 + "bola_quieta_juego.png"), _cuadro_de_archivo(F1 + "bola_quieta_cerca.png"), _cuadro_de_archivo(F1 + "bola_quieta_horizontal.png"),
		_cuadro_de_archivo(F1 + "bola_vuelo_juego.png"), _cuadro_de_archivo(F1 + "bola_vuelo_cerca.png"), _cuadro_de_archivo(F1 + "bola_vuelo_horizontal.png")]
	var antes_pared: Array = []
	for t in ["050", "150", "300", "600"]:
		antes_pared.append(_cuadro_de_archivo(F1 + "frames/pared_" + t + ".png"))
	var antes_suelo: Array = []
	for t in ["050", "150", "300", "600"]:
		antes_suelo.append(_cuadro_de_archivo(F1 + "frames/suelo_" + t + ".png"))
	var filas: Array = []
	if _hojas.has("bola_quieta_vuelo"):
		filas.append(antes_bola)
		filas.append(_hojas["bola_quieta_vuelo"])
	if _hojas.has("pared"):
		filas.append(antes_pared)
		filas.append(_hojas["pared"])
	if _hojas.has("suelo"):
		filas.append(antes_suelo)
		filas.append(_hojas["suelo"])
	for n in ["haz_vistas", "corte"]:
		if _hojas.has(n):
			filas.append(_hojas[n])
	if filas.is_empty():
		return
	var ancho: int = 0
	for f in filas:
		ancho = maxi(ancho, (f as Array).size())
	var w: int = CELDA * ancho
	var refs: Array = []
	var alto_refs: int = 0
	for r in [REF_HAZ, REF_BOLA]:
		if ResourceLoader.exists(r):
			var im: Image = load(r).get_image()
			im.convert(Image.FORMAT_RGB8)
			var hh: int = int(round(float(im.get_height()) * float(w) / float(im.get_width())))
			im.resize(w, hh, Image.INTERPOLATE_LANCZOS)
			refs.append(im)
			alto_refs += hh
	var h: Image = Image.create_empty(w, alto_refs + CELDA * filas.size(), false, Image.FORMAT_RGB8)
	h.fill(Color(0.08, 0.08, 0.1))
	var y: int = 0
	for im in refs:
		h.blit_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(0, y))
		y += im.get_height()
	for i in filas.size():
		_fila(h, filas[i], i, alto_refs)
	h.save_png(_dir.path_join("hoja_resumen.png"))


func _mano() -> Vector3:
	return (_lab.get("_pj") as Node3D).global_position + Vector3(0, 0.7, 0) + Vector3(0, 0, -1) * 0.5


# ------------------------------------------------------------------ bola ------------------------------------------------------------------

func _quieta() -> void:
	var e: Node3D = _lab.call("fuego_param", 0)
	await _seg(0.9)
	var p: Vector3 = e.global_position
	_lab.set("camara_fija", {})
	_lab.call("poner_camara", 0)
	await _seg(0.4)
	_still("bola_quieta_juego")
	_cap("bola_quieta_vuelo", "quieta_juego")
	_lab.call("poner_camara", 1)
	_cam(p + Vector3(1.0, 0.45, 1.3), p)
	await _seg(0.4)
	_still("bola_quieta_cerca")
	_cap("bola_quieta_vuelo", "quieta_cerca")
	_cam(p + Vector3(1.6, 0.0, 0.2), p)
	await _seg(0.3)
	_still("bola_quieta_horizontal")
	_cap("bola_quieta_vuelo", "quieta_horizontal")
	await _limpiar()


func _vuelo() -> void:
	var e: Node3D = _lab.call("fuego_param", 0)
	_lab.call("viaja_param")
	await _seg(0.5)
	_lab.set("camara_fija", {})
	_lab.call("poner_camara", 0)
	await _seg(0.25)
	_still("bola_vuelo_juego")
	_cap("bola_quieta_vuelo", "vuelo_juego")
	_lab.call("poner_camara", 1)
	for modo in ["cerca", "horizontal"]:
		var n: int = 0
		while n < 3:
			await process_frame
			if not is_instance_valid(e):
				break
			var p: Vector3 = e.global_position
			if modo == "cerca":
				_cam(p + Vector3(1.3, 0.55, 0.9), p + Vector3(0, 0, 0.7))
			else:
				_cam(p + Vector3(1.9, 0.0, 0.5), p + Vector3(0, 0, 0.7))
			n += 1
			if n == 3:
				_still("bola_vuelo_" + modo)
				_cap("bola_quieta_vuelo", "vuelo_" + modo)
	await _limpiar()


# ------------------------------------------------------------------ salpicadura ------------------------------------------------------------------

func _pared() -> void:
	var imp: Node3D = _lab.call("impacto_pared")
	var punto: Vector3 = imp.global_position
	_cam(punto + Vector3(2.6, 1.3, 2.4), punto + Vector3(0, 0.25, 0.3))
	for t in [0.05, 0.15, 0.30, 0.60]:
		while is_instance_valid(imp) and imp.tiempo() < t:
			await process_frame
		_cap("pared", "pared_%03d" % int(t * 1000.0))
	await _limpiar()
	# más cerca y de lado, para ver las gotas que caen y la mancha
	imp = _lab.call("impacto_pared")
	punto = imp.global_position
	_cam(punto + Vector3(1.6, 0.4, 1.4), punto + Vector3(0, -0.1, 0.0))
	for t in [0.12, 0.30, 0.45]:
		while is_instance_valid(imp) and imp.tiempo() < t:
			await process_frame
		_still("pared_lado_%03d" % int(t * 1000.0))
	await _limpiar()


func _suelo() -> void:
	var imp: Node3D = _lab.call("impacto_suelo")
	var punto: Vector3 = imp.global_position
	_cam(punto + Vector3(2.4, 1.2, 2.4), punto + Vector3(0, 0.3, 0))
	for t in [0.05, 0.15, 0.30, 0.60]:
		while is_instance_valid(imp) and imp.tiempo() < t:
			await process_frame
		_cap("suelo", "suelo_%03d" % int(t * 1000.0))
	await _limpiar()


# ------------------------------------------------------------------ haz ------------------------------------------------------------------

func _nuevo_haz() -> Node3D:
	_lab.set("camara_fija", {})
	return _lab.call("fuego_param", 4)


func _haz() -> void:
	var e: Node3D = _nuevo_haz()
	await _seg(1.3)
	var xf: Transform3D = e.global_transform
	var h: float = maxf(e.semieje_y, 0.4)
	var centro: Vector3 = xf * Vector3(0, h, -1.5)
	var lado: Vector3 = xf.basis.x
	# de lado
	_lab.call("poner_camara", 1)
	_cam(centro + lado * 4.4 + Vector3(0, 0.3, 0), centro)
	await _seg(0.3)
	_still("haz_lado")
	_cap("haz_vistas", "haz_lado")
	# cámara del juego
	_lab.set("camara_fija", {})
	_lab.call("poner_camara", 0)
	await _seg(0.4)
	_still("haz_juego")
	_cap("haz_vistas", "haz_juego")
	# cercana, desde detrás y a un lado
	_lab.call("poner_camara", 1)
	_cam(xf * Vector3(1.0, h + 0.45, 1.3), xf * Vector3(0, h, -1.8))
	await _seg(0.3)
	_still("haz_cerca")
	_cap("haz_vistas", "haz_cerca")
	# de frente a la punta
	_cam(xf * Vector3(0.9, h + 0.3, -3.8), xf * Vector3(0, h, -2.6))
	await _seg(0.3)
	_still("haz_punta")
	_cap("haz_vistas", "haz_punta")
	# nace: 3 instantes de crecimiento
	await _limpiar()


## 4 fotogramas del corte (el chorro se suelta y se rompe en gotas) con la cámara de lado.
func _corte() -> void:
	var e: Node3D = _nuevo_haz()
	await _seg(1.3)
	var xf: Transform3D = e.global_transform
	var h: float = maxf(e.semieje_y, 0.4)
	var centro: Vector3 = xf * Vector3(0, h, -1.8)
	_lab.call("poner_camara", 1)
	_cam(centro + xf.basis.x * 3.6 + Vector3(0, 0.25, 0), centro)
	await _seg(0.2)
	e.call("morir")
	var t0: int = Time.get_ticks_msec()
	for t in [0.10, 0.30, 0.55, 0.85]:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < t:
			await process_frame
		_still("corte_%03d" % int(t * 1000.0))
		_cap("corte", "corte_%03d" % int(t * 1000.0))
	await _limpiar()


## El haz entero a 12 fps: nace, se mantiene y se corta.
func _secuencia() -> void:
	var e0: Node3D = _nuevo_haz()
	var xf: Transform3D = e0.global_transform
	var h: float = maxf(e0.semieje_y, 0.4)
	var centro: Vector3 = xf * Vector3(0, h, -1.6)
	_lab.call("poner_camara", 1)
	_cam(centro + xf.basis.x * 3.4 + Vector3(0, 0.25, 0), centro)
	await _seg(0.3)
	DirAccess.make_dir_recursive_absolute(_dir.path_join("haz12"))
	var t0: int = Time.get_ticks_msec()
	var k: int = 0
	var celdas: Array = []
	var cortado: bool = false
	while k < 48:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < float(k) / 12.0:
			await process_frame
		_cam(centro + xf.basis.x * 3.4 + Vector3(0, 0.25, 0), centro)
		if not cortado and float(k) / 12.0 >= 1.3 and is_instance_valid(e0):
			e0.call("morir")
			cortado = true
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png(_dir.path_join("haz12").path_join("h_%02d.png" % k))
		celdas.append(img)
		k += 1
	var cols: int = 6
	var cw: int = 320
	var chh: int = 180
	var filas: int = int(ceil(float(celdas.size()) / float(cols)))
	var im: Image = Image.create_empty(cw * cols, chh * filas, false, Image.FORMAT_RGB8)
	for i in celdas.size():
		var c: Image = (celdas[i] as Image).duplicate()
		c.convert(Image.FORMAT_RGB8)
		c.resize(cw, chh, Image.INTERPOLATE_LANCZOS)
		im.blit_rect(c, Rect2i(0, 0, cw, chh), Vector2i((i % cols) * cw, (i / cols) * chh))
	im.save_png(_dir.path_join("secuencia_haz_12fps.png"))
	await _limpiar()
