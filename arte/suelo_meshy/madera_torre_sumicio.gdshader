shader_type spatial;

instance uniform bool tablones = true;

varying vec3 punto_mundo;
varying vec3 normal_mundo;

void vertex() {
	punto_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

float azar(vec2 celda) {
	return fract(sin(dot(celda, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 celda = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(
		mix(azar(celda), azar(celda + vec2(1.0, 0.0)), f.x),
		mix(azar(celda + vec2(0.0, 1.0)), azar(celda + vec2(1.0)), f.x), f.y);
}

vec3 madera(vec2 p) {
	const vec2 tam_tabla = vec2(1.95, 0.34);
	float hilera = floor(p.y / tam_tabla.y);
	vec2 tabla = (p + vec2(mod(hilera, 3.0) * 0.65, 0.0)) / tam_tabla;
	vec2 dentro = fract(tabla);
	vec2 borde = min(dentro, 1.0 - dentro) * tam_tabla;
	float distancia = min(borde.x, borde.y);
	float ondulacion = ruido(p * vec2(2.0, 6.0));
	float veta = ruido(vec2(p.x * 1.8, p.y * 55.0 + ondulacion * 1.35));
	float tono = 0.48 * veta + 0.22 * ondulacion + 0.30 * (tablones ? azar(floor(tabla)) : 0.55);
	vec3 fibra = mix(vec3(0.36, 0.191, 0.080), vec3(0.626, 0.387, 0.210), tono);
	float junta = tablones ? smoothstep(0.002, 0.015, distancia) : 1.0;
	return mix(fibra * 0.59, fibra, junta);
}

void fragment() {
	vec3 pesos = pow(abs(normalize(normal_mundo)), vec3(6.0));
	pesos /= pesos.x + pesos.y + pesos.z;
	ALBEDO = madera(punto_mundo.zy) * pesos.x
		+ madera(punto_mundo.xz) * pesos.y
		+ madera(punto_mundo.xy) * pesos.z;
	ROUGHNESS = 0.88;
}
