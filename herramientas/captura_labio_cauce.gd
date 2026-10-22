extends SceneTree
## CAPTURAS del labio del cauce seco («labio cauce», 22/10). NECESITA VENTANA (sin GPU no hay imagen).
##   godot --path . --script res://herramientas/captura_labio_cauce.gd -- <antes|despues|cuenca|sinprof|profundo|sinprof_cuenca|profundo_cuenca|profundo_lleno> <carpeta>
## «antes» = `bisel_cauce = false`; «despues» = de serie; «cuenca» = de serie con una casilla `c` abierta como cuenca (Terreno3D.cauces_abiertos).
## Cuatro tomas: cámara del juego y de cerca, con decorado y solo suelo.
const S: float = 2.3


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		push_error("uso: -- <antes|despues|cuenca> <carpeta>")
		quit(2)
		return
	var modo: String = a[0]
	var carpeta: String = a[1]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var m: Node3D = (load("res://escenas/PruebaBosque01.tscn") as PackedScene).instantiate()
	if modo == "antes":
		m.set("bisel_cauce", false)
	if modo.begins_with("sinprof"):
		m.set("cauce_profundo", false)       # cauce profundo (22/10): «sinprof» = el cauce de antes; «profundo» = de serie; sufijo «_cuenca» o «_lleno» (llenar_cauce)
	root.add_child(m)
	for _i in 150:
		await process_frame
	_ocultar_ui(root)
	DirAccess.make_dir_recursive_absolute(carpeta)
	var lado: int = Terreno3D.lado_del_mapa()
	var cauce: Array = []
	for y in range(lado):
		for x in range(lado):
			if Terreno3D.letra_de(Vector2i(x, y)) == "c":
				cauce.append(Vector2i(x, y))
	# Casilla de encuadre: la c con más suelo normal alrededor (el borde más largo a la vista).
	var mejor: Vector2i = cauce[0]
	var mp: int = -1
	for c in cauce:
		var p: int = 0
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var l: String = Terreno3D.letra_de((c as Vector2i) + Vector2i(dx, dy))
				if l != "c" and l != "~" and l != "#" and l != " " and l != "b":
					p += 1
		if p > mp:
			mp = p
			mejor = c
	print("CAUCE %d casillas; encuadre en %s" % [cauce.size(), mejor])
	if modo.ends_with("cuenca"):
		Terreno3D.cauces_abiertos[mejor] = true
		for _i in 240:
			await process_frame
	if modo.ends_with("lleno"):
		m.call("llenar_cauce")
		for _i in 900:
			await process_frame
	m.set("_jugador", null)
	for toma in [[6.0, false], [3.2, false], [6.0, true], [3.2, true]]:
		var tam: float = toma[0]
		var solo: bool = toma[1]
		for nodo in ["Decorado", "Piezas", "Borde"]:
			var nd: Node = m.get_node_or_null(nodo)
			if nd is Node3D:
				(nd as Node3D).visible = not solo
		if m.get("_hierba") != null:
			(m.get("_hierba") as Node3D).visible = not solo
		m.set("_foco", Vector3((float(mejor.x) + 0.5) * S, 0.5, (float(mejor.y) + 0.5) * S))
		m.set("_tam_camara", tam)
		m.get("_camara").size = tam
		m.call("_colocar_camara")
		for _i in 60:
			await process_frame
		var tri: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		var ruta: String = "%s/cauce_z%d%s_%s.png" % [carpeta, int(tam), "_suelo" if solo else "", modo]
		root.get_viewport().get_texture().get_image().save_png(ruta)
		print("MEDIDA %s | %s | triangulos %d" % [modo, ruta.get_file(), tri])
	quit()


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D) and h.name != "Vineta3D":
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
