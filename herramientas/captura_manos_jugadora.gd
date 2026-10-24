extends SceneTree
## Primeros planos de las MANOS de jugadora_base (con ventana): cámara en perspectiva cerca de la mano derecha, en idle y andando al 30 % y al 70 %, y la
## figura entera de frente andando. Uso: godot --path . --script <este> -- <carpeta> [sin_relajar]

const RESOLUCION: Vector2i = Vector2i(900, 900)
var _carpeta: String = ""
var _cam: Camera3D = null


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_carpeta = a[0]
	DirAccess.make_dir_recursive_absolute(_carpeta)
	if a.size() > 1 and a[1] == "sin_relajar":
		Pj3D.MANO_RELAJADA.clear()
	root.size = RESOLUCION
	var raiz := Node3D.new()
	root.add_child(raiz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.81, 0.91, 0.94)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 0.9)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 35, 0)
	sol.light_energy = 1.1
	raiz.add_child(sol)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	raiz.add_child(_cam)
	_cam.current = true
	var pj := Pj3D.new()
	raiz.add_child(pj)
	pj.cargar("jugadora_base")
	pj.set_alto(1.0)
	for i in 10:
		await process_frame
	if pj._arbol != null:
		pj._arbol.active = false
	var sk: Skeleton3D = pj._modelo.find_children("*", "Skeleton3D", true, false)[0]
	var mano: int = sk.find_bone("mixamorig_RightHand")
	for caso in [["idle", 0.5], ["walk", 0.3], ["walk", 0.7]]:
		var clip: String = pj.clip_de(String(caso[0]))
		pj._ap.active = true
		pj._ap.play(clip)
		pj._ap.seek(pj._ap.get_animation(clip).length * float(caso[1]), true)
		for i in 3:
			await process_frame
		# cámara a 0,45 u de la mano, mirando desde delante-derecha y un poco arriba
		var p: Vector3 = sk.global_transform * sk.get_bone_global_pose(mano).origin
		var cadera: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_Hips")).origin
		var fuera: Vector3 = (p - cadera) * Vector3(1, 0, 1)
		fuera = fuera.normalized() if fuera.length() > 0.01 else Vector3.LEFT
		for lado in [["delante", Vector3.BACK], ["detras", Vector3.FORWARD]]:
			var desde: Vector3 = p + fuera * 0.22 + (lado[1] as Vector3) * 0.30 + Vector3.UP * 0.10
			_cam.transform = Transform3D(Basis.looking_at(p - desde, Vector3.UP), desde)
			await _foto("mano_%s_%d_%s.png" % [caso[0], int(float(caso[1]) * 100.0), lado[0]])
		# figura entera de frente
		_cam.transform = Transform3D(Basis.looking_at(Vector3(0, -0.15, -1), Vector3.UP), Vector3(0, 0.75, 2.6))
		await _foto("figura_%s_%d.png" % [caso[0], int(float(caso[1]) * 100.0)])
	quit(0)


func _foto(nombre: String) -> void:
	for i in 3:
		await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(_carpeta + "/" + nombre)
	print("captura " + nombre)

