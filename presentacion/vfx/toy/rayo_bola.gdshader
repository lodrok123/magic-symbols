shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, fog_disabled;

// CUERPO DE LA BOLA DE RAYO (ronda de la bola, 3/11/2026). Una ESFERA que se lee como esfera: núcleo blanco-amarillo denso en el centro y el amarillo del rayo del juego hacia el borde (fresnel), con un
// filo azul profundo en el canto y vetas que crepitan por la superficie. MEZCLA NORMAL (como el cuerpo amarillo del trazo: sumar amarillo a un suelo claro da blanco), unshaded, sin escribir profundidad
// y sin EMISSION. `intensidad` (0,6 a 1) es el parpadeo del núcleo: nunca baja de 0,6 para que la bola no desaparezca. Los colores son los de la paleta del rayo (rayo_paleta.gd).
#include "res://presentacion/vfx/toy/rayo_toy.gdshaderinc"

uniform float intensidad : hint_range(0.0, 1.0) = 1.0;
uniform float agitacion : hint_range(0.0, 1.0) = 0.6;
uniform float difusion : hint_range(0.0, 1.0) = 0.0;

varying vec3 pos_obj;

void vertex() {
	pos_obj = VERTEX;
}

void fragment() {
	float nv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float borde = 1.0 - nv;                                              // 0 de cara, 1 en el canto
	// vetas que se mueven por la superficie (crepitan)
	float t = TIME * 34.0 * velocidad;
	float v1 = sin(pos_obj.x * 9.0 + t) * sin(pos_obj.y * 7.0 - t * 0.8) * sin(pos_obj.z * 8.0 + t * 1.3);
	float v2 = sin(pos_obj.y * 12.0 - t * 1.1 + pos_obj.x * 5.0) * sin(pos_obj.z * 10.0 + t * 0.7);
	float veta = smoothstep(0.55, 0.95, abs(v1) * 0.6 + abs(v2) * 0.55) * agitacion;
	vec3 c = mix(color_nucleo, color_cuerpo, smoothstep(0.03, 0.38, borde));      // blanco solo en el centro, amarillo en casi todo el disco
	c = mix(c, color_nucleo, veta * 0.7);                                         // las vetas son blancas
	c = mix(c, color_hondo * 0.55, smoothstep(0.63, 0.83, borde));                 // el mismo filo azul del arco
	float a = mix(0.99, 0.75, smoothstep(0.7, 1.0, borde));
	a *= 1.0 - difusion * smoothstep(0.30, 1.0, borde);
	ALBEDO = c * brillo;
	ALPHA = clamp(a, 0.0, 1.0) * intensidad * vida;
}
