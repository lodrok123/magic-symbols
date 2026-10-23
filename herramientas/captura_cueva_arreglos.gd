extends "res://herramientas/escenario_base.gd"
## ARREGLOS DE LA CUEVA (23/10): tapa del cofre legendario, luz azul de reposo y pared hueca reconocible. NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_cueva_arreglos.gd -- <prefijo> [carpeta]
## <prefijo> = `antes` o `despues` (nombre de las fotos); carpeta por defecto res://docs/capturas/cueva_arreglos (con .gdignore).
## Fotos: cofre abierto de cerca (y de frente más lejos), C6 y C1 generales, la pared hueca en reposo (de lejos, de cerca y con el jugador a 2 casillas).
## Solo mira; los contratos los comprueban `escenario_cueva_pulso.gd` y `prueba_pulso.gd`.

const RUTA: String = "res://escenas/PruebaCueva.tscn"
const TAM_C6: float = 11.0
const TAM_C1: float = 9.0
const TAM_COFRE: float = 3.8
const CELDA_COFRE: Vector2i = Vector2i(13, 13)
const CELDA_PARED: Vector2i = Vector2i(9, 16)

var _dir: String = "res://docs/capturas/cueva_arreglos"
var _pre: String = "despues"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_pre = a[0]
	if a.size() > 1 and a[1] != "":
		_dir = a[1]
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	Flags.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	await avanzar(30)
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var receptor: ReceptorPulso3D = z.nodo("ante_cofre") as ReceptorPulso3D
	var tesoro: Puzle3D.CofrePuzle = z.nodo("tesoro") as Puzle3D.CofrePuzle
	var fuente: EmisorRayo3D = z.nodo("fuente") as EmisorRayo3D
	var cristal: CristalPulso3D = z.nodo("latido_c1") as CristalPulso3D
	if cristal != null:
		cristal.cada = 0.0
	if fuente != null:
		fuente.set_process(false)
	await _mirar(Vector2i(13, 15), TAM_C6, 2.0)
	await _foto("c6")
	await _mirar(Vector2i(4, 15), TAM_C1, 2.0)
	await _foto("c1")
	# La pared hueca en reposo (de lejos, de cerca y con el jugador a 2 casillas: el zumbido/eco de aviso, si lo hay).
	await _mirar(Vector2i(11, 16), 6.5, 2.0)
	await _foto("pared_lejos")
	await _mirar(CELDA_PARED + Vector2i(3, 0), 3.4, 2.0)
	await _foto("pared_cerca")
	await _mirar(CELDA_PARED + Vector2i(2, 0), 3.4, 2.5)
	await _foto("pared_a2casillas")
	# El cofre abierto
	receptor.activar()
	colocar_jugador(Vector2i(13, 15))
	await _mirar(Vector2i(13, 14), 10.0, 1.5)
	_ocultar_ui(root)
	Engine.time_scale = 2.0
	tesoro.abrir()
	var seq: SecuenciaCofreLegendario3D = tesoro.secuencia
	var guardia: int = 0
	while not seq.hecha and guardia < 3000:
		await process_frame
		guardia += 1
	Engine.time_scale = 1.0
	await avanzar_s(2.0)
	jugador.visible = false                                    # el encuadre sigue al jugador: se le esconde y se le pone sobre el cofre para centrarlo
	await _mirar(CELDA_COFRE, TAM_COFRE, 1.5)
	await _foto("cofre_abierto_cerca")
	jugador.visible = true
	await _mirar(Vector2i(13, 14), 5.0, 1.0)
	await _foto("cofre_abierto_medio")


func _mirar(c: Vector2i, tam: float, s: float) -> void:
	colocar_jugador(c)
	maqueta.set("_tam_camara", tam)
	var cam: Camera3D = maqueta.get("_camara") as Camera3D
	if cam != null:
		cam.size = tam
	await avanzar_s(s)


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join("%s_%s.png" % [_pre, nombre]))
	print("foto %s_%s" % [_pre, nombre])


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
