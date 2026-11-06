class_name TiranteEnredadera3D
extends Node3D

## TIRANTE ENREDADERA ↔ ELEMENTAL (6/11, Pablo: «El elemental»; Dueño: Juego). Una línea verde fina del pie de una enredadera viva al pecho del elemental que la conjuró, para que se LEA
## que esa enredadera lo está curando (6 vida/s cada una, `Combate3D.ELEM_CURA_ENREDADERA`). Mientras el elemental está herido, una chispa clara recorre la línea hacia él ("pulsa hacia el
## elemental"); con la vida llena solo queda el hilo, tenue. Lo crea y lo borra `Combate3D._tirantes_elemental` (uno por enredadera VIVA: al arder o deshacerse la enredadera, se va).
## No usa VFX ni materiales nuevos del juego: un cilindro fino y una esfera pequeña, sin sombreado, del verde de la enredadera.

const COLOR: Color = Color(0.35, 0.85, 0.3)
const COLOR_CHISPA: Color = Color(0.8, 1.0, 0.6)
const GROSOR: float = 0.035                       ## u: radio del hilo
const RADIO_CHISPA: float = 0.09
const PERIODO_PULSO: float = 0.9                  ## s que tarda la chispa en ir de la enredadera al elemental
const ALTO_ORIGEN: float = 0.25                   ## u sobre los pies de la enredadera
const ALTO_DESTINO: float = 0.55                  ## fracción de la altura del elemental

var origen: Node3D = null                         ## la enredadera
var destino: Combate3D = null                     ## el elemental
var cura: bool = false                            ## true = el elemental está herido y la chispa corre
var t: float = 0.0
var _hilo: MeshInstance3D = null
var _chispa: MeshInstance3D = null
var _mat_hilo: StandardMaterial3D = null


static func crear(en: Node, p_origen: Node3D, p_destino: Combate3D) -> TiranteEnredadera3D:
	var n := TiranteEnredadera3D.new()
	n.origen = p_origen
	n.destino = p_destino
	n.name = "Tirante_" + str(p_origen.get_instance_id())
	if en != null:
		en.add_child(n)
	n._construir()
	n.actualizar(0.0)
	return n


func _construir() -> void:
	var cil := CylinderMesh.new()
	cil.top_radius = GROSOR
	cil.bottom_radius = GROSOR
	cil.height = 1.0
	cil.radial_segments = 6
	cil.rings = 1
	_mat_hilo = StandardMaterial3D.new()
	_mat_hilo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_hilo.albedo_color = COLOR
	_mat_hilo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hilo = MeshInstance3D.new()
	_hilo.mesh = cil
	_hilo.material_override = _mat_hilo
	_hilo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hilo)
	var esf := SphereMesh.new()
	esf.radius = RADIO_CHISPA
	esf.height = RADIO_CHISPA * 2.0
	esf.radial_segments = 8
	esf.rings = 4
	var mc := StandardMaterial3D.new()
	mc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mc.albedo_color = COLOR_CHISPA
	_chispa = MeshInstance3D.new()
	_chispa.mesh = esf
	_chispa.material_override = mc
	_chispa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chispa.visible = false
	add_child(_chispa)


## Extremos del hilo en el mundo: [pie de la enredadera, pecho del elemental]. Vacío si alguno ya no existe.
func extremos() -> Array:
	if origen == null or not is_instance_valid(origen) or destino == null or not is_instance_valid(destino):
		return []
	var a: Vector3 = (origen.global_position if origen.is_inside_tree() else origen.position) + Vector3(0.0, ALTO_ORIGEN, 0.0)
	var b: Vector3 = (destino.global_position if destino.is_inside_tree() else destino.position) + Vector3(0.0, destino.altura * ALTO_DESTINO, 0.0)
	return [a, b]


## Coloca el hilo y la chispa. `delta` avanza el pulso.
func actualizar(delta: float) -> void:
	t += delta
	var e: Array = extremos()
	if e.is_empty():
		return
	var a: Vector3 = e[0]
	var b: Vector3 = e[1]
	var v: Vector3 = b - a
	var largo: float = v.length()
	if largo < 0.01:
		return
	cura = destino.health < destino.vida_max
	var y: Vector3 = v / largo
	# Base con +Y a lo largo del hilo (el cilindro mide 1 en Y): cualquier eje perpendicular sirve para completarla.
	var ref: Vector3 = Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
	var x: Vector3 = ref.cross(y).normalized()
	var z: Vector3 = x.cross(y).normalized()
	var base := Basis(x, y, z).scaled(Vector3(1.0, largo, 1.0))
	var tr := Transform3D(base, (a + b) * 0.5)
	if is_inside_tree():
		_hilo.global_transform = tr
	else:
		_hilo.transform = tr
	# El hilo late despacio; más vivo mientras cura.
	var pulso: float = 0.5 + 0.5 * sin(t * (7.0 if cura else 2.5))
	_mat_hilo.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, (0.55 + 0.4 * pulso) if cura else (0.3 + 0.12 * pulso))
	_chispa.visible = cura
	if cura:
		var k: float = fmod(t / PERIODO_PULSO, 1.0)
		if is_inside_tree():
			_chispa.global_position = a.lerp(b, k)
		else:
			_chispa.position = a.lerp(b, k)


func _process(delta: float) -> void:
	actualizar(delta)
