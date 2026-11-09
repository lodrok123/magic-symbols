extends SceneTree

## CAPTURA (8/11) de piezas de `arte/piezas/<id>.tscn` (las de las laminas de Meshy: pantano, ruinas...) con la camara ortogonal a 60 grados del juego, la jugadora (1 u) al lado y el
## material por Ocluso3D.convertir como al cargarlas en PruebaTest2. Para MIRARLO, no es una prueba. Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_laminas_meshy.gd -- <carpeta> hoja <archivo.png> <id> [<id> ...]     una fila: cada pieza con la jugadora y su medida
##   godot --path . --script res://herramientas/captura_laminas_meshy.gd -- <carpeta> giros <archivo.png> <id> [<id> ...]    una fila por pieza con +0, +90, +180, +270 (para ver donde mira su frente)
## Ejemplo (hoja de las ruinas): ... -- docs/capturas/ruinas hoja artefactos.png jarron jarron_alto estatua_piedra anfora_asas_a anfora_asas_b pila_ofrenda idolo_a idolo_b

const CELDA: Vector2i = Vector2i(400, 400)
const FOTOGRAMAS: int = 8
const S: float = 2.3

var _cam: Camera3D = null
var _jug: Pj3D = null
var _mundo: Node3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() < 4:
		print("Uso: -- <carpeta> hoja|giros <archivo.png> <id> [<id> ...]")
		quit()
		return
	var dir: String = a[0]
	if not dir.is_absolute_path():
		dir = ProjectSettings.globalize_path("res://" + dir)
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.get_window().size = CELDA
	Ocluso3D.preparar()
	_montar_escena()
	var ids: Array = Array(a.slice(3))
	var yaws: Array = [0.0] if a[1] == "hoja" else [0.0, 90.0, 180.0, 270.0]
	var hoja := Image.create(CELDA.x * (ids.size() if a[1] == "hoja" else 4), CELDA.y * (1 if a[1] == "hoja" else ids.size()), false, Image.FORMAT_RGBA8)
	for i in range(ids.size()):
		for k in range(yaws.size()):
			var img: Image = await _celda(String(ids[i]), float(yaws[k]))
			if img == null:
				continue
			var pos := Vector2i(i * CELDA.x, 0) if a[1] == "hoja" else Vector2i(k * CELDA.x, i * CELDA.y)
			hoja.blit_rect(img, Rect2i(Vector2i.ZERO, CELDA), pos)
	hoja.save_png(dir.path_join(a[2]))
	print("captura: ", dir.path_join(a[2]), " ", hoja.get_size())
	quit()


func _montar_escena() -> void:
	var e := WorldEnvironment.new()
	e.environment = Environment.new()
	e.environment.background_mode = Environment.BG_COLOR
	e.environment.background_color = Color(0.55, 0.68, 0.78)
	e.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	e.environment.ambient_light_energy = 0.7
	Paleta3D.aplicar_ajuste(e.environment)
	root.add_child(e)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 35, 0)
	sol.light_energy = 1.1
	sol.shadow_enabled = true
	root.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(80, 80)
	suelo.mesh = pl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Paleta3D.HIERBA
	sm.roughness = 1.0
	suelo.material_override = sm
	root.add_child(suelo)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.far = 300.0
	_cam.current = true
	root.add_child(_cam)
	_mundo = Node3D.new()
	root.add_child(_mundo)
	_jug = Pj3D.new()
	root.add_child(_jug)
	_jug.cargar("jugadora_base")
	_jug.set_alto(1.0)


func _celda(id: String, yaw: float) -> Image:
	var ruta: String = "res://arte/piezas/%s.tscn" % id
	if not ResourceLoader.exists(ruta):
		push_warning("sin pieza " + id)
		return null
	var pieza: Node3D = (load(ruta) as PackedScene).instantiate() as Node3D
	_mundo.add_child(pieza)
	var caja := AABB()
	var primera: bool = true
	for mi in pieza.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in range(m.mesh.get_surface_count()):
			var mat: Material = m.get_active_material(s)
			if mat != null:
				m.set_surface_override_material(s, Ocluso3D.convertir(mat.duplicate() as Material))
		var cm: AABB = m.global_transform * m.mesh.get_aabb()
		caja = cm if primera else caja.merge(cm)
		primera = false
	var ancho: float = caja.size.x
	var fondo: float = caja.size.z
	var alto: float = caja.size.y
	pieza.rotation.y = deg_to_rad(yaw)
	if int(round(yaw / 90.0)) % 2 != 0:
		var tmp: float = ancho
		ancho = fondo
		fondo = tmp
	var total: float = ancho + 0.8 + 0.5
	var x0: float = -total * 0.5 + ancho * 0.5
	pieza.position = Vector3(x0, 0.0, 0.0)
	_jug.position = Vector3(x0 + ancho * 0.5 + 0.8, 0.0, 0.0)
	var tam: float = clampf(maxf((alto * 0.87 + fondo * 0.5) * 1.35 + 0.6, total * 1.15), 2.6, 18.0)
	_cam.size = tam
	var e: float = deg_to_rad(30.0)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	var mira := Vector3(0.0, alto * 0.5 * 0.87, 0.0)
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), mira - dir * 40.0)
	var rotulo := Label3D.new()
	rotulo.text = "%s%s\n%.2f x %.2f x %.2f u" % [id, "" if yaw == 0.0 else " +%d" % int(yaw), maxf(ancho, fondo), alto, minf(ancho, fondo)]
	rotulo.font_size = 40
	rotulo.pixel_size = 0.0011 * tam
	rotulo.no_depth_test = true
	rotulo.outline_modulate = Color(0.1, 0.1, 0.15)
	rotulo.outline_size = 10
	rotulo.rotation_degrees = Vector3(-30.0, 0.0, 0.0)
	rotulo.position = Vector3(0.0, 0.0, fondo * 0.5 + 0.1 * tam)
	_mundo.add_child(rotulo)
	for k in range(FOTOGRAMAS):
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	pieza.free()
	rotulo.free()
	return img
