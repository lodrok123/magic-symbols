extends "res://herramientas/prueba_prototipo_anidado.gd"
## FOTOS DEL PROTOTIPO DE ANIDACIÓN Y COMBINACIÓN (23/11). Con ventana:
##   godot --fixed-fps 30 --path E:\magic-symbols --script res://herramientas/captura_prototipo_anidado.gd -- <carpeta>

var _dir: String = ""


func foto(nombre: String) -> void:
	if _dir == "":
		return
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("CAPTURA ", nombre)


## Para las fotos: dispara hacia la DERECHA (a la izquierda está la paleta de depuración, que tapaba el goblin y el muro).
func _lanzar_este(fila: int) -> bool:
	colocar_jugador(Vector2i(8, fila))
	await avanzar(2)
	return lanzador.lanzar_pagina_ya(0, jugador.position, Vector3(1, 0, 0))


func _esconder_paleta() -> void:
	var capa: Node = lanzador.get("capa_ui")
	if capa == null:
		return
	for n in capa.get_children():
		var s: Script = n.get_script() as Script
		if s != null and s.resource_path.ends_with("rune_palette.gd"):
			(n as CanvasItem).hide()


func _escenario() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_dir = args[0]
		DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	await cargar("res://laboratorios/LabLibroRojo.tscn", false)
	for _i in range(60):
		if paused:
			break
		await process_frame
	var lr: LibroRojo = root.find_child("LibroRojo", true, false) as LibroRojo
	_proto = root.find_child("PrototipoAnidado", true, false)
	if _proto == null or lr == null:
		return
	lr.cerrar()
	Repertoire.activate_all()
	_esconder_paleta()
	await avanzar(10)
	# 1 · Flecha de fuego → al impactar → barrera de tierra, contra un goblin.
	var g: Combate3D = _goblin(Vector2i(10, 31))
	_pagina("fuego", ["flecha"], _hijo("tierra", ["barrera"]), "al_impactar")
	var nacido: Array = [false]
	_proto.connect("hijo_lanzado", func(_i): nacido[0] = true, CONNECT_ONE_SHOT)
	await _lanzar_este(31)
	await avanzar(12)
	await foto("01_flecha_de_fuego_en_vuelo")
	for _k in range(90):
		if nacido[0]:
			break
		await avanzar(1)
	await avanzar(4)
	await foto("02_al_impactar_nace_el_muro_de_tierra")
	await avanzar_s(1.0)
	await foto("03_el_muro_queda_junto_al_goblin")
	g.queue_free()
	await avanzar(10)
	# 2 · A la vez: flecha de fuego y flecha de agua.
	_pagina("fuego", ["flecha"], _hijo("agua", ["flecha"]), "a_la_vez")
	await _lanzar_este(35)
	await avanzar(12)
	await foto("04_a_la_vez_dos_flechas")
	await avanzar_s(1.5)
	# 3 · La combinación: magma.
	Repertoire.libro = "avanzado"
	_pagina("fuego", ["flecha"], {}, "")
	lanzador.place_element("tierra")
	lanzador.cooldown_left[0] = 0.0
	await _lanzar_este(39)
	await avanzar(12)
	await foto("05_combinacion_flecha_de_magma")
	Repertoire.libro = "bosque"
	lanzador.clear_sequence()
