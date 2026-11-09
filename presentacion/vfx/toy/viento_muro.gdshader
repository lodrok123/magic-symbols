shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 verde : source_color = vec4(0.37, 0.70, 0.36, 1.0);
uniform vec4 claro : source_color = vec4(0.81, 0.99, 0.66, 1.0);
uniform float tiempo = 0.0;
uniform float opacidad = 1.0;

void fragment() {
	float altura = UV.y;
	float deriva = sin(altura * 6.2 - tiempo * 2.8 + UV.x * 4.0);
	float lenta = sin(UV.x * 56.0 - altura * 10.0 + tiempo * 3.0 + deriva * 1.65);
	float rapida = sin(UV.x * 115.0 - altura * 21.0 + tiempo * 8.4 + deriva * 2.1);
	float vetas = smoothstep(0.16, 0.96, lenta) * 0.64 + smoothstep(0.58, 1.0, rapida) * 0.36;

	float lateral = smoothstep(0.0, 0.14, min(UV.x, 1.0 - UV.x));
	float cresta = 0.80 + 0.065 * sin(UV.x * 19.0 - tiempo * 4.4) + deriva * 0.035;
	float techo = 1.0 - smoothstep(cresta - 0.19, cresta + 0.15, altura);
	float pie = smoothstep(0.0, 0.055, altura);

	ALBEDO = mix(verde.rgb, claro.rgb, vetas * 0.61);
	ALPHA = lateral * techo * pie * (0.25 + vetas * 0.25) * opacidad;
}
