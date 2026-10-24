extends "res://herramientas/escenario_base.gd"
## LA ESTALAGMITA RESONANTE DE C4 EN ACCIÓN (24/10). NECESITA VENTANA.
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_cueva_estalagmitas.gd -- [carpeta] [sufijo]   (por defecto res://docs/capturas/cueva_piezas y `v2`)
## En reposo, vibrando (1.er pulso), cayendo (2.º), rota y con el goblin de la casilla donde cae aturdido.

const RUTA: String = "res://escenas/PruebaCueva.tscn"

var _dir: String = "res://docs/capturas/cueva_piezas"
var _suf: String = "v2"
var _cam: Camera3D = null
var _z: Puzle3D = null


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1:
		_suf = a[1]
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
	var cerrojo: Puzle3D.CerrojoPuzle = _z.nodo("entrada_c4") as Puzle3D.CerrojoPuzle
	cerrojo.abrir()
	var g: Combate3D = null
	for n in get_nodes_in_group("combate3d"):
		if n is Combate3D and Rect2i(19, 1, 7, 8).has_point(Terreno3D.celda_de((n as Combate3D).global_position)):
			g = n as Combate3D
			break
	var celda_cae: Vector2i = Vector2i(23, 4)
	colocar_jugador(Vector2i(22, 5))
	maqueta.set("_tam_camara", 4.2)
	_cam.size = 4.2
	if g != null:
		g.quieto = true
		g.position = Terreno3D.centro_de(celda_cae, Terreno3D.y_pies(celda_cae))
		g.pj.position = g.position
		g.casa = g.position
	await avanzar_s(1.5)
	await _foto("c4_estalagmita_en_reposo")
	Pulso3D.emitir(maqueta, [Vector2i(23, 2)], "", 4)
	await avanzar_s(0.3)
	await _foto("c4_estalagmita_vibrando")
	await avanzar_s(1.0)
	Pulso3D.emitir(maqueta, [Vector2i(23, 2)], "", 4)
	await avanzar_s(0.75)
	await _foto("c4_estalagmita_cayendo")
	await avanzar_s(0.5)
	await _foto("c4_estalagmita_golpea_y_aturde_al_goblin")
	await avanzar_s(2.0)
	await _foto("c4_estalagmita_rota")
	print("goblin stun %s vida %s" % [str(g.get("stun_timer")) if g != null else "-", str(g.get("health")) if g != null else "-"])


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join("%s_%s.png" % [nombre, _suf]))
	print("foto %s" % nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
