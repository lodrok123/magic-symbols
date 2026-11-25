class_name EstelaFlecha3D
extends Node3D

## ESTELA DE UNA FLECHA (21/11/2026, Pablo: «quiero que las flechas sean visibles»). Una cola corta y clara detrás de la flecha: dos cintas cruzadas (una horizontal y una vertical, así se lee
## desde la cámara alta y desde los lados) que se desvanecen hacia atrás. Cuelga de la raíz de la flecha, que mira por −Z, así que la cola sale por +Z desde el culatín.
## Color por defecto: blanco azulado pálido, que se ve sobre hierba y sobre suelo oscuro y NUNCA es amarillo (regla de Pablo). El chamán la tiñe de verde veneno.
## Es solo dibujo: no cambia velocidades, daños ni colisiones.

const LARGO_DEFECTO: float = 1.4
const ANCHO_DEFECTO: float = 0.26
const COLOR_DEFECTO: Color = Color(0.9, 0.93, 1.0)
const ALFA_DEFECTO: float = 0.85

const CODIGO: String = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(0.9, 0.93, 1.0, 1.0);
uniform float alfa = 0.7;
void fragment() {
	float lado = 1.0 - smoothstep(0.15, 1.0, abs(UV.x * 2.0 - 1.0));
	float cola = pow(max(1.0 - UV.y, 0.0), 1.6);   // 25/11: con UV.y un pelo por encima de 1, pow() de un negativo daba NaN y el glow lo pintaba como una bola blanca enorme en la cola
	ALBEDO = color.rgb;
	ALPHA = lado * cola * alfa;
}
"""

static var _shader: Shader = null

var _mat: ShaderMaterial = null


## La estela lista para colgar de la raíz de la flecha. `desde_z`: dónde empieza la cola (el culatín: la mitad del largo de la flecha).
static func crear(desde_z: float, largo: float = LARGO_DEFECTO, ancho: float = ANCHO_DEFECTO, color: Color = COLOR_DEFECTO, alfa: float = ALFA_DEFECTO) -> EstelaFlecha3D:
	var e := EstelaFlecha3D.new()
	e.name = "Estela"
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODIGO
	e._mat = ShaderMaterial.new()
	e._mat.shader = _shader
	e._mat.render_priority = 3
	e.poner_color(color, alfa)
	for giro in [0.0, PI * 0.5]:
		var pm := PlaneMesh.new()
		pm.size = Vector2(ancho, largo)
		var mi := MeshInstance3D.new()
		mi.name = "Cinta"
		mi.mesh = pm
		mi.material_override = e._mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0.0, 0.0, desde_z + largo * 0.5)
		mi.rotation = Vector3(0.0, 0.0, giro)
		e.add_child(mi)
	return e


func poner_color(color: Color, alfa: float = ALFA_DEFECTO) -> void:
	if _mat != null:
		_mat.set_shader_parameter("color", color)
		_mat.set_shader_parameter("alfa", alfa)
