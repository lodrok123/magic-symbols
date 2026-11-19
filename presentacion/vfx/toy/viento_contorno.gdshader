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
		// COLUMNA DE VIENTO (16/11): el mismo perfil que las vetas (perfil_columna en viento_corrientes.gd) y el eje quieto. Antes esto era un CONO (0,75 -> 1,92) con el eje
		// tambaleandose: la silueta se salia del cilindro de la huella del hechizo y las vetas, que ahora van rectas, no la tocaban.
		float nivel = clamp(altura * 1.1, 0.0, 1.0);   // el contorno mide 1,1 veces la altura de las vetas
		// sin boca ensanchada: el ensanche de la base (que las vetas si llevan) dejaba dos manchas redondas en los costados de la columna baja
		float radio = 1.0 + 0.12 * smoothstep(0.6, 1.0, nivel);
		VERTEX.xz = VERTEX.xz * radio;
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
