extends SceneTree
## Hoja de las pociones de la alquimia (diario 353) junto a la jugadora, a la escala del juego (jugadora_base mide 1,0). NECESITA VENTANA.
##   godot --path . --script res://herramientas/captura_pociones_alquimia.gd -- <salida.png>
## Dibuja, de izquierda a derecha: la jugadora, `pocion` (la del botin y la maqueta), `pocion_grande` y las cuatro pocion_alq_0..3 (por su id de modelo).

func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	var salida: String = a[0] if a.size() > 0 else "docs/capturas/pociones_alquimia/hoja_pociones.png"
	root.size = Vector2i(1400, 700)
	var raiz := Node3D.new()
	root.add_child(raiz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.81, 0.91, 0.94)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 0.9)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 35, 0)
	sol.light_energy = 1.1
	raiz.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.55, 0.72, 0.4)
	pm.material = sm
	suelo.mesh = pm
	raiz.add_child(suelo)
	var cam := Camera3D.new()
	cam.fov = 30.0
	raiz.add_child(cam)
	cam.current = true
	var pj := Pj3D.new()
	raiz.add_child(pj)
	pj.cargar("jugadora_base")
	pj.set_alto(1.0)
	pj.position = Vector3(-1.8, 0, 0)
	var ids: Array = ["pocion", "pocion_grande", "pocion_alq_0", "pocion_alq_1", "pocion_alq_2", "pocion_alq_3"]
	var x: float = -1.0
	for id in ids:
		var v: Node3D = Pieza3D.crear_visual(String(id))
		if v == null:
			print("FALLO sin modelo ", id)
			continue
		v.position = Vector3(x, 0, 0)
		raiz.add_child(v)
		var et := Label3D.new()
		et.text = String(id)
		et.font_size = 18
		et.pixel_size = 0.0035
		et.modulate = Color(0.1, 0.1, 0.15)
		et.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		raiz.add_child(et)
		et.no_depth_test = true
		et.position = Vector3(x, -0.07, 0.3)
		x += 0.58
	cam.transform = Transform3D(Basis.looking_at(Vector3(0.0, -0.1, -1.0), Vector3.UP), Vector3(0.2, 0.6, 5.3))
	for i in 12:
		await process_frame
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(salida.get_base_dir())
	img.save_png(salida)
	print("guardado ", salida, " ", img.get_size())
	quit(0)


