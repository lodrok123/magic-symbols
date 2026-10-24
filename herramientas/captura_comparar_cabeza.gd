extends SceneTree
## CAPTURA COMPARATIVA de la cabeza de la protagonista (24/10): de izquierda a derecha la elfa anterior (woodland_wanderer), elfo_base, chibi_elf y jugadora_base con la cabeza a
## las escalas que se pidan (por defecto 1,0 · 0,9 · 0,8 · 0,75), todos en reposo (Idle, primer fotograma) y a 1,0 u de alto como en el juego. Dos fotos en la carpeta:
## `comparar_cabeza_frente.png` (perspectiva de frente) y `comparar_cabeza_juego.png` (cámara del juego, ortográfica a 30°, tamaño 6, ampliada ×2 sin suavizar). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_comparar_cabeza.gd -- <carpeta> [escalas separadas por coma] [nombre de la hoja]
## Si Pj3D.PROPORCIONES ya trae una escala para jugadora_base, la primera columna de jugadora_base es la de «antes» (1,0) y las demás las que se pidan.

const OTROS: Array = ["woodland_wanderer", "elfo_base", "chibi_elf"]
const SEPARACION: float = 0.95
const ALTO: float = 1.0

var _carpeta: String = "res://docs/capturas/lab_jugadora"
var _cam: Camera3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_carpeta = a[0]
	var escalas: Array = [1.0, 0.9, 0.8, 0.75]
	if a.size() > 1 and a[1] != "":
		escalas = []
		for e in a[1].split(",", false):
			escalas.append(float(e))
	var nombre: String = a[2] if a.size() > 2 else "comparar_cabeza"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_carpeta))
	Estado.nuevo()
	root.size = Vector2i(1280, 720)
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
	_cam = Camera3D.new()
	raiz.add_child(_cam)
	_cam.current = true
	var ids: Array = []
	for o in OTROS:
		ids.append([o, 1.0])
	for e in escalas:
		ids.append(["jugadora_base", float(e)])
	var n: int = ids.size()
	for i in range(n):
		var p := Pj3D.new()
		raiz.add_child(p)
		p.position = Vector3((float(i) - float(n - 1) * 0.5) * SEPARACION, 0.0, 0.0)
		var id: String = String(ids[i][0])
		if not p.cargar(id):
			push_warning("no carga " + id)
			continue
		if id == "jugadora_base":
			p.set_proporcion(float(ids[i][1]), 1.0, 1.0)
		p.set_alto(ALTO)
		p.pose_fija("idle", 0.0)
		print("columna %d: %s%s" % [i + 1, id, " cabeza ×%.2f" % float(ids[i][1]) if id == "jugadora_base" else ""])
	for _i in 20:
		await process_frame
	# De frente, en perspectiva.
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.fov = 35.0
	var d_f: float = 1.6 + float(n) * 0.65
	_cam.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.55, d_f)).looking_at(Vector3(0.0, 0.55, 0.0), Vector3.UP)
	await _guardar(nombre + "_frente.png", Rect2i(60, 255, 1160, 235), 2, Image.INTERPOLATE_LANCZOS)
	# Cámara del juego.
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 6.0
	var e: float = deg_to_rad(30.0)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	var foco := Vector3(0.0, 0.85, 0.0)
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 40.0)
	var ancho: int = int(ceil(float(n) * SEPARACION * 120.0 + 100.0))
	await _guardar(nombre + "_juego.png", Rect2i(640 - ancho / 2, 280, ancho, 200), 2)
	quit()


func _guardar(archivo: String, recorte: Rect2i, ampliar: int, modo: Image.Interpolation = Image.INTERPOLATE_NEAREST) -> void:
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image().get_region(recorte)
	if ampliar > 1:
		img.resize(img.get_width() * ampliar, img.get_height() * ampliar, modo)
	img.save_png(ProjectSettings.globalize_path(_carpeta).path_join(archivo))
	print("captura ", archivo)
