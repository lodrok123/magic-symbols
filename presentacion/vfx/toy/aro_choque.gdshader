shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
// Mezcla normal, no aditiva: sumado sobre un suelo claro el naranja se lavaba a crema (nunca amarillo); así el aro es un trazo toon opaco del color de la rampa.

// ARO DE CHOQUE NÍTIDO (25/11/2026, lo que faltaba tras la comparativa con Effekseer: el aro de hit01, la onda de choque toon de hit02 y los arcos de ToonHit).
// Sin textura: un anillo de BORDE DURO (anti-alias de un píxel con fwidth), en dos tonos toon (cuerpo y filo exterior claro), que puede partirse en `arcos` afilados.
// La CPU lo anima: `radio` crece, `grosor` adelgaza y `vida` lo apaga (impacto_capas_toy.gd, pieza «aro»). Billboard (2) o tumbado en la superficie (0).

uniform vec3 color : source_color = vec3(1.0, 0.36, 0.08);       // cuerpo del aro
uniform vec3 color_filo : source_color = vec3(1.0, 0.72, 0.42);  // banda exterior (más clara)
uniform float brillo : hint_range(0.0, 4.0) = 1.0;                // multiplica el color (> 1 lo aclara un poco)
uniform float radio : hint_range(0.0, 1.0) = 0.7;                // borde exterior, en fracción del quad (1 = toca el borde)
uniform float grosor : hint_range(0.0, 1.0) = 0.25;              // fracción del radio que ocupa el aro hacia dentro
uniform float filo : hint_range(0.0, 1.0) = 0.35;                // fracción exterior del grosor pintada con color_filo
uniform int arcos : hint_range(0, 12) = 0;                       // 0 = aro entero; n = n arcos
uniform float hueco : hint_range(0.0, 0.9) = 0.35;               // fracción de cada arco que queda vacía
uniform float giro = 0.0;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform int billboard : hint_range(0, 2) = 2;
uniform float fade_canto : hint_range(0.0, 1.0) = 0.0;

#include "res://presentacion/vfx/toy/nucleo_toy.gdshaderinc"

void vertex() {
	if (billboard == 2) {
		vec3 esc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		MODELVIEW_MATRIX = nucleo_billboard(esc, VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
	}
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float aa = max(fwidth(r), 0.0005);
	float g = grosor * radio;
	if (arcos > 0) {
		// arcos afilados: el grosor va de 0 en las puntas a entero en el centro de cada arco (medias lunas)
		float a = fract((atan(p.y, p.x) + giro) / 6.2831853 * float(arcos));
		float lleno = 1.0 - hueco;
		float s = clamp(a / max(lleno, 0.001), 0.0, 1.0);
		g *= (a < lleno) ? sin(3.1415927 * s) : 0.0;
	}
	float r_in = radio - g;
	float m = smoothstep(r_in - aa, r_in + aa, r) * (1.0 - smoothstep(radio - aa, radio + aa, r));
	m *= step(0.0005, g);
	float t = (r - r_in) / max(g, 0.0001);                           // 0 borde interior .. 1 borde exterior
	float banda = smoothstep(1.0 - filo - aa / max(g, 0.0001), 1.0 - filo + aa / max(g, 0.0001), t);
	vec3 c = mix(color, color_filo, banda);
	float suave = 1.0;
	if (fade_canto > 0.0) {
		suave = smoothstep(0.0, fade_canto, abs(dot(normalize(NORMAL), normalize(VIEW))));
	}
	ALBEDO = c * brillo;
	ALPHA = clamp(m * vida * suave, 0.0, 1.0);
}
