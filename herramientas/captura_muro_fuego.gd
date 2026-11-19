extends SceneTree

## TIRA TEMPORAL DEL MURO DE FUEGO (17/11/2026): para MIRAR si se lee como una cortina de fuego densa y gruesa, con lenguas de alturas distintas en la cresta (referencia: vídeo de Pablo
## de muros de fuego entre columnas), y no como una banda fina. Misma tira que captura_muro_agua.gd (cámara del juego, mismos tamaños e instantes).
## Necesita ventana (sin --headless). No es una prueba; las capturas van en docs/capturas (tiene .gdignore, no genera .import):
##   godot --path . --script res://herramientas/captura_muro_fuego.gd -- docs/capturas/muro_fuego_2026-11-17/despues

const TAM: Vector2i = Vector2i(1000, 720)
const COLS: int = 6
## nombre, semiejes, vista del juego (tamaño ortogonal), vista de perfil (tamaño ortogonal), recorte (px) del juego y del perfil
const TAMANOS: Array = [
	["ref_3.45x1.5x0.3", Vector3(3.45, 1.5, 0.3), 9.0, 5.0],
	["alto_1.6x2.4x0.3", Vector3(1.6, 2.4, 0.3), 6.0, 6.0],
]
const T_NACER: Array = [0.15, 0.3, 0.6]
const T_VIVIR: Array = [1.2, 1.7]
const T_ROMPER: Array = [0.15, 0.4, 0.7, 1.0, 1.4, 1.8]

var _dir: String = "docs/capturas/muro_fuego_2026-11-17/despues"
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
	await _una("calentamiento", Vector3(1, 1, 0.3), "juego", 6.0, false)
	for t in TAMANOS:
		await _una(t[0] + "_juego", t[1], "juego", t[2], true)
		await _una(t[0] + "_perfil", t[1], "perfil", t[3], true)
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


func _una(nombre: String, s: Vector3, vista: String, tam_vista: float, guardar: bool) -> void:
	var pj: Node3D = _lab.get("_pj") as Node3D
	var cam: Camera3D = _lab.get("_cam") as Camera3D
	var e: Node3D = _lab.call("_nuevo_toy")
	e.definir(1, s.x, s.y, s.z, false)                             # Figura.MURO
	(_lab.get("_efectos") as Node3D).add_child(e)
	var pie: Vector3 = Vector3(pj.global_position.x, 0.0, pj.global_position.z)
	e.global_position = pie
	var celda: Vector2i
	if vista == "juego":
		_lab.call("poner_camara", 0)
		pj.global_position = Vector3(pie.x, 0.5, pie.z - 0.8)         # el foco de la cámara del juego, un poco por delante del muro
		celda = Vector2i(900, 560)
	else:
		_lab.call("poner_camara", 1)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_lab.set("camara_fija", {"desde": pie + Vector3(20.0, s.y * 0.5, -s.y * 0.7), "mira": pie + Vector3(0.0, s.y * 0.5, -s.y * 0.7)})
		celda = Vector2i(700, 520)
	await process_frame
	cam.size = tam_vista
	e.lanzar(-1.0)
	var fotos: Array = []
	var tiempos: Array = []
	var t0: int = Time.get_ticks_msec()
	for t in T_NACER:
		await _foto(fotos, tiempos, "nacer", t0, t, celda)
	for t in T_VIVIR:
		await _foto(fotos, tiempos, "vive", t0, t, celda)
	e.morir()
	t0 = Time.get_ticks_msec()
	for t in T_ROMPER:
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
