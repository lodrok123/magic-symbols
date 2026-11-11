extends SceneTree
## PANTALLA DE TIENDA (11/11, `presentacion/ui/tienda_ui.gd`): se abre sola con `Tiendas.abrir`, pausa el mundo, se maneja con teclado y ratón y compra
## con `Tiendas.comprar`.
##   godot --headless --path . --script res://herramientas/prueba_tienda_ui.gd

var _fallos: int = 0


func _initialize() -> void:
	call_deferred("_probar")


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	if not bien:
		_fallos += 1
	print(("OK    " if bien else "FALLO ") + nombre + ("  " + info if info != "" else ""))


func _tecla(ui: TiendaUI, k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	ui._input(ev)


func _probar() -> void:
	Estado.nuevo()
	Flags.nuevo()
	var ui := TiendaUI.new()
	root.add_child(ui)
	await process_frame
	var e: Estado = Estado.i()
	e.oro = 50
	_ok("1 cerrada al empezar", not ui.abierta)
	Tiendas.abrir("alquimista")
	await process_frame
	_ok("1 Tiendas.abrir la abre con la oferta del alquimista y pausa el mundo", ui.abierta and ui.tienda == "alquimista" and ui.oferta().size() == Tiendas.oferta("alquimista").size() and paused)
	_ok("1 empieza en la primera fila, cantidad 1", ui.elegido == 0 and ui.cantidad == 1 and String(ui.fila_elegida()["objeto"]) == "pocion")
	_tecla(ui, KEY_DOWN)
	_tecla(ui, KEY_DOWN)
	_ok("2 ↓ baja de fila", ui.elegido == 2 and String(ui.fila_elegida()["objeto"]) == "antidoto")
	_tecla(ui, KEY_UP)
	_ok("2 ↑ sube", ui.elegido == 1)
	_tecla(ui, KEY_RIGHT)
	_ok("2 → sube la cantidad", ui.cantidad == 2)
	_tecla(ui, KEY_LEFT)
	_tecla(ui, KEY_LEFT)
	_ok("2 ← no baja de 1", ui.cantidad == 1)
	# Comprar: la poción grande (35) con 50 de oro.
	_tecla(ui, KEY_ENTER)
	_ok("3 Enter compra: cobra y mete en la mochila, y lo dice", e.oro == 15 and e.cuenta("pocion_grande") == 1 and ui.mensaje_bien and ui.mensaje.contains("Poción grande"), ui.mensaje)
	_tecla(ui, KEY_ENTER)
	_ok("3 sin oro no compra y dice cuánto falta", e.oro == 15 and e.cuenta("pocion_grande") == 1 and not ui.mensaje_bien and ui.mensaje.contains("20"), ui.mensaje)
	# Existencias: el tónico (3) no deja pedir más de las que quedan.
	e.oro = 500
	ui.elegir(6)
	for _i in range(6):
		_tecla(ui, KEY_RIGHT)
	_ok("4 la cantidad no pasa de lo que queda (3 tónicos)", String(ui.fila_elegida()["objeto"]) == "tonico_tinta" and ui.cantidad == 3)
	_tecla(ui, KEY_SPACE)
	_ok("4 al agotarse, el tónico desaparece de la lista", e.cuenta("tonico_tinta") == 3 and not _tiene(ui, "tonico_tinta"))
	# Ratón: clic en una fila la elige; otro clic, compra.
	var antes: int = e.cuenta("baya")
	var fila_baya: int = _indice(ui, "baya")
	ui.elegir(fila_baya)
	var v: int = fila_baya - ui._scroll
	var centro: Vector2 = TiendaUI._rect_fila(v).get_center()
	ui._clic(centro)
	_ok("5 clic sobre la fila elegida la compra", e.cuenta("baya") == antes + 1)
	ui._clic(TiendaUI._rect_mas().get_center())
	ui._clic(TiendaUI._rect_mas().get_center())
	ui._clic(TiendaUI._rect_comprar().get_center())
	_ok("5 + + y Comprar: 3 más", e.cuenta("baya") == antes + 4, str(e.cuenta("baya")))
	# Cerrar.
	_tecla(ui, KEY_ESCAPE)
	await process_frame
	_ok("6 Esc cierra y quita la pausa", not ui.abierta and not paused)
	Tiendas.abrir("no_existe")
	await process_frame
	_ok("6 una tienda que no existe no la abre", not ui.abierta)
	Tiendas.abrir("librera")
	await process_frame
	_ok("6 la librera tiene la suya", ui.abierta and ui.tienda == "librera" and String(ui.fila_elegida()["objeto"]) == "flor_silvestre")
	ui.cerrar()
	ui.queue_free()
	await process_frame
	Estado.nuevo()
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)


func _indice(ui: TiendaUI, id: String) -> int:
	for k in range(ui.oferta().size()):
		if String(ui.oferta()[k]["objeto"]) == id:
			return k
	return -1


func _tiene(ui: TiendaUI, id: String) -> bool:
	return _indice(ui, id) >= 0
