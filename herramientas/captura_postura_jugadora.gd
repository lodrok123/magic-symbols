extends SceneTree
## CAPTURAS DE LA POSTURA de `jugadora_base` (vestida, como en el juego) con la CÁMARA DEL JUEGO (ortogonal, picado 30° bajo la horizontal, tamaño 6:
## la de PruebaTest2._colocar_camara, igual que herramientas/captura_capa_juego.gd). Los clips se REPRODUCEN (la capa cae con sus muelles). NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_postura_jugadora.gd -- <prefijo> [<carpeta>]
## Escribe en <carpeta> (por omisión docs/capturas/jugadora_base) `postura_<prefijo>_<toma>.png` y su recorte ampliado `_cerca`: idle y walk de lado y de frente,
## run (50 %) y cast_proyectil (50 %) de tres cuartos, y `recolectable`: quieta (idle) de lado junto a unas setas, que es lo que suena junto a algo que se
## puede coger (Recolectable3D solo pide `agacharse` al pulsar E; Jugador3D._animar pide idle si no te mueves).

const ALTO_JUEGO: float = 1.0
const CAMARA_PICADO: float = 30.0
const FOCO_ALTO: float = 0.85
const CAMARA_TAM: float = 6.0
const RESOLUCION: Vector2i = Vector2i(1280, 720)
const RECORTE: Vector2i = Vector2i(220, 240)
const AMPLIA: int = 3
const ASENTAR_S: float = 1.0
const PIEZA_RECOLECTABLE: String = "res://arte/piezas/setas_rojas.tscn"
const RECOLECTABLE_DIST: float = 0.55      ## u por delante de ella
## [nombre de la toma, rol, fracción del clip, giro del personaje en grados]
const TOMAS: Array = [
	["idle_lado", "idle", 0.5, 90.0], ["idle_frente", "idle", 0.5, 0.0],
	["walk_lado", "walk", 0.5, 90.0], ["walk_frente", "walk", 0.5, 0.0],
	["run", "run", 0.5, 40.0], ["cast", "cast_proyectil", 0.5, 40.0],
]

var _carpeta: String = ""
var _prefijo: String = ""
var _cam: Camera3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	_prefijo = a[0] if a.size() > 0 else "antes"
	_carpeta = a[1] if a.size() > 1 else "res://docs/capturas/jugadora_base"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_carpeta))
	root.size = RESOLUCION
	var raiz := Node3D.new()
	root.add_child(raiz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.81, 0.91, 0.94)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.82, 0.9)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 35, 0)
	sol.light_energy = 1.1
	sol.shadow_enabled = true
	raiz.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(30, 30)
	suelo.mesh = pl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.55, 0.68, 0.45)
	suelo.material_override = sm
	raiz.add_child(suelo)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = CAMARA_TAM
	raiz.add_child(_cam)
	_cam.current = true
	var dir := Vector3(0.0, -sin(deg_to_rad(CAMARA_PICADO)), -cos(deg_to_rad(CAMARA_PICADO)))
	var foco := Vector3(0, ALTO_JUEGO * FOCO_ALTO, 0)
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 40.0)
	var pj := Pj3D.new()
	raiz.add_child(pj)
	pj.cargar("jugadora_base")
	pj.set_alto(ALTO_JUEGO)
	for i in 10:
		await process_frame
	if pj._arbol != null:
		pj._arbol.active = false
	for t in TOMAS:
		pj.rotation_degrees.y = float(t[3])
		await _clip_hasta(pj, String(t[1]), float(t[2]))
		await _foto("postura_%s_%s.png" % [_prefijo, t[0]])
	# Junto a un recolectable: quieta (idle) de lado, con unas setas delante (el personaje mira a +Z girado 90°, o sea a +X).
	var escena: PackedScene = load(PIEZA_RECOLECTABLE) as PackedScene
	if escena != null:
		var setas: Node3D = escena.instantiate() as Node3D
		raiz.add_child(setas)
		setas.position = Vector3(RECOLECTABLE_DIST, 0.0, 0.0)
	pj.rotation_degrees.y = 90.0
	await _clip_hasta(pj, "idle", 0.5)
	await _foto("postura_%s_recolectable.png" % _prefijo)
	quit(0)


## Reproduce el clip del rol desde el principio (con los muelles en marcha) hasta `fraccion` de su duración; para idle deja antes ASENTAR_S de idle.
func _clip_hasta(pj: Pj3D, rol: String, fraccion: float) -> void:
	var clip: String = pj.clip_de(rol)
	pj._ap.active = true
	if rol == "idle":
		pj._ap.play(clip)
		for i in int(ASENTAR_S * 30.0):
			await process_frame
	pj._ap.play(clip)
	pj._ap.seek(0.0, true)
	var m: CapaMuelles3D = Ropa3D.muelles(pj, "capa")
	if m != null and rol != "idle":
		m.reset()
	var hasta: float = pj._ap.get_animation(clip).length * fraccion
	while pj._ap.current_animation_position < hasta and pj._ap.is_playing():
		await process_frame


func _a_pantalla(p: Vector3) -> Vector2i:
	return Vector2i(_cam.unproject_position(p))


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(_carpeta + "/" + nombre))
	var c: Vector2i = _a_pantalla(Vector3(0, ALTO_JUEGO * 0.5, 0))
	var rec: Image = img.get_region(Rect2i(c - RECORTE / 2, RECORTE))
	rec.resize(RECORTE.x * AMPLIA, RECORTE.y * AMPLIA, Image.INTERPOLATE_LANCZOS)
	rec.save_png(ProjectSettings.globalize_path(_carpeta + "/" + nombre.replace(".png", "_cerca.png")))
	print("captura ", nombre)
