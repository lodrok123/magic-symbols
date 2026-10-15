extends "res://herramientas/escenario_base.gd"
## Escenario 13.8 · un hechizo de agua sobre HIERBA deja un charco que moja el suelo y se seca solo. Lo escribe el Juego (15/10).
##
## Recorre el camino del jugador (flecha + agua contra una casilla de suelo, con la escena entera): el impacto echa VOL_AGUA_IMPACTO
## (0,24 u³) a la simulación → una lámina muy fina en la casilla («charco») que el suelo absorbe enseguida (PROF_CHARCO) → la casilla
## queda «mojada» (el suelo se oscurece) y se SECA_EN s después de quedarse sin agua deja de estarlo.
## Mide cada 0,1 s la casilla más honda de la zona. Las cifras (cuándo se absorbe, cuándo se seca) van al diario («charco») y a la consola.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_agua_estanque.gd

const OBJETIVO := Vector2i(6, 24)                      ## hierba abierta del Bosque, lejos de agua, de muros y de objetos
const DESDE := Vector2i(9, 24)
const RADIO: int = 4                                   ## casillas alrededor del objetivo donde se busca el charco
const TOLERANCIA: float = 1.5                          ## s de margen al afirmar cuándo se seca
const DURACION: float = 40.0

var _t0: float = 0.0
var _pico: float = 0.0                                 ## la mayor profundidad vista en la zona
var _celda_pico := Vector2i(-1, -1)
var _t_pico: float = -1.0
var _t_sin_agua: float = -1.0                          ## s (desde lanzar) en que toda la zona se quedó sin lámina tras el pico
var _t_seca: float = -1.0                              ## s en que la casilla del pico dejó de estar mojada
var _mojada_en_pico: bool = false                      ## ¿estaba mojada la casilla en el instante de más agua?


func _escenario() -> void:
	await cargar()
	var sim: AguaSim3D = Terreno3D.agua_sim
	_ok("1 la zona es hierba abierta (no agua, no bloqueada)", not Terreno3D.es_agua(OBJETIVO) and not Lanzador3D.bloqueada(OBJETIVO) and not Terreno3D.es_agua(DESDE))
	_ok("1 antes del hechizo no hay agua ni mojado en la zona", _zona(sim).is_empty())
	_t0 = reloj.t
	_ok("2 el hechizo agua + flecha sale", lanzar_a_celda("agua", ["flecha"], OBJETIVO, DESDE))
	await avanzar_vigilando(DURACION, 0.1, _medir)

	_ok("3 se forma un charco: alguna casilla llega a tener agua (> 0)", _pico > 0.0, "pico %.4f u en %s a los %.1f s" % [_pico, _celda_pico, _t_pico])
	_ok("3 el charco está en la casilla apuntada o pegado a ella", _celda_pico.distance_to(Vector2(OBJETIVO)) <= 1.5, "%s (objetivo %s)" % [_celda_pico, OBJETIVO])
	_ok("4 el suelo está mojado donde más agua hay", _mojada_en_pico)
	_ok("5 el charco se absorbe (la zona se queda sin lámina)", _t_sin_agua > 0.0, "a los %.1f s" % _t_sin_agua)
	_ok("6 la casilla se seca a los SECA_EN (%.0f s) de quedarse sin agua" % AguaSim3D.SECA_EN, _t_seca > 0.0 and absf((_t_seca - _t_sin_agua) - AguaSim3D.SECA_EN) <= TOLERANCIA,
		"sin agua a los %.1f s, seca a los %.1f s (diferencia %.1f s)" % [_t_sin_agua, _t_seca, _t_seca - _t_sin_agua])
	volcar("charco", {"pico": snappedf(_pico, 0.0001), "celda": [_celda_pico.x, _celda_pico.y], "t_pico": _t_pico, "t_sin_agua": _t_sin_agua, "t_seca": _t_seca})


## Las casillas de la zona con agua o mojadas: {celda: profundidad}.
func _zona(sim: AguaSim3D) -> Dictionary:
	var r: Dictionary = {}
	for y in range(OBJETIVO.y - RADIO, OBJETIVO.y + RADIO + 1):
		for x in range(OBJETIVO.x - RADIO, OBJETIVO.x + RADIO + 1):
			var c := Vector2i(x, y)
			if sim.profundidad_casilla(c) > 0.0 or sim.casilla_mojada(c):
				r[c] = sim.profundidad_casilla(c)
	return r


func _medir(t: float) -> void:
	var sim: AguaSim3D = Terreno3D.agua_sim
	var zona: Dictionary = _zona(sim)
	var con_agua: bool = false
	for c in zona:
		var p: float = float(zona[c])
		if p > 0.0:
			con_agua = true
			if p > _pico:
				_pico = p
				_celda_pico = c
				_t_pico = t
				_mojada_en_pico = sim.casilla_mojada(c)       # (una lámina por debajo de PROF_CHARCO aún no cuenta como mojado: por eso solo en el pico)
	if _pico > 0.0 and _t_sin_agua < 0.0 and not con_agua:
		_t_sin_agua = t
	if _t_sin_agua > 0.0 and _t_seca < 0.0 and not sim.casilla_mojada(_celda_pico):
		_t_seca = t
