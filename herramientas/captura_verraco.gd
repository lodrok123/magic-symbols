extends "res://herramientas/escenario_base.gd"
## Fotos del VERRACO (X2 de PLAN_COMBATE, 22/11) en la Sala del Verraco: quieto, en pose con su línea en el suelo, embistiendo, agrietado tras chocar y partido con el núcleo.
## NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_verraco.gd -- [carpeta]   (por defecto res://docs/capturas/verraco)

var _dir: String = "res://docs/capturas/verraco"
var vr: Verraco3D = null


func _foto(archivo: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(archivo + ".png"))          # la pantalla entera: la cámara sigue a la jugadora y él queda a un lado
	print("foto ", archivo, "  fase ", vr.fase, "  grietas ", vr.grietas)


func _escenario() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] != "":
		_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	await cargar("res://escenas/PruebaSalaVerraco.tscn", true)
	if maqueta == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	vr = z.nodo("verraco") as Verraco3D
	(jugador as Jugador3D).vida = 1.0e9
	maqueta.set("_tam_camara", 9.0)
	(maqueta.get("_camara") as Camera3D).size = 9.0
	colocar_jugador(Vector2i(2, 2))
	vr.global_position = Terreno3D.centro_de(Vector2i(6, 2), Terreno3D.y_pies(Vector2i(6, 2)))
	vr.set_physics_process(false)
	await avanzar_s(0.6)
	await _foto("01_quieto")
	vr._t = 99.0
	vr.set_physics_process(true)
	while vr.fase != Verraco3D.Fase.POSE:
		await process_frame
	await avanzar_s(0.3)
	await _foto("02_pose")
	while vr.fase != Verraco3D.Fase.EMBISTE:
		await process_frame
	await avanzar_s(0.12)
	await _foto("03_embiste")
	while vr.fase != Verraco3D.Fase.ATURDIDO:
		await process_frame
	await avanzar_s(0.3)
	await _foto("04_agrietado")
	vr.grietas = Verraco3D.GRIETAS_NUCLEO - 1
	vr._pintar_grietas()
	await avanzar_s(Verraco3D.ATURDIDO_S)
	colocar_jugador(Vector2i(2, 2))
	vr._quitar_aviso()
	vr.global_position = Terreno3D.centro_de(Vector2i(6, 2), Terreno3D.y_pies(Vector2i(6, 2)))
	vr._cambiar(Verraco3D.Fase.ACECHA)
	vr._t = 99.0
	while vr.fase != Verraco3D.Fase.EXPUESTO:
		await process_frame
	await avanzar_s(0.4)
	await _foto("05_partido_nucleo")
