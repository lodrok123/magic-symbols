extends SceneTree
## 14/11 · Fotos de los interiores de las pallozas (muro redondo de granito, suelo de tierra) con la cámara de cada casa. Con ventana:
##   godot --path . --script res://herramientas/captura_interiores_palloza.gd -- <carpeta>

func _initialize() -> void:
	var carpeta: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://interiores"
	DirAccess.make_dir_recursive_absolute(carpeta)
	root.size = Vector2i(1280, 720)
	var escena: Node = (load("res://escenas/PruebaMonteSumicio.tscn") as PackedScene).instantiate()
	root.add_child(escena)
	for i in 40:
		await process_frame
	# Sin interfaz: solo la sala.
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).hide()
	for nombre in ["PallozaNorte", "PallozaCentral", "PallozaSur", "TiendaEste"]:
		var casa := escena.get_node("Interiores/" + nombre)
		if casa.get_child_count() < 5 and casa.has_method("montar"):
			casa.montar()
		casa.show()
		(casa.get_node("Camara") as Camera3D).current = true
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png("%s/%s.png" % [carpeta, nombre])
		print("guardado ", nombre)
	quit()
