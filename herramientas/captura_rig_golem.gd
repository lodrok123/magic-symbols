extends SceneTree
## Fotos del gólem riggeado (golem_piedra_rig.glb) con el núcleo colgado de Spine2. NECESITA VENTANA:
##   Godot --path . --resolution 1280x720 --script res://herramientas/captura_rig_golem.gd
## Salida en res://docs/capturas/golem/: rig_reposo, rig_brazos_arriba, rig_andar (clip Walking del goblin guerrero retargeteado con ClipsFamilia, si traduce).

const DIR: String = "res://docs/capturas/golem"
const ALTO_JUEGO: float = 1.7
const ALTO_CUERPO: float = 0.704346
const HUECO_CENTRO: Vector3 = Vector3(-0.006, 0.429, 0.09)    ## en el modelo, en reposo (ver informe)
const NUCLEO_ESCALA: float = 0.85 * 2.0 * 0.053 / 0.259
var _cam: Camera3D = null


func _initialize() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(DIR)
	_entorno()
	_cam = Camera3D.new()
	_cam.near = 0.05
	_cam.far = 100.0
	_cam.fov = 24.0
	root.add_child(_cam)
	var k: float = ALTO_JUEGO / ALTO_CUERPO
	var modelo: Node3D = (load("res://arte/modelos/golem_piedra_rig.glb") as PackedScene).instantiate()
	modelo.scale = Vector3.ONE * k
	root.add_child(modelo)
	var sk: Skeleton3D = modelo.find_children("*", "Skeleton3D", true, false)[0]
	# Núcleo colgado de Spine2: su transformación local es la del hueso en reposo invertida por la del hueco.
	var ba := BoneAttachment3D.new()
	ba.bone_name = "mixamorig_Spine2"
	sk.add_child(ba)
	var nu: Node3D = (load("res://arte/modelos/nucleo_golem.glb") as PackedScene).instantiate()
	ba.add_child(nu)
	var h: int = sk.find_bone("mixamorig_Spine2")
	var rest: Transform3D = sk.get_bone_global_rest(h)
	nu.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * NUCLEO_ESCALA), HUECO_CENTRO)
	await process_frame
	var foco := Vector3(0, ALTO_JUEGO * 0.5, 0)
	_cam.look_at_from_position(foco + Vector3(0.3, 0.15, 1.0).normalized() * 6.5, foco)
	await _foto("rig_reposo")
	_giro(sk, "mixamorig_RightArm", Basis(Vector3.RIGHT, deg_to_rad(-120.0)))
	_giro(sk, "mixamorig_LeftArm", Basis(Vector3.RIGHT, deg_to_rad(-120.0)))
	await _foto("rig_brazos_arriba")
	_giro(sk, "mixamorig_RightArm", Basis.IDENTITY)
	_giro(sk, "mixamorig_LeftArm", Basis.IDENTITY)
	_giro(sk, "mixamorig_RightUpLeg", Basis(Vector3.RIGHT, deg_to_rad(-35.0)))
	_giro(sk, "mixamorig_RightLeg", Basis(Vector3.RIGHT, deg_to_rad(60.0)))
	_giro(sk, "mixamorig_LeftArm", Basis(Vector3.RIGHT, deg_to_rad(-30.0)))
	_giro(sk, "mixamorig_RightArm", Basis(Vector3.RIGHT, deg_to_rad(30.0)))
	await _foto("rig_andar")
	quit(0)


func _giro(sk: Skeleton3D, nombre: String, r: Basis) -> void:
	var b: int = sk.find_bone(nombre)
	var p: int = sk.get_bone_parent(b)
	var pg: Basis = sk.get_bone_global_pose(p).basis if p >= 0 else Basis.IDENTITY
	var deseada: Basis = r * sk.get_bone_global_rest(b).basis
	sk.set_bone_pose_rotation(b, (pg.inverse() * deseada).get_rotation_quaternion())


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
	pl.size = Vector2(20, 20)
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
