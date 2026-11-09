extends SceneTree
## El fantasma elfo (fantasma_elfo_rig.glb) ANIMADO con los clips de la elfa (chibi_elf.glb) traducidos por ClipsFamilia.
## Es la prueba que de verdad importa: el rig no se juzga con poses inventadas, sino con el andar y los conjuros que va a usar en el juego.
## NECESITA VENTANA:
##   Godot --path . --resolution 1280x720 --script res://herramientas/captura_clips_fantasma.gd
## Salida en res://docs/capturas/fantasma_rig/: clip_<nombre>.png, una hoja de cuatro instantes del ciclo (frente) por clip.

## Sin argumentos usa el fantasma; con `-- <id>` usa res://arte/modelos/<id>.glb y guarda en res://docs/capturas/<id>/.
const ID_POR_DEFECTO: String = "fantasma_elfo_rig"
const FUENTE: String = "res://arte/modelos/chibi_elf.glb"
var _id: String = ID_POR_DEFECTO
var DIR: String = ""
var GLB: String = ""
const CLIPS: Array[String] = ["Walking", "Running", "Idle", "MageSoellCast001", "Dead"]
## Fracciones del clip que se fotografían (un ciclo de paso se lee bien en cuartos).
const INSTANTES: Array[float] = [0.0, 0.25, 0.5, 0.75]
var _cam: Camera3D = null


func _initialize() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_id = args[0] if args.size() > 0 and args[0] != "" else ID_POR_DEFECTO
	GLB = "res://arte/modelos/%s.glb" % _id
	DIR = "res://docs/capturas/%s" % _id
	if not ResourceLoader.exists(GLB):
		push_error("no existe " + GLB)
		quit(1)
		return
	print("modelo: ", GLB)
	DirAccess.make_dir_recursive_absolute(DIR)
	_entorno()
	_cam = Camera3D.new()
	_cam.near = 0.05
	_cam.far = 100.0
	_cam.fov = 24.0
	root.add_child(_cam)
	var modelo: Node3D = (load(GLB) as PackedScene).instantiate()
	root.add_child(modelo)
	var sk: Skeleton3D = modelo.find_children("*", "Skeleton3D", true, false)[0]
	var ap := AnimationPlayer.new()
	modelo.add_child(ap)
	var lib := AnimationLibrary.new()
	var puestos: Array[String] = []
	for c in CLIPS:
		var an: Animation = ClipsFamilia.traducir_clip(_id, FUENTE, c, modelo, sk)
		if an == null:
			print("NO se pudo traducir: ", c)
			continue
		lib.add_animation(c, an)
		puestos.append(c)
	ap.add_animation_library("", lib)
	print("clips traducidos: ", puestos)
	if puestos.is_empty():
		quit(1)
		return
	await process_frame
	for c in puestos:
		await _hoja(ap, sk, c)
	quit(0)


func _hoja(ap: AnimationPlayer, sk: Skeleton3D, clip: String) -> void:
	var an: Animation = ap.get_animation(clip)
	var largo: float = an.length
	var foco := Vector3(0, 0.48, 0)
	var hoja := Image.create_empty(2560, 720, false, Image.FORMAT_RGB8)
	# dos vistas por instante no caben: se usa frente para el ciclo y se confía en las hojas de poses para el lado
	_cam.look_at_from_position(foco + Vector3(0.35, 0.08, 1.0).normalized() * 3.0, foco)
	for k in INSTANTES.size():
		var t: float = largo * INSTANTES[k]
		ap.play(clip)
		ap.seek(t, true)
		ap.pause()
		for i in 3:
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		hoja.blit_rect(img, Rect2i(320, 0, 640, 720), Vector2i(640 * k, 0))
	hoja.save_png(DIR.path_join("clip_%s.png" % clip))
	print("hoja ", clip, "  (", String.num(largo, 2), " s)")


func _entorno() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.47, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 0.9
	sol.rotation_degrees = Vector3(-40.0, -25.0, 0.0)
	root.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(20, 20)
	suelo.mesh = pl
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.3, 0.32, 0.36)
	suelo.material_override = mt
	root.add_child(suelo)
