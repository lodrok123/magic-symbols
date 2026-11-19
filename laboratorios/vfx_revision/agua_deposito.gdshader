shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"
uniform float reloj = 0.0;
uniform float expansion = 0.0;
uniform float edad = 0.0;
uniform float limite_x = 1000.0;
varying vec3 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	if (mundo.x > limite_x) { discard; }
	// El quad es 1,3 veces mayor que el charco para dejar sitio a los islotes sueltos.
	vec2 p = (UV * 2.0 - 1.0) * 1.3;
	float a = atan(p.y, p.x);
	float borde = 0.90 + 0.045 * sin(a * 5.0 + 1.0) + 0.025 * sin(a * 9.0);
	float r = length(p);
	// Frente de lobulos: cada direccion avanza a su ritmo y los rezagados alcanzan despues.
	float ritmo = 1.0 + 0.9 * (0.5 + 0.5 * sin(a * 4.0 + 2.0 + 1.3 * sin(a * 2.0)));
	float ex = pow(clamp(expansion, 0.0, 1.0), ritmo);
	float dedo = 1.0 + 0.10 * pow(0.5 + 0.5 * sin(a * 7.0 + 0.6), 3.0) * (1.0 - expansion);
	float mascara = 1.0 - smoothstep(borde * ex * dedo - 0.045, borde * ex * dedo, r);
	// Ruido de la textura de flujo del proyecto (en UV del charco: viaja con el).
	float rn1 = textureLod(flujo, UV * 2.2, 0.0).r;
	float rn2 = textureLod(flujo, UV * 5.3 + vec2(0.37, 0.61), 0.0).r;
	float ruido = rn1 * 0.65 + rn2 * 0.35;
	// Retirada en islotes: el campo cae desde el borde y el umbral sube con la edad.
	float gr = r / max(borde, 0.001);
	float retiro = 1.0 - vida;
	// El ruido apenas actua al principio y gobierna la ruptura cuando el charco se retira.
	float amp = 0.5 + 2.4 * smoothstep(0.0, 0.6, retiro);
	float campo = 1.15 - gr * 0.95 + (ruido - 0.5) * amp;
	float umbral = retiro * 1.35 - 0.12;
	float isla = smoothstep(umbral - 0.05, umbral + 0.05, campo);
	mascara *= isla;
	// Islotes sueltos delante del frente: gotas que aterrizaron y se unen al charco.
	float suelto = smoothstep(0.62, 0.68, rn2) * (1.0 - smoothstep(1.0, 1.35, gr))
		* smoothstep(0.30, 0.75, expansion) * (1.0 - smoothstep(0.05, 0.45, retiro));
	mascara = max(mascara, suelto * 0.9 * (1.0 - smoothstep(0.55, 1.0, retiro)));
	float ondas = pow(0.5 + 0.5 * sin(r * 30.0 - edad * 14.0), 12.0);
	float rizo = ondas * exp(-edad * 1.6) * smoothstep(0.0, 0.08, edad);
	float cau = agua_cau(mundo.xz * 1.3, reloj * velocidad);
	vec3 col = agua_tonos(0.20 + 0.30 * cau + 0.25 * rizo, 0.40, 0.78, 0.07);
	col = agua_cau_color(col, cau, 0.35);
	ALBEDO = mix(color_lecho, col, 0.85) * brillo;
	ALPHA = mascara * vida * (0.45 + 0.12 * cau + rizo * 0.16);
}
