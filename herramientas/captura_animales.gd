extends SceneTree
## 4/11 · TIRAS DE FOTOGRAMAS de los animales (loberno y canouro) con la cámara del juego (ortogonal, inclinación 60°, el animal mira a la derecha de la pantalla).
## Con ventana (no --headless). Una tira de 8 fotogramas por clip repartidos en un ciclo, en dos filas de 4. Uso:
##   godot --path . --fixed-fps 30 --script res://herramientas/captura_animales.gd -- <carpeta> <prefijo> [marcha] [lateral]
##   `marcha`  = pone la capa MarchaCuadrupedo3D (si existe) y la velocidad que le toca al clip; sin él, el modelo tal cual estaba (antes).
##   `lateral` = cámara de perfil pura (inclinación 0°) en vez de la del juego.
## Clips: loberno → andar, correr y (con marcha) acecho; canouro → andar, correr (Gallop), zarpazo.

const TILE: Vector2i = Vector2i(400, 300)
const COLS: int = 4
const FILAS: int = 2
var _cam: Camera3D = null
var _carpeta: String = ""
var _prefijo: String = ""
var _marcha: bool = false
var _lateral: bool = false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_carpeta = a[0]
	_prefijo = a[1]
	_marcha = a.has("marcha")
	_lateral = a.has("lateral")
	DirAccess.make_dir_recursive_absolute(_carpeta)
	root.size = TILE
	var raiz := Node3D.new()
	root.add_child(raiz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.72, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 0.9)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55, 25, 0)
	sol.light_energy = 1.0
	raiz.add_child(sol)
	# Suelo con una raya cada 0,25 u para ver si los pies resbalan en una tira (cada fotograma es un instante distinto: se compara con la posición del pie respecto a las marcas).
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	suelo.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.6, 0.38)
	suelo.material_override = mat
	raiz.add_child(suelo)
	for i in range(-16, 17):
		var r := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.012, 0.002, 0.5)
		r.mesh = bm
		var m2 := StandardMaterial3D.new()
		m2.albedo_color = Color(0.2, 0.3, 0.2)
		r.material_override = m2
		r.position = Vector3(float(i) * 0.25, 0.002, 0.0)
		raiz.add_child(r)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 1.5
	raiz.add_child(_cam)
	_cam.current = true
	var e: float = deg_to_rad(0.0 if _lateral else 30.0)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	var foco := Vector3(0.0, 0.25, 0.0)
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 10.0)
	var casos: Array = []
	if _carpeta.contains("extra"):
		casos = [["loberno", 0.75, "clip:Walk_Alt"], ["loberno", 0.75, "clip:Creep"], ["loberno", 0.75, "clip:Run_Alt"], ["loberno", 0.75, "attack"]]
	else:
		casos = [
		["loberno", 0.75, "walk"], ["loberno", 0.75, "run"],
		["canouro", 0.55, "walk"], ["canouro", 0.55, "run"], ["canouro", 0.55, "attack"]]
	if _marcha and not _carpeta.contains("extra"):
		casos.insert(2, ["loberno", 0.75, "acecho"])
	for c in casos:
		await _tira(String(c[0]), float(c[1]), String(c[2]), raiz)
	quit()


func _tira(id: String, alto: float, rol: String, raiz: Node3D) -> void:
	var pj := Pj3D.new()
	raiz.add_child(pj)
	if not pj.cargar(id):
		print("NO CARGA ", id)
		pj.queue_free()
		return
	pj.set_alto(alto)
	pj.rotation.y = PI * 0.5            # mira a +X = derecha de la pantalla
	pj._yaw = PI * 0.5
	pj.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	var marcha: MarchaCuadrupedo3D = null
	var v_suelo: float = 0.0
	var modo: String = ""
	if _marcha:
		marcha = MarchaCuadrupedo3D.para(pj)
		if marcha != null:
			v_suelo = marcha.v_base("run") if rol == "run" else (float(marcha.perfil["v_acecho"]) if rol == "acecho" else marcha.v_base("walk"))
			modo = "acecho" if rol == "acecho" else ""
			marcha.agachado = 1.0 if rol == "acecho" else 0.0
	for i in 6:
		await process_frame
	var clip_rol: String = "walk" if rol == "acecho" else rol
	var dur: float = pj.duracion(clip_rol)
	var vel_clip: float = 1.0
	if rol.begins_with("clip:"):
		var nom: String = rol.substr(5)
		pj._arbol.pedir("andar_x", nom, {"mezcla": 0.0})
		dur = pj._ap.get_animation(nom).length
	elif marcha != null:
		var e: Dictionary = marcha.animar_andar(v_suelo, modo)
		dur = pj._ap.get_animation(String(e["clip"])).length
		vel_clip = float(e["vel"])
		marcha.velocidad = v_suelo
	else:
		pj.jugar(clip_rol)
		pj.set_velocidad_animacion(1.0, false)
	var t_ciclo: float = dur / absf(vel_clip)
	var dt: float = 1.0 / 30.0
	var n_total: int = COLS * FILAS
	# Una vuelta de calentamiento para que la mezcla (0,15 s) y la capa procedural se asienten
	var espera: int = int(ceil((t_ciclo + 0.5) / dt))
	for i in espera:
		_alimentar(marcha, v_suelo)
		await process_frame
	var lamina := Image.create(TILE.x * COLS, TILE.y * FILAS, false, Image.FORMAT_RGBA8)
	var pasos: float = t_ciclo / float(n_total) / dt
	var acum: float = 0.0
	for k in n_total:
		# avanzar `pasos` fotogramas (puede ser fraccionario: se acumula)
		acum += pasos
		var n: int = int(floor(acum))
		acum -= float(n)
		for i in n:
			_alimentar(marcha, v_suelo)
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		if img.get_size() != TILE:
			if k == 0:
				print("ojo: la ventana da ", img.get_size(), " y se reescala a ", TILE)
			img.resize(TILE.x, TILE.y, Image.INTERPOLATE_BILINEAR)
		lamina.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i((k % COLS) * TILE.x, (k / COLS) * TILE.y))
	var ruta: String = "%s/%s_%s_%s.png" % [_carpeta, _prefijo, id, rol.replace(":", "_")]
	lamina.save_png(ruta)
	print("guardado ", ruta, "  clip=", pj.clip_actual(), " vel_clip=", vel_clip, " ciclo=", t_ciclo)
	pj.queue_free()
	await process_frame


func _alimentar(marcha: MarchaCuadrupedo3D, v_suelo: float) -> void:
	if marcha != null:
		marcha.velocidad = v_suelo
