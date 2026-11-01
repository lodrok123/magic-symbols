shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// JIRONES de la bola en vuelo (ronda 7): trozos de la textura de lenguas que se estiran y se apagan. Cuerpo en particula_toy.gdshaderinc.
const int MODO = 0;
#include "res://presentacion/vfx/toy/particula_toy.gdshaderinc"
