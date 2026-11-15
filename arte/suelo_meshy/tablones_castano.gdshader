shader_type spatial;

varying vec3 posicion_mundo;

void vertex() {
	posicion_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 celda = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(
		mix(azar(celda), azar(celda + vec2(1.0, 0.0)), f.x),
		mix(azar(celda + vec2(0.0, 1.0)), azar(celda + vec2(1.0)), f.x),
		f.y
	);
}

void fragment() {
	vec2 p = posicion_mundo.xz;
	float hilera = floor(p.y / 0.32);
	vec2 tabla = vec2((p.x + mod(hilera, 3.0) * 0.82) / 2.45, p.y / 0.32);
	vec2 local = fract(tabla);
	vec2 borde = min(local, 1.0 - local) * vec2(2.45, 0.32);
	float distancia = min(borde.x, borde.y);
	float interior = smoothstep(0.004, 0.022, distancia);
	float veta = ruido(vec2(p.x * 1.9, p.y * 54.0 + ruido(p * vec2(1.0, 8.0)) * 1.4));
	float tono = 0.6 * azar(floor(tabla)) + 0.4 * veta;
	vec3 madera = mix(vec3(0.17, 0.082, 0.035), vec3(0.34, 0.195, 0.099), tono);
	ALBEDO = mix(vec3(0.052, 0.024, 0.011), madera, interior);
	ROUGHNESS = 0.91;
}
