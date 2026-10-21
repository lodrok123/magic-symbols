extends SceneTree

## CAPTURA (21/10, rayo de ᛁ `linea`): saca PNG del HAZ de cada elemento en DOS momentos (recién nacido y a pleno) con la cámara del juego, y uno de cerca, para MIRARLOS
## (no es una prueba: la prueba es `prueba_haz.gd`). Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_haz.gd -- docs/capturas/haz
##   godot --path . --script res://herramientas/captura_haz.gd -- docs/capturas/haz hielo        (solo un elemento)
## Escribe <elemento>_juego_1.png (0,18 s), <elemento>_juego_2.png (0,55 s) y <elemento>_cerca.png (0,55 s, cámara a 3,2 u de alto). Dibuja con `VfxElemento3D.haz`, el mismo que usa el juego.

const TAM_JUEGO: Vector2i = Vector2i(1280, 720)     ## 120 px por unidad de juego (cámara de 6 u de alto)
const ELEMENTOS: PackedStringArray = ["hielo", "fuego", "agua", "tierra", "viento", "rayo"]
const ALCANCE_U: float = 6.9                        ## 3 m (una sola ᛁ) × casilla 2,3
const T_1: float = 0.18
const T_2: float = 0.55

var _vp: SubViewport = null
var _mundo: Node3D = null
var _cam: Camera3D = null
var _dir: String = "docs/capturas/haz"
var _solo: String = ""
var _ve: VfxElemento3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	if a.size() > 1:
		_solo = a[1]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	_vp = SubViewport.new()
	_vp.size = TAM_JUEGO
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_cam = Camera3D.new()
	_vp.add_child(_cam)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55, 25, 0)
	luz.light_color = Color(1.0, 0.96, 0.88)
	luz.light_energy = 1.0
	luz.directional_shadow_max_distance = 30.0
	luz.shadow_enabled = true
	_vp.add_child(luz)
	# Luz y entorno COMO LA MAQUETA (igual que captura_assets_elementos.gd)
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.81, 0.91, 0.94)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.95, 0.94, 1.0)
	e.ambient_light_energy = 0.6
	Paleta3D.aplicar_ajuste(e)
	VfxKit3D.activar_glow(e)
	Posproceso3D.aplicar_entorno(e, _vp)
	var we := WorldEnvironment.new()
	we.environment = e
	_vp.add_child(we)
	_mundo = Node3D.new()
	_vp.add_child(_mundo)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 30)
	suelo.mesh = pm
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.45, 0.62, 0.34)
	suelo.material_override = ms
	_mundo.add_child(suelo)
	_ve = VfxElemento3D.new()
	_mundo.add_child(_ve)
	_ve._mundo = _mundo
	_ve.casilla = 2.3
	await _esperar(0.3)
	for el in ELEMENTOS:
		if _solo != "" and _solo != el:
			continue
		await _caso(el)
	print("capturas en ", _dir)
	quit()


func _caso(el: String) -> void:
	_limpiar()
	var jug := Vector3(-4.2, 0.0, 0.0)
	_referencia(jug)
	var desde: Vector3 = jug + Vector3(0.4, 0.9, 0.0)
	var hasta: Vector3 = jug + Vector3(ALCANCE_U, 0.1, 0.0)
	var vida: float = Hechizo.HAZ_DURA_S
	_camara_juego(Vector3(-0.8, 0.5, 0.0), 6.0)
	_ve.haz(el, desde, hasta, vida, Hechizo.HAZ_ANCHO * 2.3, 0.0)
	await _esperar(T_1)
	await _foto("%s_juego_1" % el)
	await _esperar(T_2 - T_1)
	await _foto("%s_juego_2" % el)
	_camara_juego(Vector3(-0.8, 0.5, 0.0), 3.2)
	await _foto("%s_cerca" % el)
	await _esperar(1.6)


func _camara_juego(mira: Vector3, tam: float) -> void:
	_vp.size = TAM_JUEGO
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = tam
	_cam.near = 0.1
	_cam.far = 300.0
	var e: float = deg_to_rad(90.0 - 60.0)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), mira - dir * 40.0)
	_cam.current = true


func _referencia(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.25
	cm.height = 1.0
	mi.mesh = cm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.85, 0.35, 0.55)
	mi.material_override = mt
	_mundo.add_child(mi)
	mi.position = pos + Vector3(0.0, 0.5, 0.0)


func _esperar(s: float) -> void:
	await create_timer(maxf(s, 0.02)).timeout
	await process_frame


func _foto(nombre: String) -> void:
	await process_frame
	var ruta: String = "%s/%s.png" % [_dir, nombre]
	_vp.get_texture().get_image().save_png(ruta)
	print("guardado ", ruta)


func _limpiar() -> void:
	for c in _mundo.get_children():
		if c == _ve or (c is MeshInstance3D and (c as MeshInstance3D).mesh is PlaneMesh):
			continue
		c.queue_free()
