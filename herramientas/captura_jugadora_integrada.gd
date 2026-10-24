extends "res://herramientas/escenario_base.gd"
## CAPTURAS DE LA JUGADORA NUEVA (jugadora_base) DENTRO DEL JUEGO (24/10): en el Bosque 01 v01, en la Cueva, en el laboratorio de hechizos, lanzando (los tres cast points, con el libro
## en la mano) y abriendo el cofre legendario. NECESITA VENTANA; una escena por ejecución:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_jugadora_integrada.gd -- <carpeta> <bosque|cueva|lab|lanzar|cofre>
## Lo que se ve es lo que hay: se miran a ojo (no hay `_ok` de imagen; los `_ok` solo dicen que la jugadora cargada es la nueva).

const ID_ESPERADO: String = "jugadora_base"
const RUTA_BOSQUE_V01: String = "res://escenas/PruebaBosque01_v01.tscn"
const RUTA_CUEVA: String = "res://escenas/PruebaCueva.tscn"
const RUTA_LAB: String = "res://laboratorios/LabHechizos3D.tscn"
const TAM_CERCA: float = 3.4
const TAM_LANZAR: float = 6.0
const T_ASENTAR: float = 2.0
const CASILLA_BOSQUE: Vector2i = Vector2i(9, 3)           ## la tala del Bosque 01 v01 (junto al goblin leñador)
const CASILLA_LANZAR: Vector2i = Vector2i(44, 18)         ## la plaza de piedra de la boca de la Cueva: suelo liso y sin arbustos que tapen
const CASILLA_BOCA: Vector2i = Vector2i(44, 18)           ## la boca de la Cueva
const CASILLA_CUEVA: Vector2i = Vector2i(4, 17)           ## la entrada de la Cueva (`desde_bosque`)
const CASILLA_TESORO: Vector2i = Vector2i(13, 14)         ## junto al cofre legendario de la Cueva
const POSICIONES: Dictionary = {"x_mano": ["linea_z"], "alto": ["altura"], "abajo": ["barrera", "linea_x", "linea_x", "linea_x"]}
const CUANDO_COFRE: Array = [0.2, 0.8, 1.4, 2.2, 3.0]

var _dir: String = "res://docs/capturas/jugadora_integrada"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	var seccion: String = a[1] if a.size() > 1 else "bosque"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	Flags.nuevo()
	Misiones.nuevo()
	match seccion:
		"bosque":
			await _bosque()
		"cueva":
			await _cueva()
		"lab":
			await _lab()
		"lanzar":
			await _lanzar()
		"cofre":
			await _cofre()


func _arrancar(ruta: String) -> bool:
	await cargar(ruta, true)
	if maqueta == null or jugador == null:
		return false
	var pj: Pj3D = jugador.get("pj") as Pj3D
	_ok("la protagonista del juego es %s" % ID_ESPERADO, pj != null and pj.id == ID_ESPERADO, "id: %s" % (pj.id if pj != null else "ninguno"))
	_ocultar_ui(root)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	await avanzar(30)
	return true


func _mirar(c: Vector2i, tam: float, s: float) -> void:
	colocar_jugador(c)
	maqueta.set("_tam_camara", tam)
	var cam: Camera3D = maqueta.get("_camara") as Camera3D
	if cam != null:
		cam.size = tam
	await avanzar_s(s)
	_ocultar_ui(root)


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(_dir.path_join(nombre + ".png")))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and h.name != Niveles.NOMBRE_FUNDIDO:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)


func _bosque() -> void:
	if not await _arrancar(RUTA_BOSQUE_V01):
		return
	await _mirar(CASILLA_BOSQUE, TAM_CERCA, T_ASENTAR)
	await _foto("bosque_01_v01_idle")
	# andando: se le pide el clip de andar un momento (el movimiento real depende del foco de la ventana)
	var pj: Pj3D = jugador.get("pj") as Pj3D
	pj.jugar("walk")
	await avanzar_s(0.6)
	await _foto("bosque_01_v01_andando")
	pj.jugar("idle")
	await _mirar(CASILLA_BOCA, TAM_CERCA, 1.5)
	await _foto("bosque_01_v01_boca_cueva")
	await _mirar(CASILLA_BOCA, TAM_CERCA * 2.5, 1.0)
	await _foto("bosque_01_v01_boca_cueva_ancha")


func _cueva() -> void:
	if not await _arrancar(RUTA_CUEVA):
		return
	await _mirar(CASILLA_CUEVA, TAM_CERCA, T_ASENTAR)
	await _foto("cueva_entrada")
	await _mirar(Vector2i(10, 10), TAM_CERCA * 1.5, 1.0)
	await _foto("cueva_dentro")


func _lab() -> void:
	await cargar(RUTA_LAB)
	if maqueta == null or jugador == null:
		return
	var pj: Pj3D = jugador.get("pj") as Pj3D
	_ok("la protagonista del laboratorio es %s" % ID_ESPERADO, pj != null and pj.id == ID_ESPERADO, "id: %s" % (pj.id if pj != null else "ninguno"))
	await avanzar_s(1.5)
	await _foto("lab_hechizos_idle")


## Lanzando: los tres cast points reales (x_mano · alto · abajo) con la receta de la prueba, el libro en la mano y el hechizo naciendo donde dice el clip. Se hace la foto en
## el instante del disparo y un poco antes (la forma), con el libro aún en la mano.
func _lanzar() -> void:
	if not await _arrancar(RUTA_BOSQUE_V01):
		return
	lanzador.tinta = null
	await _mirar(CASILLA_LANZAR, TAM_LANZAR, T_ASENTAR)
	var pj: Pj3D = jugador.get("pj") as Pj3D
	for nombre in ["x_mano", "alto", "abajo"]:
		await _esperar_cooldown()
		pj.soltar_lanzar()
		await avanzar_s(0.7)
		var r := Lanzador3D.Receta3D.new(Vector2.RIGHT)
		for g in (POSICIONES[nombre] as Array):
			r.apply(String(g))
		var rune: RuneData = load("res://nucleo/fire_rune.tres") as RuneData
		var datos: Dictionary = {"indice": 0, "receta": r, "rune": rune, "calidad": 1.0, "glifos": POSICIONES[nombre], "elemento_nombre": "fire"}
		lanzador.lanzar_ahora(datos, jugador.position, Vector3.RIGHT, true)
		var inst: float = pj.tiempo_instante()
		await avanzar_s(maxf(inst - 0.25, 0.05))
		await _foto("lanzar_%s_antes" % nombre)
		await avanzar_s(0.25)
		await _foto("lanzar_%s_instante" % nombre)
		await avanzar_s(0.3)
		await _foto("lanzar_%s_despues" % nombre)
		await avanzar_s(1.0)


func _esperar_cooldown() -> void:
	lanzador.cooldown_left[0] = 0.0
	lanzador.cooldown_left[1] = 0.0
	if jugador.get("tinta") != null:
		jugador.tinta.actual = 100.0
	var t: float = 0.0
	while lanzador.conjurando and t < 4.0:
		t += await avanzar_s(0.1)
	await avanzar(2)


## El cofre legendario de la Cueva (secuencia con el clip `abrir_cofre`): la jugadora inclinada con las manos en la tapa.
func _cofre() -> void:
	if not await _arrancar(RUTA_CUEVA):
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var tesoro: Puzle3D.CofrePuzle = z.nodo("tesoro") as Puzle3D.CofrePuzle
	var receptor: ReceptorPulso3D = z.nodo("ante_cofre") as ReceptorPulso3D
	if receptor != null:
		receptor.activar()
	colocar_jugador(CASILLA_TESORO)
	maqueta.set("_tam_camara", 8.0)
	(maqueta.get("_camara") as Camera3D).size = 8.0
	await avanzar_s(1.5)
	_ocultar_ui(root)
	Engine.time_scale = 0.5
	_ok("el cofre se abre y arranca la secuencia", tesoro.abrir())
	var seq: SecuenciaCofreLegendario3D = tesoro.secuencia
	var i: int = 0
	while i < CUANDO_COFRE.size() and not seq.hecha:
		await process_frame
		if seq.t >= float(CUANDO_COFRE[i]):
			_ocultar_ui(root)
			await _foto("cofre_abrir_t%03d" % int(round(float(CUANDO_COFRE[i]) * 100.0)))
			i += 1
	Engine.time_scale = 1.0
	await avanzar_s(1.0)
