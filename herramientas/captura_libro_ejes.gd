extends SceneTree

## CAPTURA DEL LIBRO REAL con los tres ejes (Juego, 18/10, diario 156/157): el `Spellbook` de verdad con un `Grimorio` (el del juego 3D) y una página con
## ᛁ horizontal (linea_x), ᛁ vertical (linea_z) y ᛏ (levitación = altura). Necesita un renderizador (no vale --headless):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://herramientas/captura_libro_ejes.gd -- <salida.png> [ancho alto]
## Guarda <salida>.png (el libro abierto con la página compuesta) y <salida>_vacia.png (la página vacía, para comparar el cubo 1·1·1 y la chuleta).

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var salida: String = args[0] if args.size() > 0 else "/tmp/libro_ejes.png"
	var ancho: int = int(args[1]) if args.size() > 1 else 1280
	var alto: int = int(args[2]) if args.size() > 2 else 720
	Estado.nuevo()
	Repertoire.libro = "bosque"
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = 0
	root.size = Vector2i(ancho, alto)
	var grimorio: Node = load("res://magia/grimorio.gd").new()
	root.add_child(grimorio)
	var libro: Control = load("res://presentacion/ui/spellbook.gd").new()
	libro.size = Vector2(float(ancho), float(alto))
	root.add_child(libro)
	for _i in range(8):
		await process_frame
	libro.is_open = true
	libro.visible = true
	for _i in range(8):
		libro.queue_redraw()
		await process_frame
	root.get_texture().get_image().save_png(salida.replace(".png", "_vacia.png"))
	grimorio.call("place_element", "fuego")
	grimorio.call("add_sigil", Vector2.RIGHT, "linea_x", 1.0)      # ᛁ horizontal («ancho»)
	grimorio.call("add_sigil", Vector2.DOWN, "linea_z", 1.0)       # ᛁ vertical («fondo»)
	grimorio.call("add_sigil", Vector2.UP, "levitacion", 1.0)      # ᛏ («altura»)
	print("contadores de la página: ", libro.call("_contadores_pagina"))
	for _i in range(10):
		libro.queue_redraw()
		await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(salida)
	print("guardada ", salida, " ", img.get_size())
	quit(0)
