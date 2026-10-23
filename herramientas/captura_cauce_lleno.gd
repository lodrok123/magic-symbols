extends SceneTree
## CAPTURAS del CAUCE HONDO LLENO frente al río del Bosque (23/10, agua del cauce lleno). NECESITA VENTANA.
##   godot --path . --script res://herramientas/captura_cauce_lleno.gd -- <carpeta> <etiqueta> [uniform=valor,...|-]
## Saca, con la etiqueta en el nombre: rio_juego / rio_cerca (el río del Bosque, la masa de agua más grande, para comparar), lleno_juego / lleno_cerca (el cauce
## una vez lleno, ESPERA_LLENO_S después de `llenar_cauce`) y llenado_tNNN (el llenado en varios instantes, zoom de cerca). «juego» = cámara de la maqueta con todo
## visible; «cerca» = ZOOM_CERCA sin decorado ni hierba (como captura_llenado_cauce.gd).
const S: float = 2.3
const ZOOM_CERCA: float = 4.5
const ZOOM_JUEGO: float = 10.0
const INSTANTES_LLENADO: Array = [1.8, 2.6, 3.6, 5.0]
const ESPERA_INICIAL_FRAMES: int = 150
const ESPERA_LLENO_S: float = 14.0
const FRAMES_ASENTAR: int = 25
const ESPERA_RIO_S: float = 10.0       ## s tras cargar antes de las fotos del río: la simulación tarda en asentarse (con 150 fotogramas el río aún tiene masas de espuma)

var _m: Node3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		push_error("uso: -- <carpeta> <etiqueta> [uniform=valor,...]")
		quit(2)
		return
	var carpeta: String = a[0]
	var etiqueta: String = a[1]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_m = (load("res://escenas/PruebaBosque01.tscn") as PackedScene).instantiate()
	root.add_child(_m)
	for _i in ESPERA_INICIAL_FRAMES:
		await process_frame
	_ocultar_ui(root)
	var t_ini: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t_ini) < ESPERA_RIO_S * 1000.0:
		await process_frame
	print("fps tras esperar %.0f s: %d" % [ESPERA_RIO_S, int(Engine.get_frames_per_second())])
	DirAccess.make_dir_recursive_absolute(carpeta)
	if a.size() > 2 and a[2] != "-":
		var mat: ShaderMaterial = (_m.get("_agua_render") as AguaRender3D).material_agua()
		for par in String(a[2]).split(","):
			var kv: PackedStringArray = par.split("=")
			mat.set_shader_parameter(kv[0], float(kv[1]))
	_m.set("_jugador", null)
	var rio: Vector2i = _centro_rio()
	var cauce: Vector2i = _mejor_cauce()
	# 1. El río, para comparar (todo visible, y de cerca sin decorado).
	await _foto(carpeta, "rio_juego_%s" % etiqueta, rio, ZOOM_JUEGO)
	_vista_cerca(false)
	await _foto(carpeta, "rio_cerca_%s" % etiqueta, rio, ZOOM_CERCA)
	# 2. El cauce seco (lecho a la vista) y su llenado.
	await _foto(carpeta, "seco_cerca_%s" % etiqueta, cauce, ZOOM_CERCA)
	_vista_cerca(true)
	await _foto(carpeta, "seco_juego_%s" % etiqueta, cauce, ZOOM_JUEGO)
	_vista_cerca(false)
	_m.call("llenar_cauce")
	var t0: int = Time.get_ticks_msec()
	for t in INSTANTES_LLENADO:
		while float(Time.get_ticks_msec() - t0) < float(t) * 1000.0:
			await process_frame
		var nombre_t: String = "llenado_t%03d_%s" % [int(float(t) * 10.0), etiqueta]
		await _foto(carpeta, nombre_t, cauce, ZOOM_CERCA, false)
		if a.size() > 3:
			# Capas de diagnóstico del sombreado (uniform `dbg`, solo en la versión de depuración): una foto por capa en el MISMO instante.
			var mat_d: ShaderMaterial = (_m.get("_agua_render") as AguaRender3D).material_agua()
			for d in String(a[3]).split(","):
				mat_d.set_shader_parameter("dbg", float(d))
				await _foto(carpeta, "%s_dbg%s" % [nombre_t, d], cauce, ZOOM_CERCA, false)
			mat_d.set_shader_parameter("dbg", 0.0)
	# 3. El cauce lleno, de cerca y desde la cámara del juego.
	while float(Time.get_ticks_msec() - t0) < ESPERA_LLENO_S * 1000.0:
		await process_frame
	await _foto(carpeta, "lleno_cerca_%s" % etiqueta, cauce, ZOOM_CERCA)
	var centro: Color = root.get_viewport().get_texture().get_image().get_pixel(576, 324)
	print("COLOR del centro del cauce lleno: %s" % centro)
	if centro.g > 0.85:
		print("MENTA: mallas visibles sobre la casilla %s" % cauce)
		var ar: AguaRender3D = _m.get("_agua_render") as AguaRender3D
		ar.visible = false
		for _i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		print("  SIN el agua dibujada -> %s" % root.get_viewport().get_texture().get_image().get_pixel(576, 324))
		_foto(carpeta, "lleno_cerca_%s_sinagua" % etiqueta, cauce, ZOOM_CERCA, false)
		ar.visible = true
		for _i in 3:
			await process_frame
		var cubren: Array = []
		_listar(_m, (float(cauce.x) + 0.5) * S, (float(cauce.y) + 0.5) * S, cubren)
		for g in cubren:
			if g is MultiMeshInstance3D:
				var mm: MultiMesh = (g as MultiMeshInstance3D).multimesh
				var aqui: Array = []
				for i in range(mm.instance_count):
					var o: Vector3 = (g as MultiMeshInstance3D).global_transform * mm.get_instance_transform(i).origin
					if absf(o.x - (float(cauce.x) + 0.5) * S) < S * 0.5 and absf(o.z - (float(cauce.y) + 0.5) * S) < S * 0.5:
						aqui.append(snappedf(o.y, 0.01))
				var cerca: Array = []
				for i in range(mm.instance_count):
					var o2: Vector3 = (g as MultiMeshInstance3D).global_transform * mm.get_instance_transform(i).origin
					cerca.append([Vector2(o2.x - (float(cauce.x) + 0.5) * S, o2.z - (float(cauce.y) + 0.5) * S).length(), o2])
				cerca.sort_custom(func(p, q): return float(p[0]) < float(q[0]))
				print("  vecinas ", (g as Node).get_path(), " aabb ", mm.mesh.get_aabb() if mm.mesh != null else "-", " ", cerca.slice(0, 3))
				print("  MM ", (g as Node).get_path(), " n=", mm.instance_count, " malla=", mm.mesh.resource_name if mm.mesh != null else "-", " ", mm.mesh.get_class() if mm.mesh != null else "", " en la casilla y=", aqui.slice(0, 8))
		# Prueba de ocultación: se apaga cada una y se mira de qué color queda el centro (la que lo cambie es la que tapa el lecho).
		for g in cubren:
			(g as GeometryInstance3D).visible = false
			for _i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			print("  sin %s -> %s" % [(g as Node).get_path(), root.get_viewport().get_texture().get_image().get_pixel(576, 324)])
			(g as GeometryInstance3D).visible = true
	if a.size() > 3:
		var mat_f: ShaderMaterial = (_m.get("_agua_render") as AguaRender3D).material_agua()
		for d in String(a[3]).split(","):
			mat_f.set_shader_parameter("dbg", float(d))
			await _foto(carpeta, "lleno_cerca_%s_dbg%s" % [etiqueta, d], cauce, ZOOM_CERCA, false)
		mat_f.set_shader_parameter("dbg", 0.0)
	_vista_cerca(true)
	await _foto(carpeta, "lleno_juego_%s" % etiqueta, cauce, ZOOM_JUEGO)
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim != null:
		var ps: Array = []
		for dy in range(-3, 4):
			ps.append(snappedf(sim.profundidad_casilla(cauce + Vector2i(0, dy)), 0.01))
		print("prof de las casillas (dy -3..+3) sobre %s: %s" % [cauce, ps])
	quit()


## `mostrar`: false oculta el decorado, las piezas y la hierba (lo que tapa el cauce visto de cerca); true los enseña.
func _vista_cerca(mostrar: bool) -> void:
	for nodo in ["Decorado", "Piezas"]:
		var nd: Node = _m.get_node_or_null(nodo)
		if nd is Node3D:
			(nd as Node3D).visible = mostrar
	if _m.get("_hierba") != null:
		(_m.get("_hierba") as Node3D).visible = mostrar


func _foto(carpeta: String, nombre: String, c: Vector2i, zoom: float, asentar: bool = true) -> void:
	_m.set("_foco", Vector3((float(c.x) + 0.5) * S, 0.5, (float(c.y) + 0.5) * S))
	_m.set("_tam_camara", zoom)
	_m.get("_camara").size = zoom
	_m.call("_colocar_camara")
	if asentar:
		for _i in FRAMES_ASENTAR:
			await process_frame
	await RenderingServer.frame_post_draw
	var ruta: String = "%s/%s.png" % [carpeta, nombre]
	root.get_viewport().get_texture().get_image().save_png(ruta)
	print("FOTO %s · %s · %d fps" % [ruta.get_file(), _medida_corriente(c), int(Engine.get_frames_per_second())])


## Lista las mallas visibles cuya caja cubre (cx, cz) en planta (sin las enormes): quién se dibuja sobre esa casilla.
func _listar(n: Node, cx: float, cz: float, acumula: Array) -> void:
	if n is GeometryInstance3D and (n as GeometryInstance3D).is_visible_in_tree() and n != _m.get("_agua_render"):
		var g := n as GeometryInstance3D
		var bb: AABB = g.global_transform * g.get_aabb()
		if bb.position.x <= cx and bb.end.x >= cx and bb.position.z <= cz and bb.end.z >= cz:
			acumula.append(g)
			var mat: Material = g.material_override
			if mat == null and g is MeshInstance3D and (g as MeshInstance3D).mesh != null and (g as MeshInstance3D).mesh.get_surface_count() > 0:
				mat = (g as MeshInstance3D).mesh.surface_get_material(0)
			print("  ", n.get_path(), " ", n.get_class(), " y[%.2f..%.2f] " % [bb.position.y, bb.end.y], mat.get_class() if mat != null else "-")
	for h in n.get_children():
		_listar(h, cx, cz, acumula)


## Corriente de la simulación en las 7 casillas de la columna de `c` (dy -3..+3): la mayor (u/s) y si hay algún valor no finito (una simulación que se desmanda).
func _medida_corriente(c: Vector2i) -> String:
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim == null:
		return "sin simulación"
	var mayor: float = 0.0
	var no_finito: int = 0
	for dy in range(-3, 4):
		var p := Vector3((float(c.x) + 0.5) * S, 0.5, (float(c.y + dy) + 0.5) * S)
		for k in range(4):
			var v: Vector2 = sim.corriente_en(p + Vector3(float(k % 2) - 0.5, 0.0, float(k / 2) - 0.5) * 0.6)
			if is_finite(v.x) and is_finite(v.y):
				mayor = maxf(mayor, v.length())
			else:
				no_finito += 1
	return "corriente máx %.2f u/s, %d no finitas" % [mayor, no_finito]


## La casilla `c` del cauce con más vecinos que no son agua ni cauce (la misma que elige captura_llenado_cauce.gd).
func _mejor_cauce() -> Vector2i:
	var lado: int = Terreno3D.lado_del_mapa()
	var mejor := Vector2i.ZERO
	var mp: int = -1
	for y in range(lado):
		for x in range(lado):
			var c := Vector2i(x, y)
			if Terreno3D.letra_de(c) != "c":
				continue
			var p: int = 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var l: String = Terreno3D.letra_de(c + Vector2i(dx, dy))
					if l != "c" and l != "~" and l != "#" and l != " " and l != "b":
						p += 1
			if p > mp:
				mp = p
				mejor = c
	return mejor


## Centro de la masa de agua más grande del mapa (el río): la casilla `~` más cercana a la media de la masa.
func _centro_rio() -> Vector2i:
	var mapa: PackedStringArray = _m.get("_mapa")
	var visto: Dictionary = {}
	var mejor_masa: Array = []
	for y in range(mapa.size()):
		for x in range(mapa[y].length()):
			var c := Vector2i(x, y)
			if mapa[y][x] != "~" or visto.has(c):
				continue
			var cola: Array = [c]
			var celdas: Array = []
			visto[c] = true
			while not cola.is_empty():
				var p: Vector2i = cola.pop_back()
				celdas.append(p)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = p + (d as Vector2i)
					if q.y >= 0 and q.y < mapa.size() and q.x >= 0 and q.x < mapa[q.y].length() and mapa[q.y][q.x] == "~" and not visto.has(q):
						visto[q] = true
						cola.append(q)
			if celdas.size() > mejor_masa.size():
				mejor_masa = celdas
	var sx: float = 0.0
	var sy: float = 0.0
	for c in mejor_masa:
		sx += float((c as Vector2i).x)
		sy += float((c as Vector2i).y)
	var cen := Vector2(sx / mejor_masa.size(), sy / mejor_masa.size())
	var mejor: Vector2i = mejor_masa[0]
	for c in mejor_masa:
		if Vector2(c as Vector2i).distance_to(cen) < Vector2(mejor).distance_to(cen):
			mejor = c
	return mejor


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D) and h.name != "Vineta3D":
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
