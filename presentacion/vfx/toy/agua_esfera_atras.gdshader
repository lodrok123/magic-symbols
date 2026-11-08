shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_mix, fog_disabled;

// ESFERA DE AGUA (cara trasera, se dibuja antes que la delantera). Más oscura y menos opaca: se ve a través de la cara de delante y da volumen a la bola. Ver agua_esfera.gdshader.
#define AGUA_CON_EROSION
#define AGUA_ERO_ESCALA 2.5
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

uniform float radio = 0.4;
uniform float esc_cau = 1.05;
uniform float opacidad = 0.34;
uniform float semilla = 0.0;

varying vec3 p_obj;

void vertex() {
	p_obj = VERTEX / radio;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float nv = clamp(dot(-n, VIEW), 0.0, 1.0);
	float t = TIME * velocidad + semilla * 7.0 + 3.7;
	float cau = agua_cau3(p_obj * esc_cau * 0.8 + vec3(0.3 + semilla), normalize(p_obj), t);
	float v = 0.10 + 0.40 * cau + 0.3 * pow(nv, 2.0);
	float av = agua_ero_av(1.0 - vida);
	vec3 pe = p_obj + vec3(semilla * 13.0);          // el mismo ruido que la cara delantera: los huecos de una dejan ver el hueco de la otra
	ALBEDO = agua_ero_tinte(mix(agua_tonos(v, 0.40, 0.82, 0.07), color_lecho, 0.4), pe, av) * brillo;      // lo que se ve a través: más oscuro y frío (color_lecho del agua del mundo)
	ALPHA = agua_ero_alfa(clamp(opacidad * (0.7 + 0.5 * cau) * (0.5 + 0.5 * (1.0 - nv)), 0.0, 0.7) * agua_fade(vida) * agua_prof(SCREEN_UV, VERTEX.z, suave_prof, INV_PROJECTION_MATRIX), pe, av);
}
