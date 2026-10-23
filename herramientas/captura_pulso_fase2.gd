extends "res://herramientas/escenario_base.gd"
## EL PULSO, FASE 2 (23/10; PLAN_PULSO_RESONANTE §8, §10, §12.2). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_pulso_fase2.gd -- [carpeta]   (por defecto res://docs/capturas/pulso_fase2)
## Fotos para MIRAR (los contratos los comprueba `escenario_cueva_pulso.gd`; aquí solo hay `_ok` de lo imprescindible para que la foto sea la que toca):
## 1 · La Cueva iluminada en azul, ANTES / DESPUÉS del brillo de reposo (el «antes» apaga lo que añade esta fase: emisión de reposo de cristales y vetas y sus luces).
## 2 · La secuencia del cofre legendario (primer plano, luz baja, onda por las vetas, glifo con halo, destello, página, escritura, fin).
## 3 · Flecha + ᚱ chocando (el pulso nace donde choca la flecha). 4 · Barrera + ᚱ latiendo. 5 · La pared hueca: eco con el pulso del escenario y abriéndose con el del jugador.
## 6 · El prisma girando el pulso.
## La interfaz se oculta ANTES de cada escena (la capa del cine, el destello y la página de la secuencia nacen después y se ven).

const RUTA: String = "res://escenas/PruebaCueva.tscn"
const ESCALA_TIEMPO: float = 0.25
const TAM_C6: float = 9.0
const TAM_CERCA: float = 5.0

var _dir: String = "res://docs/capturas/pulso_fase2"
var _z: Puzle3D = null
var _vistas: Dictionary = {}


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
	_ocultar_ui(root)
	await avanzar(30)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	var cristal: CristalPulso3D = _z.nodo("latido_c1") as CristalPulso3D
	var receptor: ReceptorPulso3D = _z.nodo("ante_cofre") as ReceptorPulso3D
	var prisma: PrismaPulso3D = _z.nodo("prisma_c6") as PrismaPulso3D
	var pared: ParedHuecaPulso3D = _z.nodo("salida") as ParedHuecaPulso3D
	var tesoro: Puzle3D.CofrePuzle = _z.nodo("tesoro") as Puzle3D.CofrePuzle
	var fuente: EmisorRayo3D = _z.nodo("fuente") as EmisorRayo3D
	_ok("0 están el cristal, el receptor, el prisma, la pared hueca, el cofre y la fuente", cristal != null and receptor != null and prisma != null and pared != null and tesoro != null and fuente != null)
	if cristal == null or receptor == null or prisma == null or pared == null or tesoro == null or fuente == null:
		return
	cristal.cada = 0.0
	fuente.set_process(false)                              # la fuente no suelta pulsos propios: los que se ven son los que lanzo yo
	await _mirar(Vector2i(12, 15), TAM_C6, 2.0)

	# 1 · Antes / después del brillo de reposo
	await _vista_general("cueva_c6", Vector2i(13, 15), 11.0)
	await _vista_general("cueva_c1", Vector2i(4, 15), 9.0)

	# 6 · El prisma (antes del cofre, con el receptor apagado)
	await _prisma(prisma, receptor, pared)
	# 5 · La pared hueca
	await _pared(prisma, pared, receptor)
	# 2 · El cofre
	await _cofre(tesoro, receptor)
	# 3 y 4 · Flecha + ᚱ y barrera + ᚱ (ya con el glifo)
	await _flecha(receptor)
	await _barrera()
	Engine.time_scale = 1.0


# ---------------------------------------------------------------------------------------------------------------------

func _vista_general(nombre: String, c: Vector2i, tam: float) -> void:
	await _mirar(c, tam, 1.5)
	await _foto("%s_despues" % nombre)
	_reposo(false)
	await avanzar(4)
	await _foto("%s_antes" % nombre)
	_reposo(true)
	await avanzar(4)


## Apaga o enciende lo que añade el brillo azul de reposo (emisión y luces de cristales, receptor, prisma y vetas): sirve para sacar el «antes».
func _reposo(si: bool) -> void:
	for n in maqueta.find_children("*", "", true, false):
		if n is CristalPulso3D or n is ReceptorPulso3D or n is PrismaPulso3D:
			for m in (n.get("_mats") as Array):
				(m as ShaderMaterial).set_shader_parameter("energia_reposo", BrilloPulso3D.ENERGIA_REPOSO if si else 0.0)
			var luz: OmniLight3D = n.get("_luz") as OmniLight3D
			if luz != null and bool(n.get("_luz_reposo")):
				if not si:
					_vistas[n.get_instance_id()] = luz.light_energy
				luz.visible = si
		elif n is VetaPulso3D:
			for c in (n.get("_mats") as Dictionary):
				((n.get("_mats") as Dictionary)[c] as ShaderMaterial).set_shader_parameter("emision_reposo", VetaPulso3D.EMISION_REPOSO if si else 0.0)


func _prisma(prisma: PrismaPulso3D, receptor: ReceptorPulso3D, pared: ParedHuecaPulso3D) -> void:
	receptor.apagar()
	Flags.i().quitar("cueva.c6.pulso")
	prisma.poner_dir("n")
	await _mirar(Vector2i(15, 15), TAM_CERCA + 1.0, 2.0)
	await _foto("prisma_n_reposo")
	# El pulso del escenario llega por la veta de C5, el prisma lo reemite hacia el norte.
	Engine.time_scale = ESCALA_TIEMPO
	Pulso3D.emitir(maqueta, [Vector2i(19, 16)], "rayo", 24, null)
	var t0: float = reloj.t
	for t in [0.30, 0.55, 0.80, 1.05]:
		await _hasta(t0 + t * 0.5)
		await _foto("prisma_norte_%03d" % int(round(t * 100.0)))
	Engine.time_scale = 1.0
	await avanzar_s(2.0)
	# Se gira 90° (horario) y el mismo pulso sale por el oeste, hacia la pared hueca.
	await avanzar_s(PrismaPulso3D.ENFRIAR)
	prisma.girar()
	await avanzar_s(PrismaPulso3D.ENFRIAR + 0.1)
	prisma.girar()
	await avanzar_s(PrismaPulso3D.ENFRIAR + 0.1)
	prisma.girar()
	await avanzar_s(0.6)
	_ok("6 el prisma ha girado de n a o (tres giros horarios)", prisma.dir == "o", prisma.dir)
	await _foto("prisma_girado_oeste_reposo")
	Engine.time_scale = ESCALA_TIEMPO
	Pulso3D.emitir(maqueta, [Vector2i(19, 16)], "rayo", 24, null)
	t0 = reloj.t
	for t in [0.30, 0.60, 0.90, 1.20, 1.50]:
		await _hasta(t0 + t * 0.5)
		await _foto("prisma_oeste_%03d" % int(round(t * 100.0)))
	Engine.time_scale = 1.0
	await avanzar_s(2.0)
	prisma.poner_dir("n")


func _pared(prisma: PrismaPulso3D, pared: ParedHuecaPulso3D, receptor: ReceptorPulso3D) -> void:
	prisma.poner_dir("o")
	await _mirar(Vector2i(11, 16), 6.5, 2.0)
	await _foto("pared_hueca_reposo")
	# Eco con el pulso del escenario (por el prisma girado al oeste).
	Engine.time_scale = ESCALA_TIEMPO
	Pulso3D.emitir(maqueta, [Vector2i(19, 16)], "rayo", 24, null)
	var t0: float = reloj.t
	for t in [1.40, 1.70, 2.0]:
		await _hasta(t0 + t * 0.5)
		await _foto("pared_eco_escenario_%03d" % int(round(t * 100.0)))
	Engine.time_scale = 1.0
	await avanzar_s(2.0)
	_ok("5 con el pulso del escenario la pared hace eco y NO se abre", pared.ecos >= 1 and not pared.abierta)
	# Se abre con el pulso del jugador (el glifo no está aún: se lanza la misma señal que lanzaría el hechizo).
	colocar_jugador(Vector2i(11, 16))
	await avanzar_s(0.5)
	Engine.time_scale = ESCALA_TIEMPO
	Pulso3D.emitir(maqueta, [Vector2i(11, 16)], "", 4, null, Callable(), true)
	t0 = reloj.t
	for t in [0.16, 0.30, 0.60, 1.0, 1.5, 2.2]:
		await _hasta(t0 + t * 0.5)
		await _foto("pared_abre_%03d" % int(round(t * 100.0)))
	Engine.time_scale = 1.0
	await avanzar_s(1.5)
	_ok("5 con el pulso del jugador la pared se abre", pared.abierta)
	await _foto("pared_abierta")
	prisma.poner_dir("n")


func _cofre(tesoro: Puzle3D.CofrePuzle, receptor: ReceptorPulso3D) -> void:
	receptor.activar()
	colocar_jugador(Vector2i(13, 14))
	await _mirar(Vector2i(13, 14), 10.0, 1.5)
	await _foto("cofre_0_antes")
	_ocultar_ui(root)                                      # (lo que ya existía; las capas de la secuencia nacen después)
	Engine.time_scale = 0.5
	_ok("2 el cofre se abre y arranca la secuencia", tesoro.abrir())
	var seq: SecuenciaCofreLegendario3D = tesoro.secuencia
	var cuando: Array = [0.35, 0.95, 1.5, 2.1, 2.62, 2.9, 3.5, 4.2, 4.9]
	var i: int = 0
	while i < cuando.size() and not seq.hecha:
		await process_frame
		if seq.t >= float(cuando[i]):
			await _foto("cofre_%d_t%03d" % [i + 1, int(round(float(cuando[i]) * 100.0))])
			i += 1
	Engine.time_scale = 1.0
	await avanzar_s(1.2)
	await _foto("cofre_9_despues")
	_ok("2 el glifo ᚱ queda desbloqueado", Repertoire.sigil_active("raido"))


func _flecha(receptor: ReceptorPulso3D) -> void:
	receptor.apagar()
	Flags.i().quitar("cueva.c6.pulso")
	colocar_jugador(Vector2i(17, 13))
	await _mirar(Vector2i(16, 13), TAM_CERCA + 1.0, 1.5)
	Engine.time_scale = ESCALA_TIEMPO
	lanzar("fuego", ["flecha", "raido"], Vector3.LEFT)
	var t0: float = reloj.t
	for t in [0.10, 0.22, 0.34, 0.46, 0.60, 0.85, 1.2]:
		await _hasta(t0 + t)
		await _foto("flecha_pulso_%03d" % int(round(t * 100.0)))
	Engine.time_scale = 1.0
	await avanzar_s(1.5)
	_ok("3 el receptor se activó con el pulso que nació donde chocó la flecha", receptor.activo)


func _barrera() -> void:
	colocar_jugador(Vector2i(13, 16))
	await _mirar(Vector2i(13, 15), TAM_CERCA + 1.5, 2.0)
	Engine.time_scale = 0.5
	lanzar("fuego", ["barrera", "raido"], Vector3(0.0, 0.0, -1.0))
	var t0: float = reloj.t
	for t in [0.1, 0.4, 1.5, 1.8, 3.0, 3.3]:
		await _hasta(t0 + t * 0.5)
		await _foto("barrera_pulso_%03d" % int(round(t * 100.0)))
	Engine.time_scale = 1.0
	await avanzar_s(2.0)


func _mirar(c: Vector2i, tam: float, s: float) -> void:
	colocar_jugador(c)
	maqueta.set("_tam_camara", tam)
	var cam: Camera3D = maqueta.get("_camara") as Camera3D
	if cam != null:
		cam.size = tam
	await avanzar_s(s)


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
