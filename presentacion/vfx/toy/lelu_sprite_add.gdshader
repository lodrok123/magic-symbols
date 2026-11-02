shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_add, fog_disabled;

// Sprite de Le Lu con la rampa de la bola, ADITIVO y sin prueba de profundidad: solo para el destello del primer instante (T_VFX_hit22). Ver lelu_sprite.gdshaderinc.
#include "res://presentacion/vfx/toy/lelu_sprite.gdshaderinc"

void fragment() {
	vec4 c = sprite_color(UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
