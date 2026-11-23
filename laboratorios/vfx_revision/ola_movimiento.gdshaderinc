// Movimiento compartido por la cortina, el cuerpo y la espuma del laboratorio.
uniform float tiempo_ola = 0.0;
uniform float alcance_colapso = 4.6;

// p = (profundidad, altura). La base se queda; el labio adelanta y cae primero.
// Compartido con las láminas de espuma para que no se queden sobre el muro inicial.
vec2 ola_colapso(vec2 p, float H, float zc, float s, float co) {
	float yn = clamp(p.y / max(H, 0.02), 0.0, 1.0);
	float frente = smoothstep(0.38, 0.78, s);
	float vuelca = smoothstep(0.0, 0.48, co);
	float arrastra = smoothstep(0.23, 0.88, co);
	float vuelo = vuelca * (1.15 * pow(yn, 1.8) + 0.75 * frente * sqrt(yn));
	float viaje = min(H, max(alcance_colapso - 1.1, 0.2) / 2.0);
	float z = zc + (p.x - zc) * (1.0 - 0.65 * arrastra)
		- viaje * (vuelo + 0.75 * arrastra * (0.3 + 0.7 * yn));
	// El labio cae antes que la espalda. No se comprime toda la ola como un bloque.
	float cae = smoothstep(0.16, 0.68, co + 0.09 * frente);
	float y = p.y * (1.0 - cae * cae) * (1.0 - 0.8 * arrastra);
	y = max(0.0, y - H * 0.08 * frente * sin(vuelca * 3.14159265));
	return vec2(z, y);
}

float ola_subida(float x, float ancho, float crecimiento) {
	float retraso = 0.25 * abs(x) / max(ancho, 0.05);
	float local = clamp((crecimiento - retraso) / (1.0 - retraso), 0.0, 1.0);
	// Primero reúne una lámina baja; después levanta la cresta y se asienta.
	float levanta = smoothstep(0.16, 1.0, local);
	return 0.045 * smoothstep(0.0, 0.16, local) + 0.955 * levanta
		+ 0.08 * sin(3.14159265 * smoothstep(0.48, 1.0, local));
}

float ola_pulso(float x, float t) {
	return 0.10 * sin(x * 1.8 - t * 3.6) + 0.045 * sin(x * 3.7 + t * 5.1);
}

float ola_desplazamiento(float x, float t, float co) {
	return (0.15 * sin(x * 1.8 - t * 3.6) + 0.05 * sin(x * 3.7 + t * 5.1))
		* (1.0 - smoothstep(0.0, 0.5, co));
}
