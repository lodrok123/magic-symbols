extends SceneTree
## Hoja de contacto de GLB sueltos (necesita ventana).
##   godot --path . --script res://herramientas/hoja_glbs.gd -- <salida.png> <glb> <glb> ...
## Cada objeto se centra en su AABB y se escala a un cubo comun; se numera por el orden dado.
func _initialize() -> void:
	_correr()

func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	var salida: String = a[0]
	var glbs: Array = a.slice(1)
	var vp := Window.new()
	var n: int = glbs.size()
	var cols: int = mini(n, 4)
	var filas: int = ceili(float(n) / cols)
	var celda: int = 320
	root.size = Vector2i(cols * celda, filas * celda)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.36, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.85)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	root.add_child(luz)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(filas) * 1.0
	root.add_child(cam)
	cam.position = Vector3(0, 0, 10)
	for i in n:
		var st := GLTFState.new()
		var doc := GLTFDocument.new()
		if doc.append_from_file(glbs[i], st) != OK:
			print("FALLO carga ", glbs[i])
			continue
		var nodo: Node = doc.generate_scene(st)
		var mi: Array = nodo.find_children("*", "MeshInstance3D", true, false)
		var aabb := AABB()
		for m in mi:
			var b: AABB = (m as MeshInstance3D).get_aabb()
			aabb = b if aabb.size == Vector3.ZERO else aabb.merge(b)
		var k: float = 0.8 / maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		var piv := Node3D.new()
		root.add_child(piv)
		piv.add_child(nodo)
		nodo.position = -aabb.get_center()
		piv.scale = Vector3.ONE * k
		piv.rotation_degrees = Vector3(20.0, -30.0, 0.0)
		var c: int = i % cols
		var f: int = i / cols
		piv.position = Vector3((c - (cols - 1) * 0.5) * 1.0 * (float(filas) / filas), ((filas - 1) * 0.5 - f) * 1.0, 0)
		var et := Label3D.new()
		et.text = str(i)
		et.font_size = 96
		et.pixel_size = 0.004
		et.modulate = Color(1, 1, 0.3)
		et.no_depth_test = true
		root.add_child(et)
		et.position = piv.position + Vector3(-0.4, 0.4, 1)
	# camara: ancho = cols unidades
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = float(cols)
	for _i in 6:
		await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(salida)
	print("guardado ", salida, " ", img.get_size())
	quit()
