extends SceneTree

## CAPTURAS CON VENTANA de la carga y el impacto del fuego «toy», 2.ª versión con las texturas de Le Lu (rama fuego-toy-carga-impacto). Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_carga_impacto_lelu.gd -- docs/capturas/comparativa_vfx/godot_toy/carga_impacto_lelu [todo | carga | impactos | fin | rebote | juego]
## Saca, en el LabVfxComparativa3D, los fotogramas sueltos en <carpeta>/frames/ y las hojas: carga_secuencia, soltar, impacto_pared_A/B, impacto_suelo_A/B, impacto_suelo_juego_A/B,
## carga_juego, fin_sin_choque, rebote y hoja_resumen. Los instantes del impacto se leen de ImpactoFuegoToy.tiempo() (exactos al fotograma).

const TAM: Vector2i = Vector2i(1280, 720)
const CELDA: int = 320
const T_IMPACTO: Array = [0.05, 0.15, 0.30, 0.60]

var _dir: String = "docs/capturas/comparativa_vfx/godot_toy/carga_impacto_lelu"
var _lab: Node3D = null
var _hojas: Dictionary = {}            ## nombre de hoja -> Array[Image]
var _orden: Array = []


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
	_lab.call("poner_camara", 1)
	await _seg(0.6)
	if que in ["todo", "carga"]:
		await _carga()
	if que in ["todo", "impactos"]:
		for est in [ImpactoFuegoToy.Estilo.A, ImpactoFuegoToy.Estilo.B]:
			ImpactoFuegoToy.estilo = est
			await _impacto_pared()
			await _impacto_suelo()
	if que in ["todo", "juego"]:
		for est in [ImpactoFuegoToy.Estilo.A, ImpactoFuegoToy.Estilo.B]:
			ImpactoFuegoToy.estilo = est
			await _impacto_juego()
		await _carga_juego()
	if que in ["todo", "fin"]:
		await _fin()
	if que in ["todo", "rebote"]:
		for est in [ImpactoFuegoToy.Estilo.A, ImpactoFuegoToy.Estilo.B]:
			ImpactoFuegoToy.estilo = est
			await _rebote()
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


func _suf() -> String:
	return "A" if ImpactoFuegoToy.estilo == ImpactoFuegoToy.Estilo.A else "B"


## Guarda el fotograma (cuadrado central) y lo añade a la hoja `hoja`.
func _cap(hoja: String, nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var lado: int = mini(img.get_width(), img.get_height())
	var cuadro: Image = img.get_region(Rect2i((img.get_width() - lado) / 2, 0, lado, lado))
	cuadro.save_png(_dir.path_join("frames").path_join(nombre + ".png"))
	if not _hojas.has(hoja):
		_hojas[hoja] = []
		_orden.append(hoja)
	(_hojas[hoja] as Array).append(cuadro)
	print("captura " + nombre)


func _fila(ims: Array, y: int, h: Image) -> void:
	for i in ims.size():
		var im: Image = (ims[i] as Image).duplicate()
		im.convert(Image.FORMAT_RGB8)
		im.resize(CELDA, CELDA, Image.INTERPOLATE_LANCZOS)
		h.blit_rect(im, Rect2i(0, 0, CELDA, CELDA), Vector2i(i * CELDA, y))


func _hoja_resumen() -> void:
	if _orden.is_empty():
		return
	var ancho: int = 0
	for n in _orden:
		ancho = maxi(ancho, (_hojas[n] as Array).size())
		var uno: Image = Image.create_empty(CELDA * (_hojas[n] as Array).size(), CELDA, false, Image.FORMAT_RGB8)
		_fila(_hojas[n], 0, uno)
		uno.save_png(_dir.path_join(String(n) + ".png"))
	var h: Image = Image.create_empty(CELDA * ancho, CELDA * _orden.size(), false, Image.FORMAT_RGB8)
	h.fill(Color(0.08, 0.08, 0.1))
	for r in _orden.size():
		_fila(_hojas[_orden[r]], r * CELDA, h)
	h.save_png(_dir.path_join("hoja_resumen.png"))


# ------------------------------------------------------------------ carga, suelta, vuelo y estallido ------------------------------------------------------------------

func _carga() -> void:
	var pie: Vector3 = _lab.get("_pj").global_position
	var mano: Vector3 = pie + Vector3(0, 0.7, 0) + Vector3(0, 0, -1) * 0.5
	_cam(mano + Vector3(1.1, 0.35, 2.4), mano + Vector3(0, 0.05, 0))
	await _seg(0.4)
	var e: FuegoToy = _lab.call("carga_completa")
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
	var imp: ImpactoFuegoToy = null
	while imp == null:
		await process_frame
		for h in _lab.get_node("Efectos").get_children():
			if h is ImpactoFuegoToy:
				imp = h
	var punto: Vector3 = imp.global_position
	_cam(punto + Vector3(2.6, 1.3, 2.4), punto + Vector3(0, 0.25, 0.3))
	for t in T_IMPACTO:
		while is_instance_valid(imp) and imp.tiempo() < t:
			await process_frame
		_cap("ciclo_impacto", "ciclo_%03d" % int(t * 1000.0))
	await _limpiar()


func _impacto_pared() -> void:
	var imp: ImpactoFuegoToy = _lab.call("impacto_pared")
	var punto: Vector3 = imp.global_position
	_cam(punto + Vector3(2.6, 1.3, 2.4), punto + Vector3(0, 0.25, 0.3))
	await process_frame
	for t in T_IMPACTO:
		while is_instance_valid(imp) and imp.tiempo() < t:
			await process_frame
		_cap("impacto_pared_" + _suf(), "pared_%s_%03d" % [_suf(), int(t * 1000.0)])
	await _limpiar()


func _impacto_suelo() -> void:
	var imp: ImpactoFuegoToy = _lab.call("impacto_suelo")
	var punto: Vector3 = imp.global_position
	_cam(punto + Vector3(2.4, 1.2, 2.4), punto + Vector3(0, 0.3, 0))
	await process_frame
	for t in T_IMPACTO:
		while is_instance_valid(imp) and imp.tiempo() < t:
			await process_frame
		_cap("impacto_suelo_" + _suf(), "suelo_%s_%03d" % [_suf(), int(t * 1000.0)])
	await _limpiar()


## Con la cámara del juego (ortográfica, 30°), a 1,8 m de la jugadora.
func _impacto_juego() -> void:
	_lab.set("camara_fija", {})
	_lab.call("poner_camara", 0)
	var imp2: ImpactoFuegoToy = _lab.call("impacto_suelo")
	imp2.global_position = _lab.get("_pj").global_position + Vector3(0, 0, -1.8)
	await process_frame
	for t in T_IMPACTO:
		while is_instance_valid(imp2) and imp2.tiempo() < t:
			await process_frame
		_cap("impacto_suelo_juego_" + _suf(), "suelo_juego_%s_%03d" % [_suf(), int(t * 1000.0)])
	_lab.call("poner_camara", 1)
	await _limpiar()


func _carga_juego() -> void:
	_lab.set("camara_fija", {})
	_lab.call("poner_camara", 0)
	await _seg(0.4)
	var e: FuegoToy = _lab.call("carga_completa")
	var t0: int = Time.get_ticks_msec()
	for t in [0.15, 0.5, 0.85, 1.2, 1.6]:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < t:
			await process_frame
		_cap("carga_juego", "carga_juego_%03d" % int(t * 1000.0))
	_lab.call("poner_camara", 1)
	await _limpiar()


func _fin() -> void:
	var e: FuegoToy = _lab.call("lanzar_proyectil", "fin")
	var pie: Vector3 = _lab.get("_pj").global_position
	var fin_pos: Vector3 = pie + Vector3(0, 0.7, -0.5) + Vector3(0, 0, -3.5)
	_cam(fin_pos + Vector3(2.4, 0.6, 2.2), fin_pos + Vector3(0, 0.0, 0))
	while is_instance_valid(e) and int(e.get("_est")) != FuegoToy.EstadoCarga.APAGANDO:
		await process_frame
	var t0: int = Time.get_ticks_msec()
	for t in [0.05, 0.2, 0.4, 0.7]:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < t:
			await process_frame
		_cap("fin_sin_choque", "fin_%03d" % int(t * 1000.0))
	await _limpiar()


func _rebote() -> void:
	var e: FuegoToy = _lab.call("lanzar_proyectil", "rebote")
	var pie: Vector3 = _lab.get("_pj").global_position
	var punto: Vector3 = pie + Vector3(0, 0.7, -6.0)
	_cam(punto + Vector3(2.6, 1.0, 2.6), punto + Vector3(0, 0.0, 0.5))
	var imp: ImpactoFuegoToy = null
	while imp == null:
		await process_frame
		for h in _lab.get_node("Efectos").get_children():
			if h is ImpactoFuegoToy:
				imp = h
	for t in [0.04, 0.12, 0.25, 0.45]:
		while is_instance_valid(imp) and imp.tiempo() < t:
			await process_frame
		_cap("rebote_" + _suf(), "rebote_%s_%03d" % [_suf(), int(t * 1000.0)])
	await _limpiar()
