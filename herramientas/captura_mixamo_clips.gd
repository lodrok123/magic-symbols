extends SceneTree
## FOTOS de los clips de Mixamo traducidos a jugadora_base (compañera de prueba_mixamo_clips.gd): por clip, una hoja con el 10/50/90 % del clip, cada instante de frente
## y de lado, con la jugadora vestida como en el juego y la postura final (ProporcionChibi, capa...). NECESITA VENTANA:
##   tools/Godot_v4.7.2-stable_win64.exe --path . --resolution 1280x720 --script res://herramientas/captura_mixamo_clips.gd [-- <glb_de_clips>]
## Salida en res://docs/capturas/mixamo_prueba/<clip>.png.

const DIR: String = "res://docs/capturas/mixamo_prueba"
const GLB_CLIPS: String = "res://arte/meshy/mixamo_clips.glb"
const ID_DESTINO: String = "jugadora_base"
const FRACS: Array = [0.1, 0.5, 0.9]
const ALTO: float = 1.0
var _cam: Camera3D = null


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var ruta: String = args[0] if args.size() > 0 else GLB_CLIPS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_entorno()
	_cam = Camera3D.new()
	_cam.near = 0.05
	_cam.far = 100.0
	_cam.fov = 30.0
	root.add_child(_cam)
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(ruta), estado) != OK:
		push_error("no se pudo leer " + ruta)
		quit(1)
		return
	var fuente: Node3D = doc.generate_scene(estado) as Node3D
	root.add_child(fuente)
	fuente.visible = false
	var sk_s: Skeleton3D = fuente.find_children("*", "Skeleton3D", true, false)[0]
	var ap_s: AnimationPlayer = fuente.find_children("*", "AnimationPlayer", true, false)[0]
	var pj := Pj3D.new()
	root.add_child(pj)
	pj.cargar(ID_DESTINO)
	pj.set_alto(ALTO)
	for i in 3:
		await process_frame
	var sk_d: Skeleton3D = pj.find_children("*", "Skeleton3D", true, false)[0]
	if pj._arbol != null:
		pj._arbol.active = false
	var ap_d: AnimationPlayer = pj._ap
	ap_d.active = true
	var c := ClipsFamilia._Ctx.new()
	c.preparar(fuente, sk_s, pj._modelo, sk_d, ClipsFamilia.alinear_de(ID_DESTINO))
	var lib: AnimationLibrary = ap_d.get_animation_library("")
	var prefijo: String = String(pj._modelo.get_path_to(sk_d)) + ":"
	for nombre in ap_s.get_animation_list():
		var an_d: Animation = (c.traducir(ap_s.get_animation(nombre), prefijo) as Array)[0]
		lib.add_animation("mx_" + String(nombre), an_d)
		var hoja := Image.create_empty(640 * FRACS.size(), 720 * 2, false, Image.FORMAT_RGB8)
		for k in FRACS.size():
			ap_d.play("mx_" + String(nombre))
			ap_d.seek(an_d.length * float(FRACS[k]), true)
			ap_d.pause()
			var vistas: Array = [Vector3(0, 0.15, 1.0), Vector3(1.0, 0.15, 0.0)]
			for v in vistas.size():
				for i in 2:
					await process_frame
				# La cámara sigue a la cadera (la voltereta y el nado avanzan): foco a media altura bajo la cadera, en su vertical.
				var cadera: Vector3 = sk_d.global_transform * sk_d.get_bone_global_pose(sk_d.find_bone("mixamorig_Hips")).origin
				var foco := Vector3(cadera.x, 0.5, cadera.z)
				_cam.look_at_from_position(foco + (vistas[v] as Vector3).normalized() * 3.2, foco)
				for i in 4:
					await process_frame
				var img: Image = root.get_viewport().get_texture().get_image()
				hoja.blit_rect(img, Rect2i(320, 0, 640, 720), Vector2i(640 * k, 720 * v))
		hoja.save_png(ProjectSettings.globalize_path(DIR.path_join("%s.png" % nombre)))
		print("hoja ", nombre)
	quit(0)


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
