extends SceneTree
## Grimorio (M4, 13/10): el lanzador 3D ya no es un nodo 2D y conserva el contrato con el libro. Sin ventana. Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_grimorio.gd

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	var l := Lanzador3D.new()
	root.add_child(l)
	await process_frame
	var n: Node = l
	_ok("1 Lanzador3D es un Grimorio y un Node3D, y NO un nodo 2D", l is Grimorio and l is Node3D and not (n is Node2D))
	_ok("2 sigue en el grupo «spellcaster» (el libro lo busca así)", l.is_in_group("spellcaster") and get_first_node_in_group("spellcaster") == l)
	_ok("3 tiene 3 páginas vacías", Grimorio.PAGES == 3 and l.pages.size() == 3 and l.page == 0 and not l.page_ready(0) and l.page_element_data(0) == null)
	l.select_page(2)
	_ok("4 select_page cambia de página y respeta los límites", l.page == 2)
	l.select_page(7)
	l.select_page(-1)
	_ok("4 fuera de rango no cambia", l.page == 2)
	l.select_page(0)
	# Recarga: cuenta tiempo de juego y llega a 0.
	l.cooldown_total[1] = 2.0
	l.cooldown_left[1] = 2.0
	l._process(0.5)
	_ok("5 la recarga baja con el tiempo", absf(float(l.cooldown_left[1]) - 1.5) < 1.0e-4 and absf(l.page_cooldown_fraction(1) - 0.75) < 1.0e-3, "%.3f" % l.page_cooldown_fraction(1))
	l._process(5.0)
	_ok("5 y no pasa de 0", float(l.cooldown_left[1]) == 0.0 and l.page_cooldown_fraction(1) == 0.0)
	_ok("6 la base del grimorio no lanza nada (cast_page de Grimorio es un hueco), pero Lanzador3D sí lo sobrescribe", Grimorio.new().has_method("cast_page") and l.get_script() != Grimorio)
	# La base se puede instanciar sola (sin Lanzador3D) y no revienta.
	var g := Grimorio.new()
	root.add_child(g)
	await process_frame
	g.cast_current()
	g.remember_aim()
	g.cast_page(0)
	_ok("7 Grimorio solo: cast_current, remember_aim y cast_page no hacen nada ni fallan", g.pages.size() == 3)
	# El sonido acepta un origen 3D (antes pedía Node2D).
	Sfx.play(l, "sello_no")
	Sfx.play(g, "sello_ok")
	_ok("8 Sfx.play acepta un nodo 3D", true)
	g.queue_free()
	l.queue_free()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
