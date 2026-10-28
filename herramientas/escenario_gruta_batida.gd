extends "res://herramientas/escenario_cueva_resonante.gd"
## LA GRUTA BATIDA, AUTOPLAY DE PRINCIPIO A FIN (28/10, versión SOLO FUEGO; diseño en docs/GRUTA_BATIDA.md, mapa mundo/datos_nivel/mapas/GrutaBatida.txt).
## Las mismas reglas que el autoplay de la Cueva Resonante (de él salen `_andar_a`, `_ruta`, `_lanzar`, `_pulsar_e`): se anda con WASD, se lanza con la receta real y con gravedad,
## se usa con E y nunca se teletransporta a nadie. La jugadora lleva FUEGO + FLECHA (kit `gruta`); la barrera la levantan los TÓTEMS hasta que el cofre da ᛜ.
## Única ayuda: frente a los arqueros se repone la vida (las flechas pegan de verdad; esto no prueba el combate). Lo que se mide de daño se mide ANTES de curar.
##
##   1 G1 · el tótem que late levanta la barrera tras la reja, el brasero se enciende y la puerta se abre, sin hacer nada.
##   2 G2 · la flecha no pasa la reja; una flecha a cada tótem dormido enciende su brasero; con uno solo no se abre.
##   3 G3 · el arquero bate el paso; el tótem le prende fuego bajo los pies hasta tumbarlo y se abre la puerta.
##   4 G4 · la flecha no llega a la cuerda (3 casillas); el tótem la quema y el puente sube; se cruza.
##   5 G5 · los dos tótems: fuego bajo los arqueros y la cuerda del puente; se cruza el río.
##   6 G6 · el puente; la flecha no pasa la reja; un tótem con dos marcas enciende los dos braseros; el cofre da ᛜ; con fuego + ᛜ
##          la jugadora enciende el brasero del atajo (junto al tótem roto) y vuelve a G1. FIN.
##   7 · recarga: lo resuelto sigue resuelto y los arqueros vencidos no vuelven.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_gruta_batida.gd

const RUTA_GRUTA: String = "res://escenas/PruebaGrutaBatida.tscn"
const T_PELEA_MAX_S: float = 70.0
const MAX_GOLPES_TOTEM: int = 6


## Los arqueros vivos cuya casilla de partida está en `celdas`.
func _arqueros(celdas: Array) -> Array:
	var res: Array = []
	for n in get_nodes_in_group("combate3d"):
		if is_instance_valid(n) and n is Combate3D and not (n as Combate3D).muerto and celdas.has(Terreno3D.celda_de((n as Combate3D).casa)):
			res.append(n)
	return res


func _totem(id: String) -> GuardianBarrera3D:
	return _z.nodo(id) as GuardianBarrera3D


func _puerta(id: String) -> Puzle3D.PuertaPuzle:
	return _z.nodo(id) as Puzle3D.PuertaPuzle


func _encendido(id: String) -> bool:
	var n: Node = _z.nodo(id)
	return n != null and bool(n.get("is_lit"))


## Una flecha de fuego al tótem `id` (en `celda`) desde donde está la jugadora; espera a que levante su barrera. true si la levantó.
func _despertar(id: String, celda: Vector2i) -> bool:
	var t: GuardianBarrera3D = _totem(id)
	var antes: int = t.levantadas
	await avanzar_s(GuardianBarrera3D.ENFRIAR * 0.5)
	if not await _lanzar("fuego", ["flecha"], celda):
		return false
	await _esperar(func() -> bool: return t.levantadas > antes, 3.0)
	return t.levantadas > antes


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_GRUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	_t0 = reloj.t
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("0 Puzle3D monta la Gruta Batida sin avisos", _z != null and _z.avisos.is_empty(), str(_z.avisos) if _z != null else "sin Puzle3D")
	if _z == null:
		return
	_ok("0 el mapa mide 25 × 19 y la jugadora nace en G1 (4,15)", maqueta.get("_ancho") == 25 and maqueta.get("_alto") == 19 and celda_jugador() == Vector2i(4, 15), str(celda_jugador()))
	_ok("0 kit «gruta»: solo FUEGO y FLECHA; sin ᛜ (ni ningún otro elemento)", Repertoire.element_active("fuego") and Repertoire.sigil_active("flecha") and not Repertoire.sigil_active("barrera")
		and not Repertoire.element_active("tierra") and not Repertoire.element_active("hielo") and not Repertoire.element_active("agua"))
	for paso in [_g1, _g2, _g3, _g4, _g5, _g6]:
		if not await (paso as Callable).call():
			_ok("FIN: el recorrido se cortó (ver el primer FALLO)", false)
			return
	print("TIEMPO DE JUEGO: %.0f s" % (reloj.t - _t0))
	await _recargar_gruta()


# ---------------------------------------------------------------------------------------------------------------------
#  1 · G1 · La boca: el tótem que late
# ---------------------------------------------------------------------------------------------------------------------

func _g1() -> bool:
	var t: GuardianBarrera3D = _totem("totem_g1")
	var puerta: Puzle3D.PuertaPuzle = _puerta("puerta_g1")
	_ok("1 G1: el tótem (que late, con la marca tras la reja), el brasero y la puerta están", t != null and _z.nodo("br_g1") != null and puerta != null and t.cada > 0.0 and t.marcas.has(Vector2i(7, 11)))
	if t == null or puerta == null:
		return false
	await _esperar(func() -> bool: return puerta.abierta, 8.0)
	_ok("1 G1 [legible]: SIN HACER NADA, el tótem late, la barrera de fuego nace tras la reja, el brasero se enciende y la puerta se abre", t.levantadas >= 1 and _encendido("br_g1") and puerta.abierta,
		"latidos %d" % t.levantadas)
	if not await _ruta("1 G1", [Vector2i(4, 13), Vector2i(4, 11), Vector2i(4, 9), Vector2i(4, 8)]):
		return false
	return true


# ---------------------------------------------------------------------------------------------------------------------
#  2 · G2 · Las rejas: el tótem dormido
# ---------------------------------------------------------------------------------------------------------------------

func _g2() -> bool:
	var puerta: Puzle3D.PuertaPuzle = _puerta("puerta_g2")
	_ok("2 G2: dos tótems dormidos, dos braseros tras sus rejas y la puerta cerrada", _totem("totem_g2a") != null and _totem("totem_g2b") != null and puerta != null and not puerta.abierta
		and _totem("totem_g2a").cada == 0.0 and not _encendido("br_g2a") and not _encendido("br_g2b"))
	if puerta == null:
		return false
	if not await _ruta("2 G2", [Vector2i(4, 6), Vector2i(3, 4), [Vector2i(2, 4), TOL_EXACTA]]):
		return false
	_ok("2 G2: fuego + flecha al brasero (2,1) sale", await _lanzar("fuego", ["flecha"], Vector2i(2, 1)))
	await avanzar_s(3.0)
	_ok("2 G2 [legible]: la flecha se para en la REJA: el brasero sigue apagado", not _encendido("br_g2a"))
	if not await _ruta("2 G2", [Vector2i(3, 4), Vector2i(3, 6), [Vector2i(2, 7), TOL_EXACTA]]):
		return false
	_ok("2 G2: una flecha al tótem (2,5) lo DESPIERTA", await _despertar("totem_g2a", Vector2i(2, 5)))
	await _esperar(func() -> bool: return _encendido("br_g2a"), 3.0)
	_ok("2 G2 [legible]: su barrera nace tras la reja y enciende el brasero (2,1)", _encendido("br_g2a"))
	await avanzar_s(1.0)
	_ok("2 G2 [legible]: con un solo brasero la puerta sigue cerrada", not puerta.abierta)
	if not await _ruta("2 G2", [Vector2i(4, 7), [Vector2i(6, 7), TOL_EXACTA]]):
		return false
	_ok("2 G2: una flecha al otro tótem (6,5) lo despierta", await _despertar("totem_g2b", Vector2i(6, 5)))
	await _esperar(func() -> bool: return puerta.abierta, 4.0)
	_ok("2 G2: los dos braseros encendidos ABREN la puerta del este", _encendido("br_g2b") and puerta.abierta)
	return await _ruta("2 G2", [Vector2i(5, 6), Vector2i(5, 4), Vector2i(7, 3), Vector2i(8, 3), Vector2i(9, 3)])


# ---------------------------------------------------------------------------------------------------------------------
#  3 · G3 · La galería: la trampa
# ---------------------------------------------------------------------------------------------------------------------

func _g3() -> bool:
	var puerta: Puzle3D.PuertaPuzle = _puerta("puerta_g3")
	var arq: Array = [Vector2i(12, 8)]
	_ok("3 G3: el tótem, el arquero de puesto en su cornisa y la puerta del este cerrada", _totem("totem_g3") != null and _arqueros(arq).size() == 1 and puerta != null and not puerta.abierta)
	if puerta == null or _arqueros(arq).is_empty():
		return false
	if not await _ruta("3 G3", [Vector2i(9, 4), [Vector2i(10, 4), TOL_EXACTA]]):
		return false
	_curar()
	await avanzar_s(6.0)
	var dano: float = VIDA_MAX - float(jugador.get("vida"))
	_ok("3 G3 [legible]: el arquero bate el paso (daño en 6 s: %.0f)" % dano, dano > 0.0)
	var golpes: int = 0
	while not _arqueros(arq).is_empty() and golpes < MAX_GOLPES_TOTEM:
		_curar()
		if await _despertar("totem_g3", Vector2i(10, 2)):
			golpes += 1
		await avanzar_s(1.5)
	await _esperar(func() -> bool: return puerta.abierta, 4.0)
	_ok("3 G3: el fuego del tótem nace BAJO EL ARQUERO, al otro lado del agua, y lo tumba (%d golpes)" % golpes, _arqueros(arq).is_empty() and Flags.i().tiene("gruta.g3.arquero"))
	_ok("3 G3: caído el arquero, la puerta del este se abre", puerta.abierta)
	_curar()
	return await _ruta("3 G3", [Vector2i(12, 3), Vector2i(15, 3), Vector2i(16, 3), Vector2i(17, 3)])


# ---------------------------------------------------------------------------------------------------------------------
#  4 · G4 · La charca: lo que la flecha no alcanza
# ---------------------------------------------------------------------------------------------------------------------

func _g4() -> bool:
	var cuerda: Cuerda3D = _z.nodo("cuerda_g4") as Cuerda3D
	var puente: PuenteReactivo3D = _z.nodo("puente_g4") as PuenteReactivo3D
	_ok("4 G4: el tótem, la cuerda en la otra orilla y el puente plegado", _totem("totem_g4") != null and cuerda != null and puente != null and not puente.tendido and not cuerda.rota_ya)
	if cuerda == null or puente == null:
		return false
	_ok("4 G4 [legible]: el agua no se pisa", not Terreno3D.pisable(Vector2i(20, 5), 0, false, 1, false))
	if not await _ruta("4 G4", [Vector2i(19, 4), [Vector2i(21, 4), TOL_EXACTA]]):
		return false
	_ok("4 G4: fuego + flecha a la cuerda (21,7) sale", await _lanzar("fuego", ["flecha"], Vector2i(21, 7)))
	await avanzar_s(3.0)
	_ok("4 G4 [legible]: la flecha (2 casillas) cae al agua: la cuerda, a 3, sigue entera", not cuerda.rota_ya and not puente.tendido)
	if not await _ruta("4 G4", [[Vector2i(20, 3), TOL_EXACTA]]):
		return false
	_ok("4 G4: una flecha al tótem (22,3) lo despierta", await _despertar("totem_g4", Vector2i(22, 3)))
	await _esperar(func() -> bool: return puente.tendido and Terreno3D.pisable(Vector2i(20, 6), 0, false, 1, false), 6.0)
	_ok("4 G4: la barrera de fuego nace en la cuerda, la QUEMA, y el puente sube y se pisa", cuerda.rota_ya and puente.tendido and Terreno3D.pisable(Vector2i(20, 5), 0, false, 1, false))
	return await _ruta("4 G4", [Vector2i(20, 4), Vector2i(20, 5), Vector2i(20, 6), Vector2i(20, 7), Vector2i(20, 9), Vector2i(20, 10), Vector2i(20, 11)])


# ---------------------------------------------------------------------------------------------------------------------
#  5 · G5 · El paso batido: trampa y puente
# ---------------------------------------------------------------------------------------------------------------------

func _g5() -> bool:
	var cuerda: Cuerda3D = _z.nodo("cuerda_g5") as Cuerda3D
	var puente: PuenteReactivo3D = _z.nodo("puente_g5") as PuenteReactivo3D
	var arq: Array = [Vector2i(18, 17), Vector2i(22, 17)]
	_ok("5 G5: dos tótems, dos arqueros en la otra orilla, la cuerda y el puente plegado", _totem("totem_g5a") != null and _totem("totem_g5b") != null and _arqueros(arq).size() == 2
		and cuerda != null and puente != null and not puente.tendido)
	if cuerda == null or puente == null:
		return false
	if not await _ruta("5 G5", [[Vector2i(21, 12), TOL_EXACTA]]):
		return false
	_curar()
	_ok("5 G5: fuego + flecha a la cuerda (21,15) sale", await _lanzar("fuego", ["flecha"], Vector2i(21, 15)))
	await avanzar_s(3.0)
	_ok("5 G5 [legible]: tampoco aquí llega la flecha (3 casillas)", not cuerda.rota_ya)
	if not await _ruta("5 G5", [[Vector2i(20, 12), TOL_EXACTA]]):
		return false
	var golpes: int = 0
	while not _arqueros(arq).is_empty() and golpes < MAX_GOLPES_TOTEM:
		_curar()
		if await _despertar("totem_g5b", Vector2i(18, 12)):
			golpes += 1
		await avanzar_s(1.5)
	await avanzar_s(1.0)
	_ok("5 G5: el tótem del oeste prende fuego bajo LOS DOS arqueros a la vez y los tumba (%d golpes)" % golpes, _arqueros(arq).is_empty() and Flags.i().tiene("gruta.g5.arqueros"))
	_curar()
	_ok("5 G5: una flecha al tótem del este (22,12) lo despierta", await _despertar("totem_g5a", Vector2i(22, 12)))
	await _esperar(func() -> bool: return puente.tendido and Terreno3D.pisable(Vector2i(20, 14), 0, false, 1, false), 6.0)
	_ok("5 G5: su barrera quema la cuerda y el puente cruza el río", cuerda.rota_ya and puente.tendido)
	return await _ruta("5 G5", [Vector2i(20, 13), Vector2i(20, 14), Vector2i(20, 15), Vector2i(20, 16), Vector2i(18, 16), Vector2i(16, 16), Vector2i(15, 16)])


# ---------------------------------------------------------------------------------------------------------------------
#  6 · G6 · El santuario: combinar, el premio y el primer uso
# ---------------------------------------------------------------------------------------------------------------------

func _g6() -> bool:
	var cuerda: Cuerda3D = _z.nodo("cuerda_g6") as Cuerda3D
	var puente: PuenteReactivo3D = _z.nodo("puente_g6") as PuenteReactivo3D
	var puerta: Puzle3D.PuertaPuzle = _puerta("puerta_g6")
	var atajo: Puzle3D.PuertaPuzle = _puerta("atajo")
	var tesoro: Puzle3D.CofrePuzle = _z.nodo("tesoro") as Puzle3D.CofrePuzle
	var roto: GuardianBarrera3D = _totem("totem_roto")
	_ok("6 G6: tótem del puente, cuerda, puente plegado, tótem de las dos marcas, puerta del cofre, cofre legendario, atajo y tótem roto están",
		_totem("totem_g6a") != null and cuerda != null and puente != null and _totem("totem_g6b") != null and _totem("totem_g6b").marcas.size() == 2
		and puerta != null and not puerta.abierta and tesoro != null and atajo != null and not atajo.abierta and roto != null and roto.roto)
	if cuerda == null or puente == null or puerta == null or tesoro == null or atajo == null or roto == null:
		return false
	# El puente.
	if not await _ruta("6 G6", [Vector2i(14, 16), [Vector2i(13, 16), TOL_EXACTA]]):
		return false
	_ok("6 G6: fuego + flecha a la cuerda (13,13) sale", await _lanzar("fuego", ["flecha"], Vector2i(13, 13)))
	await avanzar_s(3.0)
	_ok("6 G6 [legible]: la flecha no llega a la cuerda", not cuerda.rota_ya)
	if not await _ruta("6 G6", [Vector2i(12, 16), [Vector2i(12, 17), TOL_EXACTA]]):
		return false
	_ok("6 G6: una flecha al tótem del puente (14,17) lo despierta", await _despertar("totem_g6a", Vector2i(14, 17)))
	await _esperar(func() -> bool: return puente.tendido and Terreno3D.pisable(Vector2i(12, 14), 0, false, 1, false), 6.0)
	_ok("6 G6: el puente sube", cuerda.rota_ya and puente.tendido)
	_curar()
	if not await _ruta("6 G6", [Vector2i(12, 16), Vector2i(12, 15), Vector2i(12, 14), Vector2i(12, 13), [Vector2i(11, 13), TOL_EXACTA]]):
		return false
	# Los braseros tras las rejas.
	_curar()
	_ok("6 G6: fuego + flecha al brasero (11,11) sale", await _lanzar("fuego", ["flecha"], Vector2i(11, 11)))
	await avanzar_s(2.5)
	_ok("6 G6 [legible]: la reja lo para: el brasero sigue apagado y la puerta cerrada", not _encendido("br_g6a") and not puerta.abierta)
	if not await _ruta("6 G6", [[Vector2i(12, 13), TOL_EXACTA]]):
		return false
	_curar()
	_ok("6 G6: una flecha al tótem de las DOS marcas (14,13) lo despierta", await _despertar("totem_g6b", Vector2i(14, 13)))
	await _esperar(func() -> bool: return puerta.abierta, 4.0)
	_ok("6 G6: un solo golpe enciende LOS DOS braseros y la puerta del cofre se abre", _encendido("br_g6a") and _encendido("br_g6b") and puerta.abierta)
	# El cofre: ᛜ.
	_curar()
	if not await _ruta("6 G6", [[Vector2i(12, 12), TOL_EXACTA]]):
		return false
	await _pulsar_e()
	_ok("6 G6: con E arranca la secuencia del cofre legendario", tesoro.secuencia != null and tesoro.secuencia.activa)
	await _esperar(func() -> bool: return tesoro.secuencia != null and tesoro.secuencia.hecha, 14.0)
	_ok("6 G6: EL GLIFO: el cofre da ᛜ «barrera» y queda en el libro", Repertoire.sigil_active("barrera") and tesoro.es_abierto and Flags.i().tiene("gruta.g6.glifo"))
	await avanzar_s(1.5)
	# El primer uso: el atajo.
	_curar()
	if not await _ruta("6 G6", [Vector2i(12, 13), Vector2i(10, 13), [Vector2i(9, 13), TOL_EXACTA]]):
		return false
	_ok("6 G6: fuego + flecha al brasero del atajo (9,11) sale", await _lanzar("fuego", ["flecha"], Vector2i(9, 11)))
	await avanzar_s(2.5)
	_ok("6 G6 [legible]: la reja la para; el atajo sigue cerrado", not _encendido("br_atajo") and not atajo.abierta)
	_ok("6 G6 [legible]: el tótem roto no hace nada (no recibe golpes ni bloquea)", roto.levantadas == 0 and not Terreno3D.bloqueada(Vector2i(10, 13)))
	_curar()
	_ok("6 G6: fuego + ᛜ de la JUGADORA, nacido en la marca tras la reja (9,11), sale", await _lanzar("fuego", ["barrera"], Vector2i(9, 11), true))
	await _esperar(func() -> bool: return atajo.abierta, 4.0)
	_ok("6 G6: la barrera de la jugadora enciende el brasero y el atajo a G1 se abre", _encendido("br_atajo") and atajo.abierta)
	if not await _ruta("6 G6", [Vector2i(8, 13), Vector2i(7, 13), Vector2i(5, 14), Vector2i(4, 16)]):
		return false
	_ok("FIN: de la entrada al glifo y de vuelta a G1 por el atajo, todo a pie y con hechizos reales", celda_jugador() == Vector2i(4, 16) and Repertoire.sigil_active("barrera"))
	return true


# ---------------------------------------------------------------------------------------------------------------------
#  7 · Volver a entrar: lo resuelto sigue resuelto
# ---------------------------------------------------------------------------------------------------------------------

func _recargar_gruta() -> void:
	maqueta.get_parent().remove_child(maqueta)
	maqueta.queue_free()
	await avanzar(5)
	await cargar(RUTA_GRUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(20)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	await avanzar_s(2.0)
	var abiertas: bool = true
	for id in ["puerta_g1", "puerta_g2", "puerta_g3", "puerta_g6", "atajo"]:
		abiertas = abiertas and _puerta(id) != null and _puerta(id).abierta
	_ok("7 recarga: todas las puertas resueltas nacen abiertas", abiertas)
	var puentes: bool = true
	for id in ["puente_g4", "puente_g5", "puente_g6"]:
		puentes = puentes and _z.nodo(id) != null and bool(_z.nodo(id).get("tendido"))
	_ok("7 recarga: los tres puentes vuelven a estar tendidos", puentes)
	var tesoro: Puzle3D.CofrePuzle = _z.nodo("tesoro") as Puzle3D.CofrePuzle
	_ok("7 recarga: el cofre nace abierto y ᛜ sigue en el libro", tesoro != null and tesoro.es_abierto and Repertoire.sigil_active("barrera"))
	_ok("7 recarga: los arqueros vencidos de G3 y G5 no vuelven", _arqueros([Vector2i(12, 8), Vector2i(18, 17), Vector2i(22, 17)]).is_empty())
