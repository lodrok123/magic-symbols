extends SceneTree

## CAPTURAS CON VENTANA del agua «toy», FASE 3 (pilar / géiser y explosión de área). Necesita ventana (sin --headless) y no espera clics:
##   godot --path . --script res://herramientas/captura_agua_fase3.gd -- docs/capturas/comparativa_vfx/godot_agua/fase3 [todo | geiser | area | secuencia | hoja]
## Saca: géiser (juego, cercana, horizontal; 4 fotogramas al nacer y 4 al morir), explosión de área en 6 fotogramas (0,1 / 0,3 / 0,5 / 0,7 / 1,0 / 1,4 s) con la cámara del juego y la cercana,
## las dos secuencias a 12 fps y la hoja_resumen con las referencias de Pablo arriba.

const TAM: Vector2i = Vector2i(1280, 720)
const CELDA: int = 320
const REF_A: String = "res://docs/capturas/comparativa_vfx/referencia_agua/ref_agua_bola_ola_pilar_a.png"
const REF_B: String = "res://docs/capturas/comparativa_vfx/referencia_agua/ref_agua_bola_ola_pilar_b.png"

var _dir: String = "docs/capturas/comparativa_vfx/godot_agua/fase3"
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
	if que in ["todo", "geiser"]:
		await _geiser()
	if que in ["todo", "area"]:
		await _area()
	if que in ["todo", "secuencia"]:
		await _secuencias()
	_hoja_resumen()
	print("CAPTURAS en " + _dir)
	quit()


## Segundos de SIMULACIÓN desde `t0` (ms reales) con la escala de tiempo actual: las capturas van a cámara lenta para que un tirón al guardar el PNG no se coma fotogramas.
func _sim(t0: int) -> float:
	return float(Time.get_ticks_msec() - t0) / 1000.0 * Engine.time_scale


func _hasta(t0: int, t: float) -> void:
	await process_frame
	while _sim(t0) < t:
		await process_frame


func _seg(s: float) -> void:
	await create_timer(s).timeout


func _cam(desde: Vector3, mira: Vector3) -> void:
	_lab.set("camara_fija", {"desde": desde, "mira": mira})


func _limpiar() -> void:
	_lab.set("camara_fija", {})
	_lab.call("limpiar")
	await _seg(0.4)


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


func _fila(h: Image, ims: Array, fila: int, y0: int) -> void:
	for i in ims.size():
		if ims[i] == null:
			continue
		var im: Image = (ims[i] as Image).duplicate()
		im.convert(Image.FORMAT_RGB8)
		im.resize(CELDA, CELDA, Image.INTERPOLATE_LANCZOS)
		h.blit_rect(im, Rect2i(0, 0, CELDA, CELDA), Vector2i(i * CELDA, y0 + fila * CELDA))


func _hoja_resumen() -> void:
	var filas: Array = []
	for n in ["geiser_vistas", "geiser_nace", "geiser_muere", "area_juego", "area_cerca"]:
		if _hojas.has(n):
			filas.append(_hojas[n])
	if filas.is_empty():
		return
	var ancho: int = 0
	for f in filas:
		ancho = maxi(ancho, (f as Array).size())
	var w: int = CELDA * maxi(ancho, 6)
	var refs: Array = []
	var alto_refs: int = 0
	for r in [REF_A, REF_B]:
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


# ------------------------------------------------------------------ géiser ------------------------------------------------------------------

func _nuevo_pilar() -> Node3D:
	_lab.set("camara_fija", {})
	return _lab.call("fuego_param", 2)


func _vistas(modo: String, p: Vector3) -> void:
	match modo:
		"juego":
			_lab.set("camara_fija", {})
			_lab.call("poner_camara", 0)
		"cerca":
			_lab.call("poner_camara", 1)
			_cam(p + Vector3(2.7, 2.0, 3.4), p + Vector3(0, 1.5, 0))
		"horizontal":
			_lab.call("poner_camara", 1)
			_cam(p + Vector3(5.0, 1.1, 0.8), p + Vector3(0, 1.7, 0))


func _geiser() -> void:
	# vistas del géiser ya asentado
	var e: Node3D = _nuevo_pilar()
	await _seg(1.6)
	var p: Vector3 = e.global_position
	for modo in ["juego", "cerca", "horizontal"]:
		_vistas(modo, p)
		await _seg(0.35)
		_still("geiser_" + modo)
		_cap("geiser_vistas", "geiser_" + modo)
	await _limpiar()
	# nacer y morir, con la cámara cercana y con la del juego
	for modo in ["cerca", "juego"]:
		e = _nuevo_pilar()
		p = e.global_position
		_vistas(modo, p)
		Engine.time_scale = 0.3
		var t0: int = Time.get_ticks_msec()
		for t in [0.10, 0.22, 0.38, 0.65]:
			await _hasta(t0, t)
			_still("geiser_%s_nace_%03d" % [modo, int(t * 1000.0)])
			if modo == "cerca":
				_cap("geiser_nace", "nace_%03d" % int(t * 1000.0))
		await _hasta(t0, 1.6)
		e.call("morir")
		t0 = Time.get_ticks_msec()
		for t in [0.15, 0.45, 0.80, 1.20]:
			await _hasta(t0, t)
			_still("geiser_%s_muere_%03d" % [modo, int(t * 1000.0)])
			if modo == "cerca":
				_cap("geiser_muere", "muere_%03d" % int(t * 1000.0))
		Engine.time_scale = 1.0
		await _limpiar()


# ------------------------------------------------------------------ explosión de área ------------------------------------------------------------------

func _area() -> void:
	for modo in ["juego", "cerca"]:
		var imp: Node3D = _lab.call("explosion_area")
		var punto: Vector3 = imp.global_position
		if modo == "juego":
			_lab.set("camara_fija", {})
			_lab.call("poner_camara", 0)
		else:
			_lab.call("poner_camara", 1)
			_cam(punto + Vector3(3.0, 2.1, 3.6), punto + Vector3(0, 0.55, 0))
		Engine.time_scale = 0.3
		for t in [0.1, 0.3, 0.5, 0.7, 1.0, 1.4]:
			await process_frame
			while is_instance_valid(imp) and imp.tiempo() < t:
				await process_frame
			_still("area_%s_%03d" % [modo, int(t * 1000.0)])
			_cap("area_" + modo, "area_%s_%03d" % [modo, int(t * 1000.0)])
		Engine.time_scale = 1.0
		await _limpiar()


# ------------------------------------------------------------------ secuencias a 12 fps ------------------------------------------------------------------

func _tira(nombre: String, imgs: Array) -> void:
	var cols: int = 6
	var cw: int = 320
	var chh: int = 180
	var filas: int = int(ceil(float(imgs.size()) / float(cols)))
	var im: Image = Image.create_empty(cw * cols, chh * filas, false, Image.FORMAT_RGB8)
	for i in imgs.size():
		var c: Image = (imgs[i] as Image).duplicate()
		c.convert(Image.FORMAT_RGB8)
		c.resize(cw, chh, Image.INTERPOLATE_LANCZOS)
		im.blit_rect(c, Rect2i(0, 0, cw, chh), Vector2i((i % cols) * cw, (i / cols) * chh))
	im.save_png(_dir.path_join(nombre))


func _secuencias() -> void:
	DirAccess.make_dir_recursive_absolute(_dir.path_join("geiser12"))
	DirAccess.make_dir_recursive_absolute(_dir.path_join("area12"))
	# géiser: nace, se mantiene y se desploma
	var e: Node3D = _nuevo_pilar()
	var p: Vector3 = e.global_position
	_vistas("cerca", p)
	Engine.time_scale = 0.4
	var t0: int = Time.get_ticks_msec()
	var k: int = 0
	var celdas: Array = []
	var muerto: bool = false
	while k < 42:
		await _hasta(t0, float(k) / 12.0)
		_vistas("cerca", p)
		if not muerto and float(k) / 12.0 >= 1.5 and is_instance_valid(e):
			e.call("morir")
			muerto = true
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png(_dir.path_join("geiser12").path_join("g_%02d.png" % k))
		celdas.append(img)
		k += 1
	_tira("secuencia_geiser_12fps.png", celdas)
	Engine.time_scale = 1.0
	await _limpiar()
	# explosión de área
	var imp: Node3D = _lab.call("explosion_area")
	var punto: Vector3 = imp.global_position
	_lab.call("poner_camara", 1)
	_cam(punto + Vector3(3.0, 2.1, 3.6), punto + Vector3(0, 0.55, 0))
	Engine.time_scale = 0.4
	t0 = Time.get_ticks_msec()
	k = 0
	celdas = []
	while k < 24:
		await _hasta(t0, float(k) / 12.0)
		var img2: Image = root.get_viewport().get_texture().get_image()
		img2.save_png(_dir.path_join("area12").path_join("a_%02d.png" % k))
		celdas.append(img2)
		k += 1
	_tira("secuencia_area_12fps.png", celdas)
	Engine.time_scale = 1.0
	await _limpiar()

