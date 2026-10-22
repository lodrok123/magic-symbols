extends SceneTree
## CAPTURAS de las ESQUINAS del agua («triángulos vacíos», 22/10) y del MOVIMIENTO del río/caída (varios fotogramas seguidos). NECESITA VENTANA.
##   godot --path . --script res://herramientas/captura_agua_esquinas.gd -- <esquinas|movimiento> <carpeta> <etiqueta> [arriba|-] [adornos_off|guij_off|guij_sinsombra|-] [uniform=valor,...]
## esquinas: 2 esquinas convexas (casilla de agua con dos vecinos secos en ángulo) y 2 cóncavas (vecinos de agua pero diagonal seca) del Bosque 01, a dos zooms.
## movimiento: el tramo de río con más corriente y la mayor caída, FOTOGRAMAS fotogramas separados SEPARACION segundos.
const S: float = 2.3
const ZOOMS: Array = [3.0, 1.6]
const FOTOGRAMAS: int = 3
const SEPARACION: float = 0.35
const ESPERA_FRAMES: int = 30
const ALTURA_ARRIBA: float = 12.0     ## con el 4.º argumento «arriba» la cámara mira recta hacia abajo (para ver huecos de la malla)


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("uso: -- <esquinas|movimiento> <carpeta> <etiqueta>")
		quit(2)
		return
	var modo: String = a[0]
	var carpeta: String = a[1]
	var etiqueta: String = a[2]
	var arriba: bool = a.size() > 3 and a[3] == "arriba"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var m: Node3D = (load("res://escenas/PruebaBosque01.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for _i in 150:
		await process_frame
	_ocultar_ui(root)
	var apaga: String = a[4] if a.size() > 4 else ""
	if apaga == "adornos_off" and m.get("_adornos_lecho") != null:
		(m.get("_adornos_lecho") as Node3D).visible = false
	if apaga == "guij_off" and m.get_node_or_null("lecho_rio") != null:
		(m.get_node("lecho_rio") as Node3D).visible = false
	# 6.º argumento opcional: «uniform=valor,uniform=valor» para el material del agua (diagnóstico, p. ej. orilla_mov=0).
	if a.size() > 5 and m.get("_agua_render") != null:
		var mat_agua: ShaderMaterial = (m.get("_agua_render") as AguaRender3D).material_agua()
		for par in String(a[5]).split(","):
			var kv: PackedStringArray = par.split("=")
			mat_agua.set_shader_parameter(kv[0], float(kv[1]))
	var lr: MultiMeshInstance3D = m.get_node_or_null("lecho_rio") as MultiMeshInstance3D
	if lr != null:
		print("GUIJARROS n=%d color0=%s mat=%s" % [lr.multimesh.instance_count, lr.multimesh.get_instance_color(0), lr.multimesh.mesh.surface_get_material(0)])
	if apaga == "guij_sinsombra" and lr != null:
		var sm := StandardMaterial3D.new()
		sm.vertex_color_use_as_albedo = true
		sm.vertex_color_is_srgb = true
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lr.material_override = sm
	DirAccess.make_dir_recursive_absolute(carpeta)
	m.set("_jugador", null)
	for nodo in ["Decorado", "Piezas"]:
		var nd: Node = m.get_node_or_null(nodo)
		if nd is Node3D:
			(nd as Node3D).visible = false
	if m.get("_hierba") != null:
		(m.get("_hierba") as Node3D).visible = false
	var mapa: PackedStringArray = m.get("_mapa")
	var vistas: Array = _vistas(mapa, modo)
	for v in vistas:
		var cv: Vector2i = v["c"]
		for z in (ZOOMS if modo == "esquinas" else [float(v["zoom"])]):
			m.set("_foco", Vector3((float(cv.x) + 0.5) * S, 0.5, (float(cv.y) + 0.5) * S))
			m.set("_tam_camara", z)
			m.get("_camara").size = z
			m.call("_colocar_camara")
			if arriba:
				m.set_process(false)
				(m.get("_camara") as Camera3D).attributes = null
				_sin_tilt(root)
				var cam: Camera3D = m.get("_camara")
				var foco: Vector3 = m.get("_foco")
				cam.global_position = foco + Vector3(0.0, ALTURA_ARRIBA, 0.0)
				cam.look_at(foco, Vector3.FORWARD)
			for _i in ESPERA_FRAMES:
				await process_frame
			for f in (1 if modo == "esquinas" else FOTOGRAMAS):
				await RenderingServer.frame_post_draw
				var ruta: String = "%s/%s_%s_z%d_%s%s.png" % [carpeta, modo, v["nombre"], int(z * 10), etiqueta, "" if modo == "esquinas" else "_f%d" % f]
				root.get_viewport().get_texture().get_image().save_png(ruta)
				print("FOTO %s casilla %s" % [ruta.get_file(), cv])
				if modo == "movimiento":
					var t0: int = Time.get_ticks_msec()
					while float(Time.get_ticks_msec() - t0) < SEPARACION * 1000.0:
						await process_frame
	quit()


func _agua(mapa: PackedStringArray, c: Vector2i) -> bool:
	return c.y >= 0 and c.y < mapa.size() and c.x >= 0 and c.x < mapa[c.y].length() and mapa[c.y][c.x] == "~"


func _vistas(mapa: PackedStringArray, modo: String) -> Array:
	var res: Array = []
	var conv: Array = []
	var conc: Array = []
	var lineal: Array = []
	for y in range(mapa.size()):
		for x in range(mapa[y].length()):
			var c := Vector2i(x, y)
			if not _agua(mapa, c):
				continue
			var n: int = 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _agua(mapa, c + (d as Vector2i)):
					n += 1
			var seco_diag: bool = false
			for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				if not _agua(mapa, c + (d as Vector2i)):
					seco_diag = true
			if n == 2 and (_agua(mapa, c + Vector2i(1, 0)) != _agua(mapa, c + Vector2i(-1, 0))):
				conv.append(c)
			elif n == 4 and seco_diag:
				conc.append(c)
			elif n == 2:
				lineal.append(c)
	print("esquinas convexas %d, cóncavas %d" % [conv.size(), conc.size()])
	if modo == "esquinas":
		for i in range(mini(2, conv.size())):
			res.append({"c": conv[i * conv.size() / 2], "nombre": "convexa%d" % i})
		for i in range(mini(2, conc.size())):
			res.append({"c": conc[i * conc.size() / 2], "nombre": "concava%d" % i})
	else:
		var n_l: int = lineal.size()
		if n_l > 0:
			res.append({"c": lineal[n_l / 3], "nombre": "rio_a", "zoom": 5.0})
			res.append({"c": lineal[2 * n_l / 3], "nombre": "rio_b", "zoom": 5.0})
		var sim: AguaSim3D = Terreno3D.agua_sim
		if sim != null:
			var mejor_salto: float = 0.0
			var mejor_c := Vector2i(-1, -1)
			for ty in range(sim.h):
				for tx in range(sim.w - 1):
					var k: int = ty * sim.w + tx
					if sim.prof[k] < 0.05 or sim.prof[k + 1] < 0.05:
						continue
					var salto: float = absf((sim.suelo[k] + sim.prof[k]) - (sim.suelo[k + 1] + sim.prof[k + 1]))
					if salto > mejor_salto:
						mejor_salto = salto
						mejor_c = Vector2i(tx / sim.sub, ty / sim.sub)
			print("mayor caída (superficie) %.2f u en la casilla %s" % [mejor_salto, mejor_c])
			if mejor_salto > 0.2:
				res.append({"c": mejor_c, "nombre": "caida", "zoom": 4.0})
	return res


func _sin_tilt(n: Node) -> void:
	for h in n.get_children():
		if h is TiltShift3D:
			(h as CanvasLayer).visible = false
		_sin_tilt(h)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D) and h.name != "Vineta3D":
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
