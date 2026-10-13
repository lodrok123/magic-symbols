extends SceneTree
## Mundo3D + EstadosSuelo3D (M2, 13/10): la fachada del mundo, sus señales y el dueño del estado «helada», con una maqueta falsa
## y sin ventana. Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_mundo.gd

class MundoFalso extends Node3D:
	const S: float = 2.3
	const ALTO: float = 2.3 * 0.45
	const ALTO_AGUA: float = 2.3 * 0.45 * 0.6
	var _lado: int = 6
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])

var _fallos: int = 0
var _avisos: Array = []
var _impactos: Array = []


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_estados()
	await _fachada()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _estados() -> void:
	var e := EstadosSuelo3D.new()
	var visto: Array = []
	e.cambio.connect(func(c: Vector2i, est: String, si: bool) -> void: visto.append([c, est, si]))
	var c := Vector2i(2, 3)
	_ok("1 una casilla empieza sin estados", not e.tiene(c, "helada") and e.cuantas("helada") == 0)
	_ok("1 poner devuelve true si cambió", e.poner(c, "helada", true) and e.tiene(c, "helada"))
	_ok("1 poner lo mismo no cambia ni avisa", not e.poner(c, "helada", true) and visto.size() == 1)
	_ok("1 los estados son independientes", not e.tiene(c, "electrificada") and e.poner(c, "electrificada", true) and e.tiene(c, "helada"))
	_ok("1 celdas() da una copia", e.celdas("helada") == [c])
	_ok("1 quitar avisa con si = false", e.poner(c, "helada", false) and not e.tiene(c, "helada") and visto.back() == [c, "helada", false])
	_ok("1 un estado desconocido se rechaza", not e.poner(c, "lava", true) and not e.tiene(c, "lava"))
	e.limpiar()
	_ok("1 limpiar lo borra todo sin avisar", e.cuantas("electrificada") == 0 and visto.size() == 3)


func _fachada() -> void:
	var m := MundoFalso.new()
	m._mapa = ["######", "#....#", "#.~~.#", "#.b..#", "#....#", "######"]
	root.add_child(m)
	Lanzador3D.configurar(m)
	var c := Vector2i(2, 2)
	# Sin Mundo3D los estados existen igual (son de Terreno3D): así se prueba el terreno sin nodos.
	_ok("2 sin Mundo3D, Mundo3D.actual es null pero Terreno3D.estados existe", Mundo3D.actual == null and Terreno3D.estados != null)
	Terreno3D.poner_helada(c, true)
	_ok("2 sin Mundo3D, poner_helada y helada() funcionan", Terreno3D.helada(c) and Terreno3D.estados.tiene(c, "helada"))
	Terreno3D.poner_helada(c, false)
	_ok("2 y la quita", not Terreno3D.helada(c))
	# Con Mundo3D.
	var w := Mundo3D.new()
	w.casilla_cambio.connect(func(cc: Vector2i, que: String) -> void: _avisos.append([cc, que]))
	w.impacto.connect(func(p: Vector3, el: String, r: float) -> void: _impactos.append([p, el, r]))
	root.add_child(w)
	_ok("3 al entrar en el árbol es el mundo actual y sus estados son los de Terreno3D", Mundo3D.actual == w and Terreno3D.estados == w.estados)
	_ok("3 terreno responde como Terreno3D", w.terreno.celda_de(Vector3(3.0, 0, 1.0)) == Terreno3D.celda_de(Vector3(3.0, 0, 1.0)))
	_ok("3 agua es la simulación del terreno (null sin ella)", w.agua == null)
	var sim: AguaSim3D = Lanzador3D.montar_agua_sim()
	_ok("3 y la misma instancia cuando existe", w.agua == sim and sim != null)
	_avisos.clear()
	Terreno3D.poner_helada(c, true)
	_ok("4 poner_helada: el dueño es estados y avisa UNA vez «hielo»", w.estados.tiene(c, "helada") and _avisos == [[c, "hielo"]], "%s" % [_avisos])
	_ok("4 helada() es verdad", Terreno3D.helada(c))
	Terreno3D.poner_helada(c, true)
	_ok("4 repetir no avisa otra vez", _avisos.size() == 1)
	# Un nivel nuevo (configurar) borra los estados y no avisa a nadie.
	var c2 := Vector2i(3, 2)
	Terreno3D.poner_helada(c2, true)
	_avisos.clear()
	Lanzador3D.configurar(m)
	_ok("4 configurar borra los estados del nivel anterior sin avisar", not Terreno3D.helada(c2) and not Terreno3D.helada(c) and _avisos.is_empty())
	Terreno3D.poner_helada(c, true)
	_avisos.clear()
	Terreno3D.poner_helada(c, false)
	_ok("4 deshelar avisa «hielo»", _avisos == [[c, "hielo"]] and not Terreno3D.helada(c))
	_avisos.clear()
	Terreno3D.bloquear_celda(Vector2i(1, 1))
	Terreno3D.liberar_celda(Vector2i(1, 1))
	_ok("5 bloquear y liberar avisan «bloqueo»", _avisos == [[Vector2i(1, 1), "bloqueo"], [Vector2i(1, 1), "bloqueo"]])
	_avisos.clear()
	Terreno3D.fijar_altura(Vector2i(4, 4), 1)
	_ok("5 fijar_altura avisa «altura»", _avisos == [[Vector2i(4, 4), "altura"]])
	_avisos.clear()
	w.estados.poner(Vector2i(1, 4), "electrificada", true)
	w.estados.poner(Vector2i(1, 4), "quemada", true)
	_ok("6 los otros estados se traducen: rayo y fuego", _avisos == [[Vector2i(1, 4), "rayo"], [Vector2i(1, 4), "fuego"]], "%s" % [_avisos])
	w.avisar_impacto(Vector3(1, 2, 3), "fuego", 1.5)
	_ok("7 avisar_impacto emite punto, elemento y radio", _impactos == [[Vector3(1, 2, 3), "fuego", 1.5]])
	# M5: fachada para la presentación.
	_avisos.clear()
	w.bloquear_casilla(Vector2i(2, 4), true)
	_ok("9 bloquear_casilla bloquea y avisa «bloqueo»", Terreno3D.bloqueada(Vector2i(2, 4)) and _avisos == [[Vector2i(2, 4), "bloqueo"]])
	w.bloquear_casilla(Vector2i(2, 4), false)
	_ok("9 y la libera", not Terreno3D.bloqueada(Vector2i(2, 4)))
	var obj := Node3D.new()
	_ok("9 punto_activacion de algo que no es activable es INF", Mundo3D.punto_activacion(obj) == Vector3.INF and Mundo3D.punto_activacion(null) == Vector3.INF)
	obj.free()
	_impactos.clear()
	Lanzador3D._efecto_mundo("vapor", Vector3(3, 0, 3), 0.0, 0.0)
	Lanzador3D._efecto_mundo("hielo_desde", Vector3(4, 0, 4), 0.0, 0.0)
	_ok("10 vapor y hielo_desde salen por Mundo3D.impacto, no por campos de la maqueta", _impactos.map(func(i: Array) -> String: return i[1]) == ["vapor", "hielo_desde"], "%s" % [_impactos])
	root.remove_child(w)
	_ok("8 al salir del árbol deja de ser el actual y de escuchar", Mundo3D.actual == null and not Terreno3D.estados.cambio.is_connected(w._estado_cambio))
	_avisos.clear()
	Terreno3D.poner_helada(c, false)
	_ok("8 sin Mundo3D los estados siguen funcionando y nadie recibe avisos", not Terreno3D.helada(c) and _avisos.is_empty())
	w.free()
	m.queue_free()
