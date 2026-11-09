shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// SALPICADURA DEL HAZ DE FUEGO (9/11/2026, idea «el fuego envuelve lo que golpea» de la demo de gas de three.js). Una lámina (QuadMesh) pegada a la superficie que el haz golpea
// (su normal es la de la superficie): las llamas salen del punto de choque y se ABREN EN ABANICO por los lados, lamiendo el obstáculo (más ancho que alto), con las lenguas corriendo hacia fuera.
// La lámina corta contra el suelo por profundidad (no hay que hacer nada). Mismos nombres de mandos que haz_toy.gdshader para que `FuegoToy` los mueva igual.
//   crece 0 → 1   el chorro llega: la salpicadura se abre cuando ya ha llegado (smoothstep 0,78 → 1)
//   corte 0 → 1   el chorro se suelta: la salpicadura se apaga

group_uniforms mandos;
uniform float velocidad : hint_range(0.1, 4.0) = 1.0;
uniform float brillo : hint_range(0.3, 3.0) = 1.0;
group_uniforms;

uniform sampler2D lenguas : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D ruido_a : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D rampa : source_color, filter_linear, repeat_disable;
uniform float crece : hint_range(0.0, 1.0) = 1.0;
uniform float corte : hint_range(0.0, 1.0) = 0.0;
uniform float semilla = 0.0;
uniform float umbral = 0.25;
uniform float blandura = 0.4;
uniform float tope_calor : hint_range(0.3, 1.0) = 0.7;
uniform float transparencia : hint_range(0.2, 1.0) = 0.95;
uniform float suelo : hint_range(0.0, 1.0) = 0.0;       // 1 = la lámina está tumbada en el suelo (abanico redondo, sin sesgo a lo ancho)
uniform float apertura = 1.0;                // × cuánto se abre hacia los lados (1 = lámina entera)

void fragment() {
	vec2 q = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);      // x a lo ancho de la superficie, y hacia arriba
	float entra = smoothstep(0.78, 1.0, crece);
	float sale = 1.0 - smoothstep(0.1, 0.8, corte);
	// el abanico es más ancho que alto: las llamas corren por la superficie
	float rx = mix(length(vec2(q.x * 0.82, q.y * 1.3)), length(q) * 0.95, suelo);
	float rr = rx / max(0.2 + 0.8 * entra, 0.01) / max(apertura, 0.2);
	float ang = atan(q.y, q.x);
	float t = TIME * velocidad;
	float l = texture(lenguas, vec2(ang * 0.4775 + semilla, -rr * 0.7 + t * 1.25)).r;       // 0,4775 = 3 / 2π: tres repeticiones, la costura de atan cierra
	float r2 = texture(ruido_a, vec2(ang * 0.3183 + semilla * 0.5, -rr * 0.5 + t * 0.9)).r;  // 0,3183 = 2 / 2π
	float f = l * 0.85 + (r2 - 0.5) * 0.75 + 1.0 - rr * 1.45;
	f += 0.35 * (1.0 - smoothstep(0.0, 0.45, rr));                                       // el centro, el punto de choque, más lleno
	float a = smoothstep(umbral, umbral + blandura, f);
	a *= (1.0 - smoothstep(0.82, 1.0, rr)) * entra * sale;
	float idx = clamp((f - umbral) * 0.9 + 0.12 - 0.22 * smoothstep(0.35, 1.0, rr), 0.0, 1.0) * tope_calor;
	ALBEDO = texture(rampa, vec2(idx, 0.5)).rgb * brillo;
	ALPHA = clamp(a * transparencia, 0.0, 1.0);
}
