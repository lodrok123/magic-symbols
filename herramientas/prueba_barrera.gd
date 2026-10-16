extends SceneTree
## La barrera-burbuja (Fase 12, 16/10), sin escena ni ventana: forma y seguimiento, parar un golpe y reventar, la reacción entre elementos
## (agua+fuego → vapor, hielo+fuego → charco, tierra absorbe), caducar sin reventar, una sola a la vez, y lo que arde o lleva corriente
## dentro de la esfera. Lo escribe el Juego. La flecha de un goblin contra la burbuja está en herramientas/escenario_barrera.gd.
##   godot --headless --path . --script res://herramientas/prueba_barrera.gd

class MundoFalso extends Node3D:
	const S: float = 2.3
	const ALTO: float = 2.3 * 0.45
	const ALTO_AGUA: float = 2.3 * 0.45 * 0.6
	var _lado: int = 6
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])

class JugadorFalso extends Node3D:
	pass

class EmisorFalso extends Node3D:
	var electrificada: Array = []

class AntorchaFalsa extends Node3D:
	var is_lit: bool = true

var _fallos: int = 0
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _jug: JugadorFalso = null
var _w: Mundo3D = null
var _impactos: Array = []


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


## Una burbuja del elemento dado, como la que sale al lanzar la página «barrera»: pasa por _crear_campo de verdad.
func _burbuja(elemento: String) -> Lanzador3D.Campo:
	var rune := RuneData.new()
	rune.tags.append(elemento)
	var receta := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	receta.apply("barrera")
	_l._una_ola(receta, rune, elemento, _jug.position, Vector3.RIGHT)
	return _l._barrera_activa


func _initialize() -> void:
	await process_frame
	_m = MundoFalso.new()
	_m._mapa = ["######", "#....#", "#....#", "#....#", "#....#", "######"]
	root.add_child(_m)
	Lanzador3D.configurar(_m)
	for y in range(6):
		for x in range(6):
			if _m._mapa[y][x] == "#":
				_m._bloqueadas[Vector2i(x, y)] = true
	_w = Mundo3D.new()
	root.add_child(_w)
	_w.impacto.connect(func(p: Vector3, el: String, r: float) -> void: _impactos.append([p, el, r]))
	_jug = JugadorFalso.new()
	root.add_child(_jug)
	_jug.position = Lanzador3D.centro_de(Vector2i(2, 2))
	_l = Lanzador3D.new()
	_l.mundo = _m
	_l.jugador = _jug
	root.add_child(_l)
	await process_frame
	var sim: AguaSim3D = Terreno3D.agua_sim     # el del Lanzador (su _ready monta el suyo): el que ve la reacción
	if sim == null:
		sim = Lanzador3D.montar_agua_sim()

	# --- 1 · La forma: una esfera de 1,3 u sobre el jugador ---
	var b: Lanzador3D.Campo = _burbuja("agua")
	_ok("1 lanzar la barrera crea UNA burbuja y es la barrera activa", b != null and b.burbuja and _l._barrera_activa == b)
	_ok("1 es una sola esfera (no el anillo de casillas de antes)", b.puntos.size() == 1)
	_ok("1 su centro es el jugador + (0, %.1f, 0)" % Lanzador3D.ALTO_BURBUJA, b.centro().is_equal_approx(_jug.position + Vector3(0.0, Lanzador3D.ALTO_BURBUJA, 0.0)), str(b.centro()))
	_ok("1 contiene un punto a 1,2 u del centro y no uno a 1,4 u", b.contiene(b.centro() + Vector3(1.2, 0.0, 0.0)) and not b.contiene(b.centro() + Vector3(1.4, 0.0, 0.0)))
	_ok("1 el radio es RADIO_BURBUJA = 1,3", is_equal_approx(Lanzador3D.RADIO_BURBUJA, 1.3))
	_ok("1 no bloquea los hechizos del propio jugador (sus flechas salen de dentro)", not b.bloquea and not _l._barrera_en(_jug.position + Vector3(0.6, 0.9, 0.0), 0))
	_ok("1 dura vida_campo (la barrera ya duraba el doble, mínimo %.0f s)" % Lanzador3D.VIDA_MIN_BARRERA, b.vida >= Lanzador3D.VIDA_MIN_BARRERA, "%.1f s" % b.vida)

	# --- 2 · Le sigue ---
	_jug.position += Vector3(3.0, 0.0, 1.0)
	b._physics_process(1.0 / 60.0)
	_ok("2 sigue al jugador cuando se mueve", b.centro().is_equal_approx(_jug.position + Vector3(0.0, Lanzador3D.ALTO_BURBUJA, 0.0)) and (b.puntos[0] as Vector3).is_equal_approx(b.centro()))
	_jug.position = Lanzador3D.centro_de(Vector2i(2, 2))
	b._physics_process(1.0 / 60.0)

	# --- 3 · Un golpe de enemigo la revienta, y el daño no llega ---
	var recibidos: Array = []
	b.revento.connect(func(rec: String, p: Vector3, reac: String) -> void: recibidos.append([rec, p, reac]))
	var desde: Vector3 = _jug.position + Vector3(2.0, 0.0, 0.0)
	var paro: bool = _l.absorber_golpe(20.0, desde)
	_ok("3 absorber_golpe para el golpe (el daño no llega al jugador)", paro)
	_ok("3 y la burbuja ha reventado, con un golpe normal («» de elemento)", b.reventada and recibidos.size() == 1 and String(recibidos[0][0]) == "")
	_ok("3 el punto del impacto está en la esfera, del lado del atacante", not recibidos.is_empty() and absf((recibidos[0][1] as Vector3).distance_to(b.centro()) - Lanzador3D.RADIO_BURBUJA) < 1.0e-3 and (recibidos[0][1] as Vector3).x > b.centro().x)
	_ok("3 la salpicadura sale por la fachada con el elemento de la burbuja y su radio", _impactos.any(func(i: Array) -> bool: return String(i[1]) == "agua" and absf(float(i[2]) - Lanzador3D.RADIO_BURBUJA) < 1.0e-4), str(_impactos))
	_ok("3 un golpe normal no tiene reacción", b.reaccion == "")
	_ok("3 un segundo golpe en el mismo fotograma ya no la encuentra", not _l.absorber_golpe(20.0, desde))
	await process_frame
	await process_frame
	_ok("3 el campo queda liberado", not is_instance_valid(b))
	_ok("3 y con el campo liberado no hay barrera que pare nada", not _l.absorber_golpe(20.0, desde))

	# --- 4 · Agua + fuego → vapor: se quita el agua del punto y la maqueta recibe «vapor» ---
	var punto: Vector3 = Lanzador3D.centro_de(Vector2i(2, 2), 0.0)
	sim.anadir(punto, 1.0, 0.5)
	for _i in range(60):
		sim.paso(1.0 / 60.0)
	var v0: float = sim.volumen_total()
	_impactos.clear()
	var ba: Lanzador3D.Campo = _burbuja("agua")
	v0 = sim.volumen_total()                                     # tras crearla: lanzar la barrera ya pudo mover agua
	_ok("4 la burbuja de agua recibe fuego y revienta", _l.burbuja_recibe("fuego", punto) and ba.reventada)
	_ok("4 la reacción es «vapor»", ba.reaccion == "vapor", ba.reaccion)
	_ok("4 el agua del punto baja (se evapora): %.2f → %.2f u³" % [v0, sim.volumen_total()], sim.volumen_total() < v0 - 0.05)
	_ok("4 la maqueta recibe «vapor» y la salpicadura del agua", _impactos.any(func(i: Array) -> bool: return String(i[1]) == "vapor") and _impactos.any(func(i: Array) -> bool: return String(i[1]) == "agua"), str(_impactos.map(func(i: Array) -> String: return String(i[1]))))
	await process_frame
	await process_frame

	# --- 5 · Hielo + fuego → charco ---
	var bh: Lanzador3D.Campo = _burbuja("hielo")
	var v1: float = sim.volumen_total()
	_ok("5 la burbuja de hielo recibe fuego y revienta con reacción «charco»", _l.burbuja_recibe("fuego", punto) and bh.reaccion == "charco", bh.reaccion)
	_ok("5 el charco echa %.2f u³ de agua en el punto" % ReaccionesAgua3D.VOL_AGUA_IMPACTO, absf((sim.volumen_total() - v1) - ReaccionesAgua3D.VOL_AGUA_IMPACTO) < 0.02, "%.3f" % (sim.volumen_total() - v1))
	await process_frame
	await process_frame

	# --- 6 · Tierra absorbe sin más ---
	var bt: Lanzador3D.Campo = _burbuja("tierra")
	var v2: float = sim.volumen_total()
	_ok("6 la burbuja de tierra recibe fuego, revienta y «absorbe»", _l.burbuja_recibe("fuego", punto) and bt.reaccion == "absorbe", bt.reaccion)
	_ok("6 sin tocar el agua del mundo", absf(sim.volumen_total() - v2) < 0.01)
	await process_frame
	await process_frame

	# --- 7 · Fuego + agua → vapor (al revés), y agua + hielo no reacciona (solo salpica) ---
	var bf: Lanzador3D.Campo = _burbuja("fuego")
	_ok("7 la burbuja de fuego recibe agua: «vapor»", _l.burbuja_recibe("agua", punto) and bf.reaccion == "vapor", bf.reaccion)
	await process_frame
	await process_frame
	var bn: Lanzador3D.Campo = _burbuja("agua")
	_ok("7 agua + hielo: sin reacción, pero revienta", _l.burbuja_recibe("hielo", punto) and bn.reaccion == "" and bn.reventada)
	await process_frame
	await process_frame

	# --- 8 · Sin tocarla caduca y NO revienta ---
	_impactos.clear()
	var bc: Lanzador3D.Campo = _burbuja("agua")
	var reventó: Array = [false]
	bc.revento.connect(func(_r: String, _p: Vector3, _x: String) -> void: reventó[0] = true)
	bc.vida = 0.5
	for _i in range(40):
		bc._physics_process(1.0 / 60.0)
	_ok("8 pasada su vida, la burbuja se libera sin haber reventado", bc.is_queued_for_deletion() and not bc.reventada and not reventó[0])
	_ok("8 y se desvanece sin salpicar ni reaccionar", _impactos.is_empty(), str(_impactos))
	await process_frame
	await process_frame

	# --- 9 · Dos seguidas: una viva ---
	var b1: Lanzador3D.Campo = _burbuja("agua")
	var b1_reventó: Array = [false]
	b1.revento.connect(func(_r: String, _p: Vector3, _x: String) -> void: b1_reventó[0] = true)
	var b2: Lanzador3D.Campo = _burbuja("fuego")
	await process_frame
	await process_frame
	var vivas: int = 0
	for h in _m.get_children():
		if h is Lanzador3D.Campo and (h as Lanzador3D.Campo).burbuja and not (h as Lanzador3D.Campo).is_queued_for_deletion():
			vivas += 1
	_ok("9 dos barreras seguidas dejan UNA burbuja viva (la nueva)", vivas == 1 and not is_instance_valid(b1) and is_instance_valid(b2) and _l._barrera_activa == b2, "%d vivas" % vivas)
	_ok("9 la vieja se fue sin reventar", not b1_reventó[0])
	if is_instance_valid(b2):
		b2.queue_free()
	await process_frame
	await process_frame

	# --- 10 · Lo que ya arde o lleva corriente dentro de la esfera la revienta ---
	var be: Lanzador3D.Campo = _burbuja("agua")
	var emisor := EmisorFalso.new()
	emisor.add_to_group("emisor_rayo")
	root.add_child(emisor)
	emisor.electrificada = [Vector2i(5, 5)]                      # una casilla lejos
	be._vigilar_mundo()
	_ok("10 agua electrificada lejos de la esfera: no pasa nada", not be.reventada)
	emisor.electrificada = [Vector2i(3, 2)]                      # la casilla vecina: la esfera (1,3 u) alcanza su borde (1,15 u)
	be._vigilar_mundo()
	_ok("10 agua electrificada tocando la esfera: revienta con «rayo»", be.reventada)
	emisor.queue_free()
	await process_frame
	await process_frame
	var bq: Lanzador3D.Campo = _burbuja("agua")
	var antorcha := AntorchaFalsa.new()
	antorcha.add_to_group("flammable3d")
	root.add_child(antorcha)
	antorcha.position = _jug.position + Vector3(3.0, 0.0, 0.0)
	bq._vigilar_mundo()
	_ok("10 una llama a 3 u: no pasa nada", not bq.reventada)
	antorcha.position = _jug.position + Vector3(1.5, 0.0, 0.0)
	bq._vigilar_mundo()
	_ok("10 una llama pegada a la esfera: revienta con «fuego» y reacción «vapor»", bq.reventada and bq.reaccion == "vapor", bq.reaccion)
	antorcha.queue_free()
	await process_frame
	await process_frame

	# --- 11 · Ya no hay escudo de vida ---
	_ok("11 VIDA_ESCUDO y ESCALA_CUPULA ya no existen", not _l.get_script().get_script_constant_map().has("VIDA_ESCUDO") and not _l.get_script().get_script_constant_map().has("ESCALA_CUPULA"))

	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
