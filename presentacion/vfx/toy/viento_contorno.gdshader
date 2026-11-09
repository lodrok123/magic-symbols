shader_type spatial;
render_mode unshaded, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 color_borde : source_color = vec4(0.83, 0.85, 0.84, 1.0);
uniform float opacidad = 1.0;
uniform bool tornado = false;
uniform float tiempo = 0.0;
varying float altura;

void vertex() {
	altura = VERTEX.y + 0.5;
	if (tornado) {
		float nivel = altura * 1.1;
		float radio = mix(0.75, 1.92, altura) + sin(nivel * 10.0 - tiempo * 2.8) * 0.08;
		vec2 eje = vec2(
			sin(nivel * 5.5 - tiempo * 2.4) * (0.13 + nivel * 0.38),
			cos(nivel * 4.0 - tiempo * 1.8) * nivel * 0.27
		);
		VERTEX.xz = VERTEX.xz * radio + eje * 0.5;
	}
}

void fragment() {
	float rasante = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float borde = smoothstep(0.71, 0.96, rasante);
	if (tornado) {
		float extremos = smoothstep(0.0, 0.16, altura) * (1.0 - smoothstep(0.84, 1.0, altura));
		borde = smoothstep(0.48, 0.97, rasante) * extremos;
	}
	ALBEDO = color_borde.rgb;
	ALPHA = borde * opacidad * 0.82;
}
