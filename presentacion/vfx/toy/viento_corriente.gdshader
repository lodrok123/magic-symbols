shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 claro : source_color = vec4(0.95, 1.0, 0.97, 1.0);
uniform vec4 sombra : source_color = vec4(0.55, 0.79, 0.71, 1.0);

void fragment() {
	float centro = 1.0 - abs(UV.x * 2.0 - 1.0);
	float punta = smoothstep(0.0, 0.19, UV.y) * (1.0 - smoothstep(0.66, 1.0, UV.y));
	float nervio = smoothstep(0.26, 0.92, centro);
	vec3 base = mix(sombra.rgb, claro.rgb, nervio);
	float cobertura = smoothstep(0.0, 0.75, centro);
	if (COLOR.g < 0.25) {
		base = mix(vec3(0.50), vec3(0.88), nervio);
	} else if (COLOR.g < 0.75) {
		base = mix(vec3(0.18, 0.54, 0.13), claro.rgb, nervio);
	} else if (COLOR.g < 0.9) {
		// Las cintas del tornado se ensanchan por tramos y se afinan en los extremos.
		float perfil = 0.29 + 0.62 * sin(UV.y * 3.14159)
			+ 0.11 * sin(UV.y * 17.0 + TIME * 2.4);
		float sesgo = sin(UV.y * 9.0 + TIME * 1.6) * 0.11;
		float cinta = 1.0 - abs(UV.x * 2.0 - 1.0 + sesgo) / perfil;
		float cuerpo = smoothstep(0.06, 0.78, cinta);
		float borde = smoothstep(-0.16, 0.19, cinta);
		base = mix(sombra.rgb, claro.rgb, smoothstep(0.17, 0.8, cinta));
		cobertura = borde * (0.21 + cuerpo * 0.79);
	}
	ALBEDO = base;
	ALPHA = cobertura * punta * COLOR.a;
}
