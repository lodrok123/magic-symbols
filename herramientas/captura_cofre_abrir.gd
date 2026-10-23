extends "res://herramientas/escenario_base.gd"
## LA SECUENCIA DEL COFRE LEGENDARIO CON EL CLIP `abrir_cofre` de la jugadora (24/10). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_cofre_abrir.gd -- [carpeta]   (por defecto res://docs/capturas/clips_jugadora)
## Fotogramas de la secuencia a tiempos fijos (T_ONDA = cuando la tapa empieza a girar y las manos llegan abajo) y, de cada uno, el estado de la jugadora, la altura de su mano y la tapa.

const RUTA: String = "res://escenas/PruebaCueva.tscn"
const CUANDO: Array = [0.2, 0.5, 0.8, 1.1, 1.6, 2.2, 2.8, 3.4]

var _dir: String = "res://docs/capturas/clips_jugadora"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	await avanzar(30)
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var tesoro: Puzle3D.CofrePuzle = z.nodo("tesoro") as Puzle3D.CofrePuzle
	var receptor: ReceptorPulso3D = z.nodo("ante_cofre") as ReceptorPulso3D
	receptor.activar()
	colocar_jugador(Vector2i(13, 14))
	maqueta.set("_tam_camara", 10.0)
	(maqueta.get("_camara") as Camera3D).size = 10.0
	await avanzar_s(1.5)
	_ocultar_ui(root)
	Engine.time_scale = 0.5
	_ok("el cofre se abre y arranca la secuencia", tesoro.abrir())
	var seq: SecuenciaCofreLegendario3D = tesoro.secuencia
	var pj: Pj3D = jugador.pj
	var tapa: Node3D = tesoro.modelo.find_child("cofre_tapa", true, false) as Node3D
	var i: int = 0
	while i < CUANDO.size() and not seq.hecha:
		await process_frame
		if seq.t >= float(CUANDO[i]):
			print("t=%.2f estado %s clip %s · mano izq y %.3f · tapa girada %.2f rad" % [seq.t, pj.estado_anim(), pj.clip_actual(), _y_mano(pj),
				tapa.quaternion.get_angle() if tapa != null else -1.0])
			await _foto("cofre_abrir_%d_t%03d" % [i + 1, int(round(float(CUANDO[i]) * 100.0))])
			i += 1
	Engine.time_scale = 1.0
	await avanzar_s(1.5)


func _y_mano(pj: Pj3D) -> float:
	var sk: Skeleton3D = pj.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var h: int = sk.find_bone("mixamorig_LeftHand")
	if h < 0:
		return -1.0
	return (sk.global_transform * sk.get_bone_global_pose(h)).origin.y - pj.global_position.y


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
