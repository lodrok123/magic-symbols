extends SceneTree
## CAPTURAS ANTES / DESPUÉS del «material de juguete» (docs/PLAN_EOW_VISUAL.md §1 punto 5). NECESITA VENTANA.
##   godot --path . --script res://herramientas/captura_personaje_juguete.gd -- <bosque|neutra> <antes|despues> <carpeta>
## «antes» = Pj3D.material_juguete = false (el StandardMaterial3D PBR de V5). «despues» = de serie.
## bosque: PruebaBosque01 (jugadora y goblin más cercano, general y goblin quemado/congelado). neutra: suelo liso + sol, jugadora, librera y goblin en fila.
## Mide el tiempo de fotograma (120 fotogramas sin vsync) en la vista general.

const ESCENA_BOSQUE: String = "res://escenas/PruebaBosque01.tscn"


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("uso: -- <bosque|neutra> <antes|despues> <carpeta>")
		quit(2)
		return
	var cual: String = a[0]
	var antes: bool = a[1] == "antes"
	var carpeta: String = a[2]
	Pj3D.material_juguete = not antes
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(carpeta)
	if cual == "neutra":
		await _neutra(a[1], carpeta)
	else:
		await _bosque(a[1], carpeta)
	quit()


func _neutra(etq: String, carpeta: String) -> void:
	var raiz := Node3D.new()
	root.add_child(raiz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.81, 0.91, 0.94)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.82, 0.9)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 35, 0)
	sol.light_energy = 1.1
	sol.shadow_enabled = true
	raiz.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(30, 30)
	suelo.mesh = pl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.55, 0.68, 0.45)
	sm.roughness = 1.0
	suelo.material_override = sm
	raiz.add_child(suelo)
	var ids: Array = ["woodland_wanderer", "bookseller_chibi", "goblin_warrior_chibi"]
	var pjs: Array = []
	for i in range(ids.size()):
		var p := Pj3D.new()
		p.position = Vector3((i - 1) * 1.7, 0, 0)
		raiz.add_child(p)
		p.cargar(ids[i])
		p.set_alto(1.2 if i < 2 else 0.9)
		p.rotation.y = deg_to_rad(-20)
		pjs.append(p)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	raiz.add_child(cam)
	cam.current = true
	var dir: Vector3 = -Vector3(0.0, sin(deg_to_rad(40.0)), cos(deg_to_rad(40.0)))
	for _i in 30:
		await process_frame
	var vistas: Array = [["general", Vector3(0, 0.6, 0), 6.0], ["jugadora", (pjs[0] as Node3D).position + Vector3(0, 0.6, 0), 2.4],
		["npc", (pjs[1] as Node3D).position + Vector3(0, 0.6, 0), 2.4], ["goblin", (pjs[2] as Node3D).position + Vector3(0, 0.4, 0), 2.0]]
	for v in vistas:
		cam.size = v[2]
		cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), (v[1] as Vector3) - dir * 20.0)
		await _foto("neutra", v[0], etq, carpeta, v[0] == "general")


func _bosque(etq: String, carpeta: String) -> void:
	var m: Node3D = (load(ESCENA_BOSQUE) as PackedScene).instantiate()
	root.add_child(m)
	for _i in 150:
		await process_frame
	_ocultar_ui(root)
	var cam: Camera3D = m.get("_camara")
	var jug: Pj3D = m.get("_jugador")
	var tam0: float = cam.size
	var pos_jug: Vector3 = jug.position
	await _vista(m, "general", etq, pos_jug, tam0, true)
	await _vista(m, "jugadora", etq, pos_jug + Vector3(0, 0.6, 0), 3.0, false)
	var gob: Combate3D = null
	var mejor: float = 1.0e9
	for n in get_nodes_in_group("goblins"):
		if n is Combate3D and not (n as Combate3D).muerto and String((n as Combate3D).pj.id).begins_with("goblin"):
			var d: float = (n as Node3D).global_position.distance_to(pos_jug)
			if d < mejor:
				mejor = d
				gob = n
	if gob == null:
		print("sin goblins vivos")
		return
	gob.set_physics_process(false)
	await _vista(m, "goblin", etq, gob.global_position + Vector3(0, 0.5, 0), 2.4, false)
	gob.quemando = 1000.0
	gob._dibujar_estado(0.016)    # con la física parada nadie lo llama: se escribe el tinte a mano (como haría Combate3D)
	await process_frame
	await _vista(m, "goblin_quemado", etq, gob.global_position + Vector3(0, 0.5, 0), 2.4, false)
	gob.quemando = 0.0
	gob.congelado = 1000.0
	gob._dibujar_estado(0.016)
	await process_frame
	await _vista(m, "goblin_congelado", etq, gob.global_position + Vector3(0, 0.5, 0), 2.4, false)


func _vista(m: Node3D, nombre: String, etq: String, foco: Vector3, tam: float, medir: bool) -> void:
	m.set("_jugador", null)
	m.set("_foco", foco)
	m.set("_tam_camara", tam)
	(m.get("_camara") as Camera3D).size = tam
	m.call("_colocar_camara")
	await _foto("bosque", nombre, etq, "", medir, m)


func _foto(cual: String, nombre: String, etq: String, carpeta: String, medir: bool, _m: Node = null) -> void:
	for _i in 40:
		await process_frame
	if medir:
		var t0: int = Time.get_ticks_usec()
		for _i in 120:
			await process_frame
		var ms: float = float(Time.get_ticks_usec() - t0) / 120000.0
		print("MEDIDA %s | %s | %s | fotograma %.2f ms (%.0f fps)" % [cual, nombre, etq, ms, 1000.0 / maxf(ms, 0.001)])
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%s_%s.png" % [_carpeta(), cual, nombre, etq])


func _carpeta() -> String:
	return OS.get_cmdline_user_args()[2]


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D) and h.name != "Vineta3D":
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
