shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// ANILLO / CHARCO DE ONDAS (salpicadura y casteo). Un quad tumbado sobre la superficie (se orienta con su normal): de dentro afuera, un charco suave (T_VFX_CircleFit1) con cáusticas y hasta tres
// anillos de onda que se expanden y se desvanecen; el borde de cada anillo lo deforma un ruido (T_Noise_W5i) para que no sea un círculo perfecto. `u` = 0..1 es la edad: lo anima quien lo usa.
// Sin luz ni emisión. De canto se desvanece (fade_canto), así que con la cámara baja no se queda en una raya.
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

uniform sampler2D disco : filter_linear, repeat_disable;           // T_VFX_CircleFit1
uniform float u : hint_range(0.0, 1.0) = 0.0;
uniform float anillos : hint_range(1.0, 3.0) = 3.0;
uniform float grosor = 0.075;
uniform float separacion = 0.17;
uniform float charco = 0.55;             // opacidad del charco de dentro
uniform float radio_ini = 0.1;
uniform float radio_fin = 0.94;
uniform float borde_ruido = 0.022;
uniform float aparece = 0.05;            // fracción de u que tarda en aparecer
uniform float se_va = 0.45;              // u a partir de la cual se desvanece
uniform float fade_canto : hint_range(0.0, 1.0) = 0.3;
uniform float semilla = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float ru = texture(flujo, vec2(cos(ang), sin(ang)) * 0.22 + vec2(0.5 + semilla, 0.5 + u * 0.4)).r;
	float rr = r + (ru - 0.5) * borde_ruido * (0.5 + u * 1.5) * 2.0;
	float frente = 1.0 - pow(1.0 - u, 2.4);
	float r0 = mix(radio_ini, radio_fin, frente);
	float anillo = 0.0;
	float cresta = 0.0;
	for (int k = 0; k < 3; k++) {
		float on = step(float(k) + 0.5, anillos);
		float rk = r0 - float(k) * separacion * (0.55 + frente);
		float d = abs(rr - rk) / (grosor * (0.7 + 0.8 * u));
		float ring = (1.0 - smoothstep(0.0, 1.0, d)) * on * (1.0 - 0.28 * float(k)) * step(0.0, rk);
		anillo = max(anillo, ring);
		cresta = max(cresta, (1.0 - smoothstep(0.0, 0.45, d)) * on * step(0.0, rk) * (1.0 - 0.3 * float(k)));
	}
	float t = TIME * velocidad;
	float cau = agua_cau(p * 1.1 + vec2(semilla * 3.0), t);
	float masa = texture(disco, UV).r;
	float relleno = (1.0 - smoothstep(r0 * 0.5, r0, rr)) * masa * charco;
	float v = 0.22 + 0.34 * cau * relleno + 0.48 * anillo + 0.24 * cresta;      // la cresta de cada anillo llega a espuma (franja clara, como el borde del agua del mundo)
	vec3 col = agua_tonos(v, 0.40, 0.78, 0.07);
	col = mix(col, color_lecho, 0.28 * relleno * (1.0 - anillo));      // el charco deja ver el lecho (como el agua del mundo)
	col = agua_cau_color(col, cau, 0.4 * relleno);
	ALBEDO = col * brillo;
	float vive = smoothstep(0.0, aparece, u) * (1.0 - smoothstep(se_va, 1.0, u));
	float a = clamp(max(anillo * 0.85, relleno * (0.55 + 0.35 * cau)), 0.0, 0.9) * vive;
	float canto = 1.0;
	if (fade_canto > 0.0) {
		canto = smoothstep(0.0, fade_canto, abs(dot(normalize(NORMAL), VIEW)));
	}
	ALPHA = a * canto * vida * (1.0 - smoothstep(0.88, 1.0, r));
}
