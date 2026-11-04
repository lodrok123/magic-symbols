extends "res://herramientas/escenario_base.gd"
## PRUEBA DE COGER Y LANZAR (4/11, jugador/cargar_objeto_3d.gd; docs/RECOGER_LANZAR_2026-11-04.md). Sin ventana, a 30 fps fijos:
##     godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_recoger_lanzar.gd
## Escena de verdad (PruebaBosque, jugadora, Lanzador3D, goblins), la E y la Q son EVENTOS DE TECLA (Input.parse_input_event), no llamadas. Mide:
##   coger un jarrón (tiempos de la agachada, casilla liberada, el objeto sobre la cabeza), que cargando no se corre (ni rueda, golpea o lanza hechizos), la velocidad ×0,7,
##   lanzar (cae a la distancia de la tabla), que se rompe y suelta botín, que daña a un goblin con empuje, que Q lo deja entero delante (y se puede volver a coger),
##   que un golpe recibido lo tira y rompe, un cogible suelto cualquiera (piedra), el interruptor, y (segunda escena) que E sobre un cofre sigue abriéndolo aunque haya un jarrón al lado.

const RUTA_02: String = "res://escenas/PruebaBosque02.tscn"
const CLARO_X: Vector2i = Vector2i(-3, 6)         ## el claro buscado: casillas llanas y libres de claro+CLARO_X.x a claro+CLARO_X.y en X (la jugadora lanza hacia +X)
const CLARO_Y: int = 3                            ## y de claro-CLARO_Y a claro+CLARO_Y

var j: Jugador3D = null
var c: CargarObjeto3D = null
var claro: Vector2i = Vector2i.ZERO
var _n: int = 0


func _escenario() -> void:
	Flags.nuevo()
	Misiones.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null:
		return
	j = jugador as Jugador3D
	c = j.carga
	_ok("1 el jugador trae el nodo CargarObjeto3D y el interruptor está en true", c != null and CargarObjeto3D.RECOGER_ACTIVO and c.activo)
	if c == null:
		return
	lanzador.tinta = null
	j.vida = 100000.0
	_claro()
	await _coger()
	await _no_correr()
	await _lanzar_y_romper()
	await _dano_goblin()
	await _soltar()
	await _golpe_recibido()
	await _suelto_generico()
	await _interruptor()
	await _cofre()


# ---------------------------------------------------------------------------------------------------------------------
#  Montaje
# ---------------------------------------------------------------------------------------------------------------------

## Un claro llano y libre de (2·MEDIO+1)² casillas lo más cerca posible de la jugadora; los goblins del nivel, lejos y quietos.
func _claro() -> void:
	var ancho: int = int(maqueta.get("_ancho"))
	var alto: int = int(maqueta.get("_alto"))
	var desde: Vector2i = celda_jugador()
	var mejor: Vector2i = Vector2i(-1, -1)
	var dmejor: float = INF
	for y in range(CLARO_Y + 1, alto - CLARO_Y - 1):
		for x in range(-CLARO_X.x + 1, ancho - CLARO_X.y - 1):
			var cc := Vector2i(x, y)
			var n0: int = Terreno3D.altura_en(cc)
			var bien: bool = true
			for dy in range(-CLARO_Y, CLARO_Y + 1):
				for dx in range(CLARO_X.x, CLARO_X.y + 1):
					var v := cc + Vector2i(dx, dy)
					if Terreno3D.es_agua(v) or Terreno3D.bloqueada(v) or Terreno3D.altura_en(v) != n0:
						bien = false
						break
				if not bien:
					break
			if bien and Vector2(cc - desde).length() < dmejor:
				dmejor = Vector2(cc - desde).length()
				mejor = cc
	_ok("2 hay un claro llano de %d×%d casillas" % [CLARO_X.y - CLARO_X.x + 1, CLARO_Y * 2 + 1], mejor.x >= 0, str(mejor))
	claro = mejor
	for g in get_nodes_in_group("combate3d"):
		(g as Combate3D).quieto = true
		(g as Combate3D).position = Vector3(-500.0, 0.0, -500.0)


func _jarron(cel: Vector2i, id: String, tipo: String = "jarron", botin: String = "oro", cant: int = 7) -> Rompible3D:
	var r := Rompible3D.new()
	r.name = id
	r.preparar(cel, tipo, botin, cant, false, "", maqueta)
	maqueta.add_child(r)
	return r


func _pulsar(tecla: Key, frames: int = 2) -> void:
	_tecla(tecla, true)
	await avanzar(frames)
	_tecla(tecla, false)
	await avanzar(1)


## Espera hasta que `cond` sea cierta (tope `max_s`); devuelve los segundos que tardó (-1 si no llegó).
func _hasta(cond: Callable, max_s: float = 3.0) -> float:
	var t0: float = reloj.t
	while reloj.t - t0 < max_s:
		if bool(cond.call()):
			return reloj.t - t0
		await process_frame
	return -1.0


func _poner(cel: Vector2i, mira: Vector3 = Vector3.RIGHT) -> void:
	colocar_jugador(cel)
	j.mirar_hacia(mira)
	(j.pj as Pj3D).mirar(mira, 1.0)


func _poner_mirada(mira: Vector3) -> void:
	j.mirar_hacia(mira)
	(j.pj as Pj3D).mirar(mira, 1.0)


func _plano(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------------------------------------------------------------------------------------------------------------------
#  1. Coger
# ---------------------------------------------------------------------------------------------------------------------

var jar: Rompible3D = null


func _coger() -> void:
	await avanzar_s(0.5)
	var cj: Vector2i = claro + Vector2i(-1, 0)
	_poner(claro)
	await avanzar_s(0.3)
	jar = _jarron(cj, "jarron_a")
	_ok("3 el jarrón nace en el grupo cogible con el metadato «cogible» = jarron", jar.is_in_group("cogible") and String(jar.get_meta("cogible")) == "jarron")
	_ok("3 el jarrón tapa su casilla", Terreno3D.bloqueada(cj))
	await avanzar(2)
	_ok("3 sin hacer nada, el candidato es el jarrón", c.candidato() == jar, str(c.candidato()))
	_ok("3 no hay otra interacción más prioritaria a mano", not c.hay_otra_interaccion())
	_ok("3 la pista [E] ofrece «Coger»", PistaProximidad.accion_actual() == "Coger" or c.accion_pista() == "Coger", PistaProximidad.accion_actual())
	var vel_ant: float = await _velocidad(false)          # andar sin carga: se mide aquí, en el mismo claro
	_poner(claro)
	await avanzar_s(0.3)
	var y0: float = jar.global_position.y
	var t0: float = reloj.t
	_tecla(KEY_E, true)
	await avanzar(1)
	_tecla(KEY_E, false)
	await avanzar(1)
	_ok("3 E empieza a cogerlo (estado COGIENDO)", c.estado == CargarObjeto3D.Estado.COGIENDO, str(c.estado))
	_ok("3 mientras se agacha no se anda (gesto)", j.en_gesto())
	var t_fondo: float = await _hasta(func() -> bool: return bool(c._agarrado), 1.5)
	var t_carga: float = await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.CARGANDO, 2.0)
	var total: float = reloj.t - t0
	var fondo_real: float = float(c.ultimo.get("t_fondo", 9.0))
	print("      tiempos: agarra a los %.2f s de empezar la agachada (T_FONDO %.2f) · cargando a los %.2f s de pulsar E" % [fondo_real, CargarObjeto3D.T_FONDO, total])
	_ok("3 agarra el objeto en el fondo de la agachada (~%.2f s)" % CargarObjeto3D.T_FONDO, t_fondo >= 0.0 and absf(fondo_real - CargarObjeto3D.T_FONDO) < 0.1, str(c.ultimo))
	_ok("3 y lo tiene sobre la cabeza a los 0,5-0,9 s de pulsar E (EoW: ~0,6 s)", t_carga >= 0.0 and total > 0.5 and total < 0.9, "%.2f s" % total)
	_ok("3 el jarrón está en brazos y no tapa la casilla de origen", jar.en_brazos and not Terreno3D.bloqueada(claro + Vector2i(-1, 0)))
	var cabeza: float = j.position.y + (j.pj as Pj3D).alto_modelo() * (j.pj as Pj3D).scale.y
	_ok("3 el objeto va sobre la cabeza (base %.2f u, coronilla %.2f u; la base se hunde ≤ %.2f u en ella)" % [jar.global_position.y, cabeza, CargarObjeto3D.HUNDE_EN_CABEZA], jar.global_position.y >= cabeza - CargarObjeto3D.HUNDE_EN_CABEZA - 0.05, "alto del modelo %.2f · escala %.2f" % [(j.pj as Pj3D).alto_modelo(), (j.pj as Pj3D).scale.y])
	_ok("3 y sobre ella (a ≤ 0,4 u en el plano)", _plano(jar.global_position, j.position) < 0.4, "%.2f u" % _plano(jar.global_position, j.position))
	_ok("3 con él en brazos, F/Ctrl/Shift/hechizos no valen (lleva_carga)", j.lleva_carga() and not j.puede_lanzar())
	_ok("3 el jarrón no se rompe solo estando en brazos (golpear no hace nada)", (func() -> bool:
		jar.golpear(Vector3.ZERO)
		return not jar.roto_ya).call())
	print("      velocidad andando sin carga: %.2f u/s" % vel_ant)
	_vel_sin = vel_ant


var _vel_sin: float = 0.0


## Anda 1 s con W (y Mayús si `corre`) desde el centro del claro y devuelve u/s.
func _velocidad(corre: bool) -> float:
	var p0: Vector3 = j.position
	_tecla(KEY_W, true)
	if corre:
		_tecla(KEY_SHIFT, true)
	await avanzar_s(0.4)                                    # arrancar
	var p1: Vector3 = j.position
	var t1: float = reloj.t
	await avanzar_s(0.8)
	var p2: Vector3 = j.position
	_tecla(KEY_W, false)
	_tecla(KEY_SHIFT, false)
	await avanzar_s(0.3)
	if p0 == p1:
		return 0.0
	return _plano(p2, p1) / 0.8


# ---------------------------------------------------------------------------------------------------------------------
#  2. No correr, no rodar, no golpear
# ---------------------------------------------------------------------------------------------------------------------

func _no_correr() -> void:
	if c.estado != CargarObjeto3D.Estado.CARGANDO:
		_ok("4 (no se pudo cargar: se salta)", false)
		return
	_poner(claro)
	await avanzar_s(0.2)
	var v_andar: float = await _velocidad(false)
	_poner(claro)
	await avanzar_s(0.2)
	var v_mayus: float = await _velocidad(true)
	print("      cargando: andar %.2f u/s · Mayús (correr) %.2f u/s · sin carga %.2f u/s" % [v_andar, v_mayus, _vel_sin])
	_ok("4 cargando se anda a ×0,7 (%.2f vs %.2f u/s)" % [v_andar, _vel_sin], _vel_sin > 0.5 and absf(v_andar / _vel_sin - 0.7) < 0.12, "razón %.2f" % (v_andar / maxf(_vel_sin, 0.001)))
	_ok("4 con Mayús NO corre (la misma velocidad)", absf(v_mayus - v_andar) < 0.15 and not j.corriendo, "%.2f vs %.2f" % [v_mayus, v_andar])
	_poner(claro)
	await avanzar_s(0.3)
	_tecla(KEY_CTRL, true)
	await avanzar(2)
	_tecla(KEY_CTRL, false)
	_ok("4 Ctrl no hace la voltereta", float(j.get("_t_roll")) <= 0.0)
	_tecla(KEY_F, true)
	await avanzar(2)
	_tecla(KEY_F, false)
	_ok("4 F no da el golpe cuerpo a cuerpo", float(j.get("_t_pegar")) <= 0.0 and not j.golpeando())
	_ok("4 el clip que suena al andar cargando es walk (y brazos en alto: capa activa)", c._brazos != null and c._brazos.influence > 0.99, "peso %s" % (c._brazos.influence if c._brazos != null else "sin capa"))
	# manos y cabeza medidas
	var pj: Pj3D = j.pj
	var mi: Vector3 = c.mano_izq                # (de skeleton_updated: fuera de esa señal la pose es la de la animación sin capas)
	var md: Vector3 = c.mano_der
	var cab: float = j.position.y + pj.alto_modelo() * pj.scale.y
	print("      manos: izq y=%.2f der y=%.2f · separación %.2f · cabeza (alto del modelo) %.2f" % [mi.y, md.y, mi.distance_to(md), cab])
	print("      hombro-mano: las manos suben a %.2f u sobre los pies; la coronilla está a %.2f u (la jugadora es chibi: sus brazos no llegan más arriba que su cabeza)" % [mi.y - j.position.y, cab - j.position.y])
	_ok("4 las dos manos quedan juntas (< 0,5 u) y casi a la altura de la coronilla (≥ 80 % de su altura)", mi.distance_to(md) < 0.5 and mi.y - j.position.y >= 0.8 * (cab - j.position.y) and md.y - j.position.y >= 0.8 * (cab - j.position.y))


# ---------------------------------------------------------------------------------------------------------------------
#  3. Lanzar, caer a la distancia y romperse con botín
# ---------------------------------------------------------------------------------------------------------------------

func _lanzar_y_romper() -> void:
	_poner(claro, Vector3.RIGHT)
	await avanzar_s(0.4)
	var antes_oro: Array = []
	var t0: float = reloj.t
	_tecla(KEY_E, true)
	await avanzar(1)
	_tecla(KEY_E, false)
	_ok("5 E con el jarrón en brazos arma el lanzamiento", c.estado == CargarObjeto3D.Estado.ANTICIPANDO)
	_ok("5 mientras arma no se anda ni se coge otra cosa (quieta)", c.quieta())
	var t_suelta: float = await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.LANZANDO, 1.0)
	_ok("5 lo suelta a los ~%.2f s de pulsar E" % CargarObjeto3D.T_ANTICIPAR, t_suelta >= 0.0 and absf((reloj.t - t0) - CargarObjeto3D.T_ANTICIPAR) < 0.15, "%.2f s" % (reloj.t - t0))
	var t_vuelo0: float = reloj.t
	await avanzar_s(0.1)
	_ok("5 tras soltarlo sigue quieta (remate) con los brazos al frente (capa activa)", c.estado == CargarObjeto3D.Estado.LANZANDO and c.quieta() and c._brazos != null and c._brazos.influence > 0.5, "estado %d" % c.estado)
	var origen: Vector3 = jar.global_position
	var t_imp: float = await _hasta(func() -> bool: return c.ultimo.get("accion", "") == "impacto", 2.5)
	var t_vuelo: float = reloj.t - t_vuelo0
	var u: Dictionary = c.ultimo
	var esperado: float = float(CargarObjeto3D.COGIBLES["jarron"]["alcance"]) * Terreno3D.casilla
	print("      lanzamiento: vuelo %.2f s · distancia en plano %.2f u (tabla %.2f u = %.1f casillas) · punto %s" % [t_vuelo, float(u.get("distancia", 0.0)), esperado, float(CargarObjeto3D.COGIBLES["jarron"]["alcance"]), u.get("punto", "")])
	_ok("5 cae y avisa del impacto", t_imp >= 0.0 and u.get("accion", "") == "impacto")
	_ok("5 cae a %.1f casillas (%.2f u ±0,6) en la dirección de la mirada" % [float(CargarObjeto3D.COGIBLES["jarron"]["alcance"]), esperado], absf(float(u.get("distancia", 0.0)) - esperado) < 0.6 and (u["punto"] as Vector3).x > origen.x and absf((u["punto"] as Vector3).z - origen.z) < 0.3)
	_ok("5 el vuelo dura 0,5-0,9 s", t_vuelo > 0.5 and t_vuelo < 0.9, "%.2f s" % t_vuelo)
	_ok("5 al caer se rompe (roto_ya)", jar.roto_ya and bool(u.get("rompio", false)))
	_ok("5 y suelta el botín de su fila (7 de oro)", jar.soltado.size() == 1 and String((jar.soltado[0] as Dictionary)["que"]) == "oro" and int((jar.soltado[0] as Dictionary)["n"]) == 7, str(jar.soltado))
	await avanzar(1)
	_ok("5 deja restos en el suelo", jar.n_restos() > 0, str(jar.n_restos()))
	_ok("5 no tapa ninguna casilla", not Terreno3D.bloqueada(Terreno3D.celda_de(jar.global_position)) and not Terreno3D.bloqueada(claro + Vector2i(-1, 0)))
	_ok("5 la jugadora vuelve a andar a los ~%.2f s del lanzamiento" % (CargarObjeto3D.T_ANTICIPAR + CargarObjeto3D.T_REMATE), await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.LIBRE and not j.lleva_carga(), 1.0) >= 0.0 or c.estado == CargarObjeto3D.Estado.LIBRE)


# ---------------------------------------------------------------------------------------------------------------------
#  4. Daña a un goblin
# ---------------------------------------------------------------------------------------------------------------------

func _goblin(cel: Vector2i) -> Combate3D:
	var p: Vector3 = Terreno3D.centro_de(cel, Terreno3D.y_pies(cel))
	var modelo := Pj3D.new()
	maqueta.add_child(modelo)
	modelo.cargar("goblin_warrior_chibi")
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	modelo.set_alto(0.85)
	modelo.position = p
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, j, lanzador)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.mirada = Vector3(-1, 0, 0)
	return g


func _dano_goblin() -> void:
	var g: Combate3D = _goblin(claro + Vector2i(3, 0))
	await avanzar_s(0.5)
	var v0: float = g.health
	var p0: Vector3 = g.position
	var jr: Rompible3D = _jarron(claro + Vector2i(-1, 0), "jarron_b", "jarron", "nada", 0)
	_poner(claro, Vector3.RIGHT)
	await avanzar_s(0.3)
	await _pulsar(KEY_E)
	await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.CARGANDO, 2.0)
	_poner_mirada(Vector3.RIGHT)
	await avanzar(2)
	await _pulsar(KEY_E)
	var t: float = await _hasta(func() -> bool: return c.ultimo.get("accion", "") == "impacto" and jr.roto_ya, 2.5)
	await avanzar_s(0.6)
	var u: Dictionary = c.ultimo
	print("      goblin: vida %.1f → %.1f · empujado %.2f u · daño %s · impacto en %s (goblin en %s)" % [v0, g.health, _plano(g.position, p0), u.get("danos", []), u.get("punto", ""), p0])
	_ok("6 el jarrón lanzado golpea al goblin (%d enemigo)" % int(u.get("enemigos", 0)), t >= 0.0 and int(u.get("enemigos", 0)) == 1)
	_ok("6 le quita vida (%.1f → %.1f)" % [v0, g.health], g.health < v0 - 1.0)
	_ok("6 y lo empuja (más de 0,5 u)", _plano(g.position, p0) > 0.5)
	_ok("6 choca contra él en el aire, antes de la distancia máxima", float(u.get("distancia", 99.0)) < float(CargarObjeto3D.COGIBLES["jarron"]["alcance"]) * Terreno3D.casilla - 0.5, "%.2f u" % float(u.get("distancia", 99.0)))
	_ok("6 el jarrón se rompe en el golpe", jr.roto_ya)
	g.queue_free()


# ---------------------------------------------------------------------------------------------------------------------
#  5. Soltar con Q
# ---------------------------------------------------------------------------------------------------------------------

func _soltar() -> void:
	await avanzar_s(0.8)
	var jr: Rompible3D = _jarron(claro + Vector2i(-1, 0), "jarron_c", "jarron", "oro", 3)
	_poner(claro, Vector3.RIGHT)
	await avanzar_s(0.3)
	await _pulsar(KEY_E)
	await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.CARGANDO, 2.0)
	_ok("7 cargando otra vez", c.estado == CargarObjeto3D.Estado.CARGANDO)
	_poner_mirada(Vector3.RIGHT)
	await avanzar(2)
	var vida0: float = j.vida
	var t0: float = reloj.t
	await _pulsar(KEY_Q)
	var t: float = await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.LIBRE, 1.5)
	await avanzar(2)
	var delante: Vector3 = jr.global_position - j.position
	delante.y = 0.0
	print("      soltar: %.2f s · queda a %.2f u delante · casilla %s" % [reloj.t - t0, delante.length(), jr.celda])
	_ok("7 Q lo deja entero (no roto, no en brazos)", t >= 0.0 and not jr.roto_ya and not jr.en_brazos)
	_ok("7 delante de ella (a 1-3,5 u en la dirección de la mirada)", delante.length() > 1.0 and delante.length() < 3.5 and delante.normalized().dot(Vector3.RIGHT) > 0.5, str(delante))
	_ok("7 y vuelve a tapar su casilla", Terreno3D.bloqueada(jr.celda) and jr.celda != claro)
	_ok("7 sin soltar botín", jr.soltado.is_empty())
	_ok("7 Q no se bebe nada ni gasta vida", j.vida == vida0)
	await avanzar_s(0.5)
	_ok("7 puede volver a cogerlo (candidato)", c.candidato() == jr, str(c.candidato()))
	await _pulsar(KEY_E)
	var t2: float = await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.CARGANDO, 2.0)
	_ok("7 y lo coge de nuevo", t2 >= 0.0 and jr.en_brazos)
	jar = jr


# ---------------------------------------------------------------------------------------------------------------------
#  6. Un golpe recibido lo tira
# ---------------------------------------------------------------------------------------------------------------------

func _golpe_recibido() -> void:
	_ok("8 sigue cargando el jarrón antes del golpe", c.estado == CargarObjeto3D.Estado.CARGANDO and jar.en_brazos)
	var vida0: float = j.vida
	j.recibir_dano(6.0, j.position + Vector3(2.0, 0, 0))
	await avanzar(2)
	print("      golpe: vida %.1f → %.1f · jarrón roto %s · restos %d · botín %s" % [vida0, j.vida, jar.roto_ya, jar.n_restos(), jar.soltado])
	_ok("8 el golpe le quita vida", j.vida < vida0)
	_ok("8 deja de cargar (manos libres)", c.estado == CargarObjeto3D.Estado.LIBRE and not j.lleva_carga())
	_ok("8 el jarrón se cae y se rompe", jar.roto_ya)
	_ok("8 con su botín (3 de oro)", jar.soltado.size() == 1 and int((jar.soltado[0] as Dictionary)["n"]) == 3, str(jar.soltado))
	await avanzar_s(0.8)
	_ok("8 los brazos vuelven a la animación (capa a 0)", c._brazos == null or c._brazos.influence < 0.01)
	_ok("8 y puede volver a lanzar hechizos (puede_lanzar) y su velocidad es la de siempre", j.puede_lanzar() and c.mult_vel() == 1.0)


# ---------------------------------------------------------------------------------------------------------------------
#  7. Un cogible suelto cualquiera (piedra) y las filas de la tabla
# ---------------------------------------------------------------------------------------------------------------------

func _suelto_generico() -> void:
	await avanzar_s(1.0)
	var cel: Vector2i = claro + Vector2i(-1, 0)
	var piedra := Node3D.new()
	piedra.name = "piedra_p"
	maqueta.add_child(piedra)
	piedra.set_meta("cogible", "piedra")
	piedra.add_to_group("cogible")
	piedra.global_position = Terreno3D.centro_de(cel, Terreno3D.y_pies(cel))
	var mi := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.2
	esfera.height = 0.4
	mi.mesh = esfera
	mi.position.y = 0.2
	piedra.add_child(mi)
	_poner(claro, Vector3.RIGHT)
	await avanzar_s(0.3)
	await _pulsar(KEY_E)
	var t: float = await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.CARGANDO, 2.0)
	_poner_mirada(Vector3.RIGHT)
	await avanzar(2)
	_ok("9 una piedra (nodo suelto con metadato cogible) se coge", t >= 0.0 and c.tipo == "piedra", c.tipo)
	_ok("9 con su fila: ×%.1f de velocidad y no se rompe" % float(CargarObjeto3D.COGIBLES["piedra"]["vel"]), is_equal_approx(c.mult_vel(), 0.6) and not bool(CargarObjeto3D.COGIBLES["piedra"]["rompe"]))
	await _pulsar(KEY_E)
	await _hasta(func() -> bool: return c.ultimo.get("accion", "") == "impacto", 2.5)
	var u: Dictionary = c.ultimo
	var esperado: float = float(CargarObjeto3D.COGIBLES["piedra"]["alcance"]) * Terreno3D.casilla
	_ok("9 cae a %.1f casillas (%.2f u ±0,6)" % [float(CargarObjeto3D.COGIBLES["piedra"]["alcance"]), esperado], absf(float(u.get("distancia", 0.0)) - esperado) < 0.6, "%.2f u" % float(u.get("distancia", 0.0)))
	_ok("9 y se queda entera en el suelo", is_instance_valid(piedra) and not bool(u.get("rompio", true)) and absf(piedra.global_position.x - (u["punto"] as Vector3).x) < 0.01)
	for tipo in CargarObjeto3D.COGIBLES:
		var f: Dictionary = CargarObjeto3D.COGIBLES[tipo]
		_ok("9 la fila «%s» trae peso, alcance, daño y rompe" % tipo, f.has("vel") and f.has("alcance") and f.has("dano") and f.has("rompe") and f.has("empuje"))
	piedra.queue_free()
	await avanzar_s(0.8)


# ---------------------------------------------------------------------------------------------------------------------
#  8. Interruptor
# ---------------------------------------------------------------------------------------------------------------------

func _interruptor() -> void:
	var cel: Vector2i = claro + Vector2i(-1, 0)
	var jr: Rompible3D = _jarron(cel, "jarron_d")
	_poner(claro, Vector3.RIGHT)
	await avanzar_s(0.3)
	c.activo = false
	await _pulsar(KEY_E)
	await avanzar_s(0.5)
	_ok("10 con el interruptor apagado, E no coge nada", c.estado == CargarObjeto3D.Estado.LIBRE and not jr.en_brazos and c.accion_pista() == "")
	c.activo = true
	_ok("10 con él encendido el mismo jarrón sí es candidato", c.candidato() == jr)
	jr.golpear()
	# el bloque empujable no es cogible
	var bloque := BloqueEmpujable3D.new()
	_ok("10 un bloque empujable no está en el grupo cogible (no se coge)", not bloque.is_in_group("cogible"))
	bloque.free()
	await avanzar_s(0.3)


# ---------------------------------------------------------------------------------------------------------------------
#  9. E sobre un cofre sigue abriéndolo (Bosque 02, con un jarrón al lado)
# ---------------------------------------------------------------------------------------------------------------------

func _cofre() -> void:
	maqueta.queue_free()
	maqueta = null
	await avanzar(5)
	Flags.nuevo()
	await cargar(RUTA_02, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	j = jugador as Jugador3D
	c = j.carga
	lanzador.tinta = null
	j.vida = 100000.0
	var abre: Variant = null
	for n in get_nodes_in_group("e_cofre"):
		if bool(n.get("es_cerrado")) and bool(n.call("sellado_cumplido")) and String(n.get("glifo")) == "" and String(n.get("calidad")) == "":
			abre = n
			break
	_ok("11 hay un cofre común cerrado y abrible en el Bosque 02", abre != null, "cofres: %d" % get_nodes_in_group("e_cofre").size())
	if abre == null:
		return
	var cofre: Node3D = abre as Node3D
	var cc: Vector2i = abre.get("celda")
	# jugadora en una casilla libre vecina y un jarrón en otra vecina de ella
	var libres: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var v: Vector2i = cc + (d as Vector2i)
		if Terreno3D.pisable(v, Terreno3D.altura_en(v), false, Terreno3D.altura_en(v), false):
			libres.append(v)
	_ok("11 el cofre tiene casillas libres alrededor", libres.size() >= 2, str(libres))
	if libres.size() < 2:
		return
	var yo: Vector2i = libres[0]
	var jc: Vector2i = Vector2i(-1, -1)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var v3: Vector2i = yo + (d as Vector2i)
		if v3 != cc and v3 != yo and not Terreno3D.bloqueada(v3) and Terreno3D.pisable(v3, Terreno3D.altura_en(v3), false, Terreno3D.altura_en(v3), false):
			jc = v3
			break
	_ok("11 hay una casilla libre junto a la jugadora para el jarrón", jc.x >= 0)
	if jc.x < 0:
		return
	colocar_jugador(yo)
	var jr: Rompible3D = _jarron(jc, "jarron_cofre")
	j.mirar_hacia(Terreno3D.centro_de(cc, 0.0) - j.position)
	await avanzar_s(0.5)
	var d_cofre: float = PistaProximidad.dist_plana(cofre.global_position, j.position)
	var d_jarron: float = PistaProximidad.dist_plana(jr.global_position, j.position)
	print("      cofre a %.2f u, jarrón a %.2f u de la jugadora" % [d_cofre, d_jarron])
	_ok("11 el jarrón está al alcance de E (candidato)", c.candidato() == jr, "d=%.2f" % d_jarron)
	_ok("11 el cofre cerrado manda: hay otra interacción más prioritaria", c.hay_otra_interaccion())
	_ok("11 y la pista no ofrece «Coger»", c.accion_pista() != "Coger", c.accion_pista())
	await _pulsar(KEY_E)
	await avanzar_s(1.0)
	await avanzar_s(2.5)
	_ok("11 E ABRE el cofre", bool(cofre.get("es_abierto")), "abierto=%s abriendo=%s" % [cofre.get("es_abierto"), cofre.get("_abriendo")])
	_ok("11 y NO coge el jarrón", c.estado == CargarObjeto3D.Estado.LIBRE and not jr.en_brazos)
	# alejada del cofre, E sí coge el jarrón
	var lejos: Vector2i = Vector2i(-1, -1)
	for dx in range(-6, 7):
		for dy in range(-6, 7):
			var v2: Vector2i = jc + Vector2i(dx, dy)
			if lejos.x < 0 and PistaProximidad.dist_plana(Terreno3D.centro_de(v2, 0.0), cofre.global_position) > 4.5 and PistaProximidad.dist_plana(Terreno3D.centro_de(v2, 0.0), Terreno3D.centro_de(jc, 0.0)) < 6.0 and Terreno3D.pisable(v2, Terreno3D.altura_en(v2), false, Terreno3D.altura_en(v2), false):
				lejos = v2
	if lejos.x >= 0:
		var cel2: Vector2i = lejos + Vector2i(1, 0)
		if Terreno3D.pisable(cel2, Terreno3D.altura_en(cel2), false, Terreno3D.altura_en(cel2), false):
			var jr2: Rompible3D = _jarron(cel2, "jarron_lejos")
			colocar_jugador(lejos)
			j.mirar_hacia(Vector3.RIGHT)
			await avanzar_s(0.5)
			await _pulsar(KEY_E)
			var t: float = await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.CARGANDO, 2.0)
			_ok("11 lejos del cofre, E coge el jarrón", t >= 0.0 and jr2.en_brazos)
