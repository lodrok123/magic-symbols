class_name SelloRayo
extends Node3D

## SELLO DEL RAYO EN EL SUELO (5/11/2026; referencia en vídeo de Pablo: «Ultimate» = pilar sobre un sello circular, «Area of effect» = sello con descargas). Un círculo mágico de líneas finas con estrella de seis puntas,
## aro doble y corona de marcas, con el perfil de color del rayo del juego (rayo_sello.gdshader: decal que lee la profundidad y sigue el terreno). Se abre del centro al borde en T_ABRIR s, parpadea a saltos
## y se apaga en T_CERRAR s. El origen del nodo es el SUELO bajo el centro.
## Uso:  var s := SelloRayo.crear(radio); padre.add_child(s); s.global_position = suelo   ·   s.cerrar() lo apaga y se libera   ·   `fijar(abre, vida)` lo pone a mano (pruebas y capturas).

const RayoPaleta = preload("res://presentacion/vfx/toy/rayo_paleta.gd")
const SHADER: String = "res://presentacion/vfx/toy/rayo_sello.gdshader"
const GRUPO: String = "sello_rayo"
const ALTO_CAJA: float = 2.4
const CENTRO_Y: float = 0.4
const T_ABRIR: float = 0.10
const T_CERRAR: float = 0.25
const GIRO_RAD_S: float = 0.35

var radio: float = 1.0
var abre: float = 0.0                 ## 0 → 1 (se abre solo)
var vida: float = 1.0                 ## 1 → 0 (se apaga con `cerrar`)
var brillo: float = 1.0
var _t: float = 0.0
var _cerrando: bool = false
var _manual: bool = false
var _caja: MeshInstance3D = null
var _mat: ShaderMaterial = null


static func crear(radio_: float) -> SelloRayo:
	var s := SelloRayo.new()
	s.radio = maxf(radio_, 0.2)
	return s


func _ready() -> void:
	add_to_group(GRUPO)
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER)
	_mat.render_priority = -2
	var pal: Dictionary = RayoPaleta.uniforms()
	for k in pal:
		_mat.set_shader_parameter(k, pal[k])
	_mat.set_shader_parameter("semilla", randf())
	_caja = MeshInstance3D.new()
	_caja.name = "Sello"
	_caja.mesh = caja
	_caja.material_override = _mat
	_caja.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_caja.scale = Vector3(2.0 * radio, ALTO_CAJA, 2.0 * radio)
	_caja.position = Vector3(0.0, CENTRO_Y, 0.0)
	_caja.extra_cull_margin = 2.0
	add_child(_caja)
	_aplicar()


func _process(delta: float) -> void:
	if _manual:
		return
	_t += delta
	if not _cerrando:
		abre = clampf(_t / T_ABRIR, 0.0, 1.0)
	else:
		vida = clampf(vida - delta / T_CERRAR, 0.0, 1.0)
		if vida <= 0.0:
			queue_free()
			return
	_aplicar()


## Se apaga en T_CERRAR s y se libera.
func cerrar() -> void:
	_cerrando = true


## Lo pone a mano (sin animación): abre 0..1, vida 0..1.
func fijar(abre_: float, vida_: float) -> void:
	_manual = true
	abre = clampf(abre_, 0.0, 1.0)
	vida = clampf(vida_, 0.0, 1.0)
	_aplicar()


func _aplicar() -> void:
	if _caja == null:
		return
	var m: ShaderMaterial = _caja.material_override as ShaderMaterial      # se lee cada vez: RayoToy duplica los materiales de sus hijos al recogerlos
	if m == null:
		return
	m.set_shader_parameter("aparece", abre * 1.15)
	m.set_shader_parameter("vida", vida)
	m.set_shader_parameter("brillo", brillo)
	m.set_shader_parameter("giro", _t * GIRO_RAD_S)
	_caja.visible = vida > 0.001 and abre > 0.001
