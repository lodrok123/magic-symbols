extends SceneTree
## Pruebas de Flotador3D (11.6) y del enchufe de AguaSim3D al Lanzador (11.3), sin ventana. Lo escribe el Juego.
##   godot --headless --path . --script res://poc_25d/herramientas/prueba_flotador.gd
## Termina con «FALLOS: n».

class MundoFalso extends Node3D:
	const S: float = 2.3
	const ALTO: float = 2.3 * 0.45
	const ALTO_AGUA: float = 2.3 * 0.45 * 0.6
	var _lado: int = 6
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var mapa: PackedStringArray = ["######", "#....#", "~~~~~~", "~~~~~~", "#....#", "######"]
	func _letra(c: Vector2i) -> String:
		return String(mapa[c.y][c.x])

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _suelo_plano(raiz: Node, ancho: float, y: float) -> void:
	var cuerpo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var f := BoxShape3D.new()
	f.size = Vector3(ancho, 1.0, ancho)
	col.shape = f
	cuerpo.add_child(col)
	raiz.add_child(cuerpo)
	cuerpo.global_position = Vector3(ancho * 0.5, y - 0.5, ancho * 0.5)


func _esperar(seg: float) -> void:
	for _i in range(int(seg * 60.0)):
		await physics_frame


func _initialize() -> void:
	await process_frame
	await _flota_en_hoyo()
	await _corriente()
	await _en_seco()
	await _lanzador()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Un hoyo de 4 × 4 casillas con 0,6 u de agua: el tronco cae, se asienta y flota a ~0,08 por debajo de la superficie.
func _flota_en_hoyo() -> void:
	var raiz := Node3D.new()
	root.add_child(raiz)
	var a := AguaSim3D.new()
	a.configurar(4, 4, 3, 2.3, func(_c): return 0.0, func(_c): return false)
	for y in range(4):
		for x in range(4):
			a.llenar_casilla(Vector2i(x, y), 0.6)
	_suelo_plano(raiz, 9.2, 0.0)
	var f := Flotador3D.new()
	f.agua = a
	raiz.add_child(f)
	f.global_position = Vector3(4.6, 1.8, 4.6)
	var t0: int = Time.get_ticks_usec()
	var n: int = 0
	var minimo: float = INF
	for _i in range(60 * 8):
		await physics_frame
		a.paso(1.0 / 60.0)
		n += 1
		if _i > 60 * 2:
			minimo = minf(minimo, f.global_position.y)
	var y_f: float = f.global_position.y
	var inclin: float = f.global_transform.basis.y.dot(Vector3.UP)
	_ok("1 flota (3-4 sondas en el agua)", f.flota(), "hundidas %d" % f.hundidas)
	_ok("1 la altura es la de la superficie menos ~0,08", absf(y_f - (0.6 - 0.082)) < 0.05, "y %.3f (esperado %.3f)" % [y_f, 0.6 - 0.082])
	_ok("1 no se hunde ni sale despedido", minimo > 0.3 and y_f < 0.7, "mínimo tras el rebote %.3f" % minimo)
	_ok("1 queda derecho", inclin > 0.99, "up·Y %.4f" % inclin)
	var v: float = f.linear_velocity.length()
	_ok("1 se calma", v < 0.05, "|v| %.3f" % v)
	# Sube el nivel del agua: el tronco sube con ella (no está clavado).
	for y in range(4):
		for x in range(4):
			a.llenar_casilla(Vector2i(x, y), 1.0)
	for _i in range(60 * 4):
		await physics_frame
		a.paso(1.0 / 60.0)
	_ok("2 sube con el agua", absf(f.global_position.y - (1.0 - 0.082)) < 0.07, "y %.3f (esperado %.3f)" % [f.global_position.y, 1.0 - 0.082])
	raiz.queue_free()


## Un canal de 6 casillas con manantial a la izquierda y salida a nivel fijo a la derecha: la corriente lo arrastra.
func _corriente() -> void:
	var raiz := Node3D.new()
	root.add_child(raiz)
	var a := AguaSim3D.new()
	a.configurar(6, 1, 3, 2.3, func(_c): return 0.0, func(_c): return false)
	a.fuente_en(Vector2i(0, 0), 2.0)
	a.fijar_nivel(Vector2i(5, 0), 0.3)
	for _i in range(60 * 20):
		a.paso(1.0 / 60.0)
	_suelo_plano(raiz, 14.0, 0.0)
	var f := Flotador3D.new()
	f.agua = a
	raiz.add_child(f)
	f.global_position = Vector3(2.0 * 2.3 + 1.1, 1.0, 1.15)
	var x0: float = f.global_position.x
	for _i in range(60 * 5):
		await physics_frame
		a.paso(1.0 / 60.0)
	_ok("3 la corriente lo arrastra", f.global_position.x - x0 > 0.8, "x %.2f -> %.2f" % [x0, f.global_position.x])
	raiz.queue_free()


## En seco no flota: cae y se queda en el suelo con 0 sondas en el agua.
func _en_seco() -> void:
	var raiz := Node3D.new()
	root.add_child(raiz)
	var a := AguaSim3D.new()
	a.configurar(4, 4, 3, 2.3, func(_c): return 0.0, func(_c): return false)
	_suelo_plano(raiz, 9.2, 0.0)
	var f := Flotador3D.new()
	f.agua = a
	raiz.add_child(f)
	f.global_position = Vector3(4.6, 1.5, 4.6)
	await _esperar(3.0)
	_ok("4 en seco no flota y apoya en el suelo", f.hundidas == 0 and f.global_position.y < 0.3, "y %.3f hundidas %d" % [f.global_position.y, f.hundidas])
	raiz.queue_free()


## Lanzador3D.montar_agua_sim con una maqueta falsa: las casillas «~» son agua, el resto no; el borde del río mantiene el nivel.
func _lanzador() -> void:
	var m := MundoFalso.new()
	root.add_child(m)
	Lanzador3D.configurar(m)
	for y in range(6):
		for x in range(6):
			if m.mapa[y][x] == "#":
				m._bloqueadas[Vector2i(x, y)] = true
	var sim: AguaSim3D = Lanzador3D.montar_agua_sim()
	_ok("5 se crea la simulación", sim != null and Lanzador3D.agua_sim == sim)
	var bien: bool = true
	for y in range(6):
		for x in range(6):
			var c := Vector2i(x, y)
			bien = bien and (Lanzador3D.es_agua(c) == (m.mapa[y][x] == "~"))
	_ok("5 es_agua coincide con las letras «~» al empezar", bien)
	var mal: Array = []
	for _i in range(60 * 10):
		sim.paso(1.0 / 60.0)
	for y in range(6):
		for x in range(6):
			var c := Vector2i(x, y)
			if Lanzador3D.es_agua(c) != (m.mapa[y][x] == "~"):
				mal.append(c)
	_ok("5 tras 10 s el río sigue donde estaba (nivel fijo en el borde, paredes en la orilla)", mal.is_empty(), "distintas: %s" % [mal])
	_ok("5 se nada en el río", sim.se_nada_en(Vector2i(2, 2)), "prof %.2f" % sim.profundidad_casilla(Vector2i(2, 2)))
	m._helada[Vector2i(2, 2)] = true
	_ok("5 una casilla helada del mundo no es agua", not Lanzador3D.es_agua(Vector2i(2, 2)))
	Lanzador3D.agua_sim = null
	_ok("5 sin simulación vuelve a la letra", Lanzador3D.es_agua(Vector2i(0, 2)))
	m.queue_free()
