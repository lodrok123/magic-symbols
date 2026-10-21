extends SceneTree
## CAPTURAS ANTES / DESPUÉS de las tiras de transición del suelo («joints», PLAN_EOW_VISUAL §1 punto 3). NECESITA VENTANA (sin GPU no hay imagen).
##   godot --path . --script res://herramientas/captura_joints.gd -- <bosque|lab> <antes|despues|procedural> <carpeta>
##   «procedural» = la tira procedural de antes de la lámina (`joints_lamina = false`); «despues» = con el atlas pintado (por defecto).
## «antes» = `joints_suelo = false` en la maqueta; «despues» = los valores de serie. Para cada pareja de suelos distintos que hay en el nivel
## busca una casilla de ejemplo lejos del borde y captura con la cámara del juego (ZOOM_INICIAL) y de cerca (3,2). Imprime triángulos y llamadas.
const S: float = 2.3
const NOMBRES: Array = ["hierba", "camino", "tierra", "piedra"]
const ESCENAS: Dictionary = {"bosque": "res://escenas/PruebaBosque01.tscn", "lab": "res://laboratorios/LabPlaytestEoW.tscn"}


func _initialize() -> void:
	_correr()


func _tipo(m: Node, c: Vector2i, lado: int) -> int:
	var l: String = m.call("_letra", c)
	if l == " " or l == "#" or c.x < 0 or c.y < 0 or c.x >= lado or c.y >= lado:
		return -1
	var a: int = int(m.call("_tipo_suelo", c))
	if a == 0 and m.call("_junto_a_agua", c):
		a = 1
	return a


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("uso: -- <bosque|lab> <antes|despues> <carpeta>")
		quit(2)
		return
	var cual: String = a[0]
	var antes: bool = a[1] == "antes"
	var modo: String = a[1]
	var carpeta: String = a[2]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var m: Node3D = (load(ESCENAS[cual]) as PackedScene).instantiate()
	if antes:
		m.set("joints_suelo", false)
	if modo == "procedural":
		m.set("joints_lamina", false)
	root.add_child(m)
	for _i in 150:
		await process_frame
	_ocultar_ui(root)
	DirAccess.make_dir_recursive_absolute(carpeta)
	var lado: int = int(m.get("_lado"))
	# Ejemplos: la casilla con más vecinos de la misma pareja alrededor (lejos del borde del mapa).
	var mejor: Dictionary = {}
	for y in range(3, lado - 3):
		for x in range(3, lado - 3):
			var c := Vector2i(x, y)
			var t: int = _tipo(m, c, lado)
			if t < 0:
				continue
			for v in [Vector2i(1, 0), Vector2i(0, 1)]:
				var u: int = _tipo(m, c + v, lado)
				if u < 0 or u == t:
					continue
				var k: String = "%s_%s" % [NOMBRES[mini(t, u)], NOMBRES[maxi(t, u)]]
				# Puntuación: variedad de la vecindad 5x5 (para que el encuadre tenga la frontera larga).
				var p: int = 0
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var w: int = _tipo(m, c + Vector2i(dx, dy), lado)
						if w == t or w == u:
							p += 1
				if not mejor.has(k) or p > int(mejor[k][1]):
					mejor[k] = [c, p]
	m.set("_jugador", null)
	for k in mejor.keys():
		var c: Vector2i = mejor[k][0]
		# Cuatro tomas por pareja: zoom del juego y de cerca, cada una con decorado y solo el suelo (sin decorado ni hierba 3D, para juzgar la frontera).
		for toma in [[6.0, false], [3.2, false], [6.0, true], [3.2, true]]:
			var tam: float = toma[0]
			var solo: bool = toma[1]
			for nodo in ["Decorado", "Piezas", "Borde"]:
				var nd: Node = m.get_node_or_null(nodo)
				if nd is Node3D:
					(nd as Node3D).visible = not solo
			if m.get("_hierba") != null:
				(m.get("_hierba") as Node3D).visible = not solo
			m.set("_foco", Vector3((float(c.x) + 1.0) * S, 0.5, (float(c.y) + 0.5) * S))
			m.set("_tam_camara", tam)
			m.get("_camara").size = tam
			m.call("_colocar_camara")
			for _i in 40:
				await process_frame
			var t0: int = Time.get_ticks_usec()
			for _i in 60:
				await process_frame
			var ms: float = float(Time.get_ticks_usec() - t0) / 60000.0
			var tri: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
			var dc: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			var ruta: String = "%s/%s_%s_%s_%s.png" % [carpeta, cual, k, ("z%d%s" % [int(tam), "_suelo" if solo else ""]), "antes" if antes else modo]
			root.get_viewport().get_texture().get_image().save_png(ruta)
			print("MEDIDA %s | %s %s | %s | casilla %s | fotograma %.2f ms | triangulos %d | llamadas %d" % [cual, k, tam, "antes" if antes else modo, c, ms, tri, dc])
	quit()


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D) and h.name != "Vineta3D":
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
