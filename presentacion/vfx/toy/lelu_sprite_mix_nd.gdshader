shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix, fog_disabled;

// Sprite de Le Lu con la rampa de la bola, mezcla normal y SIN prueba de profundidad (billboards medio hundidos en una pared o el suelo). Ver lelu_sprite.gdshaderinc.
#include "res://presentacion/vfx/toy/lelu_sprite.gdshaderinc"

void fragment() {
	vec4 c = sprite_color(UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
