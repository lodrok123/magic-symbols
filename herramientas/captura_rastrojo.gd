extends SceneTree
## Captura del rastrojo en el Bosque (Fase 14.2 · P3). Uso: -- <prefijo>. Pone 4 casillas de hierba: 2 cortadas y 2 quemadas, y mira hacia ellas.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefijo: String = args[0] if args.size() > 0 else "/tmp/cap_rastrojo"
	var m: Node3D = (load("res://escenas/PruebaBosque.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for _i in 60:
		await process_frame
	var S: float = 2.3
	var lado: int = int(m.get("_lado"))
	var celdas: Array = []
	for y in lado:
		for x in lado:
			var c := Vector2i(x, y)
			if m._es_hierba(c) and m._es_hierba(c + Vector2i(1, 0)) and m._es_hierba(c + Vector2i(2, 0)) and m._es_hierba(c + Vector2i(3, 0)) and celdas.is_empty():
				celdas = [c, c + Vector2i(1, 0), c + Vector2i(2, 0), c + Vector2i(3, 0)]
	print("celdas ", celdas)
	m.marcar_segada(celdas[0], true)
	m.marcar_segada(celdas[1], true)
	m.call("_poner_quemado", celdas[2], 1.0)
	m.marcar_segada(celdas[2], true)
	m.call("_poner_quemado", celdas[3], 1.0)
	m.marcar_segada(celdas[3], true)
	for h in root.get_children():
		pass
	_ocultar_ui(root)
	m.set("_jugador", null)
	m.set("_foco", Vector3((float((celdas[1] as Vector2i).x) + 1.0) * S, 0.5, (float((celdas[0] as Vector2i).y) + 0.5) * S))
	m.set("_tam_camara", 7.0)
	m.get("_camara").size = 7.0
	m.call("_colocar_camara")
	for _i in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(prefijo + ".png")
	quit()
func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
