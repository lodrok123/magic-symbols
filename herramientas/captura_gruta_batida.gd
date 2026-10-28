extends "res://herramientas/escenario_gruta_batida.gd"
## LA GRUTA BATIDA SOLO DE FUEGO (28/10): las fotos de lo nuevo (tótems, marcas, hilos de luz, rejas de barrotes, la barrera nacida tras la reja, la cuerda y el puente,
## el tótem roto). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_gruta_batida.gd -- [carpeta]   (por defecto res://docs/capturas/gruta_batida, con .gdignore)
## Solo mira (teletransporta y despierta los tótems a mano); los contratos los comprueba `escenario_gruta_batida.gd`.

const TAM: float = 9.0
var _dir: String = "res://docs/capturas/gruta_batida"
var _cam: Camera3D = null


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_GRUTA, true)
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	await avanzar(30)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_cam = maqueta.get("_camara") as Camera3D
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	# G1: el tótem que late (la barrera tras la reja, al nacer).
	await _ver(Vector2i(4, 15))
	await _esperar(func() -> bool: return _totem("totem_g1").levantadas >= 1, 6.0)
	await avanzar_s(0.5)
	await _foto("1_g1_totem_late")
	await avanzar_s(3.5)
	await _foto("1_g1_brasero_y_puerta")
	# G2: las rejas, los dos tótems dormidos y sus hilos; uno despierto.
	await _ver(Vector2i(4, 7))
	await _foto("2_g2_rejas_y_totems")
	_totem("totem_g2a").levantar("fuego")
	await avanzar_s(0.8)
	await _foto("2_g2_totem_despierta")
	# G3: el fuego bajo el arquero, al otro lado del agua.
	await _ver(Vector2i(11, 4))
	_totem("totem_g3").levantar("fuego")
	await avanzar_s(0.8)
	await _foto("3_g3_fuego_bajo_arquero")
	# G4: la cuerda y el puente plegado; el puente tendido.
	await _ver(Vector2i(21, 3))
	await _foto("4_g4_cuerda_y_agua")
	_totem("totem_g4").levantar("fuego")
	await avanzar_s(0.8)
	await _foto("4_g4_cuerda_arde")
	await avanzar_s(3.0)
	await _foto("4_g4_puente")
	# G6: el santuario: el tótem de las dos marcas y el tótem roto del atajo.
	await _ver(Vector2i(12, 13))
	await _foto("6_g6_orilla_norte")
	_totem("totem_g6b").levantar("fuego")
	await avanzar_s(0.8)
	await _foto("6_g6_dos_marcas")
	await _ver(Vector2i(10, 14))
	await _foto("6_g6_totem_roto_atajo")
	print("CAPTURA FIN")


func _ver(c: Vector2i) -> void:
	colocar_jugador(c)
	maqueta.set("_tam_camara", TAM)
	if _cam != null:
		_cam.size = TAM
	await avanzar_s(1.2)


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join("%s.png" % nombre))
	print("foto %s" % nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
