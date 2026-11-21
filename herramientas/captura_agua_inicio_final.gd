extends SceneTree

## TIRAS TEMPORALES DEL INICIO Y EL FINAL DEL AGUA (21/11/2026): para MIRAR, con la cámara del juego (ortogonal, inclinada 60°), cómo empiezan y cómo acaban las cinco formas de AguaToy
## (BOLA, MURO, PILAR, BARRERA, HAZ). Por cada forma saca un PNG con una tira: NACER (inicio), VIVIR (activo) y MORIR (final). Las etiquetas llevan el tiempo real de cada fotograma (el reloj es
## el del motor). Necesita ventana (sin --headless). No es una prueba; la salida va donde digas (por defecto docs/capturas/agua_inicio_final_2026-11-21, que tiene .gdignore):
##   godot --path . --script res://herramientas/captura_agua_inicio_final.gd -- ruta/de/salida [bola muro pilar barrera haz]
## (los nombres tras la ruta eligen formas; sin ellos salen las cinco)

const TAM: Vector2i = Vector2i(1000, 720)
const COLS: int = 6
## nombre, figura, semiejes, ¿el nodo a la altura de la mano/centro? (0,7 m sobre el suelo), giro Y (°), tamaño de la vista ortogonal (m de alto), altura del foco (m),
## recorte central de cada fotograma (px), instantes de nacer (s desde lanzar), de vivir y de morir (s desde morir)
const FORMAS: Array = [
	["bola", 0, Vector3(0.4, 0.4, 0.4), true, 0.0, 3.0, -0.4, Vector2i(420, 420), [0.2, 0.42], [1.2], [0.22, 0.34, 0.5, 0.8]],
	["muro", 1, Vector3(3.45, 1.5, 0.3), false, 0.0, 9.0, 0.6, Vector2i(900, 620), [0.15, 0.45, 0.8], [1.8], [0.45, 0.9, 1.5, 2.0, 2.4]],
	["pilar", 2, Vector3(0.5, 4.0, 0.5), false, 0.0, 6.0, 1.0, Vector2i(300, 700), [0.15, 0.4, 0.6], [1.6], [0.5, 1.0, 1.7, 2.0]],
	["barrera", 3, Vector3(1.5, 1.5, 1.5), true, 0.0, 6.0, 0.6, Vector2i(520, 520), [0.2, 0.5, 0.8], [1.6], [0.25, 0.5, 0.75, 0.95]],
	["haz", 4, Vector3(1.5, 0.5, 0.15), false, -90.0, 6.0, 0.5, Vector2i(1000, 400), [0.12, 0.3], [1.2], [0.3, 0.7, 1.1]],
]

var _dir: String = "docs/capturas/agua_inicio_final_2026-11-21"
var _lab: Node3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var cuales: Array = []
	if a.size() > 0:
		_dir = a[0]
	for i in range(1, a.size()):
		cuales.append(a[i])
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = TAM
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_lab = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_lab)
	_lab.set("_panel_visible", false)
	_lab.call("poner_elemento", "agua")
	_lab.call("poner_camara", 0)                                   # la del juego: ortogonal, inclinada 60°
	for i in 4:
		var cubo: Node3D = _lab.get_node_or_null("Cubo%d" % i) as Node3D
		if cubo != null:
			cubo.visible = false
	var pj: Node3D = _lab.get("_pj") as Node3D
	pj.visible = false                                             # la jugadora no tapa; el foco de la cámara sigue siendo ella
	await _seg(0.8)
	await _una(FORMAS[2], false)                                   # calentamiento: compila los shaders (si no, el primer «nacer» sale a los 0,5 s)
	for f in FORMAS:
		if cuales.is_empty() or cuales.has(f[0]):
			await _una(f, true)
	print("CAPTURAS en " + _dir)
	quit()


func _seg(s: float) -> void:
	await create_timer(s).timeout


func _sim(t0: int) -> float:
	return float(Time.get_ticks_msec() - t0) / 1000.0 * Engine.time_scale


func _hasta(t0: int, t: float) -> void:
	await process_frame
	while _sim(t0) < t:
		await process_frame


func _foto(img_lista: Array, tiempos: Array, rotulo: String, t0: int, t: float, celda: Vector2i) -> void:
	await _hasta(t0, t)
	var img: Image = root.get_viewport().get_texture().get_image()
	var r: Rect2i = Rect2i((TAM.x - celda.x) / 2, (TAM.y - celda.y) / 2, celda.x, celda.y)
	img_lista.append(img.get_region(r))
	tiempos.append("%s %.2f" % [rotulo, _sim(t0)])


func _una(f: Array, guardar: bool) -> void:
	var pj: Node3D = _lab.get("_pj") as Node3D
	var cam: Camera3D = _lab.get("_cam") as Camera3D
	var s: Vector3 = f[2]
	var celda: Vector2i = f[7]
	var base: Vector3 = pj.global_position
	pj.global_position = Vector3(base.x, f[6], base.z)
	await process_frame
	cam.size = f[5]
	var e: Node3D = _lab.call("_nuevo_toy")
	e.definir(int(f[1]), s.x, s.y, s.z, false)
	(_lab.get("_efectos") as Node3D).add_child(e)
	e.global_position = Vector3(pj.global_position.x, 0.7 if bool(f[3]) else 0.0, pj.global_position.z)
	e.rotation_degrees.y = float(f[4])
	_lab.set("ultimo_efecto", null)
	cam.size = f[5]
	e.lanzar(-1.0)
	var fotos: Array = []
	var tiempos: Array = []
	var t0: int = Time.get_ticks_msec()
	for t in f[8]:
		await _foto(fotos, tiempos, "nace", t0, t, celda)
	for t in f[9]:
		await _foto(fotos, tiempos, "vive", t0, t, celda)
	e.morir()
	t0 = Time.get_ticks_msec()
	for t in f[10]:
		await _foto(fotos, tiempos, "muere", t0, t, celda)
	if guardar:
		_tira(String(f[0]), fotos, tiempos, celda)
	await _seg(2.5)
	if is_instance_valid(e):
		e.queue_free()
	pj.global_position = base
	await _seg(0.4)


func _tira(nombre: String, imgs: Array, tiempos: Array, celda: Vector2i) -> void:
	var cols: int = clampi(4000 / celda.x, 1, COLS)
	var filas: int = int(ceil(float(imgs.size()) / float(cols)))
	var lienzo: Image = Image.create(cols * celda.x, filas * celda.y, false, Image.FORMAT_RGBA8)
	lienzo.fill(Color(0, 0, 0, 1))
	for i in imgs.size():
		var im: Image = imgs[i]
		im.convert(Image.FORMAT_RGBA8)
		lienzo.blit_rect(im, Rect2i(0, 0, celda.x, celda.y), Vector2i((i % cols) * celda.x, (i / cols) * celda.y))
	lienzo.save_png(_dir.path_join("tira_" + nombre + ".png"))
	print("tira %s: %s" % [nombre, ", ".join(tiempos)])
