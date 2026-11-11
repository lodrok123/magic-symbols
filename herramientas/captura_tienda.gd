extends SceneTree
## CAPTURA de la pantalla de tienda (11/11): la del alquimista con el tónico elegido y una compra que falla por oro, y la de la librera tras comprar.
## Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_tienda.gd -- docs/capturas/tienda

var _dir: String = "docs/capturas/tienda"


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
	var ui := TiendaUI.new()
	root.add_child(ui)
	await process_frame
	Estado.i().oro = 72
	Tiendas.abrir("alquimista")
	ui.elegir(6)                       # el tónico de tinta
	await _esperar(20)
	await _guardar("tienda_alquimista.png")
	ui.cantidad = 3
	ui.comprar()                       # 90 de oro con 72: falla y lo dice
	await _esperar(6)
	await _guardar("tienda_sin_oro.png")
	ui.cerrar()
	await _esperar(10)
	Estado.i().oro = 120
	Tiendas.abrir("librera")
	ui.elegir(4)                       # el bulbo de luz
	ui.comprar()
	await _esperar(20)
	await _guardar("tienda_librera.png")
	quit()


func _esperar(n: int) -> void:
	for k in n:
		await process_frame


func _guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var ruta: String = _dir.path_join(nombre)
	root.get_texture().get_image().save_png(ruta)
	print("captura: ", ruta)
