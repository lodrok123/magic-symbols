extends SceneTree

## TIRA DEL CONGELADO (CongeladoToy, 18/11/2026): para MIRAR la costra de hielo, los cuadraditos celestes y el vaho sobre un cuerpo. Cámara del juego, acercada; la jugadora del lab
## (tecla Supr). Necesita ventana (sin --headless). No es una prueba:
##   godot --path . --script res://herramientas/captura_congelado.gd -- docs/capturas/hielo_2026-11-18/congelado

const TAM: Vector2i = Vector2i(1000, 720)
const CELDA: Vector2i = Vector2i(420, 520)
const COLS: int = 5
const DURA: float = 1.6
const INSTANTES: Array = [0.1, 0.3, 0.9, 1.5, 1.95]

var _dir: String = "docs/capturas/hielo_2026-11-18/congelado"


func _initialize() -> void:
	_correr()


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
	cam.size = 3.2
	lab.call("congelado_demo", 0.6)                                # calentamiento: compila los shaders
	await create_timer(2.6).timeout
	cam.size = 3.2
	lab.call("congelado_demo", DURA)
	var t0: int = Time.get_ticks_msec()
	var fotos: Array = []
	for t in INSTANTES:
		await process_frame
		while float(Time.get_ticks_msec() - t0) / 1000.0 < float(t):
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		fotos.append(img.get_region(Rect2i((TAM.x - CELDA.x) / 2, (TAM.y - CELDA.y) / 2, CELDA.x, CELDA.y)))
	var lienzo: Image = Image.create(COLS * CELDA.x, CELDA.y, false, Image.FORMAT_RGBA8)
	lienzo.fill(Color(0, 0, 0, 1))
	for i in fotos.size():
		var im: Image = fotos[i]
		im.convert(Image.FORMAT_RGBA8)
		lienzo.blit_rect(im, Rect2i(0, 0, CELDA.x, CELDA.y), Vector2i(i * CELDA.x, 0))
	lienzo.save_png(_dir.path_join("tira_congelado.png"))
	print("CAPTURAS en " + _dir)
	quit()
