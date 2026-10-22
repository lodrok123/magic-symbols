extends SceneTree
## CAPTURAS del LLENADO del cauce hondo en varios momentos (agua blanca/gris al llenarse, 22/10). NECESITA VENTANA.
##   godot --path . --script res://herramientas/captura_llenado_cauce.gd -- <carpeta> <etiqueta> [uniform=valor,...|-] [mov]
## Se llama a `llenar_cauce()` y se saca una foto a cada instante de INSTANTES (segundos desde la llamada), con el zoom ZOOM.
const S: float = 2.3
const ZOOM: float = 4.5
const INSTANTES: Array = [0.6, 1.2, 1.8, 2.6, 3.6, 5.0, 8.0]
const INSTANTES_MOVIMIENTO: Array = [1.5, 1.85, 2.2, 2.55]   ## con el 4.º argumento «mov»: fotogramas seguidos de la caída que entra en el cauce (para ver su movimiento)
const ESPERA_INICIAL_FRAMES: int = 150


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		push_error("uso: -- <carpeta> <etiqueta>")
		quit(2)
		return
	var carpeta: String = a[0]
	var etiqueta: String = a[1]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var m: Node3D = (load("res://escenas/PruebaBosque01.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for _i in ESPERA_INICIAL_FRAMES:
		await process_frame
	_ocultar_ui(root)
	DirAccess.make_dir_recursive_absolute(carpeta)
	var lado: int = Terreno3D.lado_del_mapa()
	var cauce: Array = []
	for y in range(lado):
		for x in range(lado):
			if Terreno3D.letra_de(Vector2i(x, y)) == "c":
				cauce.append(Vector2i(x, y))
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
	# Diagnóstico: 3.er argumento «uniform=valor,uniform=valor» (p. ej. caida_fuerza=0,menisco=0) se aplica al material del agua.
	if a.size() > 2 and a[2] != "-":
		var mat: ShaderMaterial = (m.get("_agua_render") as AguaRender3D).material_agua()
		for par in String(a[2]).split(","):
			var kv: PackedStringArray = par.split("=")
			mat.set_shader_parameter(kv[0], float(kv[1]))
	m.set("_jugador", null)
	for nodo in ["Decorado", "Piezas"]:
		var nd: Node = m.get_node_or_null(nodo)
		if nd is Node3D:
			(nd as Node3D).visible = false
	if m.get("_hierba") != null:
		(m.get("_hierba") as Node3D).visible = false
	m.set("_foco", Vector3((float(mejor.x) + 0.5) * S, 0.5, (float(mejor.y) + 0.5) * S))
	m.call("llenar_cauce")
	var t0: int = Time.get_ticks_msec()
	var instantes: Array = INSTANTES_MOVIMIENTO if a.size() > 3 and a[3] == "mov" else INSTANTES
	for t in instantes:
		m.set("_tam_camara", ZOOM)
		m.get("_camara").size = ZOOM
		m.call("_colocar_camara")
		while float(Time.get_ticks_msec() - t0) < float(t) * 1000.0:
			await process_frame
		await RenderingServer.frame_post_draw
		var ruta: String = "%s/llenado_t%03d_%s.png" % [carpeta, int(float(t) * 10.0), etiqueta]
		root.get_viewport().get_texture().get_image().save_png(ruta)
		print("FOTO %s" % ruta.get_file())
		var sim: AguaSim3D = Terreno3D.agua_sim
		if sim != null:
			var ps: Array = []
			for dy in range(-3, 4):
				ps.append(snappedf(sim.profundidad_casilla(mejor + Vector2i(0, dy)), 0.01))
			print("   prof de las casillas (dy -3..+3) sobre %s: %s" % [mejor, ps])
	quit()


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D) and h.name != "Vineta3D":
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
