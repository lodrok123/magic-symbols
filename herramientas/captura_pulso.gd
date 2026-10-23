extends "res://herramientas/escenario_base.gd"
## EL PULSO SE LEE (23/10, FASE 1 del Pulso resonante). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_pulso.gd -- [carpeta]   (por defecto res://docs/capturas/pulso_fase1)
## Fotos para MIRAR si el pulso se lee sobre la roca oscura de la Cueva. El tiempo se frena (`Engine.time_scale`) para pillar el frente en 4-5 fotogramas seguidos: a
## velocidad normal el pulso cruza una veta de 6 casillas en 0,5 s.
## 1 · C1: el cristal y su veta en reposo; el pulso base (azul claro) recorriendo la veta, en fotogramas seguidos; el pulso de fuego (hechizo de fuego contra el cristal).
## 2 · C5 → C6: la fuente suelta su pulso de rayo por el agua, sigue por la veta bajo la puerta y llega al receptor (antes / durante / después).
## Los contratos (el pulso llega, el receptor se activa) los comprueba `escenario_cueva_pulso.gd`; aquí solo hay `_ok` de lo imprescindible para que la foto sea la que toca.

const RUTA: String = "res://escenas/PruebaCueva.tscn"
const ESCALA_TIEMPO: float = 0.2
const TAM_CAMARA_C1: float = 8.0
const TAM_CAMARA_C5C6: float = 15.0
const TAM_CAMARA_RECEPTOR: float = 4.0
const CASILLA_C1: Vector2i = Vector2i(4, 15)         ## donde se pone la jugadora (la cámara la sigue): centro de cristal y veta
const CASILLA_C5C6: Vector2i = Vector2i(19, 15)      ## entre la charca y el receptor

var _dir: String = "res://docs/capturas/pulso_fase1"
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
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(maqueta.get_tree().root)
	await avanzar(30)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	var cristal: CristalPulso3D = _z.nodo("latido_c1") as CristalPulso3D
	var receptor: ReceptorPulso3D = _z.nodo("ante_cofre") as ReceptorPulso3D
	var fuente: EmisorRayo3D = _z.nodo("fuente") as EmisorRayo3D
	_ok("0 están el cristal de C1, el receptor de C6 y la fuente", cristal != null and receptor != null and fuente != null)
	if cristal == null or receptor == null or fuente == null:
		return

	# 1 · C1
	cristal.cada = 0.0                                   # lo hago latir yo, a mano, para saber el instante exacto
	await _mirar(CASILLA_C1, TAM_CAMARA_C1, 2.5)
	await avanzar_s(CristalPulso3D.T_DESTELLO + 0.5)
	await _foto("c1_reposo")
	Engine.time_scale = ESCALA_TIEMPO
	cristal.latir("")
	var t0: float = reloj.t
	for t in [0.04, 0.16, 0.28, 0.40, 0.52]:
		await _hasta(t0 + t)
		await _foto("c1_pulso_base_%03d" % int(round(t * 100.0)))
	Engine.time_scale = 1.0
	await avanzar_s(1.5)
	Engine.time_scale = ESCALA_TIEMPO
	cristal.latir("fuego")
	t0 = reloj.t
	for t in [0.04, 0.28]:
		await _hasta(t0 + t)
		await _foto("c1_pulso_fuego_%03d" % int(round(t * 100.0)))
	Engine.time_scale = 1.0
	await avanzar_s(1.5)

	# 2 · C5 → C6
	await _mirar(CASILLA_C5C6, TAM_CAMARA_C5C6, 2.5)
	receptor.apagar()
	Flags.i().quitar("cueva.c6.pulso")
	await avanzar_s(0.6)
	# Se espera a la próxima descarga y se frena el tiempo justo cuando suelta su pulso.
	var llego: Array = [false]
	fuente.descarga.connect(func(_c: Array) -> void: llego[0] = true, CONNECT_ONE_SHOT)
	var guarda: float = 0.0
	while not llego[0] and guarda < 15.0:
		guarda += await avanzar_s(0.05)
	Engine.time_scale = ESCALA_TIEMPO
	t0 = reloj.t
	for t in [0.0, 0.30, 0.65, 0.95, 1.25, 1.45, 1.9]:
		await _hasta(t0 + t)
		await _foto("c5c6_pulso_%03d" % int(round(t * 100.0)))
	_ok("2 el receptor de C6 acaba activado", receptor.activo)
	Engine.time_scale = 1.0
	await avanzar_s(0.8)
	# El receptor de cerca: activado y apagado.
	await _mirar(Vector2i(14, 14), TAM_CAMARA_RECEPTOR, 2.0)
	_aviso("receptor de C6 antes de la foto", "activo %s · energía %.2f · materiales con brillo %d · energía en el material %s · color %s" % [str(receptor.activo), receptor.energia(), receptor._mats.size(), str(receptor._mats[0].get_shader_parameter("energia")), str(receptor._mats[0].get_shader_parameter("color_pulso"))])
	await _foto("c6_receptor_activo_cerca")
	receptor.apagar()
	await avanzar_s(1.0)
	await _foto("c6_receptor_apagado_cerca")


func _mirar(c: Vector2i, tam: float, s: float) -> void:
	colocar_jugador(c)
	maqueta.set("_tam_camara", tam)
	var cam: Camera3D = maqueta.get("_camara") as Camera3D
	if cam != null:
		cam.size = tam
	await avanzar_s(s)


## Avanza fotogramas hasta que el reloj (tiempo de juego, ya frenado) llega a `t`.
func _hasta(t: float) -> void:
	while reloj.t < t:
		await process_frame


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
