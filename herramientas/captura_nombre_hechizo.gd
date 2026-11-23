extends "res://herramientas/escenario_base.gd"
## H16 · FOTOS DEL NOMBRE DE LA PÁGINA EN EL HUD (22/11, sesión HECHIZOS). Con ventana:
##   godot --fixed-fps 30 --path E:\magic-symbols --script res://herramientas/captura_nombre_hechizo.gd -- <carpeta>
## 1) recién cambiada la página: el nombre en grande; 2) a los 2 s: pequeño; 3) otra página; 4) con un nombre puesto por la jugadora.

var _dir: String = ""


func foto(nombre: String) -> void:
	if _dir == "":
		return
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre + ".png"))
	print("CAPTURA ", nombre)


func _pagina(i: int, elemento: String, glifos: Array) -> void:
	lanzador.select_page(i)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))


func _escenario() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_dir = args[0]
		DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = 8
	for enemigo in get_nodes_in_group("combate3d"):
		enemigo.set("quieto", true)
		enemigo.position = Vector3(-500, 0, -500)
	colocar_jugador(Vector2i(6, 24))
	await avanzar(8)
	_pagina(0, "fuego", ["flecha", "flecha"])
	_pagina(1, "agua", ["barrera"])
	_pagina(2, "tierra", ["suelo"])
	lanzador.select_page(0)
	await avanzar(3)
	_ok("página 1: «Flecha de fuego larga»", lanzador.nombre_pagina(0) == "Flecha de fuego larga", lanzador.nombre_pagina(0))
	await foto("01_grande_al_cambiar")
	await avanzar_s(2.0)
	await foto("02_pequeno_a_los_2s")
	lanzador.select_page(1)
	await avanzar(3)
	_ok("página 2: «Escudo de agua»", lanzador.nombre_pagina(1) == "Escudo de agua", lanzador.nombre_pagina(1))
	await foto("03_otra_pagina")
	lanzador.renombrar_pagina(1, "Paraguas")
	await avanzar_s(2.0)
	await foto("04_nombre_propio")
	lanzador.renombrar_pagina(1, "")
	await avanzar(2)
