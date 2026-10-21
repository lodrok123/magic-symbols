extends SceneTree
## CAPTURAS ANTES / DESPUÉS de V5 «personajes juguete» (docs/PLAN_EOW_VISUAL.md). NECESITA VENTANA (sin GPU no hay imagen ni silueta).
##   godot --path . --script res://herramientas/captura_personajes_v5.gd -- <lab|bosque> <antes|despues> <carpeta>
## «antes» = los interruptores de Pj3D apagados (sin rim, sin silueta, sin sombra de contacto, rugosidad 1,0): el personaje de antes de V5
## (el disco oscuro antiguo ya no existe en el código, así que «antes» no lo dibuja). «despues» = los valores de serie.
## Vistas: la jugadora de cerca, un goblin de cerca, la sala/el nivel y la jugadora DETRÁS de un árbol (en el lab, tras un tronco sintético si no hay árbol).
## Mide también el tiempo de fotograma (120 fotogramas sin vsync) en la vista general.
const S: float = 2.3
const ESCENAS: Dictionary = {
	"lab": "res://laboratorios/LabPlaytestEoW.tscn",
	"bosque": "res://escenas/PruebaBosque01.tscn",
}


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("uso: -- <lab|bosque> <antes|despues> <carpeta>")
		quit(2)
		return
	var cual: String = a[0]
	var antes: bool = a[1] == "antes"
	var carpeta: String = a[2]
	if antes:
		Pj3D.rim_activo = false
		Pj3D.silueta_activa = false
		Pj3D.sombra_contacto_activa = false
		Pj3D.pbr_juguete_activo = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var m: Node3D = (load(ESCENAS[cual]) as PackedScene).instantiate()
	root.add_child(m)
	for _i in 150:
		await process_frame
	_ocultar_ui(root)
	DirAccess.make_dir_recursive_absolute(carpeta)
	var etq: String = "antes" if antes else "despues"
	var cam: Camera3D = m.get("_camara")
	var jug: Pj3D = m.get("_jugador")
	var j3d: Node = m.get_node_or_null("Jugador3D")
	var tam0: float = cam.size
	var pos_jug: Vector3 = jug.position

	# 1 · general (con el tiempo de fotograma)
	await _vista(m, "general", etq, cual, carpeta, pos_jug, tam0 if cual == "bosque" else 10.0, true)
	# 2 · la jugadora de cerca
	await _vista(m, "jugadora", etq, cual, carpeta, pos_jug + Vector3(0, 0.6, 0), 3.6, false)
	# 3 · un goblin de cerca
	var gob: Node3D = null
	var mejor: float = 1.0e9
	for n in get_nodes_in_group("goblins"):
		if n is Combate3D and not (n as Combate3D).muerto:
			var d: float = (n as Node3D).global_position.distance_to(pos_jug)
			if d < mejor:
				mejor = d
				gob = n
	if gob != null:
		await _vista(m, "goblin", etq, cual, carpeta, gob.global_position + Vector3(0, 0.5, 0), 3.6, false)
	else:
		print("sin goblins vivos en esta escena")
	# 4 · la jugadora detrás de un árbol (o de un tronco sintético)
	var h: Vector3 = cam.global_basis.z
	h.y = 0.0
	h = h.normalized()
	var arbol: Node3D = _arbol_cercano(m, pos_jug)
	var donde: Vector3 = pos_jug
	var que: String = "tronco_sintetico"
	if arbol != null:
		donde = arbol.global_position - h * 0.8
		que = String(arbol.name)
	else:
		var tronco := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.45
		cil.bottom_radius = 0.5
		cil.height = 4.0
		tronco.mesh = cil
		m.add_child(tronco)
		tronco.global_position = pos_jug + h * 0.8 + Vector3(0, 2.0, 0)
	donde.y = pos_jug.y if arbol == null else pos_jug.y
	if j3d != null:
		j3d.set_physics_process(false)
		j3d.set("position", donde)
	jug.position = donde
	print("silueta: tras ", que)
	await _vista(m, "silueta", etq, cual, carpeta, donde + Vector3(0, 0.6, 0), 4.5, false)
	quit()


func _arbol_cercano(n: Node, cerca_de: Vector3) -> Node3D:
	var mejor: Node3D = null
	var dm: float = 1.0e9
	# El decorado va en lotes (MultiMesh por pieza): un «árbol» es una instancia alta de un MultiMesh. Se devuelve un Node3D auxiliar en su sitio.
	for h in n.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi: MultiMeshInstance3D = h as MultiMeshInstance3D
		if mmi.multimesh == null or mmi.multimesh.mesh == null or mmi.multimesh.mesh.get_aabb().size.y < 2.0:
			continue
		for i in range(mmi.multimesh.instance_count):
			var p: Vector3 = (mmi.global_transform * mmi.multimesh.get_instance_transform(i)).origin
			var d: float = p.distance_to(cerca_de)
			if d < dm and d > 2.0:
				dm = d
				var aux := Node3D.new()
				aux.name = "arbol_multimesh_" + String(mmi.name)
				mejor = aux
				n.add_child(aux)
				aux.global_position = p
	if mejor != null:
		return mejor
	for h in n.find_children("*", "Node3D", true, false):
		var nombre: String = String(h.name).to_lower()
		if (nombre.begins_with("arbol") or nombre.begins_with("pino") or nombre.begins_with("abedul")):
			var d: float = (h as Node3D).global_position.distance_to(cerca_de)
			if d < dm and d > 1.0:
				dm = d
				mejor = h
	return mejor


func _vista(m: Node3D, nombre: String, etq: String, cual: String, carpeta: String, foco: Vector3, tam: float, medir: bool) -> void:
	m.set("_jugador", null)
	m.set("_foco", foco)
	m.set("_tam_camara", tam)
	(m.get("_camara") as Camera3D).size = tam
	m.call("_colocar_camara")
	for _i in 40:
		await process_frame
	if medir:
		var t0: int = Time.get_ticks_usec()
		for _i in 120:
			await process_frame
		var ms: float = float(Time.get_ticks_usec() - t0) / 120000.0
		print("MEDIDA %s | %s | %s | fotograma %.2f ms (%.0f fps)" % [cual, nombre, etq, ms, 1000.0 / maxf(ms, 0.001)])
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%s_%s.png" % [carpeta, cual, nombre, etq])


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D) and h.name != "Vineta3D":
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
