extends "res://herramientas/escenario_base.gd"
## Fotos de la COCA (enemigos/coca_3d.gd; prototipo de primitivas, 27/11) en la Sala de la Coca, DE LADO (cámara ortogonal propia, +Z hacia la derecha): erguida, recogida (la pose),
## lanzada con el chorro, varada con la runa encendida, calmada y, desde arriba, una poza tapada por un bloque de tierra REAL (hechizo de verdad) junto a otra libre con sus burbujas. Se sostiene cada pose alargando el tiempo de su fase (las `static var` de Coca3D) y se restauran al acabar.
## NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_coca.gd -- [carpeta]   (por defecto res://docs/capturas/coca)

var _dir: String = "res://docs/capturas/coca"
var co: Coca3D = null
var cam: Camera3D = null


func _foto(archivo: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(archivo + ".png"))
	print("foto ", archivo, "  fase ", co.fase, "  runa ", snappedf(co._runa_luz, 0.01), "  ", img.get_size())


## La cámara de lado, mirando a +X, centrada en la coca (desplazada `adelante` u hacia +Z, y `alto` de alto).
func _encuadrar(tam: float, adelante: float, sube: float = 0.0) -> void:
	var c: Vector3 = co.global_position
	cam.size = tam
	cam.global_position = Vector3(maxf(c.x - 5.5, 2.4), c.y + 1.7 + sube, c.z + adelante)
	cam.look_at(Vector3(c.x, c.y + 1.7, c.z + adelante), Vector3.UP)
	cam.make_current()


func _poner(c: Vector2i, por_bajio: bool) -> void:
	co._quitar_aviso()
	co._cambiar(Coca3D.Fase.SUMERGIDA)
	co.reiniciar()
	co._salir_por(c, por_bajio)


func _escenario() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] != "":
		_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir) if _dir.begins_with("res://") else _dir)
	Flags.nuevo()
	Estado.nuevo()
	await cargar("res://escenas/PruebaSalaCoca.tscn", true)
	if maqueta == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	co = z.nodo("coca") as Coca3D
	(jugador as Jugador3D).vida = 1.0e9
	Repertoire.activate_all()                                # el hechizo real de la foto 06 (tierra + barrera) necesita el repertorio completo
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.05
	cam.far = 200.0
	maqueta.add_child(cam)
	# Se guardan los tiempos y se sostiene cada pose.
	var viejo: Array = [Coca3D.ACECHA_S, Coca3D.POSE_S, Coca3D.CHORRO_S, Coca3D.VARADA_S, Coca3D.BAJO_AGUA_S]
	Coca3D.BAJO_AGUA_S = 999.0
	Coca3D.ACECHA_S = 999.0
	colocar_jugador(Vector2i(8, 8))                          # a un lado de la línea del chorro (5,4)→(5,8) para que no estorbe en la foto
	# 6 - una poza tapada por un bloque de tierra REAL (la Coca sigue sumergida: BAJO_AGUA_S = 999) y otra libre con sus burbujas. Se hace primero para que la Coca no estorbe.
	var tapada: Vector2i = Vector2i(7, 5)
	colocar_jugador(Vector2i(7, 8))
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element("tierra")
	lanzador.place_sigil("barrera")
	lanzador.cooldown_left[0] = 0.0
	var salio: bool = lanzador.lanzar_pagina_ya(0, Terreno3D.centro_de(tapada, Terreno3D.y_pies(tapada)), Vector3(0, 0, -1))
	await avanzar_s(1.2)
	colocar_jugador(Vector2i(12, 8))
	cam.size = 11.0
	var cc: Vector3 = Terreno3D.centro_de(Vector2i(7, 5), 0.6)
	cam.global_position = cc + Vector3(-3.0, 11.0, 9.0)
	cam.look_at(cc + Vector3(0.0, 0.0, 0.5), Vector3.UP)
	cam.make_current()
	await avanzar_s(0.3)
	print("poza tapada: lanzo ", salio, " | libre ", co.poza_libre(tapada), " | otras libres ", co.pozas_libres())
	await _foto("06_poza_tapada")
	for bq in lanzador._bloques.duplicate():
		lanzador._deshacer_bloque(bq)
	for sv in lanzador._solideces_v2.duplicate():
		if is_instance_valid(sv):
			lanzador._solideces_v2.erase(sv)
			(sv as Node).queue_free()
	await avanzar_s(4.0)                                     # el agua vuelve a la poza
	colocar_jugador(Vector2i(8, 8))
	# 1 · erguida
	_poner(Vector2i(5, 4), false)
	await avanzar_s(Coca3D.EMERGE_S + 0.6)
	_encuadrar(7.0, -0.3)
	await avanzar_s(0.2)
	await _foto("01_erguida")
	# 2 · recogida (la pose: quieta con el aviso en el suelo)
	Coca3D.POSE_S = 999.0
	colocar_jugador(Vector2i(5, 8))
	co._empezar_pose()
	await avanzar_s(0.7)
	_encuadrar(9.0, 1.2)
	await _foto("02_recogida")
	# 3 · lanzada con el chorro
	Coca3D.CHORRO_S = 999.0
	colocar_jugador(Vector2i(8, 8))
	co._quitar_aviso()                                       # con POSE_S alargado el aviso seguiria vivo (999 s): en el juego acaba solo (0,6 s) justo cuando empieza el chorro
	co._empezar_chorro()
	await avanzar_s(0.7)
	_encuadrar(10.0, 2.6)
	await _foto("03_lanzada_chorro")
	# 4 · varada con la runa encendida (por el bajío)
	Coca3D.VARADA_S = 999.0
	colocar_jugador(Vector2i(3, 8))
	_poner(BAJIO, true)
	await avanzar_s(Coca3D.EMERGE_S + 1.5)
	_encuadrar(6.0, 1.3, 4.5)                                  # algo desde arriba: tendida entre la hierba, la runa mira hacia arriba
	await _foto("04_varada")
	# 5 · calmada
	co.recibir(co.vida)
	await avanzar_s(Coca3D.T_CALMA + 0.8)
	_encuadrar(6.0, 0.4, 2.5)
	await _foto("05_calma")
	Coca3D.ACECHA_S = viejo[0]
	Coca3D.POSE_S = viejo[1]
	Coca3D.CHORRO_S = viejo[2]
	Coca3D.VARADA_S = viejo[3]
	Coca3D.BAJO_AGUA_S = viejo[4]


const BAJIO: Vector2i = Vector2i(3, 6)
