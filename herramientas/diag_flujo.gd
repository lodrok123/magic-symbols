extends SceneTree
func _initialize() -> void:
	var filas: Array = []
	for l in FileAccess.get_file_as_string("res://mundo/datos_nivel/mapas/Bosque.txt").split("\n"):
		if not l.begins_with(";") and l.strip_edges() != "": filas.append(l)
	var lado := 49
	var es_rio := func(c: Vector2i) -> bool: return c.y < filas.size() and c.x < filas[c.y].length() and filas[c.y][c.x] in "~b"
	var ysur := 0
	for y in filas.size():
		for x in filas[y].length():
			if es_rio.call(Vector2i(x, y)): ysur = y
	var f := AguaRender3D.flujo_hacia_salidas(lado, es_rio, func(c: Vector2i) -> bool: return c.y == ysur)
	for c in [Vector2i(1,29), Vector2i(5,29), Vector2i(7,29), Vector2i(7,30), Vector2i(7,35), Vector2i(7,46), Vector2i(7,47)]:
		print(c, " -> ", f.get(c, "sin flujo"))
	print("casillas con flujo: ", f.size())
	quit()
