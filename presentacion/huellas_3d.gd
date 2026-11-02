class_name Huellas3D
extends MultiMeshInstance3D

## HUELLAS DE LA JUGADORA (2/11, docs/REVISION_GAMEFEEL_30-10.md §11 · W1). Un solo MultiMesh de HUELLAS_MAX óvalos oscuros en el suelo, en anillo: la huella nueva pisa
## la más vieja. Cada una nace con ALFA y se funde en T_HUELLA s (el shader mira su edad: `ahora` − INSTANCE_CUSTOM.x). Solo en camino y tierra (lo decide `Caminar3D.paso`).
## Cuelga de la maqueta (`Huellas3D.de(mundo)`), a coordenadas de mundo (top_level). Solo aspecto: ni colisión ni reglas. `Sensacion3D.ACTIVA = false` → `poner` no hace nada.

static var HUELLAS_ACTIVO: bool = true
static var HUELLAS_MAX: int = 48                  ## huellas vivas como mucho (anillo)
static var T_HUELLA: float = 6.0                  ## s hasta desvanecerse del todo
static var ALFA_HUELLA: float = 0.25              ## opacidad al nacer
static var TAM_HUELLA: Vector2 = Vector2(0.13, 0.22)   ## u (ancho, largo en la marcha)
static var COLOR_HUELLA: Color = Color(0.13, 0.09, 0.06)
static var ALTO_HUELLA: float = 0.025             ## u sobre el suelo

const CODIGO: String = """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 color : source_color = vec3(0.13, 0.09, 0.06);
uniform float ahora = 0.0;
uniform float vida = 6.0;
uniform float alfa = 0.25;
varying float edad;
void vertex() {
	edad = ahora - INSTANCE_CUSTOM.x;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	if (r2 > 1.0) {
		discard;
	}
	float f = clamp(1.0 - edad / vida, 0.0, 1.0);
	ALBEDO = color;
	ALPHA = alfa * (1.0 - smoothstep(0.45, 1.0, r2)) * f * step(0.0, edad);
}
"""

var creadas: int = 0                              ## cuántas ha puesto en total (para las pruebas)
var _t: float = 0.0
var _siguiente: int = 0
var _nacida: PackedFloat32Array = PackedFloat32Array()
var _mat: ShaderMaterial = null


## La instancia de la maqueta `mundo` (la crea la primera vez). Null si el mundo no es un Node3D en el árbol.
static func de(mundo: Node) -> Huellas3D:
	if mundo == null or not is_instance_valid(mundo) or not (mundo is Node3D):
		return null
	var h: Node = mundo.get_node_or_null("Huellas3D")
	if h is Huellas3D:
		return h as Huellas3D
	var nueva := Huellas3D.new()
	nueva.name = "Huellas3D"
	mundo.add_child(nueva)
	return nueva


func _init() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-2000.0, -20.0, -2000.0), Vector3(4000.0, 60.0, 4000.0))
	var sh := Shader.new()
	sh.code = CODIGO
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.orientation = PlaneMesh.FACE_Y
	q.material = _mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = maxi(HUELLAS_MAX, 1)
	for i in range(mm.instance_count):
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0.0, -100.0, 0.0)))
		mm.set_instance_custom_data(i, Color(-1000.0, 0.0, 0.0, 0.0))
	multimesh = mm
	_nacida.resize(mm.instance_count)
	_nacida.fill(-1000.0)
	_aplicar_parametros()


func _aplicar_parametros() -> void:
	_mat.set_shader_parameter("color", Vector3(COLOR_HUELLA.r, COLOR_HUELLA.g, COLOR_HUELLA.b))
	_mat.set_shader_parameter("vida", T_HUELLA)
	_mat.set_shader_parameter("alfa", ALFA_HUELLA)


func _process(delta: float) -> void:
	_t += delta
	_mat.set_shader_parameter("ahora", _t)


## Una huella en `pos` (los pies) orientada a `dir` (rumbo de la marcha, plano XZ).
func poner(pos: Vector3, dir: Vector3) -> void:
	if not Sensacion3D.ACTIVA or not HUELLAS_ACTIVO or multimesh == null:
		return
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.01:
		d = Vector3(0.0, 0.0, 1.0)
	var yaw: float = atan2(d.x, d.z)
	var b := Basis(Vector3.UP, yaw).scaled_local(Vector3(TAM_HUELLA.x, 1.0, TAM_HUELLA.y))
	var i: int = _siguiente
	_siguiente = (_siguiente + 1) % multimesh.instance_count
	multimesh.set_instance_transform(i, Transform3D(b, pos + Vector3(0.0, ALTO_HUELLA, 0.0)))
	multimesh.set_instance_custom_data(i, Color(_t, 0.0, 0.0, 0.0))
	_nacida[i] = _t
	creadas += 1
	_aplicar_parametros()


## Cuántas se ven todavía (edad < T_HUELLA).
func activas() -> int:
	var n: int = 0
	for t in _nacida:
		if _t - t < T_HUELLA:
			n += 1
	return n


## Edad (s) de la huella `i`, o -1 si ese hueco nunca se usó.
func edad_de(i: int) -> float:
	if i < 0 or i >= _nacida.size() or _nacida[i] < -500.0:
		return -1.0
	return _t - _nacida[i]
