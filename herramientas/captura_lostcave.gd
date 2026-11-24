extends SceneTree

## CAPTURA (24/11/2026, pack Stylized Lost Cave): fotografía TODAS las piezas `arte/lostcave/piezas/lost_*.tscn` (las que genera
## `generar_piezas_lostcave.gd`) cargando las escenas reales, en hojas por categoría con el nombre, el tamaño en casillas y los triángulos debajo
## y la jugadora (jugadora_base, 1 u) al lado. Cámara ortogonal a 30° sobre el suelo, como el juego; el material pasa por Ocluso3D.convertir
## como al cargar una pieza en la maqueta. Hecho a partir de captura_provencal.gd. Para MIRARLO, no es una prueba. Necesita ventana:
##   godot --path . --script res://herramientas/captura_lostcave.gd
##   godot --path . --script res://herramientas/captura_lostcave.gd -- giros lost_arch lost_cart ...   (cada pieza con sus 4 giros)
## Escribe arte/lostcave/capturas/lostcave_<categoria>[_N].png (fuera de git, como todo el pack). Máximo 20 piezas por imagen.

const T = preload("res://arte/lostcave/tabla_lostcave.gd")
const CELDA: Vector2i = Vector2i(400, 400)
const COLUMNAS: int = 5
const POR_IMAGEN: int = 20
const FOTOGRAMAS: int = 8
const S: float = 2.3
const DIR: String = "res://arte/lostcave/capturas"

var _cam: Camera3D = null
var _jug: Pj3D = null
var _mundo: Node3D = null
var _pared: MeshInstance3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var dir: String = ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.get_window().size = CELDA
	Ocluso3D.preparar()
	_montar_escena()
	if a.size() > 1 and a[0] == "giros":
		await _giros(dir, a.slice(1))
		quit()
		return
	var por_cat: Dictionary = {}
	var ficheros: PackedStringArray = DirAccess.open(T.CARPETA_PIEZAS).get_files()
	ficheros.sort()
	for fich in ficheros:
		if fich.begins_with(T.PREFIJO) and fich.ends_with(".tscn"):
			var n: Node3D = (load(T.CARPETA_PIEZAS + fich) as PackedScene).instantiate() as Node3D
			var cat: String = String(n.get_meta("categoria", "sin_categoria"))
			if not por_cat.has(cat):
				por_cat[cat] = []
			(por_cat[cat] as Array).append(fich)
			n.free()
	var total: int = 0
	for cat in por_cat.keys():
		var lista: Array = por_cat[cat]
		var trozos: int = int(ceil(float(lista.size()) / POR_IMAGEN))
		for k in range(trozos):
			var parte: Array = lista.slice(k * POR_IMAGEN, (k + 1) * POR_IMAGEN)
			var filas: int = int(ceil(float(parte.size()) / COLUMNAS))
			var hoja := Image.create(CELDA.x * COLUMNAS, CELDA.y * filas, false, Image.FORMAT_RGBA8)
			for i in range(parte.size()):
				var img: Image = await _celda(String(parte[i]))
				hoja.blit_rect(img, Rect2i(Vector2i.ZERO, CELDA), Vector2i((i % COLUMNAS) * CELDA.x, (i / COLUMNAS) * CELDA.y))
				total += 1
			var nombre: String = "lostcave_%s%s.png" % [cat, "" if trozos == 1 else "_%d" % (k + 1)]
			hoja.save_png(dir.path_join(nombre))
			print("captura: ", dir.path_join(nombre), " ", hoja.get_size(), " (", parte.size(), " piezas)")
	print("RESULTADO piezas fotografiadas: ", total)
	quit()


func _montar_escena() -> void:
	var e := WorldEnvironment.new()
	e.environment = Environment.new()
	e.environment.background_mode = Environment.BG_COLOR
	e.environment.background_color = Color(0.16, 0.17, 0.2)
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
	pl.size = Vector2(200, 200)
	suelo.mesh = pl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.36, 0.31, 0.26)
	sm.roughness = 1.0
	suelo.material_override = sm
	root.add_child(suelo)
	# pared detrás de las calcas (el Decal proyecta hacia -Z)
	_pared = MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(2.4, 2.4, 0.2)
	_pared.mesh = bx
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.55, 0.53, 0.5)
	_pared.material_override = pm
	_pared.visible = false
	root.add_child(_pared)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.far = 500.0
	_cam.current = true
	root.add_child(_cam)
	_mundo = Node3D.new()
	root.add_child(_mundo)
	_jug = Pj3D.new()
	root.add_child(_jug)
	_jug.cargar("jugadora_base")
	_jug.set_alto(1.0)


## La pieza cargada de su escena, con su material por Ocluso3D, junto a la jugadora; devuelve la imagen de su celda.
func _celda(fichero: String, yaw: float = 0.0) -> Image:
	var pieza: Node3D = (load(T.CARPETA_PIEZAS + fichero) as PackedScene).instantiate() as Node3D
	_mundo.add_child(pieza)
	var es_calca: bool = String(pieza.get_meta("categoria", "")) == "calca"
	for mi in pieza.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in range(m.mesh.get_surface_count()):
			var mat: Material = m.get_surface_override_material(s)
			if mat != null:
				m.set_surface_override_material(s, Ocluso3D.convertir(mat.duplicate() as Material))
	var caja := AABB(Vector3(-T.CALCA_LADO * 0.5, 0, -0.1), Vector3(T.CALCA_LADO, T.CALCA_LADO, 0.2))
	if not es_calca:
		var m0: MeshInstance3D = pieza.get_node("modelo/malla") as MeshInstance3D
		caja = m0.transform * m0.mesh.get_aabb()
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
	pieza.position = Vector3(x0, 1.2 if es_calca else 0.0, 0.0)
	_pared.visible = es_calca
	_pared.position = Vector3(x0, 1.2 + T.CALCA_LADO * 0.5 - 0.4, -0.2)
	_jug.position = Vector3(x0 + ancho * 0.5 + 0.8, 0.0, 0.0)
	var tam: float = clampf(maxf((alto * 0.87 + fondo * 0.5) * 1.35 + 0.6, total * 1.15), 2.6, 45.0)
	_cam.size = tam
	var e: float = deg_to_rad(30.0)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	var mira := Vector3(0.0, (2.0 if es_calca else alto * 0.5) * 0.87, 0.0)
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), mira - dir * 120.0)
	var rotulo := Label3D.new()
	rotulo.text = "%s\n%.2f x %.2f cas. · %d tris" % [String(pieza.name).trim_prefix(T.PREFIJO) + ("" if yaw == 0.0 else " +%d" % int(yaw)),
		maxf(ancho, fondo) / S, alto / S, int(pieza.get_meta("triangulos", 0))]
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


## Una fila por pieza con 4 giros (+0, +90, +180, +270) para decidir cuál frente mira a la cámara (y apuntarlo en TablaLostCave.GIRO).
func _giros(dir: String, ids: Array) -> void:
	var hoja := Image.create(CELDA.x * 4, CELDA.y * ids.size(), false, Image.FORMAT_RGBA8)
	for i in range(ids.size()):
		for k in range(4):
			var img: Image = await _celda("%s.tscn" % ids[i], 90.0 * k)
			hoja.blit_rect(img, Rect2i(Vector2i.ZERO, CELDA), Vector2i(k * CELDA.x, i * CELDA.y))
	hoja.save_png(dir.path_join("lostcave_giros.png"))
	print("captura: ", dir.path_join("lostcave_giros.png"))
