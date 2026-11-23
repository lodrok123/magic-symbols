shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"
uniform vec3 ejes = vec3(1.5);
uniform float crece = 1.0;
uniform float corte = 0.0;
uniform vec3 contacto = vec3(1.0, 0.3, 0.0);
uniform float edad_golpe = 10.0;
varying vec3 piel;
void vertex() {
	piel = VERTEX;
	float cae = smoothstep(0.0, 0.8, corte);
	VERTEX *= ejes;
	VERTEX.y *= 1.0 - cae * cae;
	VERTEX.xz *= 1.0 + 0.12 * cae;
}
void fragment() {
	if (piel.y < 0.0) { discard; }
	float nace = 1.0 - smoothstep(crece - 0.08, crece, piel.y);
	float t = TIME * velocidad;
	vec2 uv = vec2(atan(piel.z, piel.x) / 6.283185 + 0.5, piel.y);
	float flujo_v = texture(flujo, uv * vec2(6.0, 2.0) + vec2(0.1 * t, -0.55 * t)).r;
	float cau = agua_cau(uv * 3.0, t);
	float pie = (1.0 - smoothstep(0.02, 0.16, piel.y)) * smoothstep(0.3, 0.65, flujo_v);
	float distancia = length((piel - contacto) * ejes);
	float onda = exp(-pow((distancia - edad_golpe * 2.5) / 0.09, 2.0)) * (1.0 - smoothstep(0.1, 0.9, edad_golpe));
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	ALBEDO = agua_tonos(0.25 + 0.2 * flujo_v + 0.1 * cau + 0.5 * pie + onda, 0.42, 0.8, 0.07) * brillo;
	ALPHA = (0.12 + 0.17 * fres + 0.09 * flujo_v + 0.46 * pie + 0.5 * onda) * nace * (1.0 - smoothstep(0.65, 1.0, corte)) * vida;
}
