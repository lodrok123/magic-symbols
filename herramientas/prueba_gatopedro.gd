extends SceneTree
## Gatopedro (14/10): el enemigo que huye. Sin ventana y sin modelo: usa los Combate3D/Terreno3D de verdad sobre una maqueta falsa
## de 20×20 con un muro y un callejón, y un Jugador3D sin montar que se mueve a mano. Mide lo que el diseño promete:
##   1) cae con 2 flechas de fuego y NO con 1 (ni con 1 + toda su quemadura); 2) huye al detectarte y no antes; 3) corre a
##   tramos y se para a mirar solo si estás lejos; 4) no ataca; 5) no pisa lo que no se pisa y no se va del tutorial;
##   6) acorralado, no revienta; 7) se calma y vuelve a casa; 8) los goblins siguen con sus sonidos de siempre.
## Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_gatopedro.gd

class MundoFalso extends Node3D:
	const S: float = 2.3
	const ALTO: float = 2.3 * 0.45
	const ALTO_AGUA: float = 2.3 * 0.45 * 0.6
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var _goblins: Array = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])

const DT: float = 1.0 / 60.0

var _fallos: int = 0
var _mundo: MundoFalso = null


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _construir_mapa() -> void:
	# 20×20 de suelo con borde de muro. Un muro vertical en x=10 con un hueco, y un callejón sin salida abajo a la izquierda.
	var filas: PackedStringArray = []
	for y in range(20):
		var f: String = ""
		for x in range(20):
			var l: String = "."
			if x == 0 or y == 0 or x == 19 or y == 19:
				l = "#"
			if x == 10 and y >= 2 and y <= 16 and y != 9:
				l = "#"
			if y == 15 and x >= 2 and x <= 6:        # techo del callejón
				l = "#"
			if y == 18 and x >= 2 and x <= 6:        # suelo del callejón
				l = "#"
			if x == 6 and y >= 16 and y <= 17:       # fondo cerrado del callejón (x=6)
				l = "#"
			f += l
		filas.append(f)
	if _mundo != null:
		_mundo.queue_free()
	_mundo = MundoFalso.new()
	_mundo._mapa = filas
	root.add_child(_mundo)
	Lanzador3D.configurar(_mundo)
	for y in range(20):
		for x in range(20):
			if filas[y][x] == "#":
				_mundo._bloqueadas[Vector2i(x, y)] = true


func _pos(cx: float, cy: float) -> Vector3:
	# Coordenadas en casillas (con decimales) -> punto del mundo a la altura del suelo.
	return Vector3(cx * MundoFalso.S, MundoFalso.ALTO, cy * MundoFalso.S)


## Un Gatopedro nuevo en la casilla (cx, cy) y un jugador en (jx, jy); sin que el motor llame a su _physics_process.
func _escena(cx: float, cy: float, jx: float, jy: float) -> Array:
	_construir_mapa()
	var j := Jugador3D.new()
	j.position = _pos(jx, jy)
	var modelo := Pj3D.new()
	modelo.position = _pos(cx, cy)
	_mundo.add_child(modelo)
	var g: Gatopedro3D = Gatopedro3D.equipar_gatopedro(modelo, _mundo, j, null)
	g.set_physics_process(false)
	g.altura = 0.65
	return [g, j]


func _avanzar(g: Combate3D, segundos: float) -> void:
	for i in range(int(segundos / DT)):
		if g.muerto:
			return
		g._physics_process(DT)


func _dist(a: Node3D, b: Node3D) -> float:
	return Vector2(a.position.x - b.position.x, a.position.z - b.position.z).length()


func _initialize() -> void:
	await process_frame
	_vida()
	_deteccion()
	_huida()
	_tramos()
	_no_ataca()
	_limites()
	_acorralado()
	_vuelta()
	_goblins_igual()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _vida() -> void:
	var fuego: RuneData = load("res://nucleo/fire_rune.tres")
	var agua: RuneData = load("res://nucleo/water_rune.tres")
	# Una flecha de fuego y se queda mirando cómo arde hasta que se apaga: vivo.
	var e: Array = _escena(5, 5, 15, 15)
	var g: Gatopedro3D = e[0]
	g.golpe(fuego, Vector3.ZERO)
	_ok("1 una flecha de fuego quita 40 (fire_rune.tres)", absf((g.vida_max - g.health) - 40.0) < 0.5, "vida %.1f de %.0f" % [g.health, g.vida_max])
	_avanzar(g, 6.0)
	_ok("1 una flecha + TODA su quemadura no lo mata", not g.muerto and g.health > 0.0, "vida %.1f" % g.health)
	g.golpe(fuego, Vector3.ZERO)
	_ok("1 la segunda flecha de fuego lo tumba", g.muerto and g.health <= 0.0, "vida %.1f" % g.health)
	# Dos flechas seguidas, sin esperar a la quemadura: cae igual.
	e = _escena(5, 5, 15, 15)
	g = e[0]
	g.golpe(fuego, Vector3.ZERO)
	g.golpe(fuego, Vector3.ZERO)
	_ok("1 dos flechas seguidas lo tumban", g.muerto)
	# Sin debilidad ni resistencia: el fuego no se multiplica.
	e = _escena(5, 5, 15, 15)
	g = e[0]
	_ok("1 sin debilidad ni resistencia al fuego", g.multiplicador("fuego") == 1.0 and g.multiplicador("agua") == 1.0 and g.debil == "" and g.resiste == "")
	_ok("1 se llama Gatopedro y maúlla en vez de gritar", g.nombre == "Gatopedro" and g.snd_alerta == "gato_maullido" and g.snd_muere == "gato_maullido")
	# Un hechizo que no mata lo asusta aunque no te vea.
	e = _escena(5, 5, 15, 15)
	g = e[0]
	g.golpe(agua, Vector3.ZERO)
	_ok("1 un hechizo que no lo mata lo hace huir y lo asusta", g.estado == "huye" and g._t_susto > 0.0)
	# La muerte avisa con su nombre (para la misión del tutorial) y suelta oro.
	var avisado: Array = []
	var anotar := func(_p: Vector2, n: String) -> void: avisado.append(n)
	Estado.i().enemigo_muerto.connect(anotar)
	e = _escena(5, 5, 15, 15)
	g = e[0]
	g.golpe(fuego, Vector3.ZERO)
	g.golpe(fuego, Vector3.ZERO)
	_ok("1 al caer emite enemigo_muerto(«Gatopedro»)", avisado == ["Gatopedro"], str(avisado))
	Estado.i().enemigo_muerto.disconnect(anotar)       # Estado es estático: si no, la función sobrevive a la prueba


func _deteccion() -> void:
	var e: Array = _escena(5, 5, 5 + 7.0 / MundoFalso.S, 5)       # a 7 u: fuera de RADIO_DETECCION (5,75)
	var g: Gatopedro3D = e[0]
	_avanzar(g, 1.0)
	_ok("2 a 7 u no te ha visto: sigue paseando", g.estado == "patrulla")
	e = _escena(5, 5, 5 + 4.0 / MundoFalso.S, 5)                  # a 4 u
	g = e[0]
	_avanzar(g, 0.2)
	_ok("2 a 4 u te detecta y huye", g.estado == "huye")
	# Detrás del muro (x=10): a menos de 5,75 u pero sin línea de visión
	e = _escena(9.4, 5, 10.9, 5)
	g = e[0]
	_avanzar(g, 0.5)
	_ok("2 con un muro por medio no te ve", g.estado == "patrulla", g.estado)


func _huida() -> void:
	var e: Array = _escena(5, 5, 5 - 3.0 / MundoFalso.S, 5)       # jugador a 3 u por la izquierda
	var g: Gatopedro3D = e[0]
	var j: Jugador3D = e[1]
	var d0: float = _dist(g, j)
	_avanzar(g, 1.0)
	var d1: float = _dist(g, j)
	_ok("3 se aleja de ti al detectarte", d1 > d0 + 1.0, "%.2f -> %.2f u" % [d0, d1])
	_ok("3 corre (clip run) y más que andas (1,6) y menos que corres (3,0)",
			g.moviendo == 2 and Gatopedro3D.VEL_HUIDA > 1.6 and Gatopedro3D.VEL_HUIDA < 3.0)
	# Velocidad medida: 1 s corriendo en línea recta
	var e2: Array = _escena(5, 5, 5 - 3.0 / MundoFalso.S, 5)
	var g2: Gatopedro3D = e2[0]
	_avanzar(g2, 0.1)
	var p0: Vector3 = g2.position
	_avanzar(g2, 1.0)
	var v: float = Vector2(g2.position.x - p0.x, g2.position.z - p0.z).length()
	_ok("3 la velocidad medida es la de VEL_HUIDA", absf(v - Gatopedro3D.VEL_HUIDA) < 0.4, "%.2f u/s (esperado %.2f)" % [v, Gatopedro3D.VEL_HUIDA])


func _tramos() -> void:
	# Jugador lejos (6 u) y quieto: debe pararse a ratos. Mide la fracción de tiempo quieto.
	var e: Array = _escena(8, 5, 8 - 5.5 / MundoFalso.S, 5)
	var g: Gatopedro3D = e[0]
	var j: Jugador3D = e[1]
	var parado: float = 0.0
	var total: float = 0.0
	var paradas: int = 0
	var prev: bool = false
	var racha: float = 0.0
	var mejor_racha: float = 0.0
	for i in range(int(9.0 / DT)):
		# el jugador se queda a ~5,5 u: lo justo para que el gato lo vea y no esté en la zona cercana
		var d: Vector3 = g.position - j.position
		d.y = 0.0
		if d.length() > 5.0:
			j.position += d.normalized() * 2.0 * DT
		g._physics_process(DT)
		total += DT
		if g._parado:
			parado += DT
			if not prev:
				paradas += 1
		racha = racha + DT if g._parado else 0.0
		mejor_racha = maxf(mejor_racha, racha)
		prev = g._parado
		if g.estado != "huye":
			break
	_ok("4 con el jugador lejos hace pausas de tiro", paradas >= 2, "%d pausas en %.1f s" % [paradas, total])
	_ok("4 cada pausa dura lo bastante para apuntar y disparar (>= 0,6 s seguidos)", mejor_racha >= 0.6, "la más larga: %.2f s" % mejor_racha)
	var frac: float = parado / maxf(total, 0.01)
	var esperada: float = Gatopedro3D.TRAMO_PARADA / (Gatopedro3D.TRAMO_PARADA + Gatopedro3D.TRAMO_CARRERA)
	_ok("4 y está quieto ~%d %% del tiempo (el diseño dice %d %%)" % [int(frac * 100), int(esperada * 100)], absf(frac - esperada) < 0.12)
	# Jugador pegado a él (2 u) persiguiéndolo: nunca se para.
	e = _escena(8, 5, 8 - 2.0 / MundoFalso.S, 5)
	g = e[0]
	j = e[1]
	var se_paro: bool = false
	for i in range(int(6.0 / DT)):
		var d2: Vector3 = g.position - j.position
		d2.y = 0.0
		if d2.length() > 2.0:
			j.position += d2.normalized() * 3.0 * DT
		g._physics_process(DT)
		if g._parado:
			se_paro = true
	_ok("4 con el jugador encima (2 u) no se para nunca", not se_paro)


func _no_ataca() -> void:
	var e: Array = _escena(8, 5, 8.3, 5)          # jugador pegado
	var g: Gatopedro3D = e[0]
	var j: Jugador3D = e[1]
	var v0: float = j.vida
	_avanzar(g, 5.0)
	_ok("5 no ataca: la vida del jugador no cambia aunque lo tenga encima", j.vida == v0 and g._golpe_pendiente == false and g._ataque == 0.0)


func _limites() -> void:
	# Persecución larga en una sala con un muro: nunca pisa una casilla bloqueada ni se va muy lejos de casa.
	var e: Array = _escena(5, 5, 3, 5)
	var g: Gatopedro3D = e[0]
	var j: Jugador3D = e[1]
	var en_muro: int = 0
	var max_casa: float = 0.0
	for i in range(int(40.0 / DT)):
		var d: Vector3 = g.position - j.position
		d.y = 0.0
		# el jugador va siempre hacia el gato a 3 u/s (lo más agresivo)
		if d.length() > 1.0:
			j.position += -d.normalized() * 3.0 * DT
		g._physics_process(DT)
		var c: Vector2i = Terreno3D.celda_de(g.position)
		if not Terreno3D.en_mapa(c) or _mundo._bloqueadas.has(c):
			en_muro += 1
		max_casa = maxf(max_casa, _dist(g, _casa_nodo(g)))
	_ok("6 en 40 s de persecución no pisa nunca un muro ni sale del mapa", en_muro == 0, "%d fotogramas dentro" % en_muro)
	_ok("6 no se va del tutorial: nunca a más de RADIO_CASA + 4 u de su sitio", max_casa < Gatopedro3D.RADIO_CASA + 4.0, "máx %.1f u" % max_casa)


func _casa_nodo(g: Combate3D) -> Node3D:
	var n := Node3D.new()
	n.position = g.casa
	return n


func _acorralado() -> void:
	# En el fondo del callejón (casillas x 2..5, y 16..17) con el jugador en la boca: no hay a dónde ir.
	var e: Array = _escena(5.5, 16.5, 1.5, 16.5)
	var g: Gatopedro3D = e[0]
	var j: Jugador3D = e[1]
	_avanzar(g, 0.3)
	for i in range(int(4.0 / DT)):
		j.position.x += 0.6 * DT       # el jugador entra despacio
		g._physics_process(DT)
	var c: Vector2i = Terreno3D.celda_de(g.position)
	_ok("7 acorralado no atraviesa el muro ni revienta", not _mundo._bloqueadas.has(c) and Terreno3D.en_mapa(c) and not g.muerto, str(c))


func _vuelta() -> void:
	var e: Array = _escena(5, 5, 5 - 3.0 / MundoFalso.S, 5)
	var g: Gatopedro3D = e[0]
	var j: Jugador3D = e[1]
	_avanzar(g, 1.0)
	_ok("8 primero huye", g.estado == "huye")
	j.position = _pos(17, 17)                   # el jugador se va lejos
	_avanzar(g, 6.0)
	_ok("8 sin verte se calma y vuelve a casa", g.estado == "vuelve" or g.estado == "patrulla", g.estado)
	_avanzar(g, 20.0)
	_ok("8 acaba paseando junto a su sitio", g.estado == "patrulla" and _dist(g, _casa_nodo(g)) < Gatopedro3D.DISTANCIA_PATRULLA + 0.5, "%s a %.1f u" % [g.estado, _dist(g, _casa_nodo(g))])


func _goblins_igual() -> void:
	var c := Combate3D.new()
	_ok("9 los goblins siguen con sus sonidos y su rombo de siempre", c.snd_alerta == "goblin_grito" and c.snd_muere == "goblin_muere" and c.debil == "agua" and c.resiste == "fuego" and c.vida_max == 100.0)
	c.free()
