extends SceneTree
## 14/11 · Fotos de la vegetación de Monte Sumicio (escenas/monte_sumicio_vegetacion.gd) con la cámara del juego. NECESITA VENTANA:
##   E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols --script res://herramientas/captura_vegetacion_sumicio.gd -- [carpeta]
## Por defecto deja las fotos en docs/capturas/vegetacion_sumicio/ (se miran a ojo). Con `sin` en vez de carpeta, quita la vegetación (el «antes»).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var sin := args.has("sin")
	var dir: String = "res://docs/capturas/vegetacion_sumicio"
	for a in args:
		if a != "sin":
			dir = a
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir) if dir.begins_with("res://") else dir)
	root.size = Vector2i(1280, 720)
	var escena: Node = (load("res://escenas/PruebaMonteSumicio.tscn") as PackedScene).instantiate()
	root.add_child(escena)
	for i in 45:
		await process_frame
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).hide()
	var maq := escena.get_node("Maqueta")
	var veg := maq.find_child("Vegetacion", true, false) as Node3D
	print("vegetación: ", veg != null, " · hijos ", veg.get_child_count() if veg else 0)
	if sin and veg:
		veg.visible = false
	var sufijo := "_sin" if sin else ""
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	escena.add_child(cam)
	cam.current = true
	var dir_cam := -Vector3(0.0, sin(deg_to_rad(60.0)), cos(deg_to_rad(60.0)))      # la cámara del juego: ortogonal a 60°
	var porton: Node3D = maq.porton
	var torre: Node3D = maq.torre
	var casas: Array = maq.casas()
	var vistas := {
		"cancela": [porton.global_position + Vector3(0, 1, 0.8), 10.0],
		"valla_suroeste": [porton.global_position + Vector3(-10.5, 1, -4.0), 9.0],
		"palloza": [(casas[0] as Node3D).global_position + Vector3(0, 1, 0.5), 9.0],
		"tienda": [(casas[3] as Node3D).global_position + Vector3(0, 1, 0.5), 9.0],
		"torre": [torre.global_position + Vector3(0, 1, 3.0), 12.0],
		"aldea": [torre.global_position + Vector3(0, 1, 9.0), 26.0],
	}
	for nombre in vistas:
		var v: Array = vistas[nombre]
		cam.size = float(v[1])
		cam.global_transform = Transform3D(Basis.looking_at(dir_cam, Vector3.UP), (v[0] as Vector3) - dir_cam * 20.0)
		for k in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var ruta := "%s/%s%s.png" % [dir, nombre, sufijo]
		root.get_texture().get_image().save_png(ruta)
		print("guardado ", ruta)
	# Perspectiva rasante ante la cancela, como en la lámina 4 del PPTX.
	var cam2 := Camera3D.new()
	escena.add_child(cam2)
	cam2.fov = 50
	cam2.look_at_from_position(porton.global_position + Vector3(2.5, 2.4, 7.5), porton.global_position + Vector3(0, 1.2, 1.2))
	cam2.current = true
	for k in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/cancela_persp%s.png" % [dir, sufijo])
	quit()
