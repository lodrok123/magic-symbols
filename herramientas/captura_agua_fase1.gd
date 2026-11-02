extends SceneTree

## CAPTURAS CON VENTANA del agua «toy», FASE 1 (bola, casteo y salpicadura). Necesita ventana (sin --headless) y no espera clics:
##   godot --path . --script res://herramientas/captura_agua_fase1.gd -- docs/capturas/comparativa_vfx/godot_agua/fase1 [todo | quieta | vuelo | carga | pared | suelo | fin | rebote | secuencia]
## Usa el LabVfxComparativa3D con el elemento «agua» (tecla Z) y saca: bola quieta y en vuelo (cámara juego, cercana y horizontal), casteo (5 fotogramas + soltar), salpicadura en pared y suelo a
## 0,05 / 0,15 / 0,3 / 0,6 s, fin, rebote, la secuencia del ciclo G a 12 fps y la hoja_resumen con la referencia de Pablo encima.

const TAM: Vector2i = Vector2i(1280, 720)
const CELDA: int = 320
const REF: String = "res://docs/capturas/comparativa_vfx/referencia_agua/ref_agua_bola_ola_pilar_a.png"

var _dir: String = "docs/capturas/comparativa_vfx/godot_agua/fase1"
var _lab: Node3D = null
var _hojas: Dictionary = {}            ## nombre de hoja -> Array[Image]


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
	if que in ["todo", "quieta"]:
		await _quieta()
	if que in ["todo", "vuelo"]:
		await _vuelo()
	if que in ["todo", "carga"]:
		await _carga()
	if que in ["todo", "pared"]:
		await _pared()
	if que in ["todo", "suelo"]:
		await _suelo()
	if que in ["todo", "fin"]:
		await _fin()
	if que in ["todo", "rebote"]:
		await _rebote()
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


## Guarda el fotograma (cuadrado central) y lo añade a la hoja `hoja`.
func _cap(hoja: String, nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var lado: int = mini(img.get_width(), img.get_height())
	var cuadro: Image = img.get_region(Rect2i((img.get_width() - lado) / 2, 0, lado, lado))
	cuadro.save_png(_dir.path_join("frames").path_join(nombre + ".png"))
	if not _hojas.has(hoja):
		_hojas[hoja] = []
	(_hojas[hoja] as Array).append(cuadro)
	print("captura " + nombre)


func _guardar_hoja(hoja: String, celda: int = CELDA) -> void:
	if not _hojas.has(hoja):
		return
	var ims: Array = _hojas[hoja]
	var h: Image = Image.create_empty(celda * ims.size(), celda, false, Image.FORMAT_RGB8)
	for i in ims.size():
		var im: Image = (ims[i] as Image).duplicate()
		im.convert(Image.FORMAT_RGB8)
		im.resize(celda, celda, Image.INTERPOLATE_LANCZOS)
		h.blit_rect(im, Rect2i(0, 0, celda, celda), Vector2i(i * celda, 0))
	h.save_png(_dir.path_join(hoja + ".png"))


func _hoja_resumen() -> void:
	var filas: Array = []
	for n in ["bola_quieta_vuelo", "carga_secuencia", "soltar", "ciclo_impacto", "impacto_pared", "impacto_suelo", "impacto_suelo_juego", "fin", "rebote"]:
		if _hojas.has(n):
			filas.append(n)
	for n in filas:
		_guardar_hoja(n)
	if filas.is_empty():
		return
	var ancho: int = 0
	for n in filas:
		ancho = maxi(ancho, (_hojas[n] as Array).size())
	var w: int = CELDA * ancho
	var ref: Image = load(REF).get_image() if ResourceLoader.exists(REF) else null
	var alto_ref: int = 0
	if ref != null:
		ref.convert(Image.FORMAT_RGB8)
		alto_ref = int(round(float(ref.get_height()) * float(w) / float(ref.get_width())))
		ref.resize(w, alto_ref, Image.INTERPOLATE_LANCZOS)
	var h: Image = Image.create_empty(w, alto_ref + CELDA * filas.size(), false, Image.FORMAT_RGB8)
	h.fill(Color(0.08, 0.08, 0.1))
	if ref != null:
		h.blit_rect(ref, Rect2i(0, 0, w, alto_ref), Vector2i(0, 0))
	for r in filas.size():
		var ims: Array = _hojas[filas[r]]
		for i in ims.size():
			var im: Image = (ims[i] as Image).duplicate()
			im.convert(Image.FORMAT_RGB8)
			im.resize(CELDA, CELDA, Image.INTERPOLATE_LANCZOS)
			h.blit_rect(im, Rect2i(0, 0, CELDA, CELDA), Vector2i(i * CELDA, alto_ref + r * CELDA))
	h.save_png(_dir.path_join("hoja_resumen.png"))


func _mano() -> Vector3:
	return (_lab.get("_pj") as Node3D).global_position + Vector3(0, 0.7, 0) + Vector3(0, 0, -1) * 0.5


# ------------------------------------------------------------------ bola quieta y en vuelo ------------------------------------------------------------------

func _quieta() -> void:
	var e: Node3D = _lab.call("fuego_param", 0)
	await _seg(0.9)
	var p: Vector3 = e.global_position
	# cámara del juego (ortográfica, 30°)
	_lab.set("camara_fija", {})
	_lab.call("poner_camara", 0)
	await _seg(0.4)
	_still("bola_quieta_juego")
	_cap("bola_quieta_vuelo", "quieta_juego")
	# cercana (3/4 desde arriba) y horizontal
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


## La bola vuela en bucle (V) por delante de la jugadora; la cámara la sigue.
func _vuelo() -> void:
	var e: Node3D = _lab.call("fuego_param", 0)
	_lab.call("viaja_param")
	await _seg(0.5)
	# cámara del juego
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


# ------------------------------------------------------------------ casteo, suelta y ciclo ------------------------------------------------------------------

func _carga() -> void:
	var mano: Vector3 = _mano()
	_cam(mano + Vector3(1.5, 0.5, 3.0), mano + Vector3(0, -0.3, 0.2))
	await _seg(0.4)
	var e: Node3D = _lab.call("carga_completa")
	var t0: int = Time.get_ticks_msec()
	for t in [0.12, 0.45, 0.8, 1.15, 1.55]:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < t:
			await process_frame
		_cap("carga_secuencia", "carga_%03d" % int(t * 1000.0))
	while is_instance_valid(e) and not e.proyectil:
		await process_frame
	var ts: int = Time.get_ticks_msec()
	for t in [0.03, 0.10, 0.22]:
		while float(Time.get_ticks_msec() - ts) / 1000.0 < t:
			await process_frame
		_cap("soltar", "soltar_%03d" % int(t * 1000.0))
	var imp: Node3D = null
	while imp == null:
		await process_frame
		for h in _lab.get_node("Efectos").get_children():
			if h is ImpactoAguaToy:
				imp = h
	var punto: Vector3 = imp.global_position
	_cam(punto + Vector3(2.6, 1.3, 2.4), punto + Vector3(0, 0.25, 0.3))
	for t in [0.05, 0.15, 0.30, 0.60]:
		while is_instance_valid(imp) and imp.tiempo() < t:
			await process_frame
		_cap("ciclo_impacto", "ciclo_%03d" % int(t * 1000.0))
	await _limpiar()


func _pared() -> void:
	var imp: Node3D = _lab.call("impacto_pared")
	var punto: Vector3 = imp.global_position
	_cam(punto + Vector3(2.6, 1.3, 2.4), punto + Vector3(0, 0.25, 0.3))
	for t in [0.05, 0.15, 0.30, 0.60]:
		while is_instance_valid(imp) and imp.tiempo() < t:
			await process_frame
		_cap("impacto_pared", "pared_%03d" % int(t * 1000.0))
	await _limpiar()


func _suelo() -> void:
	var imp: Node3D = _lab.call("impacto_suelo")
	var punto: Vector3 = imp.global_position
	_cam(punto + Vector3(2.4, 1.2, 2.4), punto + Vector3(0, 0.3, 0))
	for t in [0.05, 0.15, 0.30, 0.60]:
		while is_instance_valid(imp) and imp.tiempo() < t:
			await process_frame
		_cap("impacto_suelo", "suelo_%03d" % int(t * 1000.0))
	await _limpiar()
	_lab.set("camara_fija", {})
	_lab.call("poner_camara", 0)
	var imp2: Node3D = _lab.call("impacto_suelo")
	imp2.global_position = _lab.get("_pj").global_position + Vector3(0, 0, -1.8)
	for t in [0.05, 0.15, 0.30, 0.60]:
		while is_instance_valid(imp2) and imp2.tiempo() < t:
			await process_frame
		_cap("impacto_suelo_juego", "suelo_juego_%03d" % int(t * 1000.0))
	_lab.call("poner_camara", 1)
	await _limpiar()


func _fin() -> void:
	var e: Node3D = _lab.call("lanzar_proyectil", "fin")
	var pie: Vector3 = _lab.get("_pj").global_position
	var fin_pos: Vector3 = pie + Vector3(0, 0.7, -0.5) + Vector3(0, 0, -3.5)
	_cam(fin_pos + Vector3(2.4, 0.6, 2.2), fin_pos)
	while is_instance_valid(e) and int(e.get("_est")) != AguaToy.EstadoCarga.APAGANDO:
		await process_frame
	var t0: int = Time.get_ticks_msec()
	for t in [0.05, 0.2, 0.4, 0.7]:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < t:
			await process_frame
		_cap("fin", "fin_%03d" % int(t * 1000.0))
	await _limpiar()


func _rebote() -> void:
	var e: Node3D = _lab.call("lanzar_proyectil", "rebote")
	var pie: Vector3 = _lab.get("_pj").global_position
	var punto: Vector3 = pie + Vector3(0, 0.7, -6.0)
	_cam(punto + Vector3(2.6, 1.0, 2.6), punto + Vector3(0, 0.0, 0.5))
	var imp: Node3D = null
	while imp == null:
		await process_frame
		for h in _lab.get_node("Efectos").get_children():
			if h is ImpactoAguaToy:
				imp = h
	for t in [0.04, 0.12, 0.25, 0.45]:
		while is_instance_valid(imp) and imp.tiempo() < t:
			await process_frame
		_cap("rebote", "rebote_%03d" % int(t * 1000.0))
	await _limpiar()


## El ciclo G entero (carga, suelta, vuelo, impacto) con una cámara fija de lado, a 12 fps durante ~3 s.
func _secuencia() -> void:
	var mano: Vector3 = _mano()
	_cam(mano + Vector3(6.2, 1.4, -2.8), mano + Vector3(0, -0.1, -2.8))
	await _seg(0.4)
	DirAccess.make_dir_recursive_absolute(_dir.path_join("ciclo12"))
	_lab.call("carga_completa")
	var t0: int = Time.get_ticks_msec()
	var k: int = 0
	var celdas: Array = []
	while k < 40:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < float(k) / 12.0:
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png(_dir.path_join("ciclo12").path_join("c_%02d.png" % k))
		celdas.append(img)
		k += 1
	var cols: int = 8
	var cw: int = 240
	var chh: int = 135
	var filas: int = int(ceil(float(celdas.size()) / float(cols)))
	var h: Image = Image.create_empty(cw * cols, chh * filas, false, Image.FORMAT_RGB8)
	for i in celdas.size():
		var im: Image = (celdas[i] as Image).duplicate()
		im.convert(Image.FORMAT_RGB8)
		im.resize(cw, chh, Image.INTERPOLATE_LANCZOS)
		h.blit_rect(im, Rect2i(0, 0, cw, chh), Vector2i((i % cols) * cw, (i / cols) * chh))
	h.save_png(_dir.path_join("secuencia_ciclo_12fps.png"))
	await _limpiar()
