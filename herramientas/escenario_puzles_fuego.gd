extends "res://herramientas/escenario_base.gd"
## Escenario 14.6 · el LABORATORIO DE PUZLES DE FUEGO (F1–F5) entero, sin ventana (16/10, Juego). Carga laboratorios/LabPuzlesFuego3D.tscn (la
## maqueta con el mapa PuzlesFuego, el jugador, el Lanzador3D, el agua y las piezas de verdad) y JUEGA los cinco puzles por código.
## Dos pasadas, porque lo que se quema o se derrite no se puede deshacer (una cuerda rota, un seto consumido, un hielo derretido) y cada sala
## solo tiene una de cada:
##   · `natural`  (por defecto):  la vía del jugador, lanzando el hechizo que toca (flechas de fuego y de agua con `lanzar_a_celda`).
##                                F4 aquí es «déjalo arder»: la mecha, los setos y el barril sin tocar nada.
##   · `botones`  (escenario_puzles_fuego_botones.gd): el botón `!` y la placa `@` de cada sala, que separan «falla el fuego» de «falla el
##                                disparador», y el CORTAFUEGOS de F4 (agua al seto del medio, que es lo que NO se puede probar en la pasada natural).
## Las dos terminan en FALLOS 0. Se corren con:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_fuego.gd
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_fuego_botones.gd
## (en Windows: tools\prueba_una.cmd escenario_puzles_fuego  y  tools\prueba_una.cmd escenario_puzles_fuego_botones).
## Lo que se mide y todavía no es contrato (los tiempos de cada puzle) se imprime como AVISO.

const RUTA_LAB: String = "res://laboratorios/LabPuzlesFuego3D.tscn"

var modo: String = "natural"          ## "natural" | "botones" (lo cambia el escenario hijo en su _init)
var lab: Node = null


func _escenario() -> void:
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")
	_ok("0 el laboratorio cuelga de la escena y ha montado sus cinco puzles", lab != null and lab.get("_puzles") != null and (lab.get("_puzles") as Array).size() == 5, str((lab.get("_puzles") as Array).size()) if lab != null and lab.get("_puzles") != null else "sin lab")
	if lab == null:
		return
	_ok("0 el mapa tiene las letras y las piezas que el lab espera (sin avisos)", (lab.get("_avisos") as Array).is_empty(), str(lab.get("_avisos")))
	_ok("0 la gramática nueva se ha montado: braseros, setos, contadores y cuerda", _puzle3d().pieza("f1_cont") != null and is_instance_valid(_puzle3d().nodo("f1_cont")) and is_instance_valid(_puzle3d().nodo("f3_cuerda")) and is_instance_valid(_puzle3d().nodo("f2_a")) and is_instance_valid(_puzle3d().nodo("f4_s3")))
	if modo == "natural":
		await _f1_natural()
		await _f2_natural()
		await _f5_natural()
		await _f3_natural()
		await _f4_natural()
	else:
		await _f1_botones()
		await _f2_botones()
		await _f5_botones()
		await _f3_botones()
		await _f4_botones()


# ---------------------------------------------------------------------------------------------------------------------

func _puzle3d() -> Puzle3D:
	return lab.get("_puzle_nodo") as Puzle3D


func _runa(etiquetas: Array) -> RuneData:
	return Puzle3D.runa(etiquetas)


func _arde(n: Variant) -> bool:
	return n != null and is_instance_valid(n) and bool((n as Object).get("is_lit"))


## Un disparo de FUEGO a una casilla, desde otra, y lo que tarda la flecha en llegar.
func _fuego_a(objetivo: Vector2i, desde: Vector2i) -> bool:
	var ok: bool = lanzar_a_celda("fuego", ["flecha"], objetivo, desde)
	await avanzar_s(1.2)
	return ok


func _agua_a(objetivo: Vector2i, desde: Vector2i) -> bool:
	var ok: bool = lanzar_a_celda("agua", ["flecha"], objetivo, desde)
	await avanzar_s(1.2)
	return ok


func _apagar_todos(nodos: Array) -> void:
	for n in nodos:
		if is_instance_valid(n):
			(n as Reactivo3D).apagar_llama()


# ---------------------------------------------------------------------------------------------------------------------
#  F1 · cuatro antorchas
# ---------------------------------------------------------------------------------------------------------------------

func _f1_natural() -> void:
	var q: Dictionary = lab.call("puzle", "F1")
	var bs: Array = [q["b1"], q["b2"], q["b3"], q["b4"]]
	var ct: ContadorReactivos3D = q["contador"]
	var puerta: Node = q["puerta"]
	_ok("F1.1 cuatro braseros apagados, el contador a 0/4 y la puerta cerrada", bs.size() == 4 and ct.total() == 4 and ct.encendidos == 0 and not ct.completo and not bool(puerta.get("abierta")))
	var origenes: Array = [Vector2i(10, 4), Vector2i(14, 4), Vector2i(10, 4), Vector2i(14, 4)]
	var casillas: Array = [Vector2i(10, 2), Vector2i(14, 2), Vector2i(10, 6), Vector2i(14, 6)]
	for i in range(3):
		_ok("F1.2.%d fuego + flecha al brasero %d sale" % [i + 1, i + 1], await _fuego_a(casillas[i], origenes[i]))
		_ok("F1.3.%d el brasero %d arde y el contador va a %d/4" % [i + 1, i + 1, i + 1], _arde(bs[i]) and ct.encendidos == i + 1, "contador %d/%d" % [ct.encendidos, ct.total()])
	_ok("F1.4 con 3/4 la puerta sigue cerrada", not ct.completo and not bool(puerta.get("abierta")))
	_ok("F1.5 fuego + flecha al cuarto brasero sale", await _fuego_a(casillas[3], origenes[3]))
	_ok("F1.6 con 4/4 el contador completa y la puerta se abre", ct.completo and bool(puerta.get("abierta")), "contador %d/%d" % [ct.encendidos, ct.total()])
	_ok("F1.7 agua + flecha a un brasero lo apaga", await _agua_a(casillas[1], origenes[1]) and not _arde(bs[1]))
	_ok("F1.8 con 3/4 la puerta se vuelve a cerrar", not ct.completo and not bool(puerta.get("abierta")))
	_ok("F1.9 fuego otra vez al brasero apagado: 4/4 y la puerta abre", await _fuego_a(casillas[1], origenes[1]) and ct.completo and bool(puerta.get("abierta")))


func _f1_botones() -> void:
	var q: Dictionary = lab.call("puzle", "F1")
	var bs: Array = [q["b1"], q["b2"], q["b3"], q["b4"]]
	var ct: ContadorReactivos3D = q["contador"]
	var puerta: Node = q["puerta"]
	(lab.call("pulsador_en", Vector2i(10, 7)) as Node).call("pulsar")
	await avanzar_s(0.5)
	_ok("F1.B1 el botón enciende los cuatro y abre la puerta", ct.encendidos == 4 and bool(puerta.get("abierta")), "contador %d/4" % ct.encendidos)
	_apagar_todos(bs)
	await avanzar_s(0.5)
	_ok("F1.B2 apagados los cuatro, la puerta se cierra", ct.encendidos == 0 and not bool(puerta.get("abierta")))
	colocar_jugador(Vector2i(14, 7))
	await avanzar_s(0.8)
	_ok("F1.B3 la placa (pisarla) los vuelve a encender y abre la puerta", ct.encendidos == 4 and bool(puerta.get("abierta")), "contador %d/4" % ct.encendidos)
	colocar_jugador(Vector2i(12, 8))


# ---------------------------------------------------------------------------------------------------------------------
#  F2 · relé de braseros
# ---------------------------------------------------------------------------------------------------------------------

## Mide una pasada del relé: cuándo se enciende y se apaga cada brasero y cuándo se abre y cierra la puerta (t desde que se llama).
func _medir_rele(q: Dictionary, segundos: float) -> Dictionary:
	var r: Dictionary = {"on": {}, "off": {}, "abre": -1.0, "cierra": -1.0}
	var puerta: Node = q["puerta"]
	await avanzar_vigilando(segundos, 0.1, func(t: float) -> void:
		for id in ["a", "b", "c", "d"]:
			var lit: bool = _arde(q[id])
			if lit and not (r["on"] as Dictionary).has(id):
				(r["on"] as Dictionary)[id] = t
			if not lit and (r["on"] as Dictionary).has(id) and not (r["off"] as Dictionary).has(id):
				(r["off"] as Dictionary)[id] = t
		var ab: bool = bool(puerta.get("abierta"))
		if ab and float(r["abre"]) < 0.0:
			r["abre"] = t
		if not ab and float(r["abre"]) >= 0.0 and float(r["cierra"]) < 0.0:
			r["cierra"] = t
	)
	return r


func _afirmar_rele(pref: String, r: Dictionary) -> void:
	var on: Dictionary = r["on"]
	var off: Dictionary = r["off"]
	var ta: float = float(on.get("a", -99.0))
	_ok(pref + "1 se encienden los cuatro, uno tras otro", on.size() == 4 and float(on.get("b", -1.0)) > ta and float(on.get("c", -1.0)) > float(on.get("b", -1.0)) and float(on.get("d", -1.0)) > float(on.get("c", -1.0)), str(on))
	_ok(pref + "2 cada uno enciende al siguiente a los 1,5 s (±0,3)", absf(float(on.get("b", -99.0)) - ta - 1.5) < 0.3 and absf(float(on.get("c", -99.0)) - ta - 3.0) < 0.4 and absf(float(on.get("d", -99.0)) - ta - 4.5) < 0.5, "B +%.1f C +%.1f D +%.1f" % [float(on.get("b", 0.0)) - ta, float(on.get("c", 0.0)) - ta, float(on.get("d", 0.0)) - ta])
	_ok(pref + "3 cada uno se apaga solo a los 6 s de encenderse (±0,3)", off.size() == 4 and absf(float(off.get("a", -99.0)) - ta - 6.0) < 0.3 and absf(float(off.get("d", -99.0)) - float(on.get("d", 0.0)) - 6.0) < 0.3, str(off))
	_ok(pref + "4 la puerta solo abre cuando A y D arden a la vez: se abre con D (+4,5 s)…", float(r["abre"]) > 0.0 and absf(float(r["abre"]) - float(on.get("d", -99.0))) < 0.3, "abre a los %.1f s, D a los %.1f s" % [float(r["abre"]), float(on.get("d", 0.0))])
	_ok(pref + "5 … y se cierra cuando A se apaga (+6 s): la ventana dura ~1,5 s", float(r["cierra"]) > 0.0 and absf(float(r["cierra"]) - float(off.get("a", -99.0))) < 0.3 and float(r["cierra"]) - float(r["abre"]) < 2.2, "cierra a los %.1f s (ventana %.1f s)" % [float(r["cierra"]), float(r["cierra"]) - float(r["abre"])])


func _f2_natural() -> void:
	var q: Dictionary = lab.call("puzle", "F2")
	var puerta: Node = q["puerta"]
	_ok("F2.1 los cuatro braseros apagados y la puerta cerrada", not _arde(q["a"]) and not _arde(q["b"]) and not _arde(q["c"]) and not _arde(q["d"]) and not bool(puerta.get("abierta")))
	_ok("F2.2 fuego + flecha al primer brasero sale", lanzar_a_celda("fuego", ["flecha"], Vector2i(1, 11), Vector2i(1, 13)))
	var r: Dictionary = await _medir_rele(q, 13.0)
	_afirmar_rele("F2.3.", r)
	_ok("F2.4 pasada la fila, todo apagado y la puerta cerrada", not _arde(q["a"]) and not _arde(q["b"]) and not _arde(q["c"]) and not _arde(q["d"]) and not bool(puerta.get("abierta")))
	# Cortar el relé: si el primero se apaga antes de 1,5 s, el segundo nunca llega a encenderse.
	(q["a"] as Reactivo3D).on_spell_hit(_runa(["fuego", "calor"]), Vector3.ZERO)
	await avanzar_s(0.6)
	_ok("F2.5 A encendido otra vez y B aún no (0,6 s)", _arde(q["a"]) and not _arde(q["b"]))
	(q["a"] as Reactivo3D).on_spell_hit(_runa(["agua", "humedo"]), Vector3.ZERO)
	await avanzar_s(4.0)
	_ok("F2.6 con A apagado antes de 1,5 s el relé se corta: B, C y D no se encienden nunca", not _arde(q["a"]) and not _arde(q["b"]) and not _arde(q["c"]) and not _arde(q["d"]) and not bool(puerta.get("abierta")))
	volcar("f2_natural", {"on": r["on"], "off": r["off"], "abre": r["abre"], "cierra": r["cierra"]})


func _f2_botones() -> void:
	var q: Dictionary = lab.call("puzle", "F2")
	(lab.call("pulsador_en", Vector2i(2, 14)) as Node).call("pulsar")
	_ok("F2.B1 el botón enciende el primer brasero", _arde(q["a"]))
	var r: Dictionary = await _medir_rele(q, 12.0)
	_afirmar_rele("F2.B2.", r)
	colocar_jugador(Vector2i(6, 14))
	await avanzar_s(0.5)
	_ok("F2.B3 la placa (pisarla) vuelve a encender el primero", _arde(q["a"]), "ARDE" if _arde(q["a"]) else "apagado")
	colocar_jugador(Vector2i(8, 12))
	await avanzar_s(12.0)


# ---------------------------------------------------------------------------------------------------------------------
#  F5 · derrite el bloque
# ---------------------------------------------------------------------------------------------------------------------

func _f5_natural() -> void:
	var q: Dictionary = lab.call("puzle", "F5")
	var hielo: Node = q["compuerta"]
	var antorcha: Reactivo3D = q["antorcha"]
	var det: NivelAgua3D = q["detector"]
	var puerta: Node = q["puerta"]
	var sim: AguaSim3D = Terreno3D.agua_sim
	_ok("F5.1 el hielo cierra el paso: A llena, B seca, antorcha apagada, puerta cerrada", sim.profundidad_casilla(Vector2i(2, 2)) > 0.8 and sim.profundidad_casilla(Vector2i(6, 3)) == 0.0 and not bool(hielo.get("abierta")) and not _arde(antorcha) and not bool(puerta.get("abierta")))
	# Orden equivocado: primero la antorcha.
	_ok("F5.2 fuego + flecha a la antorcha sale", await _fuego_a(Vector2i(6, 5), Vector2i(4, 5)))
	_ok("F5.3 la antorcha arde pero con el hielo puesto la puerta NO abre (hace falta el hielo derretido)", _arde(antorcha) and not bool(puerta.get("abierta")))
	_ok("F5.4 fuego + flecha al hielo sale", await _fuego_a(Vector2i(4, 3), Vector2i(4, 5)))
	_ok("F5.5 el fuego derrite el hielo (la compuerta se abre)", bool(hielo.get("abierta")))
	var r: Dictionary = {"apaga": -1.0}
	await avanzar_vigilando(40.0, 0.2, func(t: float) -> void:
		if float(r["apaga"]) < 0.0 and not _arde(antorcha):
			r["apaga"] = t
	)
	_ok("F5.6 el agua llega a B (≥ 0,2) y el charco APAGA la antorcha", float(r["apaga"]) > 0.0 and det.profundidad >= 0.2, "se apagó a los %.1f s de derretir (nivel %.2f)" % [float(r["apaga"]), det.profundidad])
	_ok("F5.7 con la antorcha apagada la puerta sigue cerrada", not bool(puerta.get("abierta")))
	_ok("F5.8 fuego otra vez a la antorcha (hielo ya derretido): la puerta se abre", await _fuego_a(Vector2i(6, 5), Vector2i(4, 5)) and _arde(antorcha) and bool(puerta.get("abierta")))
	_aviso("F5 el charco apaga la antorcha a los", "%.1f s de derretir el hielo (B %.2f u)" % [float(r["apaga"]), det.profundidad])
	volcar("f5_natural", {"apaga": r["apaga"]})


func _f5_botones() -> void:
	var q: Dictionary = lab.call("puzle", "F5")
	var hielo: Node = q["compuerta"]
	var antorcha: Reactivo3D = q["antorcha"]
	var puerta: Node = q["puerta"]
	(lab.call("pulsador_en", Vector2i(2, 6)) as Node).call("pulsar")
	_ok("F5.B1 el botón derrite el hielo", bool(hielo.get("abierta")))
	await avanzar_s(30.0)
	_ok("F5.B2 con el hielo derretido y la antorcha apagada la puerta sigue cerrada", not _arde(antorcha) and not bool(puerta.get("abierta")))
	colocar_jugador(Vector2i(6, 6))
	await avanzar_s(0.8)
	_ok("F5.B3 la placa enciende la antorcha y con el hielo ya derretido se abre la puerta", _arde(antorcha) and bool(puerta.get("abierta")))
	colocar_jugador(Vector2i(4, 8))


# ---------------------------------------------------------------------------------------------------------------------
#  F3 · cuerda
# ---------------------------------------------------------------------------------------------------------------------

func _f3_natural() -> void:
	var q: Dictionary = lab.call("puzle", "F3")
	var comp: Node = q["compuerta"]
	var cuerda: Cuerda3D = q["cuerda"]
	var puerta: Node = q["puerta"]
	var sim: AguaSim3D = Terreno3D.agua_sim
	await avanzar_s(25.0)                                   # régimen del arroyo (el arranque del manantial son 18 s)
	var vado: float = sim.profundidad_casilla(Vector2i(18, 4))
	_ok("F3.1 el arroyo corre por la compuerta levantada: el vado pasa de 0,25 y la puerta está cerrada", bool(comp.get("abierta")) and vado > 0.25 and not bool(puerta.get("abierta")), "%.2f u con %.2f u³/s" % [vado, LabPuzlesFuego3D.CAUDAL_ARROYO_F3])
	_ok("F3.2 la cuerda está entera", cuerda.estado == Cuerda3D.EstadoCuerda.ENTERA and not cuerda.rota_ya)
	_ok("F3.3 fuego + flecha a la cuerda sale", lanzar_a_celda("fuego", ["flecha"], Vector2i(19, 2), Vector2i(19, 4)))
	var r: Dictionary = {"arde": -1.0, "rota": -1.0, "baja": -1.0}
	await avanzar_vigilando(30.0, 0.1, func(t: float) -> void:
		if float(r["arde"]) < 0.0 and cuerda.estado == Cuerda3D.EstadoCuerda.ARDIENDO:
			r["arde"] = t
		if float(r["rota"]) < 0.0 and cuerda.rota_ya:
			r["rota"] = t
		if float(r["baja"]) < 0.0 and sim.profundidad_casilla(Vector2i(18, 4)) <= 0.25:
			r["baja"] = t
	)
	_ok("F3.4 la cuerda arde y se rompe a los T_ARDE s", float(r["arde"]) > 0.0 and float(r["rota"]) > float(r["arde"]) and absf(float(r["rota"]) - float(r["arde"]) - Cuerda3D.T_ARDE) < 0.25, "ardiendo a los %.1f s, rota a los %.1f s" % [float(r["arde"]), float(r["rota"])])
	_ok("F3.5 al romperse, la compuerta que sostenía CAE (se cierra)", not bool(comp.get("abierta")))
	_ok("F3.6 sin agua que baje el vado cae de 0,25 y la puerta se abre", float(r["baja"]) > 0.0 and bool(puerta.get("abierta")), "a los %.1f s de lanzar (vado %.2f u)" % [float(r["baja"]), sim.profundidad_casilla(Vector2i(18, 4))])
	volcar("f3_natural", {"arde": r["arde"], "rota": r["rota"], "baja": r["baja"]})


func _f3_botones() -> void:
	var q: Dictionary = lab.call("puzle", "F3")
	var comp: Node = q["compuerta"]
	var cuerda: Cuerda3D = q["cuerda"]
	var puerta: Node = q["puerta"]
	var sim: AguaSim3D = Terreno3D.agua_sim
	await avanzar_s(25.0)
	_ok("F3.B1 con la cuerda entera el vado pasa de 0,25 y la puerta está cerrada", bool(comp.get("abierta")) and sim.profundidad_casilla(Vector2i(18, 4)) > 0.25 and not bool(puerta.get("abierta")))
	(lab.call("pulsador_en", Vector2i(17, 6)) as Node).call("pulsar")
	_ok("F3.B2 el botón prende la cuerda", cuerda.estado == Cuerda3D.EstadoCuerda.ARDIENDO)
	var r: Dictionary = {"baja": -1.0}
	await avanzar_vigilando(30.0, 0.2, func(t: float) -> void:
		if float(r["baja"]) < 0.0 and bool(puerta.get("abierta")):
			r["baja"] = t
	)
	_ok("F3.B3 la cuerda se rompe, la compuerta cae y la puerta se abre", cuerda.rota_ya and not bool(comp.get("abierta")) and float(r["baja"]) > 0.0, "puerta a los %.1f s" % float(r["baja"]))
	var reglas: Array = _puzle3d().reglas()
	var placa_regla: bool = false
	for rg in reglas:
		if String((rg as Dictionary)["nombre"]) == "f3_placa_quema":
			var ac: Array = (rg as Dictionary)["acciones"]
			placa_regla = ac.size() == 1 and String((ac[0] as Dictionary)["accion"]) == "quemar" and String((ac[0] as Dictionary)["id"]) == "f3_cuerda"
	_ok("F3.B4 la placa está cableada a quemar la cuerda (la cuerda rota ya no se puede volver a quemar)", placa_regla)


# ---------------------------------------------------------------------------------------------------------------------
#  F4 · contrafuego
# ---------------------------------------------------------------------------------------------------------------------

func _f4_natural() -> void:
	var q: Dictionary = lab.call("puzle", "F4")
	var barril: Barril3D = q["barril"]
	var puerta: Node = q["puerta"]
	var setos: Array = [q["s1"], q["s2"], q["s3"], q["s4"]]
	_ok("F4.1 todo en reposo: mecha apagada, cuatro setos secos, barril entero, puerta cerrada", not _arde(q["mecha"]) and not lab.call("mecha_encendida") and not barril.encendido and not barril.explotado and not bool(puerta.get("abierta")) and setos.all(func(s): return is_instance_valid(s) and not _arde(s)))
	await avanzar_s(6.0)
	_ok("F4.2 sin entrar en la sala la mecha no corre (la cuenta empieza al pisarla)", not lab.call("mecha_encendida") and not _arde(q["mecha"]))
	colocar_jugador(Vector2i(28, 7))
	var r: Dictionary = {"mecha": -1.0, "s": {}, "barril": -1.0, "explota": -1.0, "puerta": -1.0}
	await avanzar_vigilando(25.0, 0.1, func(t: float) -> void:
		if float(r["mecha"]) < 0.0 and lab.call("mecha_encendida"):
			r["mecha"] = t
		for i in range(4):
			if not (r["s"] as Dictionary).has(i) and (not is_instance_valid(setos[i]) or _arde(setos[i])):
				(r["s"] as Dictionary)[i] = t
		if float(r["barril"]) < 0.0 and barril.encendido:
			r["barril"] = t
		if float(r["explota"]) < 0.0 and barril.explotado:
			r["explota"] = t
		if float(r["puerta"]) < 0.0 and bool(puerta.get("abierta")):
			r["puerta"] = t
	)
	var rs: Dictionary = r["s"]
	_ok("F4.3 a los %.0f s de entrar se enciende la mecha (±0,3)" % LabPuzlesFuego3D.T_MECHA_F4, absf(float(r["mecha"]) - LabPuzlesFuego3D.T_MECHA_F4) < 0.3, "a los %.1f s" % float(r["mecha"]))
	_ok("F4.4 el fuego corre por los setos EN ORDEN (1→2→3→4)", rs.size() == 4 and float(rs[0]) <= float(rs[1]) and float(rs[1]) < float(rs[2]) and float(rs[2]) < float(rs[3]), str(rs))
	_ok("F4.5 el último seto enciende el barril (contagio a ≤ %.1f u)" % Barril3D.RADIO_FUEGO, float(r["barril"]) >= float(rs.get(3, 99.0)) - 0.3 and float(r["barril"]) > 0.0, "barril a los %.1f s, último seto a los %.1f s" % [float(r["barril"]), float(rs.get(3, -1.0))])
	_ok("F4.6 el barril explota a los T_MECHA s de encenderse y la puerta se abre", float(r["explota"]) > 0.0 and absf(float(r["explota"]) - float(r["barril"]) - Barril3D.T_MECHA) < 0.4 and float(r["puerta"]) >= float(r["explota"]) - 0.1, "explota a los %.1f s, puerta a los %.1f s" % [float(r["explota"]), float(r["puerta"])])
	_aviso("F4 de entrar a la puerta abierta (déjalo arder)", "%.1f s" % float(r["puerta"]))
	volcar("f4_natural", {"mecha": r["mecha"], "setos": rs, "barril": r["barril"], "explota": r["explota"], "puerta": r["puerta"]})


func _f4_botones() -> void:
	var q: Dictionary = lab.call("puzle", "F4")
	var barril: Barril3D = q["barril"]
	var puerta: Node = q["puerta"]
	var s1: Reactivo3D = q["s1"]
	var s2: Reactivo3D = q["s2"]
	var s3: Reactivo3D = q["s3"]
	var s4: Reactivo3D = q["s4"]
	colocar_jugador(Vector2i(28, 6))
	_ok("F4.B1 agua + flecha al seto del medio (28,4) sale", lanzar_a_celda("agua", ["flecha"], Vector2i(28, 4), Vector2i(28, 6)))
	await avanzar_s(1.2)
	_ok("F4.B2 el seto del medio queda MOJADO y no puede arder", s3.esta_mojado() and not s3.can_burn() and not _arde(s3), "mojado %s" % str(s3.esta_mojado()))
	_ok("F4.B3 los demás siguen secos y prenden (cualquier otro seto puede arder)", s1.can_burn() and s2.can_burn() and s4.can_burn())
	var r: Dictionary = {"s2_arde": false, "s4_arde": false, "s3_arde": false, "barril": false}
	await avanzar_vigilando(14.0, 0.1, func(_t: float) -> void:
		if _arde(s2):
			r["s2_arde"] = true
		if _arde(s3):
			r["s3_arde"] = true
		if _arde(s4):
			r["s4_arde"] = true
		if barril.encendido or barril.explotado:
			r["barril"] = true
	)
	_ok("F4.B4 la mecha prende el primer seto y el fuego llega al segundo", bool(lab.call("mecha_encendida")) and bool(r["s2_arde"]), "s2 ardió: %s" % str(r["s2_arde"]))
	_ok("F4.B5 CORTAFUEGOS: el fuego se para en el seto mojado; el cuarto no arde", not bool(r["s3_arde"]) and not bool(r["s4_arde"]), "s3 %s s4 %s" % [str(r["s3_arde"]), str(r["s4_arde"])])
	_ok("F4.B6 … y el barril sigue entero y la puerta cerrada", not bool(r["barril"]) and not barril.explotado and not bool(puerta.get("abierta")))
	_ok("F4.B7 los dos primeros setos se consumieron (ya no hay fuego en la sala)", not is_instance_valid(s1) and not is_instance_valid(s2) and is_instance_valid(s3) and is_instance_valid(s4) and not _arde(s3))
	(lab.call("pulsador_en", Vector2i(26, 6)) as Node).call("pulsar")
	_ok("F4.B8 el botón enciende el barril a mano (cuando el jugador quiera)", barril.encendido)
	await avanzar_s(Barril3D.T_MECHA + 1.0)
	_ok("F4.B9 explota y la puerta se abre", barril.explotado and bool(puerta.get("abierta")))
	var hay_placa: bool = false
	for rg in _puzle3d().reglas():
		if String((rg as Dictionary)["nombre"]) == "f4_placa_enciende":
			hay_placa = true
	_ok("F4.B10 la placa está cableada a encender el barril", hay_placa)
