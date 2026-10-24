extends "res://herramientas/escenario_base.gd"
## LAS PIEZAS DE LA TERCERA TANDA, YA COLOCADAS EN LA CUEVA (24/10). NECESITA VENTANA.
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_cueva_piezas.gd -- [carpeta]   (por defecto res://docs/capturas/cueva_piezas, con .gdignore)
## C2 (pilares, labio, rocas, musgo y helechos de la cascada; cámara del juego y de cerca), C1 (brasero_cueva encendido y apagado), C3 (geoda), C4 (estalagmitas) y los recolectables
## (alga, basalto, jarrón roto, esquirla del cristal). Solo mira; los contratos los comprueba `escenario_cueva_completa.gd`.

const RUTA: String = "res://escenas/PruebaCueva.tscn"

var _dir: String = "res://docs/capturas/cueva_piezas"
var _cam: Camera3D = null
var _z: Puzle3D = null


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
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	_cam = maqueta.get("_camara") as Camera3D
	await avanzar(30)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	print("avisos Puzle3D: ", _z.avisos if _z != null else "sin Puzle3D")
	# C2 · la cascada
	colocar_jugador(Vector2i(4, 6))
	await avanzar_s(14.0)
	await _foto("c2_juego")
	colocar_jugador(Vector2i(2, 5))
	await _zoom(6.0, 1.0)
	await _foto("c2_cascada_cerca")
	colocar_jugador(Vector2i(2, 6))
	await _zoom(4.0, 1.0)
	await _foto("c2_pie_de_la_caida")
	colocar_jugador(Vector2i(4, 7))
	await _zoom(7.0, 1.0)
	await _foto("c2_pozo_y_helechos")
	# C1 · los braseros
	colocar_jugador(Vector2i(4, 13))
	await _zoom(7.0, 1.5)
	await _foto("c1_braseros_apagados")
	for id in ["br_c1a", "br_c1b"]:
		(_z.nodo(id) as Reactivo3D).encender_llama()
	await avanzar_s(1.5)
	await _foto("c1_braseros_encendidos")
	# C3 · la geoda junto a la lava
	colocar_jugador(Vector2i(11, 3))
	await _zoom(7.0, 1.5)
	await _foto("c3_geoda_y_lava")
	# C4 · las estalagmitas junto a las vetas
	colocar_jugador(Vector2i(22, 4))
	await _zoom(8.0, 1.5)
	await _foto("c4_estalagmitas_y_vetas")
	# Recolectables: alga y basalto (a mano, donde no los esconde ninguna condición), el jarrón roto y la esquirla del cristal.
	colocar_jugador(Vector2i(5, 15))
	await _zoom(3.4, 0.5)
	for par in [["alga", Vector2i(4, 14)], ["basalto", Vector2i(5, 14)], ["alga", Vector2i(6, 14)]]:
		var r := Recolectable3D.new()
		r.preparar(par[1], "", 0.0, maqueta, String(par[0]))
		(maqueta.get("_props") as Node).add_child(r)
	var jarron: Node = _z.nodo("jarron_c1b")
	if jarron != null:
		jarron.call("romper")
	var cristal: Node3D = _z.nodo("latido_c1") as Node3D
	await avanzar_s(0.6)
	await _foto("recolectables_alga_basalto")
	colocar_jugador(Vector2i(6, 16))
	await _zoom(2.4, 0.5)
	MineralPulso.dar(lanzador, "esquirla_cristal", cristal)
	await avanzar_s(0.25)
	await _foto("recolectables_esquirla_subiendo")
	colocar_jugador(Vector2i(8, 15))
	await _zoom(2.4, 0.8)
	await _foto("recolectables_jarron_roto_cerca")


func _zoom(tam: float, s: float) -> void:
	maqueta.set("_tam_camara", tam)
	if _cam != null:
		_cam.size = tam
	await avanzar_s(s)


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join("%s.png" % nombre))
	print("foto %s" % nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
