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
	await _q14()


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
	var r: Dictionary = {"t_lleno": -1.0, "t_abre": -1.0, "t_desborda": -1.0, "t_apaga": -1.0, "t_cierra": -1.0, "max": 0.0, "abierta_apagada": false, "n_aa": 0, "max_aa": 0, "max_antes_de_apagar": 0.0}
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
		# La puerta se cierra una décima después de apagarse el brasero (la regla corre en el siguiente fotograma lógico): solo cuenta si queda abierta más de 3 lecturas (0,75 s).
		r["n_aa"] = (int(r["n_aa"]) + 1) if (_abierta(puerta) and not _arde(brasero)) else 0
		r["max_aa"] = maxi(int(r["max_aa"]), int(r["n_aa"]))
		if int(r["max_aa"]) > 3:
			r["abierta_apagada"] = true
	)
	_ok("Q13.7 la cuenca llega a 0,45 (a los %.1f s) y con el brasero encendido la puerta abre (a los %.1f s)" % [float(r["t_lleno"]), float(r["t_abre"])],
		float(r["t_lleno"]) > 0.0 and float(r["t_abre"]) >= float(r["t_lleno"]) - 0.5 and float(r["t_abre"]) < float(r["t_lleno"]) + 1.0)
	_ok("Q13.8 la tinaja sigue vertiendo y el agua llega a 0,8 (a los %.1f s; máximo %.2f)" % [float(r["t_desborda"]), float(r["max"])], float(r["t_desborda"]) > float(r["t_lleno"]))
	_ok("Q13.9 al desbordar se APAGA el brasero (a los %.1f s)" % float(r["t_apaga"]), float(r["t_apaga"]) > 0.0 and float(r["t_apaga"]) <= float(r["t_desborda"]) + 1.0)
	_ok("Q13.10 … y la puerta se cierra con él (a los %.1f s); nunca quedó abierta más de 0,75 s con el brasero apagado" % float(r["t_cierra"]), float(r["t_cierra"]) > 0.0 and not bool(r["abierta_apagada"]) and not _abierta(puerta))
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


# ---------------------------------------------------------------------------------------------------------------------
#  Q14 · Reloj de agua
# ---------------------------------------------------------------------------------------------------------------------

const RELOJ_CELDAS: Array = [Vector2i(10, 26), Vector2i(11, 26), Vector2i(12, 26), Vector2i(10, 27), Vector2i(11, 27), Vector2i(12, 27), Vector2i(10, 28), Vector2i(11, 28), Vector2i(12, 28), Vector2i(10, 29), Vector2i(11, 29), Vector2i(12, 29)]


func _puzle3d() -> Puzle3D:
	return lab.get("_puzle_nodo") as Puzle3D


## Vuelve a llenar la cuenca del reloj a `prof` u (lo que haría quien recarga la sala con R) sin tocar el resto del estado.
func _rellenar_reloj(prof: float) -> void:
	for c in RELOJ_CELDAS:
		var fondo: float = float(_puzle3d().call("_fondo", c))
		Terreno3D.agua_sim.llenar_casilla(c as Vector2i, fondo + prof)


func _q14() -> void:
	var q: Dictionary = _sala("Q14")
	_ok("Q14.0 la sala existe en el lab", not q.is_empty())
	if q.is_empty():
		return
	var reloj_nivel: Variant = q["reloj"]
	var compuerta: Variant = q["compuerta"]
	var bs: Array = [q["b1"], q["b2"], q["b3"]]
	var puerta: Variant = q["puerta"]
	var boton: Pulsador3D = q["boton"]
	var placa: Pulsador3D = q["placa"]
	_tecla_sala(KEY_KP_2)
	_ok("Q14.1 la tecla 2 del teclado numérico lleva a la sala (12,25)", celda_jugador() == Vector2i(12, 25), str(celda_jugador()))
	_tecla_sala(KEY_3, true)
	_tecla_sala(KEY_2, true)
	_ok("Q14.2 Alt+2 también", celda_jugador() == Vector2i(12, 25), str(celda_jugador()))
	_ok("Q14.3 estado inicial: cuenca llena (%.2f), compuerta cerrada, tres braseros apagados y puerta cerrada" % _lleno(reloj_nivel),
		_lleno(reloj_nivel) >= 0.85 and not _abierta(compuerta) and not _arde(bs[0]) and not _arde(bs[1]) and not _arde(bs[2]) and not _abierta(puerta))
	lanzador.tinta = null
	await avanzar_s(5.0)
	_ok("Q14.4 el reloj no corre solo: 5 s después la cuenca sigue en %.2f" % _lleno(reloj_nivel), _lleno(reloj_nivel) >= 0.85 and not _abierta(compuerta))
	# 1 · Demasiado tarde: el primer brasero arranca el reloj, el nivel baja de 0,35 y los otros dos ya no abren.
	if modo == "natural":
		_ok("Q14.5 fuego + flecha al primer brasero (15,26) sale", lanzar_a_celda("fuego", ["flecha"], Vector2i(15, 26), Vector2i(15, 28)))
	else:
		colocar_jugador(Vector2i(15, 31))
	await avanzar_s(1.0)
	if modo == "natural":
		_ok("Q14.6 el primer brasero arde y abre el desagüe", _arde(bs[0]) and _abierta(compuerta))
	else:
		_ok("Q14.6 la placa @ (15,31) abre el desagüe sin encender nada", placa.veces == 1 and _abierta(compuerta) and not _arde(bs[0]))
	var r: Dictionary = {"t_050": -1.0, "t_035": -1.0}
	await avanzar_vigilando(120.0, 0.25, func(t: float) -> void:
		var h: float = _lleno(reloj_nivel)
		if float(r["t_050"]) < 0.0 and h <= 0.5:
			r["t_050"] = t
		if float(r["t_035"]) < 0.0 and h < 0.35:
			r["t_035"] = t
	)
	_ok("Q14.7 la cuenca se vacía sola: de 0,9 a 0,5 en %.1f s y por debajo de 0,35 en %.1f s (el reloj); nivel final %.2f" % [float(r["t_050"]), float(r["t_035"]), _lleno(reloj_nivel)],
		float(r["t_035"]) > 8.0 and float(r["t_035"]) < 100.0)
	_ok("Q14.8 sin agua en el reloj, nada ha abierto la puerta", not _abierta(puerta))
	if modo == "natural":
		_ok("Q14.9 fuego al segundo brasero (14,29) y al tercero (13,31) salen", lanzar_a_celda("fuego", ["flecha"], Vector2i(14, 29), Vector2i(14, 31)))
		await avanzar_s(1.0)
		_ok("Q14.9b … y al tercero", lanzar_a_celda("fuego", ["flecha"], Vector2i(13, 31), Vector2i(13, 29)))
	else:
		boton.pulsar()
	await avanzar_s(2.0)
	_ok("Q14.10 los tres arden pero tarde (nivel %.2f < 0,35): la puerta sigue cerrada" % _lleno(reloj_nivel), _arde(bs[0]) and _arde(bs[1]) and _arde(bs[2]) and _lleno(reloj_nivel) < 0.35 and not _abierta(puerta))
	# 2 · A tiempo: se rellena la cuenca (como quien recarga la sala), se apagan los braseros y se encienden los tres con el agua aún alta.
	_rellenar_reloj(0.9)
	for b in bs:
		(b as Reactivo3D).apagar_llama()
	await avanzar_s(0.5)
	_ok("Q14.11 recargada: cuenca %.2f, braseros apagados, puerta cerrada, desagüe ya abierto" % _lleno(reloj_nivel),
		_lleno(reloj_nivel) >= 0.85 and not _arde(bs[0]) and not _arde(bs[1]) and not _arde(bs[2]) and not _abierta(puerta) and _abierta(compuerta))
	var t0: float = reloj.t
	if modo == "natural":
		_ok("Q14.12 fuego al primero", lanzar_a_celda("fuego", ["flecha"], Vector2i(15, 26), Vector2i(15, 28)))
		await avanzar_s(1.0)
		_ok("Q14.12b fuego al segundo", lanzar_a_celda("fuego", ["flecha"], Vector2i(14, 29), Vector2i(14, 31)))
		await avanzar_s(1.0)
		_ok("Q14.12c fuego al tercero", lanzar_a_celda("fuego", ["flecha"], Vector2i(13, 31), Vector2i(13, 29)))
		await avanzar_s(1.5)
	else:
		boton.pulsar()
		await avanzar_s(1.0)
	var h_fin: float = _lleno(reloj_nivel)
	_ok("Q14.13 encendidos los tres a los %.1f s de la recarga, con la cuenca aún en %.2f (≥ 0,35): la puerta abre" % [reloj.t - t0, h_fin],
		_arde(bs[0]) and _arde(bs[1]) and _arde(bs[2]) and h_fin >= 0.35 and _abierta(puerta),"cont %d/%d completo=%s alcanzado=%s" % [(q["cont"] as ContadorReactivos3D).encendidos, (q["cont"] as ContadorReactivos3D).minimo, str((q["cont"] as ContadorReactivos3D).completo), str((reloj_nivel as NivelAgua3D).alcanzado)])