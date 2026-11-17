extends SceneTree

## HOJA DE LOS HACES CONTRA EL DUMMY (19/11/2026): para MIRAR, elemento por elemento, si el haz del lab se corta en el dummy de estados, qué impacto deja y en qué estado queda.
## Cámara del juego. Una celda por elemento, tomada `T_FOTO` s después de lanzar. Necesita ventana (sin --headless). No es una prueba:
##   godot --path . --script res://herramientas/captura_haces_dummy.gd -- docs/capturas/lab_dummy_2026-11-18/haces

const TAM: Vector2i = Vector2i(1000, 720)
const CELDA: Vector2i = Vector2i(620, 520)
const COLS: int = 4
const ELEMENTOS: Array = ["fuego", "agua", "hielo", "rayo", "magma", "viento", "tierra"]
const T_FOTO: float = 1.0

var _dir: String = "docs/capturas/lab_dummy_2026-11-18/haces"


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
	lab.call("poner_camara", 0)
	var cam: Camera3D = lab.get("_cam") as Camera3D
	for i in 4:
		var cubo: Node3D = lab.get_node_or_null("Cubo%d" % i) as Node3D
		if cubo != null:
			cubo.visible = false
	await create_timer(0.8).timeout
	var dummy: Node = lab.call("dummy_estados")
	var fotos: Array = []
	for el in ELEMENTOS:
		lab.call("poner_elemento", el)
		dummy.call("limpiar")
		cam.size = 6.0
		lab.call("fuego_param", 4)                                 # calentamiento del elemento (compila sus shaders)
		await create_timer(1.6).timeout
		dummy.call("limpiar")
		await create_timer(1.6).timeout                            # que se vaya el efecto de congelado o los arcos del calentamiento
		cam.size = 6.0
		lab.call("fuego_param", 4)
		await create_timer(T_FOTO).timeout
		var img: Image = root.get_viewport().get_texture().get_image()
		fotos.append(img.get_region(Rect2i((TAM.x - CELDA.x) / 2, (TAM.y - CELDA.y) / 2 - 60, CELDA.x, CELDA.y)))
		print("%s: %s" % [el, String(dummy.call("texto")).replace("\n", " | ")])
	var filas: int = int(ceil(float(fotos.size()) / float(COLS)))
	var lienzo: Image = Image.create(COLS * CELDA.x, filas * CELDA.y, false, Image.FORMAT_RGBA8)
	lienzo.fill(Color(0, 0, 0, 1))
	for i in fotos.size():
		var im: Image = fotos[i]
		im.convert(Image.FORMAT_RGBA8)
		lienzo.blit_rect(im, Rect2i(0, 0, CELDA.x, CELDA.y), Vector2i((i % COLS) * CELDA.x, (i / COLS) * CELDA.y))
	lienzo.save_png(_dir.path_join("hoja_haces.png"))
	print("CAPTURAS en " + _dir)
	quit()
