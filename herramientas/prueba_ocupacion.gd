extends SceneTree
## D1 de PLAN_EOW (21/10): Terreno3D.ocupado(c, nivel) y Terreno3D.cabe(celdas, nivel_desde, alto, sobre_agua), sin mundo gráfico.
## El terreno se alimenta con cargar_datos + fuente de casillas (como el cargador del nivel), así que no hace falta maqueta.
## Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_ocupacion.gd

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	# 8×8: muro de borde, un río «~» en la fila 3, una pieza bloqueada (árbol) en (5,5).
	var mapa := PackedStringArray([
		"########",
		"#......#",
		"#......#",
		"#.~~~..#",
		"#......#",
		"#......#",
		"#......#",
		"########"])
	var bloq: Dictionary = {Vector2i(5, 5): true}
	for i in range(8):                       # el borde también bloquea, como en el nivel real
		for p in [Vector2i(i, 0), Vector2i(i, 7), Vector2i(0, i), Vector2i(7, i)]:
			bloq[p] = true
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(mapa, bloq)
	Terreno3D.activar_fuente_casillas()
	_casos()
	_tiempo()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _casos() -> void:
	# Fuera del mapa
	_ok("1 ocupado fuera del mapa: sí (a cualquier nivel)", Terreno3D.ocupado(Vector2i(-1, 2), 0) and Terreno3D.ocupado(Vector2i(2, 9), 3))
	_ok("1 cabe con una casilla fuera del mapa: no", not Terreno3D.cabe([Vector2i(1, 1), Vector2i(8, 1)], 0, 1))
	# Suelo libre y pieza bloqueada
	_ok("2 suelo libre: no ocupado", not Terreno3D.ocupado(Vector2i(2, 2), 0))
	_ok("2 pieza bloqueada (árbol): ocupa a ras y en todas las alturas de su casilla", Terreno3D.ocupado(Vector2i(5, 5), 0) and Terreno3D.ocupado(Vector2i(5, 5), 2))
	_ok("2 cabe([libre, bloqueada]) = no; cabe([libre]) = sí", not Terreno3D.cabe([Vector2i(4, 5), Vector2i(5, 5)], 0, 1) and Terreno3D.cabe([Vector2i(4, 5)], 0, 1))
	# Río
	var rio := Vector2i(3, 3)
	_ok("3 el río «~» no es ocupado a ras", not Terreno3D.ocupado(rio, 0))
	_ok("3 cabe sobre el río si se permite agua", Terreno3D.cabe([rio], 0, 1, true))
	_ok("3 con sobre_agua=false el río se rechaza", not Terreno3D.cabe([rio], 0, 1, false))
	_ok("3 con sobre_agua=false una forma que solo roza el río también se rechaza", not Terreno3D.cabe([Vector2i(1, 3), Vector2i(2, 3)], 0, 1, false))
	Terreno3D.poner_helada(rio, true)
	_ok("3 con el río helado ya no cuenta como agua: cabe con sobre_agua=false", Terreno3D.cabe([rio], 0, 1, false))
	Terreno3D.poner_helada(rio, false)
	# Cornisa
	var cor := Vector2i(2, 2)
	Terreno3D.fijar_altura(cor, 2)
	_ok("4 cornisa de 2 niveles ocupa los niveles 0 y 1", Terreno3D.ocupado(cor, 0) and Terreno3D.ocupado(cor, 1))
	_ok("4 y no el nivel 2 (el de encima)", not Terreno3D.ocupado(cor, 2))
	_ok("4 cabe 1 de alto justo encima (nivel 2)", Terreno3D.cabe([cor], 2, 1))
	_ok("4 no cabe 2 de alto desde el nivel 1 (pisa la cornisa)", not Terreno3D.cabe([cor], 1, 2))
	_ok("4 cabe 3 de alto desde el nivel 2", Terreno3D.cabe([cor], 2, 3))
	# Forma de varias casillas
	var forma: Array = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]
	_ok("5 forma 2×2 que incluye la cornisa: a ras no cabe, desde el nivel 2 sí", not Terreno3D.cabe(forma, 0, 1) and Terreno3D.cabe(forma, 2, 2))
	var libre: Array = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(4, 2), Vector2i(5, 2)]
	_ok("5 forma 2×2 libre de alto 3 cabe", Terreno3D.cabe(libre, 0, 3))
	Terreno3D.fijar_altura(Vector2i(5, 2), 1)
	_ok("5 si una de sus casillas sube un nivel, alto 3 desde 0 ya no cabe pero desde 1 sí", not Terreno3D.cabe(libre, 0, 3) and Terreno3D.cabe(libre, 1, 3))
	Terreno3D.fijar_altura(Vector2i(5, 2), 0)
	_ok("5 al quitar la cornisa vuelve a caber", Terreno3D.cabe(libre, 0, 3))
	# Entradas inválidas
	_ok("6 forma vacía: no cabe", not Terreno3D.cabe([], 0, 1))
	_ok("6 alto 0: no cabe", not Terreno3D.cabe(libre, 0, 0))
	# Coherencia con celda_solida (la respuesta que ya usan los hechizos)
	var coincide: bool = true
	for y in range(-1, 9):
		for x in range(-1, 9):
			for n in range(0, 3):
				if Terreno3D.ocupado(Vector2i(x, y), n) != Terreno3D.celda_solida(Vector2i(x, y), n):
					coincide = false
	_ok("7 ocupado = celda_solida en todo el mapa y alrededores", coincide)
	Terreno3D.fijar_altura(cor, 0)


func _tiempo() -> void:
	# Mapa abierto de 40×40: se mide cabe() sobre todas sus casillas (el peor caso: nada lo corta antes) con alto 3.
	var filas := PackedStringArray()
	for y in range(40):
		filas.append(".".repeat(40))
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, {})
	Terreno3D.activar_fuente_casillas()
	var celdas: Array = []
	for y in range(40):
		for x in range(40):
			celdas.append(Vector2i(x, y))
	var t0: int = Time.get_ticks_usec()
	var cabe: bool = Terreno3D.cabe(celdas, 0, 3)
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	_ok("8 el mapa abierto de 40×40 cabe entero (1600 casillas × 3 alturas)", cabe)
	print("AVISO cabe() sobre 40×40 casillas × 3 alturas: %.2f ms" % ms)
