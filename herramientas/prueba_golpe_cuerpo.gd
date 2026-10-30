extends "res://herramientas/escenario_base.gd"
## C1 · GOLPE CUERPO A CUERPO (28/10; docs/PROPUESTA_COMBATE.md §2 y §7; jugador/golpe_cuerpo.gd). Tecla F: golpe débil (5) que empuja mucho (≥ 2 casillas), sin gastar tinta.
##
## Va sobre la ESCENA REAL (PruebaBosque: Jugador3D, Lanzador3D, cámara) y por el camino REAL de entrada: la F (y 1, Ctrl, Esc) entran con `Input.parse_input_event(InputEventKey)`, que es lo que lee
## `Jugador3D._gestionar_acciones`. Goblins reales (`Combate3D`, sin IA: `quieto`), con su escudo real (`Escudo3D`), un jarrón (`Rompible3D`) y un bloque de piedra (`BloqueEmpujable3D`) colocados por código.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_golpe_cuerpo.gd

var _golpes: Array = []                 ## [{t, resumen}] de cada golpe que sale (señal golpe_cuerpo_dado)
var _sonidos: Array = []                ## rutas de los AudioStreamPlayer3D que han nacido
var _premios: Array = []                ## [tipo, tinta] de cada reacción premiada
var _comprobaciones: int = 0
var _goblins: Array = []
var _libre: Vector2i = Vector2i.ZERO    ## la casilla del claro donde está ella
const ESTE := Vector3(1, 0, 0)
const OESTE := Vector3(-1, 0, 0)
const NORTE := Vector3(0, 0, -1)
const SUR := Vector3(0, 0, 1)


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


# --- utilidades ----------------------------------------------------------------------------------------------------

func _tinta() -> float:
	return lanzador.tinta.actual if lanzador.tinta != null else 0.0


## F por el camino real: pulsada 2 fotogramas y soltada.
func _pulsar(tecla: Key = KEY_F) -> void:
	_tecla(tecla, true)
	await avanzar(2)
	_tecla(tecla, false)
	await avanzar(1)


func _mirar(dir: Vector3) -> void:
	jugador.set("_mirada", dir)
	(jugador.get("pj") as Pj3D).mirar(dir, 1.0)


## El centro de la casilla a `n` casillas de la jugadora hacia `dir` (cardinal).
func _celda_a(dir: Vector3, n: int) -> Vector2i:
	return celda_jugador() + Vector2i(int(round(dir.x)), int(round(dir.z))) * n


func _pos_celda(c: Vector2i) -> Vector3:
	return Terreno3D.centro_de(c, Terreno3D.y_pies(c))


func _goblin(p: Vector3, mira: Vector3 = Vector3(0, 0, 1)) -> Combate3D:
	var modelo := Pj3D.new()
	maqueta.add_child(modelo)
	modelo.cargar("goblin_warrior_chibi")
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	modelo.set_alto(0.85)
	modelo.position = p
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.mirada = mira
	g.health = 100.0
	g.vida_max = 100.0
	_goblins.append(g)
	return g


func _quitar(g: Node) -> void:
	if g != null and is_instance_valid(g):
		if g is Combate3D and (g as Combate3D).pj != null and is_instance_valid((g as Combate3D).pj):
			(g as Combate3D).pj.queue_free()
		g.queue_free()
	_goblins.erase(g)


func _es_honda(c: Vector2i) -> bool:
	if not Terreno3D.en_mapa(c) or Terreno3D.letra_de(c) == "b" or not Terreno3D.se_nada(c):
		return false
	return Terreno3D.agua_sim == null or Terreno3D.agua_sim.se_nada_en(c)


func _suelo_llano(c: Vector2i, n0: int) -> bool:
	return Terreno3D.en_mapa(c) and not Terreno3D.es_agua(c) and not Terreno3D.bloqueada(c) and Terreno3D.altura_en(c) == n0


## Un claro llano de (2r+1)² casillas lo más cerca de la jugadora, y se pone a la jugadora en su centro.
func _buscar_claro(r: int) -> bool:
	var ancho: int = int(maqueta.get("_ancho"))
	var alto: int = int(maqueta.get("_alto"))
	var desde: Vector2i = celda_jugador()
	var mejor: Vector2i = Vector2i(-1, -1)
	var dmejor: float = INF
	for y in range(r, alto - r):
		for x in range(r, ancho - r):
			var c := Vector2i(x, y)
			var n0: int = Terreno3D.altura_en(c)
			var bien: bool = true
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if not _suelo_llano(c + Vector2i(dx, dy), n0):
						bien = false
						break
				if not bien:
					break
			if bien and Vector2(c - desde).length() < dmejor:
				dmejor = Vector2(c - desde).length()
				mejor = c
	if mejor.x < 0:
		return false
	colocar_jugador(mejor)
	_libre = mejor
	return true


## Un sitio donde el agua honda está a 3 casillas llanas de distancia en línea: {agua, dir, nivel}. Devuelve {} si no hay.
func _buscar_orilla() -> Dictionary:
	var ancho: int = int(maqueta.get("_ancho"))
	var alto: int = int(maqueta.get("_alto"))
	for y in range(4, alto - 4):
		for x in range(4, ancho - 4):
			var c := Vector2i(x, y)
			if not _es_honda(c):
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n0: int = Terreno3D.altura_en(c - d)
				if _suelo_llano(c - d, n0) and _suelo_llano(c - d * 2, n0) and _suelo_llano(c - d * 3, n0) and _suelo_llano(c - d * 4, n0):
					return {"agua": c, "dir": d}
	return {}


## Pulsa F y espera a que el golpe termine; devuelve cuánto recorrió `g` (u) tras `espera` s.
func _golpear_y_medir(g: Combate3D, espera: float = 1.4) -> float:
	var p0: Vector3 = g.position
	await _pulsar()
	await avanzar_s(espera)
	return Vector2(g.position.x - p0.x, g.position.z - p0.z).length()


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	var casilla: float = Terreno3D.casilla
	jugador.golpe_cuerpo_dado.connect(func(r: Dictionary) -> void: _golpes.append({"t": reloj.t, "r": r}))
	node_added.connect(func(n: Node) -> void:
		if n is AudioStreamPlayer3D:
			_sonidos.append(n))
	jugador.tinta.reaccion_premiada.connect(func(t: String, c: float) -> void: _premios.append([t, c]))
	for n in get_nodes_in_group("combate3d"):         # nadie más: los goblins del bosque no pintan nada aquí
		(n as Combate3D).quieto = true
		(n as Combate3D).position = Vector3(-500.0, 0.0, -500.0)
	_ok("0 hay cámara, libro cerrado y F no estaba usada por el juego (solo por laboratorios)", lanzador.camara != null and not lanzador.libro_abierto())
	_ok("0 los valores: cooldown 0,8 s, duración 0,45 s, daño 5, alcance 1 casilla, cono 70°", is_equal_approx(GolpeCuerpo.CD, 0.8) and is_equal_approx(GolpeCuerpo.DUR, 0.45)
		and is_equal_approx(GolpeCuerpo.DANO, 5.0) and is_equal_approx(GolpeCuerpo.ALCANCE_CASILLAS, 1.0) and is_equal_approx(GolpeCuerpo.ANGULO, 70.0))
	var hay: bool = _buscar_claro(4)
	if not hay:
		hay = _buscar_claro(3)
	_ok("0 hay un claro llano donde probar", hay)
	if not hay:
		return
	await avanzar(40)
	_mirar(ESTE)
	await avanzar(3)
	var origen: Vector3 = jugador.position
	var tinta_uno: float = _tinta()
	var hud: String = (jugador.get("_hud_texto") as Label).text if jugador.get("_hud_texto") != null else ""
	_ok("0 el texto de controles en pantalla lista «F golpe»", hud.contains("F golpe"), hud.get_slice("\n", 1))

	# --- 0b · geometría del cono (puro) ---
	var o := Vector3.ZERO
	var m := Vector3(1, 0, 0)
	_ok("0b en el cono: de frente a 1 casilla, y a 25° dentro del alcance", GolpeCuerpo.en_cono(o, m, Vector3(casilla, 0, 0), 0.32)
		and GolpeCuerpo.en_cono(o, m, Vector3(cos(deg_to_rad(25.0)), 0, sin(deg_to_rad(25.0))) * 2.0, 0.32))
	_ok("0b fuera: a 50° del eje, detrás, de lado y a 2 casillas", not GolpeCuerpo.en_cono(o, m, Vector3(cos(deg_to_rad(50.0)), 0, sin(deg_to_rad(50.0))) * 2.0, 0.32)
		and not GolpeCuerpo.en_cono(o, m, Vector3(-casilla, 0, 0), 0.32) and not GolpeCuerpo.en_cono(o, m, Vector3(0, 0, casilla), 0.32)
		and not GolpeCuerpo.en_cono(o, m, Vector3(2.0 * casilla, 0, 0), 0.32))
	_ok("0b la dirección cardinal es la del eje dominante", GolpeCuerpo.cardinal(Vector3(0.9, 0, 0.4)) == Vector2i(1, 0) and GolpeCuerpo.cardinal(Vector3(-0.3, 0, -0.9)) == Vector2i(0, -1))

	# --- 1 · el goblin de delante: se aleja ≥ 2 casillas, 5 de daño, la tinta no baja ---
	var g1: Combate3D = _goblin(_pos_celda(_celda_a(ESTE, 1)), OESTE)
	var v0: float = g1.v0_de_empuje(GolpeCuerpo.EMPUJE, true)
	var prev: Dictionary = g1.prever_empuje([ESTE * v0])
	_ok("1 previsión (A2): el empujón lo lleva ≥ 2 casillas en suelo libre", float(prev["recorrido"]) >= 2.0 * casilla and not bool(prev["hundira"]),
		"%.2f u = %.2f casillas" % [float(prev["recorrido"]), float(prev["recorrido"]) / casilla])
	_golpes.clear()
	_sonidos.clear()
	var t0: float = reloj.t
	await _pulsar()
	await avanzar(1)
	_ok("1 F empieza el golpe: suena el clip de empujar con las dos manos (estado «golpe_cuerpo», MageSoellCast001)", jugador.golpeando() and jugador.pj.estado_anim() == "golpe_cuerpo"
		and jugador.pj.clip_actual() == "MageSoellCast001", "%s / %s" % [jugador.pj.estado_anim(), jugador.pj.clip_actual()])
	_ok("1 la jugadora no se mueve mientras golpea", jugador.position.distance_to(origen) < 0.02, "%.3f" % jugador.position.distance_to(origen))
	await avanzar_s(0.7)
	var recorrido: float = Vector2(g1.position.x - _pos_celda(_celda_a(ESTE, 1)).x, g1.position.z - _pos_celda(_celda_a(ESTE, 1)).z).length()
	_ok("1 el golpe sale una sola vez, hacia el este, y toca 1 enemigo", _golpes.size() == 1 and int(_golpes[0]["r"]["enemigos"]) == 1, str(_golpes))
	var retardo: float = float(_golpes[0]["t"]) - t0 if _golpes.size() > 0 else -1.0
	_ok("1 el impacto cae en el instante del clip en que extiende las manos (~%.2f s tras pulsar)" % Pj3D.golpe_retardo(GolpeCuerpo.DUR), absf(retardo - Pj3D.golpe_retardo(GolpeCuerpo.DUR)) < 0.2,
		"retardo %.2f" % retardo)
	_ok("1 el goblin se aleja ≥ 2 casillas", recorrido >= 2.0 * casilla, "%.2f u = %.2f casillas (previsto %.2f)" % [recorrido, recorrido / casilla, float(prev["recorrido"])])
	_ok("1 y a favor del golpe (este)", g1.position.x > _pos_celda(_celda_a(ESTE, 1)).x + 2.0 * casilla - 0.05 and absf(g1.position.z - _pos_celda(_celda_a(ESTE, 1)).z) < 0.3)
	# 29/10, DANO_Y_TINTA: el golpe F (5) pasa por la defensa: goblin DEF 2 → 3; con escudo equipado DEF 5 → suelo del 20 % = 1.
	_ok("1 recibe 3 de daño (5 − DEF 2; 100 → 97), sin debilidades", is_equal_approx(g1.health, 97.0), "%.2f" % g1.health)
	_ok("1 pasa por la reacción «empujado» de siempre (vuela y se levanta)", g1.en_empujado() or g1.fase_empuje() != Combate3D.FASE_NINGUNA or g1.pj.estado_anim() == "empujado" or g1.pj.estado_anim() == "levantarse"
		or g1.pj.estado_anim() == "idle", "estado %s" % g1.pj.estado_anim())
	_ok("1 la tinta no baja (no gasta)", _tinta() >= tinta_uno - 0.001, "%.2f → %.2f" % [tinta_uno, _tinta()])
	var suenan: bool = false
	for p in _sonidos:
		if is_instance_valid(p) and (p as AudioStreamPlayer3D).stream != null and (p as AudioStreamPlayer3D).stream.resource_path.contains("clavar"):
			suenan = true
	_ok("1 suena el golpe seco (Sfx «clavar» existente)", suenan, "%d reproductores nuevos" % _sonidos.size())
	var ev: Array = eventos("golpe")
	_ok("1 el PlayLog apunta «golpe» con lo que tocó", ev.size() >= 1 and int((ev[ev.size() - 1] as Dictionary).get("enemigos", 0)) == 1 and (ev[ev.size() - 1] as Dictionary).has("rompibles")
		and (ev[ev.size() - 1] as Dictionary).has("bloques"), str(ev.back()) if ev.size() > 0 else "sin eventos")
	var ev_i: Array = eventos("golpe_inicio")
	_ok("1 y «golpe_inicio» dice que había clip", ev_i.size() >= 1 and bool((ev_i[ev_i.size() - 1] as Dictionary).get("clip", false)))
	_quitar(g1)

	# --- 2 · cooldown: dentro de 0,8 s no golpea; pasado, sí ---
	await avanzar_s(0.9)                                        # que se acabe el cooldown del golpe 1 y lo que quede de él
	var g2: Combate3D = _goblin(_pos_celda(_celda_a(ESTE, 1)), OESTE)
	_golpes.clear()
	t0 = reloj.t
	await _pulsar()
	await avanzar_s(0.5)
	var antes_cd: int = _golpes.size()
	_ok("2 el primer golpe sale", antes_cd == 1)
	await avanzar_s(0.1)
	var t_dentro: float = reloj.t - t0
	await _pulsar()                                              # ~0,6-0,7 s tras el primero (dentro de los 0,8 s)
	await avanzar_s(0.4)
	_ok("2 F dentro del cooldown (a los %.2f s) no golpea" % t_dentro, _golpes.size() == 1 and not jugador.golpeando() and t_dentro < GolpeCuerpo.CD, "%d golpes" % _golpes.size())
	await avanzar_s(0.5)
	await _pulsar()
	await avanzar_s(0.7)
	_ok("2 pasado el cooldown vuelve a golpear", _golpes.size() == 2, "%d golpes" % _golpes.size())
	_quitar(g2)
	await avanzar_s(0.9)

	# --- 3 · lo que NO toca: detrás, fuera del cono, fuera del alcance ---
	var g_det: Combate3D = _goblin(_pos_celda(_celda_a(OESTE, 1)), ESTE)
	var g_flanco: Combate3D = _goblin(jugador.position + Vector3(cos(deg_to_rad(55.0)), 0, sin(deg_to_rad(55.0))) * 2.0, OESTE)
	var g_lejos: Combate3D = _goblin(_pos_celda(_celda_a(ESTE, 2)) + Vector3(0.6, 0, 0), OESTE)
	var pos_det: Vector3 = g_det.position
	var pos_fl: Vector3 = g_flanco.position
	var pos_lejos: Vector3 = g_lejos.position
	_golpes.clear()
	await _pulsar()
	await avanzar_s(1.0)
	_ok("3 el golpe sale pero no toca a nadie", _golpes.size() == 1 and int(_golpes[0]["r"]["enemigos"]) == 0, str(_golpes))
	_ok("3 el goblin DETRÁS no se entera (ni se mueve ni pierde vida)", g_det.position.distance_to(pos_det) < 0.01 and is_equal_approx(g_det.health, 100.0) and not g_det.en_empujado())
	_ok("3 el goblin a 55° (fuera del cono de 70°) no se entera", g_flanco.position.distance_to(pos_fl) < 0.01 and is_equal_approx(g_flanco.health, 100.0))
	_ok("3 el goblin a más de 1 casilla de alcance no se entera", g_lejos.position.distance_to(pos_lejos) < 0.01 and is_equal_approx(g_lejos.health, 100.0))
	for g in [g_det, g_flanco, g_lejos]:
		_quitar(g)
	await avanzar_s(0.9)

	# --- 4 · el escudo de frente: empuja la mitad y no hace daño; quemado, lo tumba ---
	var g_sin: Combate3D = _goblin(_pos_celda(_celda_a(ESTE, 1)), OESTE)
	var libre_u: float = await _golpear_y_medir(g_sin)
	_ok("4 (control) sin escudo recorre ≥ 2 casillas", libre_u >= 2.0 * casilla, "%.2f u" % libre_u)
	_quitar(g_sin)
	await avanzar_s(0.9)
	var g_esc: Combate3D = _goblin(_pos_celda(_celda_a(ESTE, 1)), OESTE)       # mira hacia ella: le da el escudo de frente
	var esc: Escudo3D = Escudo3D.equipar(g_esc, false)
	var escudo_u: float = await _golpear_y_medir(g_esc)
	_ok("4 con el escudo de frente no hay daño", is_equal_approx(g_esc.health, 100.0), "%.2f" % g_esc.health)
	_ok("4 y empuja menos: la mitad (±0,15) de lo que empuja sin escudo", escudo_u > 0.2 * casilla and absf(escudo_u / libre_u - 0.5) < 0.15, "%.2f u frente a %.2f (%.2f)" % [escudo_u, libre_u, escudo_u / libre_u])
	_ok("4 el golpe cuenta como bloqueo del escudo y lo dice el resumen", esc.bloqueos == 1 and int(_golpes.back()["r"]["escudos"]) == 1)
	_quitar(g_esc)
	await avanzar_s(0.9)
	var g_q: Combate3D = _goblin(_pos_celda(_celda_a(ESTE, 1)), OESTE)
	var esc_q: Escudo3D = Escudo3D.equipar(g_q, false)
	esc_q.estado = "quemado"
	var q_u: float = await _golpear_y_medir(g_q)
	_ok("4 con el escudo QUEMADO no protege: daño 1 (5 con DEF 5 → suelo) y empuje completo", is_equal_approx(g_q.health, 99.0) and q_u >= 2.0 * casilla, "%.2f hp, %.2f u" % [g_q.health, q_u])
	_quitar(g_q)
	await avanzar_s(0.9)
	var g_esp: Combate3D = _goblin(_pos_celda(_celda_a(ESTE, 1)), ESTE)       # de espaldas a ella: el escudo no lo cubre
	Escudo3D.equipar(g_esp, false)
	var esp_u: float = await _golpear_y_medir(g_esp)
	_ok("4 con el escudo A LA ESPALDA no protege: daño 1 (DEF 5 → suelo) y empuje completo", is_equal_approx(g_esp.health, 99.0) and esp_u >= 2.0 * casilla, "%.2f hp, %.2f u" % [g_esp.health, esp_u])
	_quitar(g_esp)
	await avanzar_s(0.9)

	# --- 5 · interrumpe el ataque en curso ---
	var g_at: Combate3D = _goblin(_pos_celda(_celda_a(ESTE, 1)), OESTE)
	var disparado: Array = [false]
	g_at._iniciar_ataque(1.0, 0.8, func() -> void: disparado[0] = true)
	_ok("5 (control) está atacando y el golpe aún no ha salido", g_at._ataque > 0.0 and g_at._golpe_pendiente)
	await _pulsar()
	await avanzar_s(0.6)
	_ok("5 el golpe de la jugadora le cancela el ataque (no sale su golpe)", g_at._ataque <= 0.0 and not g_at._golpe_pendiente and not disparado[0])
	_quitar(g_at)
	await avanzar_s(0.9)

	# --- 6 · un enemigo con `empujable_golpe` false (el gólem, cuando exista) recibe daño pero no se mueve ---
	var g_masa: Combate3D = _goblin(_pos_celda(_celda_a(ESTE, 1)), OESTE)
	g_masa.empujable_golpe = false
	var masa_u: float = await _golpear_y_medir(g_masa)
	_ok("6 con `empujable_golpe` = false no se mueve, pero recibe el daño", masa_u < 0.05 and is_equal_approx(g_masa.health, 97.0), "%.3f u, %.1f hp" % [masa_u, g_masa.health])
	_quitar(g_masa)
	await avanzar_s(0.9)

	# --- 7 · el jarrón se rompe ---
	_mirar(NORTE)
	var c_jarron: Vector2i = _celda_a(NORTE, 1)
	var jarron := Rompible3D.new()
	jarron.name = "jarron_golpe"
	jarron.preparar(c_jarron, "jarron", "nada", 0, false, "Bosque", maqueta)
	maqueta.add_child(jarron)
	var otro := Rompible3D.new()                                   # un jarrón detrás: no se entera
	otro.name = "jarron_detras"
	otro.preparar(_celda_a(SUR, 1), "jarron", "nada", 0, false, "Bosque", maqueta)
	maqueta.add_child(otro)
	await avanzar(3)
	await _pulsar()
	await avanzar_s(0.7)
	_ok("7 el jarrón de delante se rompe", jarron.roto_ya)
	_ok("7 el de detrás sigue entero", not otro.roto_ya)
	var ev7: Array = eventos("golpe")
	_ok("7 el PlayLog cuenta el rompible", ev7.size() > 0 and int((ev7[ev7.size() - 1] as Dictionary).get("rompibles", 0)) == 1)
	await avanzar_s(0.5)

	# --- 8 · cosas a las que no hace nada: una placa de peso (Area), una fogata ---
	# (el golpe solo recorre enemigos, rompibles y bloques: lo demás no se consulta). Lo comprobamos con la lista de objetivos.
	var ob: Dictionary = GolpeCuerpo.objetivos(self, jugador.position, NORTE)
	_ok("8 la lista de objetivos solo tiene enemigos, rompibles, bloques y sacudibles (F1)", ob.keys().size() == 4 and (ob["sacudibles"] as Array).is_empty() and (ob["enemigos"] as Array).is_empty() and (ob["bloques"] as Array).is_empty())
	await avanzar_s(0.3)

	# --- 9 · estados que bloquean: rodando, con el modo de lanzar activo (nadando, más abajo, en el agua de verdad) ---
	await avanzar_s(0.9)
	var g_b: Combate3D = _goblin(_pos_celda(_celda_a(NORTE, 1)), SUR)
	_mirar(NORTE)
	_golpes.clear()
	_tecla(KEY_CTRL, true)                                         # rodando
	await avanzar(2)
	_tecla(KEY_CTRL, false)
	_ok("9 (control) la voltereta ha empezado", jugador.get("_t_roll") > 0.0)
	await _pulsar()
	await avanzar_s(0.1)
	_ok("9 rodando, F no golpea", _golpes.is_empty() and not jugador.golpeando() and is_equal_approx(g_b.health, 100.0))
	await avanzar_s(1.5)
	colocar_jugador(_libre)
	g_b.position = _pos_celda(_celda_a(NORTE, 1))
	_mirar(NORTE)
	await avanzar_s(1.0)
	_golpes.clear()
	_preparar_hechizo()
	_tecla(KEY_1, true)                                            # apuntando (modo lanzar rápido)
	await avanzar(3)
	_ok("9 (control) está en el modo de lanzar", lanzador.modo_lanzar)
	await _pulsar()
	await avanzar_s(0.2)
	_ok("9 con el modo de lanzar activo, F no golpea", _golpes.is_empty() and not jugador.golpeando() and is_equal_approx(g_b.health, 100.0))
	_tecla(KEY_ESCAPE, true)
	await avanzar(1)
	_tecla(KEY_ESCAPE, false)
	_tecla(KEY_1, false)
	await avanzar_s(1.0)
	_ok("9 salido del modo (Esc), no queda en modo de lanzar", not lanzador.modo_lanzar)
	_golpes.clear()
	await _pulsar()
	await avanzar_s(0.7)
	_ok("9 y de nuevo golpea (y el goblin de delante lo recibe)", _golpes.size() == 1 and int(_golpes[0]["r"]["enemigos"]) == 1 and is_equal_approx(g_b.health, 97.0), str(_golpes))
	_quitar(g_b)
	await avanzar_s(0.9)

	# --- 10 · el goblin junto al agua honda se hunde y da +20 de tinta (C2) ---
	var orilla: Dictionary = _buscar_orilla()
	_ok("10 hay una orilla con agua honda y 4 casillas llanas en línea donde probar", not orilla.is_empty())
	if not orilla.is_empty():
		var d2: Vector2i = orilla["dir"]
		var c_agua: Vector2i = orilla["agua"]
		var d3 := Vector3(float(d2.x), 0.0, float(d2.y))
		colocar_jugador(c_agua - d2 * 2)
		await avanzar(40)
		_mirar(d3)
		await avanzar_s(0.5)
		var g_ag: Combate3D = _goblin(_pos_celda(c_agua - d2), -d3)
		var hundido: Array = [false]
		g_ag.hundido.connect(func(_e: Combate3D) -> void: hundido[0] = true)
		lanzador.tinta.actual = 0.0
		_premios.clear()
		var hundira: bool = bool(g_ag.prever_empuje([d3 * g_ag.v0_de_empuje(GolpeCuerpo.EMPUJE, true)])["hundira"])
		_ok("10 la previsión (A2) ya dice que se hunde", hundira)
		await _pulsar()
		await avanzar_s(1.0)
		_ok("10 el goblin se hunde en el agua honda (señal `hundido`)", bool(hundido[0]), "hundido %s" % str(hundido[0]))
		await avanzar_s(0.5)
		_ok("10 y la tinta sube +20 por «hundido» (C2)", _premios.size() == 1 and _premios[0][0] == "hundido" and is_equal_approx(float(_premios[0][1]), 20.0), str(_premios))
		_ok("10 sin gastar nada: la barra solo subió", _tinta() >= 20.0 - 0.001, "%.2f" % _tinta())
		await avanzar_s(4.0)
		_goblins.erase(g_ag)

		# --- 9b · nadando, F no golpea (de verdad en el agua honda) ---
		var g_n: Combate3D = _goblin(_pos_celda(c_agua - d2), -d3)
		colocar_jugador(c_agua)
		await avanzar_s(1.5)
		_golpes.clear()
		_mirar(d3)
		var nada: bool = bool(jugador.get("nadando"))
		_ok("9b (control) la jugadora está nadando en el agua honda", nada)
		await _pulsar()
		await avanzar_s(0.3)
		_ok("9b nadando, F no golpea", _golpes.is_empty() and not jugador.golpeando())
		_quitar(g_n)

		# --- 11 · el bloque de piedra avanza UNA casilla en la dirección del golpe; el hielo resbala ---
		colocar_jugador(_libre)
		await avanzar(30)
		_mirar(OESTE)
		await avanzar_s(0.6)
		var c_b: Vector2i = _celda_a(OESTE, 1)
		var bloque := BloqueEmpujable3D.new()
		bloque.preparar(c_b, "piedra", maqueta)
		maqueta.add_child(bloque)
		await avanzar(3)
		var pos_j: Vector3 = jugador.position
		_golpes.clear()
		await _pulsar()
		await avanzar_s(3.6)
		_ok("11 el bloque de piedra avanza UNA casilla hacia el oeste (la dirección del golpe)", bloque.celda == c_b + Vector2i(-1, 0) and not bloque.moviendo, "celda %s, desde %s" % [bloque.celda, c_b])
		_ok("11 la jugadora no se mueve con él", jugador.position.distance_to(pos_j) < 0.05)
		_ok("11 el resumen cuenta el bloque", _golpes.size() == 1 and int(_golpes[0]["r"]["bloques"]) == 1 and int(_golpes[0]["r"]["movidos"]) == 1, str(_golpes))
		_golpes.clear()
		await avanzar_s(0.9)
		await _pulsar()
		await avanzar_s(0.7)
		_ok("11 un segundo golpe: el bloque ya está a 2 casillas, fuera del alcance: no se mueve más", bloque.celda == c_b + Vector2i(-1, 0))
		var c_h: Vector2i = _celda_a(SUR, 1)
		var hielo := BloqueEmpujable3D.new()
		hielo.preparar(c_h, "hielo", maqueta)
		maqueta.add_child(hielo)
		await avanzar(3)
		_mirar(SUR)
		await avanzar_s(0.9)
		await _pulsar()
		await avanzar_s(2.5)
		_ok("11 el bloque de hielo RESBALA (≥ 3 casillas hacia el sur, como con el viento; la piedra solo 1)", hielo.celda.y >= c_h.y + 3 and hielo.celda.x == c_h.x, "celda %s, desde %s, moviendo %s" % [hielo.celda, c_h, str(hielo.moviendo)])
		bloque.queue_free()
		hielo.queue_free()

	print("%d comprobaciones" % _comprobaciones)


func _preparar_hechizo() -> void:
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element("fuego")
	lanzador.place_sigil("flecha")
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
