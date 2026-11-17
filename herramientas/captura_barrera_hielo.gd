extends SceneTree

## TIRA DE LA BARRERA DE HIELO (19/11/2026): para MIRAR la barrera sin la cúpula (solo la jaula de cristales y la escarcha), cómo nace y cómo se rompe. Cámara del juego;
## la barrera de F7 del lab (figura 3). Necesita ventana (sin --headless). No es una prueba:
##   godot --path . --script res://herramientas/captura_barrera_hielo.gd -- docs/capturas/hielo_2026-11-18/barrera_sin_cupula

const TAM: Vector2i = Vector2i(1000, 720)
const CELDA: Vector2i = Vector2i(760, 460)
const COLS: int = 2
const T_VIVE: Array = [0.3, 0.6, 1.0, 1.6]
const T_MUERE: Array = [0.3, 0.7]

var _dir: String = "docs/capturas/hielo_2026-11-18/barrera_sin_cupula"


func _initialize() -> void:
	_correr()


func _foto(fotos: Array, t0: int, t: float) -> void:
	await process_frame
	while float(Time.get_ticks_msec() - t0) / 1000.0 < t:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	fotos.append(img.get_region(Rect2i((TAM.x - CELDA.x) / 2, (TAM.y - CELDA.y) / 2, CELDA.x, CELDA.y)))


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = TAM
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	lab.set("_panel_visible", false)
	lab.call("poner_elemento", "hielo")
	lab.call("poner_camara", 0)
	var cam: Camera3D = lab.get("_cam") as Camera3D
	for i in 4:
		var cubo: Node3D = lab.get_node_or_null("Cubo%d" % i) as Node3D
		if cubo != null:
			cubo.visible = false
	await create_timer(0.8).timeout
	cam.size = 6.0
	var e: Node3D = lab.call("fuego_param", 3)                     # calentamiento
	await create_timer(1.6).timeout
	cam.size = 6.0
	e = lab.call("fuego_param", 3)
	e.call("lanzar", -1.0)
	var fotos: Array = []
	var t0: int = Time.get_ticks_msec()
	for t in T_VIVE:
		await _foto(fotos, t0, float(t))
	e.call("morir")
	t0 = Time.get_ticks_msec()
	for t in T_MUERE:
		await _foto(fotos, t0, float(t))
	var filas: int = int(ceil(float(fotos.size()) / float(COLS)))
	var lienzo: Image = Image.create(COLS * CELDA.x, filas * CELDA.y, false, Image.FORMAT_RGBA8)
	lienzo.fill(Color(0, 0, 0, 1))
	for i in fotos.size():
		var im: Image = fotos[i]
		im.convert(Image.FORMAT_RGBA8)
		lienzo.blit_rect(im, Rect2i(0, 0, CELDA.x, CELDA.y), Vector2i((i % COLS) * CELDA.x, (i / COLS) * CELDA.y))
	lienzo.save_png(_dir.path_join("tira_barrera.png"))
	print("CAPTURAS en " + _dir)
	quit()
