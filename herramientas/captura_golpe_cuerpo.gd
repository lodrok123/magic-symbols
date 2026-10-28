extends "res://herramientas/escenario_base.gd"
## C1 · GOLPE CUERPO A CUERPO: tres fotogramas de la jugadora golpeando a un goblin (anticipación, impacto, recuperación), con la cámara del juego. NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_golpe_cuerpo.gd -- [carpeta]   (por defecto res://docs/capturas/golpe)
## El tiempo va a cámara lenta (`Engine.time_scale`) para que cada fotograma caiga donde se pide; los instantes se miden con lo que le queda al golpe (`Jugador3D._t_pegar`).

var _dir: String = "res://docs/capturas/golpe"
## Lo que queda de golpe (s) en cada foto: anticipación (manos recogidas), justo al impacto, y recuperación.


func _pulsar_f() -> void:
	_tecla(KEY_F, true)
	await process_frame
	await process_frame
	_tecla(KEY_F, false)


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	# un claro llano (7×7) y un goblin delante, mirando a la jugadora
	var ancho: int = int(maqueta.get("_ancho"))
	var alto: int = int(maqueta.get("_alto"))
	var desde: Vector2i = celda_jugador()
	var mejor: Vector2i = Vector2i(-1, -1)
	var dmejor: float = INF
	for y in range(4, alto - 4):
		for x in range(4, ancho - 4):
			var c := Vector2i(x, y)
			var n0: int = Terreno3D.altura_en(c)
			var bien: bool = true
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var v := c + Vector2i(dx, dy)
					if Terreno3D.es_agua(v) or Terreno3D.bloqueada(v) or Terreno3D.altura_en(v) != n0:
						bien = false
						break
				if not bien:
					break
			if bien and Vector2(c - desde).length() < dmejor:
				dmejor = Vector2(c - desde).length()
				mejor = c
	colocar_jugador(mejor)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
		(n as Combate3D).position = Vector3(-500.0, 0.0, -500.0)
	maqueta.set("_tam_camara", 4.5)
	(maqueta.get("_camara") as Camera3D).size = 4.5
	await avanzar_s(1.5)
	jugador.set("_mirada", Vector3(1, 0, 0))
	(jugador.get("pj") as Pj3D).mirar(Vector3(1, 0, 0), 1.0)
	var p: Vector3 = Terreno3D.centro_de(mejor + Vector2i(1, 0), Terreno3D.y_pies(mejor + Vector2i(1, 0)))
	var modelo := Pj3D.new()
	maqueta.add_child(modelo)
	modelo.cargar("goblin_warrior_chibi")
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	modelo.set_alto(0.85)
	modelo.position = p
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.mirada = Vector3(-1, 0, 0)
	modelo.mirar(Vector3(-1, 0, 0), 1.0)
	await avanzar_s(1.0)
	_ocultar_ui(root)
	Engine.time_scale = 0.2
	_tecla(KEY_F, true)
	await process_frame
	await process_frame
	_tecla(KEY_F, false)
	var t_imp: float = Pj3D.golpe_retardo(GolpeCuerpo.DUR)
	var fotos: Array = [["1_anticipacion", GolpeCuerpo.DUR - t_imp * 0.45], ["2_impacto", GolpeCuerpo.DUR - t_imp - 0.01], ["3_recuperacion", 0.10]]
	var n_foto: int = 0
	var seguro: int = 0
	while n_foto < fotos.size() and seguro < 4000:
		seguro += 1
		await process_frame
		var resto: float = float(jugador.get("_t_pegar"))
		var objetivo: float = float(fotos[n_foto][1])
		if objetivo >= 0.0 and resto <= objetivo and jugador.golpeando():
			await _foto(String(fotos[n_foto][0]) + "_resto%03d" % int(round(resto * 1000.0)))
			print("%s: queda %.3f s de golpe · clip %s en %.3f · goblin (%.2f, %.2f) vida %.0f" % [fotos[n_foto][0], resto, jugador.pj.clip_actual(), jugador.pj.arbol().posicion() if jugador.pj.arbol() != null else -1.0,
				g.position.x - p.x, g.position.z - p.z, g.health])
			n_foto += 1
	Engine.time_scale = 1.0
	await avanzar_s(1.0)


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	# Un recorte alrededor de la jugadora y el goblin, ampliado: la cámara del juego los deja pequeños.
	var centro: Vector2 = lanzador.camara.unproject_position(jugador.position + Vector3(2.0, 0.5, 0.0))
	var w: int = 600
	var h: int = 400
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
