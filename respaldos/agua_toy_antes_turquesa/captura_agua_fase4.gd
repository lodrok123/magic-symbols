extends SceneTree

## CAPTURAS CON VENTANA del agua «toy», FASE 4 (paleta del agua del mundo, lenguas y OLA). Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_agua_fase4.gd -- docs/capturas/comparativa_vfx/godot_agua/fase4 [todo | ola | secuencia | lenguas | paleta | hoja]
## ola: vistas de la ola (juego, cercana, horizontal a 0°, 45° y 90° del avance), nacer y morir en 4 fotogramas cada uno; secuencia: 12 fps; lenguas: géiser y área (después); paleta: un estanque de agua
## REAL del mundo (AguaSim3D + AguaRender3D) junto a la bola, el haz, el géiser, el área y la salpicadura de hechizo.

const TAM: Vector2i = Vector2i(1280, 720)
const CELDA: int = 320
const REF_A: String = "res://docs/capturas/comparativa_vfx/referencia_agua/ref_agua_bola_ola_pilar_a.png"
const REF_B: String = "res://docs/capturas/comparativa_vfx/referencia_agua/ref_agua_bola_ola_pilar_b.png"

var _dir: String = "docs/capturas/comparativa_vfx/godot_agua/fase4"
var _lab: Node3D = null
var _hojas: Dictionary = {}


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
	DirAccess.make_dir_recursive_absolute(_dir.path_join("frames"))
	root.get_window().size = TAM
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	if que == "paleta":
		await _paleta()
		print("CAPTURAS en " + _dir)
		quit()
		return
	_lab = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_lab)
	_lab.set("_panel_visible", false)
	_lab.call("poner_elemento", "agua")
	_lab.call("poner_camara", 1)
	for i in 4:
		var cubo: Node3D = _lab.get_node_or_null("Cubo%d" % i) as Node3D
		if cubo != null:
			cubo.visible = false
	await _seg(0.8)
	if que in ["todo", "ola"]:
		await _ola()
	if que in ["todo", "lenguas"]:
		await _lenguas()
	if que in ["todo", "secuencia"]:
		await _secuencia_ola()
	print("CAPTURAS en " + _dir)
	quit()


func _sim(t0: int) -> float:
	return float(Time.get_ticks_msec() - t0) / 1000.0 * Engine.time_scale


func _hasta(t0: int, t: float) -> void:
	await process_frame
	while _sim(t0) < t:
		await process_frame


func _seg(s: float) -> void:
	await create_timer(s).timeout


func _cam(desde: Vector3, mira: Vector3) -> void:
	_lab.set("camara_fija", {"desde": desde, "mira": mira})


func _limpiar() -> void:
	_lab.set("camara_fija", {})
	_lab.call("limpiar")
	await _seg(0.4)


func _still(nombre: String) -> Image:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre + ".png"))
	print("still " + nombre)
	return img


func _tira(nombre: String, imgs: Array, cols: int = 6, cw: int = 320, chh: int = 180) -> void:
	var filas: int = int(ceil(float(imgs.size()) / float(cols)))
	var im: Image = Image.create_empty(cw * cols, chh * filas, false, Image.FORMAT_RGB8)
	for i in imgs.size():
		var c: Image = (imgs[i] as Image).duplicate()
		c.convert(Image.FORMAT_RGB8)
		c.resize(cw, chh, Image.INTERPOLATE_LANCZOS)
		im.blit_rect(c, Rect2i(0, 0, cw, chh), Vector2i((i % cols) * cw, (i / cols) * chh))
	im.save_png(_dir.path_join(nombre))


# ------------------------------------------------------------------ ola ------------------------------------------------------------------

func _nueva_ola() -> Node3D:
	_lab.set("camara_fija", {})
	return _lab.call("fuego_param", 1)


## La ola avanza hacia -Z: «0°» = de frente (la cámara delante, mirando a la cara de la ola), 45° y 90° (de canto, a lo largo de la ola).
func _vista(modo: String, p: Vector3) -> void:
	match modo:
		"juego":
			_lab.set("camara_fija", {})
			_lab.call("poner_camara", 0)
		"cerca":
			_lab.call("poner_camara", 1)
			_cam(p + Vector3(2.4, 1.6, -4.4), p + Vector3(0.4, 0.6, 0))
		"az0":
			_lab.call("poner_camara", 1)
			_cam(p + Vector3(0, 1.2, -6.5), p + Vector3(0, 0.7, 0))
		"az45":
			_lab.call("poner_camara", 1)
			_cam(p + Vector3(4.6, 1.5, -4.6), p + Vector3(0, 0.7, 0))
		"az90":
			_lab.call("poner_camara", 1)
			_cam(p + Vector3(8.0, 1.2, 0.0), p + Vector3(0, 0.8, 0))


func _ola() -> void:
	var e: Node3D = _nueva_ola()
	await _seg(1.8)
	var p: Vector3 = e.global_position
	var vistas: Array = []
	for modo in ["juego", "cerca", "az0", "az45", "az90"]:
		_vista(modo, p)
		await _seg(0.35)
		vistas.append(_still("ola_" + modo))
	_tira("ola_vistas.png", vistas, 5, 400, 225)
	await _limpiar()
	# nacer y morir, con la cámara cercana y la del juego
	for modo in ["cerca", "juego", "az90"]:
		e = _nueva_ola()
		p = e.global_position
		_vista(modo, p)
		Engine.time_scale = 0.3
		var t0: int = Time.get_ticks_msec()
		var im_n: Array = []
		for t in [0.12, 0.28, 0.45, 0.7]:
			await _hasta(t0, t)
			im_n.append(_still("ola_%s_nace_%03d" % [modo, int(t * 1000.0)]))
		_tira("ola_%s_nace.png" % modo, im_n, 4, 480, 270)
		await _hasta(t0, 2.6)
		e.call("morir")
		t0 = Time.get_ticks_msec()
		var im_m: Array = []
		for t in [0.3, 0.7, 1.1, 1.7]:
			await _hasta(t0, t)
			im_m.append(_still("ola_%s_muere_%03d" % [modo, int(t * 1000.0)]))
		_tira("ola_%s_muere.png" % modo, im_m, 4, 480, 270)
		Engine.time_scale = 1.0
		await _limpiar()


func _secuencia_ola() -> void:
	DirAccess.make_dir_recursive_absolute(_dir.path_join("ola12"))
	var e: Node3D = _nueva_ola()
	var p: Vector3 = e.global_position
	_vista("cerca", p)
	Engine.time_scale = 0.4
	var t0: int = Time.get_ticks_msec()
	var k: int = 0
	var celdas: Array = []
	var muerto: bool = false
	while k < 54:
		await _hasta(t0, float(k) / 12.0)
		_vista("cerca", p)
		if not muerto and float(k) / 12.0 >= 2.6 and is_instance_valid(e):
			e.call("morir")
			muerto = true
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png(_dir.path_join("ola12").path_join("o_%02d.png" % k))
		celdas.append(img)
		k += 1
	_tira("secuencia_ola_12fps.png", celdas, 6)
	Engine.time_scale = 1.0
	await _limpiar()


# ------------------------------------------------------------------ lenguas ------------------------------------------------------------------

func _lenguas() -> void:
	var e: Node3D = _lab.call("fuego_param", 2)
	await _seg(1.8)
	var p: Vector3 = e.global_position
	var ims: Array = []
	for modo in ["juego", "cerca", "horiz"]:
		match modo:
			"juego":
				_lab.set("camara_fija", {})
				_lab.call("poner_camara", 0)
			"cerca":
				_lab.call("poner_camara", 1)
				_cam(p + Vector3(2.7, 2.0, 3.4), p + Vector3(0, 1.5, 0))
			"horiz":
				_lab.call("poner_camara", 1)
				_cam(p + Vector3(5.0, 1.1, 0.8), p + Vector3(0, 1.7, 0))
		await _seg(0.35)
		ims.append(_still("geiser_" + modo))
	await _limpiar()
	for modo in ["juego", "cerca"]:
		var imp: Node3D = _lab.call("explosion_area")
		var punto: Vector3 = imp.global_position
		if modo == "juego":
			_lab.set("camara_fija", {})
			_lab.call("poner_camara", 0)
		else:
			_lab.call("poner_camara", 1)
			_cam(punto + Vector3(3.0, 2.1, 3.6), punto + Vector3(0, 0.55, 0))
		Engine.time_scale = 0.3
		for t in [0.1, 0.3, 0.5, 0.7, 1.0, 1.4]:
			await process_frame
			while is_instance_valid(imp) and imp.tiempo() < t:
				await process_frame
			ims.append(_still("area_%s_%03d" % [modo, int(t * 1000.0)]))
		Engine.time_scale = 1.0
		await _limpiar()
	_tira("lenguas_despues.png", ims, 5, 400, 225)


# ------------------------------------------------------------------ paleta junto al agua del mundo ------------------------------------------------------------------

const S: float = 2.3
const ALTO_B: float = S * 0.45
const ALTO_AGUA: float = ALTO_B - 0.04
const LECHO: float = 0.9
var _agua: Array[Vector2i] = []
var _vp: SubViewport = null
var _camw: Camera3D = null
var _sim_w: AguaSim3D = null


func _es_agua(c: Vector2i) -> bool:
	return _agua.has(c)


func _suelo(c: Vector2i) -> float:
	return ALTO_AGUA - LECHO if _es_agua(c) else ALTO_B


## Un estanque real (AguaSim3D + AguaRender3D, como el juego) con los efectos de hechizo al lado, a la misma escala y con la misma cámara del juego (ortogonal, tamaño 6, 60°).
func _paleta() -> void:
	for x in range(2, 7):
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
		for x in range(10):
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
	_sim_w.configurar(10, 6, 3, S, _suelo, func(_c: Vector2i) -> bool: return false)
	for c in _agua:
		_sim_w.llenar_casilla(c, ALTO_AGUA)
	var r: AguaRender3D = AguaRender3D.new()
	mundo.add_child(r)
	r.enlazar(_sim_w)
	for i in range(60):
		_sim_w.paso(1.0 / 30.0)
		await process_frame
	var suelo_y: float = ALTO_B
	var inc: float = 60.0
	var e_: float = deg_to_rad(90.0 - inc)
	var dircam: Vector3 = -Vector3(0.0, sin(e_), cos(e_))
	var foco: Vector3 = Vector3(6.6 * S, suelo_y, 2.4 * S)
	_camw.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camw.size = 13.0
	_camw.transform = Transform3D(Basis.looking_at(dircam, Vector3.UP), foco - dircam * 40.0)
	# el agua de hechizo, en la tierra de al lado del estanque (x > 7) y sobre él
	var base: Vector3 = Vector3(7.7 * S, suelo_y, 2.2 * S)
	var bola: AguaToy = AguaToy.new()
	bola.definir(AguaToy.Figura.BOLA, 0.4, 0.4, 0.4, false)
	mundo.add_child(bola)
	bola.global_position = Vector3(8.4 * S, suelo_y + 0.8, 3.0 * S)
	var haz: AguaToy = AguaToy.new()
	haz.definir(AguaToy.Figura.HAZ, 1.5, 0.5, 0.15, false)
	mundo.add_child(haz)
	haz.global_position = Vector3(7.2 * S, suelo_y + 0.2, 1.6 * S)
	haz.look_at(haz.global_position + Vector3(1, 0, 0.3), Vector3.UP)
	haz.lanzar(-1.0)
	var gei: AguaToy = AguaToy.new()
	gei.definir(AguaToy.Figura.PILAR, 0.5, 3.0, 0.5, false)
	mundo.add_child(gei)
	gei.global_position = Vector3(8.7 * S, suelo_y, 1.5 * S)
	gei.lanzar(-1.0)
	var bola2: AguaToy = AguaToy.new()
	bola2.definir(AguaToy.Figura.BOLA, 0.4, 0.4, 0.4, false)
	mundo.add_child(bola2)
	bola2.global_position = Vector3(4.4 * S, suelo_y + 0.8, 2.4 * S)       # una bola sobre el propio estanque
	await _seg(1.8)
	_vp.get_texture().get_image().save_png(_dir.path_join("paleta_junto_al_agua_del_mundo.png"))
	r.agua_filtro = false                                  # y el agua del mundo en su versión estándar (la que usa color_somero_est / color_hondo_est directamente)
	await _seg(0.8)
	_vp.get_texture().get_image().save_png(_dir.path_join("paleta_junto_al_agua_del_mundo_estandar.png"))
	r.agua_filtro = true
	# el área y la salpicadura, aparte (junto al agua)
	var imp: ImpactoAguaToy = ImpactoAguaToy.crear(ImpactoAguaToy.Variante.AREA, Vector3.UP, 1.8)
	mundo.add_child(imp)
	imp.global_position = Vector3(8.2 * S, suelo_y, 3.6 * S)
	var sal: ImpactoAguaToy = ImpactoAguaToy.crear(ImpactoAguaToy.Variante.GOLPE, Vector3.UP, 0.4)
	mundo.add_child(sal)
	sal.global_position = Vector3(5.8 * S, suelo_y, 3.9 * S)
	Engine.time_scale = 0.3
	for t in [0.35, 0.8]:
		await process_frame
		while is_instance_valid(imp) and imp.tiempo() < t:
			await process_frame
		_vp.get_texture().get_image().save_png(_dir.path_join("paleta_area_%03d.png" % int(t * 1000.0)))
	Engine.time_scale = 1.0
