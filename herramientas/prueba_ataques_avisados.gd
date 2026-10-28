extends "res://herramientas/escenario_base.gd"
## C3 · ATAQUES AVISADOS y C4 · ESQUIVA CON PREMIO (28/10; docs/PROPUESTA_COMBATE.md §2 y §7).
## Sobre la escena real del Bosque (Jugador3D, Lanzador3D, Combate3D), con enemigos que atacan de verdad a la jugadora quieta:
##   C3  el aviso sale ≥ 0,4 s antes del golpe, cubre lo que daña (la regla de daño de cada ataque, punto a punto) y el golpe cae cuando acaba: guerrero, asesino, elemental, arquero
##       (el aviso del arquero sigue a la jugadora mientras tensa y se queda donde suelta); cancelar el ataque quita el aviso.
##   C4  rodar en la ventana del aviso → tiempo bruja (escala 0,3, ella compensada, invulnerable, puede lanzar aunque ruede; acaba a los 0,6 s de juego y el tiempo vuelve a 1);
##       rodar antes, o fuera de la zona → nada.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_ataques_avisados.gd

const FILA: int = 33
var _comprobaciones: int = 0
var _creados: Array = []


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _enemigo(ids: Array, c: Vector2i) -> Combate3D:
	var p: Vector3 = _pos(c)
	var modelo: Pj3D = maqueta.call("_personaje", ids, p)
	if modelo == null:
		return null
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.position = p
	g.casa = p
	g.health = 100000.0
	g.vida_max = 100000.0
	_creados.append(g)
	_creados.append(modelo)
	return g


func _limpiar() -> void:
	var lista: Variant = maqueta.get("_goblins")
	for n in _creados:
		if is_instance_valid(n):
			if n is Combate3D:
				(n as Combate3D)._quitar_aviso()
			if lista is Array:
				(lista as Array).erase(n)                 # la maqueta recorre sus modelos cada fotograma
			(n as Node).queue_free()
	_creados.clear()
	for a in get_nodes_in_group(AvisoAtaque3D.GRUPO):
		(a as AvisoAtaque3D).cancelar()
	TiempoBruja.terminar(lanzador)
	Engine.time_scale = 1.0


func _jugadora_lista(c: Vector2i) -> void:
	colocar_jugador(c)
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 100000.0
	j._t_inv = 0.0
	j._roll_cd = 0.0
	j._t_roll = 0.0
	j._empuje = Vector3.ZERO


## El primer aviso vivo de `dueno` (o null).
func _aviso_de(dueno: Node) -> AvisoAtaque3D:
	for a in get_nodes_in_group(AvisoAtaque3D.GRUPO):
		if (a as AvisoAtaque3D).dueno == dueno and not (a as AvisoAtaque3D).cancelado:
			return a as AvisoAtaque3D
	return null


## Espera el primer aviso de `g` (hasta `max_s` s); null si no sale.
func _esperar_aviso(g: Node, max_s: float = 8.0) -> AvisoAtaque3D:
	var t: float = 0.0
	while t < max_s:
		var a: AvisoAtaque3D = _aviso_de(g)
		if a != null:
			return a
		t += await avanzar_s(1.0 / 30.0)
	return null


## Avanza hasta que la jugadora pierde vida (o `max_s`); devuelve los s de juego que pasaron (INF si no pasó).
func _esperar_dano(max_s: float) -> float:
	var j: Jugador3D = jugador as Jugador3D
	var v0: float = j.vida
	var t: float = 0.0
	while t < max_s:
		if j.vida < v0:
			return t
		t += await avanzar_s(1.0 / 30.0)
	return INF if j.vida >= v0 else t


## Recorre una rejilla de puntos alrededor de `centro` y cuenta los que `regla` y `aviso.contiene` no dan igual (fuera de una franja de ±`tol` u del borde).
func _discrepancias(aviso: AvisoAtaque3D, centro: Vector3, regla: Callable, borde: Callable, ext: float = 4.0, tol: float = 0.06) -> int:
	var malos: int = 0
	var paso: float = 0.15
	var x: float = -ext
	while x <= ext:
		var z: float = -ext
		while z <= ext:
			var p: Vector3 = centro + Vector3(x, 0.0, z)
			if absf(float(borde.call(p))) > tol and bool(regla.call(p)) != aviso.contiene(p):
				malos += 1
			z += paso
		x += paso
	return malos


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	await avanzar(20)
	await _caso_guerrero()
	await _caso_asesino()
	await _caso_elemental()
	await _caso_arquero()
	await _caso_cancelar()
	await _caso_esquiva_a_tiempo()
	await _caso_esquiva_a_destiempo()
	await _caso_esquiva_fuera()
	_limpiar()
	print("COMPROBACIONES: %d" % _comprobaciones)


# --- C3 ---------------------------------------------------------------------------------------------------------------

func _caso_guerrero() -> void:
	_jugadora_lista(Vector2i(10, FILA))
	var g: Combate3D = _enemigo(["goblin_warrior_chibi"], Vector2i(11, FILA))
	_ok("1 guerrero: hay modelo", g != null)
	if g == null:
		return
	var a: AvisoAtaque3D = await _esperar_aviso(g)
	_ok("1 guerrero: al atacar marca el suelo", a != null)
	if a == null:
		_limpiar()
		return
	var t_aviso: float = a.t_impacto
	_ok("1 guerrero: el aviso sale ≥ 0,4 s antes del golpe (%.2f s)" % t_aviso, t_aviso >= AvisoAtaque3D.T_MIN - 0.001)
	_ok("1 guerrero: es un círculo de radio RANGO_ATAQUE + 0,5 alrededor de él", a.forma == "circulo" and is_equal_approx(a.radio, Combate3D.RANGO_ATAQUE + 0.5)
		and Vector2(a.centro.x - g.position.x, a.centro.z - g.position.z).length() < 0.05)
	var gp: Vector3 = g.position
	var malos: int = _discrepancias(a, gp, func(p: Vector3) -> bool: return Vector2(p.x - gp.x, p.z - gp.z).length() <= Combate3D.RANGO_ATAQUE + 0.5,
		func(p: Vector3) -> float: return Vector2(p.x - gp.x, p.z - gp.z).length() - (Combate3D.RANGO_ATAQUE + 0.5))
	_ok("1 guerrero: cubre EXACTAMENTE lo que daña `_conectar` (rejilla de 0,15 u: %d puntos distintos)" % malos, malos == 0)
	_ok("1 guerrero: cubre la casilla de la jugadora", a.casillas().has(Terreno3D.celda_de(jugador.position)) or a.contiene(jugador.position), str(a.casillas()))
	var ta: float = a.t
	var t_dano: float = await _esperar_dano(6.0)
	_ok("1 guerrero: el golpe llega cuando acaba el aviso (%.2f s tras salir; aviso %.2f s)" % [ta + t_dano, t_aviso], t_dano != INF and absf(ta + t_dano - t_aviso) <= 0.1)
	_limpiar()
	await avanzar(3)


func _caso_asesino() -> void:
	_jugadora_lista(Vector2i(10, FILA))
	var g: Combate3D = _enemigo(["goblin_asesino"], Vector2i(11, FILA))
	if g == null or not g.pj.id.begins_with("goblin_asesino"):
		_aviso("2 asesino: no hay modelo goblin_asesino; caso saltado")
		_limpiar()
		return
	var a: AvisoAtaque3D = await _esperar_aviso(g)
	_ok("2 asesino: marca el suelo antes de su primer corte (%.2f s)" % (a.t_impacto if a != null else -1.0), a != null and a.t_impacto >= AvisoAtaque3D.T_MIN - 0.001)
	if a != null:
		var ta: float = a.t
		var t_dano: float = await _esperar_dano(6.0)
		_ok("2 asesino: el primer corte cae al acabar el aviso", t_dano != INF and absf(ta + t_dano - a.t_impacto) <= 0.1, "%.2f vs %.2f" % [ta + t_dano, a.t_impacto])
	_limpiar()
	await avanzar(3)


func _caso_elemental() -> void:
	_jugadora_lista(Vector2i(10, FILA))
	var g: Combate3D = Combate3D.invocar_elemental(maqueta, jugador as Jugador3D, lanzador, _pos(Vector2i(12, FILA)))
	if g == null:
		_aviso("3 elemental: no hay modelo; caso saltado")
		return
	_creados.append(g)
	_creados.append(g.pj)
	g.health = 100000.0
	g.vida_max = 100000.0
	var a: AvisoAtaque3D = await _esperar_aviso(g, 12.0)
	_ok("3 elemental: el puñetazo marca un rectángulo delante de él", a != null and a.forma == "rect")
	if a == null:
		_limpiar()
		return
	_ok("3 elemental: sale ≥ 0,4 s antes (%.2f s)" % a.t_impacto, a.t_impacto >= AvisoAtaque3D.T_MIN - 0.001)
	var gp: Vector3 = g.position
	var f: Vector3 = Vector3(g.mirada.x, 0.0, g.mirada.z).normalized()
	var k: float = g._k_ref()
	var regla := func(p: Vector3) -> bool:
		var rel: Vector3 = p - gp
		rel.y = 0.0
		var delante: float = rel.dot(f)
		var lado: float = absf(rel.dot(Vector3(-f.z, 0.0, f.x)))
		return delante >= -0.3 and delante <= Combate3D.ELEM_ALCANCE_GOLPE * k and lado <= Combate3D.ELEM_ANCHO_GOLPE * k
	var borde := func(p: Vector3) -> float:
		var rel: Vector3 = p - gp
		rel.y = 0.0
		var delante: float = rel.dot(f)
		var lado: float = absf(rel.dot(Vector3(-f.z, 0.0, f.x)))
		return minf(minf(absf(delante + 0.3), absf(delante - Combate3D.ELEM_ALCANCE_GOLPE * k)), absf(lado - Combate3D.ELEM_ANCHO_GOLPE * k))
	var malos: int = _discrepancias(a, gp, regla, borde, 5.0)
	_ok("3 elemental: el rectángulo es EXACTAMENTE el área de `_golpe_elemental` (%d puntos distintos)" % malos, malos == 0)
	var ta: float = a.t
	var t_dano: float = await _esperar_dano(8.0)
	_ok("3 elemental: el puñetazo cae al acabar el aviso", t_dano != INF and absf(ta + t_dano - a.t_impacto) <= 0.1, "%.2f vs %.2f" % [ta + t_dano, a.t_impacto])
	_limpiar()
	await avanzar(3)


func _caso_arquero() -> void:
	_jugadora_lista(Vector2i(10, FILA))
	var g: Combate3D = _enemigo(["goblin_archer_chibi"], Vector2i(12, FILA))
	if g == null or not g.arquero:
		_aviso("4 arquero: no hay modelo goblin_archer_chibi; caso saltado")
		_limpiar()
		return
	var a: AvisoAtaque3D = await _esperar_aviso(g)
	_ok("4 arquero: al tensar marca dónde caerá la flecha", a != null and a.forma == "circulo" and is_equal_approx(a.radio, Combate3D.RADIO_IMPACTO_FLECHA))
	if a == null:
		_limpiar()
		return
	_ok("4 arquero: sale ≥ 0,4 s antes del impacto (%.2f s)" % a.t_impacto, a.t_impacto >= AvisoAtaque3D.T_MIN - 0.001)
	# mientras tensa, sigue a la jugadora: se la mueve media casilla
	var j: Jugador3D = jugador as Jugador3D
	j.position += Vector3(0.0, 0.0, 0.5)
	j.pj.position = j.position
	j._ultima = j.position
	await avanzar(2)
	_ok("4 arquero: mientras tensa, el aviso sigue a la jugadora", g._golpe_pendiente and Vector2(a.centro.x - j.position.x, a.centro.z - j.position.z).length() < 0.1
		or not g._golpe_pendiente, "centro %s · ella %s" % [a.centro, j.position])
	while is_instance_valid(a) and g._golpe_pendiente:
		await avanzar(1)
	var fijado: Vector3 = a.centro if is_instance_valid(a) else Vector3.INF
	_ok("4 arquero: al soltar se queda quieto donde apunta la flecha", fijado != Vector3.INF)
	var ta: float = a.t if is_instance_valid(a) else 0.0
	var t_imp: float = a.t_impacto if is_instance_valid(a) else 0.0
	var t_dano: float = await _esperar_dano(4.0)
	_ok("4 arquero: la flecha da a la jugadora (dentro del círculo) cuando acaba el aviso", t_dano != INF and absf(ta + t_dano - t_imp) <= 0.15, "%.2f vs %.2f" % [ta + t_dano, t_imp])
	_limpiar()
	await avanzar(3)


func _caso_cancelar() -> void:
	_jugadora_lista(Vector2i(10, FILA))
	var g: Combate3D = _enemigo(["goblin_warrior_chibi"], Vector2i(11, FILA))
	if g == null:
		return
	var a: AvisoAtaque3D = await _esperar_aviso(g)
	if a == null:
		_ok("5 cancelar: hubo aviso", false)
		_limpiar()
		return
	g.congelado = 2.0                                 # lo congelan antes del golpe
	await avanzar(2)
	_ok("5 cancelar: congelado antes del golpe, el aviso desaparece", not is_instance_valid(a) or a.cancelado)
	var t_dano: float = await _esperar_dano(1.0)
	_ok("5 cancelar: y el golpe no llega", t_dano == INF)
	_limpiar()
	await avanzar(3)


# --- C4 ---------------------------------------------------------------------------------------------------------------

## Pone a un guerrero a pegar y espera hasta que a su aviso le queden `queda` s. Devuelve [g, aviso] o [] si no salió.
func _hasta_ventana(queda: float) -> Array:
	_jugadora_lista(Vector2i(10, FILA))
	var g: Combate3D = _enemigo(["goblin_warrior_chibi"], Vector2i(11, FILA))
	if g == null:
		return []
	var a: AvisoAtaque3D = await _esperar_aviso(g)
	if a == null:
		return []
	while is_instance_valid(a) and a.queda() > queda:
		await avanzar(1)
	return [g, a]


func _caso_esquiva_a_tiempo() -> void:
	var r: Array = await _hasta_ventana(0.15)
	_ok("6 a tiempo: hubo aviso", not r.is_empty())
	if r.is_empty():
		return
	var j: Jugador3D = jugador as Jugador3D
	var veces: int = TiempoBruja.veces
	var vida0: float = j.vida
	j._iniciar_voltereta(Vector3(-1, 0, 0))
	_ok("6 a tiempo: rodar en la ventana abre el tiempo bruja", TiempoBruja.activa() and TiempoBruja.veces == veces + 1 and j.esquivas_perfectas >= 1)
	_ok("6 a tiempo: el mundo va a 0,3", is_equal_approx(Engine.time_scale, TiempoBruja.ESCALA), str(Engine.time_scale))
	await avanzar(1)
	_ok("6 a tiempo: ella va a su paso (animación ×%.2f)" % j.pj._arbol.vel_tiempo if j.pj._arbol != null else "6 a tiempo: ella va a su paso",
		j.pj._arbol == null or is_equal_approx(j.pj._arbol.vel_tiempo, 1.0 / TiempoBruja.ESCALA))
	_ok("6 a tiempo: puede lanzar aunque aún ruede", j._t_roll > 0.0 and j.puede_lanzar(), "rueda %.2f" % j._t_roll)
	var t: float = 0.0
	var max_ts: float = 0.0
	while t < 1.2:
		t += await avanzar_s(1.0 / 30.0)
		if TiempoBruja.activa():
			max_ts = maxf(max_ts, Engine.time_scale)
	_ok("6 a tiempo: el golpe no le hace nada", j.vida >= vida0, "vida %.0f → %.0f" % [vida0, j.vida])
	_ok("6 a tiempo: mientras dura, la escala no sube de 0,3", max_ts <= TiempoBruja.ESCALA + 0.001, str(max_ts))
	_ok("6 a tiempo: a los 0,6 s de juego acaba y el tiempo vuelve a 1", not TiempoBruja.activa() and is_equal_approx(Engine.time_scale, 1.0), "%s · %.2f" % [TiempoBruja.activa(), Engine.time_scale])
	_ok("6 a tiempo: y ella vuelve a animarse a 1", j.pj._arbol == null or is_equal_approx(j.pj._arbol.vel_tiempo, 1.0))
	_limpiar()
	await avanzar(3)
	# Lanzar una página dentro del tiempo bruja, por el camino de verdad.
	r = await _hasta_ventana(0.15)
	if r.is_empty():
		return
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element("fuego")
	lanzador.place_sigil("flecha")
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
	j._iniciar_voltereta(Vector3(-1, 0, 0))
	await avanzar(1)
	var lanzo: bool = lanzador.lanzar_pagina_ya(0, j.position, Vector3(1, 0, 0))
	_ok("6 tiempo bruja: se dispara una página aunque esté rodando", TiempoBruja.activa() and lanzo)
	_ok("6 tiempo bruja: lanzar corta la voltereta y deja el mundo a 0,3", j._t_roll <= 0.0 and is_equal_approx(Engine.time_scale, TiempoBruja.ESCALA), "rueda %.2f · %.2f" % [j._t_roll, Engine.time_scale])
	await avanzar_s(1.0)
	_ok("6 tiempo bruja: tras lanzar, el tiempo vuelve a 1", not TiempoBruja.activa() and is_equal_approx(Engine.time_scale, 1.0), str(Engine.time_scale))
	_limpiar()
	await avanzar(3)


func _caso_esquiva_a_destiempo() -> void:
	var r: Array = await _hasta_ventana(0.45)
	if r.is_empty():
		_ok("7 a destiempo: hubo aviso", false)
		return
	var j: Jugador3D = jugador as Jugador3D
	var veces: int = TiempoBruja.veces
	j._iniciar_voltereta(Vector3(0, 0, 1))
	_ok("7 a destiempo: rodar con 0,45 s por delante no da nada", not TiempoBruja.activa() and TiempoBruja.veces == veces and is_equal_approx(Engine.time_scale, 1.0))
	_limpiar()
	await avanzar(3)


func _caso_esquiva_fuera() -> void:
	var r: Array = await _hasta_ventana(0.15)
	if r.is_empty():
		_ok("8 fuera: hubo aviso", false)
		return
	var j: Jugador3D = jugador as Jugador3D
	var a: AvisoAtaque3D = r[1]
	j.position = Vector3(a.centro.x - a.radio - 0.6, j.position.y, j.position.z)       # fuera del círculo
	j.pj.position = j.position
	j._ultima = j.position
	var veces: int = TiempoBruja.veces
	j._iniciar_voltereta(Vector3(-1, 0, 0))
	_ok("8 fuera: rodar a tiempo pero fuera de la zona no da nada", not TiempoBruja.activa() and TiempoBruja.veces == veces)
	_limpiar()
	await avanzar(3)
