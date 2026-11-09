shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

#include "res://presentacion/vfx/toy/rayo_toy.gdshaderinc"

varying vec4 datos;

void vertex() {
	datos = INSTANCE_CUSTOM;
	vec3 centro = MODELVIEW_MATRIX[3].xyz;
	float escala = length(MODEL_MATRIX[0].xyz);
	vec2 giro = vec2(cos(datos.b), sin(datos.b));
	vec2 p = mat2(giro, vec2(-giro.y, giro.x)) * VERTEX.xy * escala;
	POSITION = PROJECTION_MATRIX * vec4(centro + vec3(p, 0.015), 1.0);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float radio = length(p);
	float angulo = atan(p.y, p.x + 0.00001);
	float dientes = pow(0.5 + 0.5 * cos(angulo * 8.0 + sin(angulo * 3.0)), 4.0);
	if (datos.r > 0.5) {
		float borde = 0.33 + dientes * 0.60;
		float silueta = 1.0 - smoothstep(borde - 0.02, borde + 0.02, radio);
		float nucleo = 1.0 - smoothstep(borde * 0.59, borde * 0.68, radio);
		vec3 sombra = vec3(0.018, 0.027, 0.065);
		vec3 blanco = vec3(1.45, 1.45, 1.30);
		ALBEDO = mix(sombra, blanco, datos.a > 0.5 ? max(0.88, nucleo) : nucleo);
		ALPHA = silueta * datos.g;
	} else {
		float puntas = (1.0 - smoothstep(0.02, 0.11, min(abs(p.x), abs(p.y)))) * (1.0 - smoothstep(0.08, 0.93, radio));
		float halo = 1.0 - smoothstep(0.04, 0.79, radio);
		ALBEDO = mix(color_halo, color_nucleo * 1.4, max(puntas, halo * halo));
		ALPHA = max(puntas, halo * halo * 0.8) * datos.g;
	}
}
