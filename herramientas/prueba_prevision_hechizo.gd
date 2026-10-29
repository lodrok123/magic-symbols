extends "res://herramientas/escenario_base.gd"
## A2 · PREVISIÓN «EN SECO» DEL HECHIZO (28/10; docs/PROPUESTA_COMBATE.md §1.2 y §7; magia/prevision_hechizo.gd).
## Compara, CASO POR CASO, lo que `PrevisionHechizo.prever` dice que pasaría con lo que pasa de verdad al lanzar por el camino real (`Lanzador3D.lanzar_ahora`, el que usan el libro y el
## lanzamiento rápido) sobre la ESCENA REAL (PruebaBosque: Jugador3D, Lanzador3D, simulación de agua, autómata de la hierba). En cada caso: monta, predice (dos veces, y comprueba que no cambió NADA),
## lanza, espera y mira que lo previsto ocurrió y que no ocurrió nada de lo no previsto en esas casillas.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_prevision_hechizo.gd

const ORILLA_X: int = 8          ## columna de tierra pegada al agua honda (x = 7) en las filas 30–34 del Bosque
var _comprobaciones: int = 0
var _reacciones: Array = []      ## [{nombre, nodo}] de lo que avisa Mundo3D.reaccion durante un caso
var _creados: Array = []         ## nodos de un caso, para quitarlos al acabar
var _tiempos_us: Array = []


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


# --- montaje -------------------------------------------------------------------------------------------------------

func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _goblin(c: Vector2i, debil: String = "", resiste: String = "", escudo: bool = false, de_frente: bool = true) -> Combate3D:
	var p: Vector3 = _pos(c)
	var modelo: Pj3D = maqueta.call("_personaje", ["goblin_warrior_chibi"], p)
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.mirada = Vector3(1, 0, 0) if de_frente else Vector3(-1, 0, 0)       # de cara a quien dispara desde el este (o de espaldas a él)
	g.health = 100000.0
	g.vida_max = 100000.0
	g.debil = debil
	g.resiste = resiste
	if escudo:
		Escudo3D.equipar(g)
	_creados.append(g)
	_creados.append(modelo)
	return g


func _reactivo(tipo: String, c: Vector2i) -> Reactivo3D:
	var r := Reactivo3D.new()
	r.preparar(tipo, c, "", lanzador.fx, null)
	r.position = _pos(c)
	maqueta.add_child(r)
	_creados.append(r)
	return r


## Avanza fotogramas hasta que `cond` sea verdadera o pasen `max_s` s de juego. Devuelve si se cumplió.
func _esperar(cond: Callable, max_s: float = 4.0) -> bool:
	var t: float = 0.0
	while t < max_s:
		if bool(cond.call()):
			return true
		t += await avanzar_s(0.1)
	return bool(cond.call())


## Para cada reacción de SUELO prevista sobre suelo desnudo (no hierba ni agua), mira que el estado de la casilla sea el previsto.
func _comprobar_suelo(nombre: String, prev: Array[Dictionary], exigir: bool = true) -> void:
	var visto: bool = false
	for x in prev:
		if String(x["que"]) != "suelo" or String((x["extra"] as Dictionary).get("clase", "")) != "suelo":
			continue
		var c: Vector2i = x["celda"]
		var est: String = ""
		match String(x["reaccion"]):
			"hiela":
				est = EstadosSuelo3D.HELADA
			"moja":
				est = EstadosSuelo3D.MOJADA
		if est == "":
			continue
		visto = true
		_ok("%s: la casilla %s de verdad queda «%s» (%s)" % [nombre, str(c), String(x["reaccion"]), est], Terreno3D.estados.tiene(c, est), str(Array(EstadosSuelo3D.TODOS).filter(func(t): return Terreno3D.estados.tiene(c, t))))
	_ok("%s: había alguna reacción de suelo desnudo que comprobar" % nombre, visto or not exigir)


## Las casillas de la zona de pruebas con ese estado de suelo (ordenadas).
func _con_estado(estado: String) -> Array:
	var r: Array = []
	for y in range(26, 37):
		for x in range(3, 14):
			if Terreno3D.estados.tiene(Vector2i(x, y), estado):
				r.append(Vector2i(x, y))
	return r


## Los hechizos con un proyectil todavía en vuelo.
func _vivos() -> Array:
	return lanzador.get_children().filter(func(n): return n is HechizoVivo and n.activo)


func _limpiar() -> void:
	for n in _creados:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_creados.clear()
	for z in lanzador._zonas_v2.duplicate():          # las zonas de fuego, gas… de un caso siguen un rato: no deben herir al goblin del siguiente
		if is_instance_valid(z):
			(z as Node).queue_free()
	for sd in lanzador._solideces_v2.duplicate():
		if is_instance_valid(sd):
			(sd as Node).queue_free()


## La jugadora a `c`, mirando al oeste; el libro vacío con la receta pedida; devuelve lo preparado (`_preparado`).
func _preparar(c: Vector2i, elemento: String, glifos: Array) -> Dictionary:
	colocar_jugador(c)
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
	lanzador.cast_page(0)
	return lanzador._preparado


## Lanza lo preparado por el camino real (lo que hace `lanzar_pagina_ya` tras `cast_page`).
func _lanzar_real(datos: Dictionary, dir: Vector3, origen: Vector3 = Vector3.INF) -> bool:
	var d: Dictionary = datos
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	return lanzador.lanzar_ahora(d, jugador.position if origen == Vector3.INF else origen, dir)


# --- la foto del estado: lo que `prever` NO debe tocar ------------------------------------------------------------

func _foto() -> Dictionary:
	var f: Dictionary = {}
	var gs: Array = []
	for n in get_nodes_in_group("combate3d"):
		var g: Combate3D = n as Combate3D
		if g == null:
			continue
		gs.append([g.health, g.quemando, g.mojado, g.congelado, g.lento, g.stun_timer, g.interrupcion, g.position, g._empuje, g.muerto, g._fase_empuje, g.envenenado,
			g.escudo.estado if g.escudo != null else "", g.escudo.vida if g.escudo != null else 0.0, g.escudo.bloqueos if g.escudo != null else 0, g.escudo.mojado_t if g.escudo != null else 0.0])
	f["goblins"] = gs
	var rs: Array = []
	for n in get_nodes_in_group("reactivo3d"):
		rs.append([n.get("estado"), n.get("is_lit"), n.get("activo"), n.get("_mojado_s"), n.get("recibidos"), n.get("celda"), n.get("roto_ya")])
	f["reactivos"] = rs
	var est: Array = []
	for st in EstadosSuelo3D.TODOS:
		var cs: Array = []
		for c in (Terreno3D.estados._celdas.get(st, {}) as Dictionary).keys():
			cs.append(c)
		cs.sort()
		est.append([st, cs])
	f["estados"] = est
	var hf: Variant = maqueta.get("_hf")
	f["hierba"] = (hf as Dictionary).duplicate(true).size() if hf is Dictionary else -1
	var fases: Array = []
	if hf is Dictionary:
		for k in (hf as Dictionary):
			fases.append([k, int(((hf as Dictionary)[k] as Dictionary)["fase"])])
		fases.sort()
	f["fases"] = fases
	f["nodos"] = get_node_count()
	f["campos"] = lanzador._campos.size()
	f["zonas"] = lanzador._zonas_v2.size()
	f["solideces"] = lanzador._solideces_v2.size()
	f["bloques"] = lanzador._bloques.size()
	f["hielo"] = lanzador._hielo.size()
	f["tinta"] = lanzador.tinta.actual if lanzador.tinta != null else -1.0
	f["recarga"] = lanzador.cooldown_left.duplicate()
	f["sonidos"] = lanzador.sonidos_fase.size()
	f["agua"] = _agua_total()
	f["helada"] = _heladas()
	f["lavas"] = _lavas()
	return f


func _agua_total() -> float:
	var t: float = 0.0
	for y in range(28, 36):
		for x in range(5, 13):
			t += Terreno3D.agua_sim.profundidad_casilla(Vector2i(x, y))
	return snappedf(t, 0.0001)


func _heladas() -> Array:
	var r: Array = []
	for y in range(28, 36):
		for x in range(5, 13):
			if Terreno3D.helada(Vector2i(x, y)):
				r.append(Vector2i(x, y))
	return r


func _lavas() -> Array:
	var r: Array = []
	for n in get_nodes_in_group("lava3d"):
		r.append([(n as Lava3D)._lava.size(), (n as Lava3D)._roca.size()])
	return r


# --- predecir ----------------------------------------------------------------------------------------------------

## Predice dos veces (comprueba que no cambió nada) y mide el coste. Devuelve la previsión.
func _predecir(nombre: String, datos: Dictionary, dir: Vector3, origen: Vector3 = Vector3.INF) -> Array[Dictionary]:
	var antes: Dictionary = _foto()
	var emitidas: Array = [0]
	var cuenta := func(_a = null, _b = null, _c = null, _d = null, _e = null, _f = null) -> void: emitidas[0] += 1
	var m3: Mundo3D = Mundo3D.actual
	m3.reaccion.connect(cuenta)
	m3.impacto.connect(cuenta)
	lanzador.hechizo_v2.connect(cuenta)
	lanzador.lanzado.connect(cuenta)
	var t0: int = Time.get_ticks_usec()
	var o: Vector3 = jugador.position if origen == Vector3.INF else origen
	var p1: Array[Dictionary] = PrevisionHechizo.prever(lanzador, datos, o, dir)
	_tiempos_us.append(Time.get_ticks_usec() - t0)
	var p2: Array[Dictionary] = PrevisionHechizo.prever(lanzador, datos, o, dir)
	m3.reaccion.disconnect(cuenta)
	m3.impacto.disconnect(cuenta)
	lanzador.hechizo_v2.disconnect(cuenta)
	lanzador.lanzado.disconnect(cuenta)
	var despues: Dictionary = _foto()
	var igual: bool = true
	var cual: String = ""
	for k in antes:
		if str(antes[k]) != str(despues[k]):
			igual = false
			cual += k + " "
	_ok("%s · prever NO cambia nada (estado, nodos, tinta, recarga, sonidos)" % nombre, igual, "cambió: " + cual)
	_ok("%s · prever no emite señales (reaccion, impacto, hechizo_v2, lanzado)" % nombre, emitidas[0] == 0, str(emitidas[0]))
	_ok("%s · dos previsiones seguidas dicen lo mismo" % nombre, _resumen(p1) == _resumen(p2), _resumen(p1) + " | " + _resumen(p2))
	return p1


func _resumen(p: Array[Dictionary]) -> String:
	var s: PackedStringArray = []
	for e in p:
		s.append("%s:%s@%s x%.1f" % [e["que"], e["reaccion"], e["celda"], float(e["mult"])])
	return ", ".join(s)


func _entrada(p: Array[Dictionary], que: String, nodo: Variant = null) -> Dictionary:
	for e in p:
		if String(e["que"]) == que and (nodo == null or e["nodo"] == nodo):
			return e
	return {}


func _entrada_r(p: Array[Dictionary], que: String, reaccion: String) -> Dictionary:
	for e in p:
		if String(e["que"]) == que and String(e["reaccion"]) == reaccion:
			return e
	return {}


## Los avisos reales de un nodo durante el caso (sin repetidos), traducidos al nombre del indicador.
func _avisos_de(nodo: Node) -> Array:
	var r: Array = []
	for x in _reacciones:
		if x["nodo"] == nodo:
			var n: String = String(PrevisionHechizo.DE_AVISO.get(String(x["nombre"]), String(x["nombre"])))
			if not r.has(n):
				r.append(n)
	return r


# --- los casos -----------------------------------------------------------------------------------------------------

func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	Mundo3D.actual.reaccion.connect(func(nombre: String, _p: Vector3, nodo: Node) -> void: _reacciones.append({"nombre": nombre, "nodo": nodo}))
	await avanzar(30)
	var oeste := Vector3(-1, 0, 0)
	_ok("0 la orilla del Bosque es la esperada: tierra en (8,32) y agua honda en (7,32)", not Terreno3D.es_agua(Vector2i(8, 32)) and Terreno3D.es_agua(Vector2i(7, 32))
		and Terreno3D.agua_sim.se_nada_en(Vector2i(7, 32)))
	await _caso_enemigos(oeste)
	await _caso_viento_agua(oeste)
	await _caso_escudo(oeste)
	await _caso_suelo(oeste)
	await _caso_piezas(oeste)
	await _coste(oeste)
	print("COMPROBACIONES: %d" % _comprobaciones)


## Un caso con un goblin a 2 casillas: predice, lanza, espera `espera` s y devuelve {prev, g}.
func _contra_goblin(nombre: String, elemento: String, glifos: Array, debil: String, resiste: String, espera: float = 2.2, previo: Callable = Callable(),
		c_g: Vector2i = Vector2i(9, 31), c_j: Vector2i = Vector2i(11, 31), escudo: bool = false, de_frente: bool = true) -> Dictionary:
	var g: Combate3D = _goblin(c_g, debil, resiste, escudo, de_frente)
	if previo.is_valid():
		previo.call(g)
	var datos: Dictionary = _preparar(c_j, elemento, glifos)
	var vida0: float = g.health
	_reacciones.clear()
	var prev: Array[Dictionary] = _predecir(nombre, datos, Vector3(-1, 0, 0))
	var salio: bool = _lanzar_real(datos, Vector3(-1, 0, 0))
	_ok("%s · el hechizo sale" % nombre, salio)
	await avanzar_s(espera)
	return {"prev": prev, "g": g, "vida0": vida0}


func _caso_enemigos(oeste: Vector3) -> void:
	# fuego a un goblin normal (sin debilidad ni resistencia): prende, ×1
	var r: Dictionary = await _contra_goblin("1 fuego a goblin normal", "fuego", ["flecha"], "", "")
	var g: Combate3D = r["g"]
	var e: Dictionary = _entrada(r["prev"], "enemigo", g)
	_ok("1 fuego (normal): se prevé «prende» ×1,0", not e.is_empty() and e["reaccion"] == "prende" and is_equal_approx(float(e["mult"]), 1.0), _resumen(r["prev"]))
	_ok("1 fuego (normal): de verdad prende", g.quemando > 0.0 or g.health < r["vida0"] - 0.5, "quemando %.2f" % g.quemando)
	_ok("1 fuego (normal): avisos reales = previstos %s" % str(e.get("extra", {}).get("reacciones", [])), _avisos_de(g).has("prende"), str(_avisos_de(g)))
	_ok("1 fuego (normal): recibe al menos el daño previsto (después suman la quemadura y los pulsos de la zona de fuego, que no se prevén)", e.has("extra") and (r["vida0"] - g.health) >= float(e["extra"]["dano"]) - 0.01 and (r["vida0"] - g.health) <= float(e["extra"]["dano"]) + 100.0,
		"previsto %.1f · recibido %.1f" % [float(e["extra"]["dano"]) if e.has("extra") else -1.0, r["vida0"] - g.health])
	_limpiar()
	await avanzar(5)
	# agua a un goblin débil al agua (×2)
	r = await _contra_goblin("2 agua a goblin débil", "agua", ["flecha"], "agua", "")
	g = r["g"]
	e = _entrada(r["prev"], "enemigo", g)
	_ok("2 agua (débil): se prevé «moja» ×1,5", not e.is_empty() and e["reaccion"] == "moja" and is_equal_approx(float(e["mult"]), 1.5), _resumen(r["prev"]))
	_ok("2 agua (débil): de verdad queda mojado", g.mojado > 0.0, "mojado %.2f" % g.mojado)
	_ok("2 agua (débil): recibe el daño previsto (29/10: débil ×1,5 y defensa 2) (%.1f)" % (r["vida0"] - g.health), e.has("extra") and absf((r["vida0"] - g.health) - float(e["extra"]["dano"])) < 0.01)
	_limpiar()
	await avanzar(5)
	# fuego a un resistente (×0,5)
	r = await _contra_goblin("3 fuego a goblin resistente", "fuego", ["flecha"], "agua", "fuego")
	g = r["g"]
	e = _entrada(r["prev"], "enemigo", g)
	_ok("3 fuego (resiste): se prevé «prende» ×0,75", not e.is_empty() and e["reaccion"] == "prende" and is_equal_approx(float(e["mult"]), 0.75), _resumen(r["prev"]))
	_ok("3 fuego (resiste): de verdad arde y recibe la mitad", g.quemando > 0.0 and e.has("extra") and (r["vida0"] - g.health) >= float(e["extra"]["dano"]) - 0.01, "quemando %.2f" % g.quemando)
	_limpiar()
	await avanzar(5)
	# rayo a un goblin mojado (electrocutado ×1,5) y a uno seco
	r = await _contra_goblin("4 rayo a goblin mojado", "rayo", ["linea_z"], "", "", 2.2, func(gg: Combate3D) -> void: gg.mojado = 6.0)
	g = r["g"]
	e = _entrada(r["prev"], "enemigo", g)
	_ok("4 rayo (mojado): se prevé «electrocuta» con el daño ×1,5", not e.is_empty() and e["reaccion"] == "electrocuta", _resumen(r["prev"]))
	_ok("4 rayo (mojado): de verdad se electrocuta", _avisos_de(g).has("electrocuta"), str(_avisos_de(g)))
	_ok("4 rayo (mojado): daño previsto = recibido", e.has("extra") and absf((r["vida0"] - g.health) - float(e["extra"]["dano"])) < 0.5, "previsto %.2f · recibido %.2f" % [float(e["extra"]["dano"]) if e.has("extra") else -1.0, r["vida0"] - g.health])
	var dano_mojado: float = float(e["extra"]["dano"]) if e.has("extra") else 0.0
	_limpiar()
	await avanzar(5)
	r = await _contra_goblin("5 rayo a goblin seco", "rayo", ["linea_z"], "", "", 2.2)
	g = r["g"]
	e = _entrada(r["prev"], "enemigo", g)
	_ok("5 rayo (seco): se prevé «electrocuta» pero con menos daño que mojado (%.1f < %.1f)" % [float(e["extra"]["dano"]) if e.has("extra") else -1.0, dano_mojado], not e.is_empty() and e["reaccion"] == "electrocuta"
		and float(e["extra"]["dano"]) < dano_mojado)
	_ok("5 rayo (seco): daño previsto = recibido", e.has("extra") and absf((r["vida0"] - g.health) - float(e["extra"]["dano"])) < 0.5, "previsto %.2f · recibido %.2f" % [float(e["extra"]["dano"]) if e.has("extra") else -1.0, r["vida0"] - g.health])
	_limpiar()
	await avanzar(5)
	# hielo a un goblin: congela
	r = await _contra_goblin("6 hielo a goblin", "hielo", ["flecha"], "", "")
	g = r["g"]
	e = _entrada(r["prev"], "enemigo", g)
	_ok("6 hielo: se prevé «congela» y de verdad se congela", not e.is_empty() and e["reaccion"] == "congela" and g.congelado > 0.0, _resumen(r["prev"]) + " · congelado %.2f" % g.congelado)
	_limpiar()
	await avanzar(5)
	# tierra a un goblin: ralentiza + golpe
	r = await _contra_goblin("7 tierra a goblin", "tierra", ["flecha"], "", "")
	g = r["g"]
	e = _entrada(r["prev"], "enemigo", g)
	_ok("7 tierra: se prevé una reacción de enemigo y de verdad queda ralentizado", not e.is_empty() and g.lento > 0.0, _resumen(r["prev"]) + " · lento %.2f" % g.lento)
	_limpiar()
	await avanzar(5)


func _caso_viento_agua(oeste: Vector3) -> void:
	# viento a un goblin junto al agua honda: empuja y se hunde; el destino previsto ±0,5 casilla
	var r: Dictionary = await _contra_goblin("8 viento a goblin junto al agua", "viento", ["flecha"], "", "", 3.5, Callable(), Vector2i(8, 31), Vector2i(10, 31))
	var g: Combate3D = r["g"]
	var e: Dictionary = _entrada(r["prev"], "enemigo", g)
	_ok("8 viento: se prevé «hunde» (empuja y cae al agua)", not e.is_empty() and e["reaccion"] == "hunde" and bool(e["extra"]["hundira"]), _resumen(r["prev"]))
	_ok("8 viento: de verdad se hunde", g.se_hundio, "se_hundio %s · pos %s" % [g.se_hundio, g.position])
	if not e.is_empty():
		var dest: Vector3 = e["extra"]["destino"]
		var real := Vector3(g.position.x, 0, g.position.z)
		_ok("8 viento: el destino previsto cae a ±0,5 casilla de donde acabó (%.2f u)" % Vector2(dest.x - real.x, dest.z - real.z).length(),
			Vector2(dest.x - real.x, dest.z - real.z).length() <= 0.5 * Terreno3D.casilla, "previsto %s · real %s" % [dest, real])
	_limpiar()
	await avanzar(5)
	# viento a un goblin lejos del agua: empuja pero no se hunde
	var datos: Dictionary
	var g2: Combate3D = _goblin(Vector2i(10, 33), "", "")
	datos = _preparar(Vector2i(12, 33), "viento", ["flecha"])
	_reacciones.clear()
	var prev: Array[Dictionary] = _predecir("9 viento (sin agua)", datos, oeste)
	_lanzar_real(datos, oeste)
	var p_antes: Vector3 = g2.position
	await avanzar_s(2.0)
	var e2: Dictionary = _entrada(prev, "enemigo", g2)
	_ok("9 viento (sin agua): se prevé «empuja» sin hundir", not e2.is_empty() and e2["reaccion"] == "empuja" and not bool(e2["extra"]["hundira"]), _resumen(prev))
	if not e2.is_empty():
		var dest2: Vector3 = e2["extra"]["destino"]
		_ok("9 viento (sin agua): el destino previsto ±0,5 casilla del real (%.2f u; se movió %.2f)" % [Vector2(dest2.x - g2.position.x, dest2.z - g2.position.z).length(), Vector2(g2.position.x - p_antes.x, g2.position.z - p_antes.z).length()],
			Vector2(dest2.x - g2.position.x, dest2.z - g2.position.z).length() <= 0.5 * Terreno3D.casilla and not g2.se_hundio)
	_limpiar()
	await avanzar(5)


func _caso_escudo(_oeste: Vector3) -> void:
	# fuego a un goblin con escudo DE FRENTE: lo para el escudo (prende el escudo, el goblin no se entera)
	var r: Dictionary = await _contra_goblin("10 fuego a goblin con escudo de frente", "fuego", ["flecha"], "", "", 2.2, Callable(), Vector2i(9, 32), Vector2i(11, 32), true, true)
	var g: Combate3D = r["g"]
	var e: Dictionary = _entrada(r["prev"], "enemigo", g)
	_ok("10 escudo: se prevé «bloquea» y que el escudo prende", not e.is_empty() and e["reaccion"] == "bloquea" and bool(e["extra"]["cubierto"]) and e["extra"]["escudo"] == "prende", _resumen(r["prev"]))
	_ok("10 escudo: de verdad lo para (el escudo arde, el goblin ni arde ni pierde vida)", g.escudo.estado == "ardiendo" and g.quemando <= 0.0 and is_equal_approx(g.health, r["vida0"]) and g.escudo.bloqueos == 1,
		"escudo %s · quemando %.2f · vida %.1f/%.1f" % [g.escudo.estado, g.quemando, g.health, r["vida0"]])
	_ok("10 escudo: el goblin no avisa de ningún estado propio", not _avisos_de(g).has("prende"), str(_avisos_de(g)))
	_limpiar()
	await avanzar(5)
	# agua al escudo de frente: lo moja
	r = await _contra_goblin("11 agua a goblin con escudo de frente", "agua", ["flecha"], "", "", 2.2, Callable(), Vector2i(9, 32), Vector2i(11, 32), true, true)
	g = r["g"]
	e = _entrada(r["prev"], "enemigo", g)
	_ok("11 escudo: agua → «bloquea», el escudo se moja y el goblin no", not e.is_empty() and e["reaccion"] == "bloquea" and e["extra"]["escudo"] == "moja" and g.escudo.mojado_t > 0.0 and g.mojado <= 0.0, _resumen(r["prev"]))
	_limpiar()
	await avanzar(5)
	# fuego al mismo goblin POR LA ESPALDA: el escudo no cubre y el goblin prende
	r = await _contra_goblin("12 fuego a goblin con escudo por la espalda", "fuego", ["flecha"], "", "", 2.2, Callable(), Vector2i(9, 32), Vector2i(11, 32), true, false)
	g = r["g"]
	e = _entrada(r["prev"], "enemigo", g)
	_ok("12 escudo por la espalda: se prevé «prende» y es verdad", not e.is_empty() and e["reaccion"] == "prende" and not bool(e["extra"]["cubierto"]) and g.quemando > 0.0 and g.escudo.bloqueos == 0, _resumen(r["prev"]))
	_limpiar()
	await avanzar(5)


## Una casilla de hierba que pueda alcanzar una flecha de 2 casillas desde el este: devuelve [hierba, jugadora].
func _hierba_alcanzable() -> Array:
	var ancho: int = int(maqueta.get("_ancho"))
	var alto: int = int(maqueta.get("_alto"))
	var hf: Dictionary = maqueta.get("_hf")
	var mojada: Dictionary = maqueta.get("_mojada")
	for y in range(2, alto - 2):
		for x in range(2, ancho - 4):
			var c := Vector2i(x, y)
			var j := Vector2i(x + 2, y)
			if maqueta.call("_es_hierba", c) and not hf.has(c) and not Terreno3D.bloqueada(c) and Terreno3D.altura_en(c) == 0 and not Terreno3D.es_agua(j) and not Terreno3D.bloqueada(j) \
					and Terreno3D.altura_en(j) == 0 and not Terreno3D.bloqueada(c + Vector2i(1, 0)) and int(mojada.get(c, 0)) < Time.get_ticks_msec():
				return [c, j]
	return []


func _fases_ardiendo() -> Array:
	var r: Array = []
	var hf: Dictionary = maqueta.get("_hf")
	for k in hf:
		var f: int = int((hf[k] as Dictionary)["fase"])
		if f == 2 or f == 3:
			r.append(k)
	r.sort()
	return r


func _caso_suelo(oeste: Vector3) -> void:
	# --- hielo al agua: hiela ---
	var c_agua := Vector2i(7, 33)
	var datos: Dictionary = _preparar(Vector2i(9, 33), "hielo", ["flecha"])
	_reacciones.clear()
	var prev: Array[Dictionary] = _predecir("13 hielo al agua", datos, oeste)
	var e: Dictionary = _entrada_r(prev, "suelo", "hiela")
	_ok("13 hielo al agua: se prevé «hiela» en la casilla del agua", not e.is_empty() and (e["celda"] as Vector2i) == c_agua, _resumen(prev))
	var heladas0: Array = _heladas()
	_lanzar_real(datos, oeste)
	await avanzar_s(2.6)
	var heladas1: Array = _heladas()
	_ok("13 hielo al agua: de verdad se hiela esa casilla", Terreno3D.helada(c_agua), str(heladas1))
	var nuevas: Array = []
	for c in heladas1:
		if not heladas0.has(c):
			nuevas.append(c)
	var previstas: Array = []
	for x in prev:
		if String(x["que"]) == "suelo" and String(x["reaccion"]) == "hiela":
			previstas.append(x["celda"])
	nuevas.sort()
	previstas.sort()
	_ok("13 hielo al agua: no se hiela nada más de lo previsto (%s)" % str(nuevas), nuevas == previstas, "previstas %s" % str(previstas))
	# el fuego sobre esa agua helada la derrite
	# (la flecha de fuego se para en la casilla helada como en un muro: se lanza una barrera de fuego que nace sobre el hielo)
	var o14: Vector3 = Terreno3D.centro_de(c_agua, Terreno3D.y_pies(c_agua))
	datos = _preparar(Vector2i(9, 33), "fuego", ["barrera"])
	prev = _predecir("14 fuego al hielo", datos, oeste, o14)
	e = _entrada_r(prev, "suelo", "derrite")
	_ok("14 fuego al agua helada: se prevé «derrite» en la casilla del hielo", not e.is_empty() and (e["celda"] as Vector2i) == c_agua, _resumen(prev))
	_lanzar_real(datos, oeste, o14)
	await avanzar_s(2.6)
	_ok("14 fuego al agua helada: de verdad se derrite", not Terreno3D.helada(c_agua), str(_heladas()))
	_limpiar()
	await avanzar(5)

	# --- fuego a hierba: prende ---
	var par: Array = _hierba_alcanzable()
	_ok("15 hay hierba alcanzable en el Bosque", not par.is_empty())
	if not par.is_empty():
		var ch: Vector2i = par[0]
		datos = _preparar(par[1], "fuego", ["flecha"])
		prev = _predecir("15 fuego a hierba", datos, oeste)
		e = _entrada_r(prev, "suelo", "prende")
		_ok("15 fuego a hierba: se prevé «prende» en la casilla de hierba %s" % str(ch), not e.is_empty() and (e["celda"] as Vector2i) == ch, _resumen(prev))
		var ardiendo0: Array = _fases_ardiendo()
		_lanzar_real(datos, oeste)
		await _esperar(func() -> bool: return _fases_ardiendo().has(ch), 5.0)
		var ardiendo1: Array = _fases_ardiendo()
		var prendidas: Array = []
		for c in ardiendo1:
			if not ardiendo0.has(c):
				prendidas.append(c)
		var prev_h: Array = []
		for x in prev:
			if String(x["que"]) == "suelo" and String(x["reaccion"]) == "prende":
				prev_h.append(x["celda"])
		prendidas.sort()
		prev_h.sort()
		_ok("15 fuego a hierba: de verdad prende esa casilla y ninguna otra", prendidas == prev_h and prendidas.has(ch), "reales %s · previstas %s" % [str(prendidas), str(prev_h)])
		# el agua sobre esa hierba que arde la apaga
		datos = _preparar(par[1], "agua", ["flecha"])
		prev = _predecir("16 agua a la hierba que arde", datos, oeste)
		e = _entrada_r(prev, "suelo", "apaga")
		_ok("16 agua a hierba ardiendo: se prevé «apaga»", not e.is_empty() and (e["celda"] as Vector2i) == ch, _resumen(prev))
		_lanzar_real(datos, oeste)
		await _esperar(func() -> bool: return not _fases_ardiendo().has(ch), 6.0)
		_ok("16 agua a hierba ardiendo: de verdad deja de arder", not _fases_ardiendo().has(ch), str(_fases_ardiendo()))
		var d16: Dictionary = _preparar(par[1], "fuego", ["flecha"])
		var p16: Array[Dictionary] = PrevisionHechizo.prever(lanzador, d16, jugador.position, oeste)
		_ok("16 y la hierba queda mojada: ahora un fuego NO la prende (no se prevé «prende»)", _entrada_r(p16, "suelo", "prende").is_empty(), _resumen(p16))
		lanzador._salir_modo(true)
		lanzador._preparado = {}
		await avanzar(5)

	# --- agua / hielo a lava: enfría ---
	for el in ["agua", "hielo"]:
		var lv := Lava3D.new()
		var celdas: Array = [Vector2i(9, 34), Vector2i(10, 34), Vector2i(9, 35)] if el == "agua" else [Vector2i(9, 30), Vector2i(10, 30), Vector2i(9, 29)]
		lv.preparar(celdas)
		maqueta.add_child(lv)
		_creados.append(lv)
		await avanzar(3)
		var jc := Vector2i(12, celdas[0].y)
		datos = _preparar(jc, el, ["flecha"])
		prev = _predecir("17 %s a lava" % el, datos, oeste)
		e = _entrada_r(prev, "pieza", "enfria")
		_ok("17 %s a lava: se prevé «enfria» con casillas" % el, not e.is_empty() and not (e["extra"]["celdas"] as Array).is_empty(), _resumen(prev))
		var lava0: int = lv._lava.size()
		_lanzar_real(datos, oeste)
		await avanzar_s(2.6)
		var enfriadas: Array = lv._roca.keys()
		enfriadas.sort()
		var previstas_l: Array = (e["extra"]["celdas"] as Array).duplicate() if not e.is_empty() else []
		previstas_l.sort()
		_ok("17 %s a lava: de verdad se enfrían las casillas previstas y no otras (%s)" % [el, str(enfriadas)], enfriadas == previstas_l and lv._lava.size() < lava0, "previstas %s" % str(previstas_l))
		_comprobar_suelo("17 %s a lava" % el, prev, el == "hielo")
		_limpiar()
		await avanzar(3)

	# --- hielo al suelo desnudo: hiela. El agua en proyectil NO moja el suelo (no marca casillas): no se debe prever que lo moja ---
	datos = _preparar(Vector2i(12, 34), "hielo", ["flecha"])
	prev = _predecir("18b hielo al suelo", datos, oeste)
	_ok("18b hielo al suelo desnudo: se prevé «hiela»", not _entrada_r(prev, "suelo", "hiela").is_empty(), _resumen(prev))
	_lanzar_real(datos, oeste)
	await _esperar(func() -> bool: return _vivos().is_empty(), 6.0)
	await avanzar_s(0.5)
	_comprobar_suelo("18b hielo al suelo", prev)
	datos = _preparar(Vector2i(12, 32), "agua", ["flecha"])
	prev = _predecir("18c agua (proyectil) al suelo", datos, oeste)
	var mojadas0: Array = _con_estado(EstadosSuelo3D.MOJADA)
	_lanzar_real(datos, oeste)
	await _esperar(func() -> bool: return _vivos().is_empty(), 6.0)
	await avanzar_s(0.5)
	_ok("18c agua (proyectil) al suelo: no se prevé «moja» y de verdad no cambia ninguna casilla a mojada", _entrada_r(prev, "suelo", "moja").is_empty() and _con_estado(EstadosSuelo3D.MOJADA) == mojadas0,
		"%s · reales %s" % [_resumen(prev), str(_con_estado(EstadosSuelo3D.MOJADA))])
	# --- el haz de agua y el de hielo SÍ marcan cada casilla del recorrido: lo previsto es lo que cambia ---
	for el in ["agua", "hielo"]:
		var est: String = EstadosSuelo3D.MOJADA if el == "agua" else EstadosSuelo3D.HELADA
		var jh := Vector2i(13 if el == "agua" else 12, 29 if el == "agua" else 28)
		datos = _preparar(jh, el, ["linea_z"])
		prev = _predecir("18d haz de %s" % el, datos, oeste)
		var antes_e: Array = _con_estado(est)
		_lanzar_real(datos, oeste)
		await avanzar_s(1.0)
		var nuevas_e: Array = []
		for c in _con_estado(est):
			if not antes_e.has(c):
				nuevas_e.append(c)
		var previstas_e: Array = []
		for x in prev:
			if String(x["que"]) == "suelo" and String((x["extra"] as Dictionary).get("clase", "")) == "suelo" and String(x["reaccion"]) == ("moja" if el == "agua" else "hiela"):
				previstas_e.append(x["celda"])
		nuevas_e.sort()
		previstas_e.sort()
		_ok("18d haz de %s: las casillas que cambian a «%s» son las previstas %s" % [el, est, str(previstas_e)], nuevas_e == previstas_e and not previstas_e.is_empty(), "reales %s" % str(nuevas_e))
		await avanzar(3)


func _caso_piezas(oeste: Vector3) -> void:
	var fila := 33
	# --- fuego a un brasero: lo enciende ---
	var br: Reactivo3D = _reactivo("brasero", Vector2i(9, fila))
	await avanzar(3)
	var datos: Dictionary = _preparar(Vector2i(11, fila), "fuego", ["flecha"])
	var prev: Array[Dictionary] = _predecir("18 fuego a un brasero", datos, oeste)
	var e: Dictionary = _entrada(prev, "pieza", br)
	_ok("18 fuego a brasero apagado: se prevé «enciende»", not e.is_empty() and e["reaccion"] == "enciende", _resumen(prev))
	_ok("18 el brasero estaba apagado", not br.is_lit)
	_lanzar_real(datos, oeste)
	await avanzar_s(2.2)
	_ok("18 fuego a brasero: de verdad se enciende", br.is_lit)
	# el agua lo apaga
	datos = _preparar(Vector2i(11, fila), "agua", ["flecha"])
	prev = _predecir("19 agua al brasero encendido", datos, oeste)
	e = _entrada(prev, "pieza", br)
	_ok("19 agua a brasero encendido: se prevé «apaga»", not e.is_empty() and e["reaccion"] == "apaga", _resumen(prev))
	_lanzar_real(datos, oeste)
	await avanzar_s(2.2)
	_ok("19 agua a brasero encendido: de verdad se apaga", not br.is_lit)
	# agua a un brasero APAGADO: no reacciona (sin entrada de pieza) y de verdad no pasa nada
	datos = _preparar(Vector2i(11, fila), "agua", ["flecha"])
	prev = _predecir("20 agua a un brasero apagado", datos, oeste)
	_ok("20 agua a brasero apagado: no se prevé nada de la pieza", _entrada(prev, "pieza", br).is_empty(), _resumen(prev))
	_lanzar_real(datos, oeste)
	await avanzar_s(2.2)
	_ok("20 agua a brasero apagado: de verdad sigue igual", not br.is_lit)
	_limpiar()
	await avanzar(3)

	# --- viento a un bloque empujable: se mueve ---
	var b := BloqueEmpujable3D.new()
	b.preparar(Vector2i(9, fila), "piedra", maqueta)
	maqueta.add_child(b)
	_creados.append(b)
	await avanzar(3)
	datos = _preparar(Vector2i(11, fila), "viento", ["flecha"])
	prev = _predecir("21 viento a un bloque", datos, oeste)
	e = _entrada(prev, "pieza", b)
	_ok("21 viento a bloque: se prevé «mueve» a la casilla (8,%d)" % fila, not e.is_empty() and e["reaccion"] == "mueve" and (e["extra"]["destino"] as Vector2i) == Vector2i(8, fila), _resumen(prev))
	_lanzar_real(datos, oeste)
	await _esperar(func() -> bool: return b.celda != Vector2i(9, fila) and not b.moviendo, 6.0)
	_ok("21 viento a bloque: de verdad acaba en la casilla prevista", e.has("extra") and b.celda == (e["extra"]["destino"] as Vector2i), "celda %s" % str(b.celda))
	_limpiar()
	await avanzar(3)

	# --- tierra a un muro agrietado: agrieta y luego rompe ---
	var mu := MuroAgrietado3D.new()
	mu.preparar(Vector2i(9, fila), 2)
	maqueta.add_child(mu)
	_creados.append(mu)
	await avanzar(3)
	lanzador.cambios_hechizo = {"gravedad": 0.0}       # la flecha de tierra con su arco pasa por encima del muro (vuela a 3 u de altura): como `escenario_base.lanzar`, sin gravedad
	datos = _preparar(Vector2i(11, fila), "tierra", ["flecha"])
	prev = _predecir("22 tierra a un muro agrietado (1.º golpe)", datos, oeste)
	e = _entrada(prev, "pieza", mu)
	_ok("22 tierra a muro (golpe 1 de 2): se prevé «agrieta»", not e.is_empty() and e["reaccion"] == "agrieta", _resumen(prev))
	_lanzar_real(datos, oeste)
	await avanzar_s(2.2)
	_ok("22 tierra a muro: de verdad lo agrieta sin romperlo", mu.recibidos == 1 and not mu.roto_ya, "recibidos %d" % mu.recibidos)
	datos = _preparar(Vector2i(11, fila), "tierra", ["flecha"])
	prev = _predecir("23 tierra a un muro agrietado (2.º golpe)", datos, oeste)
	e = _entrada(prev, "pieza", mu)
	_ok("23 tierra a muro (golpe 2 de 2): se prevé «rompe»", not e.is_empty() and e["reaccion"] == "rompe", _resumen(prev))
	_lanzar_real(datos, oeste)
	await avanzar_s(2.2)
	_ok("23 tierra a muro: de verdad se rompe", mu.roto_ya)
	lanzador.cambios_hechizo = {}
	# fuego al muro: no reacciona
	var mu2 := MuroAgrietado3D.new()
	mu2.preparar(Vector2i(9, 31), 2)
	maqueta.add_child(mu2)
	_creados.append(mu2)
	await avanzar(3)
	datos = _preparar(Vector2i(11, 31), "fuego", ["flecha"])
	prev = _predecir("24 fuego a un muro agrietado", datos, oeste)
	_ok("24 fuego a muro agrietado: no reacciona (sin entrada de pieza)", _entrada(prev, "pieza", mu2).is_empty(), _resumen(prev))
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	_limpiar()
	await avanzar(3)

	# --- una pasada por todos los elementos × formas: prever nunca cambia nada ni falla ---
	var goblin: Combate3D = _goblin(Vector2i(9, 31), "", "")
	goblin.mojado = 3.0
	var formas: Array = [["flecha"], ["linea_z"], ["barrera"], ["flecha", "rebote"], ["flecha", "repeticion"], ["pulso"], ["altura"], ["flecha", "flecha", "flecha"]]
	var n: int = 0
	var cambios: PackedStringArray = []
	for el in ["fuego", "agua", "viento", "tierra", "rayo", "hielo"]:
		for fm in formas:
			var d: Dictionary = _preparar(Vector2i(11, 31), el, fm)
			if d.is_empty():
				lanzador._salir_modo(true)
				lanzador._preparado = {}
				continue
			var antes: Dictionary = _foto()
			PrevisionHechizo.prever(lanzador, d, jugador.position, oeste)
			var despues: Dictionary = _foto()
			n += 1
			for k in antes:
				if str(antes[k]) != str(despues[k]):
					cambios.append("%s%s:%s" % [el, str(fm), k])
			lanzador._salir_modo(true)
			lanzador._preparado = {}
	_ok("25 barrido: %d previsiones (6 elementos × %d formas) sin cambiar nada" % [n, formas.size()], n >= 30 and cambios.is_empty(), str(cambios))
	_limpiar()
	await avanzar(3)


## Coste por llamada: 100 llamadas por receta, con las 18 piezas y los goblins del Bosque en escena.
func _coste(oeste: Vector3) -> void:
	_limpiar()
	await avanzar(3)
	var _g1: Combate3D = _goblin(Vector2i(9, 31), "", "")
	var _g2: Combate3D = _goblin(Vector2i(8, 32), "", "")
	var recetas: Array = [["fuego", ["flecha"]], ["agua", ["flecha"]], ["viento", ["flecha"]], ["rayo", ["linea_z"]], ["fuego", ["flecha", "flecha", "flecha"]], ["tierra", ["barrera"]]]
	var peor: float = 0.0
	for rc in recetas:
		var datos: Dictionary = _preparar(Vector2i(11, 31), rc[0], rc[1])
		PrevisionHechizo.prever(lanzador, datos, jugador.position, oeste)         # calienta la caché del Hechizo
		var t0: int = Time.get_ticks_usec()
		for _i in range(100):
			PrevisionHechizo.prever(lanzador, datos, jugador.position, oeste)
		var us: float = float(Time.get_ticks_usec() - t0) / 100.0
		peor = maxf(peor, us)
		print("      coste %s %s: %.0f µs por llamada" % [rc[0], str(rc[1]), us])
		lanzador._salir_modo(true)
		lanzador._preparado = {}
	_ok("26 coste: ninguna previsión pasa de 5 ms en este equipo (peor %.0f µs; ~1 ms una flecha)" % peor, peor < 5000.0)
	var datos2: Dictionary = _preparar(Vector2i(11, 31), "fuego", ["flecha"])
	PrevisionHechizo.olvidar()
	var a: Array[Dictionary] = PrevisionHechizo.prever_rapido(lanzador, datos2, jugador.position, oeste)
	var t1: int = Time.get_ticks_usec()
	var b: Array[Dictionary] = []
	for _i in range(100):
		b = PrevisionHechizo.prever_rapido(lanzador, datos2, jugador.position, oeste)
	var us_r: float = float(Time.get_ticks_usec() - t1) / 100.0
	_ok("26 prever_rapido: la misma pregunta dentro de 0,1 s sale de la caché (%.1f µs) y es lo mismo" % us_r, us_r < 100.0 and a == b)
	var clave_antes: Array = PrevisionHechizo._rapida_clave.duplicate()
	PrevisionHechizo.prever_rapido(lanzador, datos2, jugador.position + Vector3(0.5, 0, 0), oeste)
	_ok("26 prever_rapido: si el origen cambia, recalcula (cambia la clave de la caché)", PrevisionHechizo._rapida_clave != clave_antes)
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	_limpiar()
	await avanzar(3)
	if not _tiempos_us.is_empty():
		var suma: float = 0.0
		for t in _tiempos_us:
			suma += float(t)
		print("      coste en los casos (1.ª llamada, con el Hechizo sin cachear): %d llamadas, media %.0f µs, máx %.0f µs" % [_tiempos_us.size(), suma / float(_tiempos_us.size()), float(_tiempos_us.max())])
