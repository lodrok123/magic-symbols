class_name NieblaCanouro3D
extends Node3D
## NIEBLA NEGRA A RAS DE LAS PATAS DEL CANOURO (5/11, encargo de Pablo: «niebla de color negro muy densa a ras de las patas del canouro»).
##
## Unas pocas láminas horizontales superpuestas, muy bajas (la más alta queda por debajo de la rodilla), con un shader de ruido que deriva
## en coordenadas del MUNDO: cuando el animal se mueve arrastra la niebla en vez de llevarla pegada como una pegatina. El nodo la sigue con
## un pequeño retraso (SUAVIZADO) para que se vea pesada.
##
## Referencias: `presentacion/niebla_foso_3d.gd` (lámina horizontal con ruido que deriva y fundido por profundidad, de donde sale la técnica)
## y `presentacion/vfx_canouro_3d.gd` (humo de pies existente, `HUMO_COLORES`, de donde sale el negro).
##
## Uso: `NieblaCanouro3D.poner(pj, alto)` (lo hace Combate3D para el id "canouro"); se cuelga del Pj3D y se libera con él.

## Radio de la niebla en ALTURAS del modelo (×0,55 en el juego ≈ 0,72 u).
static var RADIO_ALTURAS: float = 1.3
## Altura de cada lámina sobre los pies, en alturas del modelo (la más alta ≈ 0,08 u: por debajo de la rodilla, no tapa el cuerpo).
static var ALTURAS_CAPAS: Array = [0.03, 0.07, 0.11, 0.15]
## Opacidad máxima en el centro de la lámina baja.
static var OPACIDAD: float = 0.85
## Cada lámina superior lleva esta fracción de la anterior.
static var OPACIDAD_POR_CAPA: float = 0.7
## Negro casi puro (como HUMO_COLORES del humo de pies).
static var COLOR: Color = Color(0.02, 0.02, 0.03)
## u/s a la que deriva el ruido (en coordenadas del MUNDO: el animal arrastra la niebla, no la lleva pegada).
static var VELOCIDAD: float = 0.35
## Repeticiones del ruido por unidad de mundo.
static var ESCALA_RUIDO: float = 2.2
## Fracción del radio donde la opacidad empieza a caer hacia el borde (borde suave, nada de disco recortado).
static var BORDE: float = 0.45
## 1/s con que la niebla sigue al animal (va un pelín rezagada: pesada).
static var SUAVIZADO: float = 12.0
## Distancia (u) en la que la lámina se funde contra lo que tiene detrás (suelo, patas). Con 0,15 (como la niebla del foso) la lámina baja,
## a 1,6 cm del suelo, quedaba casi transparente y la niebla parecía una sombra tenue: tiene que ser menor que la altura de la primera lámina.
static var FUNDIDO: float = 0.025
## Interruptor: false = no se monta.
static var ACTIVA: bool = true

const CODIGO: String = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D profundidad : hint_depth_texture, filter_linear;
uniform vec4 color : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform float alfa = 0.85;
uniform float velocidad = 0.35;
uniform float escala_ruido = 2.2;
uniform float borde = 0.45;
uniform float fundido = 0.025;
varying vec3 pw;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	pw = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Ruido en coordenadas del mundo, dos octavas que derivan en direcciones distintas.
	vec2 base = pw.xz * escala_ruido;
	float n = ruido(base + TIME * velocidad * vec2(1.0, 0.6)) * 0.6 + ruido(base * 2.3 - TIME * velocidad * vec2(0.8, -0.4)) * 0.4;
	float densidad = mix(0.55, 1.0, smoothstep(0.25, 0.75, n));
	// Caida radial hacia el borde de la lamina.
	float dist = length(UV * 2.0 - 1.0);
	float radial = 1.0 - smoothstep(borde, 1.0, dist);
	// Se funde donde toca las patas o el suelo (profundidad de la escena frente a la de la lamina).
	float z_escena = texture(profundidad, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, z_escena, 1.0);
	vec4 v = INV_PROJECTION_MATRIX * ndc;
	v.xyz /= v.w;
	float suave = clamp((VERTEX.z - v.z) / fundido, 0.0, 1.0);
	ALBEDO = color.rgb;
	ALPHA = alfa * densidad * radial * suave;
}
"""

var pj: Node3D = null
var alto: float = 0.55
var capas: Array[MeshInstance3D] = []
## 6/11 (Pablo, canouro v2): cuánta niebla hay ahora (1 = entera, 0 = disipada). `disipar` la apaga con un fundido y `rebrotar` la devuelve; las láminas bajan su opacidad con ella.
var densidad: float = 1.0
var _densidad_meta: float = 1.0
var _t_fundido: float = 0.5   ## s que tarda en ir de 0 a 1 (o al revés) la última orden


## Crea la niebla y la cuelga del Pj3D seguido. Devuelve null si ACTIVA es false.
static func poner(p_pj: Node3D, p_alto: float) -> NieblaCanouro3D:
	if not ACTIVA:
		return null
	var n := NieblaCanouro3D.new()
	n.name = "NieblaCanouro3D"
	n.pj = p_pj
	n.alto = p_alto
	p_pj.add_child(n)
	n.montar()
	if n.is_inside_tree():
		n.global_position = p_pj.global_position
	else:
		n.position = p_pj.position
	return n


func _ready() -> void:
	top_level = true


func montar() -> void:
	top_level = true
	var r: float = radio()
	var sh := Shader.new()
	sh.code = CODIGO
	for k in range(ALTURAS_CAPAS.size()):
		var q := QuadMesh.new()
		q.orientation = PlaneMesh.FACE_Y
		q.size = Vector2(2.0 * r, 2.0 * r)
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("color", COLOR)
		mat.set_shader_parameter("alfa", OPACIDAD * pow(OPACIDAD_POR_CAPA, float(k)))
		mat.set_shader_parameter("velocidad", VELOCIDAD)
		mat.set_shader_parameter("escala_ruido", ESCALA_RUIDO)
		mat.set_shader_parameter("borde", BORDE)
		mat.set_shader_parameter("fundido", FUNDIDO)
		q.material = mat
		var mi := MeshInstance3D.new()
		mi.name = "capa%d" % k
		mi.mesh = q
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0.0, float(ALTURAS_CAPAS[k]) * alto, 0.0)
		add_child(mi)
		capas.append(mi)


func radio() -> float:
	return RADIO_ALTURAS * alto


func apagar() -> void:
	visible = false
	set_process(false)


## 6/11: la niebla se disipa (el fuego se la lleva) con un fundido de `t` s. Sigue en el árbol, solo invisible.
func disipar(t: float = 0.6) -> void:
	_densidad_meta = 0.0
	_t_fundido = maxf(t, 0.01)


## 6/11: la niebla vuelve a crecer hasta su densidad entera en `t` s.
func rebrotar(t: float = 1.5) -> void:
	_densidad_meta = 1.0
	_t_fundido = maxf(t, 0.01)


func _aplicar_densidad() -> void:
	for k in range(capas.size()):
		var mat: ShaderMaterial = capas[k].mesh.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("alfa", OPACIDAD * pow(OPACIDAD_POR_CAPA, float(k)) * densidad)
		capas[k].visible = densidad > 0.002


func _process(delta: float) -> void:
	if pj == null or not is_instance_valid(pj):
		return
	global_position = global_position.lerp(pj.global_position, clampf(SUAVIZADO * delta, 0.0, 1.0))
	global_rotation = Vector3.ZERO
	if not is_equal_approx(densidad, _densidad_meta):
		densidad = move_toward(densidad, _densidad_meta, delta / _t_fundido)
		_aplicar_densidad()
