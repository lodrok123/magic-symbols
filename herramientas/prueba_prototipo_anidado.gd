extends "res://herramientas/escenario_base.gd"
## PROTOTIPO DE ANIDACIÓN Y COMBINACIÓN (23/11, sesión HECHIZOS) sin ventana, en `laboratorios/LabLibroRojo.tscn`.
##   godot --headless --fixed-fps 30 --path E:\magic-symbols --script res://herramientas/prueba_prototipo_anidado.gd
## Comprueba, lanzando de verdad con la página 1:
##   · al impactar: flecha de fuego contra un goblin → nace el hijo (barrera de tierra) donde choca, se cobra su tinta y hay una solidez nueva;
##   · al impactar sin nada delante: la flecha llega a su alcance y el hijo NO nace;
##   · al acabar: sin nada delante, el hijo nace donde acaba;
##   · a la vez: el hijo (flecha de agua) sale ≈ 0,17 s después, desde la mano;
##   · sin tinta: el hijo no sale y se avisa;
##   · la COMBINACIÓN (fuego + tierra en el mismo núcleo, libro avanzado) se lanza como MAGMA.

var _proto: Node = null
var _lanzados: Array = []


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _goblin(c: Vector2i) -> Combate3D:
	var p: Vector3 = _pos(c)
	var modelo: Pj3D = maqueta.call("_personaje", ["goblin_warrior_chibi"], p)
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.mirada = Vector3(1, 0, 0)
	g.health = 500.0
	g.vida_max = 500.0
	return g


func _pagina(elemento: String, glifos: Array, hijo: Dictionary, condicion: String) -> void:
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	var f: Dictionary = lanzador.pages[0]
	if hijo.is_empty():
		f.erase("hijo")
		f.erase("condicion")
	else:
		f["hijo"] = hijo
		f["condicion"] = condicion
	lanzador.cooldown_left[0] = 0.0
	lanzador.tinta.rellenar_barra()


func _hijo(elemento: String, glifos: Array) -> Dictionary:
	var gs: Array = ["", "", "", "", "", ""]
	for k in range(glifos.size()):
		gs[k] = glifos[k]
	return {"elemento": elemento, "glifos": gs}


func _lanzar(fila: int) -> bool:
	colocar_jugador(Vector2i(12, fila))
	await avanzar(2)
	return lanzador.lanzar_pagina_ya(0, jugador.position, Vector3(-1, 0, 0))


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar("res://laboratorios/LabLibroRojo.tscn", false)
	for _i in range(60):
		if paused:
			break
		await process_frame
	var lr: LibroRojo = root.find_child("LibroRojo", true, false) as LibroRojo
	_proto = root.find_child("PrototipoAnidado", true, false)
	_ok("0 el lab monta el prototipo de anidación", _proto != null and lr != null)
	if _proto == null:
		return
	lr.cerrar()
	Repertoire.activate_all()
	await avanzar(10)

	# 1 · Al impactar contra un goblin.
	var g: Combate3D = _goblin(Vector2i(10, 31))
	_pagina("fuego", ["flecha"], _hijo("tierra", ["barrera"]), "al_impactar")
	var sol0: int = lanzador._solideces_v2.size()
	var t0: float = lanzador.tinta.actual
	var salio: bool = await _lanzar(31)
	await avanzar_s(2.0)
	var u: Dictionary = _proto.get("ultimo")
	_ok("1 la flecha de fuego sale", salio)
	_ok("1 AL IMPACTAR: nace el hijo de TIERRA", String(u.get("elemento", "")) == "tierra" and String(u.get("condicion", "")) == "al_impactar", str(u))
	_ok("1 nace donde chocó (junto al goblin, no en la mano)", u.has("origen") and (u["origen"] as Vector3).distance_to(g.global_position) < Terreno3D.casilla * 1.6, str(u.get("origen")))
	var cobrado: float = float(u.get("tinta_antes", 0.0)) - float(u.get("tinta_despues", 0.0))
	_ok("1 se cobra su tinta AL NACER (medido en el momento del cobro; la barra se regenera después)", float(u.get("coste", 0.0)) > 0.0 and cobrado >= float(u.get("coste", 0.0)) * 0.9 - 0.01, "cobrado %.1f, coste %.1f (antes de lanzar había %.1f)" % [cobrado, float(u.get("coste", 0.0)), t0])
	_ok("1 y hay una solidez nueva (el muro de tierra)", lanzador._solideces_v2.size() > sol0 or int(u.get("casillas", 0)) > 0, "%d → %d" % [sol0, lanzador._solideces_v2.size()])
	_ok("1 al nacer sale el efecto común del hijo (GlifoComunVfx: aro que se cierra + runa del sello)", int(GlifoComunVfx.cuenta["hijo"]) >= 1, str(GlifoComunVfx.cuenta))
	g.queue_free()
	await avanzar(10)

	# 2 · Al impactar sin nada delante: no nace.
	_proto.set("ultimo", {})
	_pagina("fuego", ["flecha"], _hijo("tierra", ["barrera"]), "al_impactar")
	await _lanzar(35)
	await avanzar_s(2.5)
	u = _proto.get("ultimo")
	_ok("2 al impactar SIN nada delante: la flecha llega a su alcance y el hijo NO nace", bool(u.get("no_nacio", false)), str(u))

	# 3 · Al acabar: nace donde acaba.
	_proto.set("ultimo", {})
	_pagina("fuego", ["flecha"], _hijo("tierra", ["barrera"]), "al_acabar")
	await _lanzar(35)
	await avanzar_s(2.5)
	u = _proto.get("ultimo")
	_ok("3 AL ACABAR: nace donde acaba el primero (a su alcance)", String(u.get("elemento", "")) == "tierra" and String(u.get("condicion", "")) == "al_acabar", str(u))

	# 4 · A la vez: sale ≈ 0,17 s después, desde la mano.
	_proto.set("ultimo", {})
	_pagina("fuego", ["flecha"], _hijo("agua", ["flecha"]), "a_la_vez")
	var r0: float = reloj.t
	var r_hijo: Array = [-1.0]
	_proto.connect("hijo_lanzado", func(_i): r_hijo[0] = reloj.t, CONNECT_ONE_SHOT)
	await _lanzar(39)
	await avanzar_s(1.0)
	u = _proto.get("ultimo")
	_ok("4 A LA VEZ: sale el hijo de agua", String(u.get("elemento", "")) == "agua" and String(u.get("condicion", "")) == "a_la_vez", str(u))
	_ok("4 ≈ 0,17 s después del primero, y desde la mano", r_hijo[0] > 0.0 and r_hijo[0] - r0 < 0.6 and (u.get("origen", Vector3.ZERO) as Vector3).distance_to(jugador.global_position) < Terreno3D.casilla, "%.2f s" % (r_hijo[0] - r0))

	# 5 · Sin tinta para el hijo.
	_proto.set("ultimo", {})
	_pagina("fuego", ["flecha"], _hijo("agua", ["flecha", "flecha", "flecha"]), "a_la_vez")
	await _lanzar(39)
	lanzador.tinta.actual = 0.0
	lanzador.tinta.frascos = 0
	await avanzar_s(1.0)
	u = _proto.get("ultimo")
	_ok("5 sin tinta, el segundo círculo no sale y se avisa", bool(u.get("sin_tinta", false)), str(u))
	lanzador.tinta.rellenar_barra()

	# 6 · LA COMBINACIÓN: fuego + tierra en el mismo núcleo = MAGMA.
	var libro0: String = Repertoire.libro
	Repertoire.libro = "avanzado"
	_pagina("fuego", ["flecha"], {}, "")
	lanzador.place_element("tierra")
	_ok("6 la página tiene dos sellos (fuego + tierra)", lanzador._gesture_name_of(lanzador.pages[0]["element2"]) == "tierra")
	_lanzados.clear()
	lanzador.lanzado.connect(func(el, _f, _n): _lanzados.append(el), CONNECT_ONE_SHOT)
	lanzador.cooldown_left[0] = 0.0
	await _lanzar(43)
	await avanzar(5)
	_ok("6 la COMBINACIÓN se lanza como MAGMA", _lanzados.has("magma"), str(_lanzados))
	Repertoire.libro = libro0
	lanzador.clear_sequence()
	maqueta.queue_free()
	await avanzar(3)
