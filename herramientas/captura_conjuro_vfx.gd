extends SceneTree
## Captura de ConjuroVfx3D: siete columnas (un elemento cada una), arriba la voluta a medio camino y abajo la forma en la mano.
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://herramientas/captura_conjuro_vfx.gd -- salida.png
func _initialize() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var salida: String = args[0] if args.size() > 0 else "/tmp/conjuro.png"
	var vp := SubViewport.new(); vp.size = Vector2i(1400, 520); vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 3.4
	vp.add_child(cam); cam.position = Vector3(3.0, 1.0, 6.0); cam.look_at(Vector3(3.0, 0.9, 0.0)); cam.current = true
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.32, 0.42, 0.30)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.6, 0.6, 0.6)
	var we := WorldEnvironment.new(); we.environment = e; vp.add_child(we)
	var mundo := Node3D.new(); vp.add_child(mundo)
	var c := ConjuroVfx3D.new(); mundo.add_child(c)
	var els: Array = ConjuroVfx3D.PERFIL.keys()
	for i in els.size():
		var x: float = i * 0.9
		c.voluta(els[i], Vector3(x - 0.4, 1.5, 0), Vector3(x + 0.4, 1.5, 0), 1.6)
		c.forma(els[i], Vector3(x, 0.4, 0), 0.4)
	for _i in 28:
		await process_frame
	await create_timer(0.45).timeout
	await process_frame; await process_frame
	var img: Image = vp.get_texture().get_image()
	img.save_png(salida)
	print("guardado ", salida, " ", img.get_size())
	quit()
