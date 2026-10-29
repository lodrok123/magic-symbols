extends SceneTree

## CAPTURA H7 (29/10, PLAN_SISTEMA_HECHIZOS §3): el libro de verdad (`Spellbook` + el `Lanzador3D` con su tinta) enseñando, SIN lanzar, lo que cuesta y hace la página y lo que aportó el último glifo.
## Necesita ventana (no vale --headless):
##   Godot --path . --script res://herramientas/captura_resumen_libro.gd -- [carpeta] [ancho alto]
## Guarda en <carpeta> (por defecto docs/capturas/resumen_libro): 1 página vacía · 2 fuego + flecha · 3 + ᛁ · 4 + ᛜ (nace donde apuntas) · 5 + un glifo aparcado (aviso) · 6 sin tinta (aviso en rojo).

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var carpeta: String = args[0] if args.size() > 0 else "res://docs/capturas/resumen_libro"
	var ancho: int = int(args[1]) if args.size() > 1 else 1280
	var alto: int = int(args[2]) if args.size() > 2 else 720
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	Estado.nuevo()
	Repertoire.libro = "bosque"
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = 0
	root.size = Vector2i(ancho, alto)
	var lanzador := Lanzador3D.new()
	lanzador.tinta = Tinta.new()
	root.add_child(lanzador)
	var libro: Control = load("res://presentacion/ui/spellbook.gd").new()
	libro.size = Vector2(float(ancho), float(alto))
	root.add_child(libro)
	for _i in range(8):
		await process_frame
	Repertoire.activate_all()                                         # otra vez: el lanzador al nacer deja el repertorio como lo encuentra la partida
	libro.is_open = true
	libro.visible = true
	await _foto(libro, carpeta + "/1_vacia.png")
	lanzador.place_element("fuego")
	lanzador.add_sigil(Vector2.DOWN, "flecha", 1.0)
	await _foto(libro, carpeta + "/2_fuego_flecha.png")
	lanzador.add_sigil(Vector2.LEFT, "linea_x", 1.0)                   # ᛁ
	await _foto(libro, carpeta + "/3_fuego_flecha_linea.png")
	lanzador.add_sigil(Vector2.UP, "barrera", 1.0)                     # ᛜ: nace donde apuntas
	await _foto(libro, carpeta + "/4_fuego_flecha_linea_barrera.png")
	lanzador.add_sigil(Vector2.RIGHT, "retardo", 1.0)                  # un glifo aparcado: «Aún sin uso»
	await _foto(libro, carpeta + "/5_con_aviso_sin_uso.png")
	lanzador.undo_last()
	lanzador.tinta.actual = 4.0
	lanzador.tinta.frascos = 0
	await _foto(libro, carpeta + "/6_sin_tinta.png")
	quit(0)


func _foto(libro: Control, ruta: String) -> void:
	for _i in range(10):
		libro.queue_redraw()
		await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(ruta))
	print("guardada ", ruta, " ", img.get_size())
