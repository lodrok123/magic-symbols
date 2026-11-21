extends SceneTree

## TIRA TEMPORAL DE LA BARRERA Y DEL HAZ DE FUEGO (21/11/2026): para MIRAR el inicio, el estado activo y el final de cada figura con la cámara del juego y de perfil
## (misma estructura que captura_muro_fuego.gd / captura_pilar_fuego.gd). Necesita ventana (sin --headless). No es una prueba:
##   godot --path . --script res://herramientas/captura_barrera_haz_fuego.gd -- <carpeta de salida>

const TAM: Vector2i = Vector2i(1000, 720)
const COLS: int = 6
## nombre, figura (3 barrera, 4 haz), semiejes, vista del juego (tamaño ortogonal), vista de perfil (tamaño ortogonal), instantes del nacer / vivir / morir
const FIGURAS: Array = [
	["barrera_1.5", 3, Vector3(1.5, 1.5, 1.5), 7.0, 5.0, [0.1, 0.25, 0.4, 0.6, 0.85], [1.2], [0.15, 0.35, 0.55, 0.75, 1.2]],
	["haz_2x0.9x0.3", 4, Vector3(2.0, 0.9, 0.3), 7.0, 6.0, [0.08, 0.16, 0.26, 0.45], [1.0], [0.2, 0.45, 0.7, 0.95, 1.4]],
]

var _dir: String = "docs/capturas/barrera_haz_fuego_2026-11-21"
var _lab: Node3D = null


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
	_lab = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_lab)
	_lab.set("_panel_visible", false)
	_lab.call("poner_elemento", a[1] if a.size() > 1 else "fuego")      # 2.º argumento: otro elemento (p. ej. tierra) con la misma tira
	for i in 4:
		var cubo: Node3D = _lab.get_node_or_null("Cubo%d" % i) as Node3D
		if cubo != null:
			cubo.visible = false
	(_lab.get("_pj") as Node3D).visible = false
	await _seg(0.8)
	await _una("calentamiento", FIGURAS[0], "juego", 6.0, false)
	for t in FIGURAS:
		await _una(t[0] + "_juego", t, "juego", t[3], true)
		await _una(t[0] + "_perfil", t, "perfil", t[4], true)
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


func _foto(fotos: Array, tiempos: Array, rotulo: String, t0: int, t: float, celda: Vector2i) -> void:
	await _hasta(t0, t)
	var img: Image = root.get_viewport().get_texture().get_image()
	fotos.append(img.get_region(Rect2i((TAM.x - celda.x) / 2, (TAM.y - celda.y) / 2, celda.x, celda.y)))
	tiempos.append("%s %.2f" % [rotulo, _sim(t0)])


func _una(nombre: String, fig: Array, vista: String, tam_vista: float, guardar: bool) -> void:
	var s: Vector3 = fig[2]
	var pj: Node3D = _lab.get("_pj") as Node3D
	var cam: Camera3D = _lab.get("_cam") as Camera3D
	var e: Node3D = _lab.call("_nuevo_toy")
	e.definir(int(fig[1]), s.x, s.y, s.z, false)
	(_lab.get("_efectos") as Node3D).add_child(e)
	var pie: Vector3 = Vector3(pj.global_position.x, 0.0, pj.global_position.z)
	e.global_position = pie
	var celda: Vector2i
	if vista == "juego":
		_lab.call("poner_camara", 0)
		pj.global_position = Vector3(pie.x, 0.5, pie.z - (0.8 if int(fig[1]) == 3 else 2.0))         # el foco de la cámara del juego (el haz sale hacia delante: se mira a su mitad)
		celda = Vector2i(900, 560)
	else:
		_lab.call("poner_camara", 1)
		var es_haz: bool = int(fig[1]) == 4
		var mira_y: float = maxf(s.y, 0.4) if es_haz else s.y * 0.5
		var mira_z: float = -s.x if es_haz else -s.y * 0.7
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_lab.set("camara_fija", {"desde": pie + Vector3(20.0, mira_y, mira_z), "mira": pie + Vector3(0.0, mira_y, mira_z)})
		celda = Vector2i(700, 520)
	await process_frame
	cam.size = tam_vista
	e.lanzar(-1.0)
	var fotos: Array = []
	var tiempos: Array = []
	var t0: int = Time.get_ticks_msec()
	for t in fig[5]:
		await _foto(fotos, tiempos, "nacer", t0, t, celda)
	for t in fig[6]:
		await _foto(fotos, tiempos, "vive", t0, t, celda)
	e.morir()
	t0 = Time.get_ticks_msec()
	for t in fig[7]:
		await _foto(fotos, tiempos, "romper", t0, t, celda)
	if guardar:
		_tira(nombre, fotos, tiempos, celda)
	await _seg(2.2)
	if is_instance_valid(e):
		e.queue_free()
	pj.global_position = Vector3(pie.x, 0.0, pie.z)
	_lab.set("camara_fija", {})
	await _seg(0.4)


func _tira(nombre: String, imgs: Array, tiempos: Array, celda: Vector2i) -> void:
	var filas: int = int(ceil(float(imgs.size()) / float(COLS)))
	var lienzo: Image = Image.create(COLS * celda.x, filas * celda.y, false, Image.FORMAT_RGBA8)
	lienzo.fill(Color(0, 0, 0, 1))
	for i in imgs.size():
		var im: Image = imgs[i]
		im.convert(Image.FORMAT_RGBA8)
		lienzo.blit_rect(im, Rect2i(0, 0, celda.x, celda.y), Vector2i((i % COLS) * celda.x, (i / COLS) * celda.y))
	lienzo.save_png(_dir.path_join("tira_" + nombre + ".png"))
	print("tira %s: %s" % [nombre, ", ".join(tiempos)])
