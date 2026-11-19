extends SceneTree
## 14/11 · Foto de la empalizada de Monte Sumicio con la valla modular, con la cámara del juego. Con ventana:
##   godot --path . --script res://herramientas/captura_empalizada_sumicio.gd -- <salida.png>

func _initialize() -> void:
	var salida: String = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	var escena: Node = (load("res://escenas/PruebaMonteSumicio.tscn") as PackedScene).instantiate()
	root.add_child(escena)
	for i in 40:
		await process_frame
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).hide()
	# Cámara propia como la del juego (ortogonal, 60°) sobre la esquina noroeste de la empalizada.
	var tramo := escena.find_child("Tramo_5_2", true, false) as Node3D
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 9.0
	escena.add_child(cam)
	var foco := tramo.global_position + Vector3(-2.0, 1.2, 9.0)
	var dir := -Vector3(0.0, sin(deg_to_rad(60.0)), cos(deg_to_rad(60.0)))
	cam.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 14.0)      # cerca: el sol solo proyecta sombra hasta 35 m de la cámara
	cam.current = true
	for l in root.find_children("*", "DirectionalLight3D", true, false):
		print("sol ", l.name, " sombra=", l.shadow_enabled, " rot=", l.global_rotation_degrees, " dist=", l.directional_shadow_max_distance, " visible=", l.visible)
	var sv := escena.find_child("SombraValla", true, false) as MeshInstance3D
	if sv:
		var pie: Vector3 = sv.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][1]
		print("franja idx=", sv.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size(), " aabb=", sv.global_transform * sv.get_aabb(), " visible=", sv.is_visible_in_tree(), " foco=", foco)
		print("franja y=", pie.y, " · suelo y_pies=", Terreno3D.y_pies(Terreno3D.celda_de(pie)), " realce=", Terreno3D.realces_terreno.get(Terreno3D.celda_de(pie), 0.0))
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(salida)
	print("guardado ", salida)
	quit()
