extends SceneTree
## 25/11 · Fotos del ATREZO de Monte Sumicio (escenas/monte_sumicio_atrezo.gd) con la cámara del juego. NECESITA VENTANA:
##   E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols --script res://herramientas/captura_atrezo_sumicio.gd -- [sin]
## Deja las fotos en docs/capturas/atrezo_sumicio/ (se miran a ojo). Con `sin`, esconde el atrezo (el «antes»).
## Además mide FPS, llamadas y triángulos en la vista de la aldea, con y sin el atrezo.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var sin := args.has("sin")
	var dir := "res://docs/capturas/atrezo_sumicio"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var gi := FileAccess.open(dir + "/.gdignore", FileAccess.WRITE)
	if gi != null:
		gi.close()
	root.size = Vector2i(1280, 720)
	var t0 := Time.get_ticks_msec()
	var escena: Node = (load("res://escenas/PruebaMonteSumicio.tscn") as PackedScene).instantiate()
	root.add_child(escena)
	for i in 60:
		await process_frame
	print("escena lista en %d ms" % (Time.get_ticks_msec() - t0))
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).hide()
	var maq := escena.get_node("Maqueta")
	var atrezo := maq.find_child("AtrezoSH", true, false) as Node3D
	print("atrezo: ", atrezo != null, " · objetos ", atrezo.get_child_count() if atrezo else 0)
	if sin and atrezo:
		atrezo.visible = false
	var sufijo := "_sin" if sin else ""
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	escena.add_child(cam)
	cam.current = true
	var dir_cam := -Vector3(0.0, sin(deg_to_rad(30.0)), cos(deg_to_rad(30.0)))      # la cámara del juego: ortogonal, 30° sobre el suelo
	var torre: Node3D = maq.torre
	var casas: Array = maq.casas()
	var vistas := {
		"palloza_iria": [(casas[0] as Node3D).global_position + Vector3(0, 1, 0.5), 9.0],
		"palloza_brais": [(casas[1] as Node3D).global_position + Vector3(0, 1, 0.5), 9.0],
		"palloza_sabela": [(casas[2] as Node3D).global_position + Vector3(0, 1, 0.5), 9.0],
		"tienda": [(casas[3] as Node3D).global_position + Vector3(0, 1, 0.5), 9.0],
		"gremio": [(casas[casas.size() - 1] as Node3D).global_position + Vector3(0, 1, 0.5), 9.0],
		"obrador": [(maq.obrador as Node3D).global_position + Vector3(0, 1, 0.5), 10.0],
		"torre": [torre.global_position + Vector3(0, 1, 3.0), 12.0],
		"aldea": [torre.global_position + Vector3(0, 1, 9.0), 30.0],
		"juego": [(casas[1] as Node3D).global_position + Vector3(0, 1, 3.0), 6.0],
	}
	var lineas: PackedStringArray = []
	for nombre in vistas:
		var v: Array = vistas[nombre]
		cam.size = float(v[1])
		cam.global_transform = Transform3D(Basis.looking_at(dir_cam, Vector3.UP), (v[0] as Vector3) - dir_cam * 40.0)
		for k in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s%s.png" % [dir, nombre, sufijo])
		if nombre in ["aldea", "juego"]:
			lineas.append(await _medir(nombre + sufijo))
	var f := FileAccess.open("%s/rendimiento%s.txt" % [dir, sufijo], FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lineas) + "\n")
		f.close()
	print("\n".join(lineas))
	quit()


func _medir(nombre: String) -> String:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for k in 30:
		await process_frame
	var n := 0
	var llamadas := 0.0
	var tris := 0.0
	var inicio := Time.get_ticks_usec()
	while Time.get_ticks_usec() - inicio < 3000000:
		await process_frame
		llamadas += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		tris += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		n += 1
	var ms := float(Time.get_ticks_usec() - inicio) / 1000.0 / float(maxi(n, 1))
	return "%s | FPS %.0f | ms %.2f | llamadas %d | triángulos %d" % [nombre, 1000.0 / ms, ms, int(llamadas / n), int(tris / n)]
