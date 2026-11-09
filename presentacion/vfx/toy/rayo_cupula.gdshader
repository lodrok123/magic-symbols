shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, fog_disabled;

#include "res://presentacion/vfx/toy/rayo_toy.gdshaderinc"

uniform float aparicion_cupula : hint_range(0.0, 1.0) = 0.0;
varying vec3 superficie;

void vertex() {
	superficie = VERTEX;
}

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.11369, 0.13787));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float ruido(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), u.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), u.x), u.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), u.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), u.x), u.y), u.z);
}

void fragment() {
	float frente = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float borde = 1.0 - frente;
	float t = TIME * velocidad;
	vec3 p = superficie;
	p.xz += vec2(p.z, -p.x) * (p.y * 0.7 + sin(t * 0.64) * 0.18);
	float nube = ruido(p * vec3(2.7, 4.3, 2.7) + vec3(t * 0.24, -t * 0.31, 0.0));
	float veta = ruido(p * vec3(5.2, 9.0, 5.2) + vec3(nube * 2.0, -t * 0.38, t * 0.23));
	float velo = smoothstep(0.33, 0.78, nube * 0.66 + veta * 0.34);
	float orilla = smoothstep(0.31, 0.91, borde);
	float filo = smoothstep(0.72, 0.99, borde) * (0.52 + nube * 0.48);
	float suelo = smoothstep(-0.68, -0.60, superficie.y);
	vec3 tono = color_cuerpo * mix(0.68, 1.0, velo * 0.66 + orilla * 0.24);
	tono = mix(tono, color_nucleo, filo * 0.35);
	ALBEDO = tono * brillo * (1.0 + filo * 0.28);
	ALPHA = (0.10 + 0.18 * velo + 0.59 * orilla) * suelo * aparicion_cupula * vida;
}
