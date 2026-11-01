// BOLA TOON (1/11, prueba 2 de VFX, opcional). Núcleo de la bola de fuego: un círculo de borde ondulado y tres tonos planos concéntricos (borde, cuerpo,
// núcleo) con la rampa en escalones del fuego. Billboard completo, sin luz, alfa 0/1, tiempo cuantizado a `fps`.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

uniform sampler2D rampa : source_color, filter_nearest, repeat_disable;
uniform float fps : hint_range(2.0, 60.0) = 12.0;
uniform float onda : hint_range(0.0, 0.3) = 0.1;           // cuánto ondula el contorno
uniform float lobulos : hint_range(3.0, 12.0) = 7.0;       // picos del contorno
uniform float radio_base : hint_range(0.3, 0.95) = 0.82;  // radio medio de la bola dentro del quad (con la onda no debe pasar de 1)
uniform float brillo : hint_range(0.2, 3.0) = 1.0;
uniform float erosion : hint_range(0.0, 1.0) = 0.0;
uniform float contorno : hint_range(0.0, 1.0) = 0.0;       // grosor de la línea oscura del borde (0 = sin contorno)
uniform vec4 color_contorno : source_color = vec4(0.45, 0.1, 0.06, 1.0);

varying float v_t;

void vertex() {
	v_t = floor(TIME * fps) / fps;
	float s = (length(MODEL_MATRIX[0].xyz) + length(MODEL_MATRIX[1].xyz)) * 0.5;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float ang = atan(p.y, p.x);
	float r = length(p);
	float radio = (radio_base + onda * sin(ang * lobulos + v_t * 9.0) + onda * 0.5 * sin(ang * (lobulos + 3.0) - v_t * 13.0)) * (1.0 - erosion);
	if (r > radio) {
		discard;
	}
	float profundidad = 1.0 - r / max(radio, 0.001);
	vec3 col = texture(rampa, vec2(clamp(profundidad * 1.2, 0.0, 0.999), 0.5)).rgb * brillo;
	if (contorno > 0.0 && profundidad < contorno * 0.12) {
		col = color_contorno.rgb;
	}
	ALBEDO = col;
}
