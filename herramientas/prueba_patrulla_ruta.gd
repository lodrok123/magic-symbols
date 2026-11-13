extends SceneTree
## Tarea 19 (13/11, Juego): LA PATRULLA DEL GOBLIN Y EL GATOPEDRO RODEAN POR RUTA lo que les corta el camino recto. Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_patrulla_ruta.gd
## Lo que comprueba:
##   1. Camino libre: la patrulla del goblin y el paseo del gatopedro siguen EXACTAMENTE la misma trayectoria con la ruta activada que con ella apagada (`PATRULLA_POR_RUTA = false`,
##      que es el comportamiento de antes): mismas velocidades, mismos giros, fotograma a fotograma.
##   2. Un obstáculo entre el goblin y su punto de patrulla (una casilla bloqueada en la línea recta): lo rodea y llega al otro lado; sin la ruta (control) se queda de este lado.
##   3. Lo mismo con el paseo del gatopedro.
##   4. El gatopedro de vuelta a casa (estado «vuelve») con un muro de por medio: lo rodea y llega a casa; sin la ruta (control) se rinde en el muro.
##   5. Nada de esto pone al goblin ni al gato dentro de una casilla bloqueada, y la ruta se pide «con moderación» (no una por fotograma).
## Nota de diseño: DISTANCIA_PATRULLA (2 u) es menor que una casilla (2,3 u), así que con la casa en su sitio no cabe obstáculo ENTRE los dos puntos de patrulla; el caso de la prueba es el de
## quien arranca desde el otro extremo de un tramo (casa desplazada de su casilla), que es el que la ruta resuelve.

const DT: float = 1.0 / 60.0
const S: float = 2.3
const LADO: int = 14

var _mundo: Mundo3D = null
var _jugador: Jugador3D = null
var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_montar()
	_libre()
	_obstaculo_goblin()
	_obstaculo_gato()
	_vuelve_gato()
	Combate3D.PATRULLA_POR_RUTA = true
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Terreno vacío de LADO x LADO con borde de piedra, un Mundo3D nuevo y un jugador lejos (arriba a la derecha) que no ve a nadie.
func _montar() -> void:
	if _mundo != null:
		_mundo.free()
	if _jugador != null:
		_jugador.free()
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			if x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1:
				f += "#"
				bloq[Vector2i(x, y)] = true
			else:
				f += "."
		filas.append(f)
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.estados = EstadosSuelo3D.new()
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	_mundo = Mundo3D.new()
	root.add_child(_mundo)
	_jugador = Jugador3D.new()
	_jugador.pj = Pj3D.new()
	_mundo.add_child(_jugador.pj)
	_jugador.position = Terreno3D.centro_de(Vector2i(LADO - 2, LADO - 2))


func _suelo(c: Vector2i) -> Vector3:
	return Terreno3D.centro_de(c, Terreno3D.y_pies(c))


func _goblin(p: Vector3) -> Combate3D:
	var modelo := Pj3D.new()
	modelo.id = "goblin_warrior"
	modelo.position = p
	_mundo.add_child(modelo)
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, _jugador, null)
	g.set_physics_process(false)
	g.position = p
	g.casa = p
	return g


func _gato(p: Vector3) -> Gatopedro3D:
	var modelo := Pj3D.new()
	modelo.id = "lince"
	modelo.position = p
	_mundo.add_child(modelo)
	var g: Gatopedro3D = Gatopedro3D.equipar_gatopedro(modelo, _mundo, _jugador, null)
	g.set_physics_process(false)
	g.position = p
	g.casa = p
	return g


func _quitar(g: Combate3D) -> void:
	if is_instance_valid(g):
		if is_instance_valid(g.pj):
			g.pj.free()
		g.free()


## Avanza `segundos` y devuelve la trayectoria (una posición por fotograma).
func _correr(g: Combate3D, segundos: float) -> Array[Vector3]:
	var t: Array[Vector3] = []
	for i in range(int(segundos / DT)):
		g.vista_perdida = 0.0
		g._physics_process(DT)
		g._ajustar_al_suelo(DT)
		t.append(g.position)
	return t


func _igual(a: Array[Vector3], b: Array[Vector3]) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if not a[i].is_equal_approx(b[i]):
			return false
	return true


## ¿Pasó la trayectoria por la casilla `c`?
func _pisa(t: Array[Vector3], c: Vector2i) -> bool:
	for p in t:
		if Terreno3D.celda_de(p) == c:
			return true
	return false


func _max_x(t: Array[Vector3]) -> float:
	var m: float = -INF
	for p in t:
		m = maxf(m, p.x)
	return m


# ---------------------------------------------------------------------------------------------------------------------
#  1. Camino libre: nada cambia
# ---------------------------------------------------------------------------------------------------------------------
func _libre() -> void:
	var inicio: Vector3 = _suelo(Vector2i(6, 6))
	Combate3D.PATRULLA_POR_RUTA = false
	var g0: Combate3D = _goblin(inicio)
	var antes: Array[Vector3] = _correr(g0, 30.0)
	_quitar(g0)
	Combate3D.PATRULLA_POR_RUTA = true
	var g1: Combate3D = _goblin(inicio)
	var despues: Array[Vector3] = _correr(g1, 30.0)
	_ok("1 goblin: con el camino libre patrulla igual que antes (misma trayectoria fotograma a fotograma)", _igual(antes, despues), "%d fotogramas" % despues.size())
	_ok("1 goblin: ... y de verdad patrulla (se movió y dio la vuelta)", _max_x(despues) - inicio.x > 0.5 and despues[despues.size() - 1].distance_to(inicio) < 3.0)
	_ok("1 goblin: ... sin pedir ninguna ruta", g1.rutas_calculadas == 0, "%d" % g1.rutas_calculadas)
	_quitar(g1)
	Combate3D.PATRULLA_POR_RUTA = false
	var k0: Gatopedro3D = _gato(inicio)
	var gato_antes: Array[Vector3] = _correr(k0, 60.0)
	_quitar(k0)
	Combate3D.PATRULLA_POR_RUTA = true
	var k1: Gatopedro3D = _gato(inicio)
	var gato_despues: Array[Vector3] = _correr(k1, 60.0)
	_ok("1 gatopedro: con el camino libre pasea igual que antes (misma trayectoria fotograma a fotograma)", _igual(gato_antes, gato_despues), "%d fotogramas" % gato_despues.size())
	_ok("1 gatopedro: ... y de verdad pasea", _max_x(gato_despues) - inicio.x > 0.3)
	_ok("1 gatopedro: ... sin pedir ninguna ruta", k1.rutas_calculadas == 0, "%d" % k1.rutas_calculadas)
	_quitar(k1)


# ---------------------------------------------------------------------------------------------------------------------
#  2. y 3. Obstáculo en la línea recta hasta el punto de patrulla
# ---------------------------------------------------------------------------------------------------------------------
## Escena: el bicho en la casilla (4,4) algo a la derecha de su centro, mirando a +X; su casa en (5,3) (centro en X + 1,9 u, así que está dentro de su tramo y camina hacia +X), y el
## punto de patrulla de ese lado, casa.x + 2, en la casilla (6,*). La casilla (5,4) está bloqueada: corta la recta de (4,4) a ese punto, pero el punto y la casa están libres.
func _montar_obstaculo(g: Combate3D) -> void:
	var c: Vector2i = Vector2i(4, 4)
	g.position = _suelo(c) + Vector3(0.55, 0.0, 0.0)
	var casa: Vector3 = _suelo(Vector2i(5, 3))
	casa.x = g.position.x + 1.2
	g.casa = casa
	g._direccion = 1.0


func _obstaculo_goblin() -> void:
	for ruteo in [false, true]:
		_montar()
		Terreno3D.bloquear_celda(Vector2i(5, 4))
		Combate3D.PATRULLA_POR_RUTA = ruteo
		var g: Combate3D = _goblin(_suelo(Vector2i(4, 4)))
		_montar_obstaculo(g)
		if ruteo:
			_ok("2 goblin: el obstáculo corta de verdad la recta al punto de patrulla", not Caminos3D.recta_andable(g.position, Vector3(g.casa.x + 2.0, g.position.y, g.position.z)))
		var t: Array[Vector3] = _correr(g, 40.0)
		var meta_x: float = (5 + 1) * S + 0.05                 # pasado el borde derecho de la casilla bloqueada (5,*) (empieza en 6·S)
		if ruteo:
			_ok("2 goblin: con la ruta rodea el obstáculo y llega a su otro lado", _max_x(t) >= meta_x, "x máx %.2f (hace falta %.2f)" % [_max_x(t), meta_x])
			_ok("2 goblin: ... sin pisar la casilla bloqueada", not _pisa(t, Vector2i(5, 4)))
			_ok("2 goblin: ... pidiendo la ruta con moderación (< 1 por fotograma de 20)", g.rutas_calculadas > 0 and g.rutas_calculadas <= t.size() / 20, "%d en %d fotogramas" % [g.rutas_calculadas, t.size()])
		else:
			_ok("2 goblin (control, sin ruta): se queda de este lado, como antes", _max_x(t) < meta_x and not _pisa(t, Vector2i(5, 4)), "x máx %.2f" % _max_x(t))
		_quitar(g)
	Combate3D.PATRULLA_POR_RUTA = true


func _obstaculo_gato() -> void:
	for ruteo in [false, true]:
		_montar()
		Terreno3D.bloquear_celda(Vector2i(5, 4))
		Combate3D.PATRULLA_POR_RUTA = ruteo
		var g: Gatopedro3D = _gato(_suelo(Vector2i(4, 4)))
		_montar_obstaculo(g)
		var t: Array[Vector3] = _correr(g, 90.0)
		var meta_x: float = (5 + 1) * S + 0.05
		if ruteo:
			_ok("3 gatopedro: con la ruta rodea el obstáculo en su paseo y llega a su otro lado", _max_x(t) >= meta_x, "x máx %.2f (hace falta %.2f)" % [_max_x(t), meta_x])
			_ok("3 gatopedro: ... sin pisar la casilla bloqueada", not _pisa(t, Vector2i(5, 4)))
		else:
			_ok("3 gatopedro (control, sin ruta): se queda de este lado, como antes", _max_x(t) < meta_x and not _pisa(t, Vector2i(5, 4)), "x máx %.2f" % _max_x(t))
		_quitar(g)
	Combate3D.PATRULLA_POR_RUTA = true


# ---------------------------------------------------------------------------------------------------------------------
#  4. Vuelta a casa con un muro de por medio
# ---------------------------------------------------------------------------------------------------------------------
func _vuelve_gato() -> void:
	for ruteo in [false, true]:
		_montar()
		var muro: Array[Vector2i] = []
		for y in range(3, 10):
			muro.append(Vector2i(6, y))
			Terreno3D.bloquear_celda(Vector2i(6, y))
		Combate3D.PATRULLA_POR_RUTA = ruteo
		var casa: Vector3 = _suelo(Vector2i(10, 6))
		var g: Gatopedro3D = _gato(_suelo(Vector2i(2, 6)))
		g.casa = casa
		g.estado = "vuelve"
		g.objetivo = null
		var llego: bool = false
		var entro_en_muro: bool = false
		for i in range(int(90.0 / DT)):
			g.vista_perdida = 0.0
			g._physics_process(DT)
			if muro.has(Terreno3D.celda_de(g.position)):
				entro_en_muro = true
			if Vector2(g.position.x - casa.x, g.position.z - casa.z).length() < 0.6:
				llego = true
				break
		if ruteo:
			_ok("4 gatopedro: de vuelta a casa rodea el muro y llega", llego, "a %.2f u de casa" % Vector2(g.position.x - casa.x, g.position.z - casa.z).length())
			_ok("4 gatopedro: ... sin pisar el muro", not entro_en_muro)
		else:
			_ok("4 gatopedro (control, sin ruta): se rinde en el muro y no llega, como antes", not llego and not entro_en_muro)
		_quitar(g)
	Combate3D.PATRULLA_POR_RUTA = true
