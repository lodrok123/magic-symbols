extends "res://herramientas/escenario_base.gd"
## Escenario 13.8 · el LABORATORIO DE PUZLES DE AGUA entero, sin ventana (15/10, Juego). Carga laboratorios/LabPuzlesAgua3D.tscn (la
## maqueta con el mapa PuzlesAgua, el jugador, el Lanzador3D, la simulación y las piezas de verdad) y JUEGA cada puzle por código: por su
## vía natural cuando se puede lanzar el hechizo (Q6) y por sus botones (Pulsador3D.pulsar) en los demás, que es lo que separa «falla el
## agua» de «falla el disparador». Afirma lo que afirma AGUA_PUZLES.md §4 (E1, E3, E4, E8-bis, E9…) con las cifras medidas en el gemelo;
## lo que todavía no es contrato (los niveles de régimen de Q3 y Q4, que dependen del caudal) se imprime como AVISO para calibrarlo.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_agua.gd

const RUTA_LAB: String = "res://laboratorios/LabPuzlesAgua3D.tscn"

var lab: Node = null


func _escenario() -> void:
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")
	_ok("0 el laboratorio cuelga de la escena y ha montado sus diez puzles", lab != null and lab.get("_puzles") != null and (lab.get("_puzles") as Array).size() == 10, str((lab.get("_puzles") as Array).size()) if lab != null else "sin lab")
	if lab == null:
		return
	_ok("0 el mapa tiene las letras que el lab espera", (lab.get("_avisos") as Array).is_empty(), str(lab.get("_avisos")))
	await _q1_cuenca()
	await _q2_trasvase()
	await _q5_vaciar()
	await _q6_riego()
	await _q3_presa()
	await _q4_desvio()
	await _q8_nivel_justo()
	await _q7_rayo()
	await _q9_molino()
	await _q10_roca()


# ---------------------------------------------------------------------------------------------------------------------

func _fuera(celdas_con_agua: Array, x0: int, y0: int, x1: int, y1: int) -> float:
	## u³ de agua en la sala (x0..x1, y0..y1) FUERA de las casillas donde debería estar.
	var sim: AguaSim3D = Terreno3D.agua_sim
	var v: float = 0.0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := Vector2i(x, y)
			if not celdas_con_agua.has(c):
				v += sim.profundidad_casilla(c) * Terreno3D.casilla * Terreno3D.casilla
	return v


func _q1_cuenca() -> void:
	var q: Dictionary = lab.call("puzle", "Q1")
	var det: Node = q["detector"]
	var puerta: Node = q["puerta"]
	var cuenca: Array = [Vector2i(11, 4), Vector2i(12, 4), Vector2i(13, 4), Vector2i(11, 5), Vector2i(12, 5), Vector2i(13, 5)]
	var canal: Array = [Vector2i(12, 2), Vector2i(12, 3)]
	_ok("Q1.1 la cuenca empieza vacía y la puerta cerrada", Terreno3D.agua_sim.profundidad_casilla(Vector2i(12, 5)) == 0.0 and not bool(puerta.get("abierta")))
	_ok("Q1.2 la tinaja de Q1 existe", q.get("tinaja") != null)
	(lab.call("pulsador_en", Vector2i(10, 2)) as Node).call("pulsar")           # el botón de magia activa la tinaja
	# (Las lambdas de GDScript capturan los locales POR VALOR: lo que se mide va en un diccionario, que es una referencia.)
	var r: Dictionary = {"t_agua": -1.0, "t_puerta": -1.0}
	var t0: float = reloj.t
	await avanzar_vigilando(90.0, 0.5, func(t: float) -> void:
		if float(r["t_agua"]) < 0.0 and Terreno3D.agua_sim.profundidad_casilla(Vector2i(12, 4)) > 0.02:
			r["t_agua"] = t
		if float(r["t_puerta"]) < 0.0 and bool(puerta.get("abierta")):
			r["t_puerta"] = t
	)
	var t_agua: float = float(r["t_agua"])
	var t_puerta: float = float(r["t_puerta"])
	_ok("Q1.3 el agua de la tinaja LLEGA a la cuenca (E1)", t_agua > 0.0, "a los %.1f s" % t_agua)
	_ok("Q1.4 el nivel sube a 0,45 y la puerta se abre", t_puerta > 0.0, "a los %.1f s (detector %.2f)" % [t_puerta, float(det.get("profundidad"))])
	_aviso("Q1 tiempo hasta abrir la puerta (AGUA_PUZLES.md pide 8–30 s para un puzle de espera)", "%.1f s con %.2f u³/s, %.0f u³ y arranque %.0f s" % [t_puerta, LabPuzlesAgua3D.CAUDAL_TINAJA_LAB, LabPuzlesAgua3D.VOL_TINAJA_LAB, ReaccionesAgua3D.ARRANQUE_CAUCE])
	var fuera: float = _fuera(cuenca + canal + [Vector2i(13, 2)], 9, 1, 15, 7)
	var nivel: float = Terreno3D.agua_sim.profundidad_casilla(Vector2i(12, 5))
	_ok("Q1.5 la tinaja tiene fondo: la cuenca NO rebosa y nada se sale a la sala (E2)", fuera < 0.05 and nivel < Terreno3D.LECHO_AGUA - 0.05, "fuera %.3f u³, cuenca %.2f u" % [fuera, nivel])
	_ok("Q1.6 la tinaja se agota: el manantial queda apagado (VOL_TINAJA_LAB %.0f u³ → ≤ %.2f u en 6 casillas)" % [LabPuzlesAgua3D.VOL_TINAJA_LAB, LabPuzlesAgua3D.VOL_TINAJA_LAB / (6.0 * Terreno3D.casilla * Terreno3D.casilla)],
		Terreno3D.agua_sim.caudal_en(Vector2i(12, 2)) == 0.0 and Terreno3D.agua_sim.volumen_restante(Vector2i(12, 2)) == INF and nivel <= LabPuzlesAgua3D.VOL_TINAJA_LAB / (6.0 * Terreno3D.casilla * Terreno3D.casilla) + 0.05,
		"caudal %.2f, nivel %.2f" % [Terreno3D.agua_sim.caudal_en(Vector2i(12, 2)), nivel])
	volcar("q1", {"t_agua": t_agua, "t_puerta": t_puerta, "fuera": snappedf(fuera, 0.001), "dur": snappedf(reloj.t - t0, 0.1)})


func _q2_trasvase() -> void:
	var q: Dictionary = lab.call("puzle", "Q2")
	var k: Node = q["compuerta"]
	var puerta: Node = q["puerta"]
	var sim: AguaSim3D = Terreno3D.agua_sim
	var a: float = sim.profundidad_casilla(Vector2i(2, 2))
	var b: float = sim.profundidad_casilla(Vector2i(6, 3))
	_ok("Q2.1 A llena (≈ 0,9) y B vacía con la compuerta cerrada", a > 0.8 and b == 0.0, "A %.2f B %.2f" % [a, b])
	await avanzar_s(5.0)
	_ok("Q2.2 con la compuerta cerrada no pasa nada a B en 5 s", sim.profundidad_casilla(Vector2i(6, 3)) == 0.0)
	(lab.call("pulsador_en", Vector2i(2, 6)) as Node).call("pulsar")
	_ok("Q2.3 el botón abre la compuerta", bool(k.get("abierta")))
	await avanzar_s(20.0)
	a = sim.profundidad_casilla(Vector2i(2, 2))
	b = sim.profundidad_casilla(Vector2i(6, 3))
	_ok("Q2.4 vasos comunicantes: A y B se igualan (E3)", absf(a - b) < 0.08, "A %.2f B %.2f" % [a, b])
	_ok("Q2.5 B pasa de 0,35 y la puerta se abre", b >= 0.35 and bool(puerta.get("abierta")), "B %.2f" % b)
	var dentro: Array = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 2), Vector2i(6, 2), Vector2i(5, 3), Vector2i(6, 3)]
	var fuera: float = _fuera(dentro, 1, 1, 7, 7)
	_ok("Q2.6 nada se sale por el camino (el canal de cuenca no desborda)", fuera < 0.05, "fuera %.3f u³" % fuera)
	volcar("q2", {"a": snappedf(a, 0.01), "b": snappedf(b, 0.01), "fuera": snappedf(fuera, 0.001)})


func _q5_vaciar() -> void:
	var q: Dictionary = lab.call("puzle", "Q5")
	var k: Node = q["compuerta"]
	var puerta: Node = q["puerta"]
	var sim: AguaSim3D = Terreno3D.agua_sim
	_ok("Q5.1 el pasillo empieza inundado: se nada", sim.se_nada_en(Vector2i(20, 11)), "%.2f u" % sim.profundidad_casilla(Vector2i(20, 11)))
	(lab.call("pulsador_en", Vector2i(18, 10)) as Node).call("pulsar")
	_ok("Q5.2 el botón abre el desagüe", bool(k.get("abierta")))
	var r: Dictionary = {"t": -1.0}
	await avanzar_vigilando(30.0, 0.5, func(t: float) -> void:
		if float(r["t"]) < 0.0 and bool(puerta.get("abierta")):
			r["t"] = t
	)
	var t_puerta: float = float(r["t"])
	_ok("Q5.3 el pasillo baja de 0,25 y la puerta se abre", t_puerta > 0.0, "a los %.1f s (ahora %.2f u)" % [t_puerta, sim.profundidad_casilla(Vector2i(20, 11))])
	volcar("q5", {"t_puerta": t_puerta, "prof": snappedf(sim.profundidad_casilla(Vector2i(20, 11)), 0.01)})


func _q6_riego() -> void:
	var q: Dictionary = lab.call("puzle", "Q6")
	var puerta: Node = q["puerta"]
	var control: Node = q["control"]
	var pa: Node = q["pulsador_agua"]
	# Fuego al pulsador de agua: no debe abrir. (El jugador se coloca dos casillas al sur y dispara al norte.)
	_ok("Q6.1 fuego + flecha sale", lanzar_a_celda("fuego", ["flecha"], Vector2i(12, 19), Vector2i(12, 21)))
	await avanzar_s(3.0)
	_ok("Q6.2 el pulsador de AGUA no reacciona al fuego", int(pa.get("veces")) == 0 and not bool(puerta.get("abierta")))
	_ok("Q6.3 agua + flecha sale", lanzar_a_celda("agua", ["flecha"], Vector2i(12, 19), Vector2i(12, 21)))
	await avanzar_s(3.0)
	_ok("Q6.4 el agua lo activa y abre la puerta", int(pa.get("veces")) == 1 and bool(puerta.get("abierta")))
	_ok("Q6.5 el botón de control (cualquier magia) reacciona al fuego", lanzar_a_celda("fuego", ["flecha"], Vector2i(10, 19), Vector2i(10, 21)))
	await avanzar_s(3.0)
	_ok("Q6.6 … y cuenta una pulsación", int(control.get("veces")) >= 1, "veces %d" % int(control.get("veces")))
	# La placa: teletransportar al jugador encima.
	colocar_jugador(Vector2i(14, 19))
	await avanzar_s(0.5)
	_ok("Q6.7 la placa de presencia nota al jugador", int((lab.call("pulsador_en", Vector2i(14, 19)) as Node).get("veces")) == 1)
	colocar_jugador(Vector2i(12, 12))
	await avanzar_s(0.5)
	_ok("Q6.8 … y lo suelta al irse", not bool((lab.call("pulsador_en", Vector2i(14, 19)) as Node).get("activo")))


func _q3_presa() -> void:
	var q: Dictionary = lab.call("puzle", "Q3")
	var puerta: Node = q["puerta"]
	var sim: AguaSim3D = Terreno3D.agua_sim
	await avanzar_s(25.0)                                   # régimen del arroyo (el arranque del manantial son 18 s)
	var vado: float = sim.profundidad_casilla(Vector2i(18, 4))
	# Medido 15/10: 0,23 u con 0,6 u³/s (la puerta ya estaba abierta sin presa); 0,53 u con 1,5 u³/s.
	_ok("Q3.1 el arroyo corre: el vado en régimen pasa de 0,25 (si no, la presa no tiene sentido)", vado > 0.25 and not bool(puerta.get("abierta")), "%.2f u con %.2f u³/s" % [vado, LabPuzlesAgua3D.CAUDAL_ARROYO_Q3])
	(lab.call("pulsador_en", Vector2i(17, 6)) as Node).call("pulsar")
	_ok("Q3.2 el botón hiela la casilla de arriba", sim.casilla_helada(Vector2i(18, 2)))
	var r: Dictionary = {"t": -1.0}
	await avanzar_vigilando(12.0, 0.5, func(t: float) -> void:
		if float(r["t"]) < 0.0 and sim.profundidad_casilla(Vector2i(18, 4)) <= 0.25:
			r["t"] = t
	)
	var t_baja: float = float(r["t"])
	_ok("Q3.3 la presa corta el agua: el vado baja de 0,25 (E4)", t_baja > 0.0 and bool(puerta.get("abierta")), "a los %.1f s (ahora %.2f u)" % [t_baja, sim.profundidad_casilla(Vector2i(18, 4))])
	await avanzar_s(AguaSim3D.DURA_HIELO)
	_ok("Q3.4 el hielo del botón caduca a los DURA_HIELO s", not sim.casilla_helada(Vector2i(18, 2)))
	await avanzar_s(10.0)
	_ok("Q3.5 tras deshelar el arroyo vuelve a correr y la puerta se cierra (la ventana de la presa es DURA_HIELO)", sim.profundidad_casilla(Vector2i(18, 4)) > 0.25 and not bool(puerta.get("abierta")), "%.2f u" % sim.profundidad_casilla(Vector2i(18, 4)))


func _q4_desvio() -> void:
	var q: Dictionary = lab.call("puzle", "Q4")
	var k: Node = q["compuerta"]
	var puerta: Node = q["puerta"]
	var sim: AguaSim3D = Terreno3D.agua_sim
	var antes_e: float = sim.profundidad_casilla(Vector2i(6, 12))
	var antes_o: float = sim.profundidad_casilla(Vector2i(2, 12))
	_ok("Q4.1 con la compuerta abierta el agua escapa por el oeste y el este (fondo de saco) se queda bajo", antes_o > 0.02 and antes_e < 0.3 and not bool(puerta.get("abierta")), "este %.2f oeste %.2f" % [antes_e, antes_o])
	(lab.call("pulsador_en", Vector2i(2, 10)) as Node).call("pulsar")
	_ok("Q4.2 el botón cierra la compuerta del brazo oeste", not bool(k.get("abierta")))
	var r: Dictionary = {"t": -1.0}
	await avanzar_vigilando(30.0, 0.5, func(t: float) -> void:
		if float(r["t"]) < 0.0 and bool(puerta.get("abierta")):
			r["t"] = t
	)
	var despues_e: float = sim.profundidad_casilla(Vector2i(6, 12))
	var despues_o: float = sim.profundidad_casilla(Vector2i(2, 12))
	_ok("Q4.3 el caudal se embalsa en el este: sube claramente (E9)", despues_e > antes_e + 0.15, "este %.2f→%.2f oeste %.2f→%.2f" % [antes_e, despues_e, antes_o, despues_o])
	_ok("Q4.4 la rueda (≥ 0,4) arranca y abre la puerta", float(r["t"]) > 0.0, "a los %.1f s" % float(r["t"]))
	(lab.call("pulsador_en", Vector2i(2, 10)) as Node).call("pulsar")        # (rearme 2 s: ya ha pasado) reabrir
	_ok("Q4.5 el botón vuelve a abrir la compuerta", bool(k.get("abierta")))
	await avanzar_s(20.0)
	_aviso("Q4 con la compuerta reabierta el este baja a", "%.2f u (puerta %s)" % [sim.profundidad_casilla(Vector2i(6, 12)), "abierta" if bool(puerta.get("abierta")) else "cerrada"])
	volcar("q4", {"este": [snappedf(antes_e, 0.01), snappedf(despues_e, 0.01)], "t_puerta": r["t"]})


func _q8_nivel_justo() -> void:
	var q: Dictionary = lab.call("puzle", "Q8")
	var det: Node = q["detector"]
	var puerta: Node = q["puerta"]
	var sim: AguaSim3D = Terreno3D.agua_sim
	_ok("Q8.1 la tinaja de Q8 existe (la maqueta solo cablea una; el lab, las dos)", q.get("tinaja") != null)
	(q["tinaja"] as Node).call("on_spell_hit", LabPuzlesAgua3D._runa(["agua", "humedo"]), Vector3.ZERO)
	var r: Dictionary = {"abrio": -1.0, "cerro": -1.0}
	await avanzar_vigilando(70.0, 0.5, func(t: float) -> void:
		if float(r["abrio"]) < 0.0 and bool(puerta.get("abierta")):
			r["abrio"] = t
		if float(r["abrio"]) > 0.0 and float(r["cerro"]) < 0.0 and not bool(puerta.get("abierta")):
			r["cerro"] = t
	)
	var abrio: float = float(r["abrio"])
	var cerro: float = float(r["cerro"])
	_ok("Q8.2 al pasar por la banda 0,5 ± 0,08 la puerta se abre", abrio > 0.0, "a los %.1f s" % abrio)
	_ok("Q8.3 … y al pasarse de la banda (la tinaja sigue) se vuelve a cerrar", cerro > 0.0, "a los %.1f s (nivel %.2f)" % [cerro, float(det.get("profundidad"))])
	(lab.call("pulsador_en", Vector2i(2, 21)) as Node).call("pulsar")        # cerrar el grifo
	var p1: float = sim.profundidad_casilla(Vector2i(2, 18))
	await avanzar_s(6.0)
	var p2: float = sim.profundidad_casilla(Vector2i(2, 18))
	_ok("Q8.4 el botón cierra el grifo: el nivel deja de subir (apagar_fuente)", p2 <= p1 + 0.02, "%.2f → %.2f en 6 s" % [p1, p2])
	volcar("q8", {"abrio": abrio, "cerro": cerro, "tras_grifo": [snappedf(p1, 0.01), snappedf(p2, 0.01)]})


func _q7_rayo() -> void:
	var q: Dictionary = lab.call("puzle", "Q7")
	var puerta: Node = q["puerta"]
	var em: Node = q["emisor"]
	var nexo: Node = q["nexo"]
	_ok("Q7.1 hay fuente eléctrica, nexo y tótem de rayo", em != null and nexo != null and q.get("totem") != null)
	await avanzar_s(6.0)                                     # una descarga completa de la fuente (PERIODO 4 s) con el nexo seco
	_ok("Q7.2 con el nexo seco la corriente no llega al tótem: puerta cerrada", not bool(nexo.get("conduce")) and not bool(puerta.get("abierta")),
		"electrificadas %d" % (em.get("electrificada") as Array).size())
	_ok("Q7.3 agua + flecha a la pila (desde tres casillas al sur: dos glifos de flecha, alcance 3)", lanzar_a_celda("agua", ["flecha", "flecha"], Vector2i(20, 20), Vector2i(20, 23)))
	await avanzar_s(3.0)
	_ok("Q7.4 el nexo se moja y conduce", bool(nexo.get("conduce")) and Terreno3D.conduce(Vector2i(20, 20)), "mojado %.0f s" % float(nexo.get("mojado")))
	var r: Dictionary = {"t": -1.0}
	await avanzar_vigilando(12.0, 0.5, func(t: float) -> void:
		if float(r["t"]) < 0.0 and bool(puerta.get("abierta")):
			r["t"] = t
	)
	_ok("Q7.5 la fuente descarga por pozo → nexo → pozo, el tótem se activa y la puerta se abre", float(r["t"]) > 0.0, "a los %.1f s" % float(r["t"]))
	_ok("Q7.6 fuego + flecha a la pila", lanzar_a_celda("fuego", ["flecha", "flecha"], Vector2i(20, 20), Vector2i(20, 23)))
	await avanzar_s(3.0)
	_ok("Q7.7 el fuego seca el nexo: deja de conducir", not bool(nexo.get("conduce")))
	volcar("q7", {"t_puerta": r["t"]})


func _q9_molino() -> void:
	var q: Dictionary = lab.call("puzle", "Q9")
	var puerta: Node = q["puerta"]
	var k: Node = q["compuerta"]
	var mol: Node = q["molino"]
	_ok("Q9.1 el arroyo está seco y el molino quieto", float(mol.call("corriente")) < 0.05 and not bool(mol.get("activo")) and not bool(puerta.get("abierta")))
	# Vía 1: un hechizo de agua a la rueda la hace girar T_IMPULSO s y la puerta se abre y se vuelve a cerrar.
	_ok("Q9.2 agua + flecha a la rueda", lanzar_a_celda("agua", ["flecha"], Vector2i(28, 5), Vector2i(26, 5)))
	await avanzar_s(2.0)
	_ok("Q9.3 la rueda gira por el golpe y abre la puerta", bool(mol.get("activo")) and bool(puerta.get("abierta")), "vel %.2f" % float(mol.get("velocidad")))
	await avanzar_s(Molino3D.T_IMPULSO + 2.0)
	_ok("Q9.4 sin agua se para y la puerta se cierra", not bool(mol.get("activo")) and not bool(puerta.get("abierta")))
	# Vía 2: abrir la compuerta: el arroyo corre y la rueda gira mientras corra.
	(lab.call("pulsador_en", Vector2i(26, 6)) as Node).call("pulsar")
	_ok("Q9.5 el botón abre la compuerta", bool(k.get("abierta")))
	var r: Dictionary = {"t": -1.0}
	await avanzar_vigilando(40.0, 0.5, func(t: float) -> void:
		if float(r["t"]) < 0.0 and bool(puerta.get("abierta")):
			r["t"] = t
	)
	var sim9: AguaSim3D = Terreno3D.agua_sim
	var arroyo: Array = []
	for y in range(1, 8):
		arroyo.append(Vector2i(28, y))
	_ok("Q9.6 con el arroyo corriendo la rueda gira (corriente ≥ umbral) y la puerta se abre", float(r["t"]) > 0.0 and bool(mol.get("activo")),
		"a los %.1f s, corriente %.2f u/s; manantial %.2f u³/s en (28,1); profundidades %s; trocitos abiertos de (28,2): %d" % [float(r["t"]), float(mol.call("corriente")),
		sim9.caudal_en(Vector2i(28, 1)), str(profundidades(arroyo)), sim9._trozos_abiertos(Vector2i(28, 2)).size()])
	# Diagnóstico (15/10): dónde está el agua de (28,1) si no baja por el canal. Por trocito: cerrado / prof / fuente, y las casillas vecinas.
	for c in [Vector2i(28, 0), Vector2i(28, 1), Vector2i(28, 2), Vector2i(28, 3)]:
		var fila: String = ""
		for i in sim9._trozos(c):
			fila += "[%d %.2f %.2f] " % [sim9.cerrado[i], sim9.prof[i], sim9.fuente[i]]
		print("      %s: %s" % [c, fila])
	print("      vecinas de (28,1): oeste %.3f este %.3f · mojadas: %s %s · lado del mapa %d" % [sim9.profundidad_casilla(Vector2i(27, 1)), sim9.profundidad_casilla(Vector2i(29, 1)),
		str(sim9.casilla_mojada(Vector2i(27, 1))), str(sim9.casilla_mojada(Vector2i(29, 1))), Terreno3D.lado_del_mapa()])
	volcar("q9", {"t_puerta": r["t"], "corriente": snappedf(float(mol.call("corriente")), 0.01)})


func _q10_roca() -> void:
	var q: Dictionary = lab.call("puzle", "Q10")
	var puerta: Node = q["puerta"]
	var roca: Node = q["compuerta"]
	var barril: Node = q["barril"]
	var sim: AguaSim3D = Terreno3D.agua_sim
	var este: float = sim.profundidad_casilla(Vector2i(30, 12))
	_ok("Q10.1 la roca corta el curso: el este está seco y el oeste no rebosa (aliviadero)", este < 0.02 and sim.profundidad_casilla(Vector2i(26, 12)) < 0.95 and not bool(roca.get("abierta")), "este %.2f oeste %.2f" % [este, sim.profundidad_casilla(Vector2i(26, 12))])
	_ok("Q10.2 fuego + flecha al barril", lanzar_a_celda("fuego", ["flecha"], Vector2i(28, 11), Vector2i(28, 9)))
	await avanzar_s(1.0)                                    # la flecha tarda ~0,5 s en llegar
	_ok("Q10.3 el barril se enciende (mecha)", is_instance_valid(barril) and bool(barril.get("encendido")))
	await avanzar_s(Barril3D.T_MECHA + 1.0)
	_ok("Q10.4 explota y la roca se desmorona", is_instance_valid(barril) and bool(barril.get("explotado")) and bool(roca.get("abierta")))
	var r: Dictionary = {"t": -1.0}
	await avanzar_vigilando(30.0, 0.5, func(t: float) -> void:
		if float(r["t"]) < 0.0 and bool(puerta.get("abierta")):
			r["t"] = t
	)
	_ok("Q10.5 el agua llega al este (≥ 0,4) y la puerta se abre", float(r["t"]) > 0.0, "a los %.1f s (este %.2f)" % [float(r["t"]), sim.profundidad_casilla(Vector2i(30, 12))])
	volcar("q10", {"t_puerta": r["t"]})
