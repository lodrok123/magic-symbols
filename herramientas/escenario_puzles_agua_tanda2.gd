extends "res://herramientas/escenario_base.gd"
## Escenario · los puzles de la SEGUNDA TANDA del LABORATORIO DE AGUA (20/11/2026, Juego): Q13 «La caldera», Q14 «Reloj de agua» y Q15 «Lava con peso» (la fila de salas de abajo: (0,3), (1,3) y (2,3)).
## Carga laboratorios/LabPuzlesAgua3D.tscn y los juega por código con las piezas de verdad. Dos pasadas, como los demás escenarios de laboratorio (lo que se abre o se llena no se deshace):
##   · `natural`  (por defecto): la vía de la jugadora (hechizos de fuego y de agua).
##   · `botones`  (escenario_puzles_agua_tanda2_botones.gd): el botón `!` y la placa `@`, que separan «falla el agua» de «falla el disparador».
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_agua_tanda2.gd
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_agua_tanda2_botones.gd

const RUTA_LAB: String = "res://laboratorios/LabPuzlesAgua3D.tscn"

var modo: String = "natural"          ## "natural" | "botones" (lo cambia el escenario hijo en su _init)
var lab: Node = null


func _escenario() -> void:
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")
	_ok("0 el laboratorio cuelga de la escena", lab != null)
	if lab == null:
		return
	_ok("0 el mapa y las piezas de la segunda tanda se montan sin avisos", (lab.get("_avisos") as Array).is_empty(), str(lab.get("_avisos")))
	await _q13()


# ---------------------------------------------------------------------------------------------------------------------

func _sala(nombre: String) -> Dictionary:
	return lab.call("nuevo", nombre)


func _lleno(nd: Variant) -> float:
	return (nd as NivelAgua3D).profundidad


func _arde(nd: Variant) -> bool:
	return bool((nd as Object).get("is_lit"))


func _abierta(nd: Variant) -> bool:
	return bool((nd as Object).get("abierta"))


func _tecla_sala(tecla: Key, alt: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = tecla
	ev.pressed = true
	ev.alt_pressed = alt
	lab.call("_unhandled_input", ev)


# ---------------------------------------------------------------------------------------------------------------------
#  Q13 · La caldera
# ---------------------------------------------------------------------------------------------------------------------

func _q13() -> void:
	var q: Dictionary = _sala("Q13")
	_ok("Q13.0 la sala existe en el lab", not q.is_empty())
	if q.is_empty():
		return
	var nivel: Variant = q["nivel"]
	var desborda: Variant = q["desborda"]
	var brasero: Variant = q["brasero"]
	var puerta: Variant = q["puerta"]
	var boton: Pulsador3D = q["boton"]
	var placa: Pulsador3D = q["placa"]
	_tecla_sala(KEY_KP_1)
	_ok("Q13.1 la tecla 1 del teclado numérico lleva a la sala (4,25)", celda_jugador() == Vector2i(4, 25), str(celda_jugador()))
	colocar_jugador(Vector2i(20, 12))
	_tecla_sala(KEY_1, true)
	_ok("Q13.2 Alt+1 también (y no a Q1)", celda_jugador() == Vector2i(4, 25), str(celda_jugador()))
	_ok("Q13.3 estado inicial: cuenca vacía (%.2f), brasero apagado y puerta cerrada; los dos detectores piden 0,45 y 0,8" % _lleno(nivel),
		_lleno(nivel) < 0.05 and not _arde(brasero) and not _abierta(puerta) and absf((nivel as NivelAgua3D).objetivo - 0.45) < 0.001 and absf((desborda as NivelAgua3D).objetivo - 0.8) < 0.001)
	lanzador.tinta = null
	# 1 · Solo fuego: el brasero arde y la puerta sigue cerrada (la cuenca está vacía).
	if modo == "natural":
		_ok("Q13.4 fuego + flecha al brasero (3,29) sale", lanzar_a_celda("fuego", ["flecha"], Vector2i(3, 29), Vector2i(3, 31)))
	else:
		colocar_jugador(Vector2i(6, 31))
	await avanzar_s(1.5)
	_ok("Q13.5 con el brasero encendido y la cuenca vacía la puerta sigue cerrada", _arde(brasero) and not _abierta(puerta))
	if modo == "botones":
		_ok("Q13.5b la placa @ (6,31) encendió el brasero por su regla", placa.veces == 1)
	# 2 · El agua: sube; con 0,45 y el brasero encendido la puerta abre; al desbordar (0,8) apaga el brasero y la puerta se cierra.
	if modo == "natural":
		_ok("Q13.6 agua + flecha a la tinaja (5,27) sale", lanzar_a_celda("agua", ["flecha"], Vector2i(5, 27), Vector2i(7, 27)))
	else:
		boton.pulsar()
	var r: Dictionary = {"t_lleno": -1.0, "t_abre": -1.0, "t_desborda": -1.0, "t_apaga": -1.0, "t_cierra": -1.0, "max": 0.0, "abierta_apagada": false, "max_antes_de_apagar": 0.0}
	await avanzar_vigilando(110.0, 0.25, func(t: float) -> void:
		var h: float = _lleno(nivel)
		r["max"] = maxf(float(r["max"]), h)
		if float(r["t_lleno"]) < 0.0 and h >= 0.45:
			r["t_lleno"] = t
		if float(r["t_abre"]) < 0.0 and _abierta(puerta):
			r["t_abre"] = t
		if float(r["t_desborda"]) < 0.0 and _lleno(desborda) >= 0.8:
			r["t_desborda"] = t
		if float(r["t_apaga"]) < 0.0 and float(r["t_desborda"]) >= 0.0 and not _arde(brasero):
			r["t_apaga"] = t
		if float(r["t_apaga"]) >= 0.0 and float(r["t_cierra"]) < 0.0 and not _abierta(puerta):
			r["t_cierra"] = t
		if _abierta(puerta) and not _arde(brasero):
			r["abierta_apagada"] = true
	)
	_ok("Q13.7 la cuenca llega a 0,45 (a los %.1f s) y con el brasero encendido la puerta abre (a los %.1f s)" % [float(r["t_lleno"]), float(r["t_abre"])],
		float(r["t_lleno"]) > 0.0 and float(r["t_abre"]) >= float(r["t_lleno"]) - 0.5 and float(r["t_abre"]) < float(r["t_lleno"]) + 1.0)
	_ok("Q13.8 la tinaja sigue vertiendo y el agua llega a 0,8 (a los %.1f s; máximo %.2f)" % [float(r["t_desborda"]), float(r["max"])], float(r["t_desborda"]) > float(r["t_lleno"]))
	_ok("Q13.9 al desbordar se APAGA el brasero (a los %.1f s)" % float(r["t_apaga"]), float(r["t_apaga"]) > 0.0 and float(r["t_apaga"]) <= float(r["t_desborda"]) + 1.0)
	_ok("Q13.10 … y la puerta se cierra con él (a los %.1f s); nunca estuvo abierta con el brasero apagado" % float(r["t_cierra"]), float(r["t_cierra"]) > 0.0 and not bool(r["abierta_apagada"]) and not _abierta(puerta))
	_ok("Q13.11 solo agua (cuenca %.2f, brasero apagado): la puerta sigue cerrada" % _lleno(nivel), _lleno(nivel) >= 0.8 and not _arde(brasero) and not _abierta(puerta))
	# 3 · ENCENDER DESPUÉS: con la cuenca llena, el brasero vuelve a arder y la puerta abre; no se vuelve a apagar (la regla del desborde salta una vez).
	if modo == "natural":
		_ok("Q13.12 fuego + flecha al brasero otra vez sale", lanzar_a_celda("fuego", ["flecha"], Vector2i(3, 29), Vector2i(3, 31)))
	else:
		colocar_jugador(Vector2i(4, 25))             # sale de la placa y vuelve a pisarla
		await avanzar_s(0.5)
		colocar_jugador(Vector2i(6, 31))
	await avanzar_s(2.0)
	_ok("Q13.13 encendido DESPUÉS del desborde, el brasero arde y la puerta abre (nivel %.2f)" % _lleno(nivel), _arde(brasero) and _abierta(puerta))
	await avanzar_s(6.0)
	_ok("Q13.14 y sigue así: el agua ya no lo apaga", _arde(brasero) and _abierta(puerta))
