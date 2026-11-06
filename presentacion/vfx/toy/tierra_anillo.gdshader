shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// ANILLO DE TIERRA QUE SE ABRE EN EL SUELO (6/11/2026, ImpactoTierraToy GOLPE; referencia tierra_pack LEEME §2, solo la secuencia). Un quad tumbado (PlaneMesh): un DISCO FACETADO
// (el borde es un polígono irregular de `lados` lados, no un círculo) que crece de 0 a 1 con `apertura`; borde CLARO (pardo claro del polvo), interior OSCURO (tierra húmeda) con
// grietas negras radiales; se va con `vida`. Dos tonos planos, borde duro, sin luz ni emisión.

uniform float apertura : hint_range(0.0, 1.0) = 1.0;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float semilla = 0.0;
uniform int lados = 9;
uniform float ancho_borde : hint_range(0.02, 0.4) = 0.16;
uniform vec3 color_borde : source_color = vec3(0.76, 0.58, 0.40);
uniform vec3 color_interior : source_color = vec3(0.40, 0.27, 0.16);
uniform vec3 color_grieta : source_color = vec3(0.06, 0.04, 0.03);

float hash1(float n) {
	return fract(sin(n * 127.1 + semilla * 311.7) * 43758.5453);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float n = float(lados);
	// radio del polígono en este ángulo: vértices a radios irregulares, interpolados en línea recta (facetas)
	float s = (ang + PI) / TAU * n;
	float i0 = floor(s);
	float f = fract(s);
	float r0 = 0.84 + 0.16 * hash1(i0);
	float r1 = 0.84 + 0.16 * hash1(mod(i0 + 1.0, n));
	float a0 = (i0 / n) * TAU - PI;
	float a1 = ((i0 + 1.0) / n) * TAU - PI;
	vec2 p0 = vec2(cos(a0), sin(a0)) * r0;
	vec2 p1 = vec2(cos(a1), sin(a1)) * r1;
	vec2 pl = mix(p0, p1, f);
	float rpol = length(pl) * apertura;
	if (r > rpol || apertura < 0.01 || vida < 0.02) {
		discard;
	}
	float borde = 1.0 - step(ancho_borde * apertura, rpol - r);
	// grietas radiales negras en el interior
	float g = 0.0;
	for (int k = 0; k < 6; k++) {
		float fk = float(k);
		float ak = TAU * fk / 6.0 + (hash1(fk + 20.0) - 0.5) * 0.6;
		float da = abs(mod(ang - ak + PI, TAU) - PI) * r;
		float w = 0.018 * (1.0 - smoothstep(0.1, 0.7, r / max(apertura, 0.01)));
		g = max(g, 1.0 - step(w, da));
	}
	g *= step(0.08 * apertura, r) * (1.0 - borde);
	vec3 col = mix(color_interior, color_borde, borde);
	col = mix(col, color_grieta, g);
	ALBEDO = col;
	ALPHA = vida;
}
