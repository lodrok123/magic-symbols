extends SceneTree
## CAPTURAS SINTÉTICAS de las tiras (lámina vs procedural vs sin tiras) para las parejas que el nivel no tiene (camino→piedra, tierra→piedra): sobre PruebaBosque01
## se sustituye la textura `mapa` del suelo por un círculo de un suelo dentro de otro. NECESITA VENTANA.
##   godot --path . --script res://herramientas/captura_joints_sintetico.gd -- <antes|procedural|despues> <carpeta>
## Parejas (fuera, dentro): hierba/camino, hierba/piedra, camino/tierra, camino/piedra, tierra/piedra. 0 hierba · 1 camino · 2 tierra · 3 piedra.
const S: float = 2.3
const PAREJAS: Array = [["camino_piedra", 1, 3], ["tierra_piedra", 2, 3], ["camino_tierra", 1, 2], ["hierba_camino", 0, 1], ["hierba_piedra", 0, 3]]


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	var modo: String = a[0]
	var carpeta: String = a[1]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var m: Node3D = (load("res://escenas/PruebaBosque01.tscn") as PackedScene).instantiate()
	if modo == "antes":
		m.set("joints_suelo", false)
	if modo == "procedural":
		m.set("joints_lamina", false)
	root.add_child(m)
	for _i in 120:
		await process_frame
	_ocultar_ui(root)
	DirAccess.make_dir_recursive_absolute(carpeta)
	var lado: int = int(m.get("_lado"))
	var mat: ShaderMaterial = m.get("_mat_suelo") as ShaderMaterial
	var c0 := Vector2i(15, 6)
	m.set("_jugador", null)
	for nodo in ["Decorado", "Piezas", "Borde"]:
		var nd: Node = m.get_node_or_null(nodo)
		if nd is Node3D:
			(nd as Node3D).visible = false
	if m.get("_hierba") != null:
		(m.get("_hierba") as Node3D).visible = false
	var fuera := Image.create_empty(lado, lado, false, Image.FORMAT_R8)
	mat.set_shader_parameter("mapa_fuera", ImageTexture.create_from_image(fuera))
	for p in PAREJAS:
		var img := Image.create_empty(lado, lado, false, Image.FORMAT_RGBA8)
		for y in range(lado):
			for x in range(lado):
				var d: float = Vector2(x - c0.x, y - c0.y).length()
				var t: int = int(p[2]) if d < 3.6 + 0.6 * sin(float(x) * 0.9) else int(p[1])
				img.set_pixel(x, y, Color(1.0 if t == 0 else 0.0, 1.0 if t == 1 else 0.0, 1.0 if t == 2 else 0.0, 1.0 if t == 3 else 0.0))
		mat.set_shader_parameter("mapa", ImageTexture.create_from_image(img))
		for toma in [[6.0, "z6"], [3.0, "z3"]]:
			for foco in [Vector2(0.0, -3.6), Vector2(3.4, 1.4)]:
				m.set("_foco", Vector3((float(c0.x) + 0.5 + foco.x) * S, 0.5, (float(c0.y) + 0.5 + foco.y) * S))
				m.set("_tam_camara", float(toma[0]))
				m.get("_camara").size = float(toma[0])
				m.call("_colocar_camara")
				for _i in 30:
					await process_frame
				var ruta: String = "%s/sint_%s_%s_%d_%s.png" % [carpeta, p[0], toma[1], int(foco.x > 1.0), modo]
				root.get_viewport().get_texture().get_image().save_png(ruta)
	quit()


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D) and h.name != "Vineta3D":
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)