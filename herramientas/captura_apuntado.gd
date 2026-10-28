extends "res://herramientas/prueba_prevision_reaccion.gd"
## FOTOS DEL APUNTADO (28/10): cómo se ve el indicador con cada forma de hechizo, apuntando sin soltar, con la cámara del juego. NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_apuntado.gd -- [carpeta]   (por defecto res://docs/capturas/apuntado/despues)
## Los casos están en la orilla del Bosque (los de la prueba de A2/A3). Se ocultan el HUD y los demás enemigos. El cursor de apuntar se pinta encima de la captura (el del sistema no sale).

var _dir: String = "res://docs/capturas/apuntado/despues"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
		(n as Combate3D).position = Vector3(-500.0, 0.0, -500.0)
	maqueta.set("_tam_camara", 8.0)
	(maqueta.get("_camara") as Camera3D).size = 8.0
	await avanzar_s(1.0)
	var oeste := Vector3(-1, 0, 0)
	_goblin(Vector2i(9, 31))
	await _caso("1_flecha_fuego_a_goblin", Vector2i(12, 31), "fuego", ["flecha"], oeste, 3.0)
	await _caso("2_flecha_tierra_arco", Vector2i(12, 34), "tierra", ["flecha"], oeste, 3.0)
	await _caso("3_flecha_hielo_repetida", Vector2i(12, 34), "hielo", ["flecha", "repeticion", "repeticion"], oeste, 3.0)
	await _caso("4_barrera_tierra_en_punto", Vector2i(12, 34), "tierra", ["barrera"], oeste, 2.0)
	await _caso("5_barrera_fuera_de_alcance", Vector2i(12, 34), "tierra", ["barrera"], oeste, 6.0)
	_goblin(Vector2i(9, 32))
	await _caso("6_rayo_linea", Vector2i(12, 32), "rayo", ["linea_z"], oeste, 3.0)
	await _caso("7_flecha_hacia_el_agua", Vector2i(10, 33), "hielo", ["flecha"], oeste, 3.0)
	await _caso("8_barrera_fuego_fantasma", Vector2i(12, 34), "fuego", ["barrera"], oeste, 2.0)
	await _caso("9_barrera_hielo_fantasma", Vector2i(12, 34), "hielo", ["barrera"], oeste, 2.0)
	await _caso("10_barrera_agua_fantasma", Vector2i(12, 34), "agua", ["barrera"], oeste, 2.0)


func _caso(nombre: String, c_j: Vector2i, elemento: String, glifos: Array, dir: Vector3, casillas: float) -> void:
	await avanzar(4)
	_preparar(c_j, elemento, glifos)
	_mover_puntero(dir, casillas)
	await avanzar(10)
	_ocultar_ui(root)
	await _foto_png(nombre, dir)
	await _soltar_sin_lanzar()
	_limpiar()
	await avanzar(3)


func _foto_png(nombre: String, dir: Vector3) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	# El cursor del ratón (el de apuntar, `Lanzador3D._poner_cursor`) lo dibuja el sistema y no sale en la captura: se pinta encima, donde estaría (el punto apuntado).
	if lanzador.cursor_puesto != "":
		var partes: PackedStringArray = lanzador.cursor_puesto.split("|")
		var cur: Image = Apuntado3D.imagen_cursor(Color.html(partes[0]), partes[1] == "true")
		img.convert(Image.FORMAT_RGBA8)                  # la captura viene sin alfa: el cursor se mezcla con el suyo
		var pc: Vector2 = lanzador.camara.unproject_position(lanzador._punto_vivo)
		img.blend_rect(cur, Rect2i(0, 0, cur.get_width(), cur.get_height()), Vector2i(int(pc.x) - cur.get_width() / 2, int(pc.y) - cur.get_height() / 2))
	var centro: Vector2 = lanzador.camara.unproject_position(jugador.position + dir.normalized() * 1.4 * Terreno3D.casilla + Vector3(0, 0.6, 0))
	var w: int = 720
	var h: int = 460
	var x0: int = clampi(int(centro.x) - w / 2, 0, img.get_width() - w)
	var y0: int = clampi(int(centro.y) - h / 2, 0, img.get_height() - h)
	var rec: Image = img.get_region(Rect2i(x0, y0, w, h))
	rec.resize(int(w * 1.3), int(h * 1.3), Image.INTERPOLATE_LANCZOS)
	rec.save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for hijo in n.get_children():
		if hijo is CanvasLayer:
			(hijo as CanvasLayer).visible = false
		_ocultar_ui(hijo)
