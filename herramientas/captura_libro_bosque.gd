extends SceneTree

## CAPTURA DEL LIBRO «BOSQUE» (Juego, 16/10): dibuja el libro con N huecos abiertos y guarda un PNG. Necesita un renderizador (no vale --headless):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://herramientas/captura_libro_bosque.gd -- <huecos> <salida.png>

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var huecos: int = int(args[0]) if args.size() > 0 else 2
	var salida: String = args[1] if args.size() > 1 else "/tmp/libro.png"
	Estado.nuevo()
	Repertoire.libro = "bosque"
	Repertoire.max_sigils_per_page = huecos
	Repertoire.set_active(PackedStringArray(["fuego", "agua"]), PackedStringArray(["flecha", "barrera", "linea"]))
	root.size = Vector2i(1280, 720)
	var caster: Node = load("res://magia/spellcaster.gd").new()
	caster.add_to_group("spellcaster")
	root.add_child(caster)
	var libro: Control = load("res://presentacion/ui/spellbook.gd").new()
	libro.size = Vector2(1280.0, 720.0)
	root.add_child(libro)
	await process_frame
	libro.is_open = true
	libro.visible = true
	if caster.has_method("place_element"):
		caster.call("place_element", "fuego")
	if caster.has_method("place_sigil"):
		caster.call("place_sigil", "flecha")
	libro.queue_redraw()
	for i in 4:
		await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(salida)
	print("guardada ", salida, " ", img.get_size())
	quit(0)
