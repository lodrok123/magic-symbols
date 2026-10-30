extends SceneTree
## H6 segunda entrega (paso 2): el lanzador y la previsión deciden por PROPIEDADES, con un elemento de laboratorio SIN etiquetas:
##   · `Lanzador3D.reacciona_a` (la consulta que comparten `_golpear`, el trazado de la bola, el haz y la previsión) pasa el Hechizo solo a quien lo admite;
##   · `empuje_de_golpe` decide «viento» con `Materia.sopla` (un gas que empuja), no con la etiqueta;
##   · «el viento lleva la llama» en `trazar` y la activación al final del tramo;
##   · la previsión (`PrevisionHechizo`) y el golpe real dicen lo mismo con un elemento sin etiquetas.
##   godot --headless --path . --script res://herramientas/prueba_materia_lanzador.gd

const MundoFalso = preload("res://herramientas/prueba_puzle.gd").MundoFalso

class Viejo extends Area3D:
	func spell_reacts(_r: RuneData, _d: Vector3) -> bool:
		return true

class Nuevo extends Area3D:
	var visto: Hechizo = null
	func spell_reacts(_r: RuneData, _d: Vector3 = Vector3.ZERO, h: Hechizo = null) -> bool:
		visto = h
		return true

class Empujable extends Area3D:
	var empujes: int = 0
	func push(_d: Vector3, _f: float) -> void:
		empujes += 1

var _fallos: int = 0
var _m: MundoFalso = null
var _fx: Vfx3D = null
var _l: Lanzador3D = null
var _x: float = 100.0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


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


func _caja(a: Area3D, centro: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.0, 1.0, 1.0)
	cs.shape = b
	a.add_child(cs)
	a.collision_layer = Lanzador3D.CAPA_REACTIVO
	a.collision_mask = 0
	a.position = centro
	root.add_child(a)


func _pieza(tipo: String, c: Vector2i) -> Reactivo3D:
	var r := Reactivo3D.new()
	r.preparar(tipo, c, "", _fx, null)
	r.position = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	_m._props.add_child(r)
	return r


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
	_l = Lanzador3D.new()
	_l.mundo = _m
	root.add_child(_l)
	_consulta()
	_empuje()
	await _previsiones()
	await _trazado()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _consulta() -> void:
	var r: RuneData = _lab({"temperatura": 1.0})
	var h: Hechizo = _h(r)
	var nuevo := Nuevo.new()
	var viejo := Viejo.new()
	var sin := Area3D.new()
	_ok("reacciona_a: a un objeto de tres argumentos le pasa el Hechizo", Lanzador3D.reacciona_a(nuevo, r, Vector3.RIGHT, h) and nuevo.visto == h)
	nuevo.visto = null
	Lanzador3D.reacciona_a(nuevo, r, Vector3.RIGHT)
	_ok("reacciona_a: sin Hechizo llega null", nuevo.visto == null)
	_ok("reacciona_a: uno de dos argumentos sigue funcionando", Lanzador3D.reacciona_a(viejo, r, Vector3.RIGHT, h))
	_ok("reacciona_a: sin spell_reacts, sí", Lanzador3D.reacciona_a(sin, r, Vector3.RIGHT, h))
	for n in [nuevo, viejo, sin]:
		(n as Node).free()


func _empuje() -> void:
	var soplo: RuneData = _lab({}, "gas", 1.0)
	var pesado: RuneData = _lab({"densidad": 2.0}, "solido", 0.8)
	var agua: RuneData = load("res://nucleo/water_rune.tres") as RuneData
	var o := Empujable.new()
	_caja(o, Vector3(40, 1, 0))
	_ok("empuje_de_golpe: un gas que empuja (sin etiquetas) empuja", not Lanzador3D.empuje_de_golpe(o, soplo, Vector3.RIGHT, o.position, false, Vector3.ZERO).is_empty()
		and not Lanzador3D.empuje_de_golpe(o, soplo, Vector3.RIGHT, o.position, false, Vector3.ZERO, _h(soplo)).is_empty())
	_ok("empuje_de_golpe: la tierra (sólida, empuje 0,8) y el agua (0,5) no", Lanzador3D.empuje_de_golpe(o, pesado, Vector3.RIGHT, o.position, false, Vector3.ZERO, _h(pesado)).is_empty()
		and Lanzador3D.empuje_de_golpe(o, agua, Vector3.RIGHT, o.position, false, Vector3.ZERO, _h(agua)).is_empty())
	_ok("empuje_de_golpe: atraer tira de todo", not Lanzador3D.empuje_de_golpe(o, pesado, Vector3.RIGHT, Vector3.ZERO, true, Vector3.ZERO).is_empty())
	var con_etiqueta: RuneData = load("res://nucleo/wind_rune.tres") as RuneData
	_ok("empuje_de_golpe: el viento de siempre sigue empujando, con y sin Hechizo", not Lanzador3D.empuje_de_golpe(o, con_etiqueta, Vector3.RIGHT, o.position, false, Vector3.ZERO).is_empty()
		and not Lanzador3D.empuje_de_golpe(o, con_etiqueta, Vector3.RIGHT, o.position, false, Vector3.ZERO, _h(con_etiqueta)).is_empty())


## La previsión y el golpe real dicen lo mismo, con y sin Hechizo, con un elemento sin etiquetas.
func _previsiones() -> void:
	var calor: RuneData = _lab({"temperatura": 1.0})
	var humedo: RuneData = _lab({"humedad": 1.0})
	var pesado: RuneData = _lab({"densidad": 2.0}, "solido", 0.8)
	var soplo: RuneData = _lab({}, "gas", 1.0)
	var gp := {"dir": Vector3.RIGHT, "punto": Vector3.ZERO, "desde": Vector3.ZERO}

	var seto: Reactivo3D = _pieza("seto", Vector2i(2, 4))
	var p: Dictionary = PrevisionHechizo._de_golpe(_l, seto, _h(calor), calor, gp)
	_ok("previsión: temperatura +1 sin etiquetas sobre un seto → «prende»", String(p.get("reaccion", "")) == "prende", str(p))
	var real: bool = _l._golpear(seto, calor, Vector3.RIGHT, seto.position, 0, false, Vector3.ZERO, _h(calor))
	_ok("golpe real: lo prende, como decía la previsión", real and seto.estado == Reactivo3D.EstadoObj.ARDIENDO)
	var p2: Dictionary = PrevisionHechizo._de_golpe(_l, seto, _h(humedo), humedo, gp)
	_ok("previsión: humedad sin etiquetas sobre un seto que arde → «apaga»", String(p2.get("reaccion", "")) == "apaga", str(p2))
	var seto2: Reactivo3D = _pieza("seto", Vector2i(3, 4))
	_ok("previsión: humedad sobre un seto sano → nada, y el golpe real tampoco lo toca",
		PrevisionHechizo._de_golpe(_l, seto2, _h(humedo), humedo, gp).is_empty() and not _l._golpear(seto2, humedo, Vector3.RIGHT, seto2.position, 0, false, Vector3.ZERO, _h(humedo))
		and seto2.estado == Reactivo3D.EstadoObj.SANO)

	var muro := MuroAgrietado3D.new()
	muro.preparar(Vector2i(5, 5), 2)
	_m._props.add_child(muro)
	await process_frame
	var pm: Dictionary = PrevisionHechizo._de_golpe(_l, muro, _h(pesado), pesado, gp)
	_ok("previsión: un sólido denso sin etiquetas sobre el muro → «agrieta»", String(pm.get("reaccion", "")) == "agrieta", str(pm))
	_l._golpear(muro, pesado, Vector3.RIGHT, muro.position, 0, false, Vector3.ZERO, _h(pesado))
	_ok("golpe real: lo agrieta (recibidos 1)", muro.recibidos == 1)
	_ok("previsión: el calor sobre el muro → nada", PrevisionHechizo._de_golpe(_l, muro, _h(calor), calor, gp).is_empty())

	var bl := BloqueEmpujable3D.new()
	bl.preparar(Vector2i(3, 2), "piedra", _m)
	_m._props.add_child(bl)
	await process_frame
	var pb: Dictionary = PrevisionHechizo._de_golpe(_l, bl, _h(soplo), soplo, gp)
	_ok("previsión: un gas que empuja, sin etiquetas, sobre el bloque → «mueve»", String(pb.get("reaccion", "")) == "mueve", str(pb))
	_ok("previsión: la tierra sobre el bloque → nada", PrevisionHechizo._de_golpe(_l, bl, _h(pesado), pesado, gp).is_empty())


## «El viento lleva la llama» y la activación al final del tramo, con un viento sin etiquetas y un brasero encendido en el camino.
func _trazado() -> void:
	var soplo: RuneData = _lab({}, "gas", 1.0)
	var pesado: RuneData = _lab({"densidad": 2.0}, "solido", 0.8)
	var calor: RuneData = _lab({"temperatura": 1.0})
	var br: Reactivo3D = _pieza("brasero", Vector2i(4, 4))
	br.on_spell_hit(calor)
	_ok("trazado: el brasero está encendido", br.is_lit)
	await physics_frame
	await physics_frame
	var y: float = br.global_position.y + 0.8
	var ini := Vector3(Terreno3D.centro_de(Vector2i(1, 4), 0.0).x, y, br.global_position.z)
	var res: Dictionary = _l.trazar(ini, Vector3.RIGHT, 8.0, 0, soplo, false, 0, false, _h(soplo))
	var tramos: Array = res["tramos"]
	var golpes: int = 0
	for t in tramos:
		golpes += (t["golpes"] as Array).size()
	_ok("trazado: la bola de aire llega al brasero", golpes > 0, "tramos %d golpes %d" % [tramos.size(), golpes])
	if golpes > 0:
		var t0: Dictionary = tramos[0]
		_ok("trazado: el aire sin etiquetas se lleva la llama (el tramo ya es de fuego)", Materia.calienta(Materia.de(t0["rune"] as RuneData)) and String(t0.get("elemento", "")) == "fuego", String(t0.get("elemento", "")))
	var res2: Dictionary = _l.trazar(ini, Vector3.RIGHT, 8.0, 0, pesado, false, 0, false, _h(pesado))
	var cargo: bool = false
	for t in res2["tramos"]:
		cargo = cargo or Materia.calienta(Materia.de(t["rune"] as RuneData))
	_ok("trazado: la tierra no se lleva la llama", not cargo)
