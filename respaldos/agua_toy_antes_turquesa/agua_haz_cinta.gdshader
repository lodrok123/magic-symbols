shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// CINTA ENROLLADA EN EL HAZ DE AGUA (fase 2). Tira helicoidal alrededor del eje del haz (AguaMallas.cinta con z de 0 a -largo, UV.x = u de 0 a 1 a lo largo). El vertex shader la mueve con `crece`
// (la cinta sale del origen con el chorro) y `corte` (se suelta, avanza y se afloja), igual que agua_haz.gdshader. T_Wave43 corre a lo largo, rápido, hacia fuera. Sin luz ni emisión.
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

uniform sampler2D onda : filter_linear_mipmap, repeat_enable;       // T_Wave43
uniform float altura : hint_range(0.3, 3.0) = 1.0;
uniform float ancho : hint_range(0.3, 2.0) = 1.0;
uniform float blandura : hint_range(0.05, 1.0) = 0.2;
uniform float ondulacion : hint_range(0.0, 1.5) = 0.6;
uniform float tono : hint_range(0.0, 1.0) = 0.0;
uniform float chisporroteo : hint_range(0.0, 1.0) = 0.6;
uniform float largo = 3.0;
uniform float crece : hint_range(0.0, 1.0) = 1.0;
uniform float corte : hint_range(0.0, 1.0) = 0.0;
uniform float fase = 0.0;
uniform float repeticion = 2.2;
uniform float ritmo = 1.5;
uniform float opacidad = 0.6;

varying float v_u;
varying float v_sc;

void vertex() {
	float g = max(crece, 0.03);
	float sc = UV.x * g + corte * 0.6;
	float afloja = mix(1.0, smoothstep(corte * 0.7 - 0.02, corte * 0.7 + 0.22, UV.x * g), step(0.001, corte));
	VERTEX.xy *= afloja;
	VERTEX.z = VERTEX.z * g - corte * 0.6 * largo;
	v_u = UV.x;
	v_sc = sc;
}

void fragment() {
	float x = UV.x;
	float cruz = abs(UV.y * 2.0 - 1.0);
	float t = TIME * velocidad;
	vec2 f = (texture(flujo, vec2(x * 1.4 - t * 0.3 + fase, UV.y * 0.7)).rg - 0.5) * 0.25;
	float w = texture(onda, vec2(x * repeticion - t * ritmo + fase + f.x, UV.y * 0.75 + f.y + fase * 0.37)).r;
	float forma = 1.0 - smoothstep(0.5, 1.0, cruz + (0.5 - w) * 0.34);
	float lon = smoothstep(0.0, 0.1, x) * (1.0 - smoothstep(0.86, 1.0, x));
	lon *= mix(1.0, smoothstep(corte * 0.7 - 0.02, corte * 0.7 + 0.22, v_u * crece), step(0.001, corte));
	lon *= 1.0 - smoothstep(0.65, 1.0, corte);
	float v = 0.30 + 0.5 * w + 0.28 * smoothstep(0.45, 1.0, cruz) * forma + 0.08 * (1.0 - cruz);
	ALBEDO = agua_tonos(v, 0.44, 0.78, 0.07) * brillo;
	ALPHA = clamp(forma * lon * opacidad, 0.0, 0.85) * vida * agua_prof(SCREEN_UV, VERTEX.z, suave_prof, INV_PROJECTION_MATRIX);
}
