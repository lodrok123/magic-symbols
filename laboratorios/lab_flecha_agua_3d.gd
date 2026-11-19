extends Node3D

const Flecha = preload("res://laboratorios/vfx_revision/flecha_agua_revision.gd")
var reloj: float = 0.0
var pausa: bool = false
var lenta: bool = false
var repetir: bool = true
var radio: float = 0.4
var camara: Camera3D
var panel: Label
var efectos: Array[Node3D] = []
var vista: int = 2
var azimut: float = 0.0
var elevacion: float = 0.0
var distancia: float = 7.0
var oscuro: bool = false
var suelo: MeshInstance3D
var objetivo: MeshInstance3D

func _ready() -> void:
	var entorno := WorldEnvironment.new()
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color(0.13, 0.17, 0.20)
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(0.68, 0.80, 0.91)
	ambiente.ambient_light_energy = 0.55
	entorno.environment = ambiente
	add_child(entorno)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-52, -35, 0)
	luz.light_energy = 1.2
	add_child(luz)
	suelo = MeshInstance3D.new()
	# Un pequeno espesor hace visible el contacto con el suelo de perfil.
	var plano := BoxMesh.new()
	plano.size = Vector3(25, 0.15, 8)
	suelo.mesh = plano
	suelo.position.y = -0.075
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = "shader_type spatial; uniform float oscuro = 0.0; varying vec3 mundo; void vertex(){mundo=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){float c=mod(floor(mundo.x*2.0)+floor(mundo.z*2.0),2.0); ALBEDO=mix(mix(vec3(0.12,0.16,0.17),vec3(0.23,0.27,0.27),c),vec3(0.035,0.045,0.055),oscuro*0.85); ROUGHNESS=0.85;}"
	suelo.material_override = mat
	add_child(suelo)
	# Objetos opacos detras del agua para reconocer la distorsion al orbitar.
	for x in [-3.0, 3.0]:
		for z in [-3.0, -4.0]:
			var poste := MeshInstance3D.new()
			var caja := BoxMesh.new()
			caja.size = Vector3(0.12, 3.5, 0.12)
			poste.mesh = caja
			poste.position = Vector3(x + 0.75, 1.75, z)
			var color := StandardMaterial3D.new()
			color.albedo_color = Color(0.63, 0.37, 0.18)
			poste.material_override = color
			add_child(poste)
	objetivo = MeshInstance3D.new()
	var bloque := BoxMesh.new()
	bloque.size = Vector3(0.12, 2.4, 1.4)
	objetivo.mesh = bloque
	var material_objetivo := StandardMaterial3D.new()
	material_objetivo.albedo_color = Color(0.28, 0.30, 0.32)
	objetivo.material_override = material_objetivo
	add_child(objetivo)
	camara = Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.fov = 43.0
	camara.near = 0.05
	add_child(camara)
	_actualizar_camara()
	var capa := CanvasLayer.new()
	add_child(capa)
	panel = Label.new()
	panel.position = Vector2(18, 14)
	panel.add_theme_font_size_override("font_size", 16)
	panel.add_theme_color_override("font_shadow_color", Color.BLACK)
	panel.add_theme_constant_override("shadow_offset_x", 2)
	panel.add_theme_constant_override("shadow_offset_y", 2)
	capa.add_child(panel)
	for x in [-3.0, 3.0]:
		var etiqueta := Label3D.new()
		etiqueta.text = "VERTICAL" if x < 0.0 else "HORIZONTAL >"
		etiqueta.position = Vector3(x, 0.1, 2.0)
		etiqueta.font_size = 48
		etiqueta.pixel_size = 0.004
		etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(etiqueta)
	reconstruir()

func reconstruir() -> void:
	for efecto in efectos:
		remove_child(efecto)
		efecto.queue_free()
	efectos.clear()
	for i in 2:
		var efecto := Flecha.new()
		efecto.oblicuo = i == 1
		efecto.horizontal = i == 1
		efecto.radio = radio
		efecto.position.x = -3.0 if i == 0 else 3.0
		add_child(efecto)
		efectos.append(efecto)
	poner_tiempo(0.0)
	objetivo.position = Vector3(3.0 + radio + 0.06, 1.2, 0.0)
	_actualizar_camara()

func poner_tiempo(t: float) -> void:
	reloj = clampf(t, 0.0, Flecha.DURACION)
	for efecto in efectos: efecto.avanzar_a(reloj)

func _process(delta: float) -> void:
	if not pausa:
		var siguiente := reloj + delta * (0.2 if lenta else 1.0)
		if siguiente > Flecha.DURACION and repetir: siguiente = 0.0
		poner_tiempo(siguiente)
	if is_instance_valid(panel):
		panel.text = "FLECHA DE AGUA | nacimiento / vuelo / impacto / deposito\nEspacio pausa | R repetir | S lenta x0.2 | flechas +/- 0.05 s | 1 carga | 2 impacto | 3 charco | 4 vuelo\nL lateral | G angulo de juego | C foco | raton derecho orbita | rueda zoom | F5 fondo | +/- radio | B bucle | H panel\n%.2f s | %s | radio %.2f m | %s\nPrototipo visual: no deposita agua en la simulacion del juego." % [reloj, efectos[0].ultimo_estado.fase, radio, "PAUSA" if pausa else ("LENTA" if lenta else "NORMAL")]

func _actualizar_camara() -> void:
	var centro := Vector3(0, 1.6, 0)
	if vista == 1: centro = Vector3(-3, 1.8, 0)
	if vista == 2: centro = Vector3(1.7, 1.5, 0)
	camara.size = distancia * (0.55 if vista == 0 else 0.72)
	camara.position = centro + Vector3(sin(azimut) * cos(elevacion), sin(elevacion), cos(azimut) * cos(elevacion)) * distancia
	camara.look_at(centro)
	for i in efectos.size(): efectos[i].visible = vista == 0 or i == vista - 1
	if is_instance_valid(objetivo): objetivo.visible = vista != 1
	for hijo in get_children():
		if hijo is Label3D: hijo.visible = vista == 0

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		azimut -= ev.relative.x * 0.006
		elevacion = clampf(elevacion + ev.relative.y * 0.006, 0.0, 1.4)
		_actualizar_camara()
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP: distancia = maxf(2.0, distancia * 0.9)
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN: distancia = minf(24.0, distancia * 1.1)
		_actualizar_camara()
	if not ev is InputEventKey or not ev.pressed or ev.echo: return
	match ev.keycode:
		KEY_SPACE: pausa = not pausa
		KEY_R: poner_tiempo(0.0)
		KEY_S: lenta = not lenta
		KEY_B: repetir = not repetir
		KEY_LEFT: pausa = true; poner_tiempo(reloj - 0.05)
		KEY_RIGHT: pausa = true; poner_tiempo(reloj + 0.05)
		KEY_1: pausa = true; poner_tiempo(0.7)
		KEY_2: pausa = true; poner_tiempo(2.50)
		KEY_3: pausa = true; poner_tiempo(4.0)
		KEY_4: pausa = true; poner_tiempo(1.8)
		KEY_H: panel.visible = not panel.visible
		KEY_L:
			azimut = 0.0
			elevacion = 0.0
			_actualizar_camara()
		KEY_G:
			# Misma proyeccion y elevacion que la vista de juego del laboratorio base.
			azimut = 0.0
			elevacion = deg_to_rad(30.0)
			_actualizar_camara()
		KEY_C:
			vista = (vista + 1) % 3
			distancia = 12.0 if vista == 0 else 7.0
			_actualizar_camara()
		KEY_F5:
			oscuro = not oscuro
			(suelo.material_override as ShaderMaterial).set_shader_parameter("oscuro", 1.0 if oscuro else 0.0)
		KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
			radio = minf(0.65, radio + 0.05)
			reconstruir()
		KEY_MINUS, KEY_KP_SUBTRACT:
			radio = maxf(0.2, radio - 0.05)
			reconstruir()
