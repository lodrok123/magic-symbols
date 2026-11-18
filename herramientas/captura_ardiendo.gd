extends SceneTree

## CAPTURAS DEL ARDIENDO (ArdiendoToy, 18/11/2026): un goblin real (modelo con esqueleto, Combate3D) ardiendo sobre suelo oscuro, cámara a ~3 m. NECESITA VENTANA (sin --headless):
##   godot --path . --script res://herramientas/captura_ardiendo.gd -- <carpeta>
## Guarda: ardiendo_a_solo_pilar.png (antes: solo el pilar de llamas), ardiendo_b_0_6s.png, ardiendo_b_1_4s.png, ardiendo_b_2_5s.png (el efecto nuevo, sin pilar) y ardiendo_c_con_pilar.png
## (el efecto nuevo + el pilar de siempre). No es una prueba.

const TAM: Vector2i = Vector2i(900, 900)
const DIST: float = 3.0

var _carpeta: String = ""
var _raiz: Node3D = null
var _cam: Camera3D = null
var _suelo: MeshInstance3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	_carpeta = a[0] if a.size() > 0 else "user://capturas_ardiendo"
	DirAccess.make_dir_recursive_absolute(_carpeta)
	root.get_window().size = TAM
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var filas: PackedStringArray = []
	for _y in range(10):
		filas.append("..........")
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, {})
	Terreno3D.activar_fuente_casillas()
	_escena()
	var p: Vector3 = Vector3(11.0, Terreno3D.y_pies(Vector2i(5, 5)), 11.0)
	var modelo: Pj3D = Pj3D.new()
	_raiz.add_child(modelo)
	modelo.cargar("goblin_warrior_chibi")
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	modelo.set_alto(0.85)
	modelo.position = p
	var g: Combate3D = Combate3D.equipar(modelo, _raiz, null, null)
	g.altura = 0.85
	g.quieto = true
	g.health = 100000.0
	g.vida_max = 100000.0
	g.position = p
	g.casa = p
	for e in modelo.find_children("*", "Skeleton3D", true, false):
		var sk: Skeleton3D = e as Skeleton3D
		var nombres: PackedStringArray = []
		for i in sk.get_bone_count():
			nombres.append(sk.get_bone_name(i))
		print("HUESOS: ", ", ".join(nombres))
	_cam.look_at_from_position(p + Vector3(0.0, 1.15, DIST), p + Vector3(0, 0.55, 0))
	_suelo.position = Vector3(p.x, p.y, p.z)
	await _esperar(0.8)
	# A: antes, solo el pilar de llamas
	ArdiendoToy.ACTIVO = false
	g.quemando = 1000.0
	VfxReaccion3D.llamas_cuerpo(g, 1.0)
	await _esperar(1.6)
	_foto("ardiendo_a_solo_pilar")
	VfxReaccion3D.apagar_llamas(g)
	g.quemando = 0.0
	await _esperar(1.5)
	# B: el efecto nuevo, sin pilar
	await _esperar(2.0)
	ArdiendoToy.ACTIVO = true
	g.quemando = 1000.0
	var t0: int = Time.get_ticks_msec()
	for par in [[0.15, "ardiendo_b_0_15s"], [0.3, "ardiendo_b_0_3s"], [0.6, "ardiendo_b_0_6s"], [1.4, "ardiendo_b_1_4s"], [2.5, "ardiendo_b_2_5s"]]:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < float(par[0]):
			await process_frame
		_foto(String(par[1]))
		var ee: Variant = g.get_meta(ArdiendoToy.META) if g.has_meta(ArdiendoToy.META) else null
		if ee != null and is_instance_valid(ee):
			print(par[1], " ", (ee as ArdiendoToy).estado(), " intensidad ", ((ee as ArdiendoToy)._mat as ShaderMaterial).get_shader_parameter("intensidad"), " tinte ", g.tinte)
	# C: el efecto nuevo con el pilar de siempre
	VfxReaccion3D.llamas_cuerpo(g, 1.0)
	await _esperar(1.5)
	_foto("ardiendo_c_con_pilar")
	print("CAPTURAS en " + _carpeta)
	quit()


func _esperar(s: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < s:
		await process_frame


func _foto(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_carpeta.path_join(nombre + ".png"))


func _escena() -> void:
	_raiz = Node3D.new()
	root.add_child(_raiz)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.03, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.27, 0.38)
	env.ambient_light_energy = 0.35
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.0
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	_raiz.add_child(we)
	var luna: DirectionalLight3D = DirectionalLight3D.new()
	luna.rotation_degrees = Vector3(-55, 30, 0)
	luna.light_color = Color(0.55, 0.62, 0.85)
	luna.light_energy = 0.25
	_raiz.add_child(luna)
	var suelo: MeshInstance3D = MeshInstance3D.new()
	var pl: PlaneMesh = PlaneMesh.new()
	pl.size = Vector2(30, 30)
	suelo.mesh = pl
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.albedo_color = Color(0.2, 0.19, 0.18)
	sm.roughness = 1.0
	suelo.material_override = sm
	_raiz.add_child(suelo)
	_suelo = suelo
	_cam = Camera3D.new()
	_cam.fov = 42.0
	_raiz.add_child(_cam)
	_cam.current = true
