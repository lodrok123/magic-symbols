extends "res://herramientas/escenario_base.gd"
## LA GEODA EXPLOSIVA Y LA COLUMNA-PUENTE DE C3 EN ACCIÓN (26/10). NECESITA VENTANA.
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_cueva_geoda.gd -- [carpeta]   (por defecto res://docs/capturas/cueva_geoda)
## En reposo, cargando (el pulso llegó a la geoda), explotando, columna cayendo, el puente tendido sobre la lava y la jugadora cruzándolo.

const RUTA: String = "res://escenas/PruebaCueva.tscn"

var _dir: String = "res://docs/capturas/cueva_geoda"
var _cam: Camera3D = null
var _z: Puzle3D = null


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	_cam = maqueta.get("_camara") as Camera3D
	await avanzar(30)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	var cristal: CristalPulso3D = _z.nodo("cristal_geoda") as CristalPulso3D
	colocar_jugador(Vector2i(11, 3))
	maqueta.set("_tam_camara", 6.5)
	_cam.size = 6.5
	maqueta.set("_foco", Terreno3D.centro_de(Vector2i(13, 2), 0.5))
	await avanzar_s(1.5)
	await _foto("c3_1_en_reposo")
	cristal.latir()
	await avanzar_s(0.9)
	await _foto("c3_2_pulso_en_la_veta")
	await avanzar_s(0.7)
	await _foto("c3_3_geoda_cargando")
	await avanzar_s(0.5)
	await _foto("c3_4_explosion")
	await avanzar_s(0.5)
	await _foto("c3_5_columna_cayendo")
	await avanzar_s(1.0)
	await _foto("c3_6_columna_tendida")
	colocar_jugador(Vector2i(14, 2))
	await avanzar_s(1.0)
	await _foto("c3_7_jugadora_sobre_el_puente")
	colocar_jugador(Vector2i(11, 4))
	maqueta.set("_tam_camara", 9.5)
	_cam.size = 9.5
	maqueta.set("_foco", Terreno3D.centro_de(Vector2i(13, 3), 0.5))
	await avanzar_s(1.0)
	await _foto("c3_8_vista_general")


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join("%s.png" % nombre))
	print("foto %s" % nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
