extends "res://herramientas/escenario_base.gd"
## E2 · CHAMÁN GOBLIN (28/10; enemigos/chaman_3d.gd, escenas/PruebaSalaChaman.tscn, mapas/SalaChaman.txt). Sobre la sala real, con dos guerreros goblin (W) delante del chamán:
##   1 · ESCUDA PRIMERO: con los guerreros sin escudo traza el ritual (rombo en el sello) ANTES de lanzar ninguna bola; la onda deja a cada guerrero con su escudo de naturaleza.
##   2 · luego SE MANTIENE LEJOS y DISPARA bolas de veneno (arco, aviso en el suelo, daño + veneno) con la distancia entre DIST_MIN y DIST_MAX;  RETROCEDE si la jugadora se acerca.
##   3 · si le pegan MIENTRAS TRAZA, el ritual se interrumpe (runa rota, sin escudos) y espera el enfriamiento.
##   4 · el escudo ABSORBE daño (25; lo que sobra pasa), no hace caso al agua y el FUEGO lo quema de un golpe (con un hechizo de verdad por `Lanzador3D.lanzar_ahora`).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_chaman_combate.gd

const RUTA_SALA: String = "res://escenas/PruebaSalaChaman.tscn"
var _z: Puzle3D = null
var _ch: Chaman3D = null


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _guerreros() -> Array:
	var res: Array = []
	for n in get_nodes_in_group("combate3d"):
		if n is Combate3D and not (n is Chaman3D) and not (n as Combate3D).muerto:
			res.append(n)
	return res


func _jugadora(c: Vector2i) -> void:
	colocar_jugador(c)
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 100000.0
	j._t_inv = 0.0
	j._empuje = Vector3.ZERO


func _quitar_escudos() -> void:
	for g in _guerreros():
		var c: Combate3D = g
		if c.escudo_natural != null and is_instance_valid(c.escudo_natural):
			c.escudo_natural.queue_free()
		c.escudo_natural = null


func _dist_a(p: Vector3) -> float:
	return Vector2(jugador.position.x - p.x, jugador.position.z - p.z).length()


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_SALA, true)
	if maqueta == null or jugador == null or lanzador == null:
		return
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("0 la sala tiene sus puzles", _z != null)
	if _z == null:
		return
	Repertoire.activate_all()
	await avanzar(10)
	var j: Jugador3D = jugador as Jugador3D
	_ch = _z.nodo("chaman_a") as Chaman3D
	_ok("0 la pieza `chaman` monta un Chaman3D con su modelo", _ch != null and _ch.pj != null and _ch.pj.id == "goblin_chaman")
	if _ch == null:
		return
	var gs: Array = _guerreros()
	_ok("0 hay dos guerreros goblin con combate", gs.size() == 2, "(%d)" % gs.size())
	_ok("0 vida baja (30; 29/10, DANO_Y_TINTA: antes 50), sin defensa", is_equal_approx(_ch.health, 30.0) and is_equal_approx(Chaman3D.VIDA, 30.0) and _ch.defensa == 0.0)
	_ok("0 CD del ritual ≈ 8 s", is_equal_approx(Chaman3D.CD_RITUAL, 8.0))
	_ok("0 el chamán lleva el bastón con el orbe aparte", _ch.pj.baston() != null and _ch.pj.baston().orbe != null)
	for g in gs:
		(g as Combate3D).quieto = true

	# ---- 1 · escuda primero --------------------------------------------------------------------------------------
	print("--- 1 · escuda primero")
	_jugadora(Vector2i(12, 4))
	var t: float = 0.0
	while t < 15.0 and _ch.rituales == 0:
		await avanzar_s(0.2)
		t += 0.2
	_ok("1.1 empieza el ritual antes de tirar ninguna bola", _ch.rituales == 1 and _ch.bolas == 0, "(t=%.1f, rituales=%d, bolas=%d)" % [t, _ch.rituales, _ch.bolas])
	var dg: float = _dist_a((gs[0] as Combate3D).position)
	_ok("1.2 está detrás de los guerreros (más lejos de la jugadora que ellos)", _dist_a(_ch.position) > dg, "(él %.1f, guerrero %.1f)" % [_dist_a(_ch.position), dg])
	var runa: RunaSuelo3D = _ch.ritual.runa if _ch.ritual != null else null
	_ok("1.3 la runa se dibuja en el suelo (sello + rombo)", runa != null and runa.estado == "dibujando")
	# 28/10: DUR_TRAZAR / INSTANTE_CLAVAR son s DE CLIP; el chamán los anima a ×RITMO_GOBLIN, así que tardan 1 / ritmo en el reloj (la onda de después, 0,8 s, es del mundo y no cambia).
	await avanzar_s(AnimacionesChaman.DUR_TRAZAR * 0.5 / _ch.ritmo())
	_ok("1.4 a medio trazo la runa está a medias", runa != null and runa.u_dibujado > 0.3 and runa.u_dibujado < 0.8 and not runa.completa(), "(u=%.2f)" % (runa.u_dibujado if runa != null else -1.0))
	_ok("1.5 aún sin escudos ni bolas", _ch.escudos_dados == 0 and _ch.bolas == 0)
	await avanzar_s((AnimacionesChaman.DUR_TRAZAR * 0.5 + AnimacionesChaman.INSTANTE_CLAVAR) / _ch.ritmo() + 0.8)
	_ok("1.6 la onda deja a los dos guerreros con escudo de naturaleza", _ch.escudos_dados == 2 and (gs[0] as Combate3D).escudo_natural != null and (gs[1] as Combate3D).escudo_natural != null,
		"(escudos_dados=%d)" % _ch.escudos_dados)
	_ok("1.7 todavía no había tirado ninguna bola (escudar va primero)", _ch.bolas == 0)
	await avanzar_s(0.6)
	_ok("1.8 ritual completado una vez", _ch.rituales_completos == 1 and _ch.rituales_rotos == 0)

	# ---- 2 · se mantiene lejos y dispara -------------------------------------------------------------------------
	print("--- 2 · se mantiene lejos y dispara bolas de veneno")
	_ch.position = _pos(Vector2i(17, 5))
	_jugadora(Vector2i(13, 5))
	await avanzar_s(0.5)
	var vida0: float = j.vida
	var b0: int = _ch.bolas
	t = 0.0
	while t < 14.0 and _ch.bolas == b0:
		await avanzar_s(0.2)
		t += 0.2
	_ok("2.1 tira una bola de veneno con línea libre", _ch.bolas > b0 and _ch.ultima_bola != null, "(t=%.1f)" % t)
	_ok("2.2 la bola avisa dónde va a caer (aviso circular con el mismo radio)", _ch.ultima_bola != null and _ch.ultima_bola.aviso != null and is_equal_approx(_ch.ultima_bola.aviso.radio, BolaVeneno3D.RADIO))
	var dd: float = _dist_a(_ch.position)
	_ok("2.3 dispara desde la distancia que mantiene", dd >= Chaman3D.DIST_MIN - 0.8 and dd <= Chaman3D.ALCANCE_BOLA + 0.5, "(%.1f u)" % dd)
	await avanzar_s(2.5)
	_ok("2.4 la jugadora quieta recibe el daño y el veneno", j.vida < vida0, "(vida %.1f -> %.1f, veneno %.1f s)" % [vida0, j.vida, j._veneno_t])
	_ok("2.5 no volvió a escudar (todos tienen escudo)", _ch.rituales == 1)

	# ---- 2b · retrocede --------------------------------------------------------------------------------------------
	print("--- 2b · retrocede si se acerca")
	_jugadora(Vector2i(15, 5))
	var d0: float = _dist_a(_ch.position)
	await avanzar_s(1.5 / Combate3D.RITMO_GOBLIN)   # 28/10: el retroceso va al ritmo goblin (×0,8) y puede pillarlo acabando un lanzamiento
	var d1: float = _dist_a(_ch.position)
	_ok("2.6 con la jugadora muy cerca (%.1f u) retrocede (ahora %.1f u)" % [d0, d1], d1 > d0 + 0.5 or d1 >= Chaman3D.DIST_MIN - 0.3)

	# ---- 3 · interrumpir el trazo ---------------------------------------------------------------------------------
	print("--- 3 · le pegan trazando")
	_quitar_escudos()
	_ch._cd_ritual = 0.0
	_ch.c_estado = "vigila"
	_ch.position = _pos(Vector2i(17, 5))
	_jugadora(Vector2i(12, 4))
	var r0: int = _ch.rituales
	t = 0.0
	while t < 12.0 and _ch.c_estado != "ritual":
		await avanzar_s(0.2)
		t += 0.2
	_ok("3.1 empieza otro ritual", _ch.c_estado == "ritual" and _ch.rituales == r0 + 1)
	await avanzar_s(1.0)
	var runa3: RunaSuelo3D = _ch.ritual.runa if _ch.ritual != null else null
	var rotos0: int = _ch.rituales_rotos
	var cancel_vista: Array = [false]
	if runa3 != null:
		runa3.cancelada.connect(func() -> void: cancel_vista[0] = true)
	_ch.receive_damage(1.0)
	await avanzar(3)
	_ok("3.5 el orbe vuelve a apagarse (o se enciende de veneno para lanzar)", _ch.pj.baston().energia_orbe == 0.0 or _ch.c_estado == "lanzando")
	_ok("3.2 el golpe interrumpe el trazo: runa cancelada y ritual roto", _ch.rituales_rotos == rotos0 + 1 and cancel_vista[0] and _ch.c_estado == "vigila")
	await avanzar_s(1.0)
	_ok("3.3 nadie recibió escudo", (gs[0] as Combate3D).escudo_natural == null and (gs[1] as Combate3D).escudo_natural == null and _ch.escudos_dados == 2)
	_ok("3.4 espera el enfriamiento antes de intentarlo otra vez", _ch._cd_ritual > 5.0, "(%.1f s)" % _ch._cd_ritual)
	
	# ---- 4 · el escudo ----------------------------------------------------------------------------------------------
	print("--- 4 · el escudo absorbe y el fuego lo quema")
	_ch.quieto = true
	_ch.objetivo = null
	var g0: Combate3D = gs[0]
	var g1: Combate3D = gs[1]
	g0.health = g0.vida_max
	var e0: EscudoNaturaleza3D = EscudoNaturaleza3D.poner(g0)
	_ok("4.1 el escudo se pone con la vida de la constante", e0 != null and is_equal_approx(e0.vida, EscudoNaturaleza3D.VIDA) and is_equal_approx(EscudoNaturaleza3D.VIDA, 25.0))
	g0.receive_damage(10.0)
	_ok("4.2 absorbe 10: el guerrero no pierde vida y el escudo queda en 15", is_equal_approx(g0.health, g0.vida_max) and is_equal_approx(e0.vida, 15.0), "(vida %.1f, escudo %.1f)" % [g0.health, e0.vida])
	g0.receive_damage(20.0)
	_ok("4.3 lo que pasa del escudo (5) sí hiere y el escudo se rompe", is_equal_approx(g0.health, g0.vida_max - 5.0) and g0.escudo_natural == null, "(vida %.1f)" % g0.health)
	EscudoNaturaleza3D.poner(g1)
	g1.health = g1.vida_max
	_jugadora(Vector2i(13, 6))
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element("fuego")
	lanzador.place_sigil("flecha")
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
	lanzador.cast_page(0)
	var prep: Dictionary = lanzador._preparado
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	var dir: Vector3 = g1.position - jugador.position
	dir.y = 0.0
	lanzador.lanzar_ahora(prep, jugador.position, dir.normalized())
	await avanzar_s(3.0)
	_ok("4.4 un hechizo de fuego de verdad quema el escudo", g1.escudo_natural == null, "(escudo %s, vida %.1f: ahora arde)" % [str(g1.escudo_natural), g1.health])
	var g3: Combate3D = g0
	g3.health = g3.vida_max
	EscudoNaturaleza3D.poner(g3)
	g3._num_elemento = "fuego"
	g3.receive_damage(5.0)
	g3._num_elemento = ""
	_ok("4.4b ...y de un golpe: el escudo se acaba y ese daño no pasa", g3.escudo_natural == null and is_equal_approx(g3.health, g3.vida_max))
	var e2: EscudoNaturaleza3D = EscudoNaturaleza3D.poner(g0)
	g0._num_elemento = "agua"
	var vida_g0: float = g0.health
	g0.receive_damage(5.0)
	g0._num_elemento = ""
	_ok("4.5 el agua no lo quema (solo lo gasta)", e2.estado == "activo" and is_equal_approx(e2.vida, 20.0) and is_equal_approx(g0.health, vida_g0))
	var vida_j: float = j.vida
	var b: BolaVeneno3D = BolaVeneno3D.lanzar(maqueta, jugador.position + Vector3(0, 1, 3), jugador.position, _ch, j, lanzador)
	await avanzar_s(b.t_vuelo + 0.3)
	_ok("4.6 una bola que cae sobre ella la hiere y la envenena", b.acerto and j.vida <= vida_j - BolaVeneno3D.DANO + 0.01 and j._veneno_t > 0.0, "(vida %.1f -> %.1f)" % [vida_j, j.vida])
	var q: Vector3 = jugador.position + Vector3(4.0, 0, 0)
	var b2: BolaVeneno3D = BolaVeneno3D.lanzar(maqueta, q + Vector3(0, 1, 3), q, _ch, j, lanzador)
	await avanzar_s(b2.t_vuelo + 0.3)
	_ok("4.7 la que cae lejos de ella no la toca", not b2.acerto)
	_ch.quieto = false
	_ch.receive_damage(1000.0)
	await avanzar(5)
	_ok("4.8 el chamán muere y su ritual no deja nada colgando", _ch.muerto and _ch.ritual == null)
