extends SceneTree
## H6 tercera entrega (tarea 11, 13/11): los reactivos que aún decidían por el NOMBRE del elemento (`Objetos.elemento_de(...) == "fuego"`) o no leían el hechizo ahora deciden por PROPIEDADES
## (`Materia.via` / `Materia.de`): colmena, nido, rompible, recolectable, cristal y prisma del pulso, guardián de la barrera, la enredadera del goblin (EnlaceEnredadera), la nube de veneno,
## la trampa de pared y el color de la roca de la lava. Para cada uno, un elemento de laboratorio SIN etiquetas que provoca su reacción reacciona como el elemento con nombre, y otro con
## las propiedades «equivocadas» no. Y los dos derivados (magma, naturaleza) siguen sin reaccionar donde antes no lo hacían.
##   godot --headless --path . --script res://herramientas/prueba_materia_reactivos_3.gd

const MundoFalso = preload("res://herramientas/prueba_puzle.gd").MundoFalso

var _fallos: int = 0
var _m: MundoFalso = null
var _fx: Vfx3D = null
var _n: int = 0


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


## Una casilla distinta cada vez (los objetos bloquean su celda).
func _celda() -> Vector2i:
	_n += 1
	return Vector2i(1 + _n % 6, 1 + _n / 6)


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
	_via()
	await _colmena_nido()
	await _rompible_prisma()
	await _recolectable()
	await _cristal()
	await _guardian()
	await _resto()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _via() -> void:
	var calor: RuneData = _lab({"temperatura": 1.0})
	_ok("via: cada propiedad da su elemento (calor→fuego, frío→hielo, humedad→agua, corriente→rayo, gas→viento, sólido denso→tierra)",
		Materia.via(Materia.de(calor)) == "fuego" and Materia.via(Materia.de(_lab({"temperatura": -1.0}))) == "hielo" and Materia.via(Materia.de(_lab({"humedad": 1.0}))) == "agua"
		and Materia.via(Materia.de(_lab({"conductividad": 1.0}))) == "rayo" and Materia.via(Materia.de(_lab({}, "gas", 1.0))) == "viento" and Materia.via(Materia.de(_lab({"densidad": 2.0}))) == "tierra")
	_ok("via: el hielo (humedad 0,5 y frío) es hielo y no agua; un sólido ligero o sin propiedades no es nada",
		Materia.via(Materia.de(load("res://nucleo/ice_rune.tres") as RuneData)) == "hielo" and Materia.via(Materia.de(_lab({"densidad": 1.0}))) == "" and Materia.via(Materia.de(_lab({}))) == "")
	var seis: Dictionary = {"fire": "fuego", "water": "agua", "ice": "hielo", "lightning": "rayo", "wind": "viento", "earth": "tierra"}
	var bien: bool = true
	for k in seis:
		var r: RuneData = load("res://nucleo/%s_rune.tres" % k) as RuneData
		bien = bien and Materia.via(Materia.de(r)) == seis[k] and Materia.via(Materia.de(_h(r))) == seis[k]
	_ok("via: los seis elementos de serie (con la runa y con su Hechizo) dan su nombre", bien)
	_ok("via: magma y naturaleza dan SU nombre (no el de fuego/agua, a los que se parecen)",
		Materia.via(Materia.de(load("res://nucleo/magma_rune.tres") as RuneData)) == "magma" and Materia.via(Materia.de(load("res://nucleo/naturaleza_rune.tres") as RuneData)) == "naturaleza")
	_ok("via: una runa solo-etiquetas «fuego» (sin números) sigue valiendo, y sin nada no es nada", Materia.via(Materia.de(Puzle3D.runa(["fuego"]))) == "fuego" and Materia.via(Materia.de(Puzle3D.runa([]))) == ""
		and Materia.via(Materia.de(null)) == "")


func _colmena_nido() -> void:
	var calor: RuneData = _lab({"temperatura": 1.0})
	var frio: RuneData = _lab({"temperatura": -1.0})
	var humedo: RuneData = _lab({"humedad": 1.0})
	var rayo: RuneData = _lab({"conductividad": 1.0})
	var soplo: RuneData = _lab({}, "gas", 1.0)
	var pesado: RuneData = _lab({"densidad": 2.0}, "solido", 0.8)
	var magma: RuneData = load("res://nucleo/magma_rune.tres") as RuneData
	var natur: RuneData = load("res://nucleo/naturaleza_rune.tres") as RuneData
	_ok("los elementos de laboratorio no traen etiquetas", calor.tags.is_empty() and soplo.tags.is_empty() and pesado.tags.is_empty())

	var col := Colmena3D.new()
	col.preparar(_celda(), "T11")
	_poner(col)
	await process_frame
	_ok("colmena: calor y aire sin etiquetas reaccionan (también con Hechizo); humedad, frío, corriente, sólido denso, magma y naturaleza no",
		col.spell_reacts(calor) and col.spell_reacts(soplo) and col.spell_reacts(calor, Vector3.ZERO, _h(calor)) and col.spell_reacts(soplo, Vector3.ZERO, _h(soplo))
		and not col.spell_reacts(humedo) and not col.spell_reacts(frio) and not col.spell_reacts(rayo) and not col.spell_reacts(pesado) and not col.spell_reacts(magma) and not col.spell_reacts(natur))
	col.on_spell_hit(humedo, Vector3.ZERO, _h(humedo))
	_ok("colmena: la humedad no la toca", col.estado == "colgada")
	col.on_spell_hit(soplo, Vector3.ZERO, _h(soplo))
	_ok("colmena: el aire sin etiquetas la descuelga", col.estado == "vacia", col.estado)
	var col2 := Colmena3D.new()
	col2.preparar(_celda(), "T11")
	_poner(col2)
	await process_frame
	col2.on_spell_hit(calor, Vector3.ZERO, _h(calor))
	_ok("colmena: el calor sin etiquetas la quema", col2.estado == "ardiendo", col2.estado)
	_ok("colmena que ya no cuelga: no reacciona a nada", not col.spell_reacts(calor) and not col2.spell_reacts(soplo))

	var ni := Nido3D.new()
	ni.preparar(_celda())
	_poner(ni)
	await process_frame
	_ok("nido: el aire sin etiquetas reacciona; calor, humedad, frío, corriente, sólido denso (0,8 de empuje), magma y naturaleza no",
		ni.spell_reacts(soplo) and ni.spell_reacts(soplo, Vector3.ZERO, _h(soplo)) and not ni.spell_reacts(calor) and not ni.spell_reacts(humedo) and not ni.spell_reacts(frio)
		and not ni.spell_reacts(rayo) and not ni.spell_reacts(pesado) and not ni.spell_reacts(magma) and not ni.spell_reacts(natur))
	ni.on_spell_hit(pesado, Vector3.ZERO, _h(pesado))
	_ok("nido: el sólido empujando no lo sacude", ni.sacudidas == 0)
	ni.on_spell_hit(soplo, Vector3.ZERO, _h(soplo))
	_ok("nido: el aire sin etiquetas lo sacude", ni.sacudidas == 1, str(ni.sacudidas))


func _rompible_prisma() -> void:
	var calor: RuneData = _lab({"temperatura": 1.0})
	var pesado: RuneData = _lab({"densidad": 2.0}, "solido", 0.8)
	var j := Rompible3D.new()
	j.preparar(_celda(), "jarron", "nada", 0, false, "T11", _m)
	_poner(j)
	await process_frame
	_ok("rompible: cualquier hechizo (con o sin Hechizo) reacciona; sin hechizo no", j.spell_reacts(calor) and j.spell_reacts(pesado, Vector3.ZERO, _h(pesado)) and not j.spell_reacts(null))
	j.on_spell_hit(calor, Vector3.ZERO, _h(calor))
	_ok("rompible: el contrato de tres argumentos lo rompe, y roto ya no reacciona", j.roto_ya and not j.spell_reacts(calor, Vector3.ZERO, _h(calor)))

	var pr := PrismaPulso3D.new()
	pr.preparar(_celda(), "n", _m)
	_poner(pr)
	await process_frame
	_ok("prisma: cualquier hechizo reacciona (con o sin Hechizo)", pr.spell_reacts(calor) and pr.spell_reacts(pesado, Vector3.ZERO, _h(pesado)))
	pr.on_spell_hit(calor, Vector3.ZERO, _h(calor))
	_ok("prisma: el contrato de tres argumentos lo gira, y en enfriamiento ya no reacciona", pr.giros == 1 and pr.dir == "e" and not pr.spell_reacts(pesado, Vector3.ZERO, _h(pesado)), "%d %s" % [pr.giros, pr.dir])


func _seta(planta: String = "seta") -> Recolectable3D:
	var r := Recolectable3D.new()
	r.preparar(_celda(), "", 0.0, _m, planta)
	_poner(r)
	return r


func _recolectable() -> void:
	var calor: RuneData = _lab({"temperatura": 1.0})
	var frio: RuneData = _lab({"temperatura": -1.0})
	var humedo: RuneData = _lab({"humedad": 1.0})
	var rayo: RuneData = _lab({"conductividad": 1.0})
	var soplo: RuneData = _lab({}, "gas", 1.0)
	var pesado: RuneData = _lab({"densidad": 2.0}, "solido", 0.8)
	var ligero: RuneData = _lab({"densidad": 1.0})
	var magma: RuneData = load("res://nucleo/magma_rune.tres") as RuneData
	var natur: RuneData = load("res://nucleo/naturaleza_rune.tres") as RuneData
	var casos: Array = [[calor, "seta_asada"], [frio, "seta_helada"], [humedo, "seta_humeda"], [rayo, "seta_electrificada"], [soplo, "esporas"]]
	for c in casos:
		var s: Recolectable3D = _seta()
		await process_frame
		var r: RuneData = c[0]
		var antes: bool = s.spell_reacts(r) and s.spell_reacts(r, Vector3.ZERO, _h(r))
		s.on_spell_hit(r, Vector3.ZERO, _h(r))
		_ok("seta: el elemento de laboratorio sin etiquetas la vuelve «%s»" % c[1], antes and s.objeto == c[1], s.objeto)
	var s2: Recolectable3D = _seta()
	await process_frame
	_ok("seta: un sólido denso, uno ligero, el magma y la naturaleza no le hacen nada (su tabla no tiene tierra, magma ni naturaleza)",
		not s2.spell_reacts(pesado) and not s2.spell_reacts(ligero) and not s2.spell_reacts(magma) and not s2.spell_reacts(natur))
	s2.on_spell_hit(ligero, Vector3.ZERO, _h(ligero))
	_ok("seta: y el golpe equivocado no la cambia", s2.objeto == "seta", s2.objeto)
	var rz: Recolectable3D = _seta("raiz")
	await process_frame
	_ok("raíz: el sólido denso sin etiquetas la vuelve cristal de tierra; la humedad también cuenta (agua)", rz.spell_reacts(pesado, Vector3.ZERO, _h(pesado)) and rz.spell_reacts(humedo) and not rz.spell_reacts(ligero) and not rz.spell_reacts(soplo))
	rz.on_spell_hit(pesado, Vector3.ZERO, _h(pesado))
	_ok("raíz: el golpe de tierra sin etiquetas la transforma", rz.objeto == "cristal_tierra", rz.objeto)
	rz.on_spell_hit(calor)
	_ok("una vez transformada ya no cambia", rz.objeto == "cristal_tierra" and not rz.spell_reacts(calor))


func _cristal() -> void:
	var calor: RuneData = _lab({"temperatura": 1.0})
	var humedo: RuneData = _lab({"humedad": 1.0})
	var rayo: RuneData = _lab({"conductividad": 1.0})
	var debil: RuneData = _lab({"conductividad": 0.3})
	var magma: RuneData = load("res://nucleo/magma_rune.tres") as RuneData
	var c1 := CristalPulso3D.new()
	c1.preparar(_celda(), 0.0, 2, _m)
	_poner(c1)
	await process_frame
	_ok("cristal: reacciona con o sin Hechizo y en reposo", c1.spell_reacts(calor) and c1.spell_reacts(rayo, Vector3.ZERO, _h(rayo)))
	c1.on_spell_hit(rayo, Vector3.ZERO, _h(rayo))
	_ok("cristal: la corriente sin etiquetas lo CARGA y late un pulso de rayo", c1.cargado_s > 0.0 and c1.latidos == 1 and c1.ultimo != null and c1.ultimo.elemento == "rayo",
		"%s %d %s" % [str(c1.cargado_s), c1.latidos, c1.ultimo.elemento if c1.ultimo != null else "-"])
	var c2 := CristalPulso3D.new()
	c2.preparar(_celda(), 0.0, 2, _m)
	_poner(c2)
	await process_frame
	c2.on_spell_hit(calor, Vector3.ZERO, _h(calor))
	_ok("cristal: el calor sin etiquetas late un pulso de fuego y no lo carga", c2.cargado_s == 0.0 and c2.latidos == 1 and c2.ultimo != null and c2.ultimo.elemento == "fuego")
	var c3 := CristalPulso3D.new()
	c3.preparar(_celda(), 0.0, 2, _m)
	_poner(c3)
	await process_frame
	c3.on_spell_hit(debil, Vector3.ZERO, _h(debil))
	_ok("cristal: una conductividad floja (0,3) no lo carga (solo carga lo que conduce de verdad) y late el pulso base", c3.cargado_s == 0.0 and c3.latidos == 1 and c3.ultimo != null and c3.ultimo.elemento == "")
	var c4 := CristalPulso3D.new()
	c4.preparar(_celda(), 0.0, 2, _m)
	_poner(c4)
	await process_frame
	c4.on_spell_hit(humedo, Vector3.ZERO, _h(humedo))
	_ok("cristal: la humedad late un pulso de agua y no lo carga", c4.cargado_s == 0.0 and c4.ultimo != null and c4.ultimo.elemento == "agua")
	var c5 := CristalPulso3D.new()
	c5.preparar(_celda(), 0.0, 2, _m)
	_poner(c5)
	await process_frame
	c5.on_spell_hit(magma)
	_ok("cristal: el magma late con SU nombre (como antes) y no lo carga", c5.cargado_s == 0.0 and c5.ultimo != null and c5.ultimo.elemento == "magma")


func _guardian() -> void:
	var calor: RuneData = _lab({"temperatura": 1.0})
	var frio: RuneData = _lab({"temperatura": -1.0})
	var humedo: RuneData = _lab({"humedad": 1.0})
	var rayo: RuneData = _lab({"conductividad": 1.0})
	var soplo: RuneData = _lab({}, "gas", 1.0)
	var pesado: RuneData = _lab({"densidad": 2.0}, "solido", 0.8)
	var nada: RuneData = _lab({"densidad": 1.0})
	var magma: RuneData = load("res://nucleo/magma_rune.tres") as RuneData
	var natur: RuneData = load("res://nucleo/naturaleza_rune.tres") as RuneData
	var casos: Array = [[calor, "fuego"], [frio, "hielo"], [humedo, "agua"], [rayo, "rayo"], [soplo, "viento"], [pesado, "tierra"], [nada, "rayo"], [magma, "rayo"], [natur, "rayo"]]
	for c in casos:
		var g := GuardianBarrera3D.new()
		g.preparar(_celda(), [Vector2i(7, 7)], 0.0, "rayo", 0.0, false, _m)
		_poner(g)
		await process_frame
		var r: RuneData = c[0]
		g.on_spell_hit(r, Vector3.ZERO, _h(r))
		var esperado: String = c[1]
		_ok("guardián (el suyo es rayo): %s → barrera de «%s»" % [("laboratorio" if r.tags.is_empty() else r.display_name), esperado], g.ultimo_elemento == esperado, g.ultimo_elemento)
	var g2 := GuardianBarrera3D.new()
	g2.preparar(_celda(), [Vector2i(7, 7)], 0.0, "fuego", 0.0, false, _m)
	_poner(g2)
	await process_frame
	_ok("guardián: reacciona a cualquier hechizo", g2.spell_reacts(calor) and g2.spell_reacts(nada, Vector3.ZERO, _h(nada)))


func _resto() -> void:
	var calor: RuneData = _lab({"temperatura": 1.0})
	var frio: RuneData = _lab({"temperatura": -1.0})
	var humedo: RuneData = _lab({"humedad": 1.0})
	var rayo: RuneData = _lab({"conductividad": 1.0})
	var soplo: RuneData = _lab({}, "gas", 1.0)
	var pesado: RuneData = _lab({"densidad": 2.0}, "solido", 0.8)
	var magma: RuneData = load("res://nucleo/magma_rune.tres") as RuneData
	var natur: RuneData = load("res://nucleo/naturaleza_rune.tres") as RuneData

	# la enredadera del goblin: solo el calor
	var en := Combate3D.EnlaceEnredadera.new()
	_poner(en)
	await process_frame
	_ok("enredadera (enlace): el calor sin etiquetas reacciona (con o sin Hechizo); humedad, frío, corriente, aire, sólido denso, magma y naturaleza no",
		en.spell_reacts(calor) and en.spell_reacts(calor, Vector3.ZERO, _h(calor)) and not en.spell_reacts(humedo) and not en.spell_reacts(frio) and not en.spell_reacts(rayo)
		and not en.spell_reacts(soplo) and not en.spell_reacts(pesado) and not en.spell_reacts(magma) and not en.spell_reacts(natur))
	var vid := Enredadera3D.new()
	vid.preparar(_fx)
	_poner(vid)
	await process_frame
	en.vid = vid
	vid.fase = Enredadera3D.Fase.VIVA
	en.on_spell_hit(humedo, Vector3.ZERO, _h(humedo))
	_ok("enredadera: la humedad no la quema", vid.fase == Enredadera3D.Fase.VIVA)
	en.on_spell_hit(calor, Vector3.ZERO, _h(calor))
	_ok("enredadera: el calor sin etiquetas la quema", vid.fase == Enredadera3D.Fase.ARDIENDO)

	# nube de veneno: el aire la empuja, el calor la quema
	var nube: NubeVeneno3D = NubeVeneno3D.crear(_m._props, Vector3(3.5, 0.0, 3.5), 60.0, 1.0, null)
	await process_frame
	_ok("nube de veneno: aire y calor sin etiquetas reaccionan; humedad, frío, corriente, sólido denso, magma y naturaleza no",
		nube.spell_reacts(calor) and nube.spell_reacts(soplo, Vector3.ZERO, _h(soplo)) and not nube.spell_reacts(humedo) and not nube.spell_reacts(frio) and not nube.spell_reacts(rayo)
		and not nube.spell_reacts(pesado) and not nube.spell_reacts(magma) and not nube.spell_reacts(natur))

	# trampa de pared: la apaga el agua o el hielo
	var tp := TrampaPared3D.new()
	tp.preparar(Vector2i(1, 0), "s", "fuego", 3, _m)
	_poner(tp)
	await process_frame
	_ok("trampa de pared: humedad y frío sin etiquetas la apagan; calor, aire, corriente, sólido denso, magma y naturaleza no",
		tp.spell_reacts(humedo) and tp.spell_reacts(frio, Vector3.ZERO, _h(frio)) and not tp.spell_reacts(calor) and not tp.spell_reacts(soplo) and not tp.spell_reacts(rayo)
		and not tp.spell_reacts(pesado) and not tp.spell_reacts(magma) and not tp.spell_reacts(natur))
	tp.on_spell_hit(calor, Vector3.ZERO, _h(calor))
	_ok("trampa de pared: el calor no la apaga", tp.activa)
	tp.on_spell_hit(humedo, Vector3.ZERO, _h(humedo))
	_ok("trampa de pared: la humedad sin etiquetas la apaga", not tp.activa)

	# lava: obsidiana con lo que enfría, basalto con lo que solo moja
	var lv := Lava3D.new()
	lv.preparar([Vector2i(2, 6), Vector2i(4, 6)])
	_poner(lv)
	await process_frame
	lv.on_spell_hit(frio, Vector3.ZERO, _h(frio))
	_ok("lava: el frío sin etiquetas la enfría en OBSIDIANA", lv.es_roca(Vector2i(2, 6)) or lv.es_roca(Vector2i(4, 6)), "")
	var celda_frio: Vector2i = Vector2i(2, 6) if lv.es_roca(Vector2i(2, 6)) else Vector2i(4, 6)
	_ok("lava: la roca recuerda la vía del hielo", lv.via_de_roca(celda_frio) == Lava3D.VIA_HIELO, lv.via_de_roca(celda_frio))
	var lv2 := Lava3D.new()
	lv2.preparar([Vector2i(2, 5)])
	_poner(lv2)
	await process_frame
	lv2.on_spell_hit(humedo, Vector3.ZERO, _h(humedo))
	_ok("lava: la humedad sin etiquetas la enfría en BASALTO", lv2.es_roca(Vector2i(2, 5)) and lv2.via_de_roca(Vector2i(2, 5)) == Lava3D.VIA_AGUA, lv2.via_de_roca(Vector2i(2, 5)))
