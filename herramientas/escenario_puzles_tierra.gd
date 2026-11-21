extends "res://herramientas/escenario_base.gd"
## Escenario · los siete PUZLES DE TIERRA del LABORATORIO (21/11/2026, Juego): T1 «Placa a distancia», T2 «Dos placas, una roca y la tierra», T3 «Desvía el arroyo», T4 «Puente de suelo», T5 «Escudo contra flechas»,
## T6 «Bloque de enlace» y T7 «Sella la mámoa». Carga laboratorios/LabPuzlesTierra3D.tscn (kit `demo`: fuego, agua y tierra; flecha, línea, barrera, altura, ᚱ y ᛒ) y juega cada sala con hechizos de verdad (los que saldrían del libro:
## `place_element` + `place_sigil` + `lanzar_pagina_ya`, con el origen en el punto apuntado para lo que nace donde apuntas) y andando de verdad con las teclas. Dos pasadas, como los demás escenarios de laboratorio:
##   · `natural`  (por defecto): la vía de la jugadora (hechizos), con sus CONTROLES (lo que NO debe resolver el puzle: el hechizo equivocado, el sitio equivocado, la tierra caducada).
##   · `botones`  (escenario_puzles_tierra_botones.gd): el botón `!` y la placa `@` de cada sala, que separan «falla el hechizo» de «falla el disparador».
## Lo que se abre, se llena o se rompe no se deshace, así que cada vía que necesita la sala intacta RECARGA la escena (`_recargar`: libera la maqueta y vuelve a cargarla).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_tierra.gd
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_tierra_botones.gd
## CÓMO SE LANZA (lo que se mide en el lab, no lo que dice el papel): un sólido quieto de tierra (tierra sola = losa, tierra + barrera = bloque) NACE DONDE SE APUNTA (a ≤ 3 casillas) y dura 7 s (no los 25 s de `construir_tierra`: el volumen V2 trae su
## `persiste`); tierra + flecha es un proyectil que NO construye; tras lanzar la jugadora queda ~1,6 s quieta. Por eso `_lanzar_en` pasa el origen = la casilla apuntada.

const RUTA_LAB: String = "res://laboratorios/LabPuzlesTierra3D.tscn"
const SUR := Vector3(0, 0, 1)

var modo: String = "natural"          ## "natural" | "botones" (lo cambia el escenario hijo en su _init)
var lab: Node = null
var _w: Vector2 = Vector2.ZERO        ## hacia dónde empuja W (plano XZ), medido una vez: la cámara es fija
var _d: Vector2 = Vector2.ZERO        ## hacia dónde empuja D


func _escenario() -> void:
	await _recargar()
	_ok("0 el mapa y las piezas del lab de tierra se montan sin avisos", (lab.get("_avisos") as Array).is_empty(), str(lab.get("_avisos")))
	colocar_jugador(Vector2i(12, 5))
	await avanzar_s(0.5)
	_w = await _empuje(KEY_W)
	_d = await _empuje(KEY_D)
	_ok("0 las teclas mueven a la jugadora (W %s, D %s)" % [str(_w), str(_d)], _w.length() > 0.5 and _d.length() > 0.5)
	await _t1()
	await _t2()
	await _t3()
	await _t4()
	await _t5()
	await _t6()
	await _t7()


# ---------------------------------------------------------------------------------------------------------------------
#  Herramientas
# ---------------------------------------------------------------------------------------------------------------------

## Carga el laboratorio de cero (si ya había uno, lo libera antes). Deja `lab` apuntando a su nodo de reglas.
func _recargar() -> void:
	if maqueta != null and is_instance_valid(maqueta):
		maqueta.queue_free()
		maqueta = null
		await avanzar(5)
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")
	_ok("0 el laboratorio cuelga de la escena", lab != null)
	lanzador.tinta = null


## Los bloques de tierra vivos (los de la materia V2 no cuentan en `Lanzador3D.bloques_de_tierra()`: se leen de `_bloques`).
func _bloques_vivos() -> int:
	return lanzador._bloques.size()


func _sala(nombre: String) -> Dictionary:
	return lab.call("sala", nombre)


func _tecla_sala(tecla: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = tecla
	ev.pressed = true
	lab.call("_unhandled_input", ev)


func _abierta(nd: Variant) -> bool:
	return bool((nd as Object).get("abierta"))


func _activo(nd: Variant) -> bool:
	return bool((nd as Object).get("activo"))


## Lanza `elemento` + `glifos` desde la casilla `desde` hacia `origen`, con el origen del hechizo en esa casilla (lo que hace el juego con un sólido que nace donde apuntas, a ≤ 3 casillas).
func _lanzar_en(elemento: String, glifos: Array, origen: Vector2i, desde: Vector2i, hacia: Vector3 = Vector3.ZERO) -> bool:
	colocar_jugador(desde)
	var dir: Vector3 = hacia if hacia != Vector3.ZERO else Terreno3D.centro_de(origen, 0.0) - Terreno3D.centro_de(desde, 0.0)
	dir.y = 0.0
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	return lanzador.lanzar_pagina_ya(0, Terreno3D.centro_de(origen, Terreno3D.y_pies(origen)), dir.normalized())


## Anda de verdad hacia el centro de una casilla con las teclas (con las direcciones ya medidas). true si llegó a menos de `tol` casillas.
func _andar_a(c: Vector2i, max_s: float = 6.0, tol: float = 0.3) -> bool:
	var meta: Vector3 = Terreno3D.centro_de(c, 0.0)
	var inicio: float = reloj.t
	var llego: bool = false
	while reloj.t - inicio < max_s:
		var a: Vector2 = Vector2(meta.x - jugador.position.x, meta.z - jugador.position.z)
		if a.length() <= tol * Terreno3D.casilla:
			llego = true
			break
		_tecla(KEY_W, a.dot(_w) > 0.15 * a.length())
		_tecla(KEY_S, a.dot(_w) < -0.15 * a.length())
		_tecla(KEY_D, a.dot(_d) > 0.15 * a.length())
		_tecla(KEY_A, a.dot(_d) < -0.15 * a.length())
		await process_frame
	for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_tecla(k, false)
	return llego


## Anda por una ruta de casillas; true si llegó a todas (cada tramo con su tope de tiempo).
func _andar_ruta(ruta: Array, max_s_tramo: float = 4.0) -> bool:
	for c in ruta:
		if not await _andar_a(c as Vector2i, max_s_tramo):
			return false
	return true


## ¿Se llega andando de `desde` a `hasta`? (por casillas pisables: no vacío salvo losa de tierra, no bloqueadas; `hasta` puede estar bloqueada: un cofre, una placa).
func _alcanzable(desde: Vector2i, hasta: Vector2i) -> bool:
	var visto: Dictionary = {desde: true}
	var cola: Array = [desde]
	while not cola.is_empty():
		var c: Vector2i = cola.pop_front()
		if c == hasta:
			return true
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if visto.has(n) or not Terreno3D.en_mapa(n):
				continue
			if Terreno3D.es_vacio(n) and not Terreno3D.plataformas_tierra.has(n):
				continue
			if Terreno3D.bloqueada(n) and n != hasta and not Terreno3D.plataformas_tierra.has(n):
				continue
			visto[n] = true
			cola.append(n)
	return false


## Espera (hasta `max_s` s) a que `cond` se cumpla; devuelve los segundos que tardó o -1.
func _esperar(cond: Callable, max_s: float) -> float:
	var t0: float = reloj.t
	while reloj.t - t0 < max_s:
		if bool(cond.call()):
			return reloj.t - t0
		await process_frame
	return -1.0


# ---------------------------------------------------------------------------------------------------------------------
#  T1 · Placa a distancia
# ---------------------------------------------------------------------------------------------------------------------

func _t1() -> void:
	await _recargar()
	var q: Dictionary = _sala("T1")
	_ok("T1.0 la sala existe en el lab", not q.is_empty())
	if q.is_empty():
		return
	var peso: Pulsador3D = q["peso"]
	var puerta: Variant = q["puerta"]
	var cofre: Variant = q["cofre"]
	_tecla_sala(KEY_1)
	_ok("T1.1 la tecla 1 lleva a la sala (4,7)", celda_jugador() == Vector2i(4, 7), str(celda_jugador()))
	_ok("T1.2 estado inicial: placa de PESO (7,6) libre y pide 1 de peso, puerta (4,3) cerrada y bloqueando, cofre cerrado detrás", peso.peso_min == 1 and peso.celda == Vector2i(7, 6) and not _activo(peso) and not _abierta(puerta)
		and Terreno3D.bloqueada(Vector2i(4, 3)) and bool(cofre.get("es_cerrado")))
	_ok("T1.3 la placa está en una isla de vacío: no se llega andando (ni al cofre, que está tras la puerta)", not _alcanzable(Vector2i(4, 7), Vector2i(7, 6)) and not _alcanzable(Vector2i(4, 7), Vector2i(4, 1)))
	if modo == "botones":
		var boton: Pulsador3D = q["boton"]
		var placa: Pulsador3D = q["placa"]
		boton.pulsar()
		await avanzar_s(0.6)
		_ok("T1.20 el botón ! (2,5) abre la puerta (sin pisar la placa de peso: %s)" % str(_activo(peso)), boton.veces == 1 and _abierta(puerta) and not _activo(peso))
		_ok("T1.21 … y ahora se llega al cofre andando (casilla libre y camino hasta (4,1))", not Terreno3D.bloqueada(Vector2i(4, 3)) and _alcanzable(Vector2i(4, 7), Vector2i(4, 1)))
		await _recargar()
		q = _sala("T1")
		colocar_jugador(Vector2i(2, 7))
		await avanzar_s(0.8)
		_ok("T1.22 la placa @ (2,7) abre la puerta por su regla", q["placa"].veces == 1 and _abierta(q["puerta"]))
		return
	# Controles: lo que NO debe resolverlo.
	_ok("T1.4 fuego + flecha a la placa de la isla sale", _lanzar_en("fuego", ["flecha"], Vector2i(7, 6), Vector2i(4, 6)))
	await avanzar_s(2.0)
	_ok("T1.5 el fuego no pesa: la placa sigue libre y la puerta cerrada", not _activo(peso) and not _abierta(puerta))
	_ok("T1.6 tierra + flecha sale (es un proyectil: no construye nada)", _lanzar_en("tierra", ["flecha"], Vector2i(7, 6), Vector2i(4, 6)))
	await avanzar_s(2.0)
	_ok("T1.7 tierra + flecha no levanta tierra (bloques %d, losas %d): la placa sigue libre" % [_bloques_vivos(), Terreno3D.plataformas_tierra.size()], not _activo(peso) and not _abierta(puerta) and _bloques_vivos() == 0 and Terreno3D.plataformas_tierra.is_empty())
	# La vía natural: tierra + barrera nace donde se apunta (la casilla de la isla, a 3 casillas).
	_ok("T1.8 tierra + barrera apuntando a la isla (7,6) desde (4,6) sale", _lanzar_en("tierra", ["barrera"], Vector2i(7, 6), Vector2i(4, 6)))
	await avanzar_s(0.8)
	_ok("T1.9 el bloque de tierra (%d vivos) PESA sobre la placa: la pisa (activa %s)" % [_bloques_vivos(), str(_activo(peso))], _bloques_vivos() == 1 and _activo(peso))
	_ok("T1.10 … y la puerta se abre", _abierta(puerta) and not Terreno3D.bloqueada(Vector2i(4, 3)))
	var t_bloque: float = reloj.t
	var llego: bool = await _andar_ruta([Vector2i(4, 5), Vector2i(4, 4), Vector2i(4, 3), Vector2i(4, 2)], 5.0)
	_ok("T1.11 se cruza la puerta andando hasta (4,2) a los %.1f s de lanzar, con el bloque aún vivo (%s)" % [reloj.t - t_bloque, str(_abierta(puerta))], llego and reloj.t - t_bloque < 7.0 and _abierta(puerta))
	var t_cierra: float = await _esperar(func() -> bool: return not _abierta(puerta), 12.0)
	_ok("T1.12 el bloque caduca (a los %.1f s de lanzar): la placa se suelta y la puerta se CIERRA tras ella" % (reloj.t - t_bloque), t_cierra >= 0.0 and not _activo(peso) and _bloques_vivos() == 0 and Terreno3D.bloqueada(Vector2i(4, 3)))
	# Segunda forma: la tierra sola (una losa) también pesa.
	await _recargar()
	q = _sala("T1")
	_ok("T1.13 tierra sola (la losa) apuntando a la isla sale", _lanzar_en("tierra", [], Vector2i(7, 6), Vector2i(4, 6)))
	await avanzar_s(0.8)
	_ok("T1.14 la losa de tierra también pesa sobre la placa (losas %d) y abre la puerta" % Terreno3D.plataformas_tierra.size(), _activo(q["peso"]) and _abierta(q["puerta"]) and Terreno3D.plataformas_tierra.has(Vector2i(7, 6)))


# ---------------------------------------------------------------------------------------------------------------------
#  T2 · Dos placas, una roca y la tierra
# ---------------------------------------------------------------------------------------------------------------------

## Empuja una roca UNA casilla: anda contra ella con `tecla` hasta que se pone en marcha y suelta (si siguiera apretando, el bloque ENCADENA la casilla siguiente y se pasaría de la placa); espera a que pare.
func _empujar_roca(roca: BloqueEmpujable3D, tecla: Key, destino: Vector2i, max_s: float = 6.0) -> bool:
	var inicio: float = reloj.t
	while reloj.t - inicio < max_s and not roca.moviendo and roca.celda != destino:
		_tecla(tecla, true)
		await process_frame
	_tecla(tecla, false)
	await _esperar(func() -> bool: return not roca.moviendo, 3.0)
	await avanzar_s(0.8)
	return roca.celda == destino


## La roca de T2, de (10,6) a (10,5), desde (10,7).
func _empujar_roca_t2(roca: BloqueEmpujable3D) -> bool:
	colocar_jugador(Vector2i(10, 7))
	await avanzar_s(0.4)
	return await _empujar_roca(roca, KEY_W, Vector2i(10, 5))


func _t2() -> void:
	await _recargar()
	var q: Dictionary = _sala("T2")
	_ok("T2.0 la sala existe en el lab", not q.is_empty())
	if q.is_empty():
		return
	var pa: Pulsador3D = q["pa"]
	var pb: Pulsador3D = q["pb"]
	var roca: BloqueEmpujable3D = q["roca"]
	var puerta: Variant = q["puerta"]
	_tecla_sala(KEY_2)
	_ok("T2.1 la tecla 2 lleva a la sala (12,7)", celda_jugador() == Vector2i(12, 7), str(celda_jugador()))
	_ok("T2.2 estado inicial: dos placas de peso 1 libres, la roca pequeña (pesa 1) en (10,6) y la puerta (12,3) cerrada", pa.peso_min == 1 and pb.peso_min == 1 and not _activo(pa) and not _activo(pb) and roca.celda == Vector2i(10, 6) and roca.peso_valor == 1 and not _abierta(puerta))
	if modo == "botones":
		q["boton"].pulsar()
		await avanzar_s(0.6)
		_ok("T2.20 el botón ! (13,7) abre la puerta sin pisar ninguna placa", q["boton"].veces == 1 and _abierta(puerta) and not _activo(pa) and not _activo(pb))
		await _recargar()
		q = _sala("T2")
		colocar_jugador(Vector2i(15, 7))
		await avanzar_s(0.8)
		_ok("T2.21 la placa @ (15,7) abre la puerta por su regla", q["placa"].veces == 1 and _abierta(q["puerta"]))
		return
	# (a) Solo la tierra, sin roca: no basta.
	_ok("T2.3 tierra + barrera sobre la placa B (14,5) desde (12,6) sale", _lanzar_en("tierra", ["barrera"], Vector2i(14, 5), Vector2i(12, 6)))
	await avanzar_s(0.8)
	_ok("T2.4 el bloque pisa la placa B pero con la A libre la puerta sigue CERRADA", _activo(pb) and not _activo(pa) and not _abierta(puerta))
	var cae_a: float = await _esperar(func() -> bool: return not _activo(pb), 12.0)
	_ok("T2.5 el bloque caduca y la placa B se suelta (a los %.1f s)" % cae_a, cae_a >= 0.0 and _bloques_vivos() == 0)
	# (b) Solo la roca: tampoco.
	_ok("T2.6 se empuja la roca al norte sobre la placa A (10,5)", await _empujar_roca_t2(roca))
	_ok("T2.7 la roca pesa 1 y pisa la placa A (la jugadora no cuenta) pero con la B libre la puerta sigue cerrada", _activo(pa) and not _activo(pb) and not _abierta(puerta))
	# (c) Las dos a la vez.
	_ok("T2.8 tierra + barrera sobre la placa B desde (12,6) sale otra vez", _lanzar_en("tierra", ["barrera"], Vector2i(14, 5), Vector2i(12, 6)))
	var t_bloque: float = reloj.t
	await avanzar_s(0.8)
	_ok("T2.9 con la roca en A y la tierra en B la puerta se ABRE", _activo(pa) and _activo(pb) and _abierta(puerta))
	var llego: bool = await _andar_ruta([Vector2i(12, 5), Vector2i(12, 4), Vector2i(12, 3), Vector2i(12, 2)], 4.0)
	_ok("T2.10 se cruza andando hasta (12,2) a los %.1f s de lanzar, con el bloque vivo" % (reloj.t - t_bloque), llego and reloj.t - t_bloque < 7.0 and _abierta(puerta))
	var t_cierra: float = await _esperar(func() -> bool: return not _abierta(puerta), 12.0)
	_ok("T2.11 al caducar el bloque (a los %.1f s) la puerta se CIERRA aunque la roca siga encima de A (A pisada %s)" % [reloj.t - t_bloque, str(_activo(pa))], t_cierra >= 0.0 and _activo(pa) and not _activo(pb))
	# (d) La tierra también vale para las dos: dos bloques.
	await _recargar()
	q = _sala("T2")
	_lanzar_en("tierra", ["barrera"], Vector2i(10, 5), Vector2i(11, 7))
	await avanzar_s(0.4)
	_lanzar_en("tierra", ["barrera"], Vector2i(14, 5), Vector2i(13, 7))
	await avanzar_s(0.8)
	_ok("T2.12 dos bloques de tierra (uno en cada placa) también abren la puerta (la roca no es la única forma): bloques %d" % _bloques_vivos(), _activo(q["pa"]) and _activo(q["pb"]) and _abierta(q["puerta"]))


# ---------------------------------------------------------------------------------------------------------------------
#  T3 · Desvía el arroyo
# ---------------------------------------------------------------------------------------------------------------------

func _t3() -> void:
	await _recargar()
	var q: Dictionary = _sala("T3")
	_ok("T3.0 la sala existe en el lab", not q.is_empty())
	if q.is_empty():
		return
	var nivel: NivelAgua3D = q["nivel"]
	var puerta: Variant = q["puerta"]
	_tecla_sala(KEY_3)
	_ok("T3.1 la tecla 3 lleva a la sala (20,7)", celda_jugador() == Vector2i(20, 7), str(celda_jugador()))
	_ok("T3.2 estado inicial: detector del vaso (19,6) en 0,30, puerta (23,6) cerrada", is_equal_approx(nivel.objetivo, 0.3) and not _abierta(puerta) and Terreno3D.bloqueada(Vector2i(23, 6)))
	if modo == "botones":
		q["boton"].pulsar()
		await avanzar_s(0.6)
		_ok("T3.20 el botón ! (17,7) abre la puerta sin presa ni agua en el vaso (nivel %.2f)" % nivel.profundidad, q["boton"].veces == 1 and _abierta(puerta) and nivel.profundidad < 0.3)
		await _recargar()
		q = _sala("T3")
		colocar_jugador(Vector2i(21, 7))
		await avanzar_s(0.8)
		_ok("T3.21 la placa @ (21,7) abre la puerta por su regla", q["placa"].veces == 1 and _abierta(q["puerta"]))
		return
	# Sin hacer nada: el agua pasa de largo y el brazo se queda bajo.
	await avanzar_s(10.0)
	var mx0: float = 0.0
	var t0: float = reloj.t
	while reloj.t - t0 < 6.0:
		await process_frame
		mx0 = maxf(mx0, nivel.profundidad)
	_ok("T3.3 sin presa el arroyo corre al sumidero y el vaso se queda en %.2f (< 0,30): la puerta sigue cerrada" % mx0, mx0 < 0.3 and not _abierta(puerta))
	_ok("T3.4 el arroyo es poco profundo en la casilla de la presa (21,3): se puede construir ahí (motivo de rechazo: «%s»)" % lanzador.puede_construir_en(Vector2i(21, 3)), lanzador.puede_construir_en(Vector2i(21, 3)) == "")
	# Control: una presa ANTES del brazo (aguas arriba) lo deja seco.
	_ok("T3.5 tierra + barrera en el cauce ANTES del brazo (18,3) desde (18,5) sale", _lanzar_en("tierra", ["barrera"], Vector2i(18, 3), Vector2i(18, 5)))
	var mx1: float = 0.0
	t0 = reloj.t
	while reloj.t - t0 < 8.5:
		await process_frame
		mx1 = maxf(mx1, nivel.profundidad)
	_ok("T3.6 la presa aguas arriba corta el agua al brazo: el vaso no sube (máx. %.2f) y la puerta sigue cerrada" % mx1, mx1 < 0.3 and not _abierta(puerta))
	await _esperar(func() -> bool: return _bloques_vivos() == 0, 5.0)
	# La vía natural: la presa DESPUÉS del brazo.
	_ok("T3.7 tierra + barrera en el cauce DESPUÉS del brazo (21,3) desde (21,5) sale", _lanzar_en("tierra", ["barrera"], Vector2i(21, 3), Vector2i(21, 5)))
	var t_presa: float = reloj.t
	await avanzar_s(1.5)
	var seco_abajo: float = Terreno3D.agua_sim.profundidad_casilla(Vector2i(22, 3))
	var t_sube: float = await _esperar(func() -> bool: return _abierta(puerta), 9.0)
	_ok("T3.8 el agua remonta por el brazo y el vaso llega a %.2f (≥ 0,30) a los %.1f s de la presa: la puerta se ABRE" % [nivel.profundidad, t_sube], t_sube >= 0.0 and _abierta(puerta) and not Terreno3D.bloqueada(Vector2i(23, 6)))
	_ok("T3.9 mientras la presa aguanta, el cauce de DESPUÉS de ella (22,3) está seco (%.2f): el agua no pasa" % seco_abajo, seco_abajo < 0.03)
	var t_baja: float = await _esperar(func() -> bool: return _bloques_vivos() == 0, 10.0)
	await avanzar_s(4.0)
	var vuelve: float = Terreno3D.agua_sim.profundidad_casilla(Vector2i(22, 3))
	_ok("T3.10 la presa caduca (a los %.1f s): el agua vuelve a su cauce (%.2f en (22,3)) y la puerta SE QUEDA abierta (es una vez)" % [reloj.t - t_presa, vuelve], t_baja >= 0.0 and vuelve > 0.03 and _abierta(puerta))


# ---------------------------------------------------------------------------------------------------------------------
#  T4 · Puente de suelo
# ---------------------------------------------------------------------------------------------------------------------

func _t4() -> void:
	await _recargar()
	var q: Dictionary = _sala("T4")
	_ok("T4.0 la sala existe en el lab", not q.is_empty())
	if q.is_empty():
		return
	var cofre: Variant = q["cofre"]
	_tecla_sala(KEY_4)
	_ok("T4.1 la tecla 4 lleva a la sala (28,7)", celda_jugador() == Vector2i(28, 7), str(celda_jugador()))
	_ok("T4.2 estado inicial: un foso de vacío de dos casillas (28,5) y (28,4) entre la entrada y el cofre (28,2), que está cerrado", Terreno3D.es_vacio(Vector2i(28, 5)) and Terreno3D.es_vacio(Vector2i(28, 4)) and bool(cofre.get("es_cerrado")))
	_ok("T4.3 el cofre no se alcanza andando desde la entrada", not _alcanzable(Vector2i(28, 7), Vector2i(28, 3)))
	if modo == "botones":
		await _t4_botones(q)
		return
	# Una sola losa no basta.
	_ok("T4.4 tierra + ᛒ suelo apuntando a (28,5) desde (28,6) sale", _lanzar_en("tierra", ["suelo"], Vector2i(28, 5), Vector2i(28, 6)))
	await avanzar_s(0.3)
	var vida_losa: float = float((lanzador._plataformas_tierra[0] as Dictionary)["resta"]) if not lanzador._plataformas_tierra.is_empty() else 0.0
	_ok("T4.5 se planta UNA losa de tierra en (28,5) (losas %s, %.1f s de vida)" % [str(Terreno3D.plataformas_tierra.keys()), vida_losa], Terreno3D.plataformas_tierra.has(Vector2i(28, 5)) and Terreno3D.plataformas_tierra.size() == 1)
	_ok("T4.6 con una sola losa aún no se llega al otro lado (queda la casilla (28,4) de vacío)", not _alcanzable(Vector2i(28, 6), Vector2i(28, 3)) and _alcanzable(Vector2i(28, 6), Vector2i(28, 5)))
	# La segunda losa y a cruzar.
	_ok("T4.7 la segunda losa en (28,4), apuntada desde (28,6) (a 2 casillas), sale", _lanzar_en("tierra", ["suelo"], Vector2i(28, 4), Vector2i(28, 6)))
	var t_losas: float = reloj.t
	_ok("T4.8 con las dos losas el cofre se alcanza andando (en el mapa de casillas)", Terreno3D.plataformas_tierra.size() == 2 and _alcanzable(Vector2i(28, 6), Vector2i(28, 3)))
	var llego: bool = await _andar_ruta([Vector2i(28, 5), Vector2i(28, 4), Vector2i(28, 3)], 6.0)
	_ok("T4.9 se cruza el foso ANDANDO de verdad hasta (28,3) a los %.1f s de la segunda losa (duran 8 s)" % (reloj.t - t_losas), llego and reloj.t - t_losas < 7.5)
	var t0: float = reloj.t
	while reloj.t - t0 < 6.0 and not bool(cofre.get("es_abierto")):
		cofre.call("abrir")
		await avanzar_s(0.2)
	_ok("T4.10 el cofre (28,2) se abre con E desde la otra orilla", bool(cofre.get("es_abierto")))
	await avanzar_s(9.0)
	_ok("T4.11 las losas caducan (a los %.1f s) y el foso vuelve a ser vacío: no se vuelve andando" % (reloj.t - t_losas), Terreno3D.plataformas_tierra.is_empty() and not _alcanzable(Vector2i(28, 3), Vector2i(28, 7)))


## Las dos vías de T4 sin hechizo: el botón y la placa plantan las dos losas por código (el lab) y se cruza andando.
func _t4_botones(q: Dictionary) -> void:
	var boton: Pulsador3D = q["boton"]
	boton.pulsar()
	await avanzar_s(0.5)
	_ok("T4.20 el botón ! (26,7) planta las dos losas (%s) y se alcanza el cofre" % str(Terreno3D.plataformas_tierra.keys()), boton.veces == 1 and Terreno3D.plataformas_tierra.has(Vector2i(28, 5)) and Terreno3D.plataformas_tierra.has(Vector2i(28, 4)) and _alcanzable(Vector2i(28, 7), Vector2i(28, 3)))
	colocar_jugador(Vector2i(28, 6))
	var llego: bool = await _andar_ruta([Vector2i(28, 5), Vector2i(28, 4), Vector2i(28, 3)], 6.0)
	_ok("T4.21 se cruza andando hasta (28,3) por las losas del botón", llego)
	await _recargar()
	q = _sala("T4")
	colocar_jugador(Vector2i(30, 7))
	await avanzar_s(0.8)
	_ok("T4.22 la placa @ (30,7) planta las dos losas por su regla (lab: %d veces)" % int(lab.get("_losas_via_puestas")), q["placa"].veces == 1 and Terreno3D.plataformas_tierra.size() == 2 and _alcanzable(Vector2i(28, 7), Vector2i(28, 3)))


# ---------------------------------------------------------------------------------------------------------------------
#  T5 · Escudo contra flechas
# ---------------------------------------------------------------------------------------------------------------------

const RUTA_T5: Array = [Vector2i(4, 15), Vector2i(4, 16), Vector2i(5, 16), Vector2i(6, 16), Vector2i(7, 16)]


func _t5() -> void:
	await _recargar()
	var q: Dictionary = _sala("T5")
	_ok("T5.0 la sala existe en el lab", not q.is_empty())
	if q.is_empty():
		return
	var tr: TrampaFlechas3D = q["trampa"]
	var cofre: Variant = q["cofre"]
	_tecla_sala(KEY_5)
	_ok("T5.1 la tecla 5 lleva a la sala (4,11)", celda_jugador() == Vector2i(4, 11), str(celda_jugador()))
	_ok("T5.2 estado inicial: mascarón (4,18) hacia el norte, flecha normal cada 1 s, dormido hasta que se llega a 3 casillas; cofre oculto", tr.celda == Vector2i(4, 18) and tr.mira == "n" and is_equal_approx(tr.cada_s, 1.0) and tr.elemento == "" and tr.cerca == 3.0 and tr.activa and bool(cofre.get("es_oculto")))
	colocar_jugador(Vector2i(4, 12))
	await avanzar_s(3.0)
	_ok("T5.3 mientras la jugadora está lejos (a 5 casillas de la boca) el mascarón duerme: %d disparos en 3 s" % tr.disparos, tr.disparos == 0)
	if modo == "botones":
		var boton: Pulsador3D = q["boton"]
		boton.pulsar()
		await avanzar_s(0.5)
		_ok("T5.20 el botón ! (2,12) apaga el mascarón (activa = %s)" % str(tr.activa), boton.veces == 1 and not tr.activa)
		jugador.vida = 1000.0
		colocar_jugador(Vector2i(4, 14))
		var llego: bool = await _andar_ruta(RUTA_T5, 4.0)
		_ok("T5.21 con el mascarón apagado se llega a la placa del fondo sin un solo flechazo (vida %.0f/1000, disparos %d)" % [jugador.vida, tr.disparos], llego and jugador.vida == 1000.0 and tr.disparos == 0)
		await avanzar_s(0.8)
		_ok("T5.22 … y aparece el cofre", not bool(cofre.get("es_oculto")))
		await _recargar()
		q = _sala("T5")
		colocar_jugador(Vector2i(6, 12))
		await avanzar_s(1.0)
		_ok("T5.23 la placa @ (6,12) hace aparecer el cofre por su condición", q["placa"].veces == 1 and not bool(q["cofre"].get("es_oculto")))
		return
	# Sin escudo: la jugadora cruza el pasillo (con vida de sobra para medir) y recibe flechazos.
	jugador.vida = 1000.0
	colocar_jugador(Vector2i(4, 14))
	var t0: float = reloj.t
	var llego_sin: bool = await _andar_ruta(RUTA_T5, 5.0)
	var perdida: float = 1000.0 - jugador.vida
	_ok("T5.4 SIN escudo, cruzar el pasillo cuesta vida: %.0f de daño en %.1f s (llega %s), %d disparos" % [perdida, reloj.t - t0, str(llego_sin), tr.disparos], perdida >= 12.0 and tr.disparos >= 1)
	# Con escudo (sala nueva): el bloque delante de la boca.
	await _recargar()
	q = _sala("T5")
	tr = q["trampa"]
	cofre = q["cofre"]
	colocar_jugador(Vector2i(4, 14))
	_ok("T5.5 tierra + barrera apuntando a la casilla de delante de la boca (4,17) desde (4,14) sale", _lanzar_en("tierra", ["barrera"], Vector2i(4, 17), Vector2i(4, 14)))
	await avanzar_s(1.0)
	_ok("T5.6 el bloque de tierra está en (4,17) (bloques %d)" % _bloques_vivos(), _bloques_vivos() == 1 and Terreno3D.altura_en(Vector2i(4, 17)) >= 1)
	t0 = reloj.t
	var vida0: float = jugador.vida
	var llego_con: bool = await _andar_ruta(RUTA_T5, 5.0)
	_ok("T5.7 CON el escudo se llega andando a la placa del fondo (7,16) en %.1f s (vida %.0f → %.0f), mientras el mascarón sigue disparando (%d disparos) al bloque" % [reloj.t - t0, vida0, jugador.vida, tr.disparos], llego_con and jugador.vida == vida0 and tr.disparos >= 1)
	await avanzar_s(0.8)
	_ok("T5.8 la placa del fondo está pisada y el cofre aparece (oculto %s)" % str(bool(cofre.get("es_oculto"))), _activo(q["fondo"]) and not bool(cofre.get("es_oculto")))
	var t_cae: float = await _esperar(func() -> bool: return _bloques_vivos() == 0, 8.0)
	_ok("T5.9 el bloque caduca (%.1f s más): el escudo no es para siempre" % t_cae, t_cae >= 0.0)


# ---------------------------------------------------------------------------------------------------------------------
#  T6 · Bloque de enlace
# ---------------------------------------------------------------------------------------------------------------------

func _t6() -> void:
	await _recargar()
	var q: Dictionary = _sala("T6")
	_ok("T6.0 la sala existe en el lab", not q.is_empty())
	if q.is_empty():
		return
	var cristal: CristalPulso3D = q["cristal"]
	var receptor: ReceptorPulso3D = q["receptor"]
	var puerta: Variant = q["puerta"]
	_tecla_sala(KEY_6)
	_ok("T6.1 la tecla 6 lleva a la sala (12,11)", celda_jugador() == Vector2i(12, 11), str(celda_jugador()))
	_ok("T6.2 estado inicial: cristal (9,12) dormido (late solo si le dan), receptor de TIERRA (15,12) libre, puerta (12,14) cerrada", cristal.cada == 0.0 and cristal.celda == Vector2i(9, 12) and receptor.elemento == "tierra" and not _activo(receptor) and not _abierta(puerta))
	if modo == "botones":
		q["boton"].pulsar()
		await avanzar_s(0.6)
		_ok("T6.20 el botón ! (10,13) activa el receptor por su regla y la puerta se abre", q["boton"].veces == 1 and _activo(receptor) and _abierta(puerta))
		await _recargar()
		q = _sala("T6")
		colocar_jugador(Vector2i(14, 13))
		await avanzar_s(0.8)
		_ok("T6.21 la placa @ (14,13) abre la puerta por su regla (el receptor sigue libre)", q["placa"].veces == 1 and _abierta(q["puerta"]) and not _activo(q["receptor"]))
		return
	# Control 1: el pulso sin bloque se para en el hueco.
	_ok("T6.3 tierra + flecha al cristal (9,12) desde (9,13) sale", _lanzar_en("tierra", ["flecha"], Vector2i(9, 12), Vector2i(9, 13)))
	await avanzar_s(2.5)
	_ok("T6.4 el cristal late (%d) pero sin nada sobre el HUECO (12,12) el pulso no pasa: receptor libre, puerta cerrada" % cristal.latidos, cristal.latidos >= 1 and not _activo(receptor) and not _abierta(puerta))
	# Control 2: con el bloque pero con un pulso de FUEGO el receptor de tierra no lo acepta.
	_ok("T6.5 tierra + barrera sobre el hueco (12,12) desde (12,11) sale", _lanzar_en("tierra", ["barrera"], Vector2i(12, 12), Vector2i(12, 11)))
	await avanzar_s(0.5)
	var lat0: int = cristal.latidos
	_ok("T6.6 fuego + flecha al cristal sale", _lanzar_en("fuego", ["flecha"], Vector2i(9, 12), Vector2i(9, 13)))
	await avanzar_s(2.5)
	_ok("T6.7 con el hueco tendido el pulso de FUEGO llega, pero el receptor pide tierra: libre, puerta cerrada (latidos %d → %d)" % [lat0, cristal.latidos], cristal.latidos > lat0 and not _activo(receptor) and not _abierta(puerta))
	# La vía natural: el hueco tendido (el bloque aún vive: 7 s) y un hechizo de tierra al cristal.
	if _bloques_vivos() == 0:
		_lanzar_en("tierra", ["barrera"], Vector2i(12, 12), Vector2i(12, 11))
		await avanzar_s(0.5)
	_ok("T6.8 tierra + flecha al cristal con el bloque sobre el hueco sale", _lanzar_en("tierra", ["flecha"], Vector2i(9, 12), Vector2i(9, 13)))
	var t_pulso: float = await _esperar(func() -> bool: return _activo(receptor), 4.0)
	_ok("T6.9 el pulso de TIERRA cruza el hueco tendido y activa el receptor (a los %.1f s)" % t_pulso, t_pulso >= 0.0)
	_ok("T6.10 … y la puerta (12,14) se abre y se puede pasar", _abierta(puerta) and not Terreno3D.bloqueada(Vector2i(12, 14)))
	await avanzar_s(9.0)
	_ok("T6.11 el bloque caduca y el receptor se queda activo (la puerta sigue abierta: es una vez)", _bloques_vivos() == 0 and _activo(receptor) and _abierta(puerta))
	# Otra forma: el pulso de la propia jugadora (tierra + flecha + ᚱ) sobre la veta, con el hueco tendido.
	await _recargar()
	q = _sala("T6")
	_lanzar_en("tierra", ["barrera"], Vector2i(12, 12), Vector2i(12, 11))
	await avanzar_s(0.5)
	_ok("T6.12 tierra + flecha + ᚱ pulso lanzado a la veta (10,12) desde (10,13) sale", _lanzar_en("tierra", ["flecha", "raido"], Vector2i(10, 12), Vector2i(10, 13), Vector3(1, 0, 0)))
	var t_propio: float = await _esperar(func() -> bool: return _activo(q["receptor"]), 4.0)
	_ok("T6.13 el pulso de la jugadora (de tierra) también cruza el hueco tendido y activa el receptor (a los %.1f s)" % t_propio, t_propio >= 0.0 and _abierta(q["puerta"]))


# ---------------------------------------------------------------------------------------------------------------------
#  T7 · Sella la mámoa
# ---------------------------------------------------------------------------------------------------------------------

func _t7() -> void:
	await _recargar()
	var q: Dictionary = _sala("T7")
	_ok("T7.0 la sala existe en el lab", not q.is_empty())
	if q.is_empty():
		return
	var mamoa: Mamoa3D = q["mamoa"]
	var mouro: MouroEspectro3D = q["mouro"]
	var cofre: Variant = q["cofre"]
	var vigia: Variant = q["vigia"]
	_tecla_sala(KEY_7)
	_ok("T7.1 la tecla 7 lleva a la sala (20,11)", celda_jugador() == Vector2i(20, 11), str(celda_jugador()))
	_ok("T7.2 estado inicial: mámoa (20,14) abierta, mouro con 45 de vida vinculado a ella, cofre oculto", mamoa.celda == Vector2i(20, 14) and mamoa.abierta and mouro.mamoa == mamoa and is_equal_approx(mouro.health, 45.0) and bool(cofre.get("es_oculto")))
	if modo == "botones":
		q["boton"].pulsar()
		await avanzar_s(0.6)
		_ok("T7.20 el botón ! (18,13) tapa la mámoa por su regla (abierta = %s)" % str(mamoa.abierta), q["boton"].veces == 1 and not mamoa.abierta)
		mouro.receive_damage(1000.0)
		await avanzar_s(3.0)
		_ok("T7.21 con la mámoa tapada el mouro muere de verdad y aparece el cofre (oculto %s)" % str(bool(cofre.get("es_oculto"))), not is_instance_valid(mouro) and not bool(cofre.get("es_oculto")))
		await _recargar()
		q = _sala("T7")
		colocar_jugador(Vector2i(22, 13))
		await avanzar_s(1.0)
		_ok("T7.22 la placa @ (22,13) hace aparecer el cofre por su condición (sin vencer al mouro)", q["placa"].veces == 1 and not bool(q["cofre"].get("es_oculto")))
		return
	# Sin sellar: el mouro vuelve y el cofre sigue oculto.
	colocar_jugador(Vector2i(20, 11))
	await avanzar_s(1.0)
	mouro.receive_damage(1000.0)
	await avanzar_s(0.3)
	_ok("T7.3 vencerlo con la mámoa abierta NO lo mata: se deshace (latente %s) y espera volver" % str(mouro.latente), not mouro.muerto and mouro.latente)
	await avanzar_s(5.0)
	_ok("T7.4 a los pocos segundos VUELVE de la mámoa con la vida llena (%.0f) y el cofre sigue oculto" % mouro.health, not mouro.latente and not mouro.muerto and is_equal_approx(mouro.health, 45.0) and bool(cofre.get("es_oculto")) and mouro.rebrotes_gastados == 1)
	# Sellando: tierra + barrera sobre la mámoa y luego vencerlo.
	await _recargar()
	q = _sala("T7")
	mamoa = q["mamoa"]
	mouro = q["mouro"]
	cofre = q["cofre"]
	colocar_jugador(Vector2i(20, 11))
	await avanzar_s(1.0)
	_ok("T7.5 tierra + barrera sobre la mámoa (20,14) desde (20,11) (a 5 casillas del mouro: no despierta) sale", _lanzar_en("tierra", ["barrera"], Vector2i(20, 14), Vector2i(20, 11)))
	await avanzar_s(0.6)
	_ok("T7.6 el bloque la TAPA (abierta = %s)" % str(mamoa.abierta), not mamoa.abierta)
	mouro.receive_damage(1000.0)
	await avanzar_s(2.5)
	_ok("T7.7 vencido con la mámoa tapada, el mouro MUERE de verdad (no vuelve)", not is_instance_valid(mouro))
	_ok("T7.8 … y aparece el cofre (oculto %s, vigía %s)" % [str(bool(cofre.get("es_oculto"))), str(q["vigia"].completo)], not bool(cofre.get("es_oculto")) and bool(cofre.get("es_cerrado")))
	# Otra forma: la roca pequeña empujada sobre la mámoa la tapa para siempre.
	await _recargar()
	q = _sala("T7")
	mamoa = q["mamoa"]
	mouro = q["mouro"]
	cofre = q["cofre"]
	var roca: BloqueEmpujable3D = q["roca"]
	mouro.quieto = true                                    # para medir el empujón: a (18,14) el mouro (a 2,8 casillas) la vería y vendría a por ella
	colocar_jugador(Vector2i(18, 14))
	await avanzar_s(0.4)
	var empujada: bool = await _empujar_roca(roca, KEY_D, Vector2i(20, 14))
	_ok("T7.9 la roca empujada al este llega a la mámoa (20,14) (celda %s) y la TAPA (abierta = %s): para siempre, sin caducar" % [str(roca.celda), str(mamoa.abierta)], roca.celda == Vector2i(20, 14) and not mamoa.abierta)
	await avanzar_s(8.0)
	_ok("T7.10 pasados 8 s (lo que dura la tierra de un hechizo) sigue tapada", not mamoa.abierta)
	mouro.receive_damage(1000.0)
	await avanzar_s(2.5)
	_ok("T7.11 el mouro muere de verdad y aparece el cofre", not is_instance_valid(mouro) and not bool(cofre.get("es_oculto")))
