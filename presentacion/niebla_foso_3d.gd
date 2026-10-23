class_name NieblaFoso3D
extends Node3D
## NIEBLA EN LOS FOSOS (bloque 3 de la revisión EoW, 23/10): una bruma baja y suave en el fondo de los cauces secos hondos, que los lee como
## hondos sin oscurecerlos más. Cuando el cauce se llena de agua, la bruma de esa casilla se desvanece; si se vacía, vuelve.
##
## POR QUÉ. EoW casi no usa niebla en las mazmorras (`Weather.json`: niebla de altura apagada en 136 de 182 entradas), pero la que usa es de
## ALTURA, pegada al fondo. Aquí no hace falta la niebla volumétrica de Godot (solo Forward+, cara): dos láminas por casilla con un ruido que
## deriva, que se funden con las paredes del foso leyendo la profundidad de la escena (no se ve la arista del quad contra la piedra).
##
## Uso: `NieblaFoso3D.montar(maqueta)` (lo hace la maqueta si `niebla_fosos` está marcado). Sin cauces hondos no crea nada.

const ALTURAS: Array = [0.22, 0.5]      ## u sobre el fondo del foso de cada lámina
const ALFA: float = 0.2
const COLOR: Color = Color(0.86, 0.9, 0.92)
const CADA: float = 0.3                 ## s entre comprobaciones de agua
const VEL_FUNDIDO: float = 1.5          ## por segundo

const CODIGO: String = """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D profundidad : hint_depth_texture, filter_linear;
uniform vec4 color : source_color = vec4(0.86, 0.9, 0.92, 1.0);
uniform float alfa = 0.2;
varying vec3 pw;
varying float visible;

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
	visible = INSTANCE_CUSTOM.a;
}

void fragment() {
	// Ruido que deriva despacio, en coordenadas del mundo: las casillas vecinas casan sin costura.
	float n = ruido(pw.xz * 0.9 + vec2(TIME * 0.08, TIME * 0.05)) * 0.6 + ruido(pw.xz * 2.1 - vec2(TIME * 0.11, 0.0)) * 0.4;
	// Se funde donde toca la pared o el fondo: diferencia entre la profundidad de la escena y la de la lámina.
	float z_escena = texture(profundidad, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, z_escena, 1.0);
	vec4 v = INV_PROJECTION_MATRIX * ndc;
	v.xyz /= v.w;
	float suave = clamp((VERTEX.z - v.z) / 0.35, 0.0, 1.0);     // en espacio de vista: la escena queda detrás (z más negativa)
	ALBEDO = color.rgb;
	ALPHA = alfa * smoothstep(0.4, 0.9, n) * suave * visible;     // en manchas: la mitad del foso, casi limpia
}
"""

var _mm: MultiMesh = null
var _celdas: Array[Vector2i] = []
var _vis: PackedFloat32Array = PackedFloat32Array()
var _t: float = 0.0


## Crea la niebla de los cauces hondos de la maqueta. Devuelve el nodo (o null si no hay ningún cauce hondo).
static func montar(maqueta: Node3D) -> NieblaFoso3D:
	var lado: int = int(maqueta.get("_lado"))
	var celdas: Array[Vector2i] = []
	for y in range(lado):
		for x in range(lado):
			var c := Vector2i(x, y)
			if Terreno3D.es_cauce_hondo(c):
				celdas.append(c)
	if celdas.is_empty():
		return null
	var n := NieblaFoso3D.new()
	n.name = "NieblaFoso3D"
	n._celdas = celdas
	maqueta.add_child(n)
	return n


func _ready() -> void:
	var s: float = Terreno3D.casilla
	var q := QuadMesh.new()
	q.size = Vector2(s * 1.02, s * 1.02)
	q.orientation = PlaneMesh.FACE_Y
	var sh := Shader.new()
	sh.code = CODIGO
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("color", COLOR)
	mat.set_shader_parameter("alfa", ALFA)
	q.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = q
	_mm.instance_count = _celdas.size() * ALTURAS.size()
	_vis.resize(_celdas.size())
	for i in range(_celdas.size()):
		var c: Vector2i = _celdas[i]
		_vis[i] = 0.0 if Terreno3D.es_agua(c) else 1.0
		for k in range(ALTURAS.size()):
			var p: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c) + float(ALTURAS[k]))
			_mm.set_instance_transform(i * ALTURAS.size() + k, Transform3D(Basis.IDENTITY, p))
			_mm.set_instance_custom_data(i * ALTURAS.size() + k, Color(0.0, 0.0, 0.0, _vis[i]))
	var mi := MultiMeshInstance3D.new()
	mi.name = "niebla"
	mi.multimesh = _mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	var mirar: bool = _t >= CADA
	if mirar:
		_t = 0.0
	for i in range(_celdas.size()):
		var objetivo: float = _vis[i]
		if mirar:
			objetivo = 0.0 if Terreno3D.es_agua(_celdas[i]) else 1.0
		var actual: float = _mm.get_instance_custom_data(i * ALTURAS.size()).a
		if is_equal_approx(actual, objetivo):
			_vis[i] = objetivo
			continue
		var v: float = move_toward(actual, objetivo, VEL_FUNDIDO * delta)
		_vis[i] = objetivo
		for k in range(ALTURAS.size()):
			_mm.set_instance_custom_data(i * ALTURAS.size() + k, Color(0.0, 0.0, 0.0, v))
