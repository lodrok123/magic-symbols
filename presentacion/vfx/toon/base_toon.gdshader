// BASE TOON (1/11, prueba 2, ronda 2): la franja baja del muro, continua y la parte MÁS brillante: dos escalones (amarillo claro abajo, naranja arriba) y un borde
// rojo fino, con el borde superior ondulado (ruido de valor por tramos de 25 cm, a saltos de 1/fps). Plano vertical; ancho en metros por la escala del nodo.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

uniform sampler2D rampa : source_color, filter_nearest, repeat_disable;
uniform float fps : hint_range(2.0, 60.0) = 12.0;
uniform float altura : hint_range(0.05, 0.4) = 0.16;              // m de la base brillante (media)
uniform float ondulacion : hint_range(0.0, 1.0) = 0.7;
uniform float brillo : hint_range(0.2, 3.0) = 0.86;
uniform float erosion : hint_range(0.0, 1.0) = 0.0;
uniform vec2 tam_malla = vec2(6.9, 0.3);

varying vec2 v_m;
varying float v_t;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	v_t = floor(TIME * fps) / fps;
	vec2 esc = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	v_m = vec2(VERTEX.x + tam_malla.x * 0.5, VERTEX.y + tam_malla.y * 0.5) * esc;
}

void fragment() {
	float f = v_m.x / 0.25;
	float i = floor(f);
	float u = smoothstep(0.0, 1.0, fract(f));
	float it = floor(v_t * 6.0);
	float n = mix(hash21(vec2(i, it)), hash21(vec2(i + 1.0, it)), u);
	float tope = altura * (1.0 - ondulacion * 0.5 + ondulacion * n) * (1.0 - erosion);
	if (v_m.y > tope) {
		discard;
	}
	float r = v_m.y / max(tope, 0.001);
	float x = 0.62;                               // amarillo
	if (r > 0.45) {
		x = 0.34;                                  // naranja
	}
	if (r > 0.88) {
		x = 0.12;                                  // rojo fino
	}
	if (r < 0.12) {
		x = 0.9;                                   // crema, solo el borde del suelo
	}
	ALBEDO = texture(rampa, vec2(x, 0.5)).rgb * brillo;
}
