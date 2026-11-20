shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// Brillos puntuales del impacto: quads que miran a la camara, con nucleo blando y cuatro
// rayos finos. Color: tono somero de la paleta del agua aclarado hacia la espuma, sin llegar
// a blanco puro. El tamano y el momento los decide el script (escala de cada instancia).
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

uniform float reloj = 0.0;
uniform float intensidad : hint_range(0.0, 2.0) = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float nucleo = pow(1.0 - smoothstep(0.0, 0.55, d), 2.2);
	float halo = pow(1.0 - smoothstep(0.0, 1.0, d), 3.0) * 0.45;
	float rayos = (1.0 - smoothstep(0.0, 0.07, min(abs(p.x), abs(p.y)))) * (1.0 - smoothstep(0.25, 1.0, d)) * 0.55;
	float f = clamp(nucleo + halo + rayos, 0.0, 1.0);
	vec3 col = mix(tono_b, tono_c, 0.62);
	ALBEDO = mix(col, tono_c, nucleo * 0.5) * brillo;
	ALPHA = f * intensidad;
}
