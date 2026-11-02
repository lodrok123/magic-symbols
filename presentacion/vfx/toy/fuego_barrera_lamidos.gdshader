shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// BARRERA de FuegoToy: lamidos de llama que salen de la silueta (los vértices se desplazan hacia fuera con el ruido). Cuerpo en fuego_barrera.gdshaderinc.
#define LAMIDOS
#include "res://presentacion/vfx/toy/fuego_barrera.gdshaderinc"
