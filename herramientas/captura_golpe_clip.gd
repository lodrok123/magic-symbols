extends "res://herramientas/escenario_base.gd"
## C1: hoja de contactos del clip `cast_empuje` de la jugadora (MageSoellCast001) cada 0,2 s, para elegir el tramo del golpe cuerpo a cuerpo. NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_golpe_clip.gd -- [carpeta]

var _dir: String = "res://docs/capturas/golpe"
var _rol: String = "cast_empuje"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1:
		_rol = a[1]
	Flags.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).position = Vector3(-500.0, 0.0, -500.0)
	maqueta.set("_tam_camara", 3.2)
	(maqueta.get("_camara") as Camera3D).size = 3.2
	await avanzar_s(1.5)
	jugador.set("_mirada", Vector3(1, 0, 0))
	var pj: Pj3D = jugador.pj
	pj.mirar(Vector3(1, 0, 0), 1.0)
	var largo: float = pj.duracion(_rol)
	var fotos: Array = []
	var t: float = 0.0
	while t < largo:
		pj.animacion_actual = ""
		pj.pose_fija(_rol, t)
		await avanzar(4)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_viewport().get_texture().get_image()
		var c: Vector2 = lanzador.camara.unproject_position(jugador.position + Vector3(0.6, 0.5, 0.0))
		var w: int = 300
		var h: int = 300
		var x0: int = clampi(int(c.x) - w / 2, 0, img.get_width() - w)
		var y0: int = clampi(int(c.y) - h / 2, 0, img.get_height() - h)
		fotos.append(img.get_region(Rect2i(x0, y0, w, h)))
		t += 0.2
	var cols: int = 6
	var filas: int = int(ceil(float(fotos.size()) / float(cols)))
	var hoja: Image = Image.create(300 * cols, 300 * filas, false, (fotos[0] as Image).get_format())
	for i in range(fotos.size()):
		hoja.blit_rect(fotos[i], Rect2i(0, 0, 300, 300), Vector2i((i % cols) * 300, (i / cols) * 300))
	hoja.save_png(_dir.path_join("hoja_clip_" + _rol + ".png"))
	print("hoja de %d fotogramas, clip de %.2f s" % [fotos.size(), largo])


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
