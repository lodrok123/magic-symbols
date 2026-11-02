shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// Sprite de Le Lu con la rampa de la bola, mezcla normal (no se lava en fondos claros) y con prueba de profundidad. Ver lelu_sprite.gdshaderinc.
#include "res://presentacion/vfx/toy/lelu_sprite.gdshaderinc"

void fragment() {
	vec4 c = sprite_color(UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
