extends "res://herramientas/escenario_base.gd"
## PRIMERA TANDA DE CONSUMIBLES (10/11, Juego; docs/PROPUESTA_CONSUMIBLES.md §10): los 16 aprobados por Pablo, con la escena de verdad (PruebaBosque, el trozo llano
## del campamento sur, filas 18–21) y la jugadora real.
##   1 · datos: los 16 están en la tabla con su uso, cada uno tiene receta, los lanzables no entran en la R y los bebibles sí
##   2 · pociones: menor 40, normal 80, mayor 120 + regenera 2/s 10 s al terminar de beber
##   3 · antídotos: el frío, el calor y el rayo de verdad (`aplicar_estado`) se quitan y luego no vuelven a entrar; el veneno, como siempre
##   4 · elixires mixtos: protegen de dos estados y NO quitan el que ya hay
##   5 · rueda: el primer lanzable entra solo en un hueco libre; poner en un hueco ocupado intercambia; quitar; se guarda con la partida
##   6 · lanzables: la G (evento de teclado de verdad) lanza el elegido; bomba de resina prende un seto; bola helada hiela agua; bulbo de luz ilumina;
##       fruto chispa electrifica y alcanza a la jugadora si cae a su lado (y con la savia aislante, no)
##   7 · pigmentos: cargar uno, lanzar un hechizo de su elemento lo gasta (y de otro, no)
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_consumibles_tanda.gd

const TANDA: Dictionary = {
	"pocion": "equipar", "pocion_grande": "equipar", "pocion_mayor": "equipar",
	"antidoto": "equipar", "abrigo": "equipar", "frescor": "equipar", "savia_aislante": "equipar",
	"elixir_filtro": "equipar", "elixir_templado": "equipar",
	"pigmento_carmesi": "pigmento", "pigmento_rocio": "pigmento", "pigmento_ocre": "pigmento", "pigmento_escarcha": "pigmento",
	"pigmento_ambar": "pigmento", "pigmento_musgo": "pigmento", "pigmento_eco": "pigmento",
	"bulbo_luz": "lanzar", "bomba_resina": "lanzar", "bola_helada": "lanzar", "fruto_chispa": "lanzar",
}

var _fx: Vfx3D = null
var _j: Jugador3D = null
var _c: Consumibles = null


func _reactivo(tipo: String, c: Vector2i) -> Reactivo3D:
	var r := Reactivo3D.new()
	r.name = "r_%s_%d_%d" % [tipo, c.x, c.y]
	r.preparar(tipo, c, "", _fx, null)
	r.position = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	maqueta.add_child(r)
	return r


## La primera casilla de agua del mapa a nivel 0 (para la bola helada).
func _agua() -> Vector2i:
	for y in range(Terreno3D.mapa.size()):
		for x in range(Terreno3D.mapa[y].length()):
			var c := Vector2i(x, y)
			if Terreno3D.es_agua(c) and Terreno3D.altura_en(c) == 0 and not Terreno3D.helada(c):
				return c
	return Vector2i(-1, -1)


## Lanza `id` (lo mete en la bolsa y lo elige en la rueda) hacia la casilla `c`, de pie a `atras` casillas al oeste. Espera a que caiga. Devuelve el resultado.
func _lanzar(id: String, c: Vector2i, desde: Vector2i) -> Dictionary:
	Estado.i().agregar(id, 1)
	Estado.i().poner_en_rueda(id, 0)
	Estado.i().elegir_hueco(0)
	colocar_jugador(desde)
	await avanzar(2)
	var p: Lanzable3D = _j.lanzar_objeto(Terreno3D.centro_de(c, Terreno3D.y_pies(c)))
	if p == null:
		return {"efecto": "no salió"}
	var res: Array = [{}]
	p.aterrizo.connect(func(r: Dictionary) -> void: res[0] = r)
	var t: float = 0.0
	while (res[0] as Dictionary).is_empty() and t < 4.0:
		t += await avanzar_s(0.1)
	return res[0] if not (res[0] as Dictionary).is_empty() else {"efecto": "no cayó en 4 s"}


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	Consumibles.limpiar_protecciones()
	_datos()
	await cargar()
	if maqueta == null or jugador == null or lanzador == null:
		return
	_fx = maqueta.get("_fx") as Vfx3D
	_j = jugador as Jugador3D
	# Los consumibles del HUD (los que usa Q): la poción mayor pide a ESOS que regeneren al terminar de beber.
	var hud: Node = _j.get("hud_eow") as Node
	_c = hud.get("consumibles") as Consumibles if hud != null and hud.get("consumibles") is Consumibles else Consumibles.new()
	_c.jugador = _j
	_j.vida = 50.0
	await _pociones()
	await _antidotos()
	await _mixtos()
	_rueda()
	await _lanzables()
	await _pigmentos()


func _datos() -> void:
	var mal: Array = []
	for id in TANDA:
		if String(BD.objeto(String(id)).get("uso", "")) != String(TANDA[id]):
			mal.append(id)
	_ok("1 los 16 de la tanda (y la poción grande y las tres de antes) están en la tabla con su uso", mal.is_empty(), str(mal))
	var sin_receta: Array = []
	for id in TANDA:
		var hay: bool = false
		for r in BD.recetas():
			if String(BD.receta(String(r)).get("da", "")).begins_with(String(id) + ":"):
				hay = true
		if not hay:
			sin_receta.append(id)
	_ok("1 todos tienen receta", sin_receta.is_empty(), str(sin_receta))
	_ok("1 los cuatro lanzables no entran en la R; los bebibles nuevos sí", Objetos.LANZABLES.size() == 4 and not Objetos.CONSUMIBLES.has("bomba_resina")
		and Objetos.CONSUMIBLES.has("pocion_mayor") and Objetos.CONSUMIBLES.has("savia_aislante") and Objetos.CONSUMIBLES.has("elixir_filtro"), str(Objetos.LANZABLES))
	_ok("1 en la bolsa, los lanzables van con las pociones", Objetos.categoria("bola_helada") == "pociones")


func _pociones() -> void:
	var e: Estado = Estado.i()
	e.vida_max = 300.0                       # que la cura no choque con el tope
	e.items = {"pocion": 1, "pocion_grande": 1, "pocion_mayor": 1}
	var curas: Array = []
	for id in ["pocion", "pocion_grande", "pocion_mayor"]:
		_j.vida = 10.0
		_c.usar(id)
		await avanzar_s(Jugador3D.T_BEBER + 0.3)
		curas.append(roundi(_j.vida - 10.0))
	_ok("2 la menor cura 40, la normal 80 y la mayor 120", curas[0] == 40 and curas[1] == 80 and curas[2] >= 120, str(curas))
	_ok("2 la mayor deja regenerando 2/s durante 10 s", _c.regen_activa() and is_equal_approx(_c.regen_tasa, 2.0) and _c.regen_t > 8.0, "tasa %.1f · %.1f s" % [_c.regen_tasa, _c.regen_t])
	var antes: float = _j.vida
	for _i in range(20):
		_c.actualizar(0.5)
	_ok("2 y en 10 s suma 20 de vida", absf(_j.vida - antes - 20.0) < 0.6, "%.1f" % (_j.vida - antes))
	e.vida_max = Estado.VIDA_BASE


func _antidotos() -> void:
	var e: Estado = Estado.i()
	Consumibles.limpiar_protecciones()
	_j.vida = 100.0
	e.items = {"abrigo": 1, "frescor": 1, "savia_aislante": 1, "antidoto": 1}
	_ok("3 el hielo la deja ralentizada", _j.aplicar_estado("hielo", 3.0) == "ralentizada" and _j.tiene_estado("frio"))
	_ok("3 la brasa embotellada lo quita y protege del frío", _c.usar("abrigo") and not _j.tiene_estado("frio") and Consumibles.protegido("frio") and is_equal_approx(_j.mult_velocidad_estado(), 1.0))
	_ok("3 con la brasa puesta, el hielo ya no la ralentiza", _j.aplicar_estado("hielo", 3.0) == "")
	_ok("3 el fuego la quema", _j.aplicar_estado("fuego", 3.0) == "quemada" and _j.esta_quemada())
	_ok("3 el frasco de frescor quita la quemadura y protege del calor", _c.usar("frescor") and not _j.esta_quemada() and _j.aplicar_estado("fuego", 3.0) == "")
	var v: float = _j.vida
	_ok("3 con el frescor, la llama propia no daña", _j.dano_ambiental(5.0, "fuego") == 0.0 and is_equal_approx(_j.vida, v))
	_ok("3 el rayo la aturde", _j.aplicar_estado("rayo", 0.6) == "aturdida" and _j.tiene_estado("rayo"))
	_ok("3 la savia aislante lo quita y protege del rayo (también del suelo electrificado)", _c.usar("savia_aislante") and not _j.tiene_estado("rayo")
		and _j.aplicar_estado("rayo", 0.6) == "" and _j.dano_ambiental(2.0, "rayo") == 0.0)
	_j.envenenar(2.0, 5.0)
	_ok("3 el antídoto quita el veneno y protege 90 s", _c.usar("antidoto") and not _j.tiene_estado("veneno") and is_equal_approx(Consumibles.tiempo_proteccion("veneno"), 90.0))
	Consumibles.limpiar_protecciones()
	await avanzar(2)


func _mixtos() -> void:
	var e: Estado = Estado.i()
	Consumibles.limpiar_protecciones()
	e.items = {"elixir_filtro": 1, "elixir_templado": 1}
	_j.envenenar(2.0, 5.0)
	_ok("4 el elixir del filtro protege del veneno y del rayo 60 s", _c.usar("elixir_filtro") and Consumibles.protegido("veneno") and Consumibles.protegido("rayo")
		and is_equal_approx(Consumibles.tiempo_proteccion("rayo"), 60.0))
	_ok("4 pero NO quita el veneno que ya tenía (eso es del antídoto)", _j.tiene_estado("veneno"))
	_ok("4 y el rayo ya no la aturde", _j.aplicar_estado("rayo", 0.6) == "")
	_ok("4 el elixir templado protege del frío y del calor a la vez", _c.usar("elixir_templado") and Consumibles.protegido("frio") and Consumibles.protegido("calor")
		and _j.aplicar_estado("hielo", 2.0) == "" and _j.aplicar_estado("fuego", 2.0) == "")
	_ok("4 con las dos protecciones puestas, otro elixir no se gasta", not _c.usar("elixir_templado") or e.cuenta("elixir_templado") == 0)
	_j.curar_estado("veneno")
	Consumibles.limpiar_protecciones()
	await avanzar(2)


func _rueda() -> void:
	Estado.nuevo()
	var e: Estado = Estado.i()
	e.agregar("bulbo_luz", 2)
	_ok("5 el primer lanzable entra solo en el primer hueco y queda elegido", e.rueda[0] == "bulbo_luz" and e.lanzable_elegido() == "bulbo_luz", str(e.rueda))
	e.agregar("bomba_resina", 1)
	_ok("5 el segundo, en el siguiente hueco libre", e.rueda[1] == "bomba_resina", str(e.rueda))
	e.quitar_de_rueda("bomba_resina")
	e.agregar("bomba_resina", 1)
	_ok("5 si la jugadora lo quitó, coger más no lo vuelve a poner", not e.rueda.has("bomba_resina"), str(e.rueda))
	e.poner_en_rueda("bomba_resina", 4)
	e.poner_en_rueda("bomba_resina", 0)
	_ok("5 ponerlo en un hueco ocupado los intercambia; un objeto, un hueco", e.rueda[0] == "bomba_resina" and e.rueda[4] == "bulbo_luz" and e.rueda.count("bomba_resina") == 1, str(e.rueda))
	_ok("5 solo entran lanzables", not e.poner_en_rueda("pocion", 2) and e.rueda[2] == "")
	e.quitar("bomba_resina", 2)
	_ok("5 el hueco recuerda el objeto aunque se acabe", e.rueda[0] == "bomba_resina" and e.cuenta("bomba_resina") == 0)
	var d: Dictionary = e.a_dic()
	var g := Estado.new()
	g.desde_dic(d)
	_ok("5 la rueda viaja con la partida (huecos, elegido y vistos)", g.rueda == e.rueda and g.rueda_elegido == e.rueda_elegido and g.rueda_vistos.has("bulbo_luz"))
	Estado.nuevo()


func _lanzables() -> void:
	var e: Estado = Estado.i()
	# La G, con un evento de teclado de verdad: lanza el elegido y gasta una unidad.
	e.agregar("bulbo_luz", 2)
	colocar_jugador(Vector2i(3, 19))
	await avanzar(2)
	var ev := InputEventKey.new()
	ev.keycode = KEY_G
	ev.physical_keycode = KEY_G
	ev.pressed = true
	_j._unhandled_input(ev)
	_ok("6 la G lanza el elegido de la rueda y gasta una unidad", e.cuenta("bulbo_luz") == 1, "quedan %d" % e.cuenta("bulbo_luz"))
	await avanzar_s(1.5)
	# Bulbo de luz: ilumina la casilla donde cae.
	var c_luz := Vector2i(7, 19)
	var r_luz: Dictionary = await _lanzar("bulbo_luz", c_luz, Vector2i(3, 19))
	_ok("6 el bulbo de luz ilumina donde cae", r_luz.get("efecto") == "luz" and Mundo3D.iluminada(c_luz), str(r_luz))
	# Bomba de resina: prende un seto.
	var c_seto := Vector2i(10, 19)
	var seto: Reactivo3D = _reactivo("seto", c_seto)
	await avanzar(3)
	var r_fuego: Dictionary = await _lanzar("bomba_resina", c_seto, Vector2i(6, 19))
	await avanzar_s(0.5)
	_ok("6 la bomba de resina prende el seto de la casilla", int(r_fuego.get("objetos", 0)) >= 1 and is_instance_valid(seto) and seto.estado != Reactivo3D.EstadoObj.SANO,
		"%s · estado %s" % [str(r_fuego), str(seto.estado) if is_instance_valid(seto) else "liberado"])
	# Bola helada: hiela el agua.
	var c_agua: Vector2i = _agua()
	if c_agua.x >= 0:
		var desde: Vector2i = Vector2i(-1, -1)
		for k in range(1, 5):
			for dir in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var cand: Vector2i = c_agua + (dir as Vector2i) * k
				if desde.x < 0 and Terreno3D.en_mapa(cand) and not Terreno3D.es_agua(cand) and not Terreno3D.bloqueada(cand) and Terreno3D.altura_en(cand) == 0:
					desde = cand
		var r_hielo: Dictionary = await _lanzar("bola_helada", c_agua, desde)
		await avanzar(3)
		_ok("6 la bola helada hiela la casilla de agua donde cae", r_hielo.get("efecto") == "hielo" and Terreno3D.helada(c_agua), "%s en %s" % [str(r_hielo), str(c_agua)])
	else:
		_aviso("6 bola helada: el mapa no tiene agua a nivel 0")
	# Fruto chispa: a sus pies alcanza a la jugadora; con la savia aislante, no.
	Consumibles.limpiar_protecciones()
	_j.vida = 100.0
	var c_chispa := Vector2i(4, 20)
	var r_rayo: Dictionary = await _lanzar("fruto_chispa", c_chispa, Vector2i(3, 20))
	_ok("6 el fruto chispa que cae a su lado también la alcanza", r_rayo.get("efecto") == "rayo" and bool(r_rayo.get("jugadora", false)) and _j.vida < 100.0, "%s · vida %.1f" % [str(r_rayo), _j.vida])
	await avanzar_s(1.0)
	e.agregar("savia_aislante", 1)
	_c.usar("savia_aislante")
	_j.vida = 100.0
	await _lanzar("fruto_chispa", c_chispa, Vector2i(3, 20))
	_ok("6 con la savia aislante, el fruto chispa no le hace nada", is_equal_approx(_j.vida, 100.0), "vida %.1f" % _j.vida)
	Consumibles.limpiar_protecciones()
	e.items.erase("bulbo_luz")
	_ok("6 sin nada que lanzar, la G no lanza ni rompe", _j.lanzar_objeto(_j.position + Vector3(3, 0, 0)) == null)


func _pigmentos() -> void:
	var e: Estado = Estado.i()
	var t: Tinta = _j.tinta
	t.rellenar()
	e.agregar("pigmento_carmesi", 1)
	_ok("7 cargar el carmesí lo deja cargado en la tinta del jugador", Sintesis.aplicar_pigmento("pigmento_carmesi", t) and t.pigmento == "resina_carmesi" and t.pigmento_cargado())
	colocar_jugador(Vector2i(3, 18))
	await avanzar(2)
	lanzar("agua", ["flecha"], Vector3.RIGHT)
	await avanzar_s(1.2)
	_ok("7 un hechizo de agua no gasta la carga de fuego", t.pigmento == "resina_carmesi")
	lanzador.cooldown_left[0] = 0.0
	lanzar("fuego", ["flecha"], Vector3.RIGHT)
	await avanzar_s(1.2)
	_ok("7 el de fuego sí la gasta", t.pigmento == Tinta.PIGMENTO_BASE and not t.pigmento_cargado())
