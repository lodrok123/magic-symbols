extends SceneTree
## H6 (paso 3 y 4): el contrato `on_spell_hit(rune, dir, hechizo = null)` / `spell_reacts(rune, dir, hechizo = null)` y `Reactivo3D` decidiendo por PROPIEDADES (Materia), sin etiquetas.
##   godot --headless --path . --script res://herramientas/prueba_materia_reactivos.gd

class Viejo extends Area3D:
	var golpes: int = 0
	func spell_reacts(_r: RuneData, _d: Vector3) -> bool:
		return true
	func on_spell_hit(_r: RuneData, _d: Vector3 = Vector3.ZERO) -> void:
		golpes += 1

class Nuevo extends Area3D:
	var hechizo_reacts: Hechizo = null
	var hechizo_hit: Hechizo = null
	func spell_reacts(_r: RuneData, _d: Vector3 = Vector3.ZERO, h: Hechizo = null) -> bool:
		hechizo_reacts = h
		return true
	func on_spell_hit(_r: RuneData, _d: Vector3 = Vector3.ZERO, h: Hechizo = null) -> void:
		hechizo_hit = h

var _fallos: int = 0
var _fx: Vfx3D = null
var _x: float = 0.0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _nuevo(tipo: String, elemento: String = "") -> Reactivo3D:
	var r := Reactivo3D.new()
	r.preparar(tipo, Vector2i(int(_x / 10.0), 0), elemento, _fx, null)
	r.position = Vector3(_x, 0.0, 0.0)
	_x += 10.0
	root.add_child(r)
	return r


## Un elemento de laboratorio SOLO con propiedades: sin una etiqueta.
func _lab(campos: Dictionary) -> RuneData:
	var r := RuneData.new()
	var mods: Dictionary = {}
	for k in campos:
		mods[k] = {"op": "fija", "valor": campos[k]}
	r.modificadores = mods
	return r


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


func _initialize() -> void:
	await process_frame
	_fx = Vfx3D.new()
	root.add_child(_fx)
	_contrato()
	_propiedades()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _contrato() -> void:
	var m := Node3D.new()
	root.add_child(m)
	var l := Lanzador3D.new()
	l.mundo = m
	root.add_child(l)
	var rune := RuneData.new()
	var h: Hechizo = Hechizo.construir(load("res://nucleo/fire_rune.tres") as RuneData, {})
	var viejo := Viejo.new()
	_caja(viejo, Vector3(5, 1, 0))
	var nuevo := Nuevo.new()
	_caja(nuevo, Vector3(8, 1, 0))
	_ok("el lanzador detecta el tercer argumento", Lanzador3D._admite_hechizo(nuevo, "on_spell_hit") and Lanzador3D._admite_hechizo(nuevo, "spell_reacts")
		and not Lanzador3D._admite_hechizo(viejo, "on_spell_hit") and not Lanzador3D._admite_hechizo(viejo, "spell_reacts"))
	var r1: bool = l._golpear(viejo, rune, Vector3.RIGHT, Vector3(5, 1, 0), 0, false, Vector3.ZERO, h)
	_ok("un reactivo de dos argumentos sigue funcionando con hechizo", r1 and viejo.golpes == 1)
	var r2: bool = l._golpear(nuevo, rune, Vector3.RIGHT, Vector3(8, 1, 0), 0, false, Vector3.ZERO, h)
	_ok("uno de tres recibe el hechizo en spell_reacts y en on_spell_hit", r2 and nuevo.hechizo_reacts == h and nuevo.hechizo_hit == h)
	l._golpear(nuevo, rune, Vector3.RIGHT, Vector3(8, 1, 0), 0, false, Vector3.ZERO)
	_ok("sin hechizo llega null", nuevo.hechizo_hit == null)
	var base := Reactivo3D.new()
	_ok("Reactivo3D declara el tercer argumento", Lanzador3D._admite_hechizo(base, "on_spell_hit") and Lanzador3D._admite_hechizo(base, "spell_reacts"))
	base.free()
	# Combate3D y Escudo3D siguen recibiéndolo (antes por el `is Combate3D`)
	var e := Escudo3D.new()
	_ok("Escudo3D lo declara", Lanzador3D._admite_hechizo(e, "on_spell_hit"))
	e.free()


func _propiedades() -> void:
	var calor: RuneData = _lab({"temperatura": 1.0})
	_ok("el elemento de laboratorio no tiene etiquetas", calor.tags.is_empty())
	var hcalor: Hechizo = Hechizo.construir(calor, {})
	var seto: Reactivo3D = _nuevo("seto")
	_ok("seto: spell_reacts con el RuneData sin etiquetas", seto.spell_reacts(calor, Vector3.ZERO))
	_ok("seto: spell_reacts con el Hechizo", seto.spell_reacts(calor, Vector3.ZERO, hcalor))
	_ok("seto: reaccion_a → prende", seto.reaccion_a(calor) == "prende" and seto.reaccion_a(calor, hcalor) == "prende")
	seto.on_spell_hit(calor, Vector3.ZERO)
	_ok("seto: on_spell_hit lo enciende (temperatura +1, sin etiquetas)", seto.estado == Reactivo3D.EstadoObj.ARDIENDO)
	var seto2: Reactivo3D = _nuevo("seto")
	seto2.on_spell_hit(calor, Vector3.ZERO, hcalor)
	_ok("seto: on_spell_hit con Hechizo también lo enciende", seto2.estado == Reactivo3D.EstadoObj.ARDIENDO)
	# frío (apaga lo que arde), humedad (apaga), corriente (prende), viento (aviva), tierra (no aviva)
	var frio: RuneData = _lab({"temperatura": -1.0})
	_ok("frío sin etiquetas apaga un seto que arde", seto.reaccion_a(frio) == "apaga")
	var humedo: RuneData = _lab({"humedad": 1.0})
	_ok("humedad sin etiquetas apaga un seto que arde", seto.reaccion_a(humedo) == "apaga")
	var seto3: Reactivo3D = _nuevo("seto")
	_ok("humedad sin etiquetas no hace nada a un seto sano (no es mojable)", not seto3.spell_reacts(humedo, Vector3.ZERO) and seto3.reaccion_a(humedo) == "")
	var rayo: RuneData = _lab({"conductividad": 1.0})
	_ok("conductividad sin etiquetas prende un seto sano", seto3.reaccion_a(rayo) == "prende" and seto3.spell_reacts(rayo, Vector3.ZERO))
	var soplo: RuneData = _lab({})
	soplo.empuje = 1.0
	soplo.estado = "gas"
	_ok("empuje de un gas sin etiquetas aviva lo que arde", seto.reaccion_a(soplo) == "aviva")
	var piedra: RuneData = _lab({})
	piedra.empuje = 0.8
	_ok("empuje de un sólido (tierra) no aviva", seto.reaccion_a(piedra) == "")
	# el hielo: humedad 0,5 pero enfría, no moja a la leña mojable
	var hielo: RuneData = load("res://nucleo/ice_rune.tres") as RuneData
	var leña: Reactivo3D = Reactivo3D.new()
	var ps := PackedStringArray(["+mojable"])
	leña.papeles = ps
	leña.preparar("seto", Vector2i(30, 0), "", _fx, null)
	root.add_child(leña)
	_ok("el hielo no moja a la leña mojable", leña.reaccion_a(hielo) == "")
	_ok("el agua sí", leña.reaccion_a(load("res://nucleo/water_rune.tres") as RuneData) == "moja")
	# el brasero y el brasero encendido, que lleva el viento: su fuego es un RuneData de solo etiquetas
	var brasero: Reactivo3D = _nuevo("brasero")
	_ok("brasero apagado + temperatura +1 sin etiquetas → enciende", brasero.reaccion_a(calor) == "enciende")
	brasero.on_spell_hit(calor, Vector3.ZERO)
	_ok("brasero encendido y su llama la entiende Materia", brasero.is_lit and brasero.carried_element() != null and Materia.calienta(Materia.de(brasero.carried_element())))
	_ok("brasero encendido + frío sin etiquetas → apaga", brasero.reaccion_a(frio) == "apaga")
	# tótem de fuego con el elemento de laboratorio
	var totem: Reactivo3D = _nuevo("totem", "fuego")
	_ok("tótem de fuego + temperatura +1 sin etiquetas → activa", totem.reaccion_a(calor) == "activa" and totem.spell_reacts(calor, Vector3.ZERO))
	_ok("tótem de fuego + humedad → nada", totem.reaccion_a(humedo) == "")
	var surtidor: Reactivo3D = _nuevo("surtidor")
	_ok("surtidor + humedad sin etiquetas → brota; con hielo, no", surtidor.reaccion_a(humedo) == "brota" and surtidor.reaccion_a(hielo) == "")
