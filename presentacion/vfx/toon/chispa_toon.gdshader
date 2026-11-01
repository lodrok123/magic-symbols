// CHISPA TOON (1/11, prueba 2, ronda 2). Trazo alargado en vertical (casi todas suben) con la cabeza redonda abajo y la cola fina arriba, de dos tonos según la
// semilla de cada chispa (amarillo y naranja de la rampa del fuego, por 0,86 de brillo). Billboard, sin luz, alfa 0/1. El movimiento a saltos de 1/12 s viene de `fixed_fps`.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

uniform sampler2D rampa : source_color, filter_nearest, repeat_disable;   // la del fuego: así los tonos de las chispas son los mismos de la llama
uniform float brillo : hint_range(0.2, 3.0) = 0.86;
uniform float alargado : hint_range(1.0, 6.0) = 4.0;

varying float v_sem;

void vertex() {
	vec3 centro = MODEL_MATRIX[3].xyz;
	v_sem = fract(sin(dot(centro.xz + vec2(centro.y, 0.0), vec2(12.9898, 78.233))) * 43758.5453);
	float s = (length(MODEL_MATRIX[0].xyz) + length(MODEL_MATRIX[1].xyz)) * 0.5;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float y = 1.0 - UV.y;                              // 0 abajo, 1 arriba
	float x = (UV.x - 0.5) * 2.0;
	float cabeza = y < 0.25 ? sqrt(max(1.0 - pow((0.25 - y) * 4.0, 2.0), 0.0)) : 1.0;
	float ancho = (1.0 - y) * cabeza * 1.1 / alargado;
	if (abs(x) > ancho) {
		discard;
	}
	ALBEDO = texture(rampa, vec2(v_sem < 0.5 ? 0.62 : 0.35, 0.5)).rgb * brillo;   // amarillo o naranja de la rampa
}
