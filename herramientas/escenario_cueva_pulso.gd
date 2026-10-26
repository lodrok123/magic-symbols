extends "res://herramientas/escenario_base.gd"
## EL PULSO EN LA CUEVA (23/10, FASES 1 y 2 del Pulso resonante; docs/PLAN_PULSO_RESONANTE.md §5, §6, §8, §10 y §12). Headless, con la escena de verdad (PruebaCueva):
## FASE 1
## 1 · Puzle3D monta el cristal, las vetas, el prisma, la pared hueca, el receptor y el cofre sin avisos, y las vetas son conductor del pulso (`Pulso3D.vetas`).
## 2 · C1: el cristal LATE solo; su pulso recorre la veta casilla a casilla (el frente avanza y deja atrás las casillas apagadas); un hechizo de fuego le hace latir con pulso de fuego.
## 3 · C5 → C6: cada descarga de la fuente suelta un pulso de rayo por el agua y la veta; llega al PRISMA de C6, que lo reemite hacia el receptor (retraso por casilla) y lo activa.
## 4 · Si la charca se hiela, el agua deja de conducir y el pulso NO llega.
## FASE 2
## 5 · La Cueva iluminada en azul: el cristal brilla muy poco en reposo, con una luz tenue (cupo `MAX_LUCES_REPOSO`), y el destello del pulso sigue por encima.
## 6 · Prisma: se gira (golpe de hechizo o giro a mano) 90° en sentido horario; girado al oeste lleva el pulso del escenario a la pared hueca; sin reentradas.
## 7 · Pared hueca: con el pulso del ESCENARIO solo hace eco (no se abre).
## 8 · Cofre legendario: sellado hasta que el receptor está activo; al abrirlo corre la secuencia (control, cámara, luz, tapa, glifo, libro), desbloquea ᚱ «pulso», pone `cueva.c6.glifo`, y lo
##     devuelve todo; a partir de la segunda vez se puede saltar.
## 9 · El glifo ᚱ: antes del cofre no está en el libro; después, ᚱ al inicio (abre la pared hueca con el pulso del jugador), flecha + ᚱ (el pulso nace donde choca, sin caso especial),
##     barrera + ᚱ (continuo con periodo mínimo, sin reentradas) y ᚷ «crecer» sigue igual.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_cueva_pulso.gd

const RUTA: String = "res://escenas/PruebaCueva.tscn"
const VETA_C1: Array = [Vector2i(5, 15), Vector2i(4, 15), Vector2i(3, 15), Vector2i(2, 15), Vector2i(2, 14), Vector2i(2, 13)]   ## por orden de paso
const VETA_C5: Array = [Vector2i(19, 16), Vector2i(18, 16), Vector2i(17, 16), Vector2i(16, 16)]
const VETA_C6_NORTE: Array = [Vector2i(15, 15), Vector2i(15, 14), Vector2i(15, 13)]
const VETA_C6_OESTE: Array = [Vector2i(14, 16), Vector2i(13, 16), Vector2i(12, 16), Vector2i(11, 16), Vector2i(10, 16)]
const VETAS_FASE3: int = 25             ## casillas de veta que añade la fase 3: pads de C1 (3), C2 (3 + 3 del filón), C3 (2 + 1 de la veta de la geoda), C4 (6 + 7)
const CHARCA: Rect2i = Rect2i(20, 13, 5, 4)
const FLAG_RECEPTOR: String = "cueva.c6.pulso"
const FLAG_GLIFO: String = "cueva.c6.glifo"
const FLAG_SALIDA: String = "cueva.c6.salida"
const CELDA_PRISMA: Vector2i = Vector2i(15, 16)
const CELDA_PARED: Vector2i = Vector2i(9, 16)
const CELDA_RECEPTOR: Vector2i = Vector2i(14, 13)
const CELDA_COFRE: Vector2i = Vector2i(13, 13)

var _z: Puzle3D = null


func _vivo() -> HechizoVivo:
	var ultimo: HechizoVivo = null
	for n in lanzador.get_children():
		if n is HechizoVivo:
			ultimo = n as HechizoVivo
	return ultimo


## Lanza el hechizo como el jugador (sin tinta ni recarga). true si salió. El HechizoVivo de algo instantáneo se libera al acabar el fotograma: se lee EN ESTE (`_vivo()`) y se guardan sus listas.
func _lanzar_y_ver(elemento: String, glifos: Array, dir: Vector3) -> bool:
	return lanzar(elemento, glifos, dir)


## Espera a que no quede ningún pulso en el aire (la fuente de C5 descarga sola cada pocos segundos y su pulso tarda ~1 s en llegar al receptor). Tope de 8 s.
func _sin_pulsos_en_vuelo() -> void:
	var espera: float = 0.0
	while espera < 8.0:
		if maqueta.find_children("*", "Pulso3D", true, false).is_empty():
			return
		espera += await avanzar_s(0.05)


func _escenario() -> void:
	Flags.nuevo()                                # sin flags heredadas de otra partida
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D

	# 1 · Montaje
	_ok("1 Puzle3D está y no avisa de nada", _z != null and _z.avisos.is_empty(), str(_z.avisos) if _z != null else "sin Puzle3D")
	if _z == null:
		return
	var cristal: CristalPulso3D = _z.nodo("latido_c1") as CristalPulso3D
	var veta1: VetaPulso3D = _z.nodo("veta_c1") as VetaPulso3D
	var veta5: VetaPulso3D = _z.nodo("veta_c5") as VetaPulso3D
	var receptor: ReceptorPulso3D = _z.nodo("ante_cofre") as ReceptorPulso3D
	var fuente: EmisorRayo3D = _z.nodo("fuente") as EmisorRayo3D
	var prisma: PrismaPulso3D = _z.nodo("prisma_c6") as PrismaPulso3D
	var pared: ParedHuecaPulso3D = _z.nodo("salida") as ParedHuecaPulso3D
	var tesoro: Puzle3D.CofrePuzle = _z.nodo("tesoro") as Puzle3D.CofrePuzle
	_ok("1 están el cristal de C1, las vetas, el receptor, la fuente, el prisma, la pared hueca y el cofre", cristal != null and veta1 != null and veta5 != null and receptor != null and fuente != null
		and prisma != null and pared != null and tesoro != null)
	if cristal == null or veta1 == null or veta5 == null or receptor == null or fuente == null or prisma == null or pared == null or tesoro == null:
		return
	var todas_vetas: bool = true
	var esperadas: Array = VETA_C1 + VETA_C5 + VETA_C6_NORTE + VETA_C6_OESTE
	for c in esperadas:
		if not Pulso3D.vetas.has(c):
			todas_vetas = false
	_ok("1 las casillas de las vetas conducen el pulso (Pulso3D.vetas; más las %d de las vetas de la fase 3: C1 pads, C2, C3 y C4)" % VETAS_FASE3, todas_vetas and Pulso3D.vetas.size() == esperadas.size() + VETAS_FASE3, "%d casillas" % Pulso3D.vetas.size())
	_ok("1 el cristal, el receptor, el prisma y la pared hueca bloquean su casilla", Terreno3D.bloqueada(Vector2i(6, 15)) and Terreno3D.bloqueada(CELDA_RECEPTOR)
		and Terreno3D.bloqueada(CELDA_PRISMA) and Terreno3D.bloqueada(CELDA_PARED))
	_ok("1 el receptor nace sin flag (con Flags.nuevo(); si ya estuviera activado es que ya pasó una descarga de la fuente durante la carga)", not receptor.activo or Flags.i().tiene(FLAG_RECEPTOR))
	_ok("1 el prisma nace mirando al norte y la pared hueca cerrada", prisma.dir == "n" and not pared.abierta)
	_ok("1 el cofre legendario nace cerrado, con su glifo (raido) y sellado hasta que el receptor esté activo", tesoro.es_cerrado and tesoro.glifo == "raido" and not tesoro.expr_abre.is_empty())
	_ok("1 antes del cofre ᚱ NO está en el libro (Repertoire)", not Repertoire.sigil_active("raido") and Repertoire.sigil_active("pulso"))

	# 2 · C1: el cristal late y el frente recorre la veta
	var pasos_vistos: Dictionary = {}                ## casilla -> paso en que el frente la alcanzó
	var pulso_c1: Array = []
	cristal.late.connect(func(p: Pulso3D) -> void:
		pulso_c1.append(p)
		p.alcanzo.connect(func(c: Vector2i, paso: int) -> void: pasos_vistos[c] = paso))
	var espera: float = 0.0
	while pulso_c1.is_empty() and espera < 5.0:
		espera += await avanzar_s(0.1)
	_ok("2 C1: el cristal late solo (primer latido a los ~1 s)", not pulso_c1.is_empty(), "esperé %.1f s, latidos %d" % [espera, cristal.latidos])
	if pulso_c1.is_empty():
		return
	var p1: Pulso3D = pulso_c1[0]
	_ok("2 C1: el pulso nace sin elemento y con el azul claro del base (y no es del jugador)", p1.elemento == "" and p1.color == Pulso3D.COLOR_BASE and not p1.del_jugador)
	# Muestreo del frente por fotogramas: qué casillas de la veta están encendidas en cada momento.
	var maxima_a_la_vez: int = 0
	var vio_frente_lejos: bool = false           ## alguna vez la 1.ª se había apagado mientras la última estaba encendida
	var inicio: float = reloj.t
	var energia_1ra: float = 0.0
	while reloj.t - inicio < 1.4:
		await process_frame
		var n_enc: int = 0
		for c in VETA_C1:
			if veta1.energia_en(c) > 0.05:
				n_enc += 1
		maxima_a_la_vez = maxi(maxima_a_la_vez, n_enc)
		energia_1ra = maxf(energia_1ra, veta1.energia_en(VETA_C1[0]))
		if veta1.energia_en(VETA_C1[VETA_C1.size() - 1]) > 0.5 and veta1.energia_en(VETA_C1[0]) < 0.05:
			vio_frente_lejos = true
	var orden_ok: bool = true
	for i in range(VETA_C1.size()):
		if int(pasos_vistos.get(VETA_C1[i], -1)) != i + 1:
			orden_ok = false
	_ok("2 C1: el frente alcanza las 6 casillas de la veta en orden (pasos 1 a 6)", orden_ok and pasos_vistos.size() >= 7, str(pasos_vistos))
	_ok("2 C1: la veta brilla al pasar el frente (energía de la 1.ª ≥ 0,9) y no a la vez entera (se apaga detrás: como mucho 5 de 6 a la vez)", energia_1ra >= 0.9 and maxima_a_la_vez <= 5, "pico %.2f, a la vez %d" % [energia_1ra, maxima_a_la_vez])
	_ok("2 C1: hay un momento con el final encendido y el principio ya apagado (el frente avanza)", vio_frente_lejos)
	# Un hechizo de fuego le hace latir con un pulso de fuego (tras el enfriamiento).
	await avanzar_s(CristalPulso3D.ENFRIAR + 0.2)
	var latidos0: int = cristal.latidos
	var fuego: RuneData = load("res://nucleo/fire_rune.tres") as RuneData
	cristal.on_spell_hit(fuego)
	_ok("2 C1: un hechizo de fuego le hace latir con pulso de FUEGO (color de su runa)", cristal.latidos == latidos0 + 1 and cristal.ultimo != null and cristal.ultimo.elemento == "fuego" and cristal.ultimo.color == fuego.color)
	cristal.on_spell_hit(fuego)
	_ok("2 C1: un segundo golpe inmediato no lo ametralla (enfriamiento)", cristal.latidos == latidos0 + 1)

	# 3 · C5 → C6, ahora por el prisma
	await _sin_pulsos_en_vuelo()                 # que un pulso de una descarga anterior no active el receptor a mitad de la medida
	receptor.apagar()
	Flags.i().quitar(FLAG_RECEPTOR)
	_ok("3 C6: el receptor se apaga a mano para empezar de cero", not receptor.activo)
	var t_descarga: Array = [-1.0]
	var t_activado: Array = [-1.0]
	fuente.descarga.connect(func(_celdas: Array) -> void:
		if t_activado[0] < 0.0:                  # la última descarga antes de que llegue el pulso
			t_descarga[0] = reloj.t)
	receptor.activado.connect(func() -> void: t_activado[0] = reloj.t)
	var esperado: float = 0.0
	while t_activado[0] < 0.0 and esperado < 16.0:
		esperado += await avanzar_s(0.1)
	_ok("3 C5→C6: una descarga de la fuente llega al prisma, éste la reemite y activa el receptor de C6", receptor.activo and t_activado[0] >= 0.0 and prisma.emisiones >= 1, "esperé %.1f s, el prisma reemitió %d" % [esperado, prisma.emisiones])
	_ok("3 C6: el receptor pone su flag (cueva.c6.pulso)", Flags.i().tiene(FLAG_RECEPTOR))
	var viaje: float = t_activado[0] - t_descarga[0]
	var minimo: float = 16.0 * Pulso3D.SEG_POR_CASILLA                 # 13 casillas hasta tocar el prisma + 3 de la veta norte (y el receptor): a 0,08 s cada una
	_ok("3 el pulso TARDA en llegar (≥ %.2f s) y no es instantáneo" % minimo, viaje >= minimo - 0.07 and viaje < 3.0, "descarga → receptor: %.2f s" % viaje)
	_ok("3 el pulso que sale del prisma conserva el elemento (rayo) y NO es del jugador; no recorre la veta por donde vino",
		prisma.ultimo != null and prisma.ultimo.elemento == "rayo" and not prisma.ultimo.del_jugador and not prisma.ultimo.alcanzadas.has(Vector2i(16, 16)))
	await avanzar_s(Pulso3D.T_COLA + 1.0)

	# 4 · La charca helada corta el circuito
	await _sin_pulsos_en_vuelo()
	receptor.apagar()
	Flags.i().quitar(FLAG_RECEPTOR)
	for y in range(CHARCA.position.y, CHARCA.end.y):
		for x in range(CHARCA.position.x, CHARCA.end.x):
			var c := Vector2i(x, y)
			Terreno3D.agua_sim.helar_casilla(c, true)
			Terreno3D.poner_helada(c, true)
	_ok("4 con la charca helada ninguna casilla de agua conduce", not Terreno3D.conduce(Vector2i(22, 14)) and not Terreno3D.conduce(Vector2i(24, 13)))
	await avanzar_s(0.3)
	var helado: Pulso3D = Pulso3D.emitir(maqueta, [Vector2i(24, 12)], "rayo", 24, fuente)
	_ok("4 con la charca helada el pulso de la fuente no alcanza la veta de C5 (queda en 1 casilla)", not helado.alcanzadas.has(Vector2i(19, 16)) and helado.alcanzadas.size() == 1, "%d casillas" % helado.alcanzadas.size())
	await avanzar_s(8.0)                         # incluye dos descargas más: ninguna puede llegar
	_ok("4 y el receptor sigue sin activarse durante varias descargas", not receptor.activo and not Flags.i().tiene(FLAG_RECEPTOR))
	# El mismo pulso sobre el agua libre sí llega (la comparación honesta: la diferencia la hace el hielo).
	for y in range(CHARCA.position.y, CHARCA.end.y):
		for x in range(CHARCA.position.x, CHARCA.end.x):
			var c2 := Vector2i(x, y)
			Terreno3D.agua_sim.helar_casilla(c2, false)
			Terreno3D.poner_helada(c2, false)
	await avanzar_s(0.3)
	var emisiones0: int = prisma.emisiones
	var libre: Pulso3D = Pulso3D.emitir(maqueta, [Vector2i(24, 12)], "rayo", 24, fuente)
	_ok("4 deshelada la charca, el mismo pulso sí llega al final de la veta de C5 y toca el prisma", libre.alcanzadas.has(Vector2i(16, 16)) and libre.tocadas.has(CELDA_PRISMA), "%d casillas" % libre.alcanzadas.size())
	await avanzar_s(1.6)
	_ok("4 y el prisma lo reemite hasta el receptor", prisma.emisiones > emisiones0 and receptor.activo)
	await avanzar_s(Pulso3D.T_COLA)

	await _brillo_azul(cristal, veta1)
	await _prisma_y_pared(prisma, pared, receptor, fuente)
	await _pared_reconocible(pared)
	await _cofre(tesoro, receptor, prisma)
	await _glifo_del_jugador(pared, receptor, prisma)


# ---------------------------------------------------------------------------------------------------------------------
#  5 · La Cueva iluminada en azul
# ---------------------------------------------------------------------------------------------------------------------

func _brillo_azul(cristal: CristalPulso3D, veta1: VetaPulso3D) -> void:
	var espera_reposo: float = 0.0
	while (cristal.destello > 0.0 or cristal._enfriando > 0.0) and espera_reposo < 5.0:
		espera_reposo += await avanzar_s(0.05)
	await process_frame
	_ok("5 las constantes del brillo azul son sutiles: reposo ≤ 8 % del destello, luz de reposo ≤ 0,9 y cupo de luces acotado (≤ 10)",
		BrilloPulso3D.ENERGIA_REPOSO <= BrilloPulso3D.ENERGIA_MAX * 0.08 and BrilloPulso3D.LUZ_REPOSO_ENERGIA <= 0.9 and BrilloPulso3D.MAX_LUCES_REPOSO <= 10)
	_ok("5 la luz de reposo es una fracción del destello: ≤ 40 % del pico de luz del cristal (reposo + ENERGIA_LUZ) y su emisión ≤ 10 % de la del pulso",
		BrilloPulso3D.LUZ_REPOSO_ENERGIA <= 0.4 * (BrilloPulso3D.LUZ_REPOSO_ENERGIA + CristalPulso3D.ENERGIA_LUZ) and BrilloPulso3D.ENERGIA_REPOSO <= 0.1 * BrilloPulso3D.ENERGIA_MAX,
		"%.2f de %.2f" % [BrilloPulso3D.LUZ_REPOSO_ENERGIA, BrilloPulso3D.LUZ_REPOSO_ENERGIA + CristalPulso3D.ENERGIA_LUZ])
	_ok("5 el color de reposo es el azul claro del pulso base (#9ED9FF)", BrilloPulso3D.COLOR_REPOSO.is_equal_approx(Pulso3D.COLOR_BASE))
	var mat_ok: bool = not cristal._mats.is_empty()
	for m in cristal._mats:
		if absf(float((m as ShaderMaterial).get_shader_parameter("energia_reposo")) - BrilloPulso3D.ENERGIA_REPOSO) > 1.0e-5:
			mat_ok = false
	_ok("5 el cristal tiene en reposo la emisión azul muy baja (energia_reposo = ENERGIA_REPOSO)", mat_ok)
	_ok("5 en reposo el cristal tiene su luz azul tenue", cristal._luz_reposo and absf(cristal._luz.light_energy - BrilloPulso3D.LUZ_REPOSO_ENERGIA) < 0.01 and cristal._luz.light_color.is_equal_approx(BrilloPulso3D.COLOR_REPOSO),
		"energía %.2f" % cristal._luz.light_energy)
	var suelo_mat: ShaderMaterial = cristal._suelo.material_override as ShaderMaterial if cristal._suelo != null else null
	_ok("5 el cristal pone en el SUELO a su pie una mancha de luz azul de reposo (SUELO_ENERGIA_REPOSO)", suelo_mat != null and absf(float(suelo_mat.get_shader_parameter("energia")) - BrilloPulso3D.SUELO_ENERGIA_REPOSO) < 1.0e-4)
	cristal.latir("")
	await process_frame
	_ok("5 y en el destello la mancha del suelo sube a 3× o más el reposo", suelo_mat != null and float(suelo_mat.get_shader_parameter("energia")) >= 3.0 * BrilloPulso3D.SUELO_ENERGIA_REPOSO, "%.2f" % float(suelo_mat.get_shader_parameter("energia")) if suelo_mat != null else "sin mancha")
	_ok("5 el destello del pulso queda MUY por encima del brillo de reposo (la luz × 2,5 o más, ya con el destello bajando un fotograma)", cristal._luz.light_energy >= BrilloPulso3D.LUZ_REPOSO_ENERGIA * 2.5, "energía %.2f" % cristal._luz.light_energy)
	_ok("5 hay luces de reposo pero no más que el cupo", BrilloPulso3D.luces_reservadas() >= 2 and BrilloPulso3D.luces_reservadas() <= BrilloPulso3D.MAX_LUCES_REPOSO, "%d luces" % BrilloPulso3D.luces_reservadas())
	var veta_ok: bool = false
	for c in veta1._mats:
		veta_ok = absf(float((veta1._mats[c] as ShaderMaterial).get_shader_parameter("emision_reposo")) - VetaPulso3D.EMISION_REPOSO) < 1.0e-5
	_ok("5 las vetas brillan también un poco en reposo (EMISION_REPOSO) y el frente las lleva a 0,9", veta_ok and VetaPulso3D.EMISION_REPOSO < VetaPulso3D.EMISION * 0.2)


# ---------------------------------------------------------------------------------------------------------------------
#  6 y 7 · Prisma y pared hueca
# ---------------------------------------------------------------------------------------------------------------------

func _prisma_y_pared(prisma: PrismaPulso3D, pared: ParedHuecaPulso3D, receptor: ReceptorPulso3D, fuente: EmisorRayo3D) -> void:
	# 6 · girar
	await avanzar_s(PrismaPulso3D.ENFRIAR + 0.1)
	var vuelta: Array = []
	for _i in range(4):
		_ok("6 el prisma gira un cuarto de vuelta", prisma.girar())
		vuelta.append(prisma.dir)
		await avanzar_s(PrismaPulso3D.ENFRIAR + 0.05)
	_ok("6 cuatro giros = vuelta entera en sentido horario (e, s, o, n)", vuelta == ["e", "s", "o", "n"], str(vuelta))
	_ok("6 un segundo giro inmediato no lo hace dar vueltas (enfriamiento)", prisma.girar() and not prisma.girar())
	await avanzar_s(PrismaPulso3D.ENFRIAR + 0.05)
	prisma.poner_dir("n")
	await avanzar_s(PrismaPulso3D.ENFRIAR + 0.05)
	var giros0: int = prisma.giros
	prisma.on_spell_hit(load("res://nucleo/water_rune.tres") as RuneData)
	_ok("6 un golpe de hechizo (cualquier elemento) lo gira también", prisma.giros == giros0 + 1 and prisma.dir == "e", prisma.dir)
	await avanzar_s(PrismaPulso3D.ENFRIAR + 0.05)
	prisma.poner_dir("n")
	await avanzar_s(PrismaPulso3D.ENFRIAR + 0.05)
	var sale_norte: Vector2i = prisma.casilla_salida()
	await avanzar_s(PrismaPulso3D.ENFRIAR + 0.05)
	prisma.poner_dir("o")
	_ok("6 la casilla de salida sigue a la dirección (n → (15,15), o → (14,16))", sale_norte == Vector2i(15, 15) and prisma.casilla_salida() == Vector2i(14, 16))
	_ok("6 el ángulo del modelo da cuartos de vuelta distintos para cada dirección (n 0, e −90°, s −180°, o −270°)", PrismaPulso3D.angulo_de("n") == 0.0 and absf(PrismaPulso3D.angulo_de("e") + PI * 0.5) < 1.0e-6
		and absf(PrismaPulso3D.angulo_de("s") + PI) < 1.0e-6 and absf(PrismaPulso3D.angulo_de("o") + PI * 1.5) < 1.0e-6)
	# 7 · girado al oeste, el pulso del escenario llega a la pared hueca: eco, no se abre
	receptor.apagar()
	Flags.i().quitar(FLAG_RECEPTOR)
	var ecos0: int = pared.ecos
	var emisiones0: int = prisma.emisiones
	var visto: Array = []                                           ## lo que sale del prisma, apuntado al emitir (el pulso se libera solo)
	prisma.emite.connect(func(p: Pulso3D) -> void: visto.append({"elemento": p.elemento, "propio": p.del_jugador, "casillas": p.alcanzadas.keys()}))
	Pulso3D.emitir(maqueta, [Vector2i(24, 12)], "rayo", 24, fuente)
	await avanzar_s(2.0)
	var llego_a_la_pared: bool = false
	for v in visto:
		if (v["casillas"] as Array).has(Vector2i(10, 16)):
			llego_a_la_pared = true
	_ok("7 el prisma girado al oeste reemite por la veta que va a la pared hueca (al menos una vez más: la fuente también descarga sola)", prisma.emisiones >= emisiones0 + 1 and llego_a_la_pared, str(visto))
	_ok("7 y el receptor ya NO se activa por ahí (el pulso se ha desviado)", not receptor.activo)
	_ok("7 la pared hueca responde con un ECO al pulso del escenario…", pared.ecos >= ecos0 + 1 and not pared.ultimo_pulso_propio)
	_ok("7 …pero NO se abre (solo se abre con el pulso del jugador): sigue cerrada, bloqueada y sin flag", not pared.abierta and Terreno3D.bloqueada(CELDA_PARED) and not Flags.i().tiene(FLAG_SALIDA))
	_ok("7 lo que sale del prisma conserva el elemento (rayo) y sigue sin ser del jugador", not visto.is_empty() and visto.all(func(v: Dictionary) -> bool: return v["elemento"] == "rayo" and not v["propio"]))
	# Sin reentradas: un pulso que ya pasó por el prisma no vuelve a salir de él.
	var emisiones1: int = prisma.emisiones
	var propio: Pulso3D = Pulso3D.new()
	propio.linaje = [prisma]
	propio.dibujar = false
	propio.preparar([Vector2i(17, 16)], "", 3)
	_ok("7 sin reentradas: un pulso cuyo linaje ya incluye al prisma no lo hace emitir de nuevo", prisma.on_pulso(propio) == null and prisma.emisiones == emisiones1)
	propio.free()
	# De vuelta al norte para el resto
	prisma.poner_dir("n")
	await avanzar_s(PrismaPulso3D.ENFRIAR + Pulso3D.T_COLA)


# ---------------------------------------------------------------------------------------------------------------------
#  8 · El cofre legendario
# ---------------------------------------------------------------------------------------------------------------------

func _cofre(tesoro: Puzle3D.CofrePuzle, receptor: ReceptorPulso3D, prisma: PrismaPulso3D) -> void:
	receptor.apagar()
	Flags.i().quitar(FLAG_RECEPTOR)
	await avanzar(2)
	_ok("8 sellado: sin el receptor activo el cofre no se abre", not tesoro.sellado_cumplido() and not tesoro.abrir() and tesoro.es_cerrado)
	receptor.activar()
	await avanzar(2)
	_ok("8 con el receptor activo el cofre queda desellado", tesoro.sellado_cumplido() and Flags.i().tiene(FLAG_RECEPTOR))
	colocar_jugador(Vector2i(13, 14))
	await avanzar_s(0.5)
	var tam0: float = float(maqueta.get("_tam_camara"))
	var sol: DirectionalLight3D = maqueta.get("_sol") as DirectionalLight3D
	var luz0: float = sol.light_energy if sol != null else 1.0
	_ok("8 el cofre aún no ha dado el glifo (flag y libro)", not Flags.i().tiene(FLAG_GLIFO) and not Repertoire.sigil_active("raido"))
	_ok("8 abrir el cofre arranca la secuencia", tesoro.abrir() and tesoro.secuencia != null and tesoro.secuencia.activa)
	var seq: SecuenciaCofreLegendario3D = tesoro.secuencia
	_ok("8 es la primera vez: no se puede saltar", not seq.saltable and not seq.saltar())
	var fases_vistas: Array = []
	var bloqueado_visto: bool = false
	var tam_min: float = 99.0
	var luz_min: float = 99.0
	var t_inicio: float = reloj.t
	var hay_pagina: bool = false
	var hay_halo: bool = false
	var escrito_v: Array = [-1.0]
	seq.glifo_escrito.connect(func() -> void: escrito_v[0] = reloj.t - t_inicio)
	while not seq.hecha and reloj.t - t_inicio < 12.0:
		await process_frame
		if fases_vistas.is_empty() or fases_vistas.back() != seq.fase:
			fases_vistas.append(seq.fase)
		bloqueado_visto = bloqueado_visto or bool(jugador.get("bloqueado"))
		tam_min = minf(tam_min, float(maqueta.get("_tam_camara")))
		if sol != null:
			luz_min = minf(luz_min, sol.light_energy / maxf(luz0, 0.0001))
		hay_pagina = hay_pagina or seq._pagina != null
		hay_halo = hay_halo or seq._halo != null
	var dura: float = reloj.t - t_inicio
	_ok("8 la secuencia pasa por sus pasos en orden (control, luz, onda, glifo, destello, escritura, fin)", fases_vistas == ["control", "luz", "onda", "glifo", "destello", "escritura", "fin"], str(fases_vistas))
	_ok("8 dura 4,5 s de escena más lo que tarda en volver la luz y la cámara (entre 4,5 y 6)", dura >= SecuenciaCofreLegendario3D.T_FIN and dura <= 6.0, "%.2f s" % dura)
	_ok("8 el control se bloquea durante la secuencia y vuelve al acabar", bloqueado_visto and not bool(jugador.get("bloqueado")))
	_ok("8 la cámara se acerca al primer plano (≤ %.1f) y vuelve a su tamaño" % (SecuenciaCofreLegendario3D.TAM_PRIMER_PLANO + 0.2), tam_min <= SecuenciaCofreLegendario3D.TAM_PRIMER_PLANO + 0.2
		and absf(float(maqueta.get("_tam_camara")) - tam0) < 0.05, "mín %.2f · antes %.2f · después %.2f" % [tam_min, tam0, float(maqueta.get("_tam_camara"))])
	_ok("8 la luz de la zona baja al %d %% y vuelve entera" % int(SecuenciaCofreLegendario3D.LUZ_ZONA_FRACCION * 100.0), luz_min <= SecuenciaCofreLegendario3D.LUZ_ZONA_FRACCION + 0.05 and (sol == null or absf(sol.light_energy - luz0) < 0.01),
		"mín %.2f" % luz_min)
	_ok("8 sale el glifo con su halo y cae a una página del libro que se abre sola", hay_halo and hay_pagina)
	var escrito_a: float = float(escrito_v[0])
	_ok("8 el glifo se escribe entre los 3,2 s y los 4,5 s (antes de que vuelva la luz)", escrito_a >= SecuenciaCofreLegendario3D.T_ESCRIBE and escrito_a <= SecuenciaCofreLegendario3D.T_FIN + 0.2, "%.2f s" % escrito_a)
	_ok("8 el cofre pone la flag cueva.c6.glifo y queda abierto", Flags.i().tiene(FLAG_GLIFO) and tesoro.es_abierto)
	_ok("8 ᚱ «pulso» queda desbloqueado en el libro (Repertoire)", Repertoire.sigil_active("raido") and Sigils.nombre_visible("raido") == "pulso" and Sigils.nombre_visible("pulso") == "crecer")
	_ok("8 la secuencia deja puesta la flag de 'ya vista' (para poder saltarla la próxima vez)", Flags.i().tiene(SecuenciaCofreLegendario3D.FLAG_VISTA))
	_tapa_abierta(tesoro)
	# Segunda vez: se puede saltar, y acaba de golpe con el glifo ya dado.
	var otra := SecuenciaCofreLegendario3D.new()
	maqueta.add_child(otra)
	var ya_escrito: Array = [false]
	otra.glifo_escrito.connect(func() -> void: ya_escrito[0] = true)
	otra.iniciar(tesoro, null, maqueta, "raido")
	_ok("8 a partir de la segunda vez la secuencia es saltable", otra.saltable and otra.saltar())
	var t_salto: float = reloj.t
	while not otra.hecha and reloj.t - t_salto < 3.0:
		await process_frame
	_ok("8 saltada, acaba en menos de 1 s con el glifo escrito y todo en su sitio", otra.hecha and ya_escrito[0] and reloj.t - t_salto < 1.0 and not bool(jugador.get("bloqueado"))
		and absf(float(maqueta.get("_tam_camara")) - tam0) < 0.05, "%.2f s" % (reloj.t - t_salto))
	await avanzar_s(1.2)


## Arreglo de la pared hueca (23/10): en reposo no se camufla. Tiene sus grietas en el suelo (latido lento entre GRIETAS_MIN y GRIETAS_MAX), una luz azul tenue delante, y AVISA
## una vez al acercarse a ALCANCE_AVISO casillas (grietas por encima del reposo y nota grave); el eco del pulso las enciende aún más; y al abrirse se apagan.
func _pared_reconocible(pared: ParedHuecaPulso3D) -> void:
	await avanzar_s(ParedHuecaPulso3D.T_ECO + 0.3)                 # que se acabe el eco del test anterior
	_ok("7b la pared hueca tiene su suelo agrietado (el indicio) con el shader de grietas y una luz azul delante", pared._grietas != null and pared._mat_grietas != null and pared._luz != null)
	if pared._grietas == null:
		return
	colocar_jugador(Vector2i(16, 13))                               # lejos: a más de ALCANCE_AVISO casillas
	await avanzar_s(0.6)
	var lejos: bool = Vector2(jugador.global_position.x - pared.global_position.x, jugador.global_position.z - pared.global_position.z).length() > Terreno3D.casilla * ParedHuecaPulso3D.ALCANCE_AVISO
	var avisos0: int = pared.avisos
	var b_min: float = 99.0
	var b_max: float = -99.0
	var luz_max: float = 0.0
	var t0: float = reloj.t
	while reloj.t - t0 < ParedHuecaPulso3D.T_LATIDO_GRIETAS:
		await process_frame
		var b: float = pared.brillo_grietas()
		b_min = minf(b_min, b)
		b_max = maxf(b_max, b)
		luz_max = maxf(luz_max, pared._luz.light_energy)
	_ok("7b el jugador estaba lejos y no hubo aviso", lejos and pared.avisos == avisos0)
	_ok("7b en reposo las grietas LATEN despacio: suben y bajan entre %.2f y %.2f en un ciclo (%.1f s)" % [ParedHuecaPulso3D.GRIETAS_MIN, ParedHuecaPulso3D.GRIETAS_MAX, ParedHuecaPulso3D.T_LATIDO_GRIETAS],
		b_min >= ParedHuecaPulso3D.GRIETAS_MIN - 0.02 and b_max <= ParedHuecaPulso3D.GRIETAS_MAX + 0.02 and b_max - b_min >= 0.8 * (ParedHuecaPulso3D.GRIETAS_MAX - ParedHuecaPulso3D.GRIETAS_MIN),
		"%.2f..%.2f" % [b_min, b_max])
	_ok("7b y se ven (brillo > 0 y la luz azul delante de la pared, tenue: no pasa de %.1f)" % ParedHuecaPulso3D.LUZ_GRIETAS, b_min > 0.0 and luz_max > 0.3 and luz_max <= ParedHuecaPulso3D.LUZ_GRIETAS + 0.01, "luz %.2f" % luz_max)
	# Al acercarse a 2 casillas: aviso (grietas por encima del latido + nota grave), una vez.
	colocar_jugador(CELDA_PARED + Vector2i(2, 0))
	await avanzar_s(0.5)
	_ok("7b al acercarse a %d casillas la pared AVISA una vez" % int(ParedHuecaPulso3D.ALCANCE_AVISO), pared.avisos == avisos0 + 1, "%d avisos" % (pared.avisos - avisos0))
	_ok("7b y en el aviso las grietas brillan por encima de lo más alto del latido", pared.brillo_grietas() > ParedHuecaPulso3D.GRIETAS_MAX + 0.2, "%.2f" % pared.brillo_grietas())
	await avanzar_s(ParedHuecaPulso3D.ENFRIAR_AVISO + ParedHuecaPulso3D.T_AVISO)
	_ok("7b quedándose cerca no repite el aviso", pared.avisos == avisos0 + 1)
	colocar_jugador(Vector2i(16, 13))
	await avanzar_s(0.6)
	colocar_jugador(CELDA_PARED + Vector2i(2, 0))
	await avanzar_s(0.6)
	_ok("7b yéndose y volviendo, avisa otra vez", pared.avisos == avisos0 + 2, "%d avisos" % (pared.avisos - avisos0))
	# El eco del pulso las enciende más aún que el aviso.
	await avanzar_s(ParedHuecaPulso3D.T_AVISO + 0.2)
	pared.destello = 1.0
	_ok("7b el eco de un pulso las enciende por encima del aviso y del latido", pared.brillo_grietas() >= ParedHuecaPulso3D.GRIETAS_MIN + 1.0 - 1.0e-4)
	pared.destello = 0.0
	colocar_jugador(Vector2i(16, 13))
	await avanzar_s(0.5)


## Arreglo de la tapa (23/10): abierta, queda PEGADA al cuerpo por detrás (eje en el interior del listón de atrás, no flotando) y su interior es liso oscuro-dorado, no el atlas.
func _tapa_abierta(tesoro: Puzle3D.CofrePuzle) -> void:
	var tapa: MeshInstance3D = tesoro.ctrl.get("_tapa") as MeshInstance3D
	var cuerpo: MeshInstance3D = tesoro.ctrl.get("_cuerpo") as MeshInstance3D
	_ok("8b el cofre legendario trae cuerpo y tapa como mallas", tapa != null and cuerpo != null)
	if tapa == null or cuerpo == null:
		return
	var ab: AABB = cuerpo.global_transform * cuerpo.get_aabb()
	var at: AABB = tapa.global_transform * tapa.get_aabb()
	var eje: Vector3 = tapa.global_position                        ## la bisagra (el origen de la tapa)
	var alto: float = ab.size.y
	_ok("8b abierta, la bisagra está dentro del listón de atrás: bajo el borde de arriba del cuerpo y entre su cara de atrás y su centro",
		eje.y < ab.end.y and eje.y > ab.end.y - alto * 0.35 and eje.z > ab.position.z and eje.z < ab.position.z + ab.size.z * 0.5,
		"eje %s · cuerpo %s" % [eje, ab])
	_ok("8b la tapa abierta queda detrás y encima, sin separarse: toca el cuerpo por detrás y sube más que él",
		at.position.z < ab.position.z and at.end.z > ab.position.z and at.end.y > ab.end.y + alto * 0.5 and at.position.y < ab.end.y,
		"tapa %s · cuerpo %s" % [at, ab])
	_ok("8b y no se sale a los lados (su ancho cabe en el del cuerpo)", at.position.x >= ab.position.x - 0.02 * ab.size.x and at.end.x <= ab.end.x + 0.02 * ab.size.x)
	var interior_liso: bool = true
	for pieza in [tapa, cuerpo]:
		var malla: Mesh = (pieza as MeshInstance3D).mesh
		var mat: Material = (pieza as MeshInstance3D).get_active_material(1) if malla.get_surface_count() > 1 else null
		var liso: bool = mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture == null and (mat as BaseMaterial3D).albedo_color.get_luminance() < 0.25
		interior_liso = interior_liso and liso
	_ok("8b el interior de la tapa y del cuerpo es un material liso oscuro (sin la textura del atlas, de ahí el morado)", interior_liso)


# ---------------------------------------------------------------------------------------------------------------------
#  9 · El glifo ᚱ en manos del jugador
# ---------------------------------------------------------------------------------------------------------------------

func _glifo_del_jugador(pared: ParedHuecaPulso3D, receptor: ReceptorPulso3D, prisma: PrismaPulso3D) -> void:
	var fuego: RuneData = load("res://nucleo/fire_rune.tres") as RuneData
	_ok("9 antes de nada: ᚱ ya está en el libro (el cofre lo desbloqueó) y la receta lo acepta", Repertoire.sigil_active("raido"))
	# a) ᚱᚱ + fuego sobre la veta de C5: al inicio; el pulso es DEL JUGADOR (alcance 8) y pasa por el prisma hasta el receptor.
	receptor.apagar()
	Flags.i().quitar(FLAG_RECEPTOR)
	colocar_jugador(Vector2i(17, 16))
	await avanzar_s(0.4)
	var prisma0: int = prisma.emisiones
	var salida_a: Array = []                                        ## lo que reemite el prisma, apuntado al emitir (el pulso se libera solo)
	var conexion_a: Callable = func(p: Pulso3D) -> void: salida_a.append({"elemento": p.elemento, "propio": p.del_jugador, "alcance": p.alcance})
	prisma.emite.connect(conexion_a)
	_ok("9a lanzar ᚱᚱ + fuego sale", await _lanzar_y_ver("fuego", ["raido", "raido"], Vector3.LEFT))
	var vivo: HechizoVivo = _vivo()
	_ok("9a es un hechizo con resuena = 8 (dos glifos, +4 cada uno) y su momento es INICIO", vivo != null and vivo.h.resuena == 8.0 and vivo.h.momento_de("raido") == "inicio")
	var pulso_a: Pulso3D = vivo.pulsos_soltados[0] as Pulso3D if not vivo.pulsos_soltados.is_empty() else null
	_ok("9a el pulso salió al nacer, con el elemento de la receta (fuego), el color de su runa y del jugador", pulso_a != null and pulso_a.elemento == "fuego" and pulso_a.del_jugador
		and pulso_a.color == fuego.color and vivo.momentos_vistos.size() == 1)
	_ok("9a alcance 8 casillas desde donde lanza", pulso_a != null and pulso_a.alcance == 8)
	await avanzar_s(1.5)
	_ok("9a el pulso del jugador pasó por el prisma (sigue siendo del jugador y de fuego, con el alcance que quedaba) y activó el receptor",
		prisma.emisiones == prisma0 + 1 and salida_a.size() == 1 and salida_a[0]["propio"] and salida_a[0]["elemento"] == "fuego" and salida_a[0]["alcance"] == 6 and receptor.activo, str(salida_a))
	prisma.emite.disconnect(conexion_a)
	await avanzar_s(Pulso3D.T_COLA)

	# b) flecha + ᚱ: el pulso sale DONDE CHOCA la flecha, no en la mano.
	receptor.apagar()
	Flags.i().quitar(FLAG_RECEPTOR)
	colocar_jugador(Vector2i(17, 13))
	await avanzar_s(0.4)
	_ok("9b lanzar flecha + ᚱ sale", await _lanzar_y_ver("fuego", ["flecha", "raido"], Vector3.LEFT))
	var flecha: HechizoVivo = _vivo()
	_ok("9b con flecha el momento de ᚱ es FINAL (sin caso especial: lo dice el dato)", flecha != null and flecha.h.momento_de("raido") == "final" and flecha.proyectil)
	var pulsos_f: Array = flecha.pulsos_soltados            # el mismo Array: el nodo se libera al acabar, la lista se queda
	var momentos_f: Array = flecha.momentos_vistos
	await avanzar_s(0.05)
	_ok("9b en el aire todavía no hay pulso (no sale en la mano)", pulsos_f.is_empty() and not receptor.activo)
	var origen_f: Array = []
	var fin_f: Vector2 = Vector2.ZERO
	var espera: float = 0.0
	while pulsos_f.is_empty() and espera < 5.0:
		if is_instance_valid(flecha):
			fin_f = Vector2(Terreno3D.celda_de(flecha.p))
		var t0: float = reloj.t
		await process_frame
		espera += reloj.t - t0
	if not pulsos_f.is_empty():
		origen_f = (pulsos_f[0] as Pulso3D).origenes.duplicate()
	_ok("9b al chocar la flecha suelta UN pulso, donde chocó (junto al receptor, no en la mano)", pulsos_f.size() == 1 and not origen_f.is_empty()
		and Vector2(origen_f[0] as Vector2i).distance_to(Vector2(17, 13)) > 1.5 and Vector2(origen_f[0] as Vector2i).distance_to(Vector2(15, 13)) <= 1.5, "origen %s · la flecha iba por %s" % [str(origen_f), fin_f])
	await avanzar_s(1.0)
	_ok("9b el pulso del choque activa el receptor (a distancia, sin conductor entre medias)", receptor.activo)
	_ok("9b solo una vez (sin reentradas): un único momento final", momentos_f.size() == 1 and String((momentos_f[0] as Dictionary)["momento"]) == "final")
	await avanzar_s(Pulso3D.T_COLA)

	# c) ᚷ «crecer» sigue funcionando como siempre.
	colocar_jugador(Vector2i(12, 14))
	await avanzar_s(0.4)
	_ok("9c lanzar ᚷ (crecer) + fuego sale", await _lanzar_y_ver("fuego", ["pulso"], Vector3.LEFT))
	var crecer: HechizoVivo = _vivo()
	_ok("9c ᚷ «crecer» sigue dando crece = 0,5, figura «pulso», sin pulso resonante ni acciones de momento", crecer != null and crecer.h.crece == 0.5 and crecer.h.figura() == "pulso" and crecer.h.resuena == 0.0
		and crecer.h.acciones_en("inicio").is_empty() and crecer.pulsos_soltados.is_empty())

	# d) barrera + ᚱ: continuo, con periodo mínimo; sin reentradas.
	colocar_jugador(Vector2i(12, 14))
	await avanzar_s(1.0)
	_ok("9d lanzar barrera + ᚱ sale", await _lanzar_y_ver("fuego", ["barrera", "raido"], Vector3.LEFT))
	var muro: HechizoVivo = _vivo()
	_ok("9d con barrera el momento de ᚱ es CONTINUO", muro != null and muro.h.momento_de("raido") == "continuo" and not muro.proyectil)
	var vida: float = muro._vida_continua()
	var periodo: float = maxf(muro.h.intervalo, Sigils.PERIODO_MIN_CONTINUO_S)
	var esperados: int = mini(1 + int(floorf(vida / periodo)), Sigils.MAX_DISPAROS_CONTINUOS)
	var pulsos_m: Array = muro.pulsos_soltados
	var momentos_m: Array = muro.momentos_vistos
	var coste_m: float = muro.h.coste
	await avanzar_s(vida + 0.5)
	_ok("9d late varias veces mientras vive: %d pulsos esperados (vida %.1f s, periodo mínimo %.1f s)" % [esperados, vida, Sigils.PERIODO_MIN_CONTINUO_S], pulsos_m.size() == esperados and esperados >= 2,
		"salieron %d" % pulsos_m.size())
	var separacion_ok: bool = true
	for i in range(1, momentos_m.size()):
		if float((momentos_m[i] as Dictionary)["t"]) - float((momentos_m[i - 1] as Dictionary)["t"]) < Sigils.PERIODO_MIN_CONTINUO_S - 0.1:
			separacion_ok = false
	_ok("9d entre dos latidos hay al menos el periodo mínimo", separacion_ok and momentos_m.size() == pulsos_m.size(), str(momentos_m.map(func(m: Dictionary) -> float: return snappedf(float(m["t"]), 0.01))))
	_ok("9d todos los momentos son «continuo» (ninguno de inicio ni final: sin reentradas)", momentos_m.all(func(m: Dictionary) -> bool: return String(m["momento"]) == "continuo"))
	_ok("9d el pulso continuo cuesta más tinta (recargo del continuo)", Sigils.recargo_continuo({"resuena": 4.0, "solidez": 1.5}) == 1.0 + Sigils.COSTE_CONTINUO_V2 and Sigils.recargo_continuo({"resuena": 4.0}) == 1.0
		and coste_m > Hechizo.construir(fuego, {"barrera": 1}).coste)

	# e) ᚱ con la pared hueca: al inicio, parado SOBRE la veta, el pulso del JUGADOR abre la salida (lo que pide la Cueva).
	_ok("9e la pared hueca sigue cerrada antes de usar el glifo", not pared.abierta and Terreno3D.bloqueada(CELDA_PARED))
	colocar_jugador(Vector2i(11, 16))
	await avanzar_s(0.4)
	var ecos0: int = pared.ecos
	_ok("9e lanzar ᚱ + fuego junto a la pared hueca sale", await _lanzar_y_ver("fuego", ["raido"], Vector3.LEFT))
	await avanzar_s(0.6)
	_ok("9e el pulso del jugador hace eco en la pared y la ABRE", pared.ecos == ecos0 + 1 and pared.ultimo_pulso_propio and pared.abierta)
	_ok("9e la casilla de la salida queda libre y se pone la flag de la salida", not Terreno3D.bloqueada(CELDA_PARED) and Flags.i().tiene(FLAG_SALIDA))
	await avanzar_s(ParedHuecaPulso3D.T_ABRIR + 0.3)
	_ok("9e la roca acaba hundida (ya no se ve)", not pared.visible)
	_ok("9e y sus grietas se apagan al abrirse (sin brillo ni aviso)", pared.brillo_grietas() == 0.0 and (pared._grietas == null or not pared._grietas.visible))
	# f) lo que se lee del glifo
	_ok("9f los datos de ᚱ: resuena +4 por glifo con tope 12 y los demás glifos conservan su momento (sin acción)", Hechizo.construir(fuego, {"raido": 2}).resuena == 8.0 and Hechizo.construir(fuego, {"raido": 9}).resuena == 12.0
		and Hechizo.construir(fuego, {"flecha": 1}).acciones_en("continuo").is_empty() and Hechizo.construir(fuego, {"barrera": 1}).acciones_en("continuo").is_empty())
