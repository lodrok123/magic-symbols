shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// CORTINA DE LA OLA (fase 4, 3/11/2026; AguaToy.Figura.MURO). Una lámina que recorre toda la ola a lo largo de x (UV.x = -a..a) y a lo largo de su PERFIL (UV.y = s: 0 pie de atrás → espalda que sube →
// CRESTA → labio que se RIZA hacia delante → cara delantera cóncava → pie de delante). El vértice shader dibuja ese perfil en el plano (z, y): la ola viaja hacia -Z (el frente del objeto).
//   crece 0 → 1   la ola SUBE desde el suelo (el rizo se forma al final de la subida)
//   corte 0 → 1   la ola CAE hacia delante (la altura se desploma y la cabeza se inclina hacia -Z)
//   avance (m)    lo que ha avanzado hacia delante; la cresta además ondula con el tiempo (ruido por x)
//   capa -1 / 0 / 1   desplazamiento en z: tres cortinas a distinta profundidad para que de canto la ola tenga volumen
// FRAGMENT: T_LiquidVertical_Wave corriendo por la espalda hacia la cresta (solo el detalle de la textura), bandas hondo / somero, borde claro por fresnel y ESPUMA en el labio, en el pie y por la cresta.
// Es agua: blend_mix, sin emisión ni luz, paleta del agua del mundo (agua_paleta.gd).
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

uniform sampler2D liquido : filter_linear_mipmap, repeat_enable;    // T_LiquidVertical_Wave
uniform float a = 3.45;                  // semieje x
uniform float b = 0.3;                   // semieje z
uniform float alto = 1.5;
uniform float crece : hint_range(0.0, 1.0) = 1.0;
uniform float corte : hint_range(0.0, 1.0) = 0.0;
uniform float avance = 0.0;
uniform float capa = 0.0;
uniform float semilla = 0.0;
uniform float opacidad = 0.55;
uniform float ritmo = 0.5;
uniform float ondulacion : hint_range(0.0, 1.5) = 0.6;

varying float v_s;
varying float v_x;
varying float v_yh;
varying float v_h;

float envol(float x, float t, float sem) {
	float borde = 1.0 - 0.6 * pow(clamp(abs(x) / max(a, 0.01), 0.0, 1.0), 4.0);
	float n = textureLod(flujo, vec2(x * 0.32 + sem, t * 0.05 + sem * 0.5), 0.0).r;
	return borde * (0.86 + 0.34 * (n - 0.5) * (0.4 + ondulacion));
}

// Perfil en el plano (z, y). H = altura de la cresta, R = radio del rizo, Lb = largo de la espalda, cu = cuánto se ha rizado (0..1), zc = z de la cresta.
vec2 perfil(float s, float H, float R, float Lb, float cu, float zc) {
	float s1 = 0.42;
	float s2 = 0.68;
	float al_max = radians(120.0) * cu;
	if (s < s1) {
		float u = s / s1;
		return vec2(mix(zc + Lb, zc, u), H * (1.0 - pow(1.0 - u, 2.2)));
	}
	if (s < s2) {
		float u = (s - s1) / (s2 - s1);
		float al = u * al_max;
		return vec2(zc - R * sin(al), (H - R) + R * cos(al));
	}
	vec2 tip = vec2(zc - R * sin(al_max), (H - R) + R * cos(al_max));
	float u = (s - s2) / (1.0 - s2);
	float zf = tip.x - 0.4 * R - 0.1 * H;
	return vec2(mix(tip.x, zf, u * u), tip.y * (1.0 - u));
}

// El mismo perfil con la caída aplicada: al caer, la altura se desploma y todo se inclina hacia delante (-Z) más cuanto más alto.
vec2 punto(float s, float H, float R, float Lb, float cu, float zc, float f2) {
	vec2 p = perfil(s, H, R, Lb, cu, zc);
	p.x -= f2 * 1.25 * p.y;
	p.x *= 1.0 + 0.5 * f2;
	p.y *= 1.0 - 0.88 * f2;
	return p;
}

void vertex() {
	float t = TIME * velocidad;
	float x = (UV.x - 0.5) * 2.0 * a;
	float rise = smoothstep(0.0, 1.0, crece);
	float H = alto * rise * envol(x, t, semilla) * (1.0 - 0.15 * abs(capa));
	float cu = smoothstep(0.45, 1.0, crece);
	float R = max(0.26 * H, 0.02);
	float Lb = 2.0 * b + 0.25 * H;
	float f2 = pow(clamp(corte, 0.0, 1.0), 1.4);
	float zc = -avance + capa * b * 0.9 + 0.07 * ondulacion * sin(x * 1.7 + t * 1.3 + semilla * 6.0) + 0.05 * sin(x * 4.1 - t * 1.9);
	vec2 p0 = punto(UV.y, H, R, Lb, cu, zc, f2);
	vec2 p1 = punto(min(UV.y + 0.012, 1.0), H, R, Lb, cu, zc, f2);
	vec2 tg = p1 - p0;
	VERTEX = vec3(x, p0.y, p0.x);
	NORMAL = normalize(vec3(0.0, -tg.x, tg.y) + vec3(0.0001));
	v_s = UV.y;
	v_x = x;
	v_yh = clamp(p0.y / max(H, 0.02), 0.0, 1.2);
	v_h = H;
}

float tri(float x) {
	return abs(fract(x * 0.5) * 2.0 - 1.0);
}

void fragment() {
	float t = TIME * velocidad;
	float s = v_s;
	float lon = s * (2.2 * alto);           // metros aproximados a lo largo del perfil
	vec2 ua = vec2(v_x * 0.45 + semilla, tri(1.0 - lon * 0.42 + t * ritmo));
	vec2 ub = vec2(v_x * 0.9 + 0.31 + semilla * 1.3, tri(1.0 - lon * 0.8 + t * ritmo * 1.6));
	float d1 = clamp(texture(liquido, ua).r - textureLod(liquido, ua, 5.0).r + 0.45, 0.0, 1.0);
	float d2 = clamp(texture(liquido, ub).r - textureLod(liquido, ub, 5.0).r + 0.45, 0.0, 1.0);
	float cau = agua_cau(vec2(v_x * 0.6, lon * 0.5 - t * 0.15) + semilla, t);
	float fres = pow(clamp(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 1.6);
	// espuma: el labio (donde se riza), la cresta rota por la textura, y los dos pies
	float labio = smoothstep(0.5, 0.58, s) * (1.0 - smoothstep(0.66, 0.74, s));
	float tira = smoothstep(0.5, 0.82, 0.55 * d1 + 0.3 * d2 + 0.35 * cau);
	float espuma = labio * (0.35 + 0.65 * tira) * smoothstep(0.1, 0.5, crece);
	espuma = max(espuma, (1.0 - smoothstep(0.0, 0.07, s)) * (0.5 + 0.5 * tira));
	espuma = max(espuma, smoothstep(0.93, 1.0, s) * (0.4 + 0.6 * tira));
	espuma = max(espuma, smoothstep(0.9, 0.99, v_yh) * (1.0 - smoothstep(0.42, 0.5, s)) * tira * 0.8);       // la parte alta de la espalda
	float v = 0.04 + 0.34 * d1 + 0.14 * d2 + 0.10 * cau + 0.22 * fres + 0.36 * v_yh + 0.7 * espuma;
	vec3 col = agua_tonos(v, 0.46, 0.80, 0.07);
	col = agua_cau_color(col, cau, 0.25);
	col = agua_borde(col, fres, 0.5);
	ALBEDO = col * brillo;
	float al = opacidad * (0.5 + 0.28 * d1 + 0.3 * fres) + 0.4 * espuma;
	al *= smoothstep(0.0, 0.04, s) * (1.0 - smoothstep(0.96, 1.0, s));
	al *= 1.0 - smoothstep(0.86, 1.0, abs(v_x) / max(a, 0.01));
	al *= smoothstep(0.015, 0.08, v_h);
	al *= 1.0 - smoothstep(0.78, 1.0, corte);
	ALPHA = clamp(al, 0.0, 0.92) * vida * agua_prof(SCREEN_UV, VERTEX.z, suave_prof, INV_PROJECTION_MATRIX);
}
