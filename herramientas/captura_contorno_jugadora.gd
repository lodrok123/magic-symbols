extends "res://herramientas/escenario_base.gd"
## CAPTURA «CONTORNO DE LA JUGADORA» (Juego, 4/11). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_contorno_jugadora.gd -- [carpeta]   (por defecto res://docs/capturas/contorno_jugadora)
## Pone a la jugadora pegada al anillo de árboles del sur del Bosque 02 (la cámara del juego mira desde el sur: el árbol la tapa) y hace
## «antes» (transparencia por dither, sin contorno) y «despues» (decorado entero + contorno), a la distancia del juego y con zoom cerca.
## Se miran a ojo; lo único que se afirma es que el pase de contorno existe y que la cámara no gira con Z/C.

const RUTA: String = "res://escenas/PruebaBosque02.tscn"
var _dir: String = "res://docs/capturas/contorno_jugadora"
const POSES: Array = [["arbol_sur", Vector2i(8, 35)], ["arbol_sur_b", Vector2i(10, 35)], ["borde_oeste", Vector2i(4, 30)]]


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Misiones.nuevo()
	Estado.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	lanzador.tinta = null
	_ocultar_ui(root)
	await avanzar(30)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	var pj: Pj3D = maqueta.get("_jugador") as Pj3D
	for p in POSES:
		colocar_jugador(p[1] as Vector2i)
		await avanzar_s(1.5)
		for zoom in [["", 12.0], ["_cerca", 5.0]]:
			maqueta.set("_tam_camara", zoom[1])
			var cam: Camera3D = maqueta.get("_camara") as Camera3D
			if cam != null:
				cam.size = zoom[1]
			# ANTES: lo de ayer (agujero por dither de radio 1,9 y sin contorno)
			Pj3D.silueta_activa = false
			pj.set_rol_visual("jugadora")
			maqueta.set("radio_transparencia", 1.9)
			await avanzar_s(0.8)
			_foto("antes_%s%s" % [p[0], zoom[0]])
			# DESPUÉS: decorado entero y contorno
			Pj3D.silueta_activa = true
			pj.set_rol_visual("jugadora")
			maqueta.set("radio_transparencia", 0.0)
			await avanzar_s(0.8)
			_foto("despues_%s%s" % [p[0], zoom[0]])
	# La cámara no gira: Z y C no cambian nada.
	var antes: float = float(maqueta.get("_giro_cam"))
	for t in [KEY_Z, KEY_C, KEY_Z]:
		_tecla(t, true)
		await avanzar(2)
		_tecla(t, false)
		await avanzar(2)
	_ok("C1 Z/C no giran la cámara (CAMARA_GIRA = false)", float(maqueta.get("_giro_cam")) == antes and antes == 0.0, "giro %s" % str(maqueta.get("_giro_cam")))


func _foto(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
