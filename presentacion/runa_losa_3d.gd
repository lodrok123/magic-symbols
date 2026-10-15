class_name RunaLosa3D
extends Node3D
## Dueño: Pipeline.
## Runa grabada sobre una losa (losa_runas_*). Es un quad plano pegado a la cara
## superior de la losa, con la textura de la runa. Por qué un quad y no una decal:
## la losa es plana y fija, el quad es barato y funciona igual en el renderer
## compatible. Apagada = grabado oscuro en la piedra; encendida = brillo de color.

const TEX_DEFECTO := "res://presentacion/vfx/runas/runa_fuego.png"
## Rojo/naranja: el color de la runa de fuego.
const COLOR_FUEGO := Color(1.0, 0.45, 0.12)
const COLOR_APAGADA := Color(0.20, 0.16, 0.15, 0.85)

signal encendida
signal apagada

var _mat: StandardMaterial3D
var _quad: MeshInstance3D
var _color_vivo: Color = COLOR_FUEGO
var _encendida := false

## Crea la runa sobre la losa `pieza` (la que sale de arte/piezas/losa_runas_*.tscn).
## `ancho` es el lado de la runa en metros; por defecto ~55 % de la losa.
## Empieza apagada salvo que `encendida_ya` sea true.
static func en_losa(pieza: Node3D, textura: Texture2D = null, color: Color = COLOR_FUEGO,
		encendida_ya: bool = false) -> RunaLosa3D:
	var r := RunaLosa3D.new()
	r.name = "Runa"
	var modelo: Node = pieza.get_node_or_null("modelo")
	var tope := 0.08
	var lado := 1.0
	if modelo is Node3D:
		var a := _aabb_global(modelo as Node3D, pieza)
		tope = a.end.y
		lado = minf(a.size.x, a.size.z) * 0.55
	pieza.add_child(r)
	r.position = Vector3(0, tope + 0.006, 0)   # un pelo por encima para evitar z-fighting
	r.preparar(textura, color, lado)
	if encendida_ya: r.encender()
	return r

static func de(pieza: Node) -> RunaLosa3D:
	return pieza.get_node_or_null("Runa") as RunaLosa3D

func preparar(textura: Texture2D, color: Color, lado: float) -> void:
	_color_vivo = color
	if textura == null:
		textura = load(TEX_DEFECTO) as Texture2D
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = textura
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.render_priority = 1
	var pm := PlaneMesh.new(); pm.size = Vector2(lado, lado)
	_quad = MeshInstance3D.new(); _quad.mesh = pm; _quad.material_override = _mat
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_quad)
	_aplicar()

func esta_encendida() -> bool:
	return _encendida

func encender() -> void:
	if _encendida: return
	_encendida = true; _aplicar(); encendida.emit()

func apagar() -> void:
	if not _encendida: return
	_encendida = false; _aplicar(); apagada.emit()

func _aplicar() -> void:
	if _mat == null: return
	# La textura es un glifo claro sobre fondo transparente: se tiñe con albedo_color.
	_mat.albedo_color = _color_vivo * 1.5 if _encendida else COLOR_APAGADA

static func _aabb_global(n: Node3D, ref: Node3D) -> AABB:
	var inv := ref.global_transform.affine_inverse() if ref.is_inside_tree() else Transform3D.IDENTITY
	var res := AABB(); var primero := true
	for m in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
		var mi := m as MeshInstance3D
		if mi.mesh == null: continue
		var t: Transform3D = inv * mi.global_transform if ref.is_inside_tree() else _t_rel(mi, ref)
		var a: AABB = t * mi.mesh.get_aabb()
		if primero: res = a; primero = false
		else: res = res.merge(a)
	return res

static func _t_rel(n: Node3D, ref: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != ref:
		if c is Node3D: t = (c as Node3D).transform * t
		c = c.get_parent()
	return t
