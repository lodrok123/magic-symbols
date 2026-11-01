// HALO TOON (1/11, prueba 2, ronda 2): resplandor de la llama sobre el suelo. Un quad horizontal con dos óvalos planos (interior y exterior) sumados a lo que hay
// debajo (aditivo), con el radio titilando a saltos de 1/fps. No es una luz: la luz del efecto sigue siendo una sola.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 tono_interior : source_color = vec4(0.17, 0.07, 0.01, 1.0);
uniform vec4 tono_exterior : source_color = vec4(0.08, 0.03, 0.005, 1.0);
uniform float fps : hint_range(2.0, 60.0) = 12.0;
uniform float radio_interior : hint_range(0.1, 0.9) = 0.55;
uniform float brillo : hint_range(0.0, 3.0) = 1.0;
uniform float erosion : hint_range(0.0, 1.0) = 0.0;

varying float v_t;

void vertex() {
	v_t = floor(TIME * fps) / fps;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float parpadeo = 1.0 + 0.05 * sin(v_t * 37.0 + 2.0 * sin(v_t * 11.0));
	float d = length(p) / (parpadeo * (1.0 - erosion));
	if (d > 1.0) {
		discard;
	}
	vec3 col = d < radio_interior ? tono_interior.rgb : tono_exterior.rgb;
	ALBEDO = col * brillo;
}
