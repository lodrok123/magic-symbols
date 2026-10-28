extends SceneTree
## Fotos del rig del chaman (goblin_chaman_rig.glb, salida de tools/autorig_chaman.py): reposo y 6 poses de prueba, cada una en una hoja de tres vistas (frente, tres cuartos, lado).
## NECESITA VENTANA:
##   Godot --path . --resolution 1280x720 --script res://herramientas/captura_rig_chaman.gd [-- esqueleto]
## Salida en res://docs/capturas/chaman_rig/: rig_<pose>.png. Con `-- esqueleto` dibuja los huesos encima (rig_<pose>_huesos.png).

const DIR: String = "res://docs/capturas/chaman_rig"
const GLB: String = "res://arte/modelos/goblin_chaman_rig.glb"
const POSES: Dictionary = {
	"reposo": {},
	"brazos_arriba": {"LeftArm": Vector3(-150, 0, 0), "RightArm": Vector3(-150, 0, 0), "LeftForeArm": Vector3(-15, 0, 0), "RightForeArm": Vector3(-15, 0, 0)},
	"brazos_lados": {"LeftArm": Vector3(0, 0, -60), "RightArm": Vector3(0, 0, 60)},
	"zancada": {"LeftUpLeg": Vector3(-40, 0, 0), "LeftLeg": Vector3(35, 0, 0), "RightUpLeg": Vector3(30, 0, 0), "RightLeg": Vector3(8, 0, 0), "_hips": Vector3(0, -0.03, 0)},
	"sentadilla": {"LeftUpLeg": Vector3(-85, 0, 8), "RightUpLeg": Vector3(-85, 0, -8), "LeftLeg": Vector3(110, 0, 0), "RightLeg": Vector3(110, 0, 0),
		"LeftFoot": Vector3(-25, 0, 0), "RightFoot": Vector3(-25, 0, 0), "Spine": Vector3(15, 0, 0), "_hips": Vector3(0, -0.13, 0)},
	"giro_cintura": {"Spine1": Vector3(0, 20, 0), "Spine2": Vector3(0, 20, 0), "Spine": Vector3(8, 20, 0)},
	"cabeza_lados": {"Head": Vector3(0, 40, 0), "Neck": Vector3(0, 15, 8)},
	"inclinado_codos": {"Spine": Vector3(20, 0, 0), "Spine1": Vector3(12, 0, 0), "LeftArm": Vector3(-70, 0, 0), "RightArm": Vector3(-70, 0, 0),
		"LeftForeArm": Vector3(-50, 0, 0), "RightForeArm": Vector3(-50, 0, 0)},
}
var _cam: Camera3D = null
var _esqueleto: bool = false
var _lineas: MeshInstance3D = null


func _initialize() -> void:
	await process_frame
	_esqueleto = OS.get_cmdline_user_args().has("esqueleto")
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
	print("huesos: ", sk.get_bone_count())
	var ctx := AnimacionesGolem._Ctx.new(sk, "")
	if _esqueleto:
		_lineas = MeshInstance3D.new()
		root.add_child(_lineas)
	await process_frame
	for nombre in POSES:
		var pose: Dictionary = POSES[nombre]
		var r: Array = ctx.fk(pose, pose.get("_hips", Vector3.ZERO))
		var lq: Array[Quaternion] = r[2]
		for i in sk.get_bone_count():
			sk.set_bone_pose_rotation(i, lq[i])
		sk.set_bone_pose_position(sk.find_bone("mixamorig_Hips"), sk.get_bone_rest(sk.find_bone("mixamorig_Hips")).origin + (pose.get("_hips", Vector3.ZERO) as Vector3))
		if _lineas != null:
			_dibujar_huesos(sk)
		await _hoja(nombre)
	quit(0)


func _dibujar_huesos(sk: Skeleton3D) -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in sk.get_bone_count():
		var p: int = sk.get_bone_parent(i)
		if p < 0:
			continue
		var a: Vector3 = sk.global_transform * sk.get_bone_global_pose(p).origin
		var b: Vector3 = sk.global_transform * sk.get_bone_global_pose(i).origin
		im.surface_set_color(Color(1, 0.1, 0.1))
		im.surface_add_vertex(a)
		im.surface_set_color(Color(1, 1, 0.1))
		im.surface_add_vertex(b)
	im.surface_end()
	_lineas.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	_lineas.material_override = m


func _hoja(nombre: String) -> void:
	var foco := Vector3(0, 0.48, 0)
	var hoja := Image.create_empty(1920, 720, false, Image.FORMAT_RGB8)
	var vistas: Array = [Vector3(0, 0.05, 1.0), Vector3(0.7, 0.15, 0.7), Vector3(1.0, 0.05, 0.0)]
	for k in vistas.size():
		_cam.look_at_from_position(foco + (vistas[k] as Vector3).normalized() * 3.0, foco)
		for i in 4:
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		hoja.blit_rect(img, Rect2i(320, 0, 640, 720), Vector2i(640 * k, 0))
	hoja.save_png(DIR.path_join("rig_%s%s.png" % [nombre, "_huesos" if _esqueleto else ""]))
	print("hoja " + nombre)


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
