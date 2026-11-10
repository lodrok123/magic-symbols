extends SceneTree
## GARANTIA DE LA EROSION DEL AGUA (8/11/2026): con VfxKit3D.usar_erosion apagado, los shaders de agua con erosion (esfera, esfera_atras, cinta) dan EXACTAMENTE lo de antes, y con la
## erosion encendida pero vida = 1 (avance 0) tambien. Dibuja cada shader con parametros fijos y semilla fija y escribe el md5 de la imagen: se compara entre dos arboles (HEAD y el de trabajo).
##   godot --rendering-driver opengl3 --fixed-fps 60 --path . --script res://herramientas/prueba_agua_erosion_apagada.gd -- <indice 0..5>   (un proceso por caso: TIME es global y cambiaria entre casos)
const AguaMallas = preload("res://presentacion/vfx/toy/agua_mallas.gd")
const CASOS: Array = [["esfera", false, 1.0], ["esfera", true, 1.0], ["esfera_atras", false, 1.0], ["esfera_atras", true, 1.0], ["cinta", false, 1.0], ["cinta", true, 1.0]]

var _vp: SubViewport
var _mi: MeshInstance3D
var _caso: int = -1
var _f: int = 0
var _solo: int = -1


func _initialize() -> void:
	_solo = int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else -1
	_caso = _solo - 1 if _solo >= 0 else -1
	_vp = SubViewport.new()
	_vp.size = Vector2i(256, 256)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.2
	_vp.add_child(cam)
	cam.position = Vector3(0, 0, 3)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.34, 0.3)
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	_mi = MeshInstance3D.new()
	_vp.add_child(_mi)


func _siguiente() -> void:
	_caso += 1
	if _caso >= CASOS.size() or (_solo >= 0 and _caso != _solo):
		quit()
		return
	var c: Array = CASOS[_caso]
	RenderingServer.global_shader_parameter_set("usar_erosion", bool(c[1]))       # directo al global: asi la prueba tambien corre en un arbol sin VfxKit3D.usar_erosion (HEAD)
	var nombre: String = c[0]
	if nombre == "cinta":
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 0.3)
		_mi.mesh = q
		_mi.material_override = AguaMallas.material(AguaMallas.SH_CINTA, {"fase": 0.3, "opacidad": 0.8, "vida": float(c[2])}, 0)
	else:
		var s := SphereMesh.new()
		s.radius = 0.4
		s.height = 0.8
		_mi.mesh = s
		var sh: String = AguaMallas.SH_ESFERA if nombre == "esfera" else AguaMallas.SH_ESFERA_ATRAS
		_mi.material_override = AguaMallas.material(sh, {"radio": 0.4, "semilla": 0.37, "vida": float(c[2])}, 0)
	_f = 0


func _process(_d: float) -> bool:
	if _f == 0 and _mi.mesh == null:
		_siguiente()
		return false
	_f += 1
	if _f == 6:
		var img: Image = _vp.get_texture().get_image()
		print(CASOS[_caso][0], " erosion=", CASOS[_caso][1], " vida=", CASOS[_caso][2], " md5=", img.get_data().hex_encode().md5_text())
		_siguiente()
	return false
