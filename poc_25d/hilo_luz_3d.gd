class_name HiloLuz3D
extends Node3D

## HILO DE LUZ: una cinta plana y brillante que une dos cosas del nivel (el tótem que activa y el puente que aparece). Una luz
## recorre el hilo de un extremo a otro (`viajar`) y después se queda tenue, como un circuito ya encendido.
##
## Por qué una cinta con shader y no partículas: es UNA malla y UN material por hilo, y se ve igual con cualquier cámara. La
## forma (núcleo casi blanco + resplandor del color del elemento) sale de la distancia al eje de la cinta; el avance de la
## luz, de la coordenada a lo largo de la cinta (UV.x en unidades de mundo). Va sin iluminación y con mezcla normal (el aditivo se pierde sobre el suelo, que es muy claro).
##
## Uso:
##   var h := HiloLuz3D.new(); padre.add_child(h)
##   h.preparar(puntos, Color(1, 0.9, 0.4))     # puntos del mundo, en orden, ya a la altura a la que se quiere ver
##   h.viajar(0.55)                              # la luz va del primer punto al último en 0,55 s y el hilo se queda tenue

const ANCHO: float = 0.85
const SUAVIZADOS: int = 2                  ## pasadas de Chaikin: redondea las esquinas en ángulo recto de la rejilla
const BRILLO_TENUE: float = 0.6

const CODIGO: String = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 color : source_color = vec3(0.1, 0.9, 1.0);
uniform float avance = 0.0;      // hasta dónde ha llegado la luz, en unidades a lo largo del hilo
uniform float energia = 1.0;     // brillo general del hilo ya encendido (se baja al terminar de viajar)
void fragment() {
	float a = abs(UV.y - 0.5) * 2.0;                                  // 0 en el eje, 1 en el borde
	float nucleo = smoothstep(0.40, 0.0, a);
	float halo = smoothstep(1.0, 0.0, a);
	float llegado = smoothstep(avance, avance - 0.5, UV.x);           // 1 detrás de la cabeza, con borde suave
	float cabeza = exp(-pow((UV.x - avance) / 0.32, 2.0));            // la luz que viaja: un destello en la punta
	float flujo = 0.5 + 0.5 * sin((UV.x - TIME * 1.3) * 5.5);         // ondulación lenta que corre por el hilo
	float k = llegado * (0.55 + 0.30 * flujo) * energia + cabeza * 1.6;
	vec3 c = mix(color, vec3(1.0), nucleo * 0.65);
	ALBEDO = c;
	ALPHA = clamp(nucleo * k * 2.4 + halo * k * 0.85, 0.0, 1.0);
}
"""

var largo: float = 0.0
var _mat: ShaderMaterial = null
var _malla: MeshInstance3D = null
var _tw: Tween = null


## `puntos`: la línea por la que va el hilo (puntos del mundo, ya a su altura). Se redondean las esquinas.
func preparar(puntos: Array, color: Color) -> void:
	var p: Array = puntos.duplicate()
	for _i in range(SUAVIZADOS):
		p = _chaikin(p)
	if p.size() < 2:
		return
	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var recorrido: float = 0.0
	for i in range(p.size()):
		var pt: Vector3 = p[i]
		if i > 0:
			recorrido += pt.distance_to(p[i - 1])
		var d: Vector3 = (p[mini(i + 1, p.size() - 1)] as Vector3) - (p[maxi(i - 1, 0)] as Vector3)
		d.y = 0.0
		d = d.normalized() if d.length() > 0.0001 else Vector3.RIGHT
		var lado := Vector3(-d.z, 0.0, d.x) * (ANCHO * 0.5)
		vertices.append(pt - lado)
		vertices.append(pt + lado)
		normales.append(Vector3.UP)
		normales.append(Vector3.UP)
		uvs.append(Vector2(recorrido, 0.0))
		uvs.append(Vector2(recorrido, 1.0))
		if i > 0:
			var b: int = (i - 1) * 2
			indices.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2]))
	largo = recorrido
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vertices
	arr[Mesh.ARRAY_NORMAL] = normales
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = indices
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var sh := Shader.new()
	sh.code = CODIGO
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("color", color)
	_mat.set_shader_parameter("avance", -1.0)       # apagado hasta que se lanza
	_mat.set_shader_parameter("energia", 1.0)
	am.surface_set_material(0, _mat)
	_malla = MeshInstance3D.new()
	_malla.mesh = am
	_malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_malla)


## La luz recorre el hilo en `dura` s y luego el hilo se queda tenue.
func viajar(dura: float) -> void:
	if _mat == null:
		return
	if _tw != null:
		_tw.kill()
	_mat.set_shader_parameter("energia", 1.0)
	_tw = create_tween()
	_tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("avance", v), -0.3, largo + 0.8, dura)
	_tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("energia", v), 1.0, BRILLO_TENUE, 0.7)


## Suaviza una línea quebrada cortando sus esquinas (Chaikin); los extremos se conservan.
static func _chaikin(p: Array) -> Array:
	if p.size() < 3:
		return p
	var r: Array = [p[0]]
	for i in range(p.size() - 1):
		var a: Vector3 = p[i]
		var b: Vector3 = p[i + 1]
		if i > 0:
			r.append(a.lerp(b, 0.25))
		if i < p.size() - 2:
			r.append(a.lerp(b, 0.75))
	r.append(p[p.size() - 1])
	return r
