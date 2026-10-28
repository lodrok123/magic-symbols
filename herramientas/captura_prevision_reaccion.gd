extends "res://herramientas/prueba_prevision_reaccion.gd"
## A3 · FOTOS DE LA PREVISIÓN DE LA REACCIÓN: los casos de la prueba (los de A2) apuntando sin soltar, con la cámara del juego. NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_prevision_reaccion.gd -- [carpeta]   (por defecto res://docs/capturas/prevision_reaccion)
## Cada foto es un recorte ampliado alrededor de la jugadora y lo apuntado. Se ocultan el HUD y los demás enemigos del Bosque.

var _dir: String = "res://docs/capturas/prevision_reaccion"


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
	maqueta.set("_tam_camara", 7.0)
	(maqueta.get("_camara") as Camera3D).size = 7.0
	await avanzar_s(1.0)

	_goblin(Vector2i(9, 31))
	await _caso_foto("1_fuego_prende", Vector2i(11, 31), "fuego", ["flecha"])
	_goblin(Vector2i(9, 31), "agua", "")
	await _caso_foto("2_agua_debil_x2", Vector2i(11, 31), "agua", ["flecha"])
	_goblin(Vector2i(9, 31), "", "fuego")
	await _caso_foto("3_fuego_resiste_medio", Vector2i(11, 31), "fuego", ["flecha"])
	_goblin(Vector2i(9, 32), "", "", true, true)
	await _caso_foto("4_escudo_bloquea", Vector2i(11, 32), "fuego", ["flecha"])
	_goblin(Vector2i(8, 31))
	await _caso_foto("5_viento_hunde", Vector2i(10, 31), "viento", ["flecha"])
	await _caso_foto("6_hielo_hiela_agua", Vector2i(9, 33), "hielo", ["flecha"])
	_reactivo("brasero", Vector2i(9, 33))
	await _caso_foto("7_fuego_enciende_brasero", Vector2i(11, 33), "fuego", ["flecha"])
	var b := BloqueEmpujable3D.new()
	b.preparar(Vector2i(9, 34), "piedra", maqueta)
	maqueta.add_child(b)
	_creados.append(b)
	await _caso_foto("8_viento_mueve_bloque", Vector2i(11, 34), "viento", ["flecha"])
	_goblin(Vector2i(9, 31))
	_goblin(Vector2i(9, 32), "fuego", "")
	await _caso_foto("9_rayo_linea_dos_goblins", Vector2i(11, 31), "rayo", ["linea_z"], Vector3(-1, 0, 0.45))


func _caso_foto(nombre: String, c_j: Vector2i, elemento: String, glifos: Array, dir: Vector3 = Vector3(-1, 0, 0)) -> void:
	await avanzar(4)
	var v: PrevisionReaccion3D = await _apuntar(c_j, elemento, glifos, dir)
	await avanzar(6)
	_ocultar_ui(root)
	await _foto_png(nombre, dir)
	print("%s: %s" % [nombre, str(v.pintado.map(func(p): return "%s %s" % [p["que"], p["texto"]])) if v != null else "sin vista"])
	await _soltar_sin_lanzar()
	_limpiar()
	await avanzar(3)


func _foto_png(nombre: String, dir: Vector3) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	var centro: Vector2 = lanzador.camara.unproject_position(jugador.position + dir.normalized() * Terreno3D.casilla + Vector3(0, 0.8, 0))
	var w: int = 640
	var h: int = 420
	var x0: int = clampi(int(centro.x) - w / 2, 0, img.get_width() - w)
	var y0: int = clampi(int(centro.y) - h / 2, 0, img.get_height() - h)
	var rec: Image = img.get_region(Rect2i(x0, y0, w, h))
	rec.resize(int(w * 1.5), int(h * 1.5), Image.INTERPOLATE_LANCZOS)
	rec.save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for hijo in n.get_children():
		if hijo is CanvasLayer:
			(hijo as CanvasLayer).visible = false
		_ocultar_ui(hijo)
