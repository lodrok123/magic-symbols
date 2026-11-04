extends "res://herramientas/escenario_base.gd"
## CAPTURAS DEL RAYO EN EL JUEGO REAL, para compararlas con la referencia en vídeo de Pablo (rama claude/vfx-rayo-ref). NECESITA VENTANA. Carga el Bosque 01 v01 con la cámara DEL JUEGO y, con el rayo de serie
## (`magic_symbols/vfx_procedural_elementos` de project.godot, sin tocarlo), hace cada uso: bola (proyectil, con su carga en la mano), impacto, pilar (ultimate), haz, muro, área, barrera, el ESTADO electrificado de una
## entidad y el AGUA ELECTRIFICADA del suelo. Todos los hechizos salen por el Lanzador3D real; el impacto con un toy suelto en el mundo (el golpe contra el suelo).
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_rayo_ref.gd -- [carpeta] [solo_caso|*]
## Escribe <caso>_<t>.png (fotograma completo del juego) en la carpeta (por defecto docs/capturas/vfx_en_juego/rayo_ref/). La hoja resumen la monta herramientas/hoja_rayo_ref.py.

const RUTA: String = "res://escenas/PruebaBosque01_v01.tscn"
## [id, título, glifos, tiempos de foto (s tras lanzar)]
const HECHIZOS: Array = [
	["proyectil", "proyectil (bola)", ["flecha"], [0.15, 0.4]],
	["carga", "carga en la mano", ["flecha"], [0.3]],
	["pilar", "pilar (ultimate)", ["altura", "altura", "altura"], [0.08, 0.3, 0.9]],
	["haz", "haz (beam)", ["linea_x", "linea_x"], [0.2, 0.8]],
	["muro", "muro (wall)", ["barrera", "linea_x", "altura"], [0.1, 0.6]],
	["area", "area (bola quieta)", ["pulso"], [0.3, 1.2, 2.6]],
]
const DIR: Vector3 = Vector3(1.0, 0.0, 0.0)

var _dir: String = "res://docs/capturas/vfx_en_juego/rayo_ref"
var _solo: String = ""
var _glifos: Array = []
var _claro: Vector2i = Vector2i(-1, -1)


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "*":
		_solo = a[1]
	if a.size() > 2 and a[2] != "":
		_glifos = Array(a[2].split(","))
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Misiones.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	lanzador.tinta = null
	_ocultar_ui(root)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	_claro = _buscar_claro()
	_ok("0 hay un claro llano para las capturas (%s)" % str(_claro), _claro != Vector2i(-1, -1))
	if _claro == Vector2i(-1, -1):
		return
	_ok("0b el rayo está encendido de serie", VfxToyJuego.usa_toy("rayo"))
	colocar_jugador(_claro)
	await avanzar_s(2.0)
	for hz in HECHIZOS:
		if _solo != "" and _solo != String(hz[0]):
			continue
		colocar_jugador(_claro)
		await avanzar_s(0.3)
		await _hechizo(hz)
	if _solo == "" or _solo == "impacto":
		await _impactos()
	if _solo == "" or _solo == "estado_entidad":
		await _estado_entidad()
	if _solo == "" or _solo == "estado_agua":
		await _estado_agua()
	print("escrito ", _dir)


func _foto(nombre: String) -> void:
	_ocultar_ui(root)
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))


func _hechizo(hz: Array) -> void:
	var id: String = String(hz[0])
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element("rayo")
	for g in (_glifos if not _glifos.is_empty() else (hz[2] as Array)):
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	var origen: Vector3 = jugador.position
	if (hz[2] as Array).has("barrera"):
		origen += DIR * Terreno3D.casilla * 0.9
	var avisos: Array = []
	var cb: Callable = func(est: String, e: String, g: Dictionary, o: Vector3, _d: Vector3, _p: Dictionary) -> void:
		avisos.append("%s/%s xyz=(%.2f,%.2f,%.2f) vida=%s suelo=%.2f origen=%s jugador=%s claves=%s" % [est, e, float(g["x"]), float(g["y"]), float(g["z"]), str(g.get("vida_total")), float(g["suelo"]), str(o), str(jugador.position), str(g.keys())])
	lanzador.hechizo_v2.connect(cb)
	var salio: bool = lanzador.lanzar_pagina_ya(0, origen, DIR, id == "carga")
	_ok("1 rayo · %s: sale el hechizo" % id, salio)
	await avanzar(2)
	lanzador.hechizo_v2.disconnect(cb)
	print("HECHIZO_V2 %s: %s" % [id, str(avisos)])
	var tj: Object = maqueta.find_child("VfxToyJuego", true, false)
	if tj != null:
		print("TOYS %s: vivos=%d creados=%s" % [id, int(tj.call("vivos")), str(tj.get("creados"))])
	var t_ant: float = 0.0
	for t in (hz[3] as Array):
		await avanzar_s(float(t) - t_ant)
		t_ant = float(t)
		_foto("%s_%03d" % [id, int(round(float(t) * 100.0))])
	await avanzar_s(4.0)


## IMPACTO: el golpe del rayo contra el suelo delante de la jugadora (un RayoToy suelto en el mundo: mismo camino que el de un proyectil que choca).
func _impactos() -> void:
	colocar_jugador(_claro)
	await avanzar_s(0.3)
	var p: Vector3 = jugador.position + DIR * Terreno3D.casilla * 1.3
	p.y = jugador.position.y
	var t: RayoToy = RayoToy.new()
	t.set("casilla", Terreno3D.casilla)
	maqueta.add_child(t)
	t.global_position = p + Vector3(0, 0.3, 0)
	var imp: Node3D = t.impactar_en(p, Vector3.UP)
	print("IMPACTO nodo=", imp, " pos=", imp.global_position if imp != null else "-", " jugador=", jugador.position, " p=", p)
	var ant: float = 0.0
	for tt in [0.06, 0.18, 0.4, 0.9]:
		await avanzar_s(float(tt) - ant)
		ant = float(tt)
		_foto("impacto_%03d" % int(round(float(tt) * 100.0)))
	await avanzar_s(1.0)


## ESTADO ELECTRIFICADO de una entidad: una reacción «electrocutado» sobre un goblin (o, si no hay, sobre un nodo suelto).
func _estado_entidad() -> void:
	colocar_jugador(_claro)
	await avanzar_s(0.3)
	var objetivo: Node3D = null
	var goblin: Node3D = jugador       # la jugadora: el goblin del claro no se ve (se descarga lejos del camino); la reacción es la misma
	if goblin != null:
		objetivo = goblin
	print("ENTIDAD ", objetivo, " grupo=", get_nodes_in_group("combate3d").size(), " jugador=", jugador.position)
	_ok("5 hay una entidad a la que electrificar", objetivo != null)
	if objetivo == null:
		return
	var m: Object = Mundo3D.actual
	_ok("5b hay Mundo3D con señal reaccion", m != null and m.has_signal("reaccion"))
	if m != null:
		m.emit_signal("reaccion", "electrocutado", objetivo.global_position + Vector3(0, 0.6, 0), objetivo)
	var tj3: Object = maqueta.find_child("VfxToyJuego", true, false)
	print("ELECTROCUTADOS=", int(tj3.get("electrocutados")) if tj3 != null else -1, " hijos=", objetivo.get_children().map(func(n: Node) -> String: return n.name), " pos_cuerpo=", (objetivo.get_parent() as Node3D).global_position if objetivo.get_parent() is Node3D else "-", " visible=", (objetivo.get_parent() as Node3D).is_visible_in_tree() if objetivo.get_parent() is Node3D else "-")
	for tt in [0.15, 0.5, 1.0]:
		await avanzar_s(0.25 if tt == 0.15 else 0.4)
		_foto("estado_entidad_%03d" % int(round(float(tt) * 100.0)))
	await avanzar_s(2.0)


## AGUA ELECTRIFICADA: unas casillas de agua del Bosque se electrifican con el reloj oficial (2 s).
func _estado_agua() -> void:
	var agua: Array = []
	for y in range(2, 40):
		for x in range(2, 44):
			var q := Vector2i(x, y)
			if Terreno3D.en_mapa(q) and Lanzador3D.es_agua(q):
				agua.append(q)
	_ok("6 el Bosque tiene agua", agua.size() > 0)
	if agua.is_empty():
		return
	var c0: Vector2i = agua[0]
	var mejor_n: int = -1
	for q0 in agua:
		var nn: int = 0
		for q1 in agua:
			if absi((q1 as Vector2i).x - (q0 as Vector2i).x) <= 2 and absi((q1 as Vector2i).y - (q0 as Vector2i).y) <= 2:
				nn += 1
		if nn > mejor_n:
			mejor_n = nn
			c0 = q0
	var celdas: Array = []
	for q in agua:
		if absi((q as Vector2i).x - c0.x) <= 2 and absi((q as Vector2i).y - c0.y) <= 2:
			celdas.append(q)
	# la jugadora, en tierra firme junto al agua
	var pie: Vector2i = Vector2i(-1, -1)
	var mejor: float = 1e9
	for dx in range(-5, 6):
		for dy in range(-5, 6):
			var q2 := Vector2i(c0.x + dx, c0.y + dy)
			if float(dx * dx + dy * dy) < mejor and Terreno3D.en_mapa(q2) and not Lanzador3D.es_agua(q2) and not Terreno3D.bloqueada(q2) and not Terreno3D.celda_solida(q2, 0):
				pie = q2
				mejor = float(dx * dx + dy * dy)
	if pie != Vector2i(-1, -1):
		colocar_jugador(pie)
	await avanzar_s(0.5)
	for q in celdas:
		Terreno3D.estados.mantener(q as Vector2i, EstadosSuelo3D.ELECTRIFICADA)
	var tj2: Object = maqueta.find_child("VfxToyJuego", true, false)
	print("AGUA c0=", c0, " pie=", pie, " celdas=", celdas.size(), " dibujadas=", (tj2.call("agua_electrica") as Dictionary).size() if tj2 != null else -1, " jugador=", jugador.position, " centro=", Terreno3D.centro_de(c0, 0.0))
	for tt in [0.1, 0.5, 1.0, 1.7]:
		await avanzar_s(0.1 if tt == 0.1 else 0.5 if tt == 0.5 else 0.5 if tt == 1.0 else 0.7)
		_foto("estado_agua_%03d" % int(round(float(tt) * 100.0)))
	await avanzar_s(2.0)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)


func _buscar_claro() -> Vector2i:
	for y in range(4, 38):
		for x in range(2, 40):
			var ok: bool = true
			var base: float = Terreno3D.y_pies(Vector2i(x, y))
			for dx in range(-1, 10):
				for dz in range(-2, 3):
					var q := Vector2i(x + dx, y + dz)
					if not Terreno3D.en_mapa(q) or Terreno3D.celda_solida(q, 0) or Terreno3D.bloqueada(q) or Lanzador3D.es_agua(q) or absf(Terreno3D.y_pies(q) - base) > 0.01:
						ok = false
						break
				if not ok:
					break
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

