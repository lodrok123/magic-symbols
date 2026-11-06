shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// CRÁTER DE MAGMA EN EL SUELO (6/11/2026, ImpactoMagmaToy). Un quad tumbado (PlaneMesh) con un disco chamuscado y GRIETAS RADIALES procedurales (brazos quebrados que
// salen del centro, con un anillo) que brillan según `calor` (1 amarillo → 0,5 rojo → 0 gris) y se van con `vida`. No es el decal de profundidad de explosion_suelo.gdshader:
// el cráter es pequeño (≤ 2 m) y basta un plano; en un suelo con desnivel se hundiría.

uniform float calor : hint_range(0.0, 1.0) = 1.0;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float semilla = 0.0;
uniform int brazos = 7;
uniform float brillo : hint_range(0.0, 4.0) = 1.0;

vec3 color_calor(float c) {
	vec3 gris = vec3(0.26, 0.23, 0.24);
	vec3 rojo = vec3(1.0, 0.10, 0.02);
	vec3 naranja = vec3(1.0, 0.42, 0.05);
	vec3 amarillo = vec3(1.0, 0.78, 0.25);
	vec3 a = mix(gris, rojo, smoothstep(0.0, 0.45, c));
	vec3 b = mix(naranja, amarillo, smoothstep(0.78, 1.0, c));
	return mix(a, b, smoothstep(0.45, 0.78, c));
}

float hash1(float n) {
	return fract(sin(n * 127.1 + semilla * 311.7) * 43758.5453);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	if (r > 1.0) {
		discard;
	}
	float ang = atan(q.y, q.x);
	float grieta = 0.0;
	float n = float(brazos);
	for (int i = 0; i < 12; i++) {
		if (i >= brazos) {
			break;
		}
		float fi = float(i);
		float a0 = TAU * fi / n + (hash1(fi) - 0.5) * 0.5;
		float a = a0 + 0.22 * sin(r * 11.0 + hash1(fi + 7.0) * 6.28) * r;      // quebrado: el brazo serpentea más lejos del centro
		float da = abs(mod(ang - a + PI, TAU) - PI);
		float d = da * r;                                                        // distancia (arco) al brazo
		float largo = 0.55 + 0.45 * hash1(fi + 3.0);
		float w = (0.02 + 0.018 * (1.0 - r)) * (1.0 - smoothstep(largo * 0.6, largo, r)) * (0.75 + 0.5 * sin(r * 37.0 + fi));   // grosor irregular: una grieta, no un tentáculo
		grieta = max(grieta, 1.0 - smoothstep(0.0, max(w, 0.001), d));
		// una rama corta a media altura
		float rr = 0.35 + 0.25 * hash1(fi + 11.0);
		float ab = a + (hash1(fi + 5.0) > 0.5 ? 0.9 : -0.9);
		float dab = abs(mod(ang - ab + PI, TAU) - PI) * r;
		float wb = 0.03 * smoothstep(rr - 0.05, rr, r) * (1.0 - smoothstep(rr + 0.15, rr + 0.3, r));
		grieta = max(grieta, 1.0 - smoothstep(0.0, max(wb, 0.001), dab));
	}
	float anillo = 1.0 - smoothstep(0.0, 0.025, abs(r - (0.42 + 0.05 * sin(ang * 5.0 + semilla * 6.28))));
	grieta = max(grieta, anillo * 0.75);
	float centro = exp(-r * r * 9.0);
	float masa = 1.0 - smoothstep(0.7, 1.0, r + 0.06 * sin(ang * 7.0 + semilla * 9.0));
	grieta = clamp(grieta * masa, 0.0, 1.0);
	vec3 col = color_calor(calor) * (0.6 + 0.5 * calor) * brillo;
	vec3 negro = vec3(0.07, 0.05, 0.06);
	float luz = max(grieta, centro * calor);
	ALBEDO = mix(negro, col, luz);
	ALPHA = vida * max(masa * 0.6, luz);
}
