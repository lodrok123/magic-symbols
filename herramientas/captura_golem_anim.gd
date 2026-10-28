extends SceneTree
## Fotogramas clave de las animaciones del gólem (con el núcleo colgado de Spine2) y una tira con la cámara del juego. NECESITA VENTANA:
##   Godot --path . --resolution 1280x720 --script res://herramientas/captura_golem_anim.gd
## Salida en res://docs/capturas/golem/: anim_<rol>_<n>.png (2-3 por animación) y tira_juego.png.
## Con el argumento `lado` hace solo las del golpe DE LADO (anim_attack_<n>_lado.png).

var DIR: String = "res://docs/capturas/golem"
var LADO: bool = false
const K: float = 1.7 / 0.704346
const HUECO_CENTRO: Vector3 = Vector3(-0.006, 0.429, 0.09)
const NUCLEO_ESCALA: float = 0.85 * 2.0 * 0.053 / 0.259
## rol -> tiempos (s) de los fotogramas
const FOTOS: Dictionary = {
	"idle": [0.0, 0.75],
	"walk": [0.0, 0.4, 0.8],
	"attack": [0.25, 1.15, 1.45, 2.1],
	"expuesto": [0.7, 1.45, 3.0, 4.6],
	"resbalar": [0.45, 1.0, 2.0],
	"levantarse": [0.0, 1.7, 3.0],
	"hit": [0.1, 0.3],
	"death": [0.45, 1.3, 2.6],
}
var _cam: Camera3D
var _clips: Dictionary = {}


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "lado":
		LADO = true
	DirAccess.make_dir_recursive_absolute(DIR)
	_entorno()
	_cam = Camera3D.new()
	_cam.near = 0.05
	_cam.far = 100.0
	_cam.fov = 26.0
	root.add_child(_cam)
	var g: Array = _golem(Vector3.ZERO)
	var ap: AnimationPlayer = g[1]
	for rol in FOTOS:
		if LADO and rol != "attack":
			continue
		var n: int = 0
		for t in FOTOS[rol]:
			n += 1
			_pose(g, rol, float(t))
			var foco := Vector3(0.0, 1.0, 0.0)
			_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			_cam.look_at_from_position(foco + (Vector3(1.0, 0.25, 0.0) if LADO else Vector3(0.15 if rol == "attack" else 0.9, 0.3, 1.0)).normalized() * 9.0, foco)
			await _foto("anim_%s_%d%s" % [rol, n, "_lado" if LADO else ""])
	if LADO:
		quit(0)
		return
	# Tira con la cámara del juego: ortogonal a 60°, una fila de gólems en distintos momentos.
	g[0].queue_free()
	var fila: Array = [["idle", 0.75], ["walk", 0.4], ["attack", 1.3], ["attack", 1.5], ["expuesto", 3.0], ["resbalar", 0.7], ["resbalar", 2.0], ["death", 2.6]]
	for i in fila.size():
		var gi: Array = _golem(Vector3((float(i) - 3.5) * 2.4, 0.0, 0.0))
		_pose(gi, fila[i][0], float(fila[i][1]))
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 11.5
	var e: float = deg_to_rad(90.0 - 60.0)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3(0, 0.8, 0) - dir * 40.0)
	await _foto("tira_juego")
	quit(0)


func _golem(pos: Vector3) -> Array:
	var modelo: Node3D = (load("res://arte/modelos/golem_piedra_rig.glb") as PackedScene).instantiate()
	modelo.scale = Vector3.ONE * K
	modelo.position = pos
	root.add_child(modelo)
	var sk: Skeleton3D = modelo.find_children("*", "Skeleton3D", true, false)[0]
	var prefijo: String = String(modelo.get_path_to(sk)) + ":"
	if _clips.is_empty():
		_clips = AnimacionesGolem.construir(sk, prefijo)
	var ap := AnimationPlayer.new()
	modelo.add_child(ap)
	ap.root_node = NodePath("..")
	var lib := AnimationLibrary.new()
	for k in _clips:
		lib.add_animation(k, (_clips[k] as Animation).duplicate())
	ap.add_animation_library("", lib)
	var ba := BoneAttachment3D.new()
	ba.bone_name = "mixamorig_Spine2"
	sk.add_child(ba)
	var nu: Node3D = (load("res://arte/modelos/nucleo_golem.glb") as PackedScene).instantiate()
	ba.add_child(nu)
	var rest: Transform3D = sk.get_bone_global_rest(sk.find_bone("mixamorig_Spine2"))
	nu.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * NUCLEO_ESCALA), HUECO_CENTRO)
	return [modelo, ap, sk]


func _pose(g: Array, rol: String, t: float) -> void:
	var ap: AnimationPlayer = g[1]
	ap.play(rol)
	ap.seek(t, true)
	ap.pause()
	(g[2] as Skeleton3D).force_update_all_bone_transforms()


func _entorno() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.47, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 0.9
	sol.rotation_degrees = Vector3(-40.0, -25.0, 0.0)
	root.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(40, 20)
	suelo.mesh = pl
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.3, 0.32, 0.36)
	suelo.material_override = mt
	root.add_child(suelo)


func _foto(nombre: String) -> void:
	for i in 5:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(DIR.path_join(nombre + ".png"))
	print("foto " + nombre)
