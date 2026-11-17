extends SceneTree

## TIRA DEL GESTO DE CASTEO EN EL LAB DE VFX (19/11/2026): con el gesto activo (Tab) y la CÁMARA LIBRE de lado, lanza cada figura (F7) y saca fotogramas del gesto: hacia el
## instante, en el instante (el efecto nace), sostenido (solo el haz) y de vuelta. Sirve para ver si el fotograma congelado del haz es el del brazo extendido.
## Necesita ventana (sin --headless). No es una prueba:
##   godot --path . --script res://herramientas/captura_lab_gesto.gd -- docs/capturas/lab_gesto_2026-11-19 [elemento]

const TAM: Vector2i = Vector2i(1000, 720)
const CELDA: Vector2i = Vector2i(560, 520)
const FIGURAS: Array = [[0, "bola"], [1, "muro"], [2, "pilar"], [4, "haz"]]
const COLS: int = 5

var _dir: String = "docs/capturas/lab_gesto_2026-11-19"


func _initialize() -> void:
	_correr()


func _foto(fotos: Array, rotulos: Array, rotulo: String) -> void:
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	fotos.append(img.get_region(Rect2i((TAM.x - CELDA.x) / 2, (TAM.y - CELDA.y) / 2 - 40, CELDA.x, CELDA.y)))
	rotulos.append(rotulo)


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
	lab.call("poner_elemento", a[1] if a.size() > 1 else "hielo")
	lab.call("poner_camara", 3)                                    # libre
	lab.set("_orb_yaw", 1.35)                                      # de lado: el brazo se ve de perfil
	lab.set("_orb_pitch", 0.18)
	lab.set("_orb_dist", 4.2)
	lab.set("gesto_activo", true)
	await create_timer(1.0).timeout
	var fotos: Array = []
	var rotulos: Array = []
	for f in FIGURAS:
		lab.call("fuego_param", int(f[0]))
		var vistas: Dictionary = {}
		var t: float = 0.0
		while t < 4.0:
			await process_frame
			t += root.get_process_delta_time()
			var eg: Dictionary = lab.call("estado_gesto")
			var fase: String = String(eg["fase"])
			if fase == "" and vistas.size() > 0:
				break
			if fase != "" and not vistas.has(fase):
				vistas[fase] = true
				if fase == "hacia":
					await create_timer(0.12).timeout
				await _foto(fotos, rotulos, "%s %s %s" % [f[1], eg["id"], fase])
		print("%s: fases vistas %s" % [f[1], str(vistas.keys())])
		await create_timer(0.6).timeout
		lab.call("limpiar")
		await create_timer(0.3).timeout
	var filas: int = int(ceil(float(fotos.size()) / float(COLS)))
	var lienzo: Image = Image.create(COLS * CELDA.x, filas * CELDA.y, false, Image.FORMAT_RGBA8)
	lienzo.fill(Color(0, 0, 0, 1))
	for i in fotos.size():
		var im: Image = fotos[i]
		im.convert(Image.FORMAT_RGBA8)
		lienzo.blit_rect(im, Rect2i(0, 0, CELDA.x, CELDA.y), Vector2i((i % COLS) * CELDA.x, (i / COLS) * CELDA.y))
	lienzo.save_png(_dir.path_join("tira_gesto.png"))
	print("orden: " + " | ".join(PackedStringArray(rotulos)))
	print("CAPTURAS en " + _dir)
	quit()
