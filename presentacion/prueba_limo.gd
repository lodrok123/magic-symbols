extends Node3D
## Escena de muestra del LIMO ELEMENTAL (E1, prototipo visual, 27/10). Ábrela con F6.
## Fila de siete limos (neutro, fuego, agua, rayo, hielo congelado, uno pequeño y uno GRANDE de fuego) y, delante, el «limo de pruebas» sobre el que
## actúan las teclas. Cámara con la misma inclinación (60°) y proyección ortogonal que `PruebaTest2`.

const INCLINACION: float = 60.0
const TAM_CAMARA: float = 6.0
const SEPARACION: float = 1.7
const CASILLA: float = 2.3

var limos: Array[LimoVisual3D] = []
var principal: LimoVisual3D = null
var grande: LimoVisual3D = null
var camara: Camera3D = null
var _foco: Vector3 = Vector3(-0.4, 0.3, 0.0)
var _rotulo: Label = null


func _ready() -> void:
	_entorno()
	_suelo()
	_camara()
	var fila: Array = [["", 1.0, false, -4.7], ["fuego", 1.0, false, -3.3], ["agua", 1.0, false, -1.9], ["rayo", 1.0, false, -0.5], ["hielo", 1.0, true, 0.9], ["", 0.6, false, 2.1], ["fuego", 1.6, false, 3.9]]
	for i in fila.size():
		var l := LimoVisual3D.new()
		l.tamano = fila[i][1]
		add_child(l)
		l.position = Vector3(fila[i][3], 0.0, -1.0)
		l.cargar(fila[i][0])
		if fila[i][2]:
			l.congelar(true)
		limos.append(l)
		if fila[i][1] > 1.5:
			grande = l
	principal = LimoVisual3D.new()
	add_child(principal)
	principal.position = Vector3(0.0, 0.0, 1.6)
	limos.append(principal)
	_interfaz()


func _entorno() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.05, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.52, 0.72)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_color = Color(0.85, 0.92, 1.0)
	sol.light_energy = 0.9
	sol.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sol.shadow_enabled = true
	add_child(sol)
	var cal := OmniLight3D.new()                       # un toque cálido de lado, como las antorchas de la Cueva
	cal.light_color = Color(1.0, 0.7, 0.4)
	cal.light_energy = 1.3
	cal.omni_range = 7.0
	cal.position = Vector3(-3.5, 1.6, 1.5)
	add_child(cal)


func _suelo() -> void:
	var base := MeshInstance3D.new()                   # fondo de las juntas entre losas
	var pl := BoxMesh.new()
	pl.size = Vector3(40.0, 0.2, 40.0)
	base.mesh = pl
	var mb := StandardMaterial3D.new()
	mb.albedo_color = Color(0.2, 0.22, 0.28)
	mb.roughness = 1.0
	base.material_override = mb
	base.position = Vector3(0.0, -0.4, 0.0)
	add_child(base)
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for iz in range(-3, 4):
		for ix in range(-6, 7):
			var m := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(CASILLA - 0.02, 0.3, CASILLA - 0.02)
			m.mesh = b
			var mat := StandardMaterial3D.new()
			var g: float = rng.randf_range(0.85, 1.1)
			mat.albedo_color = Color(0.26, 0.28, 0.33) * g
			mat.roughness = 0.95
			m.material_override = mat
			m.position = Vector3(ix * CASILLA, -0.15, iz * CASILLA)
			add_child(m)


func _camara() -> void:
	camara = Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = TAM_CAMARA
	camara.near = 0.1
	camara.far = 300.0
	add_child(camara)
	enfocar(_foco, TAM_CAMARA, INCLINACION)
	camara.current = true


## Mismo cálculo que `PruebaTest2._colocar_camara`: `incl` es la inclinación (60° = la del juego; 90° = cenital).
func enfocar(foco: Vector3, tam: float, incl: float) -> void:
	camara.size = tam
	var e: float = deg_to_rad(90.0 - incl)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	camara.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 40.0)


func _interfaz() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	_rotulo = Label.new()
	_rotulo.text = "LIMO (prueba visual)   limo de pruebas = el de delante\n1 fuego · 2 agua · 3 rayo · 4 hielo · 5 tierra · 0 neutro · repite el mismo: crece\nEspacio saltar · G golpe · D dividir (grande→2 normales, normal→2 pequeños) · C congelar / descongelar"
	_rotulo.position = Vector2(16.0, 12.0)
	_rotulo.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	_rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_rotulo.add_theme_constant_override("outline_size", 5)
	capa.add_child(_rotulo)


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	var k: Key = (ev as InputEventKey).keycode
	match k:
		KEY_1: principal.cargar("fuego")
		KEY_2: principal.cargar("agua")
		KEY_3: principal.cargar("rayo")
		KEY_4: principal.cargar("hielo")
		KEY_5: principal.cargar("tierra")
		KEY_0: principal.cargar("")
		KEY_SPACE:
			principal.saltar(Vector3.RIGHT if principal.position.x < 3.0 else Vector3.LEFT)
		KEY_G: principal.golpe()
		KEY_D:
			if principal.hijos.is_empty():
				principal.dividir()
			else:
				principal.reunir()
		KEY_C: principal.congelar(not principal.esta_congelado())
