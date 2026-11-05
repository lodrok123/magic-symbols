extends SceneTree
## Vistas de un modelo suelto (frente ±X, ±Z, arriba y tres cuartos) para ver hacia dónde mira y cómo es. NECESITA VENTANA:
##   godot --path . --resolution 900x900 --script res://herramientas/captura_modelo_vistas.gd -- <res://modelo.glb> <salida.png>

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var escena: PackedScene = load(a[0])
	var mundo := Node3D.new()
	root.add_child(mundo)
	var m: Node3D = escena.instantiate()
	mundo.add_child(m)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40, 30, 0)
	mundo.add_child(sol)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.85, 0.85, 0.88)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	mundo.add_child(env)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.3
	mundo.add_child(cam)
	var vistas: Array = [["+X", Vector3(3, 0, 0)], ["-X", Vector3(-3, 0, 0)], ["+Z", Vector3(0, 0, 3)], ["-Z", Vector3(0, 0, -3)], ["arriba", Vector3(0, 3, 0.01)], ["3/4", Vector3(2, 1.2, 2)]]
	var fotos: Array = []
	for v in vistas:
		cam.position = v[1]
		cam.look_at(Vector3.ZERO, Vector3.UP if absf((v[1] as Vector3).y) < 2.9 else Vector3.FORWARD)
		for i in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_viewport().get_texture().get_image()
		img.resize(450, 450)
		fotos.append(img)
		print("vista ", v[0])
	var tira: Image = Image.create(450 * 3, 450 * 2, false, (fotos[0] as Image).get_format())
	for i in fotos.size():
		tira.blit_rect(fotos[i], Rect2i(0, 0, 450, 450), Vector2i((i % 3) * 450, (i / 3) * 450))
	tira.save_png(a[1])
	quit()
