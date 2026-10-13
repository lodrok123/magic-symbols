extends SceneTree
## Terreno3D (M1, 13/10): el suelo del mundo sin nodos ni hechizos, con una maqueta falsa y sin ventana. Mide lo que el
## resto del juego le pregunta: casilla ↔ punto, altura de los pies (con y sin hielo), si se puede pisar, si se ven dos puntos.
## Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_terreno.gd

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

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


## Una maqueta de 6×6. Terreno3D se configura a través de Lanzador3D.configurar (así se hace en el juego).
func _mundo(mapa: PackedStringArray) -> MundoFalso:
	var m := MundoFalso.new()
	m._mapa = mapa
	root.add_child(m)
	Lanzador3D.configurar(m)
	for y in range(6):
		for x in range(6):
			if mapa[y][x] == "#" or mapa[y][x] == "u":
				m._bloqueadas[Vector2i(x, y)] = true
	return m


func _initialize() -> void:
	await process_frame
	var m := _mundo(["######", "#....#", "#.~~.#", "#.b..#", "#....#", "######"])
	_casillas(m)
	_pies(m)
	_pisar(m)
	_vista(m)
	_estado(m)
	_datos_propios(m)
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _casillas(m: MundoFalso) -> void:
	_ok("1 configurar lee S, ALTO y ALTO_AGUA de la maqueta",
			Terreno3D.casilla == m.S and Terreno3D.alto_suelo == m.ALTO and Terreno3D.alto_agua == m.ALTO_AGUA and Terreno3D.ALTO_NIVEL == m.ALTO)
	var bien: bool = true
	for y in range(-2, 8):
		for x in range(-2, 8):
			var c := Vector2i(x, y)
			if Terreno3D.celda_de(Terreno3D.centro_de(c, 1.7)) != c:
				bien = false
	_ok("2 celda_de(centro_de(c)) = c, también fuera del mapa y con coordenadas negativas", bien)
	var p := Terreno3D.centro_de(Vector2i(3, 2), 0.9)
	_ok("2 centro_de pone el punto en mitad de la casilla y a la y pedida",
			absf(p.x - 3.5 * m.S) < 1.0e-5 and absf(p.z - 2.5 * m.S) < 1.0e-5 and absf(p.y - 0.9) < 1.0e-5)
	_ok("2 el borde pertenece a la casilla de arriba: x = 3·S → casilla 3", Terreno3D.celda_de(Vector3(3.0 * m.S, 0, 0.1)).x == 3)
	_ok("2 justo antes del borde sigue en la 2", Terreno3D.celda_de(Vector3(3.0 * m.S - 0.001, 0, 0.1)).x == 2)
	_ok("3 en_mapa: dentro sí, fuera no", Terreno3D.en_mapa(Vector2i(0, 0)) and Terreno3D.en_mapa(Vector2i(5, 5))
			and not Terreno3D.en_mapa(Vector2i(6, 0)) and not Terreno3D.en_mapa(Vector2i(-1, 3)))
	_ok("3 letra_de lee la maqueta", Terreno3D.letra_de(Vector2i(2, 2)) == "~" and Terreno3D.letra_de(Vector2i(1, 1)) == ".")


func _pies(m: MundoFalso) -> void:
	var suelo := Vector2i(1, 1)
	var agua := Vector2i(2, 2)
	var puente := Vector2i(2, 3)
	_ok("4 y_pies en suelo llano = alto_suelo", Terreno3D.y_pies(suelo) == Terreno3D.alto_suelo)
	_ok("4 en agua = alto_agua (sin simulación)", Terreno3D.y_pies(agua) == Terreno3D.alto_agua)
	_ok("4 en puente = alto_agua + 0,12", absf(Terreno3D.y_pies(puente) - (Terreno3D.alto_agua + 0.12)) < 1.0e-6)
	Terreno3D.fijar_altura(suelo, 2)
	_ok("5 con 2 niveles de tierra: alto_suelo + 2·ALTO_NIVEL", absf(Terreno3D.y_pies(suelo) - (Terreno3D.alto_suelo + 2.0 * Terreno3D.ALTO_NIVEL)) < 1.0e-6)
	_ok("5 altura_en la recuerda", Terreno3D.altura_en(suelo) == 2)
	Terreno3D.fijar_altura(suelo, 0)
	_ok("5 fijar_altura(c, 0) la quita", Terreno3D.altura_en(suelo) == 0 and Terreno3D.y_pies(suelo) == Terreno3D.alto_suelo)
	# Con la simulación: sin hielo se pisa en el agua; con hielo, a la altura de la cara del hielo.
	var sim: AguaSim3D = Lanzador3D.montar_agua_sim()     # por el reenvío: así también se refresca el espejo
	_ok("6 montar_agua_sim crea la simulación, la guarda en Terreno3D y el espejo Lanzador3D.agua_sim es la misma", sim != null and Terreno3D.agua_sim == sim and Lanzador3D.agua_sim == sim)
	_ok("6 sin hielo, y_pies del agua = alto_agua", Terreno3D.y_pies(agua) == Terreno3D.alto_agua)
	_ok("6 con simulación, la casilla «~» es agua", Terreno3D.es_agua(agua))
	sim.helar_casilla(agua, true)
	Terreno3D.poner_helada(agua, true)
	var y_hielo: float = sim.hielo_en_casilla(agua)
	_ok("7 con hielo, y_pies = cara de arriba del hielo", y_hielo > -INF and Terreno3D.y_pies(agua) == y_hielo, "hielo %.3f, agua %.3f" % [y_hielo, Terreno3D.alto_agua])
	_ok("7 con hielo ya no es agua y se resbala (sobre_hielo)", not Terreno3D.es_agua(agua) and Terreno3D.sobre_hielo(Terreno3D.centro_de(agua)))
	_ok("7 y el hielo se pisa aunque debajo haya agua", Terreno3D.pisable(agua, 0, false, 0, false))
	Terreno3D.poner_helada(agua, false)
	sim.helar_casilla(agua, false)
	_ok("7 al deshelar vuelve a alto_agua y a ser agua", Terreno3D.y_pies(agua) == Terreno3D.alto_agua and Terreno3D.es_agua(agua))


func _pisar(_m: MundoFalso) -> void:
	var llana := Vector2i(1, 1)
	var agua := Vector2i(2, 2)
	var muro := Vector2i(0, 0)
	_ok("8 suelo llano: se pisa", Terreno3D.pisable(llana, 0, false, 0, false))
	_ok("8 fuera del mapa: no", not Terreno3D.pisable(Vector2i(9, 9), 0, false, 0, false))
	_ok("8 muro: no; con ignora_bloqueo sí (casilla parcial)", not Terreno3D.pisable(muro, 0, false, 0, false) and Terreno3D.pisable(muro, 0, false, 0, false, true))
	_ok("8 agua: solo si puede nadar", not Terreno3D.pisable(agua, 0, false, 0, false) and Terreno3D.pisable(agua, 0, false, 0, true))
	Terreno3D.fijar_altura(llana, 1)
	_ok("9 un nivel por encima: sin saltar no, saltando sí", not Terreno3D.pisable(llana, 0, false, 9, false) and Terreno3D.pisable(llana, 0, true, 9, false))
	_ok("9 si ya estás en el nivel 1, lo pisas sin saltar", Terreno3D.pisable(llana, 1, false, 9, false))
	_ok("9 max_nivel 0: nunca un nivel que lo supera (el goblin no sube)", not Terreno3D.pisable(llana, 1, true, 0, false))
	Terreno3D.fijar_altura(llana, 2)
	_ok("9 dos niveles: no se sube de golpe desde el 0", not Terreno3D.pisable(llana, 0, true, 9, false))
	Terreno3D.fijar_altura(llana, 0)
	Terreno3D.bloquear_celda(llana)
	_ok("10 bloquear_celda: bloqueada y ya no se pisa", Terreno3D.bloqueada(llana) and not Terreno3D.pisable(llana, 0, false, 0, false))
	Terreno3D.liberar_celda(llana)
	_ok("10 liberar_celda: vuelve a pisarse", not Terreno3D.bloqueada(llana) and Terreno3D.pisable(llana, 0, false, 0, false))


func _vista(_m: MundoFalso) -> void:
	var a := Terreno3D.centro_de(Vector2i(1, 1), 1.0)
	var b := Terreno3D.centro_de(Vector2i(4, 1), 1.0)
	_ok("11 línea libre sobre suelo llano", Terreno3D.linea_libre(a, b))
	Terreno3D.fijar_altura(Vector2i(2, 1), 1)
	_ok("11 una torre de tierra corta la vista", not Terreno3D.linea_libre(a, b))
	Terreno3D.fijar_altura(Vector2i(2, 1), 0)
	Terreno3D.bloquear_celda(Vector2i(3, 1))
	_ok("11 una casilla bloqueada corta la vista", not Terreno3D.linea_libre(a, b))
	Terreno3D.liberar_celda(Vector2i(3, 1))
	_ok("11 el agua no corta la vista", Terreno3D.linea_libre(Terreno3D.centro_de(Vector2i(1, 2), 1.0), Terreno3D.centro_de(Vector2i(4, 2), 1.0)))
	_ok("11 salir del mapa la corta", not Terreno3D.linea_libre(a, Terreno3D.centro_de(Vector2i(9, 1), 1.0)))
	_ok("11 celda_solida: el muro sí, el suelo no", Terreno3D.celda_solida(Vector2i(0, 0), 0) and not Terreno3D.celda_solida(Vector2i(1, 1), 0))


func _estado(m: MundoFalso) -> void:
	# Los reenvíos de Lanzador3D dan lo mismo que Terreno3D (mientras existan).
	var p := Vector3(5.1, 0, 7.7)
	_ok("12 reenvíos M1: Lanzador3D.celda_de/centro_de/y_pies = Terreno3D",
			Lanzador3D.celda_de(p) == Terreno3D.celda_de(p) and Lanzador3D.centro_de(Vector2i(2, 3), 1.0) == Terreno3D.centro_de(Vector2i(2, 3), 1.0)
			and Lanzador3D.y_pies(Vector2i(2, 2)) == Terreno3D.y_pies(Vector2i(2, 2)))
	_ok("12 el espejo mundo_s es el mundo de Terreno3D", Lanzador3D.mundo_s == Terreno3D.mundo_s and Terreno3D.mundo_s == m)
	_ok("12 Lanzador3D.configurar engancha al_solidificar (los presos en hielo se sueltan sin que el terreno conozca la magia)", Terreno3D.al_solidificar.is_valid())
	Terreno3D.fijar_altura(Vector2i(3, 3), 1)
	Lanzador3D.configurar(m)
	_ok("13 configurar reinicia alturas y la simulación (también el espejo)", Terreno3D.altura_en(Vector2i(3, 3)) == 0 and Terreno3D.agua_sim == null and Lanzador3D.agua_sim == null)
	Terreno3D.fijar_altura(Vector2i(3, 3), 1)
	_ok("13 una cornisa fijada queda hasta el próximo configurar", Terreno3D.altura_en(Vector2i(3, 3)) == 1 and Terreno3D.permanentes.has(Vector2i(3, 3)))


## M5 (Juego): con datos propios el terreno contesta SIN la maqueta (sin `_letra`, `_lado`, `_bloqueadas`, `_es_canal`, `_abre_hacia`).
func _datos_propios(m: MundoFalso) -> void:
	var mapa := PackedStringArray(["######", "#..c.#", "#-L~~#", "#.b..#", "#....#", "######"])
	var bloq: Dictionary = {Vector2i(0, 0): true}
	var canal: Dictionary = {Vector2i(4, 4): true}
	var giros: Dictionary = {Vector2i(1, 2): 90.0}
	Terreno3D.cargar_datos(mapa, bloq, canal, giros)
	# La maqueta falsa NO responde a nada de esto: si el terreno le preguntara, daría otra cosa.
	m._mapa = ["......", "......", "......", "......", "......", "......"]
	_ok("14 con datos propios, letra_de sale del mapa cargado y no de la maqueta", Terreno3D.letra_de(Vector2i(3, 1)) == "c" and Terreno3D.letra_de(Vector2i(3, 2)) == "~")
	_ok("14 fuera del mapa es «#» (pared), como la maqueta", Terreno3D.letra_de(Vector2i(-1, 0)) == "#" and Terreno3D.letra_de(Vector2i(0, 9)) == "#")
	_ok("14 en_mapa con el lado del mapa cargado", Terreno3D.en_mapa(Vector2i(5, 5)) and not Terreno3D.en_mapa(Vector2i(6, 0)) and Terreno3D.lado_del_mapa() == 6)
	_ok("14 el mapa se COPIA: cambiarlo fuera no cambia el del terreno", mapa[1][3] == "c" and Terreno3D.letra_de(Vector2i(3, 1)) == "c")
	_ok("15 bloqueadas es el diccionario compartido (por referencia)", Terreno3D.bloqueada(Vector2i(0, 0)) and not Terreno3D.bloqueada(Vector2i(2, 2)))
	Terreno3D.bloquear_celda(Vector2i(2, 2))
	_ok("15 bloquear_celda escribe en ese mismo diccionario", bloq.has(Vector2i(2, 2)) and Terreno3D.bloqueada(Vector2i(2, 2)))
	Terreno3D.liberar_celda(Vector2i(2, 2))
	_ok("15 y liberar lo quita", not bloq.has(Vector2i(2, 2)))
	_ok("16 es_canal: letras «-» y «L» y las celdas de piezas", Terreno3D.es_canal(Vector2i(1, 2)) and Terreno3D.es_canal(Vector2i(2, 2)) and Terreno3D.es_canal(Vector2i(4, 4)) and not Terreno3D.es_canal(Vector2i(1, 1)))
	_ok("16 el cauce «c» cuenta como cauce seco; el canal de ruinas no es «c»", Terreno3D.es_cauce_seco(Vector2i(3, 1)) and Terreno3D.es_canal_ruinas(Vector2i(1, 2)) and not Terreno3D.es_canal_ruinas(Vector2i(3, 1)))
	# Lados abiertos: recto `-` sin giro corre este-oeste; con giro 90 corre norte-sur; codo `L` sin giro abre al oeste y al sur.
	_ok("17 recto sin giro: abre al oeste y al este", Terreno3D.abre_hacia(Vector2i(4, 4), Vector2i(-1, 0)) and Terreno3D.abre_hacia(Vector2i(4, 4), Vector2i(1, 0)) and not Terreno3D.abre_hacia(Vector2i(4, 4), Vector2i(0, 1)))
	var lados90: Array = Terreno3D.lados_de_canal(Vector2i(1, 2))
	_ok("17 recto con giro 90: abre al norte y al sur", lados90.size() == 2 and lados90.has(Vector2i(0, 1)) and lados90.has(Vector2i(0, -1)), "%s" % [lados90])
	var codo: Array = Terreno3D.lados_de_canal(Vector2i(2, 2))
	_ok("17 codo sin giro: abre al oeste y al sur", codo.size() == 2 and codo.has(Vector2i(-1, 0)) and codo.has(Vector2i(0, 1)), "%s" % [codo])
	# Cambiar una letra.
	Terreno3D.poner_letra(Vector2i(3, 1), "~")
	_ok("18 poner_letra cambia el mapa del terreno", Terreno3D.letra_de(Vector2i(3, 1)) == "~")
	Terreno3D.poner_letra(Vector2i(9, 9), "x")
	_ok("18 fuera del mapa no hace nada", Terreno3D.letra_de(Vector2i(9, 9)) == "#")
	# La simulación del agua se monta sin maqueta.
	var sim: AguaSim3D = Terreno3D.montar_agua_sim()
	_ok("19 montar_agua_sim funciona con datos propios", sim != null and Terreno3D.es_agua(Vector2i(3, 2)) and not Terreno3D.es_agua(Vector2i(1, 4)))
	# Sin nada de mundo ni datos: nada pregunta a nadie.
	Terreno3D.olvidar_datos()
	_ok("20 olvidar_datos vuelve a preguntar a la maqueta (que ahora dice «.»)", not Terreno3D.datos_propios and Terreno3D.letra_de(Vector2i(3, 1)) == ".")
	m.queue_free()
