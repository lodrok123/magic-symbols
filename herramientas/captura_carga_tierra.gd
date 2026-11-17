extends SceneTree

## TIRA DE LA CARGA DE LA ROCA DE TIERRA (18/11/2026): para MIRAR si las piedrecitas que forman la roca SALEN del anillo de piedras del suelo y suben a ella (Pablo), y no nacen en el
## aire alrededor de la mano. Cámara del juego, la carga completa del lab (tecla G): un PNG con INSTANTES fotogramas de la carga.
## Necesita ventana (sin --headless). No es una prueba:
##   godot --path . --script res://herramientas/captura_carga_tierra.gd -- docs/capturas/carga_tierra_2026-11-18/despues [elemento]

const TAM: Vector2i = Vector2i(1000, 720)
const CELDA: Vector2i = Vector2i(520, 460)
const COLS: int = 3
const INSTANTES: Array = [0.15, 0.3, 0.45, 0.6, 0.8, 1.0]

var _dir: String = "docs/capturas/carga_tierra_2026-11-18/despues"


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
	lab.call("poner_elemento", a[1] if a.size() > 1 else "tierra")
	lab.call("poner_camara", 0)
	var cam: Camera3D = lab.get("_cam") as Camera3D
	await create_timer(0.8).timeout
	cam.size = 4.5
	lab.call("carga_completa")                                     # calentamiento: compila los shaders
	await create_timer(3.5).timeout
	cam.size = 4.5
	lab.call("carga_completa")
	var t0: int = Time.get_ticks_msec()
	var fotos: Array = []
	for t in INSTANTES:
		await process_frame
		while float(Time.get_ticks_msec() - t0) / 1000.0 < float(t):
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		fotos.append(img.get_region(Rect2i((TAM.x - CELDA.x) / 2, (TAM.y - CELDA.y) / 2, CELDA.x, CELDA.y)))
	var filas: int = int(ceil(float(fotos.size()) / float(COLS)))
	var lienzo: Image = Image.create(COLS * CELDA.x, filas * CELDA.y, false, Image.FORMAT_RGBA8)
	lienzo.fill(Color(0, 0, 0, 1))
	for i in fotos.size():
		var im: Image = fotos[i]
		im.convert(Image.FORMAT_RGBA8)
		lienzo.blit_rect(im, Rect2i(0, 0, CELDA.x, CELDA.y), Vector2i((i % COLS) * CELDA.x, (i / COLS) * CELDA.y))
	lienzo.save_png(_dir.path_join("tira_carga.png"))
	print("CAPTURAS en " + _dir)
	quit()
