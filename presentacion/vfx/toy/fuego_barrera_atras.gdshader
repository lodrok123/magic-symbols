shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_mix, fog_disabled;

// BARRERA de FuegoToy: caras traseras de la cúpula (se ven a través de la pared translúcida). Cuerpo en fuego_barrera.gdshaderinc.
#include "res://presentacion/vfx/toy/fuego_barrera.gdshaderinc"
