extends "res://herramientas/escenario_cueva_resonante.gd"
## LA SALA DEL EMPUJE, AUTOPLAY DE PRINCIPIO A FIN (27/10; docs/EMPUJAR_BLOQUES.md, mapa mundo/datos_nivel/mapas/SalaEmpuje.txt).
## Las mismas reglas que el autoplay de la Cueva (de él salen `_andar_a`, `_ruta`, `_lanzar`, `_pulsar_e`): se anda y se EMPUJA apretando la tecla de dirección como la jugadora (nunca se
## teletransporta a nadie ni se mueve un bloque por código), se lanza con la receta real y se usa con E. Cada sala comprueba también lo que NO debe pasar (`[legible]`).
##
##   1 E1 · el bloque: menos de 0,35 s apretando no lo mueve; con 0,35 s sí, una casilla por empujón; sobre la placa abre la puerta; el que está contra las paredes no cede (y ella se queda «empujando»);
##          una barrera de tierra desde donde se empuja no llega a la placa.
##   2 E2 · el hielo: sin barrera resbala hasta la pared y pasa de largo (la puerta no se queda abierta) y, atascado, se deshace y vuelve a su casilla; con la barrera de tierra tras la placa se para
##          encima y abre; sacarlo de la placa la suelta; vuelta a ponerlo.
##   3 E3 · la veta: con el hueco vacío el receptor no se activa (ni con una barrera de tierra desde donde se empuja: no llega); el bloque de piedra empujado hasta el hueco lo tiende, el pulso llega y la reja se abre.
##   4 E4 · la otra orilla: el bloque de hielo no se alcanza andando; el fuego no lo mueve; el viento cruza el agua y un solo impacto lo hace resbalar hasta la placa; el cofre.
##   5 · recarga: los bloques vuelven a su casilla del mapa.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_sala_empuje.gd

const RUTA_SALA: String = "res://escenas/PruebaSalaEmpuje.tscn"
const ESTE: Vector2i = Vector2i(1, 0)
const OESTE: Vector2i = Vector2i(-1, 0)
const SUR: Vector2i = Vector2i(0, 1)
const NORTE: Vector2i = Vector2i(0, -1)

var _comprobaciones: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


func _soltar_teclas() -> void:
	for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_tecla(k, false)


## La tecla de pantalla que lleva hacia `dir` (casillas del mundo) con la cámara de ahora.
func _tecla_hacia(dir: Vector2i) -> Key:
	if _eje_w == Vector2.ZERO:
		await _medir_ejes()
	var v := Vector2(dir.x, dir.y)
	var mejor: Key = KEY_W
	var dm: float = -INF
	for par in [[KEY_W, _eje_w], [KEY_S, -_eje_w], [KEY_D, _eje_d], [KEY_A, -_eje_d]]:
		var d: float = v.dot(par[1] as Vector2)
		if d > dm:
			dm = d
			mejor = par[0] as Key
	return mejor


## Aprieta hacia `dir` hasta que `listo` se cumpla o pasen `max_s`. Mide cuándo se queda «empujando» (pegada al bloque), cuándo se mueve el bloque y qué clip suena mientras empuja.
func _apretar(dir: Vector2i, b: BloqueEmpujable3D, listo: Callable, max_s: float) -> Dictionary:
	var k: Key = await _tecla_hacia(dir)
	var res: Dictionary = {"t_pegada": -1.0, "t_mueve": -1.0, "empujando": false, "clip": "", "empujando_deslizando": false, "t": 0.0, "dists": [], "ratios": [], "carga": []}
	var t0: float = reloj.t
	res["t0"] = t0
	_tecla(k, true)
	while reloj.t - t0 < max_s and not bool(listo.call()):
		await process_frame
		var t: float = reloj.t - t0
		if bool(jugador.get("empujando")):
			res["empujando"] = true
			if float(res["t_pegada"]) < 0.0:
				res["t_pegada"] = t
			if b.moviendo and b.acoplado:
				res["empujando_deslizando"] = true
			if String(res["clip"]) == "" or b.moviendo:
				res["clip"] = String(jugador.pj.animacion_actual)
		if b.moviendo and float(res["t_mueve"]) < 0.0:
			res["t_mueve"] = t
		if b.moviendo and b.acoplado:
			(res["dists"] as Array).append(Vector2(jugador.pj.position.x - b.position.x, jugador.pj.position.z - b.position.z).length())
			if b.vel > 0.8:
				(res["ratios"] as Array).append(jugador.pj.velocidad_animacion() / b.vel)
		elif bool(jugador.get("empujando")) and not b.moviendo:
			(res["carga"] as Array).append(jugador.pj.velocidad_animacion())
	_tecla(k, false)
	res["t"] = reloj.t - t0
	await avanzar(2)
	return res


## Anda hacia `dir` hasta quedarse «empujando» contra el bloque (pegada) y suelta. false si no llega a empujar en `max_s`.
func _pegarse(dir: Vector2i, b: BloqueEmpujable3D, max_s: float = 3.0) -> bool:
	var k: Key = await _tecla_hacia(dir)
	var t0: float = reloj.t
	_tecla(k, true)
	while reloj.t - t0 < max_s and not bool(jugador.get("empujando")):
		await process_frame
	var si: bool = bool(jugador.get("empujando"))
	_tecla(k, false)
	return si


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_SALA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	_t0 = reloj.t
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("0 Puzle3D monta la Sala del Empuje sin avisos", _z != null and _z.avisos.is_empty(), str(_z.avisos) if _z != null else "sin Puzle3D")
	if _z == null:
		return
	_ok("0 el mapa mide 33 × 9 y la jugadora nace en E1 (2,2)", maqueta.get("_ancho") == 33 and maqueta.get("_alto") == 9 and celda_jugador() == Vector2i(2, 2), str(celda_jugador()))
	_ok("0 kit de pruebas: tierra y viento", Repertoire.element_active("tierra") and Repertoire.element_active("viento") and Repertoire.sigil_active("barrera") and Repertoire.sigil_active("flecha"))
	var origenes: Dictionary = {"bloque_e1": Vector2i(3, 4), "bloque_fijo_e1": Vector2i(7, 7), "bloque_e2": Vector2i(11, 2), "bloque_e3": Vector2i(21, 6), "bloque_e4": Vector2i(28, 4)}
	var bien: bool = true
	for id in origenes:
		var b: BloqueEmpujable3D = _z.nodo(id) as BloqueEmpujable3D
		bien = bien and b != null and b.celda == origenes[id] and Terreno3D.bloqueada(b.celda) and b.is_in_group("peso") and b.is_in_group("empujable")
	_ok("0 los cinco bloques están en su casilla, la bloquean y son «peso» y «empujable»", bien)
	_ok("0 el clip «empujar» de la jugadora existe (%.2f s)" % jugador.pj.duracion("empujar"), jugador.pj.duracion("empujar") > 0.0)
	for paso in [_e1, _e2, _e3, _e4]:
		if not await (paso as Callable).call():
			_ok("FIN: el recorrido se cortó (ver el primer FALLO)", false)
			print("COMPROBACIONES: %d" % _comprobaciones)
			return
	print("TIEMPO DE JUEGO: %.0f s" % (reloj.t - _t0))
	await _recargar_sala()
	print("COMPROBACIONES: %d" % _comprobaciones)


# ---------------------------------------------------------------------------------------------------------------------
#  1 · E1 · El bloque
# ---------------------------------------------------------------------------------------------------------------------

func _e1() -> bool:
	var b: BloqueEmpujable3D = _z.nodo("bloque_e1") as BloqueEmpujable3D
	var fijo: BloqueEmpujable3D = _z.nodo("bloque_fijo_e1") as BloqueEmpujable3D
	var placa: Pulsador3D = _z.nodo("placa_e1") as Pulsador3D
	var puerta: Puzle3D.PuertaPuzle = _z.nodo("puerta_e1") as Puzle3D.PuertaPuzle
	_ok("1 E1: bloque, placa y puerta están; la puerta cerrada, la placa libre", b != null and placa != null and puerta != null and not puerta.abierta and not placa.activo)
	if b == null or placa == null or puerta == null:
		return false
	if not await _ruta("1 E1", [Vector2i(2, 3), [Vector2i(2, 4), TOL_EXACTA]]):
		return false
	# La barrera de tierra no llega a la placa (a 5 casillas): el atajo mágico no existe.
	_ok("1 E1: tierra + barrera hacia la placa (7,4) sale (se recorta al alcance)", await _lanzar("tierra", ["barrera"], Vector2i(7, 4), true))
	await avanzar_s(1.0)
	_ok("1 E1 [legible]: la barrera de tierra NO llega a la placa: sigue libre y la puerta cerrada", not placa.activo and not puerta.abierta)
	await _esperar(func() -> bool: return Terreno3D.altura_en(Vector2i(5, 4)) == 0 and Terreno3D.altura_en(Vector2i(6, 4)) == 0, 14.0)
	# Menos de 0,35 s apretando: no cede.
	_ok("1 E1: andando hacia el este se llega a quedar pegada al bloque y «empujando»", await _pegarse(ESTE, b))
	var e0: int = b.empujones
	var k: Key = await _tecla_hacia(ESTE)
	_tecla(k, true)
	await avanzar_s(0.2)
	var emp_ahora: bool = bool(jugador.get("empujando"))
	var clip_ahora: String = String(jugador.pj.animacion_actual)
	_tecla(k, false)
	await avanzar(2)
	_ok("1 E1 [legible]: apretando menos de 0,35 s el bloque NO se mueve (%.2f s)" % 0.2, b.celda == Vector2i(3, 4) and b.empujones == e0 and not b.moviendo)
	_ok("1 E1: mientras aprieta contra el bloque, `empujando` es true y suena el clip «empujar» (%s)" % clip_ahora, emp_ahora and clip_ahora == "empujar")
	await avanzar(3)
	_ok("1 E1: al soltar, `empujando` vuelve a false", not bool(jugador.get("empujando")))
	# Empujón completo: una casilla cada vez, hasta la placa.
	var pasos_vistos: Array = []
	b.paso_dado.connect(func(c: Vector2i, _v: float) -> void: pasos_vistos.append(c))
	var r: Dictionary = await _apretar(ESTE, b, func() -> bool: return b.celda == Vector2i(7, 4) and not b.moviendo, 25.0)
	print("MEDIDA E1: apretando pegada, el bloque empieza a moverse a los %.2f s (pegada a los %.2f s); %d empujones en %.1f s" % [float(r["t_mueve"]) - float(r["t_pegada"]), float(r["t_pegada"]), b.empujones, float(r["t"])])
	_ok("1 E1: con el empuje sostenido el bloque ENCADENA las casillas hasta la placa (7,4)", b.celda == Vector2i(7, 4) and pasos_vistos == [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4)], str(pasos_vistos))
	_ok("1 E1: el empuje empieza a los ~0,35 s de quedarse pegada (%.2f s)" % (float(r["t_mueve"]) - float(r["t_pegada"])), absf(float(r["t_mueve"]) - float(r["t_pegada"]) - 0.35) < 0.15)
	_ok("1 E1: empujando fue true y sonó el clip «empujar» durante el empuje (%s)" % str(r["clip"]), bool(r["empujando"]) and String(r["clip"]) == "empujar")
	await _esperar(func() -> bool: return puerta.abierta, 2.0)
	_ok("1 E1 [legible]: el bloque sobre la placa la PISA y abre la puerta del sur (8,6)", placa.activo and puerta.abierta)
	# Contra la pared del fondo: se queda empujando y no pasa nada.
	var e1: int = b.empujones
	await _pegarse(ESTE, b, 4.0)
	var kk: Key = await _tecla_hacia(ESTE)
	_tecla(kk, true)
	await avanzar_s(0.9)
	var empuja_atascada: bool = bool(jugador.get("empujando"))
	_soltar_teclas()
	await avanzar(2)
	_ok("1 E1 [legible]: contra el final de la pista el bloque no se mueve más, pero ella se queda «empujando» (atascado)", b.celda == Vector2i(7, 4) and b.empujones == e1 and empuja_atascada)
	_ok("1 E1: el bloque sigue sobre la placa y la puerta abierta mientras esté encima", placa.activo and puerta.abierta)
	# El bloque de la esquina (7,7): contra dos paredes.
	if not await _ruta("1 E1", [Vector2i(4, 4), Vector2i(2, 4), Vector2i(2, 5), Vector2i(2, 6), Vector2i(5, 6), Vector2i(6, 6), [Vector2i(7, 6), TOL_EXACTA]]):
		return false
	var ef: int = fijo.empujones
	var ok_peg: bool = await _pegarse(SUR, fijo)
	var k2: Key = await _tecla_hacia(SUR)
	_tecla(k2, true)
	await avanzar_s(1.0)
	var empuja_fijo: bool = bool(jugador.get("empujando"))
	_soltar_teclas()
	await avanzar(2)
	_ok("1 E1 [legible]: el bloque contra las paredes (7,7) NO se mueve aunque se le empuje 1 s; ella queda «empujando»", ok_peg and fijo.celda == Vector2i(7, 7) and fijo.empujones == ef and empuja_fijo)
	_ok("1 E1: nada de eso lo ha sacado de su casilla (7,7), que sigue bloqueada", Terreno3D.bloqueada(Vector2i(7, 7)))
	if not await _ruta("1 E1", [[Vector2i(7, 6), TOL_EXACTA], Vector2i(8, 6), Vector2i(9, 6)]):
		return false
	_ok("1 E1: se cruza la puerta (con el bloque sobre la placa sigue abierta)", celda_jugador().x >= 9 and puerta.abierta)
	return true


# ---------------------------------------------------------------------------------------------------------------------
#  2 · E2 · El hielo
# ---------------------------------------------------------------------------------------------------------------------

## Lanza la barrera de tierra detrás de la placa (13,2) desde la cabecera (10,2) y espera a que se levante.
func _barrera_e2() -> bool:
	var ok: bool = await _lanzar("tierra", ["barrera"], Vector2i(13, 2), true)
	await _esperar(func() -> bool: return Terreno3D.altura_en(Vector2i(13, 2)) >= 1, 3.0)
	return ok and Terreno3D.altura_en(Vector2i(13, 2)) >= 1


func _e2() -> bool:
	var b: BloqueEmpujable3D = _z.nodo("bloque_e2") as BloqueEmpujable3D
	var placa: Pulsador3D = _z.nodo("placa_e2") as Pulsador3D
	var puerta: Puzle3D.PuertaPuzle = _z.nodo("puerta_e2") as Puzle3D.PuertaPuzle
	_ok("2 E2: bloque de hielo, placa y puerta están; la puerta cerrada", b != null and placa != null and puerta != null and b.material == "hielo" and not puerta.abierta)
	if b == null or placa == null or puerta == null:
		return false
	if not await _ruta("2 E2", [Vector2i(9, 4), Vector2i(9, 3), Vector2i(9, 2), [Vector2i(10, 2), TOL_EXACTA]]):
		return false
	# 1) Sin barrera: pasa de largo.
	var vistos: Array = []
	var cb: Callable = func(c: Vector2i) -> void: vistos.append(c)
	b.movido.connect(cb)
	var llegadas: Array = []
	var cl: Callable = func(_c: Vector2i, _v: float) -> void: llegadas.append(reloj.t)
	b.paso_dado.connect(cl)
	var placa_vista: Array = [false]
	var cp: Callable = func(_x: Variant = null) -> void: placa_vista[0] = true
	placa.pulsado.connect(cp)
	var r: Dictionary = await _apretar(ESTE, b, func() -> bool: return b.moviendo and not b.acoplado, 8.0)
	await _esperar(func() -> bool: return not b.moviendo, 8.0)
	b.movido.disconnect(cb)
	b.paso_dado.disconnect(cl)
	placa.pulsado.disconnect(cp)
	var por_casilla: float = (float(llegadas[2]) - float(llegadas[1])) if llegadas.size() >= 3 else -1.0
	_ok("2 E2: el hielo ya suelto resbala a ~0,25 s por casilla (%.2f s)" % por_casilla, por_casilla > 0.18 and por_casilla < 0.34, str(llegadas.size()))
	await avanzar_s(0.3)
	print("MEDIDA E2: el hielo recorre 4 casillas hasta la pared en %.2f s desde que se mueve (arranca pegado a ella media casilla); %.2f s por casilla ya suelto" % [float(llegadas.back()) - (float(r["t0"]) + float(r["t_mueve"])), por_casilla])
	_ok("2 E2 [legible]: SIN barrera el hielo resbala de golpe hasta la pared (15,2): un solo movimiento, 4 casillas", b.celda == Vector2i(15, 2) and vistos == [Vector2i(15, 2)], str(vistos))
	_ok("2 E2 [legible]: al pasar de largo la placa no se queda pisada y la puerta sigue cerrada (aunque se notara de pasada: %s)" % str(placa_vista[0]), not placa.activo and not puerta.abierta)
	_ok("2 E2: en la media casilla de arranque, ella va pegada «empujando» con el clip «empujar» (%s)" % str(r["clip"]), bool(r["empujando_deslizando"]) and String(r["clip"]) == "empujar")
	# Atascado contra la pared: se deshace y vuelve a formarse en su casilla.
	if not await _andar_a(Vector2i(10, 2), 6.0, TOL_EXACTA):
		_ok("2 E2: de vuelta a la cabecera (10,2)", false, _alrededor())
		return false
	var re: Array = [0]
	b.reaparecio.connect(func() -> void: re[0] += 1)
	var t_perdido: float = await _esperar(func() -> bool: return re[0] > 0, 8.0)
	print("MEDIDA E2: el hielo atascado en la pared vuelve a su casilla a los %.1f s" % t_perdido)
	_ok("2 E2 [legible]: el hielo atascado en la pared no queda perdido: se deshace y vuelve a formarse en (11,2)", re[0] == 1 and b.celda == Vector2i(11, 2) and Terreno3D.bloqueada(Vector2i(11, 2)) and not Terreno3D.bloqueada(Vector2i(15, 2)))
	# 2) Con barrera tras la placa: se para encima.
	_ok("2 E2: tierra + barrera detrás de la placa (13,2) sale y se levanta", await _barrera_e2())
	_ok("2 E2: la barrera (altura) está en (13,2) y NO en la placa (12,2)", Terreno3D.altura_en(Vector2i(13, 2)) >= 1 and Terreno3D.altura_en(Vector2i(12, 2)) == 0)
	vistos.clear()
	b.movido.connect(cb)
	r = await _apretar(ESTE, b, func() -> bool: return b.moviendo and not b.acoplado, 6.0)
	await _esperar(func() -> bool: return not b.moviendo, 8.0)
	b.movido.disconnect(cb)
	await _esperar(func() -> bool: return puerta.abierta, 2.0)
	_ok("2 E2: CON la barrera el hielo se para justo encima de la placa (12,2) y abre la puerta del sur (16,6)", b.celda == Vector2i(12, 2) and vistos == [Vector2i(12, 2)] and placa.activo and puerta.abierta, str(vistos))
	# 3) La barrera se deshace y el bloque se queda: la puerta sigue abierta.
	await _esperar(func() -> bool: return Terreno3D.altura_en(Vector2i(13, 2)) == 0, 14.0)
	await avanzar_s(0.6)
	_ok("2 E2: al deshacerse la barrera el bloque se queda quieto sobre la placa y la puerta abierta", b.celda == Vector2i(12, 2) and placa.activo and puerta.abierta and not b.moviendo)
	# 4) Sacarlo de la placa la suelta.
	r = await _apretar(ESTE, b, func() -> bool: return b.moviendo and not b.acoplado, 8.0)
	await _esperar(func() -> bool: return not b.moviendo, 8.0)
	if not await _andar_a(Vector2i(10, 2), 6.0, TOL_EXACTA):          # ella misma pisaba la placa al seguir al bloque: se aparta
		return false
	await _esperar(func() -> bool: return not puerta.abierta, 2.0)
	_ok("2 E2 [legible]: empujado hacia la pared, el bloque deja la placa: la placa se suelta y la puerta se CIERRA", b.celda == Vector2i(15, 2) and not placa.activo and not puerta.abierta, "bloque %s mueve %s placa %s puerta %s" % [str(b.celda), str(b.moviendo), str(placa.activo), str(puerta.abierta)])
	await _esperar(func() -> bool: return b.celda == Vector2i(11, 2), 8.0)
	_ok("2 E2: el bloque vuelve a (11,2) otra vez", b.celda == Vector2i(11, 2))
	# 5) Otra vez la solución, y se sale.
	_ok("2 E2: barrera de nuevo", await _barrera_e2())
	await _apretar(ESTE, b, func() -> bool: return b.moviendo and not b.acoplado, 6.0)
	await _esperar(func() -> bool: return not b.moviendo, 8.0)
	await _esperar(func() -> bool: return puerta.abierta, 2.0)
	_ok("2 E2: de nuevo el hielo para sobre la placa y la puerta se abre", b.celda == Vector2i(12, 2) and puerta.abierta)
	if not await _ruta("2 E2", [Vector2i(9, 2), Vector2i(9, 4), Vector2i(10, 5), Vector2i(12, 6), Vector2i(15, 6), Vector2i(16, 6), Vector2i(17, 6)]):
		return false
	_ok("2 E2: se cruza la puerta hacia E3", celda_jugador().x >= 17)
	return true


# ---------------------------------------------------------------------------------------------------------------------
#  3 · E3 · La veta
# ---------------------------------------------------------------------------------------------------------------------

func _e3() -> bool:
	var b: BloqueEmpujable3D = _z.nodo("bloque_e3") as BloqueEmpujable3D
	var cristal: CristalPulso3D = _z.nodo("latido_e3") as CristalPulso3D
	var receptor: ReceptorPulso3D = _z.nodo("receptor_e3") as ReceptorPulso3D
	var reja: Puzle3D.PuertaPuzle = _z.nodo("reja_e3") as Puzle3D.PuertaPuzle
	_ok("3 E3: bloque, cristal, receptor y reja están; el hueco (21,2) sin tender", b != null and cristal != null and receptor != null and reja != null and not Pulso3D.enlace_tendido(Vector2i(21, 2)))
	if b == null or cristal == null or receptor == null or reja == null:
		return false
	if not await _ruta("3 E3", [Vector2i(17, 7), Vector2i(19, 7), [Vector2i(21, 7), TOL_EXACTA]]):
		return false
	var l0: int = cristal.latidos
	await _esperar(func() -> bool: return cristal.latidos >= l0 + 2, 10.0)
	_ok("3 E3 [legible]: el cristal late pero con el hueco vacío el receptor NO se activa y la reja sigue cerrada", cristal.latidos >= l0 + 2 and not receptor.activo and not reja.abierta and Terreno3D.bloqueada(Vector2i(24, 6)))
	# La barrera de tierra no llega al hueco desde donde se empuja (5 casillas).
	_ok("3 E3: tierra + barrera hacia el hueco (21,2) sale (se recorta al alcance)", await _lanzar("tierra", ["barrera"], Vector2i(21, 2), true))
	await avanzar_s(1.0)
	_ok("3 E3 [legible]: la barrera de tierra NO llega al hueco: sigue sin tender", not Pulso3D.enlace_tendido(Vector2i(21, 2)))
	await _esperar(func() -> bool: return Terreno3D.altura_en(Vector2i(21, 4)) == 0 and Terreno3D.altura_en(Vector2i(21, 5)) == 0, 14.0)
	var llegadas: Array = []
	var velocidades: Array = []
	var cl: Callable = func(c: Vector2i, v: float) -> void:
		llegadas.append([c, reloj.t])
		velocidades.append(v)
	b.paso_dado.connect(cl)
	# 1) Soltar a mitad de casilla: el bloque acaba la casilla frenando, en su centro, y ella se para con él.
	_ok("3 E3: se llega a quedar pegada al bloque desde el sur", await _pegarse(NORTE, b))
	var k: Key = await _tecla_hacia(NORTE)
	_tecla(k, true)
	await _esperar(func() -> bool: return b.moviendo and float(b.get("_s")) > 1.0, 6.0)
	var antes_soltar: Vector2i = b.celda
	_tecla(k, false)
	await _esperar(func() -> bool: return not b.moviendo, 6.0)
	var centro: Vector3 = Terreno3D.centro_de(Vector2i(21, 5), 0.0)
	var en_centro: float = Vector2(b.position.x - centro.x, b.position.z - centro.z).length()
	var pj0: Vector3 = jugador.pj.position
	await avanzar_s(0.5)
	_ok("3 E3 [legible]: al soltar a mitad de casilla el bloque ACABA la casilla y se queda en el centro de (21,5) (error %.3f u)" % en_centro, antes_soltar == Vector2i(21, 6) and b.celda == Vector2i(21, 5) and en_centro < 0.03)
	_ok("3 E3: ella se para con el bloque, sin dar un paso de andar de golpe (%.3f u)" % jugador.pj.position.distance_to(pj0), jugador.pj.position.distance_to(pj0) < 0.05)
	llegadas.clear()
	velocidades.clear()
	# 2) Apretando sin soltar: encadena las tres casillas que quedan, sin parar entre ellas.
	var vistos: Array = []
	b.movido.connect(func(c: Vector2i) -> void: vistos.append(c))
	var r: Dictionary = await _apretar(NORTE, b, func() -> bool: return b.celda == Vector2i(21, 2) and not b.moviendo, 40.0)
	b.paso_dado.disconnect(cl)
	var t_ini: float = reloj.t - float(r["t"]) + float(r["t_mueve"])
	var t_total: float = float(llegadas.back()[1]) - t_ini
	var t_const: float = float(llegadas[1][1]) - float(llegadas[0][1])
	var v_const: float = Terreno3D.casilla / t_const
	var d_min: float = 99.0
	var d_max: float = 0.0
	for d in (r["dists"] as Array):
		d_min = minf(d_min, float(d))
		d_max = maxf(d_max, float(d))
	var rmin: float = 99.0
	var rmax: float = 0.0
	for q in (r["ratios"] as Array):
		rmin = minf(rmin, float(q))
		rmax = maxf(rmax, float(q))
	var cmin: float = 99.0
	var cmax: float = 0.0
	for c in (r["carga"] as Array):
		cmin = minf(cmin, float(c))
		cmax = maxf(cmax, float(c))
	print("MEDIDA E3: 3 casillas encadenadas en %.2f s desde que se mueve (arranque incluido); velocidad constante %.2f u/s (%.2f s por casilla); velocidades al pasar por cada centro %s" % [t_total, v_const, t_const, str(velocidades)])
	print("MEDIDA E3: distancia jugadora–bloque %.2f..%.2f u; velocidad del clip / velocidad del bloque %.2f..%.2f; clip cargando %.2f..%.2f" % [d_min, d_max, rmin, rmax, cmin, cmax])
	_ok("3 E3: empujando hacia el norte el bloque sube hasta el hueco (21,2) en UN solo movimiento (sin parar entre casillas)", b.celda == Vector2i(21, 2) and vistos == [Vector2i(21, 2)] and llegadas.size() == 3, str(vistos) + " " + str(llegadas.size()))
	_ok("3 E3: la velocidad de la piedra en el tramo constante es ~1,0 u/s (%.2f; entre 0,8 y 1,2)" % v_const, v_const > 0.8 and v_const < 1.2)
	_ok("3 E3: 3 casillas apretando sin soltar tardan ~3 × 2,3 s más el arranque (%.1f s; entre 6,4 y 8,4)" % t_total, t_total > 6.4 and t_total < 8.4)
	_ok("3 E3: sin paradas intermedias: pasa por el centro de las dos primeras casillas con velocidad > 0,5 u/s (%s)" % str(velocidades.slice(0, 2)), velocidades.size() >= 2 and float(velocidades[0]) > 0.5 and float(velocidades[1]) > 0.5)
	_ok("3 E3: la distancia jugadora–bloque se mantiene constante mientras se mueve (%.2f..%.2f u, ±0,15)" % [d_min, d_max], (r["dists"] as Array).size() > 30 and d_max - d_min <= 0.3)
	_ok("3 E3: el clip «empujar» va a velocidad proporcional a la del bloque (%.2f..%.2f) y lento mientras carga (%.2f..%.2f)" % [rmin, rmax, cmin, cmax], (r["ratios"] as Array).size() > 20 and (rmax - rmin) / maxf(rmax, 0.01) < 0.12 and not (r["carga"] as Array).is_empty() and cmax < 0.5 and cmin > 0.3)
	_ok("3 E3: el bloque de piedra sobre el hueco lo TIENDE", Pulso3D.enlace_tendido(Vector2i(21, 2)))
	await _esperar(func() -> bool: return receptor.activo and reja.abierta, 12.0)
	_ok("3 E3: el pulso cruza el hueco, ACTIVA el receptor y se abre la reja del este (24,6)", receptor.activo and reja.abierta and not Terreno3D.bloqueada(Vector2i(24, 6)))
	if not await _ruta("3 E3", [Vector2i(20, 7), Vector2i(22, 7), Vector2i(23, 6), Vector2i(24, 6), Vector2i(25, 6)]):
		return false
	_ok("3 E3: se cruza la reja hacia E4", celda_jugador().x >= 25)
	return true


# ---------------------------------------------------------------------------------------------------------------------
#  4 · E4 · La otra orilla
# ---------------------------------------------------------------------------------------------------------------------

func _e4() -> bool:
	var b: BloqueEmpujable3D = _z.nodo("bloque_e4") as BloqueEmpujable3D
	var placa: Pulsador3D = _z.nodo("placa_e4") as Pulsador3D
	var reja: Puzle3D.PuertaPuzle = _z.nodo("reja_e4") as Puzle3D.PuertaPuzle
	var cofre: Puzle3D.CofrePuzle = _z.nodo("cofre_e4") as Puzle3D.CofrePuzle
	_ok("4 E4: bloque de hielo, placa, reja y cofre están; la reja cerrada", b != null and placa != null and reja != null and cofre != null and b.material == "hielo" and not reja.abierta)
	if b == null or placa == null or reja == null or cofre == null:
		return false
	_ok("4 E4 [legible]: el agua (27,4) no se pisa: el bloque (28,4) no se alcanza andando", Terreno3D.bloqueada(Vector2i(27, 4)) or Terreno3D.es_agua(Vector2i(27, 4)))
	if not await _ruta("4 E4", [Vector2i(25, 5), [Vector2i(26, 4), TOL_EXACTA]]):
		return false
	# El fuego no lo mueve.
	_ok("4 E4: fuego + flecha al bloque (28,4) sale", await _lanzar("fuego", ["flecha"], Vector2i(28, 4)))
	await avanzar_s(1.5)
	_ok("4 E4 [legible]: el fuego no mueve el bloque (solo el viento) ni lo funde", b.celda == Vector2i(28, 4) and b.empujones == 0 and not placa.activo)
	# El viento cruza el agua y el hielo resbala solo hasta la placa.
	var vistos: Array = []
	b.movido.connect(func(c: Vector2i) -> void: vistos.append(c))
	_ok("4 E4: viento + flecha hacia el bloque cruza el agua y sale", await _lanzar("viento", ["flecha"], Vector2i(28, 4)))
	await _esperar(func() -> bool: return not vistos.is_empty(), 9.0)
	await _esperar(func() -> bool: return reja.abierta, 2.0)
	_ok("4 E4: UN impacto de viento y el hielo resbala hasta el fondo (31,4), sobre la placa, y la reja del cofre se abre", b.celda == Vector2i(31, 4) and vistos == [Vector2i(31, 4)] and placa.activo and reja.abierta, str(vistos) + " " + str(b.celda))
	var e0: int = b.empujones
	_ok("4 E4: otro flechazo de viento sale", await _lanzar("viento", ["flecha"], Vector2i(31, 4)))
	await avanzar_s(1.5)
	_ok("4 E4 [legible]: contra el fondo de la pista el viento ya no lo mueve; la placa sigue pisada", b.celda == Vector2i(31, 4) and b.empujones == e0 and placa.activo and reja.abierta)
	if not await _ruta("4 E4", [Vector2i(25, 4), [Vector2i(25, 3), TOL_EXACTA], [Vector2i(25, 2), TOL_EXACTA]]):
		return false
	var oro0: int = Estado.i().oro
	await _pulsar_e()
	await _esperar(func() -> bool: return cofre.es_abierto, 5.0)
	_ok("4 E4: con E se abre el cofre (50 de oro)", cofre.es_abierto and Estado.i().oro == oro0 + 50)
	_ok("FIN: cuatro salas, un bloque en cada una, a pie y con hechizos reales", cofre.es_abierto)
	return true

# ---------------------------------------------------------------------------------------------------------------------
#  5 · Volver a entrar
# ---------------------------------------------------------------------------------------------------------------------

func _recargar_sala() -> void:
	maqueta.get_parent().remove_child(maqueta)
	maqueta.queue_free()
	await avanzar(5)
	await cargar(RUTA_SALA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(20)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	if _z == null:
		_ok("5 recarga: Puzle3D", false)
		return
	await avanzar_s(1.0)
	var origenes: Dictionary = {"bloque_e1": Vector2i(3, 4), "bloque_e2": Vector2i(11, 2), "bloque_e3": Vector2i(21, 6), "bloque_e4": Vector2i(28, 4)}
	var bien: bool = true
	var donde: String = ""
	for id in origenes:
		var b: BloqueEmpujable3D = _z.nodo(id) as BloqueEmpujable3D
		var aqui: bool = b != null and b.celda == origenes[id] and Terreno3D.bloqueada(b.celda)
		bien = bien and aqui
		donde += " %s=%s" % [id, str(b.celda) if b != null else "null"]
	_ok("5 recarga: los bloques vuelven a su casilla del mapa (no se guarda dónde quedaron)" + donde, bien)
	var libres: bool = true
	for c in [Vector2i(7, 4), Vector2i(12, 2), Vector2i(21, 2), Vector2i(31, 4)]:
		libres = libres and not Terreno3D.bloqueada(c) and not BloqueEmpujable3D.piedra_en(c)
	_ok("5 recarga: las casillas donde terminaron (placas y hueco) están libres", libres)
	var pl: Pulsador3D = _z.nodo("placa_e1") as Pulsador3D
	var pu: Puzle3D.PuertaPuzle = _z.nodo("puerta_e1") as Puzle3D.PuertaPuzle
	var re: ReceptorPulso3D = _z.nodo("receptor_e3") as ReceptorPulso3D
	var rj: Puzle3D.PuertaPuzle = _z.nodo("reja_e3") as Puzle3D.PuertaPuzle
	_ok("5 recarga: las placas nacen libres y sus puertas cerradas; lo que recuerda una flag (receptor y reja de E3) sigue resuelto",
		pl != null and not pl.activo and pu != null and not pu.abierta and re != null and re.activo and rj != null and rj.abierta)
