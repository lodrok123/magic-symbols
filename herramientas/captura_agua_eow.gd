extends SceneTree
## CAPTURAS Y MEDIDAS del agua EoW (Pipeline, 22/10; docs/PLAN_EOW_VISUAL.md §1.6): refracción, tercera escala de olas y sondas de reflejos por sala.
## NECESITA VENTANA (con --headless no hay imagen ni GPU).
##   godot --path . --script res://herramientas/captura_agua_eow.gd -- <lab|bosque> <carpeta> [solo_medir]
## Para cada vista saca las MISMAS capturas en cuatro estados acumulativos y mide GPU / CPU de render / llamadas de dibujo en cada uno:
##   antes    = todo lo nuevo apagado (sin refracción, sin tercera escala, UNA sonda para todo el mapa): el agua de antes de hoy
##   olas     = + tercera escala de olas
##   refr     = + refracción
##   completo = + sondas por sala (el estado de serie)
## Además, una captura con IMPACTO (ondas de AguaOndas3D) en «antes» y «completo». Imprime líneas MEDIDA y el material de las sondas.
const S: float = 2.3
const ESTADOS: Array = ["antes", "olas", "refr", "completo"]
const VISTAS: Dictionary = {
	"lab": {
		"escena": "res://laboratorios/LabPlaytestEoW.tscn",
		# nombre: [casilla x, casilla y, tamaño de cámara]. Sala 2: charca con franja helada (x 13–14). El lab horneado (el que se juega) solo tiene agua en las salas 2 y 4.
		"vistas": {
			"sala2_juego": [12.0, 3.0, 10.0], "sala2_cerca": [11.5, 3.0, 4.5], "sala2_hielo": [13.5, 3.0, 4.0],
			"sala4_rio": [28.0, 5.0, 8.0],
		},
		"impacto": "sala2_cerca",
	},
	"bosque": {
		"escena": "res://escenas/PruebaBosque01.tscn",
		"vistas": {},       # se rellenan con las dos masas de agua más grandes del mapa
		"impacto": "",
	},
}
var _gpu_rid: RID
var _m: Node3D = null
var _r: AguaRender3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		push_error("uso: -- <lab|bosque> <carpeta> [solo_medir]")
		quit(2)
		return
	var cual: String = a[0]
	var carpeta: String = a[1]
	var solo_medir: bool = a.size() > 2 and a[2] == "solo_medir"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var esc: PackedScene = load(VISTAS[cual]["escena"])
	_m = esc.instantiate()
	root.add_child(_m)
	for _i in 150:
		await process_frame
	_ocultar_ui(root)
	_r = _m.get("_agua_render") as AguaRender3D
	if _r == null:
		push_error("la escena no tiene agua física")
		quit(3)
		return
	var vistas: Dictionary = (VISTAS[cual]["vistas"] as Dictionary).duplicate(true)
	if cual == "bosque":
		vistas = _vistas_bosque()
	if cual == "lab" and Terreno3D.agua_sim != null:
		# El hielo de la sala 2 (franja x 13–14, y 2–4): lo helamos en la simulación (el estado del lab solo marca la casilla) y dura todo el rato de la captura.
		for cy in [2, 3, 4]:
			for cx in [13, 14]:
				Terreno3D.agua_sim.helar_casilla(Vector2i(cx, cy), true)
		for _i in 40:
			await process_frame
	var impacto: String = String(VISTAS[cual]["impacto"])
	if cual == "bosque" and not vistas.is_empty():
		impacto = String(vistas.keys()[0])
	DirAccess.make_dir_recursive_absolute(carpeta)
	_gpu_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_gpu_rid, true)
	print("renderer: %s · GPU: %s · ventana %s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), root.size])
	for k in vistas.keys():
		var cv := Vector2i(int((vistas[k] as Array)[0]), int((vistas[k] as Array)[1]))
		print("vista %s: casilla %s letra «%s» prof %.2f" % [k, cv, Terreno3D.letra_de(cv), Terreno3D.agua_sim.profundidad_casilla(cv)])
	if cual == "lab":
		_vistas_bosque()      # solo para que imprima las masas de agua que tiene el lab que se está jugando (el .tscn horneado, no las letras del .txt)
	print("sondas montadas con el estado de serie: %d" % (_m.call("sondas_montadas") as Array).size())
	for e in ESTADOS:
		await _estado(e)
		print("ESTADO %s · sondas %d" % [e, (_m.call("sondas_montadas") as Array).size()])
		for k in vistas.keys():
			var v: Array = vistas[k]
			_m.set("_jugador", null)
			_m.set("_foco", Vector3((float(v[0]) + 0.5) * S, 0.5, (float(v[1]) + 0.5) * S))
			_m.set("_tam_camara", float(v[2]))
			_m.get("_camara").size = float(v[2])
			_m.call("_colocar_camara")
			for _i in 25:
				await process_frame
			var med: String = await _medir(120 if solo_medir else 240)
			if not solo_medir:
				var ruta: String = "%s/%s_%s_%s.png" % [carpeta, cual, k, e]
				root.get_viewport().get_texture().get_image().save_png(ruta)
			print("MEDIDA %s | %s | %s | %s" % [cual, k, e, med])
	if impacto != "" and not solo_medir:
		var v2: Array = vistas[impacto]
		for e in ["antes", "completo"]:
			await _estado(e)
			_m.set("_jugador", null)
			_m.set("_foco", Vector3((float(v2[0]) + 0.5) * S, 0.5, (float(v2[1]) + 0.5) * S))
			_m.set("_tam_camara", float(v2[2]))
			_m.get("_camara").size = float(v2[2])
			_m.call("_colocar_camara")
			for _i in 25:
				await process_frame
			var o: AguaOndas3D = _m.call("_asegurar_ondas") as AguaOndas3D
			if o != null:
				var c0 := Vector3((float(v2[0]) + 0.5) * S, 0.5, (float(v2[1]) + 0.5) * S)
				for d in [Vector3.ZERO]:
					o.impulso(c0 + d, 0.045, 0.6)      # la fuerza de una salpicadura del juego (FUERZA_ONDA_SALPICA 0,05): con más, la espuma de crestas lo cubre todo
				await create_timer(0.12).timeout
				for _i in 3:
					await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/%s_%s_impacto_%s.png" % [carpeta, cual, impacto, e])
			print("IMPACTO %s | %s | %s" % [cual, impacto, e])
	quit()


## Aplica un estado acumulativo y deja que se horneen las sondas.
func _estado(e: String) -> void:
	_r.agua_refraccion = e == "refr" or e == "completo"
	_r.olas_tercera_escala = e != "antes"
	var por_sala: bool = e == "completo"
	if bool(_m.get("sondas_por_sala")) != por_sala or e == "antes":
		_m.set("sondas_por_sala", por_sala)
		_m.call("_montar_sonda")
	for _i in 30:
		await process_frame


func _medir(n: int) -> String:
	var t0: int = Time.get_ticks_usec()
	var gpu: float = 0.0
	var cpu: float = 0.0
	var calls: float = 0.0
	var prim: float = 0.0
	for _i in n:
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(_gpu_rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(_gpu_rid)
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prim += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var ms: float = float(Time.get_ticks_usec() - t0) / (n * 1000.0)
	return "fotograma %.2f ms | GPU %.3f ms | CPU render %.3f ms | llamadas %.1f | triángulos %.0f" % [ms, gpu / n, cpu / n, calls / n, prim / n]


## Las dos masas de agua (casillas `~` conectadas) más grandes del mapa: «rio» (la mayor) y «estanque» (la segunda), centradas en su casilla central.
func _vistas_bosque() -> Dictionary:
	var mapa: PackedStringArray = _m.get("_mapa")
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
		print("masa de agua %s: %d casillas, centro (%d, %d)" % [nombres[i], cs.size(), mejor.x, mejor.y])
		res["%s_juego" % nombres[i]] = [float(mejor.x), float(mejor.y), 16.0]
		res["%s_cerca" % nombres[i]] = [float(mejor.x), float(mejor.y), 5.0]
	return res


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D) and h.name != "Vineta3D":
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
