shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// DESTELLO DEL HIELO (el golpe de un impacto): estrella de T_VFX_hit22 en billboard, blanco azulado (escarcha → borde), con blend_mix: es un golpe de luz sobre el cristal, no una luz.
// El tamaño lo da la escala del nodo; `vida` lo apaga. Sin emisión.
#include "res://presentacion/vfx/toy/hielo_toy.gdshaderinc"

uniform sampler2D tex : filter_linear_mipmap, repeat_enable;
uniform float giro = 0.0;
uniform float opacidad = 0.85;

void vertex() {
	vec3 centro = MODELVIEW_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	float c = cos(giro);
	float sn = sin(giro);
	vec2 q = vec2(VERTEX.x * c - VERTEX.y * sn, VERTEX.x * sn + VERTEX.y * c) * s;
	POSITION = PROJECTION_MATRIX * vec4(centro + vec3(q, 0.0), 1.0);
}

void fragment() {
	float t = texture(tex, UV).r;
	vec3 col = mix(color_borde, tono_c, smoothstep(0.2, 0.9, t));
	ALBEDO = col * brillo;
	ALPHA = clamp(smoothstep(0.08, 0.7, t) * opacidad, 0.0, 1.0) * vida;
}
