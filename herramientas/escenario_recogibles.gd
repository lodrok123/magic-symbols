extends "res://herramientas/escenario_base.gd"
## C1 de docs/PLAN_COMBATE_2026-11-22.md (22/11, Pablo: «mete un recogible en botín de los enemigos que te cure al recoger y otro para la tinta»), en la ArenaCombate:
##   · un goblin muerto suelta una GOTA DE TINTA (+6; +4 más si murió por su debilidad); al pasar por encima se recoge y sube la tinta;
##   · con la tirada a favor suelta también un RECOGIBLE DE VIDA que cura un 12 % de la vida máxima al cogerlo (no va a la bolsa);
##   · los dos desaparecen a los pocos segundos si nadie los coge;
##   · un muñeco (`premia_tinta` false) y un enemigo ahogado no sueltan nada.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_recogibles.gd

const RUTA_ARENA: String = "res://escenas/PruebaArenaCombate.tscn"


func _recogibles(tipo: String) -> Array:
	var r: Array = []
	var pila: Array = [maqueta]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		if n is Combate3D.Botin3D and (n as Combate3D.Botin3D).tipo == tipo and not (n as Node).is_queued_for_deletion():
			r.append(n)
		for h in n.get_children():
			pila.append(h)
	return r


func _matar(g: Combate3D) -> void:
	g.quieto = true
	g.receive_damage(g.health + 100.0)
	await avanzar_s(0.8)                                   # que el botín salte y se asiente


## Pone a la jugadora encima de cada recogible de `tipo` (como si pasara por ahí) y espera a que se cojan.
func _recoger(tipo: String) -> int:
	var n: int = 0
	for b in _recogibles(tipo):
		if not is_instance_valid(b):
			continue
		colocar_jugador(Terreno3D.celda_de((b as Node3D).global_position))
		await avanzar_s(0.6)
		n += 1
	return n


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_ARENA, true)
	if maqueta == null or lanzador == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	await avanzar(10)
	var j: Jugador3D = jugador as Jugador3D
	colocar_jugador(Vector2i(2, 2))
	var a: Combate3D = z.nodo("escudo_a") as Combate3D
	var b: Combate3D = z.nodo("escudo_b") as Combate3D
	var c: Combate3D = z.nodo("coraza_arena") as Combate3D
	_ok("0 hay tres goblins en la arena", a != null and b != null and c != null)
	if a == null or b == null or c == null:
		return
	# --- 1 · tinta y vida de un goblin normal ---
	Combate3D.tirada_recogible_forzada = 0.0               # que salga el de vida
	lanzador.tinta.actual = 40.0
	j.vida = 50.0
	await _matar(a)
	var gotas: Array = _recogibles(Combate3D.Botin3D.TIPO_TINTA)
	var vidas: Array = _recogibles(Combate3D.Botin3D.TIPO_VIDA)
	_ok("1 el goblin muerto suelta una gota de tinta de +%d" % int(Combate3D.TINTA_MATAR), gotas.size() == 1 and is_equal_approx((gotas[0] as Combate3D.Botin3D).valor, Combate3D.TINTA_MATAR),
		"%d gotas" % gotas.size())
	_ok("1 y, con la tirada a favor, un recogible de vida del %d %%" % int(Combate3D.RECOGIBLE_VIDA_FRACCION * 100.0), vidas.size() == 1
		and is_equal_approx((vidas[0] as Combate3D.Botin3D).valor, Estado.i().vida_max * Combate3D.RECOGIBLE_VIDA_FRACCION))
	var t0: float = lanzador.tinta.actual
	var v0: float = j.vida                                 # (al ir a por la gota, el imán puede coger también la vida, que cae al lado)
	await _recoger(Combate3D.Botin3D.TIPO_TINTA)
	_ok("1 al pasar por encima se recoge la gota y sube la tinta", lanzador.tinta.actual >= t0 + Combate3D.TINTA_MATAR - 0.6 and _recogibles(Combate3D.Botin3D.TIPO_TINTA).is_empty(),
		"%.1f → %.1f" % [t0, lanzador.tinta.actual])
	await _recoger(Combate3D.Botin3D.TIPO_VIDA)
	_ok("1 al pasar por encima se recoge la vida y cura (no va a la bolsa)", j.vida >= v0 + Estado.i().vida_max * Combate3D.RECOGIBLE_VIDA_FRACCION - 0.01,
		"%.0f → %.0f" % [v0, j.vida])
	# --- 2 · por su debilidad: +4; y si nadie la coge, se va ---
	Combate3D.tirada_recogible_forzada = 0.99              # que NO salga el de vida
	b.debil = "fuego"
	b._num_golpe = true
	b._num_elemento = "fuego"
	await _matar(b)
	b._num_golpe = false
	var g2: Array = _recogibles(Combate3D.Botin3D.TIPO_TINTA)
	_ok("2 muerto por su debilidad, la gota da +%d" % int(Combate3D.TINTA_MATAR + Combate3D.TINTA_MATAR_EXTRA), g2.size() == 1
		and is_equal_approx((g2[0] as Combate3D.Botin3D).valor, Combate3D.TINTA_MATAR + Combate3D.TINTA_MATAR_EXTRA))
	_ok("2 con la tirada en contra no sale el de vida (no siempre sale)", _recogibles(Combate3D.Botin3D.TIPO_VIDA).is_empty())
	colocar_jugador(Vector2i(2, 2))
	await avanzar_s(Combate3D.RECOGIBLE_DURA + 0.5)
	_ok("2 si nadie la coge, la gota desaparece a los %.0f s" % Combate3D.RECOGIBLE_DURA, _recogibles(Combate3D.Botin3D.TIPO_TINTA).is_empty())
	# --- 3 · ni muñecos ni ahogados ---
	Combate3D.tirada_recogible_forzada = 0.0
	c.premia_tinta = false
	await _matar(c)
	_ok("3 un muñeco (premia_tinta false) no suelta ni tinta ni vida", _recogibles(Combate3D.Botin3D.TIPO_TINTA).is_empty() and _recogibles(Combate3D.Botin3D.TIPO_VIDA).is_empty())
	var limo: Combate3D = z.nodo("limo_brasa_arena") as Combate3D
	if limo != null:
		limo.quieto = true
		limo._morir(true)                                  # ahogado en agua honda
		await avanzar_s(0.8)
		_ok("3 un enemigo ahogado no suelta nada", _recogibles(Combate3D.Botin3D.TIPO_TINTA).is_empty() and _recogibles(Combate3D.Botin3D.TIPO_VIDA).is_empty())
	Combate3D.tirada_recogible_forzada = -1.0
