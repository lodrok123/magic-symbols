extends SceneTree
## Estado SEGADA del suelo (14.2 · P3, 16/10, Juego): existe, se acepta sin aviso, avisa solo al cambiar de verdad, no se mezcla con «quemada»
## y la fachada lo reenvía como «siega». Sin ventana.
##   godot --headless --path . --script res://herramientas/prueba_segada.gd

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	var e := EstadosSuelo3D.new()
	var visto: Array = []
	e.cambio.connect(func(c: Vector2i, est: String, si: bool) -> void: visto.append([c, est, si]))
	var c := Vector2i(4, 5)
	_ok("1 «segada» es un estado conocido", EstadosSuelo3D.TODOS.has(EstadosSuelo3D.SEGADA) and EstadosSuelo3D.SEGADA == "segada")
	_ok("1 la fachada lo cuenta como «siega»", String(EstadosSuelo3D.QUE.get("segada", "")) == "siega")
	_ok("2 al empezar nada está segado", not e.tiene(c, EstadosSuelo3D.SEGADA) and e.cuantas(EstadosSuelo3D.SEGADA) == 0)
	_ok("2 poner SEGADA cambia algo", e.poner(c, EstadosSuelo3D.SEGADA, true))
	_ok("2 la casilla queda segada", e.tiene(c, EstadosSuelo3D.SEGADA))
	_ok("2 avisa una vez con (casilla, «segada», true)", visto.size() == 1 and visto[0] == [c, "segada", true], str(visto))
	_ok("3 ponerlo otra vez no avisa", not e.poner(c, EstadosSuelo3D.SEGADA, true) and visto.size() == 1)
	_ok("3 no toca «quemada»", not e.tiene(c, EstadosSuelo3D.QUEMADA))
	e.poner(Vector2i(1, 1), EstadosSuelo3D.SEGADA, true)
	_ok("4 se cuentan y se listan", e.cuantas(EstadosSuelo3D.SEGADA) == 2 and e.celdas(EstadosSuelo3D.SEGADA).has(c))
	_ok("4 se puede quitar (y avisa)", e.poner(c, EstadosSuelo3D.SEGADA, false) and not e.tiene(c, EstadosSuelo3D.SEGADA) and visto.back() == [c, "segada", false])
	e.limpiar()
	_ok("5 limpiar (cambio de nivel) lo borra", e.cuantas(EstadosSuelo3D.SEGADA) == 0)
	# Fachada: lo que oye la maqueta/HUD por Mundo3D.casilla_cambio es «siega».
	var m := Mundo3D.new()
	root.add_child(m)
	var qs: Array = []
	m.casilla_cambio.connect(func(cc: Vector2i, que: String) -> void: qs.append([cc, que]))
	m.estados.poner(Vector2i(2, 2), EstadosSuelo3D.SEGADA, true)
	_ok("6 Mundo3D reenvía casilla_cambio(c, «siega»)", qs.size() == 1 and qs[0][1] == "siega", str(qs))
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
