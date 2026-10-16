extends SceneTree
## Piezas de fuego del laboratorio 14.6 (16/10, Juego), sin escena ni ventana: lo que se puede mirar sin la maqueta.
##   · ContadorReactivos3D: cuenta `is_lit`, avisa `todos(si)` al llegar al mínimo y al bajar de él, un nodo liberado cuenta como apagado.
##   · Cuerda3D: el fuego la prende, arde T_ARDE s, se rompe y lo que sostiene CAE (`tender` si lo tiene, si no `cerrar`); el agua la apaga
##     mientras arde pero no arregla una rota; el contagio de un seto que arde la prende.
##   · Barril3D: el fuego de mapa (grupo `flammable3d`, `is_lit`) a ≤ RADIO_FUEGO lo enciende; lo lejano o apagado, no.
##   · Puzle3D: la gramática nueva (brasero rele/espera/dura, seto mojable, contador de=/minimo, cuerda sostiene) y sus señales, condiciones
##     y acciones, y los avisos de las referencias rotas.
## El relé del brasero, la leña mojada y el laboratorio entero (que necesitan la maqueta) los juega herramientas/escenario_puzles_fuego*.gd.
##   godot --headless --path . --script res://herramientas/prueba_fuego.gd

## Algo que arde, sin más: `is_lit` y una posición.
class Fuego extends Node3D:
	var is_lit: bool = false

## Algo que cae: registra qué le pidieron.
class SoportePuente extends Node:
	var llamadas: Array = []
	func tender() -> void:
		llamadas.append("tender")
	func cerrar() -> void:
		llamadas.append("cerrar")

class SoporteCompuerta extends Node:
	var llamadas: Array = []
	func cerrar() -> void:
		llamadas.append("cerrar")

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_contador()
	await _cuerda()
	await _barril()
	_gramatica()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _fuego(lit: bool = false, pos: Vector3 = Vector3.ZERO) -> Fuego:
	var f := Fuego.new()
	f.is_lit = lit
	f.position = pos
	root.add_child(f)
	return f


# ---------------------------------------------------------------------------------------------------------------------

func _contador() -> void:
	var a: Fuego = _fuego()
	var b: Fuego = _fuego()
	var c: Fuego = _fuego()
	var ct := ContadorReactivos3D.new()
	ct.preparar([a, b, c])
	root.add_child(ct)
	var r: Dictionary = {"todos": [], "cambio": []}
	ct.todos.connect(func(si: bool) -> void: (r["todos"] as Array).append(si))
	ct.cambio.connect(func(n: int, t: int) -> void: (r["cambio"] as Array).append([n, t]))
	_ok("1 un contador de 3 empieza en 0/3, sin completar y sin avisar al nacer", ct.total() == 3 and ct.encendidos == 0 and not ct.completo and (r["todos"] as Array).is_empty())
	a.is_lit = true
	ct._process(0.0)
	_ok("1 con uno encendido: 1/3, aún no completo, `cambio(1,3)`", ct.encendidos == 1 and not ct.completo and r["cambio"] == [[1, 3]])
	b.is_lit = true
	c.is_lit = true
	ct._process(0.0)
	_ok("1 con los tres: completo y `todos(true)` una sola vez", ct.completo and r["todos"] == [true])
	ct._process(0.0)
	_ok("1 mirar otra vez sin cambios no repite la señal", r["todos"] == [true] and (r["cambio"] as Array).size() == 2)
	b.is_lit = false
	ct._process(0.0)
	_ok("1 al apagarse uno baja a 2/3 y `todos(false)`", ct.encendidos == 2 and not ct.completo and r["todos"] == [true, false])
	b.is_lit = true
	c.free()
	ct._process(0.0)
	_ok("1 un nodo liberado (un seto consumido) cuenta como apagado", ct.encendidos == 2 and not ct.completo and ct.contar() == 2 and r["todos"] == [true, false])
	var ct2 := ContadorReactivos3D.new()
	ct2.preparar([a, b], 1)
	root.add_child(ct2)
	_ok("1 `minimo=1` basta con uno encendido", ct2.completo and ct2.minimo == 1)
	var ct3 := ContadorReactivos3D.new()
	ct3.preparar([])
	root.add_child(ct3)
	ct3._process(0.0)
	_ok("1 una lista vacía no está nunca completa", not ct3.completo and ct3.total() == 0)


# ---------------------------------------------------------------------------------------------------------------------

func _cuerda() -> void:
	var puente := SoportePuente.new()
	var comp := SoporteCompuerta.new()
	root.add_child(puente)
	root.add_child(comp)
	var cu := Cuerda3D.new()
	cu.sostiene = puente
	root.add_child(cu)
	var rotas: Array = []
	cu.rota.connect(func() -> void: rotas.append(true))
	_ok("2 una cuerda nace entera, sin arder, en el grupo de lo que arde", cu.estado == Cuerda3D.EstadoCuerda.ENTERA and not cu.is_lit and not cu.rota_ya and cu.is_in_group(Reactivo3D.GRUPO_ARDE) and cu.can_burn())
	_ok("2 reacciona al fuego y al rayo, no al agua mientras está entera", cu.spell_reacts(Puzle3D.runa(["fuego", "calor"])) and cu.spell_reacts(Puzle3D.runa(["rayo"])) and not cu.spell_reacts(Puzle3D.runa(["agua"])))
	cu.on_spell_hit(Puzle3D.runa(["fuego", "calor"]))
	_ok("2 el fuego la prende: ARDIENDO e `is_lit`", cu.estado == Cuerda3D.EstadoCuerda.ARDIENDO and cu.is_lit and not cu.can_burn())
	_ok("2 ardiendo reacciona al agua pero ya no al fuego", cu.spell_reacts(Puzle3D.runa(["agua"])) and not cu.spell_reacts(Puzle3D.runa(["fuego", "calor"])))
	cu._process(Cuerda3D.T_ARDE * 0.5)
	cu.on_spell_hit(Puzle3D.runa(["agua", "humedo"]))
	_ok("2 el agua a mitad de arder la apaga: vuelve a estar entera y no se rompe", cu.estado == Cuerda3D.EstadoCuerda.ENTERA and not cu.is_lit and rotas.is_empty() and puente.llamadas.is_empty())
	cu.ignite()
	cu._process(Cuerda3D.T_ARDE - 0.1)
	_ok("2 a 0,1 s de romperse todavía no ha caído nada", cu.estado == Cuerda3D.EstadoCuerda.ARDIENDO and puente.llamadas.is_empty() and rotas.is_empty())
	cu._process(0.2)
	_ok("2 a los T_ARDE s se rompe: `rota`, ya no arde, sale del grupo y lo que sostiene cae con `tender` (y solo ese)", cu.rota_ya and cu.estado == Cuerda3D.EstadoCuerda.ROTA and not cu.is_lit and rotas.size() == 1 and puente.llamadas == ["tender"] and not cu.is_in_group(Reactivo3D.GRUPO_ARDE))
	cu.on_spell_hit(Puzle3D.runa(["fuego", "calor"]))
	cu.ignite()
	cu.arder()
	_ok("2 una cuerda rota no vuelve a arder ni a romperse", cu.estado == Cuerda3D.EstadoCuerda.ROTA and rotas.size() == 1 and puente.llamadas == ["tender"] and not cu.can_burn() and not cu.spell_reacts(Puzle3D.runa(["fuego", "calor"])))
	var cu2 := Cuerda3D.new()
	cu2.sostiene = comp
	root.add_child(cu2)
	cu2.quemar()
	cu2._process(Cuerda3D.T_ARDE + 0.1)
	_ok("2 sin `tender`, lo sostenido cae con `cerrar` (la compuerta levantada baja)", comp.llamadas == ["cerrar"])
	var cu3 := Cuerda3D.new()
	root.add_child(cu3)
	cu3.arder()
	cu3._process(Cuerda3D.T_ARDE + 0.1)
	_ok("2 una cuerda que no sostiene nada se rompe igual y no falla", cu3.rota_ya)
	var cu4 := Cuerda3D.new()
	cu4.sostiene = puente
	root.add_child(cu4)
	var seto: Fuego = _fuego(true, Vector3.ZERO)
	_ok("2 un seto que arde y llama a `ignite` a las cuerdas de su grupo la prende (contagio)", cu4.can_burn())
	cu4.ignite(seto.global_position)
	_ok("2 … y `ignite` la deja ardiendo", cu4.estado == Cuerda3D.EstadoCuerda.ARDIENDO)
	cu4.free()                      # arde en el origen: si se queda, enciende el barril de la prueba siguiente


# ---------------------------------------------------------------------------------------------------------------------

func _barril() -> void:
	var cerca: Fuego = _fuego(true, Vector3(2.0, 0.0, 0.0))
	var lejos: Fuego = _fuego(true, Vector3(0.0, 0.0, Barril3D.RADIO_FUEGO + 1.0))
	var apagado: Fuego = _fuego(false, Vector3(0.5, 0.0, 0.0))
	cerca.add_to_group(Reactivo3D.GRUPO_ARDE)
	lejos.add_to_group(Reactivo3D.GRUPO_ARDE)
	apagado.add_to_group(Reactivo3D.GRUPO_ARDE)
	var ba := Barril3D.new()
	root.add_child(ba)
	ba.global_position = Vector3.ZERO
	# Solo lo lejano y lo apagado en el grupo: no se enciende.
	cerca.remove_from_group(Reactivo3D.GRUPO_ARDE)
	ba._process(Barril3D.CADA_FUEGO + 0.01)
	_ok("3 un barril con solo algo apagado cerca y algo encendido lejos NO se enciende", not ba.encendido)
	cerca.add_to_group(Reactivo3D.GRUPO_ARDE)
	ba._process(Barril3D.CADA_FUEGO * 0.5)
	_ok("3 se mira cada CADA_FUEGO s, no cada fotograma", not ba.encendido)
	ba._process(Barril3D.CADA_FUEGO)
	_ok("3 con algo que arde a 2 u (≤ RADIO_FUEGO) se enciende solo", ba.encendido)
	var ba2 := Barril3D.new()
	root.add_child(ba2)
	ba2.global_position = Vector3(40.0, 0.0, 40.0)
	ba2._process(1.0)
	_ok("3 y uno que está lejos de todo sigue entero", not ba2.encendido and not ba2.explotado)
	_ok("3 el alcance es el del contagio entre setos (Reactivo3D.CONTAGIO)", Barril3D.RADIO_FUEGO == Reactivo3D.CONTAGIO)


# ---------------------------------------------------------------------------------------------------------------------

func _gramatica() -> void:
	var t: String = "\n".join([
		"; pieza b1 brasero 2 3 rele=b2 espera=2 dura=5",
		"; pieza b2 brasero 4 3 dura=6",
		"; pieza s1 seto 2 5 mojable=si",
		"; pieza c1 contador 3 3 de=2,3+4,3 minimo=2",
		"; pieza co compuerta 6 3 abierta=si",
		"; pieza cu cuerda 7 3 sostiene=co",
		"; pieza pu puerta 1 1",
		"; puzle p1 cuando=c1.todos si=b1.encendido hace=pu.abrir",
		"; puzle p2 cuando=c1.no_todos hace=pu.cerrar",
		"; puzle p3 cuando=cu.rota si=cu.rota hace=pu.abrir",
		"; puzle p4 cuando=b1.apagado hace=b2.encender y=s1.encender y=cu.quemar",
		"; puzle p5 cuando=s1.consumido hace=b1.apagar",
		"; puzle p6 cuando=b2.encendido si=s1.ardiendo hace=pu.abrir",
	])
	var r: Dictionary = Puzle3D.parsear(t)
	_ok("4 la gramática nueva se lee entera sin avisos: 7 piezas y 6 reglas", (r["avisos"] as Array).is_empty() and (r["piezas"] as Array).size() == 7 and (r["reglas"] as Array).size() == 6, str(r["avisos"]))
	var por: Dictionary = {}
	for p in (r["piezas"] as Array):
		por[(p as Puzle3D.Pieza).id] = p
	var b1: Puzle3D.Pieza = por["b1"]
	_ok("4 brasero: rele=<id>, espera y dura se leen", String(b1.p["rele"]) == "b2" and float(b1.p["espera"]) == 2.0 and float(b1.p["dura"]) == 5.0)
	_ok("4 brasero sin claves no trae ninguna (el de siempre)", Puzle3D.parsear("; pieza x brasero 1 1")["piezas"][0].p.is_empty())
	_ok("4 seto mojable=si es true", bool((por["s1"] as Puzle3D.Pieza).p["mojable"]))
	var c1: Puzle3D.Pieza = por["c1"]
	_ok("4 contador: de= es una lista de casillas y minimo un número", (c1.p["de"] as Array) == [Vector2i(2, 3), Vector2i(4, 3)] and float(c1.p["minimo"]) == 2.0)
	_ok("4 cuerda: sostiene=<id> de otra pieza", String((por["cu"] as Puzle3D.Pieza).p["sostiene"]) == "co")
	var senales: Array = []
	for rg in (r["reglas"] as Array):
		senales.append("%s:%s" % [(rg as Dictionary)["nombre"], (rg as Dictionary)["senal"]])
	_ok("4 las señales nuevas se resuelven", senales == ["p1:todos", "p2:no_todos", "p3:rota", "p4:apagado", "p5:consumido", "p6:encendido"], str(senales))
	var p4: Dictionary = (r["reglas"] as Array)[3]
	var ac4: Array = []
	for a in (p4["acciones"] as Array):
		ac4.append("%s.%s" % [(a as Dictionary)["id"], (a as Dictionary)["accion"]])
	_ok("4 las acciones nuevas se resuelven (brasero.encender, seto.encender, cuerda.quemar)", ac4 == ["b2.encender", "s1.encender", "cu.quemar"], str(ac4))
	# Líneas malas: cada una avisa y las demás siguen.
	var m: Dictionary = Puzle3D.parsear("\n".join([
		"; pieza cu cuerda 7 3 sostiene=fantasma",
		"; pieza b1 brasero 2 3 rele=nadie",
		"; pieza c1 contador 3 3 de=2,x",
		"; pieza s1 seto 2 5 mojable=quizas",
		"; pieza cu2 cuerda 8 3 largo=3",
		"; pieza pu puerta 1 1",
		"; puzle mal cuando=pu.rota hace=pu.abrir",
		"; puzle mal2 cuando=cu.rota hace=cu.arder",
	]))
	var av: String = " | ".join(m["avisos"])
	_ok("4 sostiene= / rele= a una pieza que no existe avisan y quitan solo esa clave (la pieza sigue)", av.find("sostiene=fantasma") >= 0 and av.find("rele=nadie") >= 0 and not (m["piezas"][0] as Puzle3D.Pieza).p.has("sostiene") and not (m["piezas"][1] as Puzle3D.Pieza).p.has("rele"), av)
	_ok("4 una lista de casillas mala, un sí/no malo y una clave que no existe avisan y descartan la pieza", av.find("de=2,x") >= 0 and av.find("mojable=quizas") >= 0 and av.find("«largo»") >= 0 and (m["piezas"] as Array).size() == 3, av)
	_ok("4 una señal o una acción que la pieza no tiene avisa (puerta.rota, cuerda.arder)", av.find("pu.rota") >= 0 and av.find("cu.arder") >= 0 and (m["reglas"] as Array).is_empty(), av)
