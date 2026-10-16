extends SceneTree

## PRUEBA DE LA BOLSA (Fase 14.3, 16/10, Juego): los DATOS de la mochila-bolsa, sin ventana. `tools\prueba_una.cmd prueba_bolsa`.
## Anclas dentro de la silueta, orden por categoría, contadores, corazón en lo que cura, nombre del elegido y navegación con el teclado.

var fallos: int = 0


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK  ", msg)
	else:
		fallos += 1
		print("  FALLO  ", msg)


func _init() -> void:
	print("== Geometría")
	var anc: PackedVector2Array = BolsaUI.anclas()
	_ok(anc.size() == Estado.CAPACIDAD_MAX, "hay un ancla por hueco posible (%d)" % anc.size())
	var sil: PackedVector2Array = BolsaUI.silueta()
	var fuera: int = 0
	var r: float = BolsaUI.TAM_BOLSA * 0.5
	for a in anc:
		for k in range(16):
			var p: Vector2 = a + Vector2(cos(TAU * float(k) / 16.0), sin(TAU * float(k) / 16.0)) * r
			if not Geometry2D.is_point_in_polygon(p, sil):
				fuera += 1
	_ok(fuera == 0, "los 20 huecos caben enteros dentro de la silueta (%d puntos fuera)" % fuera)
	var solapan: int = 0
	for i in range(anc.size()):
		for j in range(i + 1, anc.size()):
			if absf(anc[i].x - anc[j].x) < BolsaUI.TAM_BOLSA and absf(anc[i].y - anc[j].y) < BolsaUI.TAM_BOLSA:
				solapan += 1
	_ok(solapan == 0, "ningún hueco se pisa con otro")
	var filas: Dictionary = {}
	for a in anc:
		filas[snappedf(a.y, 0.1)] = int(filas.get(snappedf(a.y, 0.1), 0)) + 1
	var cuentas: Array = []
	for y in filas.keys():
		cuentas.append(filas[y])
	_ok(cuentas == [2, 3, 4, 5, 6], "las filas se ensanchan del cuello a la panza: %s" % str(cuentas))
	var ancho_top: float = 0.0
	var ancho_bajo: float = 0.0
	for p in sil:
		if p.y < 30.0:
			ancho_top = maxf(ancho_top, absf(p.x - BolsaUI.BOLSA_ANCHO * 0.5))
		if p.y > 320.0 and p.y < 360.0:
			ancho_bajo = maxf(ancho_bajo, absf(p.x - BolsaUI.BOLSA_ANCHO * 0.5))
	_ok(ancho_top < 0.4 * ancho_bajo, "el cuello es mucho más estrecho que la panza (%.0f contra %.0f)" % [ancho_top, ancho_bajo])
	for a in anc:
		if a.x < 0.0 or a.x > BolsaUI.BOLSA_ANCHO or a.y < 0.0 or a.y > BolsaUI.BOLSA_ALTO:
			fallos += 1
			print("  FALLO  ancla fuera del control: ", a)

	print("== Orden por categoría")
	var items: Dictionary = {"pocion": 12, "seta": 2, "lavanda": 1, "llave": 1, "baya": 3, "helecho": 1}
	var pilas: Array = BolsaUI.ordenar(items)
	var ids: Array = []
	for p in pilas:
		ids.append(p[0])
	_ok(ids == ["baya", "helecho", "lavanda", "seta", "pocion", "pocion", "llave"], "componentes por nombre, luego pociones, al final la llave: %s" % str(ids))
	_ok(pilas[4][1] == 9 and pilas[5][1] == 3, "12 pociones son una pila de 9 y otra de 3")
	_ok(Objetos.categoria("pocion") == "pociones" and Objetos.categoria("llave") == "clave" and Objetos.categoria("seta") == "componentes", "categorías de Objetos")
	_ok(Objetos.cura("pocion") and not Objetos.cura("seta"), "solo la poción cura")
	_ok(BolsaUI.ordenar({}).is_empty(), "una mochila vacía no da pilas")

	print("== Navegación con el teclado")
	var todos: Array = []
	todos.resize(20)
	todos.fill(true)
	_ok(BolsaUI.vecino(0, Vector2.DOWN, todos) in [2, 3], "desde el primer hueco, abajo cae en la fila de 3")
	_ok(BolsaUI.vecino(0, Vector2.RIGHT, todos) == 1, "a la derecha del primero está el segundo")
	_ok(BolsaUI.vecino(0, Vector2.UP, todos) == -1 and BolsaUI.vecino(0, Vector2.LEFT, todos) == -1, "no hay nada arriba ni a la izquierda del primero")
	_ok(BolsaUI.vecino(19, Vector2.DOWN, todos) == -1, "tras el último de abajo no hay más")
	var alcanzados: Dictionary = {0: true}
	var pendientes: Array = [0]
	while not pendientes.is_empty():
		var a: int = pendientes.pop_back()
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var j: int = BolsaUI.vecino(a, d, todos)
			if j >= 0 and not alcanzados.has(j):
				alcanzados[j] = true
				pendientes.append(j)
	_ok(alcanzados.size() == 20, "con las flechas se llega a los 20 huecos (%d)" % alcanzados.size())
	var pocos: Array = []
	pocos.resize(20)
	pocos.fill(false)
	pocos[0] = true
	pocos[9] = true
	_ok(BolsaUI.vecino(0, Vector2.DOWN, pocos) == 9, "solo se salta entre huecos con objeto")
	_ok(BolsaUI.vecino(0, Vector2.UP, pocos) == -1, "y sin objeto en esa dirección no se mueve")

	print("== La bolsa por dentro (nodo)")
	Estado.nuevo()
	var e: Estado = Estado.i()
	e.capacidad = 8
	e.agregar("seta", 2)
	e.agregar("pocion", 3)
	e.agregar("lavanda", 1)
	var b := BolsaUI.new()
	root.add_child(b)
	await process_frame
	b.alternar()
	await process_frame
	_ok(b.abierta and paused, "abrir la bolsa pausa el mundo")
	_ok(b._huecos.size() == 20, "hay 20 huecos colocados")
	var bloqueados: int = 0
	for h in b._huecos:
		if (h as BolsaUI.Hueco).bloqueado:
			bloqueados += 1
	_ok(bloqueados == 12, "con capacidad 8, 12 huecos salen bloqueados (%d)" % bloqueados)
	var h0: BolsaUI.Hueco = b.hueco(0)
	var h1: BolsaUI.Hueco = b.hueco(1)
	var h2: BolsaUI.Hueco = b.hueco(2)
	_ok(h0.id == "lavanda" and h1.id == "seta" and h2.id == "pocion", "los objetos van en orden: lavanda, seta, poción (%s, %s, %s)" % [h0.id, h1.id, h2.id])
	_ok(h1.cantidad == 2 and h2.cantidad == 3 and h0.cantidad == 1, "cada hueco lleva su contador")
	_ok(h2.cura and not h0.cura and not h1.cura, "solo el hueco de la poción lleva corazón")
	_ok(h0.position.is_equal_approx(BolsaUI.anclas()[0] - Vector2(BolsaUI.TAM_BOLSA, BolsaUI.TAM_BOLSA) * 0.5), "el primer hueco está en su ancla")
	_ok(b.elegido() == 0 and h0.elegido, "al abrir queda elegido el primer objeto")
	_ok(b._info.text.begins_with("Lavanda"), "la banda bajo la bolsa dice el nombre: «%s»" % b._info.text.replace("\n", " / "))
	b.mover(Vector2.RIGHT)
	_ok(b.elegido() == 1 and b._info.text.begins_with("Seta"), "→ elige el siguiente y la banda cambia")
	b.mover(Vector2.DOWN)
	_ok(b.elegido() == 3 or b.elegido() == 2 or b.elegido() == 4 or b.elegido() == 1, "↓ no se sale de los objetos que hay (%d)" % b.elegido())
	b._elegir(2)
	_ok(b._info.text.begins_with("Poción de vida"), "la poción elegida se nombra")
	e.agregar("baya", 1)
	await process_frame
	_ok(b.hueco(0).id == "baya", "al llegar un objeto se recoloca por categoría (la baya pasa al primer hueco)")
	b.alternar()
	await process_frame
	_ok(not b.abierta and not paused, "cerrar la bolsa reanuda el mundo")
	b.queue_free()
	await process_frame
	print("FALLOS: ", fallos)
	quit(1 if fallos > 0 else 0)
