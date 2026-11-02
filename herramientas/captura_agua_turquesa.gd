extends SceneTree

## CAPTURAS CON VENTANA del agua «toy» con el TURQUESA del agua del juego (agua del mundo con agua_filtro = true, el valor de serie). Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_agua_turquesa.gd -- docs/capturas/comparativa_vfx/godot_agua/turquesa [estanque | lab | todo | hoja]
## estanque: un estanque REAL (AguaSim3D + AguaRender3D con el filtro de serie) junto a bola, haz, géiser, ola, área y salpicadura de hechizo -> estanque_con_filtro.png (+ _estandar.png, la versión sin filtro);
## lab: las mismas piezas sobre el suelo del laboratorio (cámara del juego) -> lab_*.png; hoja: junta <dir>/antes/*.png (paleta azul) con <dir>/*.png (turquesa) en hoja_antes_despues.png
## (los «antes» se sacan con la paleta vieja: respaldos/agua_toy_antes_turquesa/agua_paleta.gd puesta un momento y la salida en <dir>/antes).

const TAM: Vector2i = Vector2i(1280, 720)

var _dir: String = "docs/capturas/comparativa_vfx/godot_agua/turquesa"
var _lab: Node3D = null

const S: float = 2.3
const ALTO_B: float = S * 0.45
const ALTO_AGUA: float = ALTO_B - 0.04
const LECHO: float = 0.9
var _agua: Array[Vector2i] = []
var _vp: SubViewport = null
var _camw: Camera3D = null
var _sim_w: AguaSim3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var que: String = "todo"
	if a.size() > 0:
		_dir = a[0]
	if a.size() > 1:
		que = a[1]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = TAM
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	if que == "hoja":
		_hoja()
		quit()
		return
	if que in ["todo", "estanque"]:
		await _estanque()
	if que in ["todo", "lab"]:
		await _laboratorio()
	print("CAPTURAS en " + _dir)
	quit()


func _seg(s: float) -> void:
	await create_timer(s).timeout


func _es_agua(c: Vector2i) -> bool:
	return _agua.has(c)


func _suelo(c: Vector2i) -> float:
	return ALTO_AGUA - LECHO if _es_agua(c) else ALTO_B


func _guardar(img: Image, nombre: String) -> void:
	img.save_png(_dir.path_join(nombre + ".png"))
	print("still " + nombre)


# ------------------------------------------------------------------ estanque real + hechizos ------------------------------------------------------------------

func _estanque() -> void:
	for x in range(1, 6):
		for y in range(1, 4):
			_agua.append(Vector2i(x, y))
	_vp = SubViewport.new()
	_vp.size = TAM
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var mundo: Node3D = Node3D.new()
	_vp.add_child(mundo)
	var mat_tierra: StandardMaterial3D = StandardMaterial3D.new()
	mat_tierra.albedo_color = Color(0.46, 0.55, 0.30)
	var mat_lecho: StandardMaterial3D = StandardMaterial3D.new()
	mat_lecho.albedo_color = Color(0.55, 0.47, 0.34)
	for y in range(6):
		for x in range(12):
			var c: Vector2i = Vector2i(x, y)
			var top: float = _suelo(c)
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(S, top + 1.0, S)
			var b: MeshInstance3D = MeshInstance3D.new()
			b.mesh = bm
			b.material_override = mat_lecho if _es_agua(c) else mat_tierra
			b.position = Vector3((x + 0.5) * S, (top - 1.0) * 0.5, (y + 0.5) * S)
			mundo.add_child(b)
	var sol: DirectionalLight3D = DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	mundo.add_child(sol)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.15, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	mundo.add_child(we)
	_camw = Camera3D.new()
	_camw.far = 200.0
	mundo.add_child(_camw)
	_camw.current = true
	_sim_w = AguaSim3D.new()
	_sim_w.configurar(12, 6, 3, S, _suelo, func(_c: Vector2i) -> bool: return false)
	for c in _agua:
		_sim_w.llenar_casilla(c, ALTO_AGUA)
	var r: AguaRender3D = AguaRender3D.new()
	mundo.add_child(r)
	r.enlazar(_sim_w)
	print("agua_filtro de serie = ", r.agua_filtro)
	for i in range(60):
		_sim_w.paso(1.0 / 30.0)
		await process_frame
	var suelo_y: float = ALTO_B
	var inc: float = 60.0
	var e_: float = deg_to_rad(90.0 - inc)
	var dircam: Vector3 = -Vector3(0.0, sin(e_), cos(e_))
	var foco: Vector3 = Vector3(6.4 * S, suelo_y, 2.4 * S)
	_camw.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camw.size = 15.0
	_camw.transform = Transform3D(Basis.looking_at(dircam, Vector3.UP), foco - dircam * 40.0)
	# bolas: una sobre el estanque y otra en tierra; el haz, el géiser y la ola a la derecha del estanque
	var bola: AguaToy = _toy(mundo, AguaToy.Figura.BOLA, Vector3(0.4, 0.4, 0.4), Vector3(3.2 * S, suelo_y + 0.8, 2.4 * S))
	var bola2: AguaToy = _toy(mundo, AguaToy.Figura.BOLA, Vector3(0.4, 0.4, 0.4), Vector3(6.4 * S, suelo_y + 0.8, 3.4 * S))
	var haz: AguaToy = _toy(mundo, AguaToy.Figura.HAZ, Vector3(1.5, 0.5, 0.15), Vector3(6.3 * S, suelo_y + 0.2, 1.4 * S))
	haz.look_at(haz.global_position + Vector3(1, 0, 0.3), Vector3.UP)
	haz.lanzar(-1.0)
	var gei: AguaToy = _toy(mundo, AguaToy.Figura.PILAR, Vector3(0.5, 3.0, 0.5), Vector3(8.0 * S, suelo_y, 1.5 * S))
	gei.lanzar(-1.0)
	var ola: AguaToy = _toy(mundo, AguaToy.Figura.MURO, Vector3(3.45, 1.5, 0.3), Vector3(9.6 * S, suelo_y, 3.5 * S))
	ola.rotation_degrees = Vector3(0, 0, 0)
	ola.lanzar(-1.0)
	await _seg(2.0)
	_guardar(_vp.get_texture().get_image(), "estanque_con_filtro")
	r.agua_filtro = false
	await _seg(0.8)
	_guardar(_vp.get_texture().get_image(), "estanque_estandar_sin_filtro")
	r.agua_filtro = true
	await _seg(0.8)
	# el área y la salpicadura, aparte (junto al agua)
	var imp: ImpactoAguaToy = ImpactoAguaToy.crear(ImpactoAguaToy.Variante.AREA, Vector3.UP, 1.8)
	mundo.add_child(imp)
	imp.global_position = Vector3(7.7 * S, suelo_y, 4.4 * S)
	var sal: ImpactoAguaToy = ImpactoAguaToy.crear(ImpactoAguaToy.Variante.GOLPE, Vector3.UP, 0.4)
	mundo.add_child(sal)
	sal.global_position = Vector3(4.3 * S, suelo_y, 4.2 * S)
	Engine.time_scale = 0.3
	for t in [0.35, 0.8]:
		await process_frame
		while is_instance_valid(imp) and imp.tiempo() < t:
			await process_frame
		_guardar(_vp.get_texture().get_image(), "estanque_area_%03d" % int(t * 1000.0))
	Engine.time_scale = 1.0
	_vp.queue_free()
	_agua.clear()


func _toy(mundo: Node3D, fig: int, s: Vector3, pos: Vector3) -> AguaToy:
	var e: AguaToy = AguaToy.new()
	e.definir(fig, s.x, s.y, s.z, false)
	mundo.add_child(e)
	e.global_position = pos
	return e


# ------------------------------------------------------------------ laboratorio (suelo del lab, cámara del juego) ------------------------------------------------------------------

func _laboratorio() -> void:
	_lab = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_lab)
	_lab.set("_panel_visible", false)
	_lab.call("poner_elemento", "agua")
	_lab.call("poner_camara", 0)
	for i in 4:
		var cubo: Node3D = _lab.get_node_or_null("Cubo%d" % i) as Node3D
		if cubo != null:
			cubo.visible = false
	await _seg(0.8)
	var ims: Array = []
	for i in [0, 4, 2, 1]:
		_lab.set("camara_fija", {})
		_lab.call("poner_camara", 0)
		_lab.call("fuego_param", i)
		await _seg(1.9)
		var img: Image = root.get_viewport().get_texture().get_image()
		_guardar(img, "lab_figura_%d" % i)
		ims.append(img)
		_lab.call("limpiar")
		await _seg(0.4)
	var imp: Node3D = _lab.call("explosion_area")
	Engine.time_scale = 0.3
	for t in [0.35, 0.8]:
		await process_frame
		while is_instance_valid(imp) and imp.tiempo() < t:
			await process_frame
		var img2: Image = root.get_viewport().get_texture().get_image()
		_guardar(img2, "lab_area_%03d" % int(t * 1000.0))
		ims.append(img2)
	Engine.time_scale = 1.0
	_tira("lab_hoja.png", ims, 3, 480, 270)
	_lab.queue_free()


func _tira(nombre: String, imgs: Array, cols: int, cw: int, chh: int) -> void:
	var filas: int = int(ceil(float(imgs.size()) / float(cols)))
	var im: Image = Image.create_empty(cw * cols, chh * filas, false, Image.FORMAT_RGB8)
	for i in imgs.size():
		var c: Image = (imgs[i] as Image).duplicate()
		c.convert(Image.FORMAT_RGB8)
		c.resize(cw, chh, Image.INTERPOLATE_LANCZOS)
		im.blit_rect(c, Rect2i(0, 0, cw, chh), Vector2i((i % cols) * cw, (i / cols) * chh))
	im.save_png(_dir.path_join(nombre))


## Hoja antes (arriba) / después (abajo) con lo que haya en <dir>/antes y en <dir>.
func _hoja() -> void:
	var nombres: Array = ["estanque_con_filtro", "estanque_area_350", "lab_figura_0", "lab_figura_4", "lab_figura_2", "lab_figura_1", "lab_area_350"]
	var fila_a: Array = []
	var fila_d: Array = []
	for n in nombres:
		var pa: String = _dir.path_join("antes").path_join(n + ".png")
		var pd: String = _dir.path_join(n + ".png")
		if FileAccess.file_exists(pa) and FileAccess.file_exists(pd):
			fila_a.append(Image.load_from_file(pa))
			fila_d.append(Image.load_from_file(pd))
	var todas: Array = []
	todas.append_array(fila_a)
	todas.append_array(fila_d)
	_tira("hoja_antes_despues.png", todas, fila_a.size(), 480, 270)
	print("hoja con %d pares" % fila_a.size())
