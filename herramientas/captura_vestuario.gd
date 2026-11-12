extends SceneTree
## CAPTURAS DEL VESTUARIO Y DE LA LIBRERA VENDIENDO ATUENDOS (12/11, Atuendos): la pestaña Vestuario del menú con el uniforme de Sumicio comprado y
## elegido, y la pantalla de la librera con el atuendo del loberno elegido (su imagen de producto, a la derecha). Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_vestuario.gd -- docs/capturas/vestuario

var _dir: String = "docs/capturas/vestuario"


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = Vector2i(1280, 720)
	Estado.nuevo()
	Flags.nuevo()
	var fondo := ColorRect.new()
	fondo.color = Color("5b7a4a")
	fondo.size = Vector2(1280, 720)
	root.add_child(fondo)
	# El menú, con el uniforme en la mochila y elegido
	Estado.i().agregar("atuendo_sumicio")
	var menu := MenuPestanas.new()
	root.add_child(menu)
	await process_frame
	menu.abrir(MenuPestanas.INDICE_VESTUARIO)
	menu.mover(Vector2.RIGHT)
	await _esperar(20)
	await _guardar("menu_vestuario.png")
	menu.cerrar()
	await _esperar(12)
	menu.queue_free()
	# La librera con el atuendo del loberno elegido
	Estado.i().oro = 200
	var ui := TiendaUI.new()
	root.add_child(ui)
	await process_frame
	Tiendas.abrir("librera")
	var oferta: Array = ui.oferta()
	for i in oferta.size():
		if String((oferta[i] as Dictionary)["objeto"]) == "atuendo_lobo":
			ui.elegir(i)
	await _esperar(20)
	await _guardar("tienda_librera_atuendo.png")
	quit()


func _esperar(n: int) -> void:
	for k in n:
		await process_frame


func _guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var ruta: String = _dir.path_join(nombre)
	root.get_texture().get_image().save_png(ruta)
	print("captura: ", ruta)
