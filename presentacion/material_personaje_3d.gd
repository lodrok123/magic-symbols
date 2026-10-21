class_name MaterialPersonaje3D
extends RefCounted
## Los dos pases extra que hacen que un personaje parezca «juguete» (V5 de docs/PLAN_EOW_VISUAL.md): el rim/fresnel de color y la silueta
## a través de lo que lo tapa. Los dos son ShaderMaterial en `next_pass` del material del modelo, NO sustituyen al StandardMaterial3D:
## así el tinte de `Combate3D` (quemado, congelado, golpe, que escribe `albedo_color` y la emisión) sigue funcionando sin enterarse.
##
## RIM. Aditivo y sin iluminar: suma `color * fresnel * intensidad` al píxel del borde. Se eligió esto en vez de `rim_enabled` del
## StandardMaterial3D porque ese rim toma el color de la LUZ (y se mezcla con el albedo), y aquí se quiere un color propio por rol
## (cálido la jugadora, el de su debilidad los enemigos). Con cámara ortogonal `VIEW` es constante, así que el brillo cae en las aristas
## que miran de lado: justo el contorno de plástico de Echoes of Wisdom.
##
## SILUETA. Un color plano semitransparente que se pinta SOLO donde el personaje está tapado. El truco: `depth_test_disabled` (se pinta encima
## de todo) y, en el fragmento, se lee la profundidad de la escena opaca (`hint_depth_texture`) y se descarta el píxel si lo que hay delante NO
## está claramente más cerca que el personaje. «Claramente» = `sesgo`: el propio personaje también está en esa textura, y un brazo detrás del
## torso quedaría «tapado» por el torso; el sesgo (una fracción de su altura) lo absorbe. Un árbol, un muro o un bloque suben mucho más que eso.
## POR QUÉ NO STENCIL: el «fallo de profundidad» del stencil también se activa con la autooclusión del propio modelo; habría el mismo problema
## y además solo existe desde 4.5 en Forward+/Mobile.

const CODIGO_RIM: String = """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform vec3 color : source_color = vec3(1.0, 0.75, 0.45);
uniform float potencia : hint_range(0.5, 8.0) = 2.2;
uniform float intensidad : hint_range(0.0, 3.0) = 0.7;
void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), potencia);
	ALBEDO = color * f * intensidad;
}
"""

const CODIGO_SILUETA: String = """
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform sampler2D profundidad : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.5, 0.42);
uniform float sesgo = 0.4;
void fragment() {
	float d = textureLod(profundidad, SCREEN_UV, 0.0).x;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float escena = -v.z / v.w;      // distancia (vista) a lo más cercano que hay en ese píxel
	float propio = -VERTEX.z;       // distancia (vista) de este fragmento del personaje
	if (escena > propio - sesgo) {
		discard;                    // nada lo tapa: no se ve silueta
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
"""

## Prioridad de dibujo de la silueta: por encima de las transparencias normales (agua, humo, hierba) para que no la tape un velo.
const PRIORIDAD_SILUETA: int = 20


static func rim(color: Color, potencia: float, intensidad: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = CODIGO_RIM
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("color", Vector3(color.r, color.g, color.b))
	m.set_shader_parameter("potencia", potencia)
	m.set_shader_parameter("intensidad", intensidad)
	return m


static func silueta(color: Color, sesgo: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = CODIGO_SILUETA
	var m := ShaderMaterial.new()
	m.shader = sh
	m.render_priority = PRIORIDAD_SILUETA
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("sesgo", sesgo)
	return m
