extends SceneTree
## Prueba del CORTE DEL HAZ EN EL PRIMER ENEMIGO (21/11, Pablo: «el haz no se corta en los enemigos, solo en los muros; el de fuego los atraviesa y golpea a todos los de la fila»).
##   godot --headless --path . --script res://herramientas/prueba_haz_corte_enemigos.gd
## Con tres enemigos en fila (Combate3D de verdad, quietos) comprueba, para cada elemento:
##   · AGUA, TIERRA y RAYO: solo el primero recibe el golpe; el dibujo (`volumen["haz"]`) acaba en su cara, con un choque «muro» marcado `corte`; las casillas del haz no pasan de él;
##   · FUEGO y VIENTO (`HechizoVivo.HAZ_ATRAVIESA_ENEMIGOS`): el haz sigue, el fuego hiere a los tres y el dibujo llega más allá del último;
##   · un MURO delante de todos: nadie detrás del muro (agua ni fuego); un muro entre el primer enemigo y los demás: el de delante recibe y los de detrás no, con los dos reglas;
##   · un primer enemigo MUERTO no cuenta: el corte pasa al siguiente vivo; un enemigo en otra fila (de lado) no corta;
##   · con el enemigo pegado a la mano el haz no desaparece (HAZ_CORTE_MIN_U).

class MundoFalso extends Node3D:
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _al_impactar(_elemento: String, _punto: Vector3) -> void:
		pass

class JugadorFalso extends Jugador3D:
	pass

const LADO: int = 20
const SALIDA: Vector2i = Vector2i(3, 8)
const ELEMENTOS: Dictionary = {"fuego": "fire", "agua": "water", "tierra": "earth", "viento": "wind", "rayo": "lightning"}

var _fallos: int = 0
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _jug: JugadorFalso = null
var _volumenes: Array = []
var _runas: Dictionary = {}


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, false)
	await process_frame
	for e in ELEMENTOS:
		_runas[e] = load("res://nucleo/%s_rune.tres" % ELEMENTOS[e]) as RuneData
	_ok("0 la regla: fuego, viento y magma atraviesan; agua, tierra y rayo no", HechizoVivo.HAZ_CORTA_EN_ENEMIGO and HechizoVivo.HAZ_ATRAVIESA_ENEMIGOS.has("fuego") and HechizoVivo.HAZ_ATRAVIESA_ENEMIGOS.has("viento")
		and HechizoVivo.HAZ_ATRAVIESA_ENEMIGOS.has("magma") and not HechizoVivo.HAZ_ATRAVIESA_ENEMIGOS.has("agua") and not HechizoVivo.HAZ_ATRAVIESA_ENEMIGOS.has("tierra") and not HechizoVivo.HAZ_ATRAVIESA_ENEMIGOS.has("rayo"))
	_fila()
	_con_muro()
	_muerto_y_lado()
	_pegado()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar() -> void:
	for n in [_l, _m, _jug]:
		if n != null and is_instance_valid(n):
			n.free()
	Terreno3D.alturas.clear()
	Terreno3D.conductores.clear()
	Terreno3D.plataformas_tierra.clear()
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
	_jug = JugadorFalso.new()
	root.add_child(_jug)
	_jug.position = Lanzador3D.centro_de(Vector2i(2, 2), Terreno3D.y_pies(Vector2i(2, 2)))
	_l = Lanzador3D.new()
	_l.mundo = _m
	_l.jugador = _jug
	root.add_child(_l)
	_volumenes.clear()
	_l.hechizo_v2.connect(func(estado: String, el: String, vol: Dictionary, _o: Vector3, _d: Vector3, _p: Dictionary) -> void: _volumenes.append([estado, el, vol]))


func _origen() -> Vector3:
	return Lanzador3D.centro_de(SALIDA, Terreno3D.y_pies(SALIDA) + 0.8)


func _enemigo(c: Vector2i) -> Combate3D:
	var modelo := Pj3D.new()
	modelo.position = Lanzador3D.centro_de(c, Terreno3D.y_pies(c))
	_m.add_child(modelo)
	var e: Combate3D = Combate3D.equipar(modelo, _m, _jug, _l)
	e.set_physics_process(false)
	e.altura = 0.85
	e.congelado = 99.0
	return e


func _hz(el: String, glifos: Dictionary) -> Hechizo:
	return Hechizo.construir(_runas[el], glifos)


func _lanzar(h: Hechizo) -> HechizoVivo:
	return HechizoVivo.crear(h, _origen(), Vector3.RIGHT, _l)


func _vol() -> Dictionary:
	return _volumenes[0][2] if not _volumenes.is_empty() else {}


## Metros del dibujo (de la mano a la punta) y si lleva un choque «muro» marcado `corte`.
func _largo(vol: Dictionary) -> float:
	return ((vol["haz"]["desde"] as Vector3).distance_to(vol["haz"]["hasta"] as Vector3)) if vol.has("haz") else 0.0


func _hay_corte(vol: Dictionary) -> bool:
	for ch in (vol["haz"]["choques"] as Array) if vol.has("haz") else []:
		if bool((ch as Dictionary).get("corte", false)):
			return true
	return false


func _x_de(c: Vector2i) -> float:
	return Lanzador3D.centro_de(c, 0.0).x


# 1. Tres enemigos en fila --------------------------------------------------------------------------------------------------

func _fila() -> void:
	for el in ELEMENTOS:
		_montar()
		var e1: Combate3D = _enemigo(Vector2i(5, 8))
		var e2: Combate3D = _enemigo(Vector2i(7, 8))
		var e3: Combate3D = _enemigo(Vector2i(8, 8))
		var v1: float = e1.health
		var v2: float = e2.health
		var v3: float = e3.health
		var h: Hechizo = _hz(el, {"linea_x": 5})
		var alcance_u: float = h.alcance_haz * Terreno3D.casilla
		_ok("1 %s: el haz llega a los tres (alcance %.1f u, el tercero a %.1f u)" % [el, alcance_u, _x_de(Vector2i(8, 8)) - _origen().x], alcance_u > _x_de(Vector2i(8, 8)) - _origen().x + 0.5)
		_lanzar(h)
		var vol: Dictionary = _vol()
		var hasta_x: float = (vol["haz"]["hasta"] as Vector3).x if vol.has("haz") else 0.0
		if el == "fuego":
			_ok("1 fuego: hiere a los TRES (%.0f→%.1f, %.0f→%.1f, %.0f→%.1f)" % [v1, e1.health, v2, e2.health, v3, e3.health], e1.health < v1 and e2.health < v2 and e3.health < v3)
			_ok("1 fuego: el dibujo no se corta (llega a x %.2f, más allá del tercero en %.2f) y no hay choque de corte" % [hasta_x, _x_de(Vector2i(8, 8))], hasta_x > _x_de(Vector2i(8, 8)) and not _hay_corte(vol))
		elif el == "viento":
			_ok("1 viento: el dibujo no se corta (llega a x %.2f, más allá del tercero en %.2f) y no hay choque de corte" % [hasta_x, _x_de(Vector2i(8, 8))], hasta_x > _x_de(Vector2i(8, 8)) and not _hay_corte(vol))
			var emp2: Vector3 = e2.get("_empuje") as Vector3
			var emp3: Vector3 = e3.get("_empuje") as Vector3
			_ok("1 viento: empuja al segundo y al tercero (%.2f, %.2f u/s)" % [emp2.length(), emp3.length()], emp2.length() > 0.05 and emp3.length() > 0.05)
		else:
			_ok("1 %s: solo hiere al PRIMERO (%.0f→%.1f) y no al segundo (%.1f) ni al tercero (%.1f)" % [el, v1, e1.health, e2.health, e3.health], e1.health < v1 and e2.health == v2 and e3.health == v3)
			_ok("1 %s: el dibujo acaba en la cara del primero (x %.2f, enemigo en %.2f, segundo en %.2f) con un choque de corte" % [el, hasta_x, _x_de(Vector2i(7, 8)), _x_de(Vector2i(7, 8))], hasta_x < _x_de(Vector2i(7, 8)) + 0.05 and hasta_x > _origen().x and _hay_corte(vol))
			var pasa: bool = false
			for c in vol.get("celdas", []):
				pasa = pasa or (c as Vector2i).x > 5 + 1
			_ok("1 %s: ninguna casilla del haz pasa de la del primero (%d casillas)" % [el, (vol.get("celdas", []) as Array).size()], not pasa and (vol.get("celdas", []) as Array).size() >= 1)
			var emp2: Vector3 = e2.get("_empuje") as Vector3
			_ok("1 %s: el segundo ni se mueve (%.2f u/s)" % [el, emp2.length()], emp2.length() < 0.01)


# 2. Con un muro ------------------------------------------------------------------------------------------------------------

func _con_muro() -> void:
	for el in ["agua", "fuego"]:
		# muro entre el primero y los demás
		_montar()
		_m._bloqueadas[Vector2i(6, 8)] = true
		var e1: Combate3D = _enemigo(Vector2i(5, 8))
		var e2: Combate3D = _enemigo(Vector2i(8, 8))
		var v1: float = e1.health
		var v2: float = e2.health
		_lanzar(_hz(el, {"linea_x": 5}))
		_ok("2 %s con un muro tras el primero: hiere al de delante (%.0f→%.1f) y no al de detrás del muro (%.1f)" % [el, v1, e1.health, e2.health], e1.health < v1 and e2.health == v2)
		# muro delante de todos
		_montar()
		_m._bloqueadas[Vector2i(4, 8)] = true
		var d1: Combate3D = _enemigo(Vector2i(6, 8))
		var d2: Combate3D = _enemigo(Vector2i(8, 8))
		var w1: float = d1.health
		var w2: float = d2.health
		_lanzar(_hz(el, {"linea_x": 5}))
		_ok("2 %s con el muro delante de todos: nadie recibe el golpe (%.1f, %.1f)" % [el, d1.health, d2.health], d1.health == w1 and d2.health == w2)
	# el enemigo más cerca que el muro: el corte es el enemigo, no el muro (agua)
	_montar()
	_m._bloqueadas[Vector2i(8, 8)] = true
	var near: Combate3D = _enemigo(Vector2i(5, 8))
	_lanzar(_hz("agua", {"linea_x": 5}))
	var hx: float = (_vol()["haz"]["hasta"] as Vector3).x
	_ok("2 agua con el enemigo ANTES del muro: el dibujo acaba en el enemigo (x %.2f < su casilla %.2f), no en el muro (%.2f)" % [hx, _x_de(Vector2i(5, 8)), _x_de(Vector2i(8, 8))], hx < _x_de(Vector2i(5, 8)) + 0.05 and _hay_corte(_vol()))
	# sin enemigo: el haz llega al muro como siempre y no hay corte de enemigo
	_montar()
	_m._bloqueadas[Vector2i(8, 8)] = true
	_lanzar(_hz("agua", {"linea_x": 5}))
	_ok("2 agua sin enemigos: se para en el muro como siempre (sin choque de corte)", not _hay_corte(_vol()) and (_vol()["haz"]["hasta"] as Vector3).x < _x_de(Vector2i(8, 8)))


# 3. Muerto y de lado -------------------------------------------------------------------------------------------------------

func _muerto_y_lado() -> void:
	_montar()
	var muerto: Combate3D = _enemigo(Vector2i(5, 8))
	var vivo: Combate3D = _enemigo(Vector2i(7, 8))
	var otro: Combate3D = _enemigo(Vector2i(8, 8))
	muerto.muerto = true
	var vv: float = vivo.health
	var vo: float = otro.health
	_lanzar(_hz("agua", {"linea_x": 5}))
	var hx: float = (_vol()["haz"]["hasta"] as Vector3).x
	_ok("3 un enemigo muerto no corta: el corte es el vivo siguiente (%.0f→%.1f) y el de detrás no recibe (%.1f); dibujo hasta x %.2f (vivo en %.2f)" % [vv, vivo.health, otro.health, hx, _x_de(Vector2i(7, 8))],
		vivo.health < vv and otro.health == vo and hx > _x_de(Vector2i(5, 8)) and hx < _x_de(Vector2i(7, 8)) + 0.05)
	# uno en la fila de al lado (a más de una casilla de lado): no corta
	_montar()
	var lado: Combate3D = _enemigo(Vector2i(5, 11))
	var fondo: Combate3D = _enemigo(Vector2i(8, 8))
	var vl: float = lado.health
	var vf: float = fondo.health
	_lanzar(_hz("agua", {"linea_x": 5}))
	_ok("3 uno de lado (a 3 filas) no corta ni recibe (%.1f); el de la fila sí (%.0f→%.1f)" % [lado.health, vf, fondo.health], lado.health == vl and fondo.health < vf)


# 4. Pegado a la mano -------------------------------------------------------------------------------------------------------

func _pegado() -> void:
	_montar()
	var e: Combate3D = _enemigo(Vector2i(4, 8))
	var v: float = e.health
	_lanzar(_hz("agua", {"linea_x": 3}))
	var largo: float = _largo(_vol())
	_ok("4 un enemigo pegado a la mano: recibe el golpe (%.0f→%.1f) y el haz no se queda en nada (%.2f u ≥ %.1f)" % [v, e.health, largo, HechizoVivo.HAZ_CORTE_MIN_U - 0.1], e.health < v and largo >= HechizoVivo.HAZ_CORTE_MIN_U - 0.1)
