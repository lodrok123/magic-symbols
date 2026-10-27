extends "res://herramientas/escenario_base.gd"
## LA CUEVA RESONANTE, AUTOPLAY DE PRINCIPIO A FIN (27/10; diseño en docs/CUEVA_RESONANTE.md, mapa mundo/datos_nivel/mapas/CuevaResonante.txt).
## Juega el nivel como lo jugaría una persona y falla en el primer paso que no se pueda hacer así:
##   · se ANDA solo con las teclas WASD (`_andar_a`: nunca teletransporta; si algo tapa el camino, el paso falla y dice dónde se quedó);
##   · se LANZA con la receta real y CON GRAVEDAD (`_lanzar`: como sale del libro; lo que nace donde apuntas, la tierra quieta, nace en el punto apuntado dentro del
##     anillo de 3 casillas, igual que con el ratón), esperando la tinta si falta;
##   · se USA con la tecla E (setas, prisma, puerta de la llave, cofres);
##   · los pulsos del escenario (cristales, fuente) corren solos: el arnés NUNCA suelta un pulso ni coloca a nadie.
## Única ayuda: en la pelea de C4 se repone la vida de la jugadora (los goblins pegan de verdad; esto no prueba el combate).
##
## Recorrido (cada sala comprueba también lo que la hace LEGIBLE: lo que NO debe pasar antes de resolverla):
##   1 C1 · presentar: el cristal late solo, las setas maduran, la geoda explota al acercarse, una flecha de fuego NO enciende el brasero del nicho (la reja la para),
##          el pulso azul tampoco; golpear el cristal con fuego SÍ (el pulso lleva el elemento) → los dos braseros → el paso del norte.
##   2 C2 · el receptor no recibe nada con la veta cortada; un bloque de tierra en el hueco → receptor → reja del este. Opcional: la columna del nicho y su cofre.
##   3 C3 · la geoda: golpear el cristal dormido → explota → la columna cae como PUENTE sobre la lava; se cruza por él. Opcional: enfriar la fila 5 con agua → el pulso cruza
##          el basalto → receptor → reja → cofre.
##   4 C4 · la sala se cierra, dos goblins a flechazos, cofre de la llave.
##   5 C5 · con el prisma mal girado la fuente no llega al receptor de rayo; un giro con E → receptor → la reja del oeste se abre.
##   6 C6 · el cristal golpeado con fuego sin hueco tendido no llega; tierra en el hueco + dos giros del prisma + fuego al cristal → receptor de fuego → cofre desellado;
##          la llave abre el santuario; el cofre legendario da ᚱ; ᚱ abre la pared hueca y se vuelve a C1. FIN: glifo conseguido y usado.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_cueva_resonante.gd

const RUTA: String = "res://escenas/PruebaCuevaResonante.tscn"
const FLAG_GLIFO: String = "cueva.c6.glifo"
const VIDA_MAX: float = 100.0
const T_GOBLINS_MAX_S: float = 90.0
const T_ESPERA_PULSO_MAX_S: float = 20.0
const ALCANCE_FLECHA_CAS: float = 2.8
const T_TINTA_MAX_S: float = 8.0
const TOL_ANDAR: float = 0.3
const TOL_EXACTA: float = 0.12
const T_AGACHARSE_S: float = 2.6

var _z: Puzle3D = null
var _eje_w: Vector2 = Vector2.ZERO
var _eje_d: Vector2 = Vector2.ZERO
var _t0: float = 0.0


# ---------------------------------------------------------------------------------------------------------------------
#  El jugador: andar, lanzar, usar
# ---------------------------------------------------------------------------------------------------------------------

func _medir_ejes() -> void:
	_eje_w = await _empuje(KEY_W)
	_eje_d = await _empuje(KEY_D)


## Anda DE VERDAD (WASD) hasta menos de `tol` casillas del centro de `c`. false si no llega en `max_s` o se atasca 2,5 s.
func _andar_a(c: Vector2i, max_s: float = 14.0, tol: float = TOL_ANDAR) -> bool:
	if _eje_w == Vector2.ZERO:
		await _medir_ejes()
	var meta: Vector3 = Terreno3D.centro_de(c, 0.0)
	var inicio: float = reloj.t
	var mejor: float = INF
	var t_mejora: float = reloj.t
	var llego: bool = false
	while reloj.t - inicio < max_s:
		if not is_instance_valid(jugador):
			break
		var a: Vector2 = Vector2(meta.x - jugador.position.x, meta.z - jugador.position.z)
		var d: float = a.length()
		if d <= tol * Terreno3D.casilla:
			llego = true
			break
		if d < mejor - 0.05:
			mejor = d
			t_mejora = reloj.t
		elif reloj.t - t_mejora > 2.5:
			break
		var adelante: float = a.dot(_eje_w)
		var lado: float = a.dot(_eje_d)
		_tecla(KEY_W, adelante > 0.15 * d)
		_tecla(KEY_S, adelante < -0.15 * d)
		_tecla(KEY_D, lado > 0.15 * d)
		_tecla(KEY_A, lado < -0.15 * d)
		await process_frame
	for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_tecla(k, false)
	await avanzar(2)
	return llego or not is_instance_valid(jugador)


## Una ruta a pie. Cada punto es una casilla o `[casilla, tolerancia]`. Si se atasca, dice dónde y qué hay alrededor.
func _ruta(nombre: String, puntos: Array) -> bool:
	for p in puntos:
		var c: Vector2i = p if p is Vector2i else (p as Array)[0] as Vector2i
		var tol: float = TOL_ANDAR if p is Vector2i else float((p as Array)[1])
		if not await _andar_a(c, 14.0, tol):
			_ok("%s: a pie hasta %s" % [nombre, str(c)], false, "se quedó en %s\n%s" % [str(celda_jugador()), _alrededor()])
			return false
	var ultimo: Variant = puntos.back()
	_ok("%s: a pie hasta %s" % [nombre, str(ultimo if ultimo is Vector2i else (ultimo as Array)[0])], true)
	return true


func _alrededor() -> String:
	var yo: Vector2i = celda_jugador()
	var s: String = ""
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c: Vector2i = yo + Vector2i(dx, dy)
			s += "   %s«%s»%s%s" % [str(c), Terreno3D.letra_de(c), "B" if Terreno3D.bloqueada(c) else "-", str(Terreno3D.altura_en(c))]
		s += "\n"
	return s


func _pulsar_e() -> void:
	_tecla(KEY_E, true)
	await avanzar(2)
	_tecla(KEY_E, false)
	await avanzar(2)


## Compone la página 1 y la lanza hacia el centro de `objetivo` desde donde está la jugadora DE VERDAD, con la gravedad del juego.
## `en_punto` = el hechizo nace donde se apunta (la barrera): el origen es el punto apuntado, recortado al anillo de Lanzador3D.ALCANCE_ORIGEN, como hace el ratón.
## Sin tinta, espera y reintenta (hasta T_TINTA_MAX_S), como haría quien juega.
func _lanzar(elemento: String, glifos: Array, objetivo: Vector2i, en_punto: bool = false) -> bool:
	var t: float = 0.0
	while t <= T_TINTA_MAX_S:
		var yo: Vector3 = jugador.position
		var meta: Vector3 = Terreno3D.centro_de(objetivo, 0.0)
		var hacia: Vector3 = Vector3(meta.x - yo.x, 0.0, meta.z - yo.z)
		var origen: Vector3 = yo
		if en_punto:
			var tope: float = Lanzador3D.ALCANCE_ORIGEN * Terreno3D.casilla
			origen = Vector3(yo.x, yo.y, yo.z) + (hacia if hacia.length() <= tope else hacia.normalized() * tope)
		lanzador.select_page(0)
		lanzador.clear_sequence()
		lanzador.place_element(elemento)
		for g in glifos:
			lanzador.place_sigil(String(g))
		lanzador.cooldown_left[0] = 0.0
		if lanzador.lanzar_pagina_ya(0, origen, hacia.normalized()):
			return true
		t += await avanzar_s(0.5)
	return false


func _curar() -> void:
	jugador.set("vida", VIDA_MAX)


func _esperar(cond: Callable, max_s: float) -> float:
	var t: float = 0.0
	while not bool(cond.call()) and t < max_s:
		t += await avanzar_s(0.1)
	return t


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	_t0 = reloj.t
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("0 Puzle3D monta la Cueva Resonante sin avisos", _z != null and _z.avisos.is_empty(), str(_z.avisos) if _z != null else "sin Puzle3D")
	if _z == null:
		return
	_ok("0 el mapa mide 27 × 25 y la jugadora nace en C1 (4,17)", maqueta.get("_ancho") == 27 and maqueta.get("_alto") == 25 and celda_jugador() == Vector2i(4, 17), str(celda_jugador()))
	_ok("0 se entra con fuego, agua y tierra y SIN ᚱ (kit de pruebas)", Repertoire.element_active("fuego") and Repertoire.element_active("agua") and Repertoire.element_active("tierra") and not Repertoire.sigil_active("raido"))
	for paso in [_c1, _c2, _c3, _c4, _c5, _c6]:
		if not await (paso as Callable).call():
			_ok("FIN: el recorrido se cortó (ver el primer FALLO)", false)
			return
	print("TIEMPO DE JUEGO: %.0f s" % (reloj.t - _t0))
	await _recargar()


# ---------------------------------------------------------------------------------------------------------------------
#  1 · C1 · La boca (presentar)
# ---------------------------------------------------------------------------------------------------------------------

func _c1() -> bool:
	var cristal: CristalPulso3D = _z.nodo("latido_c1") as CristalPulso3D
	var br_a: Reactivo3D = _z.nodo("br_c1a") as Reactivo3D
	var br_b: Reactivo3D = _z.nodo("br_c1b") as Reactivo3D
	var puerta: Puzle3D.PuertaPuzle = _z.nodo("paso_norte") as Puzle3D.PuertaPuzle
	var geoda: GeodaPulso3D = _z.nodo("geoda_c1") as GeodaPulso3D
	var seta: Recolectable3D = _z.nodo("seta_c1b") as Recolectable3D
	_ok("1 C1: cristal, braseros, reja del nicho, puerta, geoda y setas están", cristal != null and br_a != null and br_b != null and puerta != null and geoda != null and seta != null and _z.nodo("reja_c1") != null)
	if cristal == null or br_a == null or br_b == null or puerta == null or geoda == null:
		return false
	_ok("1 C1: el nicho del brasero (2,12) está cerrado: reja en (2,13), paredes alrededor", Terreno3D.bloqueada(Vector2i(2, 13)) and Terreno3D.bloqueada(Vector2i(1, 13)) and Terreno3D.bloqueada(Vector2i(3, 13)) and Terreno3D.bloqueada(Vector2i(3, 12)))
	await _esperar(func() -> bool: return cristal.latidos >= 2, 8.0)
	_ok("1 C1 [legible]: el cristal late solo y su pulso AZUL llega al brasero del nicho pero NO lo enciende", cristal.latidos >= 2 and not br_a.is_lit and not br_b.is_lit, "%d latidos" % cristal.latidos)
	_ok("1 C1: las setas junto a la veta maduran con el pulso", seta.objeto == "seta_resonante", seta.objeto)
	_ok("1 C1 [legible]: la geoda sigue entera mientras la jugadora está lejos (cerca=2)", not geoda.explotada)
	# A la seta de la esquina, pasando junto a la geoda (la demostración).
	if not await _ruta("1 C1", [Vector2i(4, 16), Vector2i(3, 15), [Vector2i(1, 15), TOL_EXACTA]]):
		return false
	await _pulsar_e()
	await avanzar_s(T_AGACHARSE_S)
	_ok("1 C1: con E se coge una seta madura (seta resonante)", Estado.i().cuenta("seta_resonante") >= 1, "resonantes %d" % Estado.i().cuenta("seta_resonante"))
	await _esperar(func() -> bool: return geoda.explotada, 6.0)
	_ok("1 C1: la geoda de demostración EXPLOTA al acercarse la jugadora y rompe el jarrón de al lado", geoda.explotada and not Terreno3D.bloqueada(Vector2i(5, 13)))
	# Flecha de fuego directa al brasero del nicho: la reja la para.
	if not await _ruta("1 C1", [[Vector2i(2, 15), TOL_EXACTA]]):
		return false
	_ok("1 C1: fuego + flecha hacia el brasero del nicho sale", await _lanzar("fuego", ["flecha"], Vector2i(2, 12)))
	await avanzar_s(2.0)
	_ok("1 C1 [legible]: la flecha directa NO enciende el brasero del nicho (la reja la para)", not br_a.is_lit)
	# Fuego al cristal: el pulso lleva el fuego por la veta, bajo la reja.
	if not await _ruta("1 C1", [Vector2i(4, 16), [Vector2i(6, 17), TOL_EXACTA]]):
		return false
	var vistos: Array = []
	cristal.late.connect(func(p: Pulso3D) -> void: vistos.append(p.elemento))
	_ok("1 C1: fuego + flecha al cristal (6,15) sale", await _lanzar("fuego", ["flecha"], Vector2i(6, 15)))
	await _esperar(func() -> bool: return br_a.is_lit, 5.0)
	_ok("1 C1: el golpe de fuego hace latir el cristal en FUEGO y ese pulso enciende el brasero del nicho", vistos.has("fuego") and br_a.is_lit, str(vistos))
	_ok("1 C1 [legible]: el contador aún no abre la puerta (falta un brasero)", not puerta.abierta)
	if not await _ruta("1 C1", [[Vector2i(7, 14), TOL_EXACTA]]):
		return false
	_ok("1 C1: fuego + flecha al brasero de la derecha (7,12) sale", await _lanzar("fuego", ["flecha"], Vector2i(7, 12)))
	await _esperar(func() -> bool: return br_b.is_lit and puerta.abierta, 5.0)
	_ok("1 C1: los dos braseros arden y se abre el paso del norte", br_b.is_lit and puerta.abierta and not Terreno3D.bloqueada(Vector2i(4, 10)))
	return puerta.abierta


# ---------------------------------------------------------------------------------------------------------------------
#  2 · C2 · Las grietas (presentar receptor y hueco de veta)
# ---------------------------------------------------------------------------------------------------------------------

func _c2() -> bool:
	var receptor: ReceptorPulso3D = _z.nodo("receptor_c2") as ReceptorPulso3D
	var reja: Puzle3D.PuertaPuzle = _z.nodo("reja_c2") as Puzle3D.PuertaPuzle
	var cristal: CristalPulso3D = _z.nodo("latido_c2") as CristalPulso3D
	var columna: MuroAgrietado3D = _z.nodo("columna_c2") as MuroAgrietado3D
	var cofre: Puzle3D.CofrePuzle = _z.nodo("cofre_c2") as Puzle3D.CofrePuzle
	_ok("2 C2: receptor, reja, cristal, columna y cofre están", receptor != null and reja != null and cristal != null and columna != null and cofre != null)
	if receptor == null or reja == null or cristal == null:
		return false
	if not await _ruta("2 C2", [Vector2i(4, 13), Vector2i(4, 11), Vector2i(4, 9), Vector2i(4, 7)]):
		return false
	var l0: int = cristal.latidos
	await _esperar(func() -> bool: return cristal.latidos >= l0 + 2, 10.0)
	_ok("2 C2 [legible]: con la veta cortada el cristal late pero el receptor NO se activa y la reja sigue cerrada", cristal.latidos >= l0 + 2 and not receptor.activo and Terreno3D.bloqueada(Vector2i(9, 4)))
	# Tierra sin glifos donde se apunta: el bloque de enlace en (7,5).
	if not await _ruta("2 C2", [Vector2i(5, 6), [Vector2i(7, 7), TOL_EXACTA]]):
		return false
	_ok("2 C2: tierra + barrera (nace donde apuntas) sobre el hueco (7,5) sale", await _lanzar("tierra", ["barrera"], Vector2i(7, 5), true))
	await _esperar(func() -> bool: return Pulso3D.enlace_tendido(Vector2i(7, 5)), 3.0)
	_ok("2 C2: el bloque se levanta en el hueco y lo tiende", Pulso3D.enlace_tendido(Vector2i(7, 5)), "altura %d" % Terreno3D.altura_en(Vector2i(7, 5)))
	await _esperar(func() -> bool: return receptor.activo and reja.abierta, 10.0)
	_ok("2 C2: el pulso cruza el enlace, ACTIVA el receptor y la reja del este se abre", receptor.activo and reja.abierta and not Terreno3D.bloqueada(Vector2i(9, 4)))
	# Opcional: la columna del nicho, con la misma idea.
	if not await _ruta("2 C2", [Vector2i(6, 6), [Vector2i(4, 5), TOL_EXACTA]]):
		return false
	_ok("2 C2 (opcional): tierra sobre el segundo hueco (4,3) sale", await _lanzar("tierra", ["barrera"], Vector2i(4, 3), true))
	await _esperar(func() -> bool: return columna.roto_ya, 14.0)
	_ok("2 C2 (opcional): dos pulsos por el enlace TUMBAN la columna", columna.roto_ya and not Terreno3D.bloqueada(Vector2i(4, 2)), "pulsos %d" % columna.pulsos_recibidos)
	await avanzar_s(MuroAgrietado3D.T_CAER + 0.5)
	if await _ruta("2 C2", [Vector2i(5, 4), Vector2i(5, 2), Vector2i(4, 2), Vector2i(3, 2), [Vector2i(2, 1), TOL_EXACTA]]):
		var oro0: int = Estado.i().oro
		await _pulsar_e()
		await _esperar(func() -> bool: return cofre.es_abierto, 5.0)
		_ok("2 C2 (opcional): con E se abre el cofre del nicho (poción y 15 de oro)", cofre.es_abierto and Estado.i().oro == oro0 + 15)
	# A la salida del este (rodeando el cristal por el filón).
	return await _ruta("2 C2", [Vector2i(3, 2), Vector2i(5, 2), Vector2i(6, 3), Vector2i(8, 3), Vector2i(8, 4), Vector2i(9, 4), Vector2i(10, 4)])


# ---------------------------------------------------------------------------------------------------------------------
#  3 · C3 · El río de lava (desarrollar: geoda, columna-puente, basalto)
# ---------------------------------------------------------------------------------------------------------------------

func _c3() -> bool:
	var lava: Lava3D = _z.nodo("rio") as Lava3D
	var geoda: GeodaPulso3D = _z.nodo("geoda_c3") as GeodaPulso3D
	var puente: MuroAgrietado3D = _z.nodo("puente_c3") as MuroAgrietado3D
	var receptor: ReceptorPulso3D = _z.nodo("receptor_c3") as ReceptorPulso3D
	var reja: Puzle3D.PuertaPuzle = _z.nodo("reja_c3") as Puzle3D.PuertaPuzle
	var cofre: Puzle3D.CofrePuzle = _z.nodo("cofre_c3") as Puzle3D.CofrePuzle
	_ok("3 C3: lava, geoda, columna-puente, receptor, reja y cofre están", lava != null and geoda != null and puente != null and receptor != null and reja != null and cofre != null)
	if lava == null or geoda == null or puente == null:
		return false
	_ok("3 C3 [legible]: la lava bloquea el río (filas 2 y 5)", Terreno3D.bloqueada(Vector2i(13, 2)) and Terreno3D.bloqueada(Vector2i(13, 5)))
	# El cristal dormido de la orilla: golpearlo manda el pulso a la geoda.
	if not await _ruta("3 C3", [Vector2i(11, 4), [Vector2i(10, 3), TOL_EXACTA]]):
		return false
	_ok("3 C3: fuego + flecha al cristal dormido (10,1) sale", await _lanzar("fuego", ["flecha"], Vector2i(10, 1)))
	await _esperar(func() -> bool: return geoda.explotada and not puente.cayendo and puente.roto_ya, 8.0)
	_ok("3 C3: el pulso hace EXPLOTAR la geoda y la columna cae como PUENTE sobre la lava (13..14,2 se pisan)", geoda.explotada and puente.roto_ya and not Terreno3D.bloqueada(Vector2i(13, 2)) and not Terreno3D.bloqueada(Vector2i(14, 2)))
	await avanzar_s(MuroAgrietado3D.T_CAER + 0.5)
	# Opcional: enfriar la fila 5 con agua para que el pulso del cristal (11,5) cruce el basalto.
	if await _ruta("3 C3", [Vector2i(11, 4), [Vector2i(12, 5), TOL_EXACTA]]):
		_ok("3 C3 (opcional): agua + flecha (con gravedad) hacia la lava (13,5) sale", await _lanzar("agua", ["flecha"], Vector2i(13, 5)))
		await _esperar(func() -> bool: return receptor.activo and reja.abierta, 10.0)
		_ok("3 C3 (opcional): la roca enfriada conduce, el receptor se activa y sube la reja del rincón", receptor.activo and reja.abierta, "roca (13,5) %s" % str(lava.es_roca(Vector2i(13, 5))))
	# Cruzar por el PUENTE de la columna (permanente).
	if not await _ruta("3 C3", [Vector2i(12, 4), Vector2i(12, 3), Vector2i(12, 2), Vector2i(13, 2), Vector2i(14, 2), Vector2i(15, 2), Vector2i(15, 3)]):
		return false
	_ok("3 C3: se cruza el río a pie por el puente de la columna", celda_jugador().x >= 15)
	if reja != null and reja.abierta and await _ruta("3 C3", [Vector2i(16, 3), Vector2i(17, 3), [Vector2i(17, 2), TOL_EXACTA]]):
		var oro0: int = Estado.i().oro
		await _pulsar_e()
		await _esperar(func() -> bool: return cofre.es_abierto, 5.0)
		_ok("3 C3 (opcional): con E se abre el cofre del rincón (25 de oro)", cofre.es_abierto and Estado.i().oro == oro0 + 25)
		await _ruta("3 C3", [Vector2i(17, 3), Vector2i(16, 3)])
	return await _ruta("3 C3", [Vector2i(16, 4), Vector2i(17, 4)])


# ---------------------------------------------------------------------------------------------------------------------
#  4 · C4 · La sala cerrada (la llave)
# ---------------------------------------------------------------------------------------------------------------------

func _goblins() -> Array:
	var res: Array = []
	for n in get_nodes_in_group("combate3d"):
		if is_instance_valid(n) and n is Combate3D and not (n as Combate3D).muerto and Rect2i(19, 1, 7, 8).has_point(Terreno3D.celda_de((n as Combate3D).global_position)):
			res.append(n)
	return res


func _c4() -> bool:
	var cerrojo: Puzle3D.CerrojoPuzle = _z.nodo("entrada_c4") as Puzle3D.CerrojoPuzle
	var cofre: Puzle3D.CofrePuzle = _z.nodo("cofre_llave") as Puzle3D.CofrePuzle
	_ok("4 C4: cerrojo y cofre de la llave están; dos goblins; el cofre oculto", cerrojo != null and cofre != null and _goblins().size() == 2 and cofre.es_oculto)
	if cerrojo == null or cofre == null:
		return false
	if not await _ruta("4 C4", [Vector2i(19, 4), Vector2i(20, 4)]):
		return false
	await _esperar(func() -> bool: return cerrojo.cerrado, 2.0)
	_ok("4 C4: al entrar la sala se CIERRA", cerrojo.cerrado)
	var t_inicio: float = reloj.t
	var lanzados: int = 0
	while not _goblins().is_empty() and reloj.t - t_inicio < T_GOBLINS_MAX_S:
		_curar()
		var vivo: Combate3D = null
		var dmin: float = INF
		for n in _goblins():
			var d: float = (n as Combate3D).global_position.distance_to(jugador.position)
			if d < dmin:
				dmin = d
				vivo = n as Combate3D
		if dmin > ALCANCE_FLECHA_CAS * Terreno3D.casilla:
			await _andar_a(Terreno3D.celda_de(vivo.global_position), 1.5, ALCANCE_FLECHA_CAS - 0.5)
			continue
		if await _lanzar("fuego", ["flecha"], Terreno3D.celda_de(vivo.global_position)):
			lanzados += 1
			await avanzar_s(0.7)
		else:
			await avanzar_s(1.2)
	_ok("4 C4: los dos goblins caen a flechazos de fuego (%d flechas, %.0f s)" % [lanzados, reloj.t - t_inicio], _goblins().is_empty(), "quedan %d" % _goblins().size())
	await _esperar(func() -> bool: return not cerrojo.cerrado and not cofre.es_oculto, 4.0)
	_ok("4 C4: la sala se abre y aparece el cofre de la llave", not cerrojo.cerrado and not cofre.es_oculto)
	if not await _ruta("4 C4", [[Vector2i(22, 6), TOL_EXACTA]]):
		return false
	await _pulsar_e()
	await _esperar(func() -> bool: return cofre.es_abierto, 5.0)
	_ok("4 C4: con E el cofre da la LLAVE (flag cuevap.c4.llave)", cofre.es_abierto and Flags.i().tiene("cuevap.c4.llave"))
	return Flags.i().tiene("cuevap.c4.llave")


# ---------------------------------------------------------------------------------------------------------------------
#  5 · C5 · La charca (presentar agua conductora, prisma y receptor de elemento)
# ---------------------------------------------------------------------------------------------------------------------

func _c5() -> bool:
	var prisma: PrismaPulso3D = _z.nodo("prisma_c5") as PrismaPulso3D
	var receptor: ReceptorPulso3D = _z.nodo("receptor_c5") as ReceptorPulso3D
	var reja: Puzle3D.PuertaPuzle = _z.nodo("reja_c5") as Puzle3D.PuertaPuzle
	_ok("5 C5: prisma, receptor de rayo y reja están", prisma != null and receptor != null and reja != null and receptor.elemento == "rayo")
	if prisma == null or receptor == null or reja == null:
		return false
	if not await _ruta("5 C5", [Vector2i(22, 7), Vector2i(22, 9), Vector2i(22, 11)]):
		return false
	var e0: int = prisma.emisiones
	await _esperar(func() -> bool: return prisma.emisiones >= e0 + 1, T_ESPERA_PULSO_MAX_S)
	await avanzar_s(1.5)
	_ok("5 C5 [legible]: la descarga de la fuente llega al prisma por el agua, pero mirando al sur (al agua) no reemite hacia ningún sitio: receptor apagado, reja cerrada", prisma.emisiones >= e0 + 1 and not receptor.activo and not reja.abierta, "emisiones %d" % prisma.emisiones)
	if not await _ruta("5 C5", [[Vector2i(21, 11), TOL_EXACTA]]):
		return false
	await _pulsar_e()
	_ok("5 C5: con E junto al prisma gira un cuarto (sur → oeste)", prisma.dir == "o", prisma.dir)
	await _esperar(func() -> bool: return receptor.activo and reja.abierta, T_ESPERA_PULSO_MAX_S)
	_ok("5 C5: la próxima descarga sale del prisma por la veta, ACTIVA el receptor de rayo y abre la reja del oeste", receptor.activo and reja.abierta and not Terreno3D.bloqueada(Vector2i(18, 16)))
	var vida: float = float(jugador.get("vida"))
	if not await _ruta("5 C5", [Vector2i(20, 11), Vector2i(20, 12), Vector2i(19, 13), Vector2i(19, 15), Vector2i(19, 16), Vector2i(17, 16)]):
		return false
	_ok("5 C5: se rodea la charca por la orilla y se pasa a C6 sin electrocutarse", float(jugador.get("vida")) >= vida - 0.01, "%.0f → %.0f" % [vida, float(jugador.get("vida"))])
	return true


# ---------------------------------------------------------------------------------------------------------------------
#  6 · C6 · El santuario (combinar) y el glifo
# ---------------------------------------------------------------------------------------------------------------------

func _c6() -> bool:
	var cristal: CristalPulso3D = _z.nodo("cristal_c6") as CristalPulso3D
	var prisma: PrismaPulso3D = _z.nodo("prisma_c6") as PrismaPulso3D
	var receptor: ReceptorPulso3D = _z.nodo("ante_cofre") as ReceptorPulso3D
	var puerta: Puzle3D.PuertaPuzle = _z.nodo("puerta_llave") as Puzle3D.PuertaPuzle
	var tesoro: Puzle3D.CofrePuzle = _z.nodo("tesoro") as Puzle3D.CofrePuzle
	var pared: ParedHuecaPulso3D = _z.nodo("salida") as ParedHuecaPulso3D
	_ok("6 C6: cristal, prisma, receptor de fuego, puerta de la llave, cofre legendario y pared hueca están", cristal != null and prisma != null and receptor != null and puerta != null and tesoro != null and pared != null and receptor.elemento == "fuego")
	if cristal == null or prisma == null or receptor == null or puerta == null or tesoro == null or pared == null:
		return false
	_ok("6 C6: el cofre está sellado y echa su columna dorada; el santuario cerrado", tesoro.es_cerrado and not tesoro.sellado_cumplido() and Terreno3D.bloqueada(Vector2i(15, 13)) and Terreno3D.bloqueada(Vector2i(13, 13)))
	# Primero, sin tender el hueco: el fuego al cristal no llega a nada.
	if not await _ruta("6 C6", [[Vector2i(16, 17), TOL_EXACTA]]):
		return false
	var ecos0: int = pared.ecos
	_ok("6 C6: fuego + flecha al cristal dormido (16,15) sale", await _lanzar("fuego", ["flecha"], Vector2i(16, 15)))
	await avanzar_s(2.5)
	_ok("6 C6 [legible]: sin el hueco tendido el pulso de fuego muere en (14,15): el prisma no lo recibe y el receptor sigue apagado", prisma.emisiones == 0 and not receptor.activo, "emisiones %d" % prisma.emisiones)
	# Tierra en el hueco.
	if not await _ruta("6 C6", [Vector2i(15, 17), [Vector2i(14, 17), TOL_EXACTA]]):
		return false
	_ok("6 C6: tierra + barrera (nace donde apuntas) sobre el hueco (14,15) sale", await _lanzar("tierra", ["barrera"], Vector2i(14, 15), true))
	await _esperar(func() -> bool: return Pulso3D.enlace_tendido(Vector2i(14, 15)), 3.0)
	_ok("6 C6: el hueco queda tendido", Pulso3D.enlace_tendido(Vector2i(14, 15)))
	# Con el prisma mirando al sur, el pulso va a la pared hueca: suena (la pista de la salida) pero no abre nada más.
	if not await _ruta("6 C6", [Vector2i(15, 17), [Vector2i(16, 17), TOL_EXACTA]]):
		return false
	await avanzar_s(CristalPulso3D.ENFRIAR + 0.2)
	_ok("6 C6: fuego + flecha al cristal otra vez sale", await _lanzar("fuego", ["flecha"], Vector2i(16, 15)))
	await _esperar(func() -> bool: return prisma.emisiones >= 1, 3.0)
	await avanzar_s(2.0)
	var ecos1: int = pared.ecos
	_ok("6 C6 [legible]: el pulso llega al prisma (mira al sur) y sale hacia la PARED HUECA, que hace eco; el receptor de fuego sigue apagado", prisma.emisiones >= 1 and not receptor.activo and not pared.abierta and ecos1 > ecos0, "ecos %d → %d" % [ecos0, ecos1])
	# Girar el prisma a hechizazos (cada golpe, un cuarto de vuelta en sentido horario: sur → oeste → norte), desde la fila 17, sin pisar el circuito.
	if not await _ruta("6 C6", [[Vector2i(13, 17), TOL_EXACTA]]):
		return false
	var giros0: int = prisma.giros
	var intentos: int = 0
	while prisma.dir != "n" and intentos < 4:
		intentos += 1
		await _lanzar("fuego", ["flecha"], Vector2i(13, 15))
		await _esperar(func() -> bool: return prisma.giros > giros0, 3.0)
		giros0 = prisma.giros
		await avanzar_s(PrismaPulso3D.ENFRIAR + 0.2)
	_ok("6 C6: dos golpes de hechizo dejan el prisma mirando al NORTE, al receptor de fuego (%d lanzamientos)" % intentos, prisma.dir == "n", prisma.dir)
	# La tierra del hueco dura 25 s: se vuelve a tender justo antes de cerrar el circuito.
	if not Pulso3D.enlace_tendido(Vector2i(14, 15)):
		if not await _ruta("6 C6", [[Vector2i(14, 17), TOL_EXACTA]]):
			return false
		_ok("6 C6: el hueco se había deshecho (25 s); tierra + barrera otra vez sale", await _lanzar("tierra", ["barrera"], Vector2i(14, 15), true))
		await _esperar(func() -> bool: return Pulso3D.enlace_tendido(Vector2i(14, 15)), 3.0)
	if not await _ruta("6 C6", [Vector2i(15, 17), [Vector2i(16, 17), TOL_EXACTA]]):
		return false
	_ok("6 C6: el hueco sigue tendido al cerrar el circuito", Pulso3D.enlace_tendido(Vector2i(14, 15)))
	_ok("6 C6: fuego + flecha al cristal con el circuito montado sale", await _lanzar("fuego", ["flecha"], Vector2i(16, 15)))
	await _esperar(func() -> bool: return receptor.activo, 5.0)
	_ok("6 C6: cristal (fuego) → veta → hueco tendido → prisma → receptor de FUEGO: activo y el cofre DESELLADO", receptor.activo and tesoro.sellado_cumplido() and Flags.i().tiene("cuevap.c6.fuego"), "emisiones del prisma %d · dir %s" % [prisma.emisiones, prisma.dir])
	# La llave abre el santuario.
	if not await _ruta("6 C6", [Vector2i(17, 16), Vector2i(17, 14), Vector2i(16, 14), [Vector2i(15, 14), TOL_EXACTA]]):
		return false
	await _pulsar_e()
	await _esperar(func() -> bool: return puerta.abierta, 3.0)
	_ok("6 C6: con la llave de C4, E abre la puerta del santuario", puerta.abierta and not Terreno3D.bloqueada(Vector2i(15, 13)))
	if not await _ruta("6 C6", [Vector2i(15, 13), Vector2i(15, 12), [Vector2i(14, 12), TOL_EXACTA]]):
		return false
	await _pulsar_e()
	_ok("6 C6: con E arranca la secuencia del cofre legendario", tesoro.secuencia != null and tesoro.secuencia.activa)
	await _esperar(func() -> bool: return tesoro.secuencia != null and tesoro.secuencia.hecha, 14.0)
	_ok("6 C6: EL GLIFO: el cofre da ᚱ «pulso» (flag %s) y queda en el libro" % FLAG_GLIFO, Flags.i().tiene(FLAG_GLIFO) and Repertoire.sigil_active("raido") and tesoro.es_abierto)
	await avanzar_s(1.5)
	# Primer uso: la pared hueca de la salida.
	_ok("6 C6: la pared hueca sigue cerrada hasta usar el glifo", not pared.abierta and Terreno3D.bloqueada(Vector2i(9, 16)))
	if not await _ruta("6 C6", [Vector2i(15, 12), Vector2i(15, 13), Vector2i(15, 14), Vector2i(14, 16), Vector2i(12, 16), [Vector2i(11, 16), TOL_EXACTA]]):
		return false
	_ok("6 C6: ᚱ + fuego sobre la veta de la salida sale (el pulso propio)", await _lanzar("fuego", ["raido"], Vector2i(10, 16)))
	await _esperar(func() -> bool: return pared.abierta, 4.0)
	_ok("6 C6: el pulso de la JUGADORA abre la pared hueca", pared.abierta and not Terreno3D.bloqueada(Vector2i(9, 16)))
	await avanzar_s(ParedHuecaPulso3D.T_ABRIR + 0.3)
	if not await _ruta("6 C6", [Vector2i(10, 16), Vector2i(8, 16)]):
		return false
	_ok("FIN: de la entrada al glifo y de vuelta a C1 por el atajo, todo a pie y con hechizos reales", celda_jugador() == Vector2i(8, 16) and Repertoire.sigil_active("raido"))
	return true


# ---------------------------------------------------------------------------------------------------------------------
#  7 · Volver a entrar (como al regresar del Bosque o cargar partida): lo resuelto sigue resuelto
# ---------------------------------------------------------------------------------------------------------------------

func _recargar() -> void:
	maqueta.get_parent().remove_child(maqueta)
	maqueta.queue_free()
	await avanzar(5)
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(20)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	if _z == null:
		_ok("7 recarga: Puzle3D", false)
		return
	await avanzar_s(1.0)
	var abiertas: Dictionary = {}
	for id in ["paso_norte", "reja_c2", "reja_c3", "reja_c5", "puerta_llave"]:
		var p: Puzle3D.PuertaPuzle = _z.nodo(id) as Puzle3D.PuertaPuzle
		abiertas[id] = p != null and p.abierta
	_ok("7 recarga: las puertas y rejas resueltas nacen ABIERTAS (receptores y braseros por su flag)", not abiertas.values().has(false), str(abiertas))
	var col: MuroAgrietado3D = _z.nodo("columna_c2") as MuroAgrietado3D
	var puente: MuroAgrietado3D = _z.nodo("puente_c3") as MuroAgrietado3D
	_ok("7 recarga: la columna del nicho de C2 sigue caída y el puente de C3 sigue tendido", col != null and col.roto_ya and not Terreno3D.bloqueada(Vector2i(4, 2)) and puente != null and not Terreno3D.bloqueada(Vector2i(13, 2)))
	var tesoro: Puzle3D.CofrePuzle = _z.nodo("tesoro") as Puzle3D.CofrePuzle
	var pared: ParedHuecaPulso3D = _z.nodo("salida") as ParedHuecaPulso3D
	_ok("7 recarga: el cofre legendario nace abierto, ᚱ sigue en el libro y la salida sigue abierta", tesoro != null and tesoro.es_abierto and Repertoire.sigil_active("raido") and pared != null and pared.abierta)
