extends SceneTree
## Capturas del Bosque para comparar antes/después (Fase 14.2). Uso: --script ... -- <prefijo>
## Vistas: «general» (zoom por defecto, junto al jugador), «rio» (el río del sur, de cerca), «cauce» (las ruinas con el cauce seco).
func _initialize() -> void:
	var prefijo: String = "/tmp/cap_x"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		prefijo = args[0]
	var ajuste: Array = []      # opcional: brillo contraste saturación para probar el ajuste de color sin recompilar
	if args.size() >= 4:
		ajuste = [float(args[1]), float(args[2]), float(args[3])]
	var solo: String = args[4] if args.size() >= 5 else ""
	var esc: PackedScene = load("res://escenas/PruebaBosque.tscn")
	var m: Node3D = esc.instantiate()
	root.add_child(m)
	for _i in 90:
		await process_frame
	var S: float = 2.3
	_ocultar_ui(root)
	if not ajuste.is_empty():
		for h in m.get_children():
			if h is WorldEnvironment:
				var e: Environment = (h as WorldEnvironment).environment
				e.adjustment_enabled = true
				e.adjustment_brightness = ajuste[0]
				e.adjustment_contrast = ajuste[1]
				e.adjustment_saturation = ajuste[2]
	var vistas := {
		"general": [null, 16.0],
		"rio": [Vector3(7.5 * S, 0.5, 33.0 * S), 12.0],
		"cauce": [Vector3(2.5 * S, 0.5, 27.0 * S), 12.0],
		"orilla": [Vector3(6.5 * S, 0.5, 30.5 * S), 6.0],
	}
	for k in vistas.keys():
		if solo != "" and k != solo:
			continue
		var v: Array = vistas[k]
		if v[0] != null:
			m.set("_jugador", null)
			m.set("_foco", v[0])
		m.set("_tam_camara", v[1])
		m.get("_camara").size = v[1]
		m.call("_colocar_camara")
		for _i in 20:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [prefijo, k])
	quit()

func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
