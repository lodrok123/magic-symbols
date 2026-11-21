extends SceneTree
## Prueba de que el MURO DE AGUA MOJA HACIA DELANTE (21/11, Pablo: «el muro de agua moja hacia delante, coherente con la rotura»).
##   godot --headless --path . --script res://herramientas/prueba_muro_agua_delante.gd
## Lanza agua + barrera + ᛁ (un muro) hacia +X y hacia +Z y comprueba: las casillas donde cae el agua (el charco de cruce que registra HechizoVivo) están por delante de las del muro y ninguna
## detrás; nunca son MÁS que las del muro (tope de legibilidad); el agua que entra en la simulación sale de ellas y el centro de lo mojado queda por delante del muro; con otra cosa delante
## (pared) el agua se queda en la casilla del muro y no revienta; una barrera SIN ᛁ (no es muro) y una bola no cambian.

class MundoFalso extends Node3D:
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _al_impactar(_elemento: String, _punto: Vector3) -> void:
		pass

const LADO: int = 20
var _fallos: int = 0
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _jug: Jugador3D = null
var _volumenes: Array = []


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	await _caso(Vector2i(5, 10), Vector3.RIGHT, {"barrera": 1, "linea_x": 4}, "+X, ᛁ×4")
	await _caso(Vector2i(10, 5), Vector3(0, 0, 1), {"barrera": 1, "linea_x": 4}, "+Z, ᛁ×4")
	await _caso(Vector2i(5, 10), Vector3.RIGHT, {"barrera": 1, "linea_x": 2}, "+X, ᛁ×2")
	await _contra_pared()
	await _no_muro()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar() -> void:
	for n in [_l, _m, _jug]:
		if n != null and is_instance_valid(n):
			n.free()
	Terreno3D.alturas.clear()
	Terreno3D.conductores.clear()
	var filas: PackedStringArray = []
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			f += "#" if (x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1) else "."
		filas.append(f)
	_m = MundoFalso.new()
	_m._mapa = filas
	root.add_child(_m)
	Lanzador3D.configurar(_m)
	for y in range(LADO):
		for x in range(LADO):
			if filas[y][x] == "#":
				_m._bloqueadas[Vector2i(x, y)] = true
	_jug = Jugador3D.new()
	root.add_child(_jug)
	_jug.position = Lanzador3D.centro_de(Vector2i(2, 2), 1.0)
	_l = Lanzador3D.new()
	_l.mundo = _m
	_l.jugador = _jug
	root.add_child(_l)
	_volumenes.clear()
	_l.hechizo_v2.connect(func(estado: String, el: String, vol: Dictionary, _o: Vector3, _d: Vector3, _p: Dictionary) -> void: _volumenes.append([estado, el, vol]))


func _lanzar(c: Vector2i, dir: Vector3, glifos: Dictionary, el: String = "agua") -> Hechizo:
	var rune: RuneData = load("res://nucleo/%s_rune.tres" % ("water" if el == "agua" else "fire")) as RuneData
	var h: Hechizo = Hechizo.construir(rune, glifos)
	_l.lanzar_hechizo(h, Lanzador3D.centro_de(c, 0.8), dir)
	return h


## Las casillas del último charco de cruce (donde cae el agua) y las del volumen (las del muro).
func _destino() -> Array:
	var z: Lanzador3D.ZonaV2 = _l.zonas_cruce.back() if not _l.zonas_cruce.is_empty() else null
	return z.celdas.keys() if z != null else []


func _del_muro() -> Array:
	return (_volumenes[0][2] as Dictionary).get("celdas", []) if not _volumenes.is_empty() else []


func _adelante(c: Vector2i, dir: Vector3) -> float:
	var p: Vector3 = Terreno3D.centro_de(c)
	return Vector2(p.x, p.z).dot(Vector2(dir.x, dir.z).normalized()) / Terreno3D.casilla


func _media(cs: Array, dir: Vector3) -> float:
	var s: float = 0.0
	for c in cs:
		s += _adelante(c as Vector2i, dir)
	return s / float(maxi(cs.size(), 1))


func _caso(origen: Vector2i, dir: Vector3, glifos: Dictionary, nombre: String) -> void:
	_montar()
	await process_frame
	var h: Hechizo = _lanzar(origen, dir, glifos)
	var muro: Array = _del_muro()
	var dest: Array = _destino()
	_ok("1 [%s] es un muro (barrera + ᛁ) de %d casilla/s y el agua cae en %d" % [nombre, muro.size(), dest.size()], Lanzador3D.GeometriaV2.es_muro(h.geo()) and muro.size() >= 1 and dest.size() >= 1)
	var atras: float = INF
	for c in muro:
		atras = minf(atras, _adelante(c as Vector2i, dir))
	var por_detras: int = 0
	for c in dest:
		if _adelante(c as Vector2i, dir) < atras - 0.01:
			por_detras += 1
	_ok("1 [%s] ninguna casilla de agua queda detrás del muro (%d) y su centro avanza %.2f casillas (%.2f → %.2f)" % [nombre, por_detras, _media(dest, dir) - _media(muro, dir), _media(muro, dir), _media(dest, dir)],
		por_detras == 0 and _media(dest, dir) >= _media(muro, dir) + float(HechizoVivo.MURO_AGUA_ADELANTO_CAS) - 0.01)
	_ok("1 [%s] tope: nunca más casillas de agua (%d) que las del muro (%d), y todas dentro del mapa y libres" % [nombre, dest.size(), muro.size()], dest.size() <= muro.size() and dest.all(func(c: Vector2i) -> bool: return Lanzador3D.en_mapa(c) and not Lanzador3D.bloqueada(c)))
	# lo mojado de verdad (simulación) tras dejar caer el agua
	await create_timer(3.5).timeout
	var sim: AguaSim3D = Terreno3D.agua_sim
	var mojadas: Array = []
	for y in range(1, LADO - 1):
		for x in range(1, LADO - 1):
			if sim.casilla_mojada(Vector2i(x, y)):
				mojadas.append(Vector2i(x, y))
	var detras_sim: int = 0
	for c in mojadas:
		if _adelante(c as Vector2i, dir) < atras - 0.01:
			detras_sim += 1
	_ok("1 [%s] la simulación moja %d casillas (%d por detrás del muro: el agua fluye sola) y su centro (%.2f) queda por delante del muro (%.2f)" % [nombre, mojadas.size(), detras_sim, _media(mojadas, dir), _media(muro, dir)],mojadas.size() >= 1 and _media(mojadas, dir) > _media(muro, dir) + 0.3)


func _contra_pared() -> void:
	_montar()
	await process_frame
	# pared pegada por delante de TODO el muro: no hay sitio delante, el agua se queda en las casillas del muro
	for y in range(8, 13):
		_m._bloqueadas[Vector2i(7, y)] = true
	_lanzar(Vector2i(5, 10), Vector3.RIGHT, {"barrera": 1, "linea_x": 4})
	var muro: Array = _del_muro()
	var dest: Array = _destino()
	var en_muro: bool = dest.all(func(c: Vector2i) -> bool: return muro.has(c) or not Lanzador3D.bloqueada(c))
	_ok("2 con una pared pegada delante, el agua no cae en la pared (%d casillas, muro %d) y no revienta" % [dest.size(), muro.size()], not dest.is_empty() and en_muro and dest.size() <= muro.size())


func _no_muro() -> void:
	# una barrera sin ᛁ no es muro: su agua sigue en su casilla (sin desplazar)
	_montar()
	await process_frame
	var h: Hechizo = _lanzar(Vector2i(5, 10), Vector3.RIGHT, {"barrera": 1})
	var muro: Array = _del_muro()
	var dest: Array = _destino()
	_ok("3 una barrera sin ᛁ (no es muro) no desplaza el agua: cae en las casillas del volumen %s → %s" % [str(muro), str(dest)], not Lanzador3D.GeometriaV2.es_muro(h.geo()) and dest.size() == muro.size() and dest.all(func(c: Vector2i) -> bool: return muro.has(c)))
	# una bola de agua (sin barrera) tampoco
	_montar()
	await process_frame
	_lanzar(Vector2i(5, 10), Vector3.RIGHT, {})
	var muro_b: Array = _del_muro()
	var dest_b: Array = _destino()
	_ok("3 una bola de agua cae donde siempre %s → %s" % [str(muro_b), str(dest_b)], dest_b.size() == muro_b.size() and dest_b.all(func(c: Vector2i) -> bool: return muro_b.has(c)))
