extends SceneTree
## CAPTURAS Y MEDIDAS de la CASCADA y los BORDES del agua (24/10, referencia: Zelda Echoes of Wisdom). NECESITA VENTANA.
##   godot --path . --script res://herramientas/captura_agua_cascada_eow.gd -- <banco|bosque> <carpeta> <etiqueta> [niveles]
## banco : el banco de la cascada (`banco_cascada_eow.gd`): 6 fotogramas seguidos de la caída (cámara del juego), el pie de cerca y la orilla de la charca de cerca.
## bosque: Bosque 01 con la cámara de la maqueta: río y estanque (juego, de cerca, orilla de cerca). Mide el fotograma en las dos.
const S: float = 2.3
const FOTOS_CASCADA: int = 6
const SEPARACION_S: float = 0.18
const ESPERA_BANCO_S: float = 9.0         ## segundos de simulación antes de la primera foto (la meseta ya vierte sobre la charca)
const MEDIR_FOTOGRAMAS: int = 240
const TAM_ORILLA: float = 3.2             ## tamaño de la cámara ortogonal en las vistas de orilla de cerca
const BANCO: GDScript = preload("res://herramientas/banco_cascada_eow.gd")
const RENDER_ANTES: String = "res://herramientas/_agua_render_antes_tmp.gd"
var _gpu_rid: RID


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("uso: -- <banco|bosque> <carpeta> <etiqueta> [niveles]")
		quit(2)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(a[1])
	_gpu_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_gpu_rid, true)
	if a[0] == "banco":
		await _banco(a[1], a[2], float(a[3]) if a.size() > 3 else 2.0)
	else:
		await _bosque(a[1], a[2])
	quit()


func _banco(carpeta: String, et: String, niveles: float) -> void:
	var b: Node3D = BANCO.new()
	if et == "antes":
		b.set("script_render", load(RENDER_ANTES))       # copia temporal del dibujo del agua de antes de este cambio (git show HEAD), solo para esta comparación
	root.add_child(b)
	b.call("montar", niveles)
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) < ESPERA_BANCO_S * 1000.0:
		await process_frame
	var pie: Vector3 = b.call("pie_caida")
	var tomas: Array = [["juego", pie + Vector3(0.0, 0.0, S * 1.6), 11.0], ["cerca", pie + Vector3(0.0, 0.4, S * 0.6), 6.0], ["pie", pie + Vector3(0.0, 0.2, S * 0.4), 3.4]]
	for t in tomas:
		b.call("encuadrar", t[1], t[2])
		for _i in 20:
			await process_frame
		var med: String = await _medir(MEDIR_FOTOGRAMAS)
		print("MEDIDA banco | %s | %s | %s" % [t[0], et, med])
		var n: int = FOTOS_CASCADA if t[0] != "juego" else 2
		for f in n:
			await RenderingServer.frame_post_draw
			var ruta: String = "%s/banco%d_%s_%s_f%d.png" % [carpeta, int(niveles), t[0], et, f]
			root.get_viewport().get_texture().get_image().save_png(ruta)
			print("FOTO %s" % ruta.get_file())
			var t1: int = Time.get_ticks_msec()
			while float(Time.get_ticks_msec() - t1) < SEPARACION_S * 1000.0:
				await process_frame
	# la orilla de la charca (lado de la salida) de cerca
	b.call("encuadrar", Vector3(1.6 * S, 0.0, 4.2 * S), TAM_ORILLA)
	for _i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/banco%d_orilla_%s.png" % [carpeta, int(niveles), et])


func _bosque(carpeta: String, et: String) -> void:
	var m: Node3D = (load("res://escenas/PruebaBosque01.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for _i in 150:
		await process_frame
	_ocultar_ui(root)
	var vistas: Dictionary = _vistas_bosque(m)
	var mp: PackedStringArray = m.get("_mapa")
	for y in range(mp.size()):
		print("MAPA %02d %s" % [y, mp[y]])
	for k in vistas.keys():
		var v: Array = vistas[k]
		m.set("_jugador", null)
		m.set("_foco", Vector3((float(v[0]) + 0.5) * S, 0.5, (float(v[1]) + 0.5) * S))
		m.set("_tam_camara", float(v[2]))
		m.get("_camara").size = float(v[2])
		m.call("_colocar_camara")
		print("camara rot %s incl %s" % [(m.get("_camara") as Camera3D).rotation_degrees, m.get("_incl")])
		for _i in 30:
			await process_frame
		var med: String = await _medir(MEDIR_FOTOGRAMAS)
		print("MEDIDA bosque | %s | %s | %s" % [k, et, med])
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/bosque_%s_%s.png" % [carpeta, k, et])


func _medir(n: int) -> String:
	var t0: int = Time.get_ticks_usec()
	var gpu: float = 0.0
	var cpu: float = 0.0
	for _i in n:
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(_gpu_rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(_gpu_rid)
	var ms: float = float(Time.get_ticks_usec() - t0) / (n * 1000.0)
	return "fotograma %.2f ms (%.0f fps) | GPU %.3f ms | CPU render %.3f ms" % [ms, 1000.0 / ms, gpu / n, cpu / n]


## El río (la masa de agua mayor) y el estanque (la segunda) de Bosque 01, y el trozo de orilla más recto de cada una (la casilla de agua con tierra a un lado).
func _vistas_bosque(m: Node3D) -> Dictionary:
	var mapa: PackedStringArray = m.get("_mapa")
	var visto: Dictionary = {}
	var masas: Array = []
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
			masas.append(celdas)
	masas.sort_custom(func(m1, m2) -> bool: return m1.size() > m2.size())
	var res: Dictionary = {}
	var nombres: Array = ["rio", "estanque"]
	for i in range(mini(2, masas.size())):
		var cs: Array = masas[i]
		var sx: float = 0.0
		var sy: float = 0.0
		for c in cs:
			sx += float((c as Vector2i).x)
			sy += float((c as Vector2i).y)
		var cen := Vector2(sx / cs.size(), sy / cs.size())
		var mejor: Vector2i = cs[0]
		for c in cs:
			if Vector2(c as Vector2i).distance_to(cen) < Vector2(mejor).distance_to(cen):
				mejor = c
		res["%s_juego" % nombres[i]] = [float(mejor.x), float(mejor.y), 16.0]
		res["%s_cerca" % nombres[i]] = [float(mejor.x), float(mejor.y), 5.0]
		# la orilla del norte (queda al fondo de la vista, sin árboles delante): la casilla de más al norte, la mediana en x de las de esa fila
		var y_min: int = 9999
		for c in cs:
			y_min = mini(y_min, (c as Vector2i).y)
		var xs: Array = []
		for c in cs:
			if (c as Vector2i).y == y_min:
				xs.append((c as Vector2i).x)
		xs.sort()
		res["%s_orilla" % nombres[i]] = [float(xs[xs.size() / 2]), float(y_min) - 0.3, TAM_ORILLA]
	return res


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D) and h.name != "Vineta3D":
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
