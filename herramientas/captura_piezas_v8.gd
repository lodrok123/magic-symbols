extends SceneTree
## V8 (21/10): comparacion visual de piezas decimadas (12 k vs 6 k vs 2,5 k). NECESITA VENTANA.
##   godot --path . --script res://herramientas/captura_piezas_v8.gd -- <carpeta>
## Carga cada .glb desde arte/meshy/piezas/_anteriores_v8 (12 k) y arte/meshy/aprobacion3d/v8_piezas (6 k, 2,5 k), los pone a la medida del juego
## (Pieza3D._normalizar) en fila y captura con camara ortogonal inclinada 60 grados: zoom 6 (ZOOM_INICIAL), zoom 2 (ZOOM_MINIMO) y zoom 0,9 (lupa).
const PIEZAS: Array = ["roca_musgosa", "tronco_musgoso", "troncos_apilados"]
const NIVELES: Dictionary = {"roca_musgosa": ["12k", "6k", "2k5"], "tronco_musgoso": ["12k", "6k"], "troncos_apilados": ["12k", "6k"]}
const INCL: float = 60.0


func _initialize() -> void:
	_correr()


func _ruta(id: String, n: String) -> String:
	var base: String = ProjectSettings.globalize_path("res://arte/meshy/")
	match n:
		"12k": return base + "piezas/_anteriores_v8/%s.glb" % id
		"6k": return base + "aprobacion3d/v8_piezas/%s_6000.glb" % id
		_: return base + "aprobacion3d/v8_piezas/%s_2500.glb" % id


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	var carpeta: String = a[0] if a.size() > 0 else "docs/capturas/v8/piezas_6k"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	luz.shadow_enabled = true
	root.add_child(luz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.62, 0.35)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.85)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60.0, 60.0)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.42, 0.62, 0.28)
	pm.material = sm
	suelo.mesh = pm
	root.add_child(suelo)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(cam)
	for id in PIEZAS:
		var fila := Node3D.new()
		root.add_child(fila)
		var niv: Array = NIVELES[id]
		for i in niv.size():
			var st := GLTFState.new()
			var doc := GLTFDocument.new()
			var err: int = doc.append_from_file(_ruta(id, niv[i]), st)
			if err != OK:
				print("FALLO carga ", id, " ", niv[i], " ", err)
				continue
			var n: Node3D = doc.generate_scene(st) as Node3D
			n = Pieza3D._normalizar(n, id)
			fila.add_child(n)
			n.position = Vector3((float(i) - (niv.size() - 1) * 0.5) * 1.2, 0.0, 0.0)
			n.rotation.y = deg_to_rad(-25.0)
		for _i in 8:
			await process_frame
		var e: float = deg_to_rad(90.0 - INCL)
		var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
		var vistas: Array = [["zoom6", 6.0, -1], ["zoom2", 2.0, -1]]
		for i in niv.size():
			vistas.append(["lupa_" + String(niv[i]), 1.1 if id == "roca_musgosa" else 1.8, i])
		for v in vistas:
			cam.size = float(v[1])
			var cx: float = 0.0 if int(v[2]) < 0 else (float(v[2]) - (niv.size() - 1) * 0.5) * 1.2
			cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3(cx, 0.2, 0.0) - dir * 40.0)
			for _i in 10:
				await process_frame
			var img: Image = root.get_viewport().get_texture().get_image()
			var ruta: String = "%s/%s_%s.png" % [carpeta, id, v[0]]
			img.save_png(ruta)
			print("CAPTURA ", ruta, " ", img.get_width(), "x", img.get_height())
		fila.queue_free()
		for _i in 3:
			await process_frame
	quit()

