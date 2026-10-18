extends SceneTree

## CAPTURA DEL TRONCO-PUENTE (Juego, 16/10): en pie, a mitad de caída y caído, sobre un suelo y un río de mentira. Necesita renderizador:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1000x600 --path . --script res://herramientas/captura_tronco_puente.gd -- <salida_base>

func _init() -> void:
	var base: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/tronco"
	root.size = Vector2i(1000, 600)
	var escena := Node3D.new()
	root.add_child(escena)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	escena.add_child(luz)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.7, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	escena.add_child(env)
	# suelo: dos orillas (verde) y un río (azul) de 2,3 en medio; el tronco en la orilla de la derecha, cae hacia la izquierda (-X)
	for d in [[Vector3(5.0, 0.0, 0.0), Color(0.45, 0.6, 0.3), 6.0], [Vector3(-5.0, 0.0, 0.0), Color(0.45, 0.6, 0.3), 6.0], [Vector3(0.0, -0.15, 0.0), Color(0.25, 0.45, 0.7), 2.3]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(d[2], 0.2, 6.0)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = d[1]
		mi.material_override = mat
		mi.position = d[0] + Vector3(0.0, -0.1, 0.0)
		escena.add_child(mi)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 4.2, 7.5)
	cam.rotation_degrees = Vector3(-28.0, 0.0, 0.0)
	cam.fov = 40.0
	escena.add_child(cam)
	var t := TroncoPuente3D.new()
	escena.add_child(t)
	t.preparar(null, Vector3(3.5, 0.0, 0.0), Vector3.LEFT, Vector2i(0, 0))
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png(base + "_pie.png")
	t.on_spell_hit(null)   # sin hechizo no cae; se llama a caer() directamente
	t.caer()
	await create_timer(0.35).timeout
	root.get_texture().get_image().save_png(base + "_cayendo.png")
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png(base + "_caido.png")
	print("guardadas ", base)
	quit(0)
