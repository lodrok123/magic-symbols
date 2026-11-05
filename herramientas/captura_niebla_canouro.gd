extends SceneTree
## 5/11 · CAPTURA de la niebla negra del canouro (NieblaCanouro3D). Con ventana (no --headless). Guarda dos png de 800x600 en docs/capturas/niebla_canouro/:
##   niebla_canouro_juego.png (cámara del juego, inclinada 30°) y niebla_canouro_perfil.png (casi de perfil, 12°: a 0° las láminas se ven de canto y no se ve nada; así se ve que la niebla queda por debajo de la rodilla).
##   godot --path . --resolution 800x600 --fixed-fps 30 --script res://herramientas/captura_niebla_canouro.gd

const CARPETA: String = "res://docs/capturas/niebla_canouro"
var _cam: Camera3D = null


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))
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
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	suelo.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.6, 0.38)
	suelo.material_override = mat
	raiz.add_child(suelo)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 1.5
	raiz.add_child(_cam)
	_cam.current = true
	var pj := Pj3D.new()
	raiz.add_child(pj)
	if not pj.cargar("canouro"):
		print("NO CARGA canouro")
		quit()
		return
	pj.set_alto(0.55)
	pj.rotation.y = PI * 0.5
	pj._yaw = PI * 0.5
	pj.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	pj.jugar("walk")
	NieblaCanouro3D.poner(pj, 0.55)
	for i in 40:
		await process_frame
	await _foto(30.0, "niebla_canouro_juego.png")
	await _foto(12.0, "niebla_canouro_perfil.png")
	quit()


func _foto(grados: float, nombre: String) -> void:
	var e: float = deg_to_rad(grados)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	var foco := Vector3(0.0, 0.25, 0.0)
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 10.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if img.get_size() != Vector2i(800, 600):
		img.resize(800, 600, Image.INTERPOLATE_BILINEAR)
	var ruta: String = ProjectSettings.globalize_path(CARPETA + "/" + nombre)
	img.save_png(ruta)
	print("guardado ", ruta, "  tamaño ", img.get_size())
