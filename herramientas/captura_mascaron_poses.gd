extends SceneTree
## Poses de la boca del mascarón con el modelo de Meshy (cerrada · aprieta · abierta · disparo · cerrando · rebote), de frente y de lado, para ver que la quijada se abre sin romper la malla. NECESITA VENTANA:
##   godot --path . --resolution 900x900 --script res://herramientas/captura_mascaron_poses.gd -- <salida.png>

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var mundo := Node3D.new()
	root.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-45, 25, 0)
	mundo.add_child(sol)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.82, 0.84, 0.86)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.55)
	mundo.add_child(env)
	var f := TrampaFlechas3D.new()
	f.preparar(Vector2i(0, 0), "s", "fuego", 6)
	f.preparar_ciclo(2.0, 0.0, 3.5)
	f.position = Vector3.ZERO
	f.rotation = Vector3.ZERO
	mundo.add_child(f)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.0
	mundo.add_child(cam)
	await process_frame
	f.set_physics_process(false)
	f.disparos = 1
	# [nombre, t desde el último disparo]
	var poses: Array = [["cerrada", 1.0], ["aprieta", 2.0 - 0.33], ["abierta", 2.0 - 0.03], ["disparo", 0.05], ["cerrando", 0.12], ["rebote", 0.25]]
	var fotos: Array = []
	for vista in [Vector3(0.0, 1.0, 4.0), Vector3(3.2, 1.2, 2.2)]:
		for p in poses:
			f._t = float(p[1])
			f._pintar(1.0 if String(p[0]) in ["aprieta", "abierta"] else 0.0)
			f._poner_boca(f.pose_boca(f._t))
			cam.look_at_from_position(vista, Vector3(0.0, 0.85, 0.2))
			for i in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			var img: Image = root.get_viewport().get_texture().get_image()
			img.resize(360, 360)
			fotos.append(img)
			print("pose %s %.1f°" % [p[0], f.angulo_boca])
	var tira: Image = Image.create(360 * 6, 360 * 2, false, (fotos[0] as Image).get_format())
	for i in fotos.size():
		tira.blit_rect(fotos[i], Rect2i(0, 0, 360, 360), Vector2i((i % 6) * 360, (i / 6) * 360))
	tira.save_png(a[0])
	quit()
