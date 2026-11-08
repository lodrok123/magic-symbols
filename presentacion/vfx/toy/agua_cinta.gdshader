shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// CINTA DE AGUA (bola, estela y remolino de la carga). Una tira con UV.x a lo largo (0 = origen, 1 = punta) y UV.y a lo ancho. T_Wave43 (lenguas largas) corre a lo largo con un poco de ruido de
// T_Noise_W5i: el valor decide el tono (azul medio → celeste → cresta casi blanca en el borde y en los nudos). La tira se afila en la punta y se desvanece en los dos extremos. Sin luz ni emisión.
#define AGUA_CON_EROSION
#define AGUA_ERO_ESCALA 30.0
#include "res://presentacion/vfx/toy/agua_toy.gdshaderinc"

uniform sampler2D onda : filter_linear_mipmap, repeat_enable;       // T_Wave43
uniform float repeticion = 1.6;          // repeticiones de la textura a lo largo de la tira
uniform float ritmo = 0.55;              // velocidad del flujo a lo largo (+ hacia la punta)
uniform float fase = 0.0;
uniform float opacidad = 0.82;
uniform float extremos = 0.16;           // fundido en el origen (fracción de la tira)
uniform vec2 ero_medida = vec2(3.0, 0.08);      // EROSION: largo y ancho aproximados de la tira en m (el ruido se muestrea en metros: grano parejo a lo largo y a lo ancho)
uniform float punta = 0.45;              // fundido hacia la punta (fracción de la tira)

void fragment() {
	float x = UV.x;
	float cruz = abs(UV.y * 2.0 - 1.0);
	float t = TIME * velocidad;
	vec2 f = (texture(flujo, vec2(x * 1.2 - t * 0.2 + fase, UV.y * 0.7)).rg - 0.5) * 0.22;
	float w = texture(onda, vec2(x * repeticion - t * ritmo + fase + f.x, UV.y * 0.75 + f.y + fase * 0.37)).r;
	float forma = 1.0 - smoothstep(0.5, 1.0, cruz + (0.5 - w) * 0.34);
	float lon = smoothstep(0.0, extremos, x) * (1.0 - smoothstep(1.0 - punta, 1.0, x));
	float v = 0.20 + 0.52 * w + 0.30 * smoothstep(0.45, 1.0, cruz) * forma + 0.10 * (1.0 - cruz);
	// con la erosion encendida la cinta no baja de alfa al morir (la bola la lleva con vida): se COME por ruido y el filo se tine de espuma
	float av = agua_ero_av(1.0 - vida);
	vec3 pe = vec3(UV.x * ero_medida.x, UV.y * ero_medida.y, fase);
	ALBEDO = agua_ero_tinte(agua_tonos(v, 0.40, 0.76, 0.07), pe, av) * brillo;
	ALPHA = agua_ero_alfa(clamp(forma * lon * opacidad, 0.0, 0.9) * agua_fade(vida) * agua_prof(SCREEN_UV, VERTEX.z, suave_prof, INV_PROJECTION_MATRIX), pe, av);
}
