extends "res://herramientas/escenario_base.gd"
## 28/10 · RITMO DE LOS GOBLINS (pedido de Pablo: «todo está muy acelerado, baja un 20 % animaciones y movimientos»; Combate3D.RITMO_GOBLIN = 0,8). Sobre la escena real del Bosque:
##   1  quién lleva el ritmo: guerrero, arquero, asesino y chamán sí (0,8); elemental, limo y gólem no (1,0).
##   2  movimiento (29/10, «más pausado»): el avance NO lleva el ritmo: es PASO_GOBLIN (1,1) · zancada / duración del clip, por modelo (patrulla = andar, persecución y retroceso = correr); el elemental conserva sus velocidades.
##   3  sin patinar: el clip de andar/correr va a ×1,1 (= u/s reales · duración / ZANCADA_GOBLIN) sin mojar; mojado (×0,75) baja el clip a ×0,83 y sigue con `run` si persigue.
##   4  animaciones: el idle va × ritmo; el empujado y el congelado NO (física/mundo).
##   5  tiempos contra el clip: el golpe del guerrero cae en el mismo fotograma del clip que antes (MOMENTO_GOLPE_GUERRERO) y el aviso dura 1/0,8 más; la flecha sale en
##      momento_golpe del clip; la bola del chamán, a INSTANTE_LANZAR s de clip. (El aviso C3 y el tiempo bruja C4 con ritmo los cubre prueba_ataques_avisados.)
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_ritmo_goblin.gd

const FILA: int = 33
const R: float = 0.8
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
				(lista as Array).erase(n)
			(n as Node).queue_free()
	_creados.clear()
	for a in get_nodes_in_group(AvisoAtaque3D.GRUPO):
		(a as AvisoAtaque3D).cancelar()


func _jugadora_lista(c: Vector2i) -> void:
	colocar_jugador(c)
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 100000.0
	j._t_inv = 0.0
	j._roll_cd = 0.0
	j._t_roll = 0.0
	j._empuje = Vector3.ZERO


func _cerca(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


## El clip de andar que debe llevar `g` con `v` u/s reales (la regla de Combate3D._animar, escrita otra vez a mano con las zancadas medidas).
func _clip_esperado(g: Combate3D, v: float) -> Array:
	var clip: String = "run" if v > sqrt(_vb(g, "walk") * _vb(g, "run")) else "walk"
	var z: float = float(Combate3D.ZANCADA_GOBLIN[g.pj.id][clip])
	return [clip, clampf(v * g.pj.duracion(clip) / z, Combate3D.CLIP_ANDAR_MIN, Combate3D.CLIP_ANDAR_MAX)]


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	await avanzar(20)
	_ok("0 RITMO_GOBLIN vale 0,8 (−20 %)", is_equal_approx(Combate3D.RITMO_GOBLIN, R))
	await _caso_quien()
	await _caso_movimiento()
	await _caso_sin_patinar()
	await _caso_animaciones()
	await _caso_golpe_guerrero()
	await _caso_flecha()
	await _caso_chaman()
	_limpiar()
	print("COMPROBACIONES: %d" % _comprobaciones)


# --- 1 · quién ---------------------------------------------------------------------------------------------------------

func _caso_quien() -> void:
	_jugadora_lista(Vector2i(10, FILA))
	for ids in [["goblin_warrior_chibi"], ["goblin_archer_chibi"], ["goblin_asesino", "goblin_warrior_chibi"]]:
		var g: Combate3D = _enemigo(ids, Vector2i(30, FILA))
		_ok("1 %s lleva el ritmo (%.2f) y su Pj3D también" % [ids[0], g.ritmo()], g != null and is_equal_approx(g.ritmo(), R) and is_equal_approx(g.pj.ritmo, R))
	var e: Combate3D = Combate3D.invocar_elemental(maqueta, jugador as Jugador3D, lanzador, _pos(Vector2i(30, FILA + 2)))
	if e != null:
		_creados.append(e)
		_creados.append(e.pj)
		_ok("1 elemental SIN ritmo", is_equal_approx(e.ritmo(), 1.0) and is_equal_approx(e.pj.ritmo, 1.0))
	var l: Limo3D = Limo3D.crear(maqueta, _pos(Vector2i(32, FILA)))
	_creados.append(l)
	_ok("1 limo SIN ritmo", is_equal_approx(l.ritmo(), 1.0))
	var gl: Golem3D = Golem3D.invocar_golem(maqueta, _pos(Vector2i(34, FILA)), jugador as Jugador3D, lanzador)
	if gl != null:
		_creados.append(gl)
		_ok("1 gólem SIN ritmo", is_equal_approx(gl.ritmo(), 1.0) and is_equal_approx(gl.pj.ritmo, 1.0))
	var ch: Chaman3D = Chaman3D.invocar_chaman(maqueta, _pos(Vector2i(36, FILA)), jugador as Jugador3D, lanzador)
	if ch != null:
		_creados.append(ch)
		await avanzar(2)
		_ok("1 chamán lleva el ritmo", is_equal_approx(ch.ritmo(), R) and is_equal_approx(ch.pj.ritmo, R))
	_limpiar()
	await avanzar(3)


# --- 2 · movimiento ----------------------------------------------------------------------------------------------------

## 29/10: el avance de un goblin con `clip` («walk»/«run»), escrito otra vez a mano: PASO_GOBLIN · zancada medida / duración del clip.
func _vb(g: Combate3D, clip: String) -> float:
	return Combate3D.PASO_GOBLIN * float(Combate3D.ZANCADA_GOBLIN[g.pj.id][clip]) / g.pj.duracion(clip)


## Avanza `n` fotogramas y devuelve los u/s que de verdad recorrió el cuerpo (en el plano).
func _velocidad_medida(g: Combate3D, n: int) -> float:
	var p0: Vector3 = g.position
	var t: float = await avanzar_s(float(n) / 30.0)
	var d: Vector3 = g.position - p0
	d.y = 0.0
	return d.length() / maxf(t, 0.0001)


func _caso_movimiento() -> void:
	# Patrulla (jugadora lejos): VEL_PATRULLA × ritmo.
	_jugadora_lista(Vector2i(10, FILA))
	for ids in [["goblin_warrior_chibi"], ["goblin_archer_chibi"], ["goblin_asesino", "goblin_warrior_chibi"]]:
		var g: Combate3D = _enemigo(ids, Vector2i(30, FILA))
		await avanzar(4)
		var v: float = await _velocidad_medida(g, 12)
		_ok("2 %s patrulla a %.2f u/s (1,1 · zancada / duración = %.2f)" % [ids[0], v, _vb(g, "walk")], _cerca(g._v_avance, _vb(g, "walk"), 0.001) and _cerca(v, _vb(g, "walk"), 0.06))
		g.queue_free()
	_limpiar()
	await avanzar(2)
	# Persecución (guerrero a 2 casillas): VEL_PERSEGUIR × ritmo.
	for ids in [["goblin_warrior_chibi"], ["goblin_asesino", "goblin_warrior_chibi"]]:
		_jugadora_lista(Vector2i(10, FILA))
		var g: Combate3D = _enemigo(ids, Vector2i(12, FILA))
		await avanzar(5)
		var v: float = await _velocidad_medida(g, 6)
		_ok("2 %s persigue a %.2f u/s (1,1 · zancada / duración = %.2f)" % [ids[0], v, _vb(g, "run")], g.estado == "persigue" and _cerca(g._v_avance, _vb(g, "run"), 0.001) and _cerca(v, _vb(g, "run"), 0.15))
		_limpiar()
		await avanzar(2)
	# Retroceso del arquero (acorralado de cerca): 1,6 · VEL_PATRULLA × ritmo.
	_jugadora_lista(Vector2i(10, FILA))
	var a: Combate3D = _enemigo(["goblin_archer_chibi"], Vector2i(11, FILA))
	await avanzar(4)
	_ok("2 el arquero retrocede a %.2f u/s (a su velocidad de correr)" % a._v_avance, _cerca(a._v_avance, _vb(a, "run"), 0.001))
	_limpiar()
	await avanzar(2)
	# El elemental conserva su velocidad (VEL_PERSEGUIR · ELEM_VEL, sin 0,8).
	_jugadora_lista(Vector2i(10, FILA))
	var e: Combate3D = Combate3D.invocar_elemental(maqueta, jugador as Jugador3D, lanzador, _pos(Vector2i(12, FILA)))
	if e != null:
		_creados.append(e)
		_creados.append(e.pj)
		await avanzar(5)
		_ok("2 el elemental persigue a %.2f u/s: igual que antes (VEL_PERSEGUIR · ELEM_VEL = 1,68)" % e._v_avance, e.estado == "persigue" and _cerca(e._v_avance, Combate3D.VEL_PERSEGUIR * Combate3D.ELEM_VEL, 0.001))
	_limpiar()
	await avanzar(2)


# --- 3 · sin patinar ---------------------------------------------------------------------------------------------------

func _caso_sin_patinar() -> void:
	for ids in [["goblin_warrior_chibi"], ["goblin_archer_chibi"], ["goblin_asesino", "goblin_warrior_chibi"]]:
		_jugadora_lista(Vector2i(10, FILA))
		var g: Combate3D = _enemigo(ids, Vector2i(30, FILA))
		await avanzar(5)
		var esp: Array = _clip_esperado(g, g._v_avance)
		_ok("3 %s · patrulla: clip %s a ×%.2f (= %.2f u/s · %.2f s / zancada)" % [ids[0], g.pj.animacion_actual, g.pj.velocidad_animacion(), g._v_avance, g.pj.duracion("walk")],
			g.pj.animacion_actual == "walk" and _cerca(g.pj.velocidad_animacion(), float(esp[1]), 0.01))
		# El pie avanza lo que el suelo: zancada · velocidad del clip / duración = u/s reales.
		var z: float = float(Combate3D.ZANCADA_GOBLIN[g.pj.id]["walk"])
		_ok("3 %s · los pies hacen %.2f u/s y el cuerpo %.2f u/s (±3 %%)" % [ids[0], z * g.pj.velocidad_animacion() / g.pj.duracion("walk"), g._v_avance],
			_cerca(z * g.pj.velocidad_animacion() / g.pj.duracion("walk"), g._v_avance, 0.03 * g._v_avance))
		_ok("3 %s · sin mojar el clip de andar va a ×%.2f (≈ ×1,1)" % [ids[0], g.pj.velocidad_animacion()], _cerca(g.pj.velocidad_animacion(), Combate3D.PASO_GOBLIN, 0.02))
		g.mojado = 30.0
		await avanzar(3)
		var esp2: Array = _clip_esperado(g, g._v_avance)
		_ok("3 %s · mojado (×0,75) patrulla a %.2f u/s con el clip a ×%.2f" % [ids[0], g._v_avance, g.pj.velocidad_animacion()],
			_cerca(g._v_avance, _vb(g, "walk") * 0.75, 0.001) and _cerca(g.pj.velocidad_animacion(), float(esp2[1]), 0.01) and g.pj.animacion_actual == "walk")
		_limpiar()
		await avanzar(2)
	# Persecución: `run`; mojado (1,44 u/s) pasa a `run` también y a su velocidad.
	for mojado in [false, true]:
		_jugadora_lista(Vector2i(10, FILA))
		var g: Combate3D = _enemigo(["goblin_warrior_chibi"], Vector2i(12, FILA))
		if mojado:
			g.mojado = 30.0
		await avanzar(5)
		var esp: Array = _clip_esperado(g, g._v_avance)
		if not mojado:
			_ok("3 guerrero persiguiendo: el clip de correr va a ×%.2f (≈ ×1,1)" % g.pj.velocidad_animacion(), _cerca(g.pj.velocidad_animacion(), Combate3D.PASO_GOBLIN, 0.02))
		_ok("3 guerrero persiguiendo%s: %.2f u/s, clip %s a ×%.2f" % [" mojado" if mojado else "", g._v_avance, g.pj.animacion_actual, g.pj.velocidad_animacion()],
			g.estado == "persigue" and g.pj.animacion_actual == esp[0] and esp[0] == "run" and _cerca(g.pj.velocidad_animacion(), float(esp[1]), 0.01))
		_limpiar()
		await avanzar(2)


# --- 4 · animaciones ---------------------------------------------------------------------------------------------------

func _caso_animaciones() -> void:
	_jugadora_lista(Vector2i(10, FILA))
	var g: Combate3D = _enemigo(["goblin_warrior_chibi"], Vector2i(30, FILA))
	g.quieto = true
	await avanzar(4)
	_ok("4 idle del goblin a ×0,8 (%.2f)" % g.pj.velocidad_animacion(), g.pj.animacion_actual == "idle" and _cerca(g.pj.velocidad_animacion(), R, 0.001))
	g.congelado = 5.0
	await avanzar(3)
	_ok("4 congelado: velocidad 0 (no se multiplica)", _cerca(g.pj.velocidad_animacion(), 0.0, 0.001))
	g.congelado = 0.0
	g.quieto = false
	await avanzar(2)
	g.push(Vector3(-1, 0, 0), 1500.0, true)
	await avanzar(3)
	_ok("4 empujado: el vuelo va a ×1,0 (la física no se ralentiza; fase %d, ×%.2f)" % [g.fase_empuje(), g.pj.velocidad_animacion()],
		g.fase_empuje() == Combate3D.FASE_VOLANDO and _cerca(g.pj.velocidad_animacion(), 1.0, 0.001))
	_limpiar()
	await avanzar(2)


# --- 5 · tiempos contra el clip ----------------------------------------------------------------------------------------

func _caso_golpe_guerrero() -> void:
	_jugadora_lista(Vector2i(10, FILA))
	var g: Combate3D = _enemigo(["goblin_warrior_chibi"], Vector2i(11, FILA))
	var j: Jugador3D = jugador as Jugador3D
	var dur: float = g.pj.duracion("attack")
	var a: AvisoAtaque3D = null
	var t: float = 0.0
	while a == null and t < 8.0:
		a = null
		for n in get_nodes_in_group(AvisoAtaque3D.GRUPO):
			if (n as AvisoAtaque3D).dueno == g and not (n as AvisoAtaque3D).cancelado:
				a = n as AvisoAtaque3D
		if a == null:
			t += await avanzar_s(1.0 / 30.0)
	_ok("5 guerrero ataca y saca el aviso", a != null)
	if a == null:
		_limpiar()
		return
	var esperado: float = dur * Combate3D.MOMENTO_GOLPE_GUERRERO / R
	_ok("5 el aviso dura %.2f s = clip %.2f · %.2f / 0,8 (antes %.2f s)" % [a.t_impacto, dur, Combate3D.MOMENTO_GOLPE_GUERRERO, dur * Combate3D.MOMENTO_GOLPE_GUERRERO],
		_cerca(a.t_impacto, esperado, 0.02))
	var v0: float = j.vida
	var pos_clip: float = -1.0
	var t_dano: float = 0.0
	var t_aviso: float = a.t
	while t_dano < 6.0 and pos_clip < 0.0:
		if is_instance_valid(a):
			t_aviso = a.t
		t_dano += await avanzar_s(1.0 / 30.0)
		if j.vida < v0:
			pos_clip = g.pj.arbol().posicion()
	_ok("5 el golpe cae en el mismo fotograma del clip que antes: a %.2f s de clip (%.2f = %.2f del clip de %.2f s)" % [pos_clip, dur * Combate3D.MOMENTO_GOLPE_GUERRERO, Combate3D.MOMENTO_GOLPE_GUERRERO, dur],
		pos_clip >= 0.0 and _cerca(pos_clip, dur * Combate3D.MOMENTO_GOLPE_GUERRERO, 0.1))
	_ok("5 y a los %.2f s de salir el aviso (aviso %.2f s)" % [t_aviso + 1.0 / 30.0, a.t_impacto], _cerca(t_aviso + 1.0 / 30.0, a.t_impacto, 0.1))
	_limpiar()
	await avanzar(3)


func _caso_flecha() -> void:
	_jugadora_lista(Vector2i(10, FILA))
	var g: Combate3D = _enemigo(["goblin_archer_chibi"], Vector2i(12, FILA))
	var dur: float = g.pj.duracion("attack")
	var m: float = g.pj.momento_golpe("attack")
	var t: float = 0.0
	while not g._golpe_pendiente and t < 10.0:
		t += await avanzar_s(1.0 / 30.0)
	_ok("5 el arquero tensa (ataque en curso)", g._golpe_pendiente)
	var t0: float = reloj.t
	var tf: float = 0.0
	var pos_clip: float = -1.0
	while g._golpe_pendiente and tf < 8.0:
		tf = reloj.t - t0
		await process_frame
	pos_clip = g.pj.arbol().posicion()
	var esperado: float = dur / (Combate3D.VEL_ANIM_ARQUERO * R) * m
	_ok("5 la flecha sale a los %.2f s (esperado %.2f = clip %.2f / (%.2f · 0,8) · %.2f)" % [reloj.t - t0, esperado, dur, Combate3D.VEL_ANIM_ARQUERO, m], _cerca(reloj.t - t0, esperado, 0.12))
	_ok("5 y en el fotograma %.2f s del clip (esperado %.2f)" % [pos_clip, dur * m], _cerca(pos_clip, dur * m, 0.15))
	_limpiar()
	await avanzar(3)


func _caso_chaman() -> void:
	# Velocidades del chamán: se acerca a VEL · 0,8, retrocede a VEL_RETROCESO · 0,8 (sin ningún aliado: no hay ritual).
	_jugadora_lista(Vector2i(10, FILA))
	var ch: Chaman3D = Chaman3D.invocar_chaman(maqueta, _pos(Vector2i(6, FILA)), jugador as Jugador3D, lanzador)
	if ch == null:
		_aviso("5 chamán: no hay modelo; caso saltado")
		return
	_creados.append(ch)
	_creados.append(ch.pj)
	ch._cd_bola = 99.0
	await avanzar(4)
	var dist: float = ch._dist(jugador.position)
	_ok("5 chamán lejos (%.1f u > DIST_MAX): se acerca a %.2f u/s (su andar, ×1,1)" % [dist, ch._v_avance], dist > Chaman3D.DIST_MAX and _cerca(ch._v_avance, _vb(ch, "walk"), 0.001))
	var esp: Array = _clip_esperado(ch, ch._v_avance)
	_ok("5 su clip de andar (%s) va a ×%.2f (×1,1: sin patinar)" % [ch.pj.animacion_actual, ch.pj.velocidad_animacion()], ch.pj.animacion_actual == esp[0] and _cerca(ch.pj.velocidad_animacion(), float(esp[1]), 0.01))
	_limpiar()
	await avanzar(2)
	_jugadora_lista(Vector2i(10, FILA))
	ch = Chaman3D.invocar_chaman(maqueta, _pos(Vector2i(11, FILA)), jugador as Jugador3D, lanzador)
	_creados.append(ch)
	_creados.append(ch.pj)
	ch._cd_bola = 99.0
	await avanzar(4)
	_ok("5 chamán cerca: retrocede a %.2f u/s (su correr, ×1,1)" % ch._v_avance, _cerca(ch._v_avance, _vb(ch, "run"), 0.001))
	# La bola: a los INSTANTE_LANZAR s DE CLIP (0,55 / 0,8 = 0,69 s de reloj); el lanzar acaba a DUR_LANZAR / 0,8 = 1,38 s.
	ch._cd_bola = 0.0
	await avanzar(1)
	var b0: int = ch.bolas
	var t0: float = reloj.t
	var t_bola: float = -1.0
	var pos_bola: float = -1.0
	var t_fin: float = -1.0
	while reloj.t - t0 < 4.0 and t_fin < 0.0:
		await process_frame
		if t_bola < 0.0 and ch.bolas > b0:
			t_bola = reloj.t - t0
			pos_bola = ch.pj.arbol().posicion()
		if t_bola >= 0.0 and ch.c_estado != "lanzando":
			t_fin = reloj.t - t0
	_ok("5 la bola sale a los %.2f s (INSTANTE_LANZAR / 0,8 = %.2f)" % [t_bola, AnimacionesChaman.INSTANTE_LANZAR / R], t_bola > 0.0 and _cerca(t_bola, AnimacionesChaman.INSTANTE_LANZAR / R, 0.12))
	_ok("5 en el fotograma %.2f s del clip (INSTANTE_LANZAR %.2f)" % [pos_bola, AnimacionesChaman.INSTANTE_LANZAR], _cerca(pos_bola, AnimacionesChaman.INSTANTE_LANZAR, 0.12))
	_ok("5 y el lanzar acaba a los %.2f s (DUR_LANZAR / 0,8 = %.2f)" % [t_fin, AnimacionesChaman.DUR_LANZAR / R], t_fin > 0.0 and _cerca(t_fin, AnimacionesChaman.DUR_LANZAR / R, 0.12))
	_limpiar()
	await avanzar(3)
