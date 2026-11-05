extends SceneTree
## Poses del dragón con el modelo de Meshy (reposo · aviso · fuego · apagado), de lado y de tres cuartos, para ver que la malla se dobla sin romperse. NECESITA VENTANA:
##   godot --path . --resolution 900x900 --script res://herramientas/captura_dragon_poses.gd -- <salida.png>

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var mundo := Node3D.new()
	root.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-45, 35, 0)
	mundo.add_child(sol)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.82, 0.84, 0.86)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.55)
	mundo.add_child(env)
	var d := TrampaDragon3D.new()
	d.preparar(Vector2i(0, 0), "s", "fuego", 5)
	d.position = Vector3.ZERO
	d.rotation = Vector3.ZERO
	mundo.add_child(d)
	d.set_physics_process(false)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.0
	mundo.add_child(cam)
	var poses: Array = [["reposo", TrampaDragon3D.Fase.REPOSO, 0.15, 0.05], ["aviso", TrampaDragon3D.Fase.AVISO, 0.0, 0.5], ["fuego", TrampaDragon3D.Fase.FUEGO, 1.0, 0.8], ["apagado", TrampaDragon3D.Fase.APAGADA, 0.05, 0.0]]
	var fotos: Array = []
	for vista in [Vector3(4.0, 1.2, 0.8), Vector3(2.6, 2.2, 3.4)]:
		for p in poses:
			d.set_physics_process(false)
			d.fase = int(p[1])
			d._animar(0.0, true)
			d._ext = float(p[2])
			d._mand = float(p[3])
			d._animar(0.0, false)
			cam.look_at_from_position(vista, Vector3(0.0, 1.1, 0.7))
			for i in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			var img: Image = root.get_viewport().get_texture().get_image()
			img.resize(400, 400)
			fotos.append(img)
			print("pose ", p[0], " cuello ", d._esq.get_bone_pose_rotation(1).get_euler(), " cabeza ", d._esq.get_bone_pose_rotation(2).get_euler(), " glob cab ", d._esq.get_bone_global_pose(2).origin)
	var tira: Image = Image.create(400 * 4, 400 * 2, false, (fotos[0] as Image).get_format())
	for i in fotos.size():
		tira.blit_rect(fotos[i], Rect2i(0, 0, 400, 400), Vector2i((i % 4) * 400, (i / 4) * 400))
	tira.save_png(a[0])
	quit()
