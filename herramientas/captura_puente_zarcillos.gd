extends SceneTree
## 23/11: CAPTURAS de la secuencia del PUENTE DE ZARCILLOS en la escena de prueba (escenas/PruebaPuenteZarcillos.tscn): antes / nudo abriéndose / tejiendo / final. Necesita ventana (GPU):
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_puente_zarcillos.gd -- <carpeta_salida>
## Mueve la cámara a mano (el montaje de la prueba la lleva a la jugadora) y lanza el agua a la casilla del bancal por la misma puerta que el hechizo (ReaccionesSuelo3D).

const S: float = 2.3
const BANCAL: Vector2i = Vector2i(7, 8)
const FLAG: String = "puentezarcillos.sala1.germino"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var salida: String = args[0] if args.size() > 0 else "docs/capturas/puente_zarcillos"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(salida) if salida.begins_with("res://") else salida)
	Flags.i().quitar(FLAG)             # el guardado de una captura anterior dejaría el puente ya tendido
	var m: Node3D = (load("res://escenas/PruebaPuenteZarcillos.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for _i in 90:
		await process_frame
	_ocultar_ui(root)
	await _camara(m)
	await _foto(salida + "/1_antes.png")
	var pz: Puzle3D = m.get_node("Puzles") as Puzle3D
	var bp: Puzle3D.BancalPuzle = pz.nodo("hueco") as Puzle3D.BancalPuzle
	var pq: PuenteRaices3D = pz.nodo("trama") as PuenteRaices3D
	Engine.time_scale = 0.12           # la escena rinde pocos fotogramas por segundo: a cámara lenta cada foto cae donde toca de la animación
	var r: Dictionary = ReaccionesSuelo3D._aplicar_celda("agua", BANCAL)
	print("agua: ", r)
	# 7 · primer plano a mitad del pulso de savia (fondo despierto, subiendo por las raíces de conexión)
	while bp._savia_v < 0.45:
		await process_frame
	await _camara(m, Vector3(7.5 * S, 0.45, 8.5 * S - 0.3), 2.4)
	await _foto(salida + "/7_savia.png")
	await _camara(m)
	# 2 · el nudo acaba de abrirse (se espera a que lo esté: el reloj de las animaciones no es el de la pared)
	while not bp.nudo_abierto:
		await process_frame
	for _i in 3:
		await process_frame
	await _foto(salida + "/2_nudo_abriendose.png")
	# 3 · tejiendo: el segundo tramo a mitad de crecer
	while float((pq._tramos[1]["mat"] as ShaderMaterial).get_shader_parameter("frente")) < 0.7:
		await process_frame
	await _foto(salida + "/3_tejiendo.png")
	# 4 · final: anclaje cerrado y un rato más
	while not pq.anclaje_cerrado:
		await process_frame
	Engine.time_scale = 1.0
	await create_timer(2.0).timeout
	await _foto(salida + "/4_final.png")
	await _camara(m, Vector3(7.5 * S, 0.3, 4.9 * S), 5.0)       # 5 · la otra orilla: el anclaje
	await create_timer(0.3).timeout
	await _foto(salida + "/5_anclaje.png")
	await _camara(m, Vector3(7.5 * S, 0.45, 8.5 * S - 0.3), 2.4)    # 6 · primer plano del hueco lleno y el nudo
	await create_timer(0.3).timeout
	await _foto(salida + "/6_hueco.png")
	await _camara(m, Vector3(7.5 * S + 0.5, 0.3, 8.5 * S - 0.25), 2.6)       # 8 · muy cerca de la boca del surco: contacto con el labio, bajada por fuera y entrada en el nudo
	await create_timer(0.3).timeout
	await _foto(salida + "/8_boca.png")
	Flags.i().quitar(FLAG)             # no dejar la flag en el guardado de quien lo ejecute
	Flags.i().guardar()
	quit()


func _camara(m: Node3D, foco: Vector3 = Vector3(7.5 * S, 0.3, 7.2 * S), tam: float = 6.0) -> void:
	m.set("_jugador", null)
	m.set("_foco", foco)
	m.set("_tam_camara", tam)
	m.get("_camara").size = tam
	m.call("_colocar_camara")
	var luz: Node = m.get_node_or_null("LuzPortatilCueva")      # la luz de la jugadora (no hay jugadora): se deja fija sobre el puente
	if luz is OmniLight3D:
		luz.set_process(false)
		luz.set_physics_process(false)
		(luz as OmniLight3D).global_position = Vector3(7.5 * S, 4.5, 7.0 * S)
		(luz as OmniLight3D).light_energy = 2.5
		(luz as OmniLight3D).omni_range = 14.0
	for _i in 3:
		await process_frame


func _foto(ruta: String) -> void:
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ruta)
	print("guardada ", ruta, " ", img.get_size())


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
