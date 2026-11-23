extends "res://herramientas/escenario_base.gd"
## DRAGÓN JEFE (21/11): fotos en la Sala del Dragón (un carril al pie del dragón), con la cámara del juego y la interfaz a la vista (el rótulo y la barra son parte de lo que se
## mira): presentación, carga, anillos, aliento, cristales encendidos, caído con el núcleo a tiro y el destello blanco de la silueta. NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_dragon_jefe.gd -- [carpeta] [tamaño de cámara]   (por defecto res://docs/capturas/dragon_jefe y la del juego, 6)

var _dir: String = "res://docs/capturas/dragon_jefe"
var _zoom: float = 0.0


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1].is_valid_float():
		_zoom = float(a[1])
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	await cargar("res://escenas/PruebaSalaDragon.tscn", true)
	if maqueta == null or jugador == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var dr: DragonJefe3D = z.nodo("dragon") as DragonJefe3D
	Repertoire.activate_all()
	(jugador as Jugador3D).vida = 100000.0
	if _zoom > 0.0:
		maqueta.set("_tam_camara", _zoom)
		(maqueta.get("_camara") as Camera3D).size = _zoom
	colocar_jugador(Vector2i(7, 3))
	await avanzar_s(DragonJefe3D.SUBIDA_S * 0.5)
	await _foto("1_sale_del_suelo")
	colocar_jugador(Vector2i(8, 4))
	await avanzar_s(DragonJefe3D.SUBIDA_S * 0.5 + 1.4)
	await _foto("2_rotulo")
	while dr.fase != DragonJefe3D.Fase.CARGA:
		await process_frame
	await avanzar_s(DragonJefe3D.CARGA_S * 0.85)
	await _foto("3_carga_boca_encendida")
	while dr.fase != DragonJefe3D.Fase.ANILLOS:
		await process_frame
	await avanzar_s(DragonJefe3D.ANILLOS_S * 0.45)
	await _foto("4_anillos")
	while dr.fase != DragonJefe3D.Fase.ALIENTO:
		await process_frame
	await avanzar_s(DragonJefe3D.ALIENTO_S * 0.5)
	await _foto("5_aliento_barre_el_carril")
	while dr.fase != DragonJefe3D.Fase.RECUPERA:
		await process_frame
	(dr.puntos[0] as DragonJefe3D.PuntoDebil).encender()
	(dr.puntos[1] as DragonJefe3D.PuntoDebil).encender()
	await avanzar_s(0.4)
	await _foto("6_dos_cristales_encendidos")
	(dr.puntos[2] as DragonJefe3D.PuntoDebil).encender()
	while dr.fase != DragonJefe3D.Fase.EXPUESTO:
		await process_frame
	await avanzar_s(0.6)
	await _foto("7_caido_nucleo_a_tiro")
	dr.golpe_nucleo(load("res://nucleo/fire_rune.tres") as RuneData, null)
	for k in range(4):                        # la silueta dura SILUETA_S y al menos 2 fotogramas dibujados: fotos seguidas
		await _foto("8_golpe_al_nucleo_silueta_blanca_%d" % k)


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)
