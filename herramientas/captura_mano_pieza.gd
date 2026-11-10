extends SceneTree
## PRIMER PLANO de la mano que sostiene una pieza (la cruz, un bastón), montado con Pj3D como en el juego. Tres vistas en una hoja:
## de frente, desde el lado de fuera y desde arriba. Para ver de verdad si el palo pasa por la palma o por el dorso.
## NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_mano_pieza.gd -- <id> [rol] [fracción del clip]
## Salida: res://docs/capturas/<id>/mano_<rol>.png

const ALTO: float = 0.85


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var args: Array = Array(OS.get_cmdline_user_args())
	var id: String = String(args[0]) if args.size() > 0 else "santa_compana_cruz"
	var rol: String = String(args[1]) if args.size() > 1 else "idle"
	var frac: float = float(args[2]) if args.size() > 2 else 0.0
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.47, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40.0, -25.0, 0.0)
	root.add_child(sol)
	var cam := Camera3D.new()
	cam.near = 0.01
	cam.fov = 24.0
	root.add_child(cam)
	var p := Pj3D.new()
	root.add_child(p)
	p.cargar(id)
	p.set_alto(ALTO)
	await process_frame
	var sk: Skeleton3D = (p.find_children("*", "Skeleton3D", true, false)[0]) as Skeleton3D
	var ap: AnimationPlayer = p._ap
	if p._arbol != null:
		p._arbol.active = false
	ap.active = true
	var clip: String = p.clip_de(rol)
	ap.play(clip)
	ap.seek(ap.get_animation(clip).length * frac, true)
	for i in 40:
		await process_frame
	var w: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_RightHand")).origin
	var m: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_RightHandMiddle1")).origin
	var foco: Vector3 = (w + m) * 0.5
	var hoja := Image.create_empty(640 * 3, 720, false, Image.FORMAT_RGB8)
	# de frente (el personaje mira a +Z), desde fuera (su derecha es −X) y desde arriba
	var vistas: Array = [Vector3(0, 0.1, 1), Vector3(-1, 0.1, 0.15), Vector3(0.0, 1, 0.12)]
	for k in vistas.size():
		cam.look_at_from_position(foco + (vistas[k] as Vector3).normalized() * 0.75, foco)
		for i in 4:
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		hoja.blit_rect(img, Rect2i(320, 0, 640, 720), Vector2i(640 * k, 0))
	var dir: String = "res://docs/capturas/%s" % id
	DirAccess.make_dir_recursive_absolute(dir)
	hoja.save_png(dir.path_join("mano_%s.png" % rol))
	print("hoja mano_%s (%s, %.0f %%): frente · desde fuera · desde arriba" % [rol, clip, frac * 100.0])
	quit(0)
