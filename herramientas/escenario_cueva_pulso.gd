extends "res://herramientas/escenario_base.gd"
## EL PULSO EN LA CUEVA (23/10, FASE 1 del Pulso resonante; docs/PLAN_PULSO_RESONANTE.md §5, §6 y §12.1). Headless, con la escena de verdad (PruebaCueva):
## 1 · Puzle3D monta el cristal, las dos vetas y el receptor sin avisos, y las vetas son conductor del pulso (`Pulso3D.vetas`).
## 2 · C1: el cristal LATE solo; su pulso recorre la veta casilla a casilla (el frente avanza y deja atrás las casillas apagadas); un hechizo de fuego le hace latir con pulso de fuego.
## 3 · C5 → C6: cada descarga de la fuente suelta un pulso de rayo por el agua y la veta; llega al receptor de C6 con el retraso por casilla, lo activa y pone su flag.
## 4 · Si la charca se hiela, el agua deja de conducir y el pulso NO llega.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_cueva_pulso.gd

const RUTA: String = "res://escenas/PruebaCueva.tscn"
const VETA_C1: Array = [Vector2i(5, 15), Vector2i(4, 15), Vector2i(3, 15), Vector2i(2, 15), Vector2i(2, 14), Vector2i(2, 13)]   ## por orden de paso
const VETA_C5: Array = [Vector2i(19, 16), Vector2i(18, 16), Vector2i(17, 16), Vector2i(16, 16), Vector2i(15, 16), Vector2i(15, 15), Vector2i(15, 14), Vector2i(15, 13)]
const CHARCA: Rect2i = Rect2i(20, 13, 5, 4)
const FLAG_RECEPTOR: String = "cueva.c6.pulso"

var _z: Puzle3D = null


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
	_ok("1 están el cristal de C1, las dos vetas, el receptor de C6 y la fuente", cristal != null and veta1 != null and veta5 != null and receptor != null and fuente != null)
	if cristal == null or veta1 == null or veta5 == null or receptor == null or fuente == null:
		return
	var todas_vetas: bool = true
	for c in VETA_C1 + VETA_C5:
		if not Pulso3D.vetas.has(c):
			todas_vetas = false
	_ok("1 las casillas de las dos vetas conducen el pulso (Pulso3D.vetas)", todas_vetas and Pulso3D.vetas.size() == VETA_C1.size() + VETA_C5.size(), "%d casillas" % Pulso3D.vetas.size())
	_ok("1 el cristal y el receptor bloquean su casilla (son piezas sólidas)", Terreno3D.bloqueada(Vector2i(6, 15)) and Terreno3D.bloqueada(Vector2i(14, 13)))
	_ok("1 el receptor nace sin flag (con Flags.nuevo(); si ya estuviera activado es que ya pasó una descarga de la fuente durante la carga)", not receptor.activo or Flags.i().tiene(FLAG_RECEPTOR))

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
	_ok("2 C1: el pulso nace sin elemento y con el azul claro del base", p1.elemento == "" and p1.color == Pulso3D.COLOR_BASE)
	# Muestreo del frente por fotogramas: qué casillas de la veta están encendidas en cada momento.
	var primera_encendida: Array = []            ## por fotograma: cuántas casillas de la veta brillan > 0,05
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

	# 3 · C5 → C6
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
	_ok("3 C5→C6: una descarga de la fuente llega al receptor de C6 y lo activa", receptor.activo and t_activado[0] >= 0.0, "esperé %.1f s" % esperado)
	_ok("3 C6: el receptor pone su flag (cueva.c6.pulso)", Flags.i().tiene(FLAG_RECEPTOR))
	var viaje: float = t_activado[0] - t_descarga[0]
	var minimo: float = 17.0 * Pulso3D.SEG_POR_CASILLA                 # 16 casillas de agua y veta + 1 hasta el receptor, a 0,08 s
	_ok("3 el pulso TARDA en llegar (≥ %.2f s: 17 casillas) y no es instantáneo" % minimo, viaje >= minimo - 0.07 and viaje < 3.0, "descarga → receptor: %.2f s" % viaje)
	await avanzar_s(Pulso3D.T_COLA + 1.0)

	# 4 · La charca helada corta el circuito
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
	var libre: Pulso3D = Pulso3D.emitir(maqueta, [Vector2i(24, 12)], "rayo", 24, fuente)
	_ok("4 deshelada la charca, el mismo pulso sí llega al final de la veta y toca el receptor", libre.alcanzadas.has(Vector2i(15, 13)) and libre.tocadas.has(Vector2i(14, 13)), "%d casillas" % libre.alcanzadas.size())
