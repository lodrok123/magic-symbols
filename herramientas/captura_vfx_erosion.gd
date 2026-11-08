extends SceneTree
## Las cuatro bolas (agua, fuego, hielo, rayo) en filas, una columna por valor de `vida` (1 -> 0), con la erosion apagada o encendida.
## godot --rendering-driver opengl3 --fixed-fps 60 --path . --script <este> -- <prefijo_png> <0|1 erosion> [escala dureza ancho (override de los 4)]
const AguaMallas = preload("res://presentacion/vfx/toy/agua_mallas.gd")
const HieloMallas = preload("res://presentacion/vfx/toy/hielo_mallas.gd")
const RayoTrazos = preload("res://presentacion/vfx/toy/rayo_trazos.gd")
const VIDAS: Array = [1.0, 0.85, 0.65, 0.45, 0.25, 0.08]
var _vp: SubViewport
var _frame: int = 0
var _pref: String = ""

func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	_pref = a[0]
	VfxKit3D.usar_erosion = a[1] == "1"
	_vp = SubViewport.new()
	_vp.size = Vector2i(1560, 1040)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var mundo := Node3D.new()
	_vp.add_child(mundo)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 10.4
	mundo.add_child(cam)
	cam.position = Vector3(7.8, 5.2, 12.0)
	cam.current = true
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.30, 0.34, 0.30)
	var we := WorldEnvironment.new()
	we.environment = env
	mundo.add_child(we)
	var fuego := FuegoToy.new()
	mundo.add_child(fuego)
	for c in range(VIDAS.size()):
		var v: float = VIDAS[c]
		var x: float = 1.3 + c * 2.6
		# fila 0 (arriba): agua
		var sm := SphereMesh.new()
		sm.radius = 0.4
		sm.height = 0.8
		var m0 := MeshInstance3D.new()
		m0.mesh = sm
		m0.material_override = AguaMallas.material(AguaMallas.SH_ESFERA, {"vida": v})
		m0.scale = Vector3(2.4, 2.4, 2.4)
		m0.position = Vector3(x, 9.1, 0)
		mundo.add_child(m0)
		# fila 1: fuego
		var q := QuadMesh.new()
		q.size = Vector2(2.4, 2.4)
		var m1 := MeshInstance3D.new()
		m1.mesh = q
		m1.material_override = fuego._mat_fuego(FuegoToy.SH_BOLA, {"semilla": 0.3, "tam": 2.4, "radio": 0.52, "desplaza": 0.1, "vida": v, "suave_prof": 0.0}, 0, FuegoToy._rampa_de_bola())
		m1.position = Vector3(x, 6.5, 0)
		mundo.add_child(m1)
		# fila 2: hielo
		var m2 := MeshInstance3D.new()
		m2.mesh = HieloMallas.cristal(6, 1.0)
		m2.material_override = HieloMallas.material(HieloMallas.SH_CRISTAL, {"opacidad": 0.68, "vida": v})
		m2.scale = Vector3(0.9, 1.7, 0.9)
		m2.position = Vector3(x, 3.4, 0)
		mundo.add_child(m2)
		# fila 3: rayo
		var m3: MeshInstance3D = RayoTrazos.crear_esfera("E", 0)
		(m3.material_override as ShaderMaterial).set_shader_parameter("vida", v)
		m3.scale = Vector3(1.0, 1.0, 1.0)
		m3.position = Vector3(x, 1.3, 0)
		mundo.add_child(m3)
	var a2: PackedStringArray = OS.get_cmdline_user_args()
	if a2.size() >= 5:
		var arr: Array = []
		_buscar(mundo, arr)
		for mat in arr:
			(mat as ShaderMaterial).set_shader_parameter("ero_escala", float(a2[2]))
			(mat as ShaderMaterial).set_shader_parameter("ero_dureza", float(a2[3]))
			(mat as ShaderMaterial).set_shader_parameter("ero_ancho", float(a2[4]))

func _buscar(n: Node, arr: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).material_override is ShaderMaterial:
		arr.append((n as MeshInstance3D).material_override)
	for c in n.get_children():
		_buscar(c, arr)

func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 10:
		_vp.get_texture().get_image().save_png(_pref)
		quit()
	return false
