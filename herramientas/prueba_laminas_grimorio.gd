extends SceneTree
## godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_laminas_grimorio.gd

var _fallos: int = 0


func _initialize() -> void:
	call_deferred("_probar")


func _fotogramas(n: int) -> void:
	for i in n:
		await process_frame


func _tecla(nodo: Node, metodo: String, codigo: Key) -> void:
	var tecla := InputEventKey.new()
	tecla.keycode = codigo
	tecla.physical_keycode = codigo
	tecla.pressed = true
	nodo.call(metodo, tecla)


func _comprobar(nombre: String, bien: bool) -> void:
	if not bien:
		_fallos += 1
	print(("OK " if bien else "FALLO ") + nombre)


func _probar() -> void:
	var lab := load("res://laboratorios/LabLibroAvanzado.tscn").instantiate() as Node
	root.add_child(lab)
	await process_frame
	var libro := lab.get("_libro") as Control
	for indice in 5:
		_tecla(lab, "_unhandled_key_input", (KEY_F1 + indice) as Key)
		var grimorio := lab.get("_grimorio") as Grimorio
		var datos: Dictionary = libro.call("_libro")
		var av: Dictionary = datos["avanzado"]
		var sellos: int = 2 if indice in [2, 4] else 1
		var arte := datos["arte"] as Texture2D
		var contorno: Rect2 = datos["contorno_hoja"]
		var etiqueta: String = "Lámina %d " % (indice + 1)
		_comprobar(etiqueta + "formato, corona y medallones",
			arte.get_size() == Vector2(1536, 1024) and av["medallones"].size() == sellos and av["huecos"].size() == 6)
		for zona in ["sello", "glifo"]:
			var clave: String = "zona_sellos" if zona == "sello" else "zona_glifos"
			var centro: Vector2 = av[clave]["centro"]
			_comprobar(etiqueta + "zona " + zona,
				contorno.has_point(centro) and libro.call("_zona_de", libro.call("_on_page", centro)) == zona)
		grimorio.place_element("fuego")
		grimorio.place_element("agua")
		_comprobar(etiqueta + "capacidad de sellos", (grimorio.pages[0]["element2"] != Runes.Type.NONE) == (sellos == 2))
		libro.queue_redraw()
		await process_frame
		_tecla(libro, "_input", KEY_2)
		_comprobar(etiqueta + "empieza el giro antes de cambiar", libro.pasando_pagina() and grimorio.page == 0)
		await _fotogramas(9)
		var hoja := libro.get("_hoja_giro") as Node2D
		_comprobar(etiqueta + "hoja usa el arte y el contorno de la edición",
			hoja.visible and hoja.get("_lamina") == arte and hoja.get("_contorno") == contorno and libro.scale.is_equal_approx(Vector2.ONE))
		_comprobar(etiqueta + "la mano sigue el borde",
			libro.mano.punta().is_equal_approx(libro.get("_pasar_mano_punto")))
		if indice == 4 and not OS.get_cmdline_user_args().is_empty():
			await RenderingServer.frame_post_draw
			var ruta: String = OS.get_cmdline_user_args()[0]
			_comprobar("captura del giro", root.get_texture().get_image().save_png(ruta) == OK)
		_tecla(libro, "_input", KEY_3)
		await _fotogramas(32)
		_comprobar(etiqueta + "pulsación encadenada", grimorio.page == 2 and not hoja.visible and not libro.pasando_pagina())
		_tecla(libro, "_input", KEY_1)
		_comprobar(etiqueta + "sentido inverso", libro.get("_pasar_sentido") == -1.0)
		await _fotogramas(20)
		_comprobar(etiqueta + "termina el retroceso", grimorio.page == 0 and not hoja.visible)
		_tecla(libro, "_input", KEY_2)
		libro.call("_close", false)
		_comprobar(etiqueta + "cierre a mitad del giro", grimorio.page == 1 and not hoja.visible and not libro.pasando_pagina())
		await _fotogramas(2)
	print("Fallos: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)
