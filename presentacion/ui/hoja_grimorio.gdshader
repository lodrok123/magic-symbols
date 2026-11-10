shader_type canvas_item;
render_mode unshaded;

uniform sampler2D libro : hint_screen_texture, repeat_disable, filter_linear;
varying vec4 luz;

void vertex() {
	luz = COLOR;
}

void fragment() {
	COLOR = vec4(texture(libro, UV).rgb * luz.rgb, luz.a);
}
