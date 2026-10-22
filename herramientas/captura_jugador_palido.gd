extends "res://herramientas/captura_cauce_hondo.gd"
## DIAGNÓSTICO «jugadora pálida en el fondo del cauce» (22/10). NECESITA VENTANA y Godot CERRADO.
##   godot --path . --script res://herramientas/captura_jugador_palido.gd -- <carpeta>   (por defecto res://docs/capturas/jugador_palido)
## Reproduce la toma entra_4 de captura_cauce_hondo.gd (anda de verdad hasta el fondo del cauce, al sur del tronco, cámara del juego) y hace la MISMA
## foto apagando una cosa cada vez. Guarda también recortes ampliados x3 de la jugadora y una tabla de color medio sobre su silueta.

var _dir: String = "res://docs/capturas/jugador_palido"
var _pjj: Pj3D = null


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await cargar("res://escenas/PruebaBosque01.tscn", true)
	if maqueta == null or jugador == null:
		return
	_m = maqueta as Node3D
	_pjj = jugador.get("pj") as Pj3D
	_ocultar_ui(root)
	await avanzar(60)
	_pj = _m.get("_jugador")
	_suelta_camara()
	var S: float = Terreno3D.casilla
	colocar_jugador(Vector2i(14, 13))
	await avanzar(40)
	_w = await _empuje(KEY_W)
	_d = await _empuje(KEY_D)
	await avanzar(30)
	await _caminar(Vector2i(16, 13), [], 10.0)
	var sil: ShaderMaterial = _pjj.get("_sil_mat")
	var rim: ShaderMaterial = _pjj.get("_rim_mat")
	var sil_c: Color = Pj3D.SILUETA_COLOR
	var rim_i: float = float(_pjj.call("_intensidad_rim"))
	var rad: float = float(_m.get("radio_transparencia"))
	var cam: Camera3D = _m.get("_camara") as Camera3D
	var attr: CameraAttributes = cam.attributes
	var tilt: Node = _m.get("_tilt")
	var gatillo := func() -> bool: return jugador.position.z / S >= 15.3
	var llego: bool = false
	var inicio: float = reloj.t
	while reloj.t - inicio < 12.0 and not llego:
		var av: Vector2 = Vector2(37.9, 19.0 * S) - Vector2(jugador.position.x, jugador.position.z)
		_tecla(KEY_W, av.dot(_w) > 0.1)
		_tecla(KEY_S, av.dot(_w) < -0.1)
		await process_frame
		llego = gatillo.call()
	root.get_tree().paused = true         # el mundo congelado: todas las fotos son el MISMO fotograma
	var sm: ShaderMaterial = _pjj.get("_juguete")[0][1]
	var ctl: StandardMaterial3D = _pjj.get("_juguete")[0][0]
	var mi: MeshInstance3D = null
	for n in _pjj.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).get_surface_override_material(0) == sm:
			mi = n as MeshInstance3D
	rim = _pjj.get("_rim_mat")
	print("RIM parámetros: pot %s int %s color %s" % [str(rim.get_shader_parameter("potencia")), str(rim.get_shader_parameter("intensidad")), str(rim.get_shader_parameter("color"))])
	var cas: Array = [["k0_base", 3.0, 0.5], ["k1_pot8", 8.0, 0.5], ["k2_int0", 3.0, 0.0], ["k3_int2", 3.0, 2.0], ["k4_pot0_5_int1", 0.5, 1.0]]
	for cs in cas:
		rim.set_shader_parameter("potencia", cs[1])
		rim.set_shader_parameter("intensidad", cs[2])
		await avanzar(4)
		await _foto(cs[0])
	root.get_tree().paused = false
	print("FOTOS en %s" % _dir)

## Color medio de dos parches del cuerpo (capa y gorro) en el fotograma actual.
func _parches() -> String:
	var img: Image = root.get_viewport().get_texture().get_image()
	var cam: Camera3D = _m.get("_camara") as Camera3D
	var s: String = ""
	for h in [0.45, 0.95]:
		var p: Vector2 = cam.unproject_position(jugador.position + Vector3(0, h, 0))
		var acc := Color(0, 0, 0)
		var n: int = 0
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				acc += img.get_pixel(int(p.x) + dx, int(p.y) + dy)
				n += 1
		acc = acc / float(n)
		s += "(%.2f %.2f %.2f) " % [acc.r, acc.g, acc.b]
	return s

func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_dir, nombre])
	var cam: Camera3D = _m.get("_camara") as Camera3D
	var p: Vector2 = cam.unproject_position(jugador.position + Vector3(0, 0.6, 0))
	var r := Rect2i(int(p.x) - 70, int(p.y) - 70, 140, 140).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var rec: Image = img.get_region(r)
	rec.resize(rec.get_width() * 3, rec.get_height() * 3, Image.INTERPOLATE_NEAREST)
	rec.save_png("%s/%s_recorte.png" % [_dir, nombre])
	print("FOTO %s jugadora en pantalla (%d, %d)" % [nombre, int(p.x), int(p.y)])













