shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, fog_disabled;

// ESFERA DE AGUA (cara delantera). Translúcida: el centro deja ver lo de detrás, el borde se aclara por fresnel y el interior lleva la red de cáusticas en movimiento; un núcleo algo más
// claro hacia el centro. Sin emisión ni luz. La cara trasera (agua_esfera_atras.gdshader) va debajo para dar volumen. Ver agua_toy.gdshaderinc.
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

uniform float radio = 0.4;               // radio de la malla en metros (normaliza la posición del objeto)
uniform float esc_cau = 0.7;              // tamaño de la red de cáusticas (mayor = más fina; baja = menos granulosa a la distancia del juego)
uniform float rim_pot = 2.1;             // dureza del borde claro (fresnel)
uniform float opacidad = 0.56;           // opacidad del centro
uniform float nucleo_k = 0.62;           // cuánto más claro es el núcleo
uniform float semilla = 0.0;
uniform float espuma_frente : hint_range(0.0, 1.0) = 0.0;   // en vuelo: espuma blanca suave en el borde delantero (-Z del objeto)

varying vec3 p_obj;

void vertex() {
	p_obj = VERTEX / radio;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float nv = clamp(dot(n, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - nv, rim_pot);
	float t = TIME * velocidad + semilla * 7.0;
	float cau = agua_cau3(p_obj * esc_cau + vec3(semilla), normalize(p_obj), t);
	cau = mix(cau, 0.45, 0.35);                          // cáusticas más suaves: menos contraste, no se vuelven grano a distancia
	float nucleo = pow(nv, 2.4) * nucleo_k;
	// espuma en el borde delantero (solo en vuelo): casi blanca, rota por las cáusticas
	float frente = (1.0 - smoothstep(-0.85, -0.1, normalize(p_obj).z)) * espuma_frente;
	float espuma = frente * smoothstep(0.15, 0.7, 0.45 * cau + 0.7 * fres + 0.25);
	float v = 0.18 + 0.30 * cau + 0.5 * nucleo * (0.55 + 0.45 * cau) + 0.62 * fres + 0.5 * espuma;
	vec3 col = agua_tonos(v, 0.40, 0.88, 0.07);
	col = agua_cau_color(col, cau, 0.35);
	col = agua_borde(col, fres, 0.55);
	ALBEDO = col * brillo;
	float a = mix(opacidad, 0.93, fres) + 0.2 * cau * (1.0 - fres) + 0.1 * nucleo + 0.18 * espuma;
	ALPHA = clamp(a, 0.0, 0.94) * vida * agua_prof(SCREEN_UV, VERTEX.z, suave_prof, INV_PROJECTION_MATRIX);
}
