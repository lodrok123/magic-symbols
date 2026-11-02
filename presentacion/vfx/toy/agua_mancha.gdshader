shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// MANCHA HÚMEDA EN UNA PARED (fase 2, salpicadura). Un quad pegado a la superficie (FACE_Y, se orienta con su normal): una mancha irregular y SUTIL (T_VFX_CircleFit1 deformada por T_Noise_W5i) con
// unos regueros que escurren hacia abajo (`abajo` = dirección de la gravedad en el espacio del quad, la pone quien lo usa) y que se desvanece. Sin anillos. Sin luz ni emisión.
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

uniform sampler2D disco : filter_linear, repeat_disable;           // T_VFX_CircleFit1
uniform float u : hint_range(0.0, 1.0) = 0.0;
uniform vec2 abajo = vec2(0.0, 1.0);                              // hacia dónde escurre, en el UV del quad (-1..1)
uniform float opacidad = 0.34;
uniform float semilla = 0.0;
uniform float fade_canto : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float prog = 1.0 - pow(1.0 - clamp(u * 3.0, 0.0, 1.0), 2.0);        // se extiende en el primer tercio
	vec2 q = p / max(0.25 + 0.75 * prog, 0.01);
	float ru = texture(flujo, q * 0.35 + vec2(semilla)).r;
	float masa = texture(disco, clamp(q * 0.5 + 0.5, 0.0, 1.0)).r * (1.0 - smoothstep(0.9, 1.0, length(q)));
	float irregular = smoothstep(0.12, 0.7, masa * (0.4 + 1.1 * ru));
	// regueros: bandas estrechas que se alargan hacia abajo con el tiempo
	float dd = dot(q, abajo);
	float lat = dot(q, vec2(-abajo.y, abajo.x));
	float reg = texture(flujo, vec2(lat * 1.7 + semilla * 2.0, 0.3)).r;
	float largo_r = (0.2 + 0.7 * u) * smoothstep(0.35, 0.8, reg);
	float regu = smoothstep(0.0, 0.1, dd) * (1.0 - smoothstep(0.0, 1.0, (dd - 0.1) / max(largo_r, 0.01))) * smoothstep(0.55, 0.8, reg) * (1.0 - smoothstep(0.9, 1.0, abs(lat)));
	float forma = clamp(irregular + regu * 0.8, 0.0, 1.0);
	float cau = agua_cau(q * 1.2 + vec2(semilla), TIME * velocidad);
	float v = 0.22 + 0.2 * cau + 0.2 * (1.0 - irregular) + 0.08 * regu;
	// una pared mojada se oscurece y se desatura un poco: mancha gris azulada con apenas un reflejo de cáusticas
	ALBEDO = mix(mix(color_lecho, tono_a, 0.25), agua_tonos(v, 0.40, 0.85, 0.08), 0.4) * brillo;
	float vive = smoothstep(0.0, 0.04, u) * (1.0 - smoothstep(0.35, 1.0, u));
	float canto = fade_canto > 0.0 ? smoothstep(0.0, fade_canto, abs(dot(normalize(NORMAL), VIEW))) : 1.0;
	ALPHA = clamp(forma * opacidad, 0.0, 0.6) * vive * canto * vida;
}
