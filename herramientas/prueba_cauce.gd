extends SceneTree
## Cauce abierto SIN Surtidor3D (14/10): la tinaja de la maqueta (Reactivo3D) abre su canal a la simulación con `Mundo3D.abrir_cauce`.
## Mismas casillas y mismo caudal que prueba_canal_tinaja: las profundidades en régimen tienen que salir iguales. Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_cauce.gd

class MundoFalso extends Node3D:
	const S: float = 2.3
	var _lado: int = 6
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var _abre: Dictionary = {}              ## Vector2i -> Array de Vector2i (lados que abre cada pieza)
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _es_canal(c: Vector2i) -> bool:
		return _en(c) and (_letra(c) == "-" or _letra(c) == "L")
	func _en(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < 6 and c.y < 6
	func _abre_hacia(c: Vector2i, v: Vector2i) -> bool:
		return (_abre.get(c, []) as Array).has(v)
	func _liberar(c: Vector2i) -> void:
		_bloqueadas.erase(c)

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_ok("0 sin simulación, abrir_cauce no hace nada y lo dice", not Mundo3D.abrir_cauce([Vector2i(2, 1)], 1.5))
	var m := MundoFalso.new()
	m._mapa = ["######", "#u-L##", "###-##", "###~##", "###~##", "###~##"]
	m._abre = {Vector2i(2, 1): [Vector2i(-1, 0), Vector2i(1, 0)], Vector2i(3, 1): [Vector2i(-1, 0), Vector2i(0, 1)],
			Vector2i(3, 2): [Vector2i(0, -1), Vector2i(0, 1)]}
	root.add_child(m)
	Lanzador3D.configurar(m)
	for y in range(6):
		for x in range(6):
			if m._letra(Vector2i(x, y)) in ["#", "u", "~", "-", "L"]:
				m._bloqueadas[Vector2i(x, y)] = true
	var sim: AguaSim3D = Terreno3D.montar_agua_sim()
	var canal: Array = [Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 2)]
	_ok("1 sellado hasta que se abre", sim.profundidad_casilla(canal[0] as Vector2i) == 0.0)
	_ok("2 abrir_cauce devuelve true con simulación", Mundo3D.abrir_cauce(canal, Surtidor3D.CAUDAL_TINAJA))
	_ok("3 es idempotente: una segunda llamada no suma el caudal otra vez", Mundo3D.abrir_cauce(canal, Surtidor3D.CAUDAL_TINAJA))
	var f: float = 0.0
	for i in sim._trozos(canal[0] as Vector2i):
		f += sim.fuente[i]
	# 15/10: el manantial de un cauce ARRANCA despacio (ReaccionesAgua3D.ARRANQUE_CAUCE, curva suave): al abrir casi no echa agua y al acabar el arranque llega a CAUDAL_TINAJA.
	_ok("4a el manantial arranca despacio (al abrir, %.3f u³/s)" % f, f < 0.1)
	var t: float = 0.0
	while t < 35.0:
		sim.paso(1.0 / 60.0)                     # sin esperar fotogramas de física: la simulación avanza sola, y así la prueba dura segundos
		t += 1.0 / 60.0
		if absf(t - ReaccionesAgua3D.ARRANQUE_CAUCE - 0.5) < 0.5 / 60.0:
			f = 0.0
			for i in sim._trozos(canal[0] as Vector2i):
				f += sim.fuente[i]
			_ok("4b pasado el arranque la primera casilla tiene UN manantial de CAUDAL_TINAJA (%.2f)" % Surtidor3D.CAUDAL_TINAJA, absf(f - Surtidor3D.CAUDAL_TINAJA) < 1.0e-3, "fuente %.3f" % f)
	var p: Array = []
	for c in canal:
		p.append(sim.profundidad_casilla(c as Vector2i))
	print("      profundidades (%.0f s): %.3f / %.3f / %.3f   (con Surtidor3D: 0,479 / 0,355 / 0,175)" % [t, p[0], p[1], p[2]])
	var q: float = Surtidor3D.CAUDAL_TINAJA
	var esperado: Array = [0.329 * q, 0.246 * q, 0.127 * q]
	var cerca: bool = true
	for k in range(3):
		cerca = cerca and absf(float(p[k]) - float(esperado[k])) < maxf(0.03, 0.12 * float(esperado[k]))
	_ok("5 las profundidades salen como con el Surtidor3D", cerca)
	_ok("6 hay agua en las tres casillas y el codo conduce (es_agua)", float(p[0]) > 0.05 and float(p[1]) > 0.05 and float(p[2]) > 0.05 and Terreno3D.es_agua(Vector2i(3, 1)))
	var otra := MundoFalso.new()
	_ok("7 nombre de un objeto golpeado: su tipo, su clase o su nombre", Lanzador3D.new()._nombre_de_objeto(otra) != "")
	m.queue_free()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
