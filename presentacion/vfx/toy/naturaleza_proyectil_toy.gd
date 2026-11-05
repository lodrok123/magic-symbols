class_name NaturalezaProyectilToy
extends Node3D

## BOLA DE NATURALEZA «TOY» (5/11/2026; referencia: el proyectil verde de un paquete comercial de VFX, solo como idea; todo procedural). Es el aspecto de la `BolaVeneno3D` del chamán goblin:
## un NÚCLEO claro en bandas (naturaleza_esfera.gdshader), un cuerpo verde más grande y tenue, un halo blando y tres hojitas que giran alrededor de la cabeza. Detrás deja una ESTELA que
## sigue el arco (una cadena de manchas blandas que se encogen: `NaturalezaManchas`) y suelta HOJAS que se quedan en el aire y caen balanceándose, y se apagan (`NaturalezaHojas`).
## Al caer, `estallar` hace un pequeño surtidor de hojas, un destello y un anillo en el suelo; `dispersar` es lo mismo en pequeño (la burbuja del lanzador la para en el aire).
## No decide nada del juego: la lógica (arco, aviso, daño, veneno, nube) sigue siendo de `BolaVeneno3D`. Se monta con `montar(color, suelo_y)`.

const PASO_ESTELA: float = 0.035                ## m entre dos manchas de la estela
const VIDA_ESTELA: float = 0.5
const CADA_HOJA: float = 0.05                  ## s entre dos hojas sueltas en vuelo
const MAX_HOJAS: int = 56
const MAX_MANCHAS: int = 110
const N_HOJAS_ORBITA: int = 3

var color: Color = Color(0.55, 0.92, 0.3)
var en_vuelo: bool = true
var cuerpo: Node3D = null                       ## núcleo + cuerpo + halo (se oculta al caer; las hojas y la estela siguen)
var hojas: NaturalezaHojas = null
var manchas: NaturalezaManchas = null
var _mat_nucleo: ShaderMaterial = null
var _anillo: MeshInstance3D = null
var _mat_anillo: ShaderMaterial = null
var _t_anillo: float = -1.0
var _radio_anillo: float = 1.9
var _t: float = 0.0
var _ultima: Vector3 = Vector3.ZERO
var _tiene_ultima: bool = false
var _acum: float = 0.0
var _t_hoja: float = 0.0
var _orbita: Array = []
var _estallos: int = 0


func montar(p_color: Color, suelo_y: float = -1.0e9) -> void:
	color = p_color
	cuerpo = Node3D.new()
	cuerpo.name = "Cuerpo"
	add_child(cuerpo)
	# cuerpo verde tenue (mayor que el núcleo)
	cuerpo.add_child(_esfera(0.20, color.darkened(0.05), Color(0.16, 0.52, 0.2), Color(0.55, 0.92, 0.3), 0.12, 0.5, 0.0))
	# núcleo claro en bandas
	var nucleo: MeshInstance3D = _esfera(0.115, Color(0.88, 1.0, 0.7), color, Color(0.18, 0.56, 0.22), 1.0, 1.0, 1.0)
	nucleo.name = "Nucleo"
	_mat_nucleo = nucleo.material_override as ShaderMaterial
	cuerpo.add_child(nucleo)
	# halo blando de cartel
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	var q := QuadMesh.new()
	q.size = Vector2(0.78, 0.78)
	halo.mesh = q
	var mh := ShaderMaterial.new()
	mh.shader = load("res://presentacion/vfx/toy/naturaleza_blob.gdshader") as Shader
	mh.set_shader_parameter("nucleo", 0.0)
	mh.set_shader_parameter("blandura", 0.9)
	halo.material_override = mh
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cuerpo.add_child(halo)
	mh.set_shader_parameter("modulo", Color(color.r, color.g, color.b, 0.32))
	hojas = NaturalezaHojas.new()
	hojas.name = "Hojas"
	add_child(hojas)
	hojas.montar(MAX_HOJAS)
	hojas.suelo_y = suelo_y
	manchas = NaturalezaManchas.new()
	manchas.name = "Estela"
	add_child(manchas)
	manchas.montar(MAX_MANCHAS, 0.0, 0.75)
	for i in N_HOJAS_ORBITA:
		var fase: float = float(i) / float(N_HOJAS_ORBITA) * TAU
		var col: Color = NaturalezaHojas.PALETA_VERDES[(i + 1) % NaturalezaHojas.PALETA_VERDES.size()]
		_orbita.append(hojas.emitir_atada(func() -> Vector3: return _pos_orbita(fase), 0.085, col))
	_anillo = MeshInstance3D.new()
	_anillo.name = "Anillo"
	var qa := QuadMesh.new()
	qa.size = Vector2(1.0, 1.0)
	qa.orientation = PlaneMesh.FACE_Y
	_anillo.mesh = qa
	_mat_anillo = ShaderMaterial.new()
	_mat_anillo.shader = load("res://presentacion/vfx/toy/naturaleza_blob.gdshader") as Shader
	_mat_anillo.set_shader_parameter("cartel", false)
	_mat_anillo.set_shader_parameter("anillo", 1.0)
	_mat_anillo.set_shader_parameter("blandura", 0.5)
	_anillo.material_override = _mat_anillo
	_anillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anillo.top_level = true
	_anillo.visible = false
	add_child(_anillo)


func _esfera(radio: float, c_centro: Color, c_medio: Color, c_borde: Color, a_centro: float, a_borde: float, bandas: float) -> MeshInstance3D:
	var esf := SphereMesh.new()
	esf.radius = radio
	esf.height = radio * 2.0
	esf.radial_segments = 16
	esf.rings = 8
	var m := ShaderMaterial.new()
	m.shader = load("res://presentacion/vfx/toy/naturaleza_esfera.gdshader") as Shader
	m.set_shader_parameter("color_centro", Vector3(c_centro.r, c_centro.g, c_centro.b))
	m.set_shader_parameter("color_medio", Vector3(c_medio.r, c_medio.g, c_medio.b))
	m.set_shader_parameter("color_borde", Vector3(c_borde.r, c_borde.g, c_borde.b))
	m.set_shader_parameter("alfa_centro", a_centro)
	m.set_shader_parameter("alfa_borde", a_borde)
	m.set_shader_parameter("bandas", bandas)
	var mi := MeshInstance3D.new()
	mi.mesh = esf
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _pos_orbita(fase: float) -> Vector3:
	var a: float = _t * 7.0 + fase
	return global_position + Vector3(cos(a) * 0.19, sin(a * 1.3 + fase) * 0.09, sin(a) * 0.19)


func _process(delta: float) -> void:
	if cuerpo == null:
		return
	_t += delta
	if _mat_nucleo != null:
		var pulso: float = 1.0 + 0.06 * sin(_t * 14.0)
		cuerpo.scale = Vector3.ONE * pulso
	if en_vuelo:
		_vuelo(delta)
	if _t_anillo >= 0.0:
		_t_anillo += delta
		var k: float = clampf(_t_anillo / 0.42, 0.0, 1.0)
		_anillo.scale = Vector3.ONE * _radio_anillo * lerpf(0.25, 1.0, 1.0 - pow(1.0 - k, 2.0))
		_mat_anillo.set_shader_parameter("modulo", Color(0.6, 0.95, 0.4, 0.8 * (1.0 - k)))
		if k >= 1.0:
			_t_anillo = -1.0
			_anillo.visible = false


func _vuelo(delta: float) -> void:
	var p: Vector3 = global_position
	if not _tiene_ultima:
		_ultima = p
		_tiene_ultima = true
	var d: Vector3 = p - _ultima
	var dist: float = d.length()
	_acum += dist
	if dist > 0.0001:
		var dir: Vector3 = d / dist
		var n: int = 0
		while _acum >= PASO_ESTELA and n < 6:
			_acum -= PASO_ESTELA
			n += 1
			var q: Vector3 = p - dir * _acum
			manchas.emitir(q, Vector3.ZERO, VIDA_ESTELA, 0.2, 0.02, Color(0.5, 0.88, 0.32), Color(0.1, 0.42, 0.18), 0.5)
		_t_hoja += delta
		if _t_hoja >= CADA_HOJA:
			_t_hoja = 0.0
			var alr := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.06
			var v := -dir * 0.35 + Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.5), randf_range(-0.3, 0.3))
			hojas.emitir(p + alr, v, randf_range(1.0, 1.5), randf_range(0.085, 0.14), NaturalezaHojas.color_aleatorio())
	_ultima = p


## Cuántos segundos faltan para que no quede ni hoja ni mancha (la bola espera esto antes de liberarse).
func restante() -> float:
	var r: float = 0.0
	for h in hojas.estados():
		var hd: Dictionary = h
		if not bool(hd["atada"]):
			r = maxf(r, float(hd["vida"]) - float(hd["edad"]))
	for m in manchas.estados():
		var md: Dictionary = m
		r = maxf(r, float(md["vida"]) - float(md["edad"]))
	if _t_anillo >= 0.0:
		r = maxf(r, 0.42 - _t_anillo)
	return r


func _soltar_orbita() -> void:
	for i in _orbita:
		hojas.soltar(int(i), Vector3(randf_range(-0.8, 0.8), randf_range(0.2, 1.0), randf_range(-0.8, 0.8)))
	_orbita.clear()


func _ocultar_cuerpo() -> void:
	en_vuelo = false
	if cuerpo != null:
		cuerpo.visible = false


## La bola cae en `pos`: surtidor de hojas, destello y anillo en el suelo.
func estallar(pos: Vector3, radio: float = 0.9) -> void:
	_estallos += 1
	_soltar_orbita()
	_ocultar_cuerpo()
	manchas.emitir(pos + Vector3(0, 0.12, 0), Vector3.ZERO, 0.26, 0.4, 1.35, Color(0.7, 1.0, 0.5), Color(0.3, 0.8, 0.3), 0.85)
	for i in 7:
		var a: float = randf() * TAU
		manchas.emitir(pos + Vector3(0, 0.1, 0), Vector3(cos(a), randf_range(1.2, 2.4), sin(a)) * randf_range(0.5, 1.1), randf_range(0.35, 0.55), 0.13, 0.02, Color(0.75, 1.0, 0.55), Color(0.2, 0.6, 0.25), 0.8, 4.0)
	for i in 20:
		var a: float = randf() * TAU
		var fuera: float = randf_range(0.7, 2.0)
		var v := Vector3(cos(a) * fuera, randf_range(1.8, 3.4), sin(a) * fuera)
		hojas.emitir(pos + Vector3(0, 0.1, 0), v, randf_range(1.0, 1.6), randf_range(0.09, 0.17), NaturalezaHojas.color_aleatorio())
	_anillo.global_position = Vector3(pos.x, pos.y + 0.05, pos.z)
	_radio_anillo = radio * 2.1
	_anillo.scale = Vector3.ONE * _radio_anillo * 0.25
	_mat_anillo.set_shader_parameter("modulo", Color(0.6, 0.95, 0.4, 0.8))
	_anillo.visible = true
	_t_anillo = 0.0


## La bola se para en el aire (burbuja del lanzador): unas hojas que saltan y se acabó.
func dispersar(pos: Vector3) -> void:
	_estallos += 1
	_soltar_orbita()
	_ocultar_cuerpo()
	manchas.emitir(pos, Vector3.ZERO, 0.2, 0.3, 0.8, Color(0.7, 1.0, 0.5), Color(0.3, 0.8, 0.3), 0.7)
	for i in 9:
		var v := Vector3(randf_range(-1, 1), randf_range(0.2, 1.6), randf_range(-1, 1)) * 1.1
		hojas.emitir(pos, v, randf_range(0.8, 1.3), randf_range(0.08, 0.14), NaturalezaHojas.color_aleatorio())


func estallos() -> int:
	return _estallos
