extends SceneTree
## B9b · BARRERA LEGIBLE (22/11, docs/PLAN_HECHIZOS_2026-11-22.md §11; H14 §3) sin ventana. Lo escribe la sesión HECHIZOS.
##   godot --headless --fixed-fps 30 --path E:\magic-symbols --script res://herramientas/prueba_barrera_legible.gd
## Comprueba: el rótulo «para… · no para…» sale de la tabla de contacto de COMBATE (`Contacto`) para cada elemento; qué hechizos lo enseñan (solidez > 0); la regla del tope
## de barreras compartida con `_materializar`; `Lanzador3D.barrera_que_se_ira` (la más antigua viva, solo con el tope lleno, sin disolver nada); y que los rótulos se pintan.

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _rune(elem: String) -> RuneData:
	var en: Dictionary = {"fuego": "fire", "agua": "water", "tierra": "earth", "viento": "wind", "hielo": "ice"}
	return load("res://nucleo/%s_rune.tres" % String(en.get(elem, elem))) as RuneData


func _initialize() -> void:
	await process_frame
	# 1 · El texto sale de la tabla de contacto.
	var casos: Dictionary = {
		"fuego": "para flechas y agua · no para fuego y piedras",
		"agua": "para flechas y fuego · no para agua y piedras",
		"tierra": "para todos los proyectiles",
		"viento": "para flechas y agua · no para fuego y piedras",
		"hielo": "para todos los proyectiles",                  # sin fila en la tabla: lo sólido de siempre
	}
	for el in casos:
		var t: String = PrevisionReaccion3D.texto_barrera(el)
		_ok("1 %s: «%s»" % [el, casos[el]], t == String(casos[el]), t)
	# Coherencia con la tabla, fila a fila (si COMBATE cambia una celda, el texto cambia con ella y esta comprobación lo sigue).
	var coherente: bool = true
	for el in ["fuego", "agua", "tierra", "viento"]:
		var t2: String = PrevisionReaccion3D.texto_barrera(el)
		for par in PrevisionReaccion3D.PROYECTILES_RESUMEN:
			var protege: bool = Contacto.protege(Contacto.accion(el, String(par[0])))
			var parte_si: String = t2.split(" · no para ")[0]
			if protege != (t2 == "para todos los proyectiles" or parte_si.contains(String(par[1]))):
				coherente = false
	_ok("1 cada nombre está en «para» si y solo si Contacto dice que protege", coherente)

	# 2 · Qué hechizos lo enseñan y cuáles cuentan para el tope.
	var esfera: Hechizo = Hechizo.construir(_rune("fuego"), {})
	var bar_fuego: Hechizo = Hechizo.construir(_rune("fuego"), {"barrera": 1})
	var bar_tierra: Hechizo = Hechizo.construir(_rune("tierra"), {"barrera": 1})
	_ok("2 la bola de fuego sola no es sólida (sin rótulo)", esfera.solidez == 0.0)
	_ok("2 fuego + ᛜ y tierra + ᛜ son sólidos (con rótulo)", bar_fuego.solidez > 0.0 and bar_tierra.solidez > 0.0, "%s / %s" % [bar_fuego.solidez, bar_tierra.solidez])
	_ok("2 la regla del tope es la de siempre: sólido, nace donde apuntas y no es hijo",
		Lanzador3D.cuenta_para_tope_barreras(bar_tierra) == (bar_tierra.solidez > 0.0 and bar_tierra.en_punto and bar_tierra.profundidad == 0)
		and Lanzador3D.cuenta_para_tope_barreras(bar_fuego) == (bar_fuego.solidez > 0.0 and bar_fuego.en_punto and bar_fuego.profundidad == 0)
		and not Lanzador3D.cuenta_para_tope_barreras(esfera) and not Lanzador3D.cuenta_para_tope_barreras(null),
		"tierra en_punto=%s · fuego en_punto=%s" % [bar_tierra.en_punto, bar_fuego.en_punto])

	# 3 · La barrera que se irá.
	var lz := Lanzador3D.new()
	var nodos: Array = []
	for i in range(3):
		var n := Node3D.new()
		root.add_child(n)
		nodos.append(n)
	lz.barreras_vivas = [{"linaje": 1, "pos": Vector3(1, 0, 0), "vivo": weakref(nodos[0])}, {"linaje": 2, "pos": Vector3(2, 0, 0), "vivo": weakref(nodos[1])}]
	_ok("3 con 2 barreras vivas (tope %d) aún cabe: ninguna se irá" % Lanzador3D.MAX_BARRERAS_VIVAS, lz.barrera_que_se_ira().is_empty())
	lz.barreras_vivas.append({"linaje": 3, "pos": Vector3(3, 0, 0), "vivo": weakref(nodos[2])})
	var vieja: Dictionary = lz.barrera_que_se_ira()
	_ok("3 con 3 vivas se irá la más antigua (la de (1,0,0))", not vieja.is_empty() and int(vieja["linaje"]) == 1 and (vieja["pos"] as Vector3) == Vector3(1, 0, 0))
	_ok("3 y mirar no cambia la lista ni disuelve nada", lz.barreras_vivas.size() == 3 and is_instance_valid(nodos[0]))
	(nodos[0] as Node).free()
	_ok("3 si la más antigua ya murió sola, quedan 2 vivas: ninguna se irá", lz.barrera_que_se_ira().is_empty())

	# 4 · Los rótulos se pintan y se esconden.
	var pv := PrevisionReaccion3D.new()
	root.add_child(pv)
	await process_frame
	pv.mostrar_barrera(Vector3(5, 0, 5), PrevisionReaccion3D.texto_barrera("fuego"))
	_ok("4 rótulo «para…» visible con el texto y por debajo del de la tinta", pv.rotulo_barrera != null and pv.rotulo_barrera.visible and pv.rotulo_barrera.text.begins_with("para flechas")
		and PrevisionReaccion3D.ALTO_BARRERA < PrevisionReaccion3D.ALTO_TINTA)
	pv.mostrar_barrera(Vector3.ZERO, "")
	_ok("4 con texto vacío se esconde", not pv.rotulo_barrera.visible)
	pv.mostrar_se_ira(Vector3(1, 0, 0))
	_ok("4 «se disolverá» visible sobre la barrera vieja", pv.rotulo_se_ira != null and pv.rotulo_se_ira.visible and pv.rotulo_se_ira.text == PrevisionReaccion3D.TEXTO_SE_IRA
		and is_equal_approx(pv.rotulo_se_ira.global_position.y, PrevisionReaccion3D.ALTO_SE_IRA))
	pv.mostrar_se_ira(Vector3.INF)
	_ok("4 con Vector3.INF se esconde", not pv.rotulo_se_ira.visible)
	await process_frame
	_ok("4 sin modo de lanzar, el _process los deja escondidos", not pv.rotulo_barrera.visible and not pv.rotulo_se_ira.visible)
	_ok("4 (22/11, Pablo: «prefiero la silueta») el rótulo «para…» no sale al apuntar", not PrevisionReaccion3D.ROTULO_BARRERA_AL_APUNTAR)

	pv.queue_free()
	for n in nodos:
		if is_instance_valid(n):
			(n as Node).queue_free()
	lz.free()
	await process_frame
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
