shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// ESCARCHA EN EL SUELO (o en una pared): un disco de bordes rotos con venas radiales, blanco azulado, que crece (`u` 0 → 1) y se derrite (`vida` baja). Quad de 1 m tumbado (FACE_Y):
// el tamaño lo da la escala del nodo. Es la costra que deja el hielo: hondo en las venas, claro en el cuerpo, escarcha en el borde. Sin emisión ni luz.
#include "res://presentacion/vfx/toy/hielo_toy.gdshaderinc"

uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;       // T_Noise_Wf4
uniform sampler2D grietas : filter_linear_mipmap, repeat_enable;     // T_Cracks336
uniform float u : hint_range(0.0, 1.0) = 1.0;
uniform float opacidad = 0.7;
uniform float semilla = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float borde_roto = texture(ruido, p * 0.9 + vec2(semilla * 5.0)).r;
	float radio_u = mix(0.15, 1.0, smoothstep(0.0, 1.0, u)) * (0.82 + 0.28 * borde_roto);
	float cuerpo = 1.0 - smoothstep(radio_u - 0.1, radio_u, d);
	float venas = smoothstep(0.35, 0.8, texture(grietas, p * 0.5 + 0.5 + vec2(semilla * 3.0)).r);
	float v = 0.45 + 0.25 * venas + 0.4 * smoothstep(radio_u * 0.55, radio_u, d);
	vec3 col = hielo_tonos(v, 0.82, 0.06);
	ALBEDO = col * brillo;
	ALPHA = clamp(cuerpo * (opacidad - 0.18 * (1.0 - borde_roto)), 0.0, 0.9) * vida;
}
