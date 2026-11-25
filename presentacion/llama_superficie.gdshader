shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform float semilla = 0.0;
uniform float calor = 1.0;
void fragment() {
	float h = 1.0 - UV.y;
	float ondula = sin(h * 10.0 - TIME * 9.0 + semilla) * 0.075 * h;
	ondula += sin(h * 19.0 - TIME * 13.0 + semilla * 3.0) * 0.035;
	float ancho = (1.0 - h) * 0.42 * (0.86 + 0.14 * sin(TIME * 11.0 + semilla));
	float forma = abs(UV.x - 0.5 + ondula) / max(ancho, 0.001);
	if (forma > 1.0 || h > 0.97 || calor < 0.01) { discard; }
	vec3 c = mix(vec3(1.0, 0.12, 0.006), vec3(1.0, 0.76, 0.13), step(forma, 0.55) * (1.0 - h));
	ALBEDO = c;
	EMISSION = c * 0.65;
	ALPHA = (1.0 - smoothstep(0.78, 1.0, forma)) * smoothstep(0.0, 0.07, h) * calor;
}
