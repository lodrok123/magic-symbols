extends "res://herramientas/escenario_base.gd"
## E3 · GÓLEM DE PIEDRA: tres fotos en la sala (armado, el aviso del golpe, expuesto con el núcleo brillando), con la cámara del juego. NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_golem_combate.gd -- [carpeta]   (por defecto res://docs/capturas/golem_combate)

var _dir: String = "res://docs/capturas/golem_combate"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	await cargar("res://escenas/PruebaSalaGolem.tscn", true)
	if maqueta == null or jugador == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var g: Golem3D = z.nodo("golem_a") as Golem3D
	_ocultar_ui(root)
	var celda: Vector2i = Vector2i(7, 6)
	g.position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))
	g.casa = g.position
	colocar_jugador(Vector2i(5, 6))
	(jugador as Jugador3D).vida = 100000.0
	g.quieto = true
	maqueta.set("_tam_camara", 4.5)
	(maqueta.get("_camara") as Camera3D).size = 4.5
	await avanzar_s(1.5)
	await _foto("1_armado")
	# El aviso: se le deja pegar (ya no quieto) y se saca la foto a mitad del aviso.
	g.quieto = false
	var av: AvisoAtaque3D = null
	var n: int = 0
	while av == null and n < 400:
		await process_frame
		n += 1
		for x in get_nodes_in_group(AvisoAtaque3D.GRUPO):
			if (x as AvisoAtaque3D).dueno == g:
				av = x
	while av != null and is_instance_valid(av) and av.queda() > 0.5:
		await process_frame
	await _foto("2_aviso")
	while g.g_estado == "atacando":
		await process_frame
	g.quieto = true
	while not g.vulnerable():
		await process_frame
	await avanzar_s(0.7)
	await _foto("3_expuesto_nucleo_brillando")
	print("brillo %.2f · estado %s · vulnerable %s" % [g.brillo_nucleo(), g.g_estado, g.vulnerable()])


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	var centro: Vector2 = lanzador.camara.unproject_position(jugador.position + Vector3(2.5, 0.8, 0.0))
	var w: int = 700
	var h: int = 450
	var x0: int = clampi(int(centro.x) - w / 2, 0, img.get_width() - w)
	var y0: int = clampi(int(centro.y) - h / 2, 0, img.get_height() - h)
	var rec: Image = img.get_region(Rect2i(x0, y0, w, h))
	rec.resize(w * 2, h * 2, Image.INTERPOLATE_LANCZOS)
	rec.save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
