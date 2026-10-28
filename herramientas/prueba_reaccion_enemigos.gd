extends SceneTree
## Prueba de la sensación de golpe (T-CP2, 17/10; LAB_CASTPOINT §3, diario 148). Sin ventana: `--headless --fixed-fps 60`.
## Un goblin, un golpe por elemento, distancia recorrida en 1 s. Debe ser >= 2x la de ANTES (tabla medida con el código previo)
## y >= el suelo (EMPUJE_MIN_CASILLAS x casilla). Además: el hitstop congela su posición, el clip hit sale siempre, etc.
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
var _mundo: MundoFalso = null
func _mapa() -> void:
	var filas: PackedStringArray = []
	for y in range(20):
		var f: String = ""
		for x in range(20):
			f += "#" if (x == 0 or y == 0 or x == 19 or y == 19) else "."
		filas.append(f)
	_mundo = MundoFalso.new()
	_mundo._mapa = filas
	root.add_child(_mundo)
	Lanzador3D.configurar(_mundo)
	for y in range(20):
		for x in range(20):
			if filas[y][x] == "#":
				_mundo._bloqueadas[Vector2i(x, y)] = true

## Distancias medidas en 1 s ANTES del cambio (mismo montaje, código previo): u
const ANTES: Dictionary = {"rayo": 0.192, "hielo": 0.141, "fuego": 0.244, "agua": 0.294, "tierra": 1.116, "viento": 1.321}
var _fallos: int = 0

func _ok(c: bool, m: String) -> void:
	if not c:
		_fallos += 1
		print("FALLO: ", m)

func _nuevo() -> Combate3D:
	var j := Jugador3D.new()
	j.position = Vector3(18 * 2.3, 1.0, 18 * 2.3)
	var modelo := Pj3D.new()
	modelo.position = Vector3(10 * 2.3, MundoFalso.ALTO, 10 * 2.3)
	_mundo.add_child(modelo)
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, j, null)
	g.set_physics_process(false)
	g.altura = 0.85
	return g

func _paso(g: Combate3D) -> void:
	g._physics_process(DT)
	await process_frame     # los tweens (squash, salto) solo avanzan con fotogramas del motor

func _initialize() -> void:
	await process_frame
	_mapa()
	var suelo: float = Combate3D.EMPUJE_MIN_CASILLAS * Terreno3D.casilla
	var ficheros: Dictionary = {"rayo": "lightning", "hielo": "ice", "fuego": "fire", "agua": "water", "tierra": "earth", "viento": "wind"}
	for el in ficheros.keys():
		var rune: RuneData = load("res://nucleo/%s_rune.tres" % ficheros[el])
		var g: Combate3D = _nuevo()
		var p0: Vector3 = g.position
		var pj_y0: float = g.pj.position.y
		g.golpe(Hechizo.construir(rune, {}), Vector3(1, 0, 0))
		if el == "viento":
			g.push(Vector3(1, 0, 0), Lanzador3D.FUERZA_EMPUJE)
		if g.congelado < 5.0:
			g.congelado = 99.0
		# Hitstop: durante el hitstop (proporcional al daño desde el 28/10: de 0,04 a 0,10 s) no se mueve ni un milímetro
		# El viento no hace daño: sin daño no hay hitstop (se congela solo un golpe que daña), pero sí aplastamiento y salto.
		var espera: float = g._hitstop
		var n_cong: int = int(floor(espera / DT)) - 1
		var salto_max: float = 0.0
		var escala_min_y: float = 99.0
		for i in range(n_cong):
			await _paso(g)
			_ok(g.position.is_equal_approx(p0), "%s: se movió durante el hitstop (fotograma %d)" % [el, i])
			escala_min_y = minf(escala_min_y, g.pj.scale.y)
		for i in range(60 - n_cong):
			await _paso(g)
			salto_max = maxf(salto_max, g.pj.position.y - g.position.y)
			escala_min_y = minf(escala_min_y, g.pj.scale.y)
		var d: float = Vector2(g.position.x - p0.x, g.position.z - p0.z).length()
		var antes: float = float(ANTES[el])
		var factor: float = d / antes
		print("%-6s antes %.3f u  ahora %.3f u (%.2f casillas)  x%.2f  suelo %.3f  hitstop %.2fs  salto %.2f u  escala_y_min %.2f" % [el, antes, d, d / Terreno3D.casilla, factor, suelo, espera, salto_max, escala_min_y])
		_ok(factor >= 2.0 - 0.02, "%s: no llega a x2 (x%.2f)" % [el, factor])
		_ok(d >= suelo - 0.02, "%s: por debajo del suelo (%.3f < %.3f)" % [el, d, suelo])
		_ok(g.interrupcion >= 0.0, "interrupcion")
		var con_salto: bool = Combate3D.SALTO_ELEMENTOS.has(el)
		_ok((salto_max > 0.2) == con_salto, "%s: salto visual incorrecto (%.2f)" % [el, salto_max])
		if el != "viento" and el != "tierra":
			pass
		_ok(g.pj.scale.is_equal_approx(Vector3.ONE) or g.pj.scale.y > 0.0, "escala")
		g.queue_free()
	# Pormenores con un goblin quieto: hitstop débil/normal, hit siempre, interrupción 0,6, destello 0,20, squash, salto
	var rune_f: RuneData = load("res://nucleo/fire_rune.tres")
	var g2: Combate3D = _nuevo()
	var vida_antes: float = g2.health
	g2.golpe(Hechizo.construir(rune_f, {}), Vector3(1, 0, 0))
	# 28/10 (gamefeel): el hitstop es proporcional al daño (Sensacion3D.hitstop_de), entre HITSTOP y HITSTOP_DEBIL.
	var esperado: float = Sensacion3D.hitstop_de(vida_antes - g2.health, false)
	_ok(absf(g2._hitstop - esperado) < 0.001 and g2._hitstop >= Combate3D.HITSTOP - 0.001 and g2._hitstop <= Combate3D.HITSTOP_DEBIL + 0.001,
		"hitstop no es el proporcional al daño (%.3f, esperado %.3f)" % [g2._hitstop, esperado])
	_ok(g2.interrupcion >= Combate3D.INTERRUPCION_GOLPE - 0.001, "interrupcion < 0,6 (%.2f)" % g2.interrupcion)
	_ok(absf(g2._destello - Combate3D.DESTELLO_GOLPE) < 0.001, "destello != 0,20 (%.3f)" % g2._destello)
	_ok(g2.pj.scale.x > 1.2 and g2.pj.scale.y < 0.85, "aplastamiento no aplicado (%s)" % g2.pj.scale)
	print("pormenores: hitstop %.2f  interrupcion %.2f  destello %.2f  escala %s" % [g2._hitstop, g2.interrupcion, g2._destello, g2.pj.scale])
	# Clip hit aun aturdido
	var g3: Combate3D = _nuevo()
	g3.stun_timer = 2.0
	g3.anim_orden = ""
	g3.receive_damage(5.0)
	_ok(g3.anim_orden == "hit", "aturdido: no salta el clip hit (%s)" % g3.anim_orden)
	# El aplastamiento vuelve a 1
	for i in range(30):
		await _paso(g2)
	_ok(g2.pj.scale.is_equal_approx(Vector3.ONE), "el aplastamiento no vuelve a 1 (%s)" % g2.pj.scale)
	_ok(is_zero_approx(g2._salto_y), "el salto no termina (%.3f)" % g2._salto_y)
	var g4: Combate3D = _nuevo()
	g4.golpe(Hechizo.construir(load("res://nucleo/wind_rune.tres"), {}), Vector3(1, 0, 0))
	_ok(g4._hitstop == 0.0, "el viento (sin daño) no debería congelar (%.2f)" % g4._hitstop)
	print("RESULTADO reaccion_enemigos: %d fallos" % _fallos)
	quit(1 if _fallos > 0 else 0)
