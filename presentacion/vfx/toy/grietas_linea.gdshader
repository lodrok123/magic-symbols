shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// GRIETAS A LO LARGO DE UN MURO (17/11/2026, Pablo: «mete esas líneas del suelo en el muro también, no exactamente igual sino solo las líneas alrededor del muro»).
// Hermano de grietas_magma.gdshader (el radial del pilar y del cráter): un quad tumbado (PlaneMesh de `largo_m` × `ancho_m`) con DOS grietas quebradas que corren a lo largo del muro,
// una a cada lado, a `lado_m` del eje, y ramas cortas hacia fuera. Mismo `calor` (1 amarillo → 0,5 rojo → 0 gris), `vida` y `alcance` (aquí: hasta dónde han llegado desde el centro
// hacia los dos extremos, 0-1; ≥ 1,2 = enteras). Es un plano, no un decal: en un suelo con desnivel se hunde o flota.

uniform float calor : hint_range(0.0, 1.0) = 1.0;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float semilla = 0.0;
uniform float brillo : hint_range(0.0, 4.0) = 1.0;
uniform float alcance = 2.0;
uniform float largo_m = 7.0;
uniform float ancho_m = 2.0;
uniform float lado_m = 0.5;
uniform float grosor_m = 0.04;
uniform float chamusco : hint_range(0.0, 1.0) = 0.3;      // sombra oscura bajo el muro, entre las dos grietas

vec3 color_calor(float c) {
	vec3 gris = vec3(0.26, 0.23, 0.24);
	vec3 rojo = vec3(1.0, 0.10, 0.02);
	vec3 naranja = vec3(1.0, 0.42, 0.05);
	vec3 amarillo = vec3(1.0, 0.78, 0.25);
	vec3 a = mix(gris, rojo, smoothstep(0.0, 0.45, c));
	vec3 b = mix(naranja, amarillo, smoothstep(0.78, 1.0, c));
	return mix(a, b, smoothstep(0.45, 0.78, c));
}

float azar(float n, float s) {
	return fract(sin(n * 127.1 + s * 311.7) * 43758.5453);
}

// desplazamiento lateral (m) de la grieta en x (m): ondas de varios tamaños y un escalón, para que quiebre
float quebrada(float x, float s) {
	return 0.15 * sin(x * 2.3 + s * 6.0) + 0.08 * sin(x * 5.7 + s * 11.0) + 0.04 * sin(x * 13.0 + s * 3.0) + 0.05 * sign(sin(x * 3.9 + s * 7.0));
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(largo_m, ancho_m);
	float ax = abs(p.x) / (largo_m * 0.5);
	float g = 0.0;
	for (int i = 0; i < 2; i++) {
		float lado = i == 0 ? -1.0 : 1.0;
		float s = semilla + float(i) * 1.7;
		float yc = lado * lado_m + quebrada(p.x, s);
		float w = grosor_m * (0.7 + 0.5 * sin(p.x * 4.1 + s * 9.0));
		g = max(g, 1.0 - smoothstep(0.0, max(w, 0.004), abs(p.y - yc)));
		// ramas: una cada ~0,9 m (no todas), oblicua y hacia fuera
		float celda = floor(p.x / 0.9 + s);
		float fx = (fract(p.x / 0.9 + s) - 0.5) * 0.9;
		float h = azar(celda, s);
		float fuera = (p.y - yc) * lado;
		float largo_r = 0.18 + 0.35 * h;
		float d = abs(fx - fuera * (h > 0.5 ? 0.7 : -0.7));
		float rama = (1.0 - smoothstep(0.0, grosor_m * 0.8, d)) * step(0.0, fuera) * (1.0 - smoothstep(largo_r * 0.6, largo_r, fuera));
		g = max(g, rama * step(0.3, azar(celda + 5.0, s)));
	}
	float extremos = 1.0 - smoothstep(0.86, 1.0, ax);
	float lados = 1.0 - smoothstep(0.75, 1.0, abs(p.y) / (ancho_m * 0.5));
	float llega = 1.0 - smoothstep(alcance - 0.15, alcance, ax);
	g *= extremos * lados * llega;
	float sombra = chamusco * (1.0 - smoothstep(lado_m * 0.6, lado_m * 1.5, abs(p.y))) * extremos * llega;
	vec3 col = color_calor(calor) * (0.6 + 0.5 * calor) * brillo;
	ALBEDO = mix(vec3(0.07, 0.05, 0.06), col, g);
	ALPHA = vida * max(sombra, g);
}
