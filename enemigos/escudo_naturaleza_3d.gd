class_name EscudoNaturaleza3D
extends Node3D

## ESCUDO DE NATURALEZA (28/10; Pablo: la onda verde del chamán lo pone a los aliados que alcanza): una burbuja verde de hojas sobre un `Combate3D` que absorbe VIDA daño y se acaba.
## Distinto del `Escudo3D` del goblin guerrero (el disco de madera del brazo, solo de frente): este cubre por todos lados. El FUEGO lo quema de un golpe (se consume entero, también el
## daño de ese golpe) y el agua no le hace nada. Lo consulta `Combate3D.receive_damage` (`escudo_natural`): `absorber(cantidad, elemento)` devuelve el daño que sí pasa.
## Se pone con `EscudoNaturaleza3D.poner(combate)`: si ya llevaba uno lo rellena. Señal `roto(causa)` («golpes» | «fuego») al acabarse.

signal roto(causa: String)

const VIDA: float = 25.0                        ## daño que absorbe
const COLOR: Color = Color(0.35, 1.0, 0.45)
const COLOR_ROTO: Color = Color(0.9, 0.5, 0.2)
const T_ROTURA: float = 0.45

var combate: Combate3D = null
var vida: float = VIDA
var vida_max: float = VIDA
var estado: String = "activo"                   ## activo · roto · quemado
var absorbidos: float = 0.0                     ## daño total absorbido (pruebas)
var _malla: MeshInstance3D = null
var _mat: StandardMaterial3D = null
var _t: float = 0.0
var _t_rotura: float = 0.0


## Pone (o rellena) el escudo de `c`. Devuelve el escudo.
static func poner(c: Combate3D) -> EscudoNaturaleza3D:
	if c == null or c.muerto:
		return null
	if c.escudo_natural != null and is_instance_valid(c.escudo_natural) and c.escudo_natural.estado == "activo":
		c.escudo_natural.vida = c.escudo_natural.vida_max
		return c.escudo_natural
	var e := EscudoNaturaleza3D.new()
	e.name = "EscudoNaturaleza"
	e.combate = c
	c.add_child(e)
	c.escudo_natural = e
	e._construir()
	return e


func activo() -> bool:
	return estado == "activo" and vida > 0.0


func _construir() -> void:
	var alto: float = maxf(combate.altura, 0.6)
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, 0.22)
	_mat.rim_enabled = true
	_mat.rim = 1.0
	var esf := SphereMesh.new()
	esf.radius = alto * 0.62
	esf.height = alto * 1.24
	esf.radial_segments = 20
	esf.rings = 10
	_malla = MeshInstance3D.new()
	_malla.mesh = esf
	_malla.material_override = _mat
	_malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_malla.position = Vector3(0, alto * 0.5, 0)
	add_child(_malla)


## Recibe `cantidad` de daño de `elemento`; devuelve el que NO absorbe (0 si se lo comió todo). El fuego lo quema entero.
func absorber(cantidad: float, elemento: String = "") -> float:
	if not activo():
		return cantidad
	if elemento == "fuego":
		_romper("fuego")
		Combate3D.flotante(combate.mundo, combate.position + Vector3(0, combate.altura + 0.5, 0), "¡Escudo quemado!", Color(1.0, 0.6, 0.25))
		return 0.0
	var parte: float = minf(cantidad, vida)
	vida -= parte
	absorbidos += parte
	Combate3D.flotante(combate.mundo, combate.position + Vector3(0, combate.altura + 0.5, 0), "Escudo", COLOR, 0.8)
	if vida <= 0.0:
		_romper("golpes")
	return cantidad - parte


func _romper(causa: String) -> void:
	vida = 0.0
	estado = "quemado" if causa == "fuego" else "roto"
	_t_rotura = 0.0
	if combate != null and is_instance_valid(combate) and combate.escudo_natural == self:
		combate.escudo_natural = null
	roto.emit(causa)


func _process(delta: float) -> void:
	_t += delta
	if estado == "activo":
		if _mat != null:
			_mat.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, 0.16 + 0.07 * sin(_t * 3.0) + 0.1 * (vida / vida_max))
		if combate != null and is_instance_valid(combate):
			position = Vector3.ZERO
	else:
		_t_rotura += delta
		var k: float = clampf(_t_rotura / T_ROTURA, 0.0, 1.0)
		if _mat != null:
			_mat.albedo_color = Color(COLOR_ROTO.r, COLOR_ROTO.g, COLOR_ROTO.b, 0.5 * (1.0 - k))
		if _malla != null:
			_malla.scale = Vector3.ONE * (1.0 + 0.4 * k)
		if k >= 1.0:
			queue_free()
