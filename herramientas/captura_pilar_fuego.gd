extends SceneTree

## TIRA TEMPORAL DEL PILAR DE FUEGO (17/11/2026): para MIRAR si el pilar se lee como UNA lengua (un chorro estrecho abajo que se abre y se deshace arriba; referencia: vídeo de Pablo
## de cuatro chorros de fuego) y no como un cilindro de lenguas. Misma tira que captura_pilar_agua.gd: cámara del juego, dos tamaños, NACER (4), VIVIR (2) y MORIR (5).
## Necesita ventana (sin --headless). No es una prueba; las capturas van en docs/capturas, que tiene .gdignore (no genera .import):
##   godot --path . --script res://herramientas/captura_pilar_fuego.gd -- docs/capturas/pilar_fuego_2026-11-17/antes

const TAM: Vector2i = Vector2i(1000, 720)
const COLS: int = 6
## nombre, semiejes, tamaño de la vista ortogonal (m de alto), altura a la que se sube el foco (m), recorte central de cada fotograma (px)
const TAMANOS: Array = [
	["ref_0.5x4x0.5", Vector3(0.5, 4.0, 0.5), 6.0, 1.0, Vector2i(300, 700)],
	["bajo_ancho_1.3x1.6x1.3", Vector3(1.3, 1.6, 1.3), 8.0, 0.2, Vector2i(700, 600)],
]
## instantes (s desde lanzar) de nacer y vivir, y (s desde morir) de morir
const T_NACER: Array = [0.1, 0.22, 0.38, 0.6]
const T_VIVIR: Array = [1.4, 2.0]
const T_MORIR: Array = [0.15, 0.4, 0.7, 1.0, 1.45]

var _dir: String = "docs/capturas/pilar_fuego_2026-11-17/despues"
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
	_lab.call("poner_elemento", "fuego")
	_lab.call("poner_camara", 0)                                   # la del juego: ortogonal, inclinada 60°
	for i in 4:
		var cubo: Node3D = _lab.get_node_or_null("Cubo%d" % i) as Node3D
		if cubo != null:
			cubo.visible = false
	var pj: Node3D = _lab.get("_pj") as Node3D
	pj.visible = false                                             # la jugadora no tapa el pilar; el foco de la cámara sigue siendo ella
	await _seg(0.8)
	await _una("calentamiento", TAMANOS[0][1], TAMANOS[0][2], TAMANOS[0][3], TAMANOS[0][4], false)     # compila los shaders: sin esto el primer «nacer» sale a los 0,5 s
	for t in TAMANOS:
		await _una(t[0], t[1], t[2], t[3], t[4])
	print("CAPTURAS en " + _dir)
	quit()


func _seg(s: float) -> void:
	await create_timer(s).timeout


## Reloj del motor (con time_scale): lo que el juego ha vivido, no los milisegundos de pared.
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


func _una(nombre: String, s: Vector3, tam_vista: float, sube: float, celda: Vector2i, guardar: bool = true) -> void:
	var pj: Node3D = _lab.get("_pj") as Node3D
	var cam: Camera3D = _lab.get("_cam") as Camera3D
	var base: Vector3 = pj.global_position
	pj.global_position = Vector3(base.x, sube, base.z)
	await process_frame
	cam.size = tam_vista
	var e: Node3D = _lab.call("_nuevo_toy")
	e.definir(2, s.x, s.y, s.z, false)                             # Figura.PILAR
	(_lab.get("_efectos") as Node3D).add_child(e)
	e.global_position = Vector3(pj.global_position.x, 0.0, pj.global_position.z)
	_lab.set("ultimo_efecto", null)
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
	for t in T_MORIR:
		await _foto(fotos, tiempos, "morir", t0, t, celda)
	if guardar:
		_tira(nombre, fotos, tiempos, celda)
	await _seg(2.0)
	if is_instance_valid(e):
		e.queue_free()
	pj.global_position = base
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
