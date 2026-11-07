extends SceneTree

## CAPTURA (7/11, pack Fantasy Provencal): fotografia TODAS las piezas `arte/piezas/prov_*.tscn` (las que genera `generar_piezas_provencal.gd`), cargando las escenas
## reales (asi se prueba la integracion), en rejillas por categoria con el nombre y el tamaño debajo y la jugadora (jugadora_base, 1 u) al lado de cada una. Camara ortogonal
## a 60 grados como el juego; el material pasa por Ocluso3D.convertir como al cargar la pieza en PruebaTest2. Para MIRARLO, no es una prueba. Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_provencal.gd -- docs/capturas/provencal
## Escribe provencal_<categoria>[_N].png (maximo 20 piezas por imagen).

const CELDA: Vector2i = Vector2i(400, 400)
const COLUMNAS: int = 5
const POR_IMAGEN: int = 20
const FOTOGRAMAS: int = 8
const S: float = 2.3

var _dir: String = "docs/capturas/provencal"
var _cam: Camera3D = null
var _jug: Pj3D = null
var _mundo: Node3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.get_window().size = CELDA
	Ocluso3D.preparar()
	_montar_escena()
	if a.size() > 2 and a[1] == "ventanas":
		await _ventanas(a[2])
		quit()
		return
	if a.size() > 1 and a[1] == "giros":
		await _giros()
		quit()
		return
	var por_cat: Dictionary = {}
	var d := DirAccess.open(TablaProvencal.CARPETA_PIEZAS)
	var ficheros: PackedStringArray = d.get_files()
	ficheros.sort()
	for fich in ficheros:
		if fich.begins_with("prov_") and fich.ends_with(".tscn"):
			var ps: PackedScene = load(TablaProvencal.CARPETA_PIEZAS + fich) as PackedScene
			var n: Node3D = ps.instantiate() as Node3D
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
			var nombre: String = "provencal_%s%s.png" % [cat, "" if trozos == 1 else "_%d" % (k + 1)]
			hoja.save_png(_dir.path_join(nombre))
			print("captura: ", _dir.path_join(nombre), " ", hoja.get_size(), " (", parte.size(), " piezas)")
	print("RESULTADO piezas fotografiadas: ", total)
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


## La pieza cargada de su escena, con su material por Ocluso3D, junto a la jugadora; devuelve la imagen de su celda.
func _celda(fichero: String, yaw: float = 0.0) -> Image:
	var pieza: Node3D = (load(TablaProvencal.CARPETA_PIEZAS + fichero) as PackedScene).instantiate() as Node3D
	_mundo.add_child(pieza)
	for mi in pieza.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in range(m.mesh.get_surface_count()):
			var mat: Material = m.get_surface_override_material(s)
			if mat != null:
				m.set_surface_override_material(s, Ocluso3D.convertir(mat.duplicate() as Material))
	var caja: AABB = AABB()
	var primera: bool = true
	for hijo in pieza.get_node("modelo").get_children():       # malla y, en el molino, las aspas
		var cm: AABB = (hijo as MeshInstance3D).transform * (hijo as MeshInstance3D).mesh.get_aabb()
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
	rotulo.text = "%s\n%.2f x %.2f cas." % [String(pieza.name).trim_prefix("prov_") + ("" if yaw == 0.0 else " +%d" % int(yaw)), maxf(ancho, fondo) / S, alto / S]
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


## Una fila por pieza con 4 giros (+0, +90, +180, +270 sobre el giro de la escena) para decidir cual frente mira a la camara. Escribe provencal_giros.png.
const FRENTES: Array = ["house_01", "house_passage", "bench", "cart", "crate_01", "crate_02", "crate_03", "door", "house_02", "house_barn", "house_tower", "watermill_house", "shrine", "windmill", "fence_02", "bridge"]


func _giros() -> void:
	var hoja := Image.create(CELDA.x * 4, CELDA.y * FRENTES.size(), false, Image.FORMAT_RGBA8)
	for i in range(FRENTES.size()):
		for k in range(4):
			var img: Image = await _celda("prov_%s.tscn" % FRENTES[i], 90.0 * k)
			hoja.blit_rect(img, Rect2i(Vector2i.ZERO, CELDA), Vector2i(k * CELDA.x, i * CELDA.y))
	hoja.save_png(_dir.path_join("provencal_giros.png"))
	print("captura: ", _dir.path_join("provencal_giros.png"))


## Primer plano de la ventana mas cercana a la camara de watermill_house, windmill y house_tower, en un solo PNG (tres paneles de 600 px).
##   godot --path . --script res://herramientas/captura_provencal.gd -- docs/capturas/provencal ventanas ventanas_despues.png
func _ventanas(nombre: String) -> void:
	var hoja := Image.create(1800, 600, false, Image.FORMAT_RGBA8)
	root.get_window().size = Vector2i(600, 600)
	var k: int = 0
	for id in ["watermill_house", "windmill", "house_tower"]:
		var pieza: Node3D = (load(TablaProvencal.CARPETA_PIEZAS + "prov_%s.tscn" % id) as PackedScene).instantiate() as Node3D
		_mundo.add_child(pieza)
		var mejor: Vector3 = Vector3(0, 0, -INF)
		for mi in pieza.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi as MeshInstance3D
			for s in range(m.mesh.get_surface_count()):
				var mat: Material = m.get_surface_override_material(s)
				if m.mesh.surface_get_name(s) == "M_Windows":
					for v in (m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
						var w: Vector3 = m.global_transform * v
						if w.z > mejor.z and w.y > 0.3:
							mejor = w
				if mat != null:
					m.set_surface_override_material(s, Ocluso3D.convertir(mat.duplicate() as Material))
		_cam.size = 2.4
		var e: float = deg_to_rad(30.0)
		var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
		_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), mejor - dir * 40.0)
		_jug.position = Vector3(500, 0, 500)
		for f in range(FOTOGRAMAS):
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		hoja.blit_rect(img, Rect2i(0, 0, 600, 600), Vector2i(k * 600, 0))
		print("ventana de ", id, " en ", mejor)
		pieza.free()
		k += 1
	hoja.save_png(_dir.path_join(nombre))
	print("captura: ", _dir.path_join(nombre))
