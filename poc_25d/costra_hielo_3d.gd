extends Node
class_name CostraHielo3D
## COSTRA DE HIELO PARA LO QUE QUEDA ATRAPADO (Fase 11.14, 12/10). Lo escribe el Pipeline.
##
## Qué es: una piel de hielo (azul blanquecino, en facetas con grietas, un poco hinchada) que se pone ENCIMA de todas las mallas de un
## modelo, sea un goblin, un tronco o lo que se congele. No cambia los materiales del modelo: usa `material_overlay`, así que al
## quitarla el modelo queda como estaba. Crece en ~0,3 s al helarse y se deshace en ~0,3 s al soltarse, como el hielo del agua.
##
## Uso (el Juego lo llama al entrar en el estado «congelado» y al salir):
##   var costra := CostraHielo3D.new()
##   modelo.add_child(costra)          # modelo: el Node3D del goblin (o del tronco); la costra recorre sus mallas
##   ...
##   costra.derretir()                 # se deshace y se borra sola
## `aviso(true)` abre las grietas y oscurece (le queda poco al hielo), igual que el hielo del agua con G < 0,15.

const CODIGO: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform float k = 0.0;                         // 0 = nada, 1 = costra entera (crece y se deshace)
uniform float aviso = 0.0;                     // 0-1: grietas grandes y más oscuro
uniform float grosor = 0.03;                   // cuánto se hincha sobre el modelo (u)
uniform float tam_faceta = 0.32;               // tamaño de las facetas (u)
uniform vec3 color_claro : source_color = vec3(0.72, 0.86, 0.97);
uniform vec3 color_hondo : source_color = vec3(0.46, 0.66, 0.88);
uniform vec3 color_grieta : source_color = vec3(0.30, 0.50, 0.76);

varying vec3 v_obj;

float hash(vec3 p) {
	p = fract(p * vec3(123.34, 456.21, 789.13));
	p += dot(p, p.yzx + 45.32);
	return fract((p.x + p.y) * p.z);
}

// Celdas de Voronoi en 3D (el modelo es un volumen): x = distancia a la arista, y = número al azar de la celda.
vec2 celdas(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 9.0;
	float d2 = 9.0;
	float id = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = vec3(hash(i + g), hash(i + g + 17.3), hash(i + g + 31.7));
				float d = length(g + o * 0.85 + 0.075 - f);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					id = hash(i + g + 5.7);
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec2(d2 - d1, id);
}

void vertex() {
	VERTEX += NORMAL * grosor * k;
	v_obj = VERTEX;
}

void fragment() {
	vec2 c = celdas(v_obj / tam_faceta);
	float tono = 0.35 + 0.65 * c.y;
	vec3 col = mix(color_hondo, color_claro, tono) * (0.80 + 0.20 * (1.0 - aviso));
	float ancho = 0.035 + aviso * 0.10;
	float grieta = 1.0 - smoothstep(ancho, ancho + 0.05, c.x);
	col = mix(col, color_grieta * (1.0 - 0.2 * aviso), grieta * (0.55 + 0.4 * aviso));
	// Facetas planas: la normal del triángulo, no la suave del modelo.
	vec3 nf = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = mix(NORMAL, nf, 0.65);
	float fres = pow(1.0 - clamp(dot(VIEW, NORMAL), 0.0, 1.0), 3.0);
	ALBEDO = col;
	EMISSION = col * 0.40;
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
	ALPHA = clamp((0.42 + 0.35 * fres + grieta * 0.25) * k, 0.0, 1.0);
}
"""

const SEG_CRECE: float = 0.3
const SEG_FUNDE: float = 0.3

var _mat: ShaderMaterial = null
var _mallas: Array[MeshInstance3D] = []
var _t: float = 0.0
var _saliendo: bool = false
var _aviso: float = 0.0
var _aviso_objetivo: float = 0.0


func _ready() -> void:
	var sh := Shader.new()
	sh.code = CODIGO
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	var raiz: Node = get_parent()
	if raiz != null:
		_recoger(raiz)
	for m in _mallas:
		m.material_overlay = _mat
	_mat.set_shader_parameter("k", 0.0)


## Abre las grietas y oscurece (le queda poco): lo puede llamar el Juego cuando el tiempo del hielo baja de ~15 %.
func aviso(si: bool) -> void:
	_aviso_objetivo = 1.0 if si else 0.0


## Empieza a deshacerse; al terminar quita la costra del modelo y se borra.
func derretir() -> void:
	if not _saliendo:
		_saliendo = true
		_t = 0.0


func _process(delta: float) -> void:
	if _mat == null:
		return
	_t += delta
	_aviso = move_toward(_aviso, _aviso_objetivo, delta * 6.0)
	var k: float = 0.0
	if _saliendo:
		k = 1.0 - clampf(_t / SEG_FUNDE, 0.0, 1.0)
		if k <= 0.0:
			_quitar()
			return
	else:
		k = clampf(_t / SEG_CRECE, 0.0, 1.0)
	_mat.set_shader_parameter("k", smoothstep(0.0, 1.0, k))
	_mat.set_shader_parameter("aviso", _aviso)


func _quitar() -> void:
	for m in _mallas:
		if is_instance_valid(m) and m.material_overlay == _mat:
			m.material_overlay = null
	queue_free()


func _recoger(n: Node) -> void:
	for c in n.get_children():
		if c == self:
			continue
		if c is MeshInstance3D and c.visible:
			_mallas.append(c)
		_recoger(c)
