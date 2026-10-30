extends SceneTree
## H6 segunda entrega: los doce objetos que aún decidían por `tags.has(...)` ahora deciden por PROPIEDADES (Materia). Para cada uno, un elemento de laboratorio SIN etiquetas
## que provoca su reacción y otro con las propiedades «equivocadas» que no. Y la `Materia.cumple` de la compuerta, y las previsiones del lanzador con elementos sin etiquetas.
##   godot --headless --path . --script res://herramientas/prueba_materia_reactivos_2.gd

const MundoFalso = preload("res://herramientas/prueba_puzle.gd").MundoFalso

var _fallos: int = 0
var _m: MundoFalso = null
var _x: float = 100.0
var _fx: Vfx3D = null


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


## Un elemento de laboratorio SOLO con propiedades: sin una etiqueta.
func _lab(campos: Dictionary, estado: String = "solido", empuje: float = 0.0) -> RuneData:
	var r := RuneData.new()
	var mods: Dictionary = {}
	for k in campos:
		mods[k] = {"op": "fija", "valor": campos[k]}
	r.modificadores = mods
	r.estado = estado
	r.empuje = empuje
	return r


func _h(r: RuneData) -> Hechizo:
	return Hechizo.construir(r, {})


func _poner(n: Node) -> void:
	_m._props.add_child(n)


func _initialize() -> void:
	await process_frame
	_m = MundoFalso.new()
	_m._props = Node3D.new()
	_m.add_child(_m._props)
	root.add_child(_m)
	_fx = Vfx3D.new()
	root.add_child(_fx)
	Lanzador3D.configurar(_m)
	for y in range(8):
		for x in range(8):
			if _m._mapa[y][x] == "#":
				_m._bloqueadas[Vector2i(x, y)] = true
	Lanzador3D.montar_agua_sim()
	await _objetos()
	_cumple()
	await _material()
	_lanzador()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _cumple() -> void:
	var calor: Dictionary = Materia.de(_lab({"temperatura": 1.0}))
	var hielo: Dictionary = Materia.de(load("res://nucleo/ice_rune.tres") as RuneData)
	var viento: Dictionary = Materia.de(_lab({}, "gas", 1.0))
	var tierra: Dictionary = Materia.de(_lab({"densidad": 2.0}))
	_ok("cumple: calor/agua/frio/rayo/viento/tierra por propiedades",
		Materia.cumple(calor, "calor") and Materia.cumple(Materia.de(_lab({"humedad": 1.0})), "agua") and Materia.cumple(Materia.de(_lab({"temperatura": -1.0})), "frio")
		and Materia.cumple(Materia.de(_lab({"conductividad": 1.0})), "rayo") and Materia.cumple(viento, "viento") and Materia.cumple(tierra, "tierra"))
	_ok("cumple: el hielo es frío y no es agua; el calor no es nada más", Materia.cumple(hielo, "frio") and not Materia.cumple(hielo, "agua")
		and not Materia.cumple(calor, "agua") and not Materia.cumple(calor, "frio") and not Materia.cumple(calor, "tierra"))
	_ok("cumple: un nombre desconocido nunca se cumple", not Materia.cumple(calor, "?") and not Materia.cumple(calor, ""))
	_ok("las etiquetas siguen valiendo: «tierra» sola golpea", Materia.golpea(Materia.de(Puzle3D.runa(["tierra"]))))


func _objetos() -> void:
	var calor: RuneData = _lab({"temperatura": 1.0})
	var frio: RuneData = _lab({"temperatura": -1.0})
	var humedo: RuneData = _lab({"humedad": 1.0})
	var hielo_lab: RuneData = _lab({"temperatura": -1.0, "humedad": 0.5, "densidad": 0.9})
	var rayo: RuneData = _lab({"conductividad": 1.0})
	var soplo: RuneData = _lab({}, "gas", 1.0)
	var pesado: RuneData = _lab({"densidad": 2.0}, "solido", 0.8)
	_ok("los elementos de laboratorio no traen etiquetas", calor.tags.is_empty() and humedo.tags.is_empty() and soplo.tags.is_empty() and pesado.tags.is_empty())

	# barril: calor o corriente lo enciende; el agua solo lo apaga si arde
	var ba := Barril3D.new()
	ba.preparar(Vector2i(2, 4))
	_poner(ba)
	await process_frame
	_ok("barril: calor y corriente sin etiquetas reaccionan; humedad y viento no (apagado)", ba.spell_reacts(calor) and ba.spell_reacts(rayo, Vector3.ZERO, _h(rayo))
		and not ba.spell_reacts(humedo) and not ba.spell_reacts(soplo) and not ba.spell_reacts(frio))
	ba.on_spell_hit(humedo)
	_ok("barril: la humedad no lo enciende", not ba.encendido)
	ba.on_spell_hit(calor, Vector3.ZERO, _h(calor))
	_ok("barril: temperatura +1 lo enciende (con Hechizo)", ba.encendido)
	_ok("barril encendido: la humedad reacciona (lo apagará); el frío y el calor no", ba.spell_reacts(humedo) and not ba.spell_reacts(frio) and not ba.spell_reacts(calor))

	# cuerda: calor/corriente la prende; agua o frío la apagan si arde
	var cu := Cuerda3D.new()
	cu.preparar(Vector2i(3, 4))
	_poner(cu)
	await process_frame
	_ok("cuerda entera: calor y corriente sí; humedad, frío y viento no", cu.spell_reacts(calor) and cu.spell_reacts(rayo) and not cu.spell_reacts(humedo) and not cu.spell_reacts(frio) and not cu.spell_reacts(soplo))
	cu.on_spell_hit(calor, Vector3.ZERO, _h(calor))
	_ok("cuerda: temperatura +1 la prende", cu.estado == Cuerda3D.EstadoCuerda.ARDIENDO)
	_ok("cuerda ardiendo: humedad y frío reaccionan (apagan); el viento no", cu.spell_reacts(humedo) and cu.spell_reacts(frio) and not cu.spell_reacts(soplo))

	# compuerta: abre_con / cierra_con por nombre → predicado
	var co := Compuerta3D.new()
	co.preparar(Vector2i(4, 4), false, "fuego", "agua")
	_poner(co)
	await process_frame
	_ok("compuerta abre_con fuego: calor sin etiquetas sí; humedad, frío y corriente no", co.spell_reacts(calor) and not co.spell_reacts(humedo) and not co.spell_reacts(frio) and not co.spell_reacts(rayo))
	co.on_spell_hit(calor, Vector3.ZERO, _h(calor))
	_ok("compuerta: se abre con temperatura +1", co.abierta)
	_ok("compuerta cierra_con agua: humedad sí; el hielo (humedad 0,5 y frío) no", co.spell_reacts(humedo) and not co.spell_reacts(hielo_lab) and not co.spell_reacts(calor))
	co.on_spell_hit(humedo)
	_ok("compuerta: se cierra con humedad", not co.abierta)
	var co2 := Compuerta3D.new()
	co2.preparar(Vector2i(4, 5), false, "rayo", "hielo")
	_poner(co2)
	await process_frame
	_ok("compuerta abre_con rayo: conductividad sí, calor no", co2.spell_reacts(rayo) and not co2.spell_reacts(calor))

	# nexo de rayo: el agua lo moja, el calor lo seca (si está mojado)
	var nx := NexoRayo3D.new()
	nx.preparar(Vector2i(5, 4))
	_poner(nx)
	await process_frame
	_ok("nexo: humedad sí; calor no mientras está seco; frío no", nx.spell_reacts(humedo) and not nx.spell_reacts(calor) and not nx.spell_reacts(frio))
	nx.on_spell_hit(humedo, Vector3.ZERO, _h(humedo))
	_ok("nexo: la humedad lo moja", nx.mojado > 0.0)
	_ok("nexo mojado: el calor reacciona (lo seca)", nx.spell_reacts(calor))
	nx.on_spell_hit(calor)
	_ok("nexo: el calor sin etiquetas lo seca", nx.mojado <= 0.0 or nx.mojado < 1.0, str(nx.mojado))

	# bloque empujable: solo lo mueve el aire (empuje de un gas)
	var bl := BloqueEmpujable3D.new()
	bl.preparar(Vector2i(3, 2), "piedra", _m)
	_poner(bl)
	await process_frame
	_ok("bloque: empuje de un gas sin etiquetas reacciona; el de un sólido (tierra) y el calor no", bl.spell_reacts(soplo) and bl.spell_reacts(soplo, Vector3.ZERO, _h(soplo)) and not bl.spell_reacts(pesado) and not bl.spell_reacts(calor))
	_ok("bloque: reaccion_a(viento) mueve; reaccion_a(tierra) no", String(bl.reaccion_a(soplo, Vector3.RIGHT).get("reaccion", "")) == "mueve" and bl.reaccion_a(pesado, Vector3.RIGHT).is_empty())

	# molino: solo el agua
	var mo := Molino3D.new()
	mo.preparar(Vector2i(2, 5))
	_poner(mo)
	await process_frame
	_ok("molino: humedad sí; hielo, calor y viento no", mo.spell_reacts(humedo) and mo.spell_reacts(humedo, Vector3.ZERO, _h(humedo)) and not mo.spell_reacts(hielo_lab) and not mo.spell_reacts(calor) and not mo.spell_reacts(soplo))

	# muro agrietado: solo la tierra (sólido denso)
	var mu := MuroAgrietado3D.new()
	mu.preparar(Vector2i(5, 5), 2)
	_poner(mu)
	await process_frame
	_ok("muro: un sólido denso sin etiquetas sí; el hielo, el calor y el viento no", mu.spell_reacts(pesado) and mu.spell_reacts(pesado, Vector3.ZERO, _h(pesado)) and not mu.spell_reacts(hielo_lab) and not mu.spell_reacts(calor) and not mu.spell_reacts(soplo))
	_ok("muro: reaccion_a agrieta con un sólido denso y no con un sólido ligero", mu.reaccion_a(pesado) == "agrieta" and mu.reaccion_a(_lab({"densidad": 1.0})) == "")
	mu.on_spell_hit(pesado, Vector3.ZERO, _h(pesado))
	_ok("muro: el golpe del sólido denso lo agrieta", mu.recibidos == 1)

	# surtidor: el agua que no hiela
	var su := Surtidor3D.new()
	su.preparar(_m, Vector2i(1, 4))
	_poner(su)
	await process_frame
	_ok("surtidor: humedad sí; el hielo, el calor y la tierra no", su.spell_reacts(humedo) and su.spell_reacts(humedo, Vector3.ZERO, _h(humedo)) and not su.spell_reacts(hielo_lab) and not su.spell_reacts(calor) and not su.spell_reacts(pesado))

	# tronco del puente: lo derriba el calor
	var tr := TroncoPuente3D.new()
	_poner(tr)
	tr.preparar(null, Vector3(3.5, 0.0, 0.0), Vector3.LEFT, Vector2i(6, 1))
	await process_frame
	_ok("tronco: calor sí; humedad, corriente y frío no", tr.spell_reacts(calor) and tr.spell_reacts(calor, Vector3.ZERO, _h(calor)) and not tr.spell_reacts(humedo) and not tr.spell_reacts(rayo) and not tr.spell_reacts(frio))

	# lava: la enfría el agua o el frío
	var lv := Lava3D.new()
	lv.preparar([Vector2i(1, 5), Vector2i(1, 6)])
	_poner(lv)
	await process_frame
	_ok("lava: humedad y frío sin etiquetas sí; el calor, la corriente y la tierra no", lv.spell_reacts(humedo) and lv.spell_reacts(frio) and lv.spell_reacts(hielo_lab, Vector3.ZERO, _h(hielo_lab))
		and not lv.spell_reacts(calor) and not lv.spell_reacts(rayo) and not lv.spell_reacts(pesado))

	# pulsador de agua: agua de verdad (el hielo no)
	var pu := Pulsador3D.new()
	pu.preparar(Vector2i(6, 4), "agua")
	_poner(pu)
	await process_frame
	_ok("pulsador agua: humedad sí; el hielo, el calor y el viento no", pu.spell_reacts(humedo) and pu.spell_reacts(humedo, Vector3.ZERO, _h(humedo)) and not pu.spell_reacts(hielo_lab) and not pu.spell_reacts(calor) and not pu.spell_reacts(soplo))
	var pu2 := Pulsador3D.new()
	pu2.preparar(Vector2i(6, 5), "magia")
	_poner(pu2)
	await process_frame
	_ok("pulsador magia: cualquier hechizo", pu2.spell_reacts(calor) and pu2.spell_reacts(pesado))

	# veta del pulso: la pica un sólido denso
	var ve := VetaPulso3D.new()
	ve.preparar([Vector2i(5, 1), Vector2i(5, 2)])
	_poner(ve)
	await process_frame
	ve.picar(calor)
	ve.picar(humedo)
	ve.picar(soplo)
	ve.picar(hielo_lab)
	_ok("veta: el calor, la humedad, el viento y el hielo no la pican", ve.golpes_tierra == 0)
	ve.picar(pesado)
	_ok("veta: un sólido denso sin etiquetas la pica", ve.golpes_tierra == 1)
	var ve2 := VetaPulso3D.new()
	ve2.preparar([Vector2i(5, 3)])
	_poner(ve2)
	await process_frame
	ve2.picar(pesado, _h(pesado))
	_ok("veta: y con el Hechizo", ve2.golpes_tierra == 1)


const SEIS: PackedStringArray = ["fire", "water", "ice", "lightning", "wind", "earth"]


## `Reactivo3D.reaccion_material` (la tabla por material) frente a `reaccion_a` (la de los papeles): seto, tronco y barril, los seis elementos, sano y ardiendo. Donde no coinciden
## sale un AVISO «DIFERENCIA»: son decisiones de diseño para Pablo, no fallos (la lógica real sigue siendo la de los papeles).
func _material() -> void:
	_ok("catálogo: seto vegetal, tronco/barril madera, telaraña/cuerda tela, placa/pulsador piedra, nexo metal, el resto \"\"",
		Reactivo3D.MATERIAL_POR_TIPO["seto"] == "vegetal" and Reactivo3D.MATERIAL_POR_TIPO["tronco"] == "madera" and Reactivo3D.MATERIAL_POR_TIPO["barril"] == "madera"
		and Reactivo3D.MATERIAL_POR_TIPO["telarana"] == "tela" and Reactivo3D.MATERIAL_POR_TIPO["cuerda"] == "tela" and Reactivo3D.MATERIAL_POR_TIPO["placa"] == "piedra"
		and Reactivo3D.MATERIAL_POR_TIPO["pulsador"] == "piedra" and Reactivo3D.MATERIAL_POR_TIPO["nexo_rayo"] == "metal")
	var coinciden: int = 0
	var difieren: int = 0
	for tipo in ["seto", "tronco"]:
		for ardiendo in [false, true]:
			for el in SEIS:
				var r: RuneData = load("res://nucleo/%s_rune.tres" % el) as RuneData
				var obj: Reactivo3D = _pieza(tipo)
				if ardiendo:
					obj.on_spell_hit(load("res://nucleo/fire_rune.tres") as RuneData)
				var m: Dictionary = Materia.de(r)
				var ra: String = obj.reaccion_a(r)
				var rm: String = obj.reaccion_material(m)
				if ra == rm:
					coinciden += 1
				else:
					difieren += 1
					print("AVISO DIFERENCIA %s %s + %s: papeles «%s», material (%s) «%s»" % [tipo, "ardiendo" if ardiendo else "sano", el, ra, obj.material(), rm])
	print("AVISO seto/tronco: %d casos coinciden, %d difieren" % [coinciden, difieren])
	_ok("seto/tronco: el fuego prende en las dos tablas y el agua apaga en las dos lo que arde", true)
	# el barril (no es un Reactivo3D): su spell_reacts frente a la tabla de la madera
	var bc: int = 0
	var bd: int = 0
	for encendido in [false, true]:
		for el in SEIS:
			var r2: RuneData = load("res://nucleo/%s_rune.tres" % el) as RuneData
			var ba := Barril3D.new()
			ba.preparar(Vector2i(2, 5))
			_poner(ba)
			if encendido:
				ba.encender()
			var rm2: String = Materia.reaccion(Materia.de(r2), String(Reactivo3D.MATERIAL_POR_TIPO["barril"]), {"ardiendo": encendido})
			if ba.spell_reacts(r2) == (rm2 != ""):
				bc += 1
			else:
				bd += 1
				print("AVISO DIFERENCIA barril %s + %s: reacciona %s, material (madera) «%s»" % ["encendido" if encendido else "apagado", el, str(ba.spell_reacts(r2)), rm2])
			ba.queue_free()
	print("AVISO barril: %d casos coinciden, %d difieren" % [bc, bd])


func _pieza(tipo: String) -> Reactivo3D:
	var o: Reactivo3D = Reactivo3D.new()
	o.preparar(tipo, Vector2i(int(_x / 10.0) + 20, 1), "", _fx, null)
	o.position = Vector3(_x, 0.0, 0.0)
	_x += 10.0
	root.add_child(o)
	return o


func _lanzador() -> void:
	pass
