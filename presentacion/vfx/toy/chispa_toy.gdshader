shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled;

// CHISPAS CON ESTELA de la bola en vuelo (ronda 7): quad fino con la cabeza en la partícula y la cola hacia atrás. Cuerpo en particula_toy.gdshaderinc.
const int MODO = 1;
#include "res://presentacion/vfx/toy/particula_toy.gdshaderinc"
