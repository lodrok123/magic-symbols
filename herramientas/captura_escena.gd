extends SceneTree
## Captura una escena de la maqueta mirando a una casilla. Uso: -- <prefijo> <escena.tscn> <casilla_x> <casilla_y> <tam_camara> [frames]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefijo: String = args[0]
	var esc: PackedScene = load(args[1])
	var m: Node3D = esc.instantiate()
	root.add_child(m)
	var frames: int = int(args[5]) if args.size() > 5 else 90
	for _i in frames:
		await process_frame
	_ocultar_ui(root)
	var S: float = 2.3
	m.set("_jugador", null)
	m.set("_foco", Vector3((float(args[2]) + 0.5) * S, 0.5, (float(args[3]) + 0.5) * S))
	m.set("_tam_camara", float(args[4]))
	m.get("_camara").size = float(args[4])
	m.call("_colocar_camara")
	for _i in 25:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(prefijo + ".png")
	quit()
func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
