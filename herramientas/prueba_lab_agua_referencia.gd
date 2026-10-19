extends SceneTree
## La escena de referencia del lab del agua (19/10, PLAN_TRES_FRENTES §3), sin ventana: pozo que se llena por volumen, cascada de la escalera y corriente
## del río, con las medidas que enseña en pantalla. Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_lab_agua_referencia.gd
var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _esperar(lab: Node3D, segundos: float) -> void:
	var t: float = 0.0
	while t < segundos:
		await physics_frame
		t += 1.0 / float(Engine.physics_ticks_per_second)


func _initialize() -> void:
	await process_frame
	var lab: Node3D = load("res://laboratorios/LabAgua3D.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	var S: float = 2.3
	var esperada: float = 4.0 * S * S * 1.15
	var r0: Dictionary = lab.referencia()
	_ok("1 el pozo cabe 4 casillas × 2,3² × 1 nivel (1,15 u) = %.2f u³ y rebosa a Y 0" % esperada, absf(float(r0["pozo"]["capacidad"]) - esperada) < 0.05 and absf(float(r0["pozo"]["rebose"])) < 1.0e-3, str(r0["pozo"]))
	_ok("1 el texto de pantalla lleva las tres situaciones", lab.texto_referencia().contains("POZO") and lab.texto_referencia().contains("CASCADA") and lab.texto_referencia().contains("RÍO"))
	# Cascada y río con el manantial de la escalera abierto.
	await _esperar(lab, 8.0)
	var r1: Dictionary = lab.referencia()
	print("      cascada %s · río %s" % [str(r1["cascada"]), str(r1["rio"])])
	_ok("2 la escalera cae: caída máxima ≥ UMBRAL_CAIDA (%.2f)" % float(r1["cascada"]["caida_max"]), float(r1["cascada"]["caida_max"]) >= AguaSim3D.UMBRAL_CAIDA)
	_ok("2 …y al menos una casilla de la escalera lo cuenta", int(r1["cascada"]["casillas"]) >= 1)
	_ok("3 el río lleva corriente (máx %.3f u/s)" % float(r1["rio"]["max"]), float(r1["rio"]["max"]) > 0.0)
	# Pozo: se apaga el manantial de la escalera para que solo cuente el del pozo; se mide el tiempo real contra el previsto por volumen.
	lab._manantial_abierto = false
	for y in range(lab.ALTO):
		for x in range(lab.ANCHO):
			if lab.MAPA[y][x] == "M":
				lab.agua.fuente_en(Vector2i(x, y), 0.0)
	lab._empezar()
	lab._manantial_abierto = false
	for y in range(lab.ALTO):
		for x in range(lab.ANCHO):
			if lab.MAPA[y][x] == "M":
				lab.agua.fuente_en(Vector2i(x, y), 0.0)
	await _esperar(lab, 0.2)
	lab.poner_pozo(true)
	var prevision: float = float(lab.referencia()["pozo"]["prevision"])
	_ok("4 al abrir el pozo la previsión es (capacidad − volumen) / %.1f = %.1f s" % [lab.CAUDAL_POZO, prevision], absf(prevision - esperada / lab.CAUDAL_POZO) < 1.5, "%.2f" % prevision)
	await _esperar(lab, prevision * 0.5)
	var f50: float = float(lab.referencia()["pozo"]["fraccion"])
	_ok("4 a mitad del tiempo previsto va por la mitad (%.0f %%)" % (f50 * 100.0), f50 > 0.42 and f50 < 0.58)
	await _esperar(lab, prevision * 0.8)
	var rf: Dictionary = lab.referencia()["pozo"]
	print("      pozo %s" % str(rf))
	_ok("4 se llena (tardó %.1f s de %.1f previstos, ±15 %%)" % [float(rf["tardo"]), prevision], float(rf["tardo"]) > 0.0 and absf(float(rf["tardo"]) - prevision) < prevision * 0.15)
	lab.poner_pozo(false)
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
