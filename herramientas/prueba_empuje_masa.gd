extends "res://herramientas/escenario_base.gd"
## TAREA P (31/10) · EMPUJE POR DAÑO Y POR MASA (docs/REVISION_GAMEFEEL_30-10.md §2). v0 = fuerza × MULT_EMPUJE × ESCALA_EMPUJE × k_dano / masa.
## Sobre la escena real del Bosque, en un claro llano, con enemigos quietos (`quieto`) y el golpe por el camino real (`Combate3D.golpe`) o la previsión (`prever_golpe`).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_empuje_masa.gd

var _comprobaciones: int = 0
var _creados: Array = []
var _libre: Vector2i = Vector2i.ZERO
const ESTE := Vector3(1, 0, 0)


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


func _pos(c: Vector2i) -> Vector3:
	return Terreno3D.centro_de(c, Terreno3D.y_pies(c))


func _suelo_llano(c: Vector2i, n0: int) -> bool:
	return Terreno3D.en_mapa(c) and not Terreno3D.es_agua(c) and not Terreno3D.bloqueada(c) and Terreno3D.altura_en(c) == n0


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


func _goblin() -> Combate3D:
	var p: Vector3 = _pos(_libre + Vector2i(-2, 0))
	var modelo := Pj3D.new()
	maqueta.add_child(modelo)
	modelo.cargar("goblin_warrior_chibi")
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	modelo.set_alto(0.85)
	modelo.position = p
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	return _preparar(g, p)


func _preparar(g: Combate3D, p: Vector3) -> Combate3D:
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.health = 100000.0
	g.vida_max = 100000.0
	g.mirada = Vector3(0, 0, 1)
	_creados.append(g)
	return g


func _limpiar() -> void:
	var lista: Variant = maqueta.get("_goblins")      # el elemental invocado se apunta ahí: que la maqueta no lea un modelo liberado
	if lista is Array:
		for g in _creados:
			if g is Combate3D and (g as Combate3D).pj != null:
				(lista as Array).erase((g as Combate3D).pj)
	for g in _creados:
		if is_instance_valid(g):
			if g is Combate3D and (g as Combate3D).pj != null and is_instance_valid((g as Combate3D).pj):
				(g as Combate3D).pj.queue_free()
			(g as Node).queue_free()
	_creados.clear()


func _h(rune: String, glifos: Dictionary) -> Hechizo:
	return Hechizo.construir(load("res://nucleo/%s_rune.tres" % rune) as RuneData, glifos)


## Golpea con `h` por el camino real y devuelve lo que recorre en x tras 1,5 s.
func _recorre(g: Combate3D, h: Hechizo) -> float:
	var p0: Vector3 = g.position
	g.golpe(h, ESTE)
	await avanzar_s(1.5)
	return Vector2(g.position.x - p0.x, g.position.z - p0.z).length()


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
		(n as Combate3D).position = Vector3(-500.0, 0.0, -500.0)
	# Los golpes flojos (fuego 500, agua 600, rayo 400) quedan por debajo del suelo EMPUJE_MIN_CASILLAS (0,35 casillas = 0,8 u) y recorrerían todos lo mismo: se baja el suelo a 0 para ver la regla
	# (el suelo en sí se prueba en el 8). Se restaura al final.
	var suelo_antes: float = Combate3D.EMPUJE_MIN_CASILLAS
	Combate3D.EMPUJE_MIN_CASILLAS = 0.0
	var hay: bool = _buscar_claro(4)
	if not hay:
		hay = _buscar_claro(3)
	_ok("0 hay un claro llano donde probar", hay)
	if not hay:
		return
	await avanzar(40)

	# --- 1 · más daño (más glifos ofensivos), más empuje ---
	var g1: Combate3D = _goblin()
	var h1: Hechizo = _h("earth", {"flecha": 1})
	var h5: Hechizo = _h("earth", {"flecha": 5})
	var r1: float = await _recorre(g1, h1)
	_limpiar()
	await avanzar(3)
	var g5: Combate3D = _goblin()
	var r5: float = await _recorre(g5, h5)
	_ok("1 tierra 5 glifos ofensivos (daño %.1f) recorre más que 1 glifo (daño %.1f)" % [h5.dano, h1.dano], r5 > r1 * 1.1, "%.2f u frente a %.2f u" % [r5, r1])
	_limpiar()
	await avanzar(3)

	# --- 2 · rayo (55) contra agua (40) sobre el guerrero ---
	var ga: Combate3D = _goblin()
	var d_agua: Dictionary = ga.decidir_golpe(_h("water", {"flecha": 3}))
	var ra: float = await _recorre(ga, _h("water", {"flecha": 3}))
	_limpiar()
	await avanzar(3)
	var gr: Combate3D = _goblin()
	var d_rayo: Dictionary = gr.decidir_golpe(_h("lightning", {}))
	var rr: float = await _recorre(gr, _h("lightning", {}))
	# PENDIENTE (no cuenta como fallo ni como OK): la fuerza del elemento manda sobre el daño; decide Pablo (REVISION_GAMEFEEL §7, pregunta 1).
	print("PENDIENTE 2 rayo vs agua débil: rayo %.2f u (daño %.1f), agua %.2f u (daño %.1f), proporción %.2f; decide Pablo (REVISION_GAMEFEEL §7, pregunta 1)" % [rr, float(d_rayo["dano"]), ra, float(d_agua["dano"]), rr / maxf(ra, 0.001)])
	_limpiar()
	await avanzar(3)

	# --- 3 · la misma flecha de tierra sobre limo (0,6), guerrero (1) y elemental (3,3) ---
	var ht: Hechizo = _h("earth", {"flecha": 1})
	var gg: Combate3D = _goblin()
	var rg: float = await _recorre(gg, ht)
	var m_gob: float = gg.masa
	_limpiar()
	await avanzar(3)
	var limo: Limo3D = Limo3D.crear(maqueta, _pos(_libre + Vector2i(-2, 0)), "fuego", false)   # teñido de fuego: la tierra le hace daño (sin teñir solo lo tiñe)
	limo.quieto = true
	limo.health = 100000.0
	limo.vida_max = 100000.0
	_creados.append(limo)
	var rl: float = await _recorre(limo, ht)
	var m_limo: float = limo.masa
	_limpiar()
	await avanzar(3)
	var el: Combate3D = Combate3D.invocar_elemental(maqueta, jugador as Jugador3D, lanzador, _pos(_libre + Vector2i(-2, 0)))
	_ok("3 hay elemental", el != null)
	if el != null:
		el.quieto = true
		el.health = 100000.0
		el.vida_max = 100000.0
		_creados.append(el)
		var re: float = await _recorre(el, ht)
		_ok("3 masas: limo 0,6 · guerrero 1 · elemental 3,3", is_equal_approx(m_limo, 0.6) and is_equal_approx(m_gob, 1.0) and is_equal_approx(el.masa, 3.3), "%.1f %.1f %.1f" % [m_limo, m_gob, el.masa])
		_ok("3 misma flecha: limo > guerrero > elemental", rl > rg and rg > re and re > 0.0, "limo %.2f · guerrero %.2f · elemental %.2f u" % [rl, rg, re])
	_limpiar()
	await avanzar(3)

	# --- 4 · el gólem de pie no se mueve ---
	var gol: Golem3D = Golem3D.invocar_golem(maqueta, _pos(_libre + Vector2i(-2, 0)), jugador as Jugador3D, lanzador)
	gol.quieto = true
	_creados.append(gol)
	var p_g: Vector3 = gol.position
	gol.golpe(_h("earth", {"flecha": 5}), ESTE)
	await avanzar_s(1.5)
	_ok("4 el gólem de pie no se mueve", gol.position.distance_to(p_g) < 0.02 and is_equal_approx(gol.masa, 6.0), "%.3f u" % gol.position.distance_to(p_g))
	_limpiar()
	await avanzar(3)

	# --- 5 · la previsión coincide con el recorrido real ---
	var gp: Combate3D = _goblin()
	var hp: Hechizo = _h("water", {"flecha": 3})
	var prev: Dictionary = gp.prever_golpe(hp, ESTE)
	var rp: float = float((prev["empuje"] as Dictionary)["recorrido"])
	var real5: float = await _recorre(gp, hp)
	_ok("5 prever_empuje coincide con el recorrido real (±0,15 u)", absf(rp - real5) <= 0.15, "previsto %.2f · real %.2f" % [rp, real5])
	_limpiar()
	await avanzar(3)

	# --- 6 · con la sensación apagada el recorrido real es el mismo ---
	var gs1: Combate3D = _goblin()
	var rs_on: float = await _recorre(gs1, hp)
	_limpiar()
	await avanzar(3)
	var activa_antes: bool = Sensacion3D.ACTIVA
	Sensacion3D.ACTIVA = false
	var gs0: Combate3D = _goblin()
	var rs_off: float = await _recorre(gs0, hp)
	Sensacion3D.ACTIVA = activa_antes
	_ok("6 ACTIVA = false no cambia el empuje real (±0,1 u)", absf(rs_on - rs_off) <= 0.1, "con %.2f · sin %.2f" % [rs_on, rs_off])
	_limpiar()
	await avanzar(3)

	# --- 7 · el golpe débil (agua sobre guerrero) empuja más que el que resiste (fuego) ---
	var gd: Combate3D = _goblin()
	var rd: float = await _recorre(gd, _h("water", {"flecha": 1}))
	_limpiar()
	await avanzar(3)
	var gf: Combate3D = _goblin()
	var rf: float = await _recorre(gf, _h("fire", {"flecha": 1}))
	_ok("7 agua (débil) recorre más que fuego (resiste)", rd > rf, "agua %.2f u · fuego %.2f u" % [rd, rf])
	_limpiar()
	Combate3D.EMPUJE_MIN_CASILLAS = suelo_antes
	# --- 8 · el suelo se divide por la masa: un golpe sin fuerza recorre 0,35 casillas / masa ---
	var gm: Combate3D = _goblin()
	var v_gob: float = gm.v0_de_empuje(1.0, true)
	gm.masa = 0.5
	var v_gato: float = gm.v0_de_empuje(1.0, true)
	_ok("8 el suelo de empuje se divide por la masa (masa 0,5 = el doble)", is_equal_approx(v_gato, v_gob * 2.0) and is_equal_approx(v_gob, suelo_antes * Terreno3D.casilla * Combate3D.DECAIMIENTO_EMPUJE), "%.2f y %.2f" % [v_gob, v_gato])
	_limpiar()
	print("%d comprobaciones" % _comprobaciones)


