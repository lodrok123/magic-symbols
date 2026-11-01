shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_mix, fog_disabled;

// BARRERA DE FUEGO, cara de atrás (prueba 3 de VFX): se pinta primero para que la de delante se mezcle encima. El cuerpo está en barrera_toy.gdshaderinc.
#include "res://presentacion/vfx/toy/barrera_toy.gdshaderinc"
