extends Node3D
## Escenario de prueba del titán (14/10). Un valle de 25×25 casillas con el río con un puente, las casas-cueva y el
## titán (Titan3D) sentado al norte con los pies en el valle, todo visto con la cámara REAL del juego: ortogonal, 60° de inclinación, 40 u de retroceso,
## far 300, zoom inicial 6 y máximo 60, giro de 90° en 90°. Sirve para decidir si el titán se lee y qué ajustar. NO es un nivel.
##   Mover: WASD (relativo a la cámara) · Giro: Z / C · Zoom: rueda · Vistas: 1 inicio, 2 junto al pie, 3 mirador, 4 por detrás del titán
##   Titán: R vuelve a generarlo con otra semilla · O abre/cierra los ojos
## Se lanza con la escena `escenas/PruebaTitan.tscn` (F6). Sin sonido ni combate.

const S: float = 2.3                                   ## casilla
const LADO: float = 25.0 * 2.3
const INCLINACION: float = 60.0
const RETROCESO: float = 40.0
const ZOOM_INICIAL: float = 6.0
const ZOOM_MAX: float = 60.0
const ZOOM_MIN: float = 3.0
const VEL_HEROE: float = 3.0

var titan: Titan3D = null
var heroe: MeshInstance3D = null
var cam: Camera3D = null
var _zoom: float = ZOOM_INICIAL
var _giro: int = 0                                    ## cuartos de vuelta
var _foco_extra_y: float = 0.0                        ## para el mirador: la cámara mira más alto
var _foco_libre: Variant = null                       ## si no es null, la cámara mira ahí en vez de al héroe


func _ready() -> void:
	_entorno()
	_valle()
	titan = Titan3D.new()
	titan.position = Vector3(0, 0, -LADO * 0.5)
	add_child(titan)
	heroe = _caja(Vector3(0, 0.5, 4), Vector3(0.5, 1.0, 0.5), Color(0.9, 0.1, 0.1))
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.1
	cam.far = 300.0
	add_child(cam)
	cam.current = true
	_colocar_camara()


func _process(delta: float) -> void:
	var d := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): d.z -= 1.0
	if Input.is_key_pressed(KEY_S): d.z += 1.0
	if Input.is_key_pressed(KEY_A): d.x -= 1.0
	if Input.is_key_pressed(KEY_D): d.x += 1.0
	if d != Vector3.ZERO:
		_foco_libre = null
		d = Basis(Vector3.UP, -_giro * PI * 0.5) * d.normalized()
		heroe.position += d * VEL_HEROE * delta
	_colocar_camara()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var b: int = (ev as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(ZOOM_MIN, _zoom / 1.15)
		elif b == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(ZOOM_MAX, _zoom * 1.15)
	elif ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo:
		match (ev as InputEventKey).keycode:
			KEY_Z: _giro = (_giro + 1) % 4
			KEY_C: _giro = (_giro + 3) % 4
			KEY_1: poner_vista(heroe.position, ZOOM_INICIAL, _giro)
			KEY_2: poner_vista(Vector3(0, 5.0, -LADO * 0.5 + 6), 20.0, _giro)       # junto a los pies
			KEY_3: poner_vista(Vector3(0, 30.0, -LADO * 0.5 - 40), ZOOM_MAX, _giro)   # mirador: el cuerpo entero
			KEY_4: poner_vista(Vector3(0, 30.0, -LADO * 0.5 - 85), 40.0, 2)      # por detrás del titán, mirando al sur
			KEY_R:
				titan.semilla = randi() % 1000
				titan.construir()
			KEY_O:
				titan.ojos_abiertos = not titan.ojos_abiertos
				titan.construir()


## Pone la cámara mirando a `foco` (libre del héroe) con ese zoom y ese giro. Lo usan las teclas 1-4 y las capturas de prueba.
func poner_vista(foco: Vector3, zoom: float, giro: int) -> void:
	_foco_libre = foco
	_zoom = clampf(zoom, ZOOM_MIN, ZOOM_MAX)
	_giro = giro % 4
	_colocar_camara()


func _colocar_camara() -> void:
	if cam == null:
		return
	var foco: Vector3 = (_foco_libre as Vector3) if _foco_libre != null else heroe.position
	cam.size = _zoom
	var e: float = deg_to_rad(90.0 - INCLINACION)
	var dir: Vector3 = Basis(Vector3.UP, _giro * PI * 0.5) * (-Vector3(0.0, sin(e), cos(e)))
	cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * RETROCESO)


func _entorno() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.81, 0.91, 0.94)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.94, 1.0)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55, 25, 0)
	sol.light_color = Color(1, 0.96, 0.88)
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 300.0
	add_child(sol)


func _caja(pos: Vector3, tam: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi


func _valle() -> void:
	_caja(Vector3(0, -0.1, 0), Vector3(LADO, 0.2, LADO), Color(0.45, 0.55, 0.3))
	_caja(Vector3(0, -0.1, -LADO * 0.5 - 75.0), Vector3(LADO * 2.4, 0.2, 150.0), Color(0.40, 0.48, 0.28))   # el suelo bajo el titán
	_caja(Vector3(0, 0.02, LADO * 0.32), Vector3(LADO, 0.1, 5.0), Color(0.3, 0.5, 0.7))              # el río
	for i in 5:                                                                                       # casas-cueva en la ladera oeste
		_caja(Vector3(-LADO * 0.3, 1.5, -LADO * 0.3 + i * 6.0), Vector3(5.0, 3.0, 4.6), Color(0.62, 0.5, 0.36))
	_puente(Vector3(0, 0, LADO * 0.32))                                                                # el puente de piedra sobre el río
	# Montes de los otros tres lados, con la misma roca del titán: así el giro de cámara no enseña el vacío.
	for k in 4:
		_monte(Vector3(-LADO * 0.5 - 14, 8, -LADO * 0.3 + k * 18), Vector3(14, 9, 12), 100 + k)
		_monte(Vector3(LADO * 0.5 + 14, 8, -LADO * 0.3 + k * 18), Vector3(14, 9, 12), 200 + k)
	for k in 3:
		_monte(Vector3(-24 + k * 24, 6, LADO * 0.5 + 14), Vector3(14, 7, 10), 300 + k)


## Puente de piedra sobre el río (de la ilustración): calzada, dos pretiles y tres pilares. Cajas, sin arcos.
func _puente(c: Vector3) -> void:
	var piedra := Color(0.52, 0.48, 0.42)
	_caja(c + Vector3(0, 0.55, 0), Vector3(3.2, 0.4, 7.4), piedra)
	for sx in [-1.0, 1.0]:
		_caja(c + Vector3(sx * 1.5, 1.0, 0), Vector3(0.3, 0.7, 7.4), piedra)
	for k in [-1.0, 0.0, 1.0]:
		_caja(c + Vector3(0, 0.2, k * 2.6), Vector3(3.0, 0.6, 0.8), piedra)


func _monte(pos: Vector3, radios: Vector3, semilla: int) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Titan3D.malla_blob(radios, semilla, 0.18, 32, Color(0.36, 0.44, 0.22), Color(0.48, 0.45, 0.38))
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mi.material_override = m
	mi.position = pos
	add_child(mi)
