extends SceneTree

## TIRAS DEL INICIO Y EL FINAL DE LA BOLA, LA BARRERA Y LA LÍNEA DE TIERRA (21/11/2026): para MIRAR cómo nace y cómo se va cada figura con la cámara del juego (ortogonal, 30° sobre el suelo).
## Un PNG por figura con los fotogramas (dos de inicio, activo y final) en <carpeta>/tira_<figura>.png. Necesita ventana (sin --headless). No es una prueba:
##   godot --path . --script res://herramientas/captura_tierra_inicio_final.gd -- <carpeta> [apagado]
## Con «apagado» fuerza los tres interruptores a false (la tierra de antes) para comparar.

const TAM: Vector2i = Vector2i(1000, 720)
const CELDA: Vector2i = Vector2i(520, 460)
## [figura (índice de FIGURAS_PARAM del lab), nombre, instantes del inicio (s desde lanzar), instante activo, segundos del final tras morir, desplazamiento del recorte (px)]
const TOMAS: Array = [[0, "bola", [0.12, 0.3], 0.9, 0.1, Vector2i(0, -190)], [3, "barrera", [0.35, 0.8], 2.2, 0.5, Vector2i(0, 0)], [4, "haz", [0.25, 0.45], 1.8, 0.5, Vector2i(0, -110)]]

var _dir: String = ""


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	_dir = a[0] if a.size() > 0 else "docs/capturas/tierra_inicio_final_2026-11-21"
	if a.size() > 1 and a[1] == "apagado":
		TierraToy.prueba_apagar = true
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = TAM
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	lab.set("_panel_visible", false)
	lab.call("poner_elemento", "tierra")
	lab.call("poner_camara", 0)
	await create_timer(0.8).timeout
	for toma in TOMAS:                                                           # calentamiento: compila los shaders de todo
		var w: Node3D = lab.call("fuego_param", int(toma[0]))
		await create_timer(1.0).timeout
		w.call("morir")
		await create_timer(1.6).timeout
	for toma in TOMAS:
		var e: Node3D = lab.call("fuego_param", int(toma[0]))
		var t0: int = Time.get_ticks_msec()
		var fotos: Array = []
		var off: Vector2i = toma[5]
		for ti in toma[2]:
			await _hasta(t0, float(ti))
			fotos.append(_foto(off))
		await _hasta(t0, float(toma[3]))
		fotos.append(_foto(off))
		if int(toma[0]) == 0:
			e.call("impactar_en", e.global_position, Vector3.UP)
		else:
			e.call("morir")
		var t1: int = Time.get_ticks_msec()
		await _hasta(t1, float(toma[4]))
		fotos.append(_foto(off))
		var lienzo: Image = Image.create(fotos.size() * CELDA.x, CELDA.y, false, Image.FORMAT_RGBA8)
		for i in fotos.size():
			var im: Image = fotos[i]
			im.convert(Image.FORMAT_RGBA8)
			lienzo.blit_rect(im, Rect2i(0, 0, CELDA.x, CELDA.y), Vector2i(i * CELDA.x, 0))
		lienzo.save_png(_dir.path_join("tira_%s.png" % str(toma[1])))
		await create_timer(2.5).timeout
	print("CAPTURAS en " + _dir)
	quit()


func _hasta(t0: int, seg: float) -> void:
	await process_frame
	while float(Time.get_ticks_msec() - t0) / 1000.0 < seg:
		await process_frame


func _foto(off: Vector2i) -> Image:
	var img: Image = root.get_viewport().get_texture().get_image()
	return img.get_region(Rect2i((TAM.x - CELDA.x) / 2 + off.x, maxi((TAM.y - CELDA.y) / 2 + off.y, 0), CELDA.x, CELDA.y))
