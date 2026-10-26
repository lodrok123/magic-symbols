extends "res://herramientas/escenario_base.gd"
## LA GEODA EXPLOSIVA Y LA COLUMNA-PUENTE (26/10, Cueva; decisión de Pablo: «que la lava siga y una columna haga de puente», con una demostración antes). Headless, con la escena de verdad:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_cueva_geoda.gd
## 1 · Montaje: la geoda y el jarrón de la demostración de C1, el cristal de golpe, la veta, la geoda, la columna-puente y la lava de C3, sin avisos.
## 2 · DEMOSTRACIÓN (C1): el cristal late solo, el pulso llega por la veta a la geoda, la carga y EXPLOTA una vez: rompe el jarrón de al lado y pone su flag.
## 3 · C3: la columna no se agrieta con los latidos del cristal de la fila 5 (`golpes=99`, y no está pegada a ninguna veta). Un golpe al cristal de la orilla manda el pulso a la geoda:
##     explota, tumba la columna hacia el este, que se estira, cubre las DOS casillas de lava de su fila (se pisan y conducen) y se queda tendida; la lava de las demás filas sigue ahí.
## 4 · Persistencia: al recargar el nivel con las flags puestas, la geoda ya no está y el puente nace tendido.

const RUTA: String = "res://escenas/PruebaCueva.tscn"
const FILA_PUENTE: int = 2
const CELDAS_PUENTE: Array = [Vector2i(13, 2), Vector2i(14, 2)]
const CELDA_COLUMNA: Vector2i = Vector2i(12, 2)

var _z: Puzle3D = null


func _esperar(cond: Callable, tope: float) -> float:
	var t: float = 0.0
	while not cond.call() and t < tope:
		t += await avanzar_s(0.1)
	return t


func _escenario() -> void:
	Flags.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("1 Puzle3D está y no avisa de nada", _z != null and _z.avisos.is_empty(), str(_z.avisos) if _z != null else "sin Puzle3D")
	if _z == null:
		return
	var geoda1: GeodaPulso3D = _z.nodo("geoda_c1") as GeodaPulso3D
	var jarron: Node = _z.nodo("jarron_c1a")
	var cristal: CristalPulso3D = _z.nodo("cristal_geoda") as CristalPulso3D
	var veta: VetaPulso3D = _z.nodo("veta_geoda") as VetaPulso3D
	var geoda3: GeodaPulso3D = _z.nodo("geoda_c3") as GeodaPulso3D
	var columna: MuroAgrietado3D = _z.nodo("puente_c3") as MuroAgrietado3D
	var rio: Lava3D = _z.nodo("rio") as Lava3D
	_ok("1 están las dos geodas, el jarrón, el cristal de golpe, su veta, la columna-puente y la lava", geoda1 != null and jarron != null and cristal != null and veta != null and geoda3 != null
		and columna != null and rio != null)
	if geoda1 == null or jarron == null or cristal == null or geoda3 == null or columna == null or rio == null:
		return
	_ok("1 la columna es un puente de 2 casillas hacia el este, con su flag, y solo la explosión la tumba (golpes 99)", columna.puente == rio and is_equal_approx(columna.largo_puente, 2.0) and columna.cae == "e"
		and columna.flag == "cueva.c3.puente" and columna.golpes == 99)
	_ok("1 el cristal de la orilla solo late al golpearlo (cada=0) y las geodas no bloquean su casilla", is_zero_approx(cristal.cada) and not Terreno3D.bloqueada(Vector2i(11, 2)) and not Terreno3D.bloqueada(Vector2i(1, 13)))
	_ok("1 la columna bloquea su casilla y las dos de lava de su fila bloquean el paso", Terreno3D.bloqueada(CELDA_COLUMNA) and Terreno3D.bloqueada(CELDAS_PUENTE[0]) and Terreno3D.bloqueada(CELDAS_PUENTE[1]))
	_ok("1 ni las geodas ni el jarrón han explotado todavía", not geoda3.explotada and not bool(jarron.get("roto_ya")))

	# 2 · La demostración de C1: el latido del cristal de C1 llega por la veta a la geoda
	var avisos_expl: Array = []
	geoda1.explota.connect(func(p: Vector3, r: float) -> void: avisos_expl.append([p, r]))
	await avanzar_s(4.0)                         # el cristal de C1 late cada 3 s; la jugadora sigue en el inicio, a más de 3 casillas de la geoda
	_ok("2 C1: con la jugadora lejos (en el inicio) la geoda ignora los latidos: la demostración espera a que la veas", not geoda1.explotada and geoda1.pulsos_recibidos == 0 and not bool(jarron.get("roto_ya")),
		"pulsos %d" % geoda1.pulsos_recibidos)
	colocar_jugador(Vector2i(3, 13))             # a 2 casillas
	var t: float = await _esperar(func() -> bool: return geoda1.explotada, 12.0)
	_ok("2 C1: con la jugadora cerca, el latido del cristal llega a la geoda y la carga (a los %.1f s)" % t, geoda1.pulsos_recibidos >= 1 and geoda1.explotada, "pulsos %d, explotada %s" % [geoda1.pulsos_recibidos, geoda1.explotada])
	_ok("2 C1: explota UNA vez y avisa con el punto y el radio", avisos_expl.size() == 1 and is_equal_approx(float(avisos_expl[0][1]), GeodaPulso3D.RADIO), str(avisos_expl.size()))
	_ok("2 C1: la explosión rompe el jarrón de al lado", bool(jarron.get("roto_ya")) and geoda1.rotos.has(jarron), "rotos %d" % geoda1.rotos.size())
	_ok("2 C1: se acuerda (flag cueva.c1.geoda) y deja de ser un reactivo del pulso", Flags.i().tiene("cueva.c1.geoda") and not geoda1.is_in_group(Pulso3D.GRUPO_PULSABLE))
	await avanzar_s(1.5)
	_ok("2 C1: con más latidos no vuelve a explotar", avisos_expl.size() == 1)

	# 3 · C3
	_ok("3 C3: los latidos del cristal de la fila 5 no agrietan la columna", columna.pulsos_recibidos == 0 and not columna.roto_ya, "pulsos %d" % columna.pulsos_recibidos)
	_ok("3 C3: la geoda espera intacta", not geoda3.explotada and geoda3.pulsos_recibidos == 0)
	var pulso: Pulso3D = cristal.latir()
	_ok("3 C3: el golpe al cristal de la orilla suelta un pulso", pulso != null and cristal.latidos >= 1)
	t = await _esperar(func() -> bool: return geoda3.explotada, 6.0)
	_ok("3 C3: el pulso corre por la veta, carga la geoda y explota (a los %.1f s)" % t, geoda3.explotada and geoda3.pulsos_recibidos >= 1)
	_ok("3 C3: la explosión alcanza la columna y la tumba", geoda3.rotos.has(columna) and columna.roto_ya, "rotos %d" % geoda3.rotos.size())
	_ok("3 C3: se acuerdan las dos flags", Flags.i().tiene("cueva.c3.geoda") and Flags.i().tiene("cueva.c3.puente"))
	t = await _esperar(func() -> bool: return not columna.cayendo and columna.cubiertas.size() > 0, 4.0)
	_ok("3 C3: la columna cae y cubre las DOS casillas de lava de su fila (a los %.1f s)" % t, (columna.cubiertas.size() == 2 and columna.cubiertas.has(CELDAS_PUENTE[0])
		and columna.cubiertas.has(CELDAS_PUENTE[1])), str(columna.cubiertas))
	await avanzar_s(1.5)
	_ok("3 C3: esas casillas ya no bloquean (se pisan), son puente y conducen el pulso", not Terreno3D.bloqueada(CELDAS_PUENTE[0]) and not Terreno3D.bloqueada(CELDAS_PUENTE[1])
		and rio.es_puente(CELDAS_PUENTE[0]) and rio.es_puente(CELDAS_PUENTE[1]) and Terreno3D.conductores.has(CELDAS_PUENTE[0]) and Terreno3D.conductores.has(CELDAS_PUENTE[1]))
	_ok("3 C3: el puente no cuenta como roca enfriada (el basalto de al lado no se coge encima)", not rio.es_roca(CELDAS_PUENTE[0]))
	_ok("3 C3: la lava SIGUE en el resto del río (la fila de al lado bloquea, el río no está apagado)", Terreno3D.bloqueada(Vector2i(13, 4)) and Terreno3D.bloqueada(Vector2i(14, 3)) and rio.is_lit)
	_ok("3 C3: la columna se queda tendida, visible y no se deshace", columna.get("_cuerpo") != null and (columna.get("_cuerpo") as Node3D).visible)
	_ok("3 C3: su casilla (la orilla donde estaba) queda libre", not Terreno3D.bloqueada(CELDA_COLUMNA))
	# Se recorre a pie de una orilla a la otra por el puente
	colocar_jugador(Vector2i(12, FILA_PUENTE))
	await avanzar_s(0.3)
	var ruta: Array = Caminos3D.camino(Vector2i(12, FILA_PUENTE), Vector2i(15, FILA_PUENTE))
	_ok("3 C3: hay camino a pie de la orilla oeste (12,2) a la este (15,2) por el puente", not ruta.is_empty(), str(ruta))

	# 4 · Persistencia: se recarga el nivel SIN tocar las flags
	await cargar(RUTA, true)
	await avanzar(10)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	var g3: GeodaPulso3D = _z.nodo("geoda_c3") as GeodaPulso3D
	var col2: MuroAgrietado3D = _z.nodo("puente_c3") as MuroAgrietado3D
	var rio2: Lava3D = _z.nodo("rio") as Lava3D
	await avanzar_s(0.5)
	_ok("4 recargado: la geoda ya no está (ya explotó) y la columna nace tendida", g3 != null and g3.explotada and col2 != null and col2.roto_ya)
	_ok("4 recargado: el puente cubre las dos casillas y se pisan", rio2 != null and rio2.es_puente(CELDAS_PUENTE[0]) and rio2.es_puente(CELDAS_PUENTE[1])
		and not Terreno3D.bloqueada(CELDAS_PUENTE[0]) and not Terreno3D.bloqueada(CELDAS_PUENTE[1]))
	_ok("4 recargado: la geoda de C1 tampoco queda y el resto de la lava sigue", (_z.nodo("geoda_c1") as GeodaPulso3D).explotada and Terreno3D.bloqueada(Vector2i(13, 4)))
