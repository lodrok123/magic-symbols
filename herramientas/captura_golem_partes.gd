extends SceneTree
## Fotos del cuerpo del gólem y del núcleo separados (ver separar_golem.gd) y montados. NECESITA VENTANA:
##   Godot --path . --resolution 1280x720 --script res://herramientas/captura_golem_partes.gd
## Salida en res://docs/capturas/golem/: cuerpo_frente, cuerpo_tres_cuartos, nucleo, montado, montado_juego, montado_pecho.

const DIR: String = "res://docs/capturas/golem"
const ALTO_JUEGO: float = 1.7
const ALTO_CUERPO: float = 0.704346                   ## alto del cuerpo tal como sale de separar_golem.gd
## Hueco del pecho medido en el cuerpo centrado (unidades del modelo; ver el informe): centro, radio de la abertura y z de la boca.
const HUECO_CENTRO: Vector3 = Vector3(-0.006, 0.429, 0.09)
const HUECO_RADIO: float = 0.053
const NUCLEO_ALTO_MODELO: float = 0.259               ## alto de nucleo_golem.glb
const NUCLEO_ESCALA: float = 0.85 * 2.0 * HUECO_RADIO / NUCLEO_ALTO_MODELO
var _cam: Camera3D = null


func _initialize() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(DIR)
	_entorno()
	_cam = Camera3D.new()
	_cam.near = 0.05
	_cam.far = 100.0
	root.add_child(_cam)
	var k: float = ALTO_JUEGO / ALTO_CUERPO
	var cuerpo: Node3D = _cargar("golem_piedra_cuerpo")
	cuerpo.scale = Vector3.ONE * k
	_cam.fov = 22.0
	var foco := Vector3(0, ALTO_JUEGO * 0.5, 0)
	_cam.look_at_from_position(foco + Vector3(0, 0.12, 1.0).normalized() * 6.0, foco)
	await _foto("cuerpo_frente")
	_cam.look_at_from_position(foco + Vector3(sin(deg_to_rad(40.0)), 0.12, cos(deg_to_rad(40.0))).normalized() * 6.0, foco)
	await _foto("cuerpo_tres_cuartos")
	# Núcleo solo, grande.
	cuerpo.visible = false
	var nu: Node3D = _cargar("nucleo_golem")
	nu.scale = Vector3.ONE * 5.0
	nu.position = Vector3(0, 0.7, 0)
	_cam.fov = 18.0
	_cam.look_at_from_position(Vector3(0, 0.8, 4.0), Vector3(0, 0.7, 0))
	await _foto("nucleo")
	# Montado.
	cuerpo.visible = true
	nu.scale = Vector3.ONE * NUCLEO_ESCALA * k
	nu.position = HUECO_CENTRO * k
	_cam.fov = 22.0
	_cam.look_at_from_position(foco + Vector3(0, 0.12, 1.0).normalized() * 6.0, foco)
	await _foto("montado")
	_cam.fov = 9.0
	var cp: Vector3 = HUECO_CENTRO * k
	_cam.look_at_from_position(cp + Vector3(0, 0.1, 6.0), cp)
	await _foto("montado_pecho")
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 3.0
	var e: float = deg_to_rad(90.0 - 60.0)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3(0, 0.8, 0) - dir * 40.0)
	await _foto("montado_juego")
	quit(0)


func _cargar(nombre: String) -> Node3D:
	var n: Node3D = (load("res://arte/modelos/%s.glb" % nombre) as PackedScene).instantiate()
	root.add_child(n)
	return n


func _entorno() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.47, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 0.9
	sol.rotation_degrees = Vector3(-40.0, -25.0, 0.0)
	root.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(20, 20)
	suelo.mesh = pl
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.3, 0.32, 0.36)
	suelo.material_override = mt
	root.add_child(suelo)


func _foto(nombre: String) -> void:
	for i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(DIR.path_join(nombre + ".png"))
	print("foto " + nombre)
