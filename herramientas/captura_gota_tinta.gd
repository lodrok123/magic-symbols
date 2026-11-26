extends "res://herramientas/escenario_base.gd"
## GOTA DE TINTA RECOGIBLE (24/11; presentacion/gota_tinta_3d.gd): fotos para compararla con el concepto de Pablo. Sala del Gólem (gólem quieto y lejos).
##   1 «juego»: con la cámara del juego, la gota quieta (con su charco) a varios giros;
##   2 «cerca»: una cámara ortográfica pequeña con la MISMA inclinación, para ver la forma (cuerpo, punta curvada, gotita, remolino, charco);
##   3 «iman»: la jugadora se acerca y la gota vuela hacia ella estirándose, fotograma a fotograma.
## NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_gota_tinta.gd -- [carpeta]

var _dir: String = "res://docs/capturas/gota_tinta"


func _escenario() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] != "":
		_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	await cargar("res://escenas/PruebaSalaGolem.tscn", true)
	if maqueta == null or jugador == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var g: Node3D = z.nodo("golem_a") as Node3D if z != null else null
	if g != null:
		g.set("quieto", true)
		g.position = Terreno3D.centro_de(Vector2i(14, 1), Terreno3D.y_pies(Vector2i(14, 1)))
	var j: Jugador3D = jugador as Jugador3D
	colocar_jugador(Vector2i(4, 6))
	await avanzar_s(1.0)
	if lanzador.tinta != null:
		lanzador.tinta.actual = 10.0                  # que le quepa: con la barra llena la gota no se imanta
	var pos: Vector3 = j.position + Vector3(2.6, 0.0, -1.5)       # suelo despejado a 3 u de ella (fuera del imán, 2,4 u) y por encima de la fila de rocas
	var b: Combate3D.Botin3D = Combate3D.Botin3D.soltar_recogible(maqueta.get("mundo") if maqueta.get("mundo") is Node3D else j.mundo, j, Combate3D.Botin3D.TIPO_TINTA, 6.0, pos)
	b.dura = 60.0
	await avanzar_s(0.9)
	for i in range(4):
		await _foto(b, "juego_%d" % i)
		await avanzar_s(0.45)
	# De cerca, con la misma inclinación que la cámara del juego.
	var cam_juego: Camera3D = root.get_viewport().get_camera_3d()
	var cerca := Camera3D.new()
	cerca.projection = Camera3D.PROJECTION_ORTHOGONAL
	cerca.size = 1.1
	(maqueta as Node).add_child(cerca)
	var atras: Vector3 = cam_juego.global_transform.basis.z if cam_juego != null else Vector3(0, 0.866, 0.5)
	for i in range(4):
		cerca.global_position = b.global_position + atras * 6.0
		cerca.look_at(b.global_position, Vector3.UP)
		cerca.current = true
		await _foto(b, "cerca_%d" % i, false)
		await avanzar_s(0.4)
	if cam_juego != null:
		cam_juego.current = true
	cerca.queue_free()
	# El imán: ella se pone a 2 u y la gota vuela hacia ella.
	j.position = b.position + Vector3(-2.0, -0.3, 0.0)
	for i in range(8):
		await avanzar(1)
		if not is_instance_valid(b):
			break
		await _foto(b, "iman_%d" % i)
	print("fotos en ", _dir)


## Foto: la pantalla reducida y, al lado, un recorte de 360 × 360 alrededor de la gota (con `recorte` false, la pantalla entera).
func _foto(b: Node3D, archivo: String, recorte: bool = true) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	if not recorte or not is_instance_valid(b):
		img.save_png(_dir.path_join(archivo + ".png"))
		return
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var c: Vector2 = cam.unproject_position(b.global_position)
	var w: int = 360
	var x0: int = clampi(int(c.x) - w / 2, 0, img.get_width() - w)
	var y0: int = clampi(int(c.y) - w / 2, 0, img.get_height() - w)
	var rec: Image = img.get_region(Rect2i(x0, y0, w, w))
	var peq: Image = img.duplicate()
	peq.resize(640, 360)
	var hoja := Image.create(640 + w, 360, false, img.get_format())
	hoja.blit_rect(peq, Rect2i(0, 0, 640, 360), Vector2i(0, 0))
	hoja.blit_rect(rec, Rect2i(0, 0, w, w), Vector2i(640, 0))
	hoja.save_png(_dir.path_join(archivo + ".png"))
