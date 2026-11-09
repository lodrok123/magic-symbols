shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, shadows_disabled;

uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform vec4 centro_verde : source_color = vec4(0.53, 0.79, 0.43, 1.0);
uniform vec4 verde_claro : source_color = vec4(0.88, 1.0, 0.70, 1.0);

void fragment() {
	float frente = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float radio = sqrt(1.0 - frente * frente);
	float degradado = smoothstep(0.13, 0.89, radio);
	float borde = 1.0 - smoothstep(0.88, 1.0, radio);
	ALBEDO = mix(centro_verde.rgb, verde_claro.rgb, degradado);
	ALPHA = mix(0.82, 0.96, degradado) * borde * vida;
}
