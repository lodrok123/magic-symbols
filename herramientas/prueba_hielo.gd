extends SceneTree
## Hielo de verdad (11.13) con la maqueta falsa, sin ventana: hechizos, pisar, cobertura, atrapar, soltar, resbalar, y el canal de la
## tinaja (diario 12/10 15:30). Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_hielo.gd

class MundoFalso extends Node3D:
	const S: float = 2.3
	const ALTO: float = 2.3 * 0.45
	const ALTO_AGUA: float = 2.3 * 0.45 * 0.6
	var _lado: int = 6
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var liberadas: Array = []
	var canales: Array = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _es_canal(c: Vector2i) -> bool:
		return _letra(c) == "-"
	func _liberar(c: Vector2i) -> void:
		liberadas.append(c)
		_bloqueadas.erase(c)
	func _poner_canal(c: Vector2i, canal: int, valor: float) -> void:
		canales.append([c, canal, valor])

class GoblinFalso extends Node3D:
	var congelado: float = 0.0

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _mundo(mapa: PackedStringArray) -> MundoFalso:
	var m := MundoFalso.new()
	m._mapa = mapa
	root.add_child(m)
	Lanzador3D.configurar(m)
	for y in range(6):
		for x in range(6):
			if mapa[y][x] == "#" or mapa[y][x] == "u" or mapa[y][x] == "~":
				m._bloqueadas[Vector2i(x, y)] = true
	return m


func _correr(sim: AguaSim3D, seg: float) -> void:
	for _i in range(int(seg * 60.0)):
		sim.paso(1.0 / 60.0)
		Lanzador3D.procesar_cambios_hielo()


func _initialize() -> void:
	await process_frame
	await _hielo()
	await _canal(false)
	_resbalar()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _hielo() -> void:
	var m := _mundo(["######", "#....#", "~~~~~~", "~~~~~~", "#....#", "######"])
	var sim: AguaSim3D = Terreno3D.montar_agua_sim()
	var c := Vector2i(2, 2)
	var p: Vector3 = Terreno3D.centro_de(c, Terreno3D.alto_agua)
	_correr(sim, 1.0)
	var v0: float = sim.volumen_total()
	_ok("1 el río empieza sin hielo", not Terreno3D.sobre_hielo(p) and Terreno3D.es_agua(c) and not m._helada.has(c))
	var y_agua: float = sim.superficie_en(p)
	# Colocamos un tronco y un goblin dentro del agua que se va a helar, y otro goblin en la orilla.
	var tronco := Flotador3D.new()
	tronco.agua = sim
	root.add_child(tronco)
	tronco.global_position = p + Vector3(0.3, 0.0, 0.0)
	var dentro := GoblinFalso.new()
	dentro.add_to_group("combate3d")
	root.add_child(dentro)
	dentro.global_position = p + Vector3(-0.4, 0.0, 0.2)
	var orilla := GoblinFalso.new()
	orilla.add_to_group("combate3d")
	root.add_child(orilla)
	orilla.global_position = Terreno3D.centro_de(Vector2i(2, 1), 1.0)
	Lanzador3D.hechizo_sobre_agua("hielo", p)
	_ok("2 el hielo hiela la casilla (≥ 5 de 9 trocitos)", sim.casilla_helada(c))
	_ok("2 la maqueta lo sabe (_helada) y la libera", m._helada.has(c) and m.liberadas.has(c))
	_ok("2 ya no es agua para el juego", not Terreno3D.es_agua(c))
	_ok("2 se pisa aunque debajo haya agua: pisable", Terreno3D.pisable(c, 0, false, 0, false))
	_ok("2 y_pies = cara de arriba del hielo", absf(Terreno3D.y_pies(c) - y_agua) < 0.02, "%.3f (agua %.3f)" % [Terreno3D.y_pies(c), y_agua])
	_ok("2 resbala: sobre_hielo", Terreno3D.sobre_hielo(p))
	_ok("2 el volumen no cambia", absf(sim.volumen_total() - v0) < 1.0e-4, "%.4f -> %.4f" % [v0, sim.volumen_total()])
	_ok("3 atrapa al goblin que estaba dentro", dentro.congelado >= 19.9 and dentro.has_meta("preso_hielo"), "%.1f" % dentro.congelado)
	_ok("3 no al de la orilla", orilla.congelado == 0.0)
	await physics_frame
	_ok("3 atrapa el tronco (freeze)", tronco.freeze)
	# Cobertura: agua de 0,9 u de hondo ≥ 0,5.
	_ok("4 hielo gordo: sólido para proyectiles", Terreno3D.celda_solida(c, 0) and Terreno3D.cubre_hielo(c), "espesor %.2f" % sim.espesor_hielo(c))
	var a: Vector3 = Terreno3D.centro_de(Vector2i(2, 1), 1.0)
	var b: Vector3 = Terreno3D.centro_de(Vector2i(2, 4), 1.0)
	_ok("4 y la mirada no atraviesa", not Terreno3D.linea_libre(a, b))
	_ok("4 pero se anda por encima: pisable", Terreno3D.pisable(c, 0, false, 0, false))
	# Fuego: funde, suelta, y el agua es la misma.
	Lanzador3D.hechizo_sobre_agua("fuego", p)
	_ok("5 el fuego funde el hielo", not sim.casilla_helada(c) and not m._helada.has(c))
	_ok("5 vuelve a ser agua y se bloquea a pie", Terreno3D.es_agua(c) and m._bloqueadas.has(c))
	_ok("5 el volumen es el mismo", absf(sim.volumen_total() - v0) < 1.0e-4, "%.4f" % sim.volumen_total())
	_ok("5 el goblin queda libre", dentro.congelado == 0.0 and not dentro.has_meta("preso_hielo"))
	_ok("5 el suelo deja de estar «helado»", m.canales.any(func(e: Array) -> bool: return e[0] == c and e[1] == 2 and e[2] == 0.0))
	await physics_frame
	_ok("5 el tronco se suelta", not tronco.freeze)
	_ok("5 la cobertura se va", not Terreno3D.cubre_hielo(c))
	# Tiempo: a los 20 s se suelta solo y _helada se pone al día sin que nadie llame.
	Lanzador3D.hechizo_sobre_agua("hielo", p)
	_ok("6 se vuelve a helar", m._helada.has(c))
	_correr(sim, 19.0)
	_ok("6 a los 19 s sigue helada", m._helada.has(c))
	_correr(sim, 2.0)
	_ok("6 a los 21 s se ha soltado sola y _helada lo sabe", not m._helada.has(c) and Terreno3D.es_agua(c))
	# Agua poco honda: no cubre.
	var poco := Vector2i(1, 1)
	sim.llenar_casilla(poco, sim.suelo[sim._trozos(poco)[0]] + 0.3)
	m._mapa[1] = "#~...#"
	Lanzador3D.hechizo_sobre_agua("hielo", Terreno3D.centro_de(poco, 1.0))
	_ok("7 un hielo fino (0,3) no cubre", sim.casilla_helada(poco) and not Terreno3D.cubre_hielo(poco), "espesor %.2f" % sim.espesor_hielo(poco))
	# Sin simulación nada cambia.
	Terreno3D.agua_sim = null
	Lanzador3D.hechizo_sobre_agua("hielo", p)
	_ok("8 sin simulación no hace nada y no falla", true)
	for n in [tronco, dentro, orilla, m]:
		n.queue_free()


func _canal(_x: bool) -> void:
	var m := _mundo(["######", "#u---#", "######", "######", "######", "######"])
	var sim: AguaSim3D = Terreno3D.montar_agua_sim()
	var s := Surtidor3D.new()
	s.preparar(m, Vector2i(1, 1))
	root.add_child(s)
	await process_frame
	_ok("9 el canal de ruinas cuenta como cauce (3 casillas)", s.cauce.size() == 3, "%s" % [s.cauce])
	for _i in range(180):
		sim.paso(1.0 / 60.0)
	_ok("9 sellado hasta que se abre", sim.profundidad_casilla(Vector2i(3, 1)) == 0.0 and not Terreno3D.es_agua(Vector2i(3, 1)))
	var rune := RuneData.new()
	rune.tags.append("agua")
	s.on_spell_hit(rune)
	var t: float = 0.0
	while t < 30.0 and not (s._sim == null and s.esta_lleno):
		await physics_frame
		sim.paso(1.0 / 60.0)
		t += 1.0 / 60.0
	for _i in range(60 * 6):
		sim.paso(1.0 / 60.0)
	var agua_ok: bool = true
	for x in range(2, 5):
		agua_ok = agua_ok and Terreno3D.es_agua(Vector2i(x, 1)) and sim.se_nada_en(Vector2i(x, 1))
	_ok("10 el agua corre por el canal y las 3 casillas son agua (el rayo la verá)", agua_ok, "a los %.1f s" % t)
	var letras: bool = true
	for x in range(2, 5):
		letras = letras and m._letra(Vector2i(x, 1)) == "-"
	_ok("10 el canal conserva su letra (la maqueta lo sigue viendo como canal)", letras)
	_ok("10 el emisor de rayo la conduce", EmisorRayo3D.agua_conectada(Vector2i(2, 1), func(c: Vector2i) -> bool: return Terreno3D.es_agua(c)).has(Vector2i(4, 1)))
	s.queue_free()
	m.queue_free()


func _resbalar() -> void:
	var v := Vector3.ZERO
	var objetivo := Vector3(1.6, 0, 0)
	for _i in range(15):
		v = Jugador3D.velocidad_hielo(v, objetivo, 1.0 / 30.0)
	_ok("11 acelera poco a poco (0,5 s a 3 u/s²)", v.length() > 1.4 and v.length() < 1.61, "%.2f u/s a los 0,5 s" % v.length())
	var v1 := Jugador3D.velocidad_hielo(Vector3.ZERO, objetivo, 1.0 / 30.0)
	_ok("11 al primer paso va muy por debajo de la velocidad de andar", v1.length() < 0.2, "%.2f" % v1.length())
	var w := Vector3(1.6, 0, 0)
	var dist: float = 0.0
	var t: float = 0.0
	while w.length() > 0.001 and t < 10.0:
		w = Jugador3D.velocidad_hielo(w, Vector3.ZERO, 1.0 / 60.0)
		dist += w.length() / 60.0
		t += 1.0 / 60.0
	_ok("11 cuesta frenar: patina más de 1 u y tarda más de 1 s", dist > 1.0 and t > 1.0, "%.2f u en %.2f s" % [dist, t])
