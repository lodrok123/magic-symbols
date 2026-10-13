extends SceneTree
## DatosTest2 (L2.1, 13/10): las cinco constantes que lee la maqueta del Test 2, sin cargar el nivel 2D. Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_datos_test2.gd

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _init() -> void:
	var mapa: PackedStringArray = DatosTest2.MAPA_TEST2
	var cuadrado: bool = true
	for fila in mapa:
		cuadrado = cuadrado and fila.length() == 40
	_ok("1 MAPA_TEST2 tiene 40 filas", mapa.size() == 40, "%d" % mapa.size())
	_ok("1 y todas de 40 columnas", cuadrado)
	_ok("1 bordes de muro (primera y última fila)", mapa[0] == "#".repeat(40) and mapa[39] == "#".repeat(40))
	var camaras: Array = ["fuego", "agua", "tierra", "viento", "rayo", "hielo"]
	var todas: bool = true
	for c in camaras:
		todas = todas and DatosTest2.ROTULOS.has(c) and DatosTest2.COLOR_PRUEBA.has(c)
	_ok("2 ROTULOS y COLOR_PRUEBA traen las seis cámaras", todas and DatosTest2.ROTULOS.size() == 6 and DatosTest2.COLOR_PRUEBA.size() == 6)
	var dentro: bool = true
	for c in camaras:
		var r: Vector2i = DatosTest2.ROTULOS[c]
		dentro = dentro and r.x >= 0 and r.y >= 0 and r.x < 40 and r.y < 40
	_ok("2 los rótulos caen dentro del mapa", dentro)
	_ok("3 GUARDADOS_T2: 4 celdas dentro del mapa", DatosTest2.GUARDADOS_T2.size() == 4 and _en_mapa(DatosTest2.GUARDADOS_T2))
	var suelo_ok: bool = DatosTest2.SUELO_T2.size() == 11
	for e in DatosTest2.SUELO_T2:
		suelo_ok = suelo_ok and (e as Array).size() == 4 and ["oro", "pocion"].has(e[0]) and int(e[1]) < 40 and int(e[2]) < 40
	_ok("3 SUELO_T2: 11 objetos [tipo, x, y, cantidad]", suelo_ok)
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _en_mapa(celdas: Array) -> bool:
	for c in celdas:
		var v: Vector2i = c
		if v.x < 0 or v.y < 0 or v.x >= 40 or v.y >= 40:
			return false
	return true
