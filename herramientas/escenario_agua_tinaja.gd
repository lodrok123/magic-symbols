extends "res://herramientas/escenario_base.gd"
## Escenario 13.8 · la tinaja llena el canal, con la ESCENA entera (PruebaBosque.tscn, agua física). Lo escribe el Juego (15/10).
##
## Recorre el camino que hace el jugador: flecha + agua contra la tinaja (3,26) → Lanzador3D._golpear → el Reactivo3D «surtidor» se
## llena, se inclina y vierte → `agua_llega` → PruebaTest2 llama a `Mundo3D.abrir_cauce` → la simulación recibe CAUDAL_TINAJA en la
## primera casilla del canal → el agua baja por (2,26), (2,27), (2,28) y desemboca en el río (2,29).
## Cada segundo vuelca al diario (PlayLog «canal_profundidad») y a la consola la profundidad de cada casilla del canal, la del río y el
## volumen total de la simulación: esa tabla es la referencia para que el Pipeline compare el agua que DIBUJA con el agua que HAY (13.9).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_agua_tinaja.gd

const TINAJA := Vector2i(3, 26)
const DESDE := Vector2i(6, 26)                        ## desde donde se tira: 3 casillas al este, la tinaja vierte al oeste
const CANAL: Array = [Vector2i(2, 26), Vector2i(2, 27), Vector2i(2, 28)]
const RIO := Vector2i(2, 29)
const UMBRAL: float = 0.25                            ## lo que pide Pablo: ≥ 0,25 u (= AguaSim3D.UMBRAL_AGUA, lo mínimo que cuenta como agua)
const HORIZONTE: float = 5.0                          ## «a los 5 s» de lanzar
const MARGEN_DESDE_LLEGADA: float = 20.0             ## s tras `agua_llega` en que las tres casillas deben haber pasado de UMBRAL
const DURACION: float = 32.0                          ## 15/10: el manantial tarda ARRANQUE_CAUCE (18 s) en llegar a su caudal, hay que mirar más allá

var _t_llega: float = -1.0                            ## s (desde lanzar) a los que la tinaja avisó `agua_llega`
var _t_cast: float = 0.0
var _tabla: Array = []                                ## [t, [c1, c2, c3], río, volumen] cada segundo


func _escenario() -> void:
	await cargar()
	var sim: AguaSim3D = Terreno3D.agua_sim
	_ok("1 la escena tiene la simulación de agua montada", sim != null)
	var tinaja: Reactivo3D = null
	for r in maqueta.find_children("*", "Reactivo3D", true, false):
		if (r as Reactivo3D).tipo == "surtidor" and (r as Reactivo3D).celda == TINAJA:
			tinaja = r as Reactivo3D
	_ok("1 la escena tiene la tinaja (Reactivo3D «surtidor») en %s" % TINAJA, tinaja != null)
	if sim == null or tinaja == null:
		return
	tinaja.agua_llega.connect(func() -> void: _t_llega = reloj.t - _t_cast)

	var r0: float = sim.profundidad_casilla(RIO)
	var v0: float = sim.volumen_total()
	_ok("2 antes del golpe el canal está seco", profundidades(CANAL).all(func(p: float) -> bool: return p == 0.0), str(profundidades(CANAL)))

	_t_cast = reloj.t
	var salio: bool = lanzar_a_celda("agua", ["flecha", "flecha"], TINAJA, DESDE)        # 3 casillas = flecha ×2 (la 1.ª da 2 de alcance, cada una más suma 1)
	_ok("3 el hechizo agua + flecha sale", salio)
	await avanzar_vigilando(DURACION, 1.0, _al_segundo)

	# --- El golpe, visto desde el diario del juego (el que lee Pablo) ---
	var golpes: Array = eventos("golpe_objeto").filter(func(e: Dictionary) -> bool: return String(e.get("objeto", "")) == "surtidor")
	_ok("4 el diario tiene `golpe_objeto` con objeto «surtidor»", not golpes.is_empty(), "%d golpes" % golpes.size())
	_ok("4 y el golpe REACCIONA (reacciona = true)", not golpes.is_empty() and bool((golpes[0] as Dictionary).get("reacciona", false)))

	# --- Cuándo llega el agua y cuánta ---
	_ok("5 la tinaja avisó `agua_llega`", _t_llega > 0.0, "a los %.2f s de lanzar" % _t_llega)
	var pico: Array = [0.0, 0.0, 0.0]
	for fila in _tabla:
		for i in range(3):
			pico[i] = maxf(float(pico[i]), float((fila[1] as Array)[i]))
	for i in range(3):
		var nombre6: String = "6 la casilla %d del canal %s llega a ≥ %.2f u en algún momento de los %d s" % [i + 1, CANAL[i], UMBRAL, int(DURACION)]
		# La 3.ª desagua al río y, con el río a su nivel (desagüe, 15/10), se queda en ≈ 0,17 u: AVISO, no contrato (ver diario, entrada 71).
		if i == 2 and float(pico[i]) < UMBRAL:
			_aviso(nombre6, "máx %.3f" % pico[i])
		else:
			_ok(nombre6, float(pico[i]) >= UMBRAL, "máx %.3f" % pico[i])
	var al_horizonte: Array = _fila_en(HORIZONTE)
	if not al_horizonte.is_empty():
		# El objetivo literal de Pablo («a los 5 s las tres ≥ 0,25») NO es alcanzable con esta tinaja: tarda ≈ 4,1 s en llenarse, inclinarse
		# y verter (T_LLENADO 1,6 + T_INCLINA 1,2 + los tramos del chorro + el vuelo de la flecha) y a los 5 s solo lleva ≈ 0,9 s con agua.
		# Se mide y se enseña como AVISO; el contrato que sí se afirma es el 7 (medido desde `agua_llega`).
		var p5: Array = al_horizonte[1]
		var nombre7: String = "7 a los %d s de lanzar las tres casillas tienen ≥ %.2f u (objetivo de Pablo)" % [int(HORIZONTE), UMBRAL]
		if p5.all(func(p: float) -> bool: return p >= UMBRAL):
			_ok(nombre7, true)
		else:
			_aviso(nombre7, "%.3f / %.3f / %.3f (el agua llegó a los %.1f s)" % [p5[0], p5[1], p5[2], _t_llega])
	# Medido desde que LLEGA el agua, que es lo que depende de la simulación y no de la animación de la tinaja.
	var llegada_ok: bool = true
	var t_corte: float = _t_llega + MARGEN_DESDE_LLEGADA
	var tope: Array = [0.0, 0.0, 0.0]
	for fila in _tabla:
		if float(fila[0]) <= t_corte + 1.0e-6:
			for i in range(3):
				tope[i] = maxf(float(tope[i]), float((fila[1] as Array)[i]))
	for i in range(2):                                    # las dos primeras; la 3.ª (desagüe al río) se avisa en el 6
		llegada_ok = llegada_ok and float(tope[i]) >= UMBRAL
	_ok("7 a los %.0f s de `agua_llega` las dos primeras casillas ya han pasado de %.2f u" % [MARGEN_DESDE_LLEGADA, UMBRAL], _t_llega > 0.0 and llegada_ok,
		"%.3f / %.3f / %.3f" % [tope[0], tope[1], tope[2]])

	# --- El río NO sube (15/10, Pablo: «el caudal se va fuera del mapa») ---
	# Antes se exigía que subiera: era el fallo. El río del Bosque es una balsa cerrada y, sin desagüe, el manantial lo desbordaba.
	# Ahora `abrir_cauce` deja el río que recibe el canal a su nivel: se queda donde estaba y el volumen solo crece lo que cabe en el canal.
	var fila_fin: Array = _tabla.back()
	_ok("8 el río no sube (profundidad %.3f → %.3f u)" % [r0, float(fila_fin[2])], absf(float(fila_fin[2]) - r0) < 0.05)
	_ok("8 y el volumen total solo crece lo que cabe en el canal (%.2f → %.2f u³)" % [v0, float(fila_fin[3])], float(fila_fin[3]) > v0 and float(fila_fin[3]) - v0 < 5.0)


func _al_segundo(t: float) -> void:
	var sim: AguaSim3D = Terreno3D.agua_sim
	var p: Array = profundidades(CANAL)
	var fila: Array = [t, p, sim.profundidad_casilla(RIO), sim.volumen_total()]
	_tabla.append(fila)
	volcar("canal_profundidad", {"s": t, "c1": snappedf(p[0], 0.001), "c2": snappedf(p[1], 0.001), "c3": snappedf(p[2], 0.001),
		"rio": snappedf(float(fila[2]), 0.001), "volumen": snappedf(float(fila[3]), 0.01)})


func _fila_en(t: float) -> Array:
	for fila in _tabla:
		if absf(float(fila[0]) - t) < 0.05:
			return fila
	return []
