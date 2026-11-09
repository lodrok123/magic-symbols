shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// SALPICADURA DEL HAZ DE FUEGO (9/11/2026, idea «el fuego envuelve lo que golpea»). Lámina pegada a la superficie golpeada (o tumbada en el suelo delante de ella). Con el MISMO lenguaje que el
// chorro (haz_toy.gdshader: textura de lenguas, bordes recortados por umbral, rampa rojo → naranja con el núcleo salmón): llamas que salen del punto de choque, se curvan siguiendo la superficie
// hacia los lados y suben, más altas en el centro y bajas en los extremos (un lamido, no una estrella). Tumbada en el suelo (`suelo` = 1) es una mancha de llamas irregular sin rayos simétricos.
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
uniform float umbral = 0.24;
uniform float blandura = 0.42;
uniform float tope_calor : hint_range(0.3, 1.0) = 0.62;
uniform float nucleo_claro : hint_range(0.0, 1.0) = 0.6;
uniform vec3 color_claro : source_color = vec3(1.0, 0.62, 0.38);
uniform float transparencia : hint_range(0.2, 1.0) = 1.0;
uniform float suelo : hint_range(0.0, 1.0) = 0.0;                  // 1 = tumbada en el suelo

void fragment() {
	vec2 q = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);            // x a lo ancho de la superficie, y hacia arriba
	float entra = smoothstep(0.78, 1.0, crece);
	float sale = 1.0 - smoothstep(0.1, 0.8, corte);
	float t = TIME * velocidad;
	float esc = 1.0 / max(0.25 + 0.75 * entra, 0.01);
	float dx;
	float dy;
	vec2 uv;
	if (suelo > 0.5) {
		// mancha en el suelo: ruido cartesiano que sube lento, máscara redonda irregular (sin ángulo: no hay rayos)
		vec2 p = q * esc;
		dx = length(p) * 0.95;
		dy = dx;
		uv = vec2(p.x * 1.3 + semilla, -p.y * 0.8 + t * 0.9);
	} else {
		// lamido: las llamas suben desde la base (y ≈ -0,15), más altas en el centro y bajas en los extremos, y se curvan hacia los lados al subir
		vec2 p = vec2(q.x, q.y + 0.15) * esc;
		float alto = 0.95 * (1.0 - pow(min(abs(p.x), 1.0), 1.7));
		dx = abs(p.x);
		dy = max(p.y, 0.0) / max(alto, 0.08);
		uv = vec2(p.x * 1.5 + semilla + sign(p.x) * max(p.y, 0.0) * 0.35, -p.y * 0.6 + t * 1.3);
	}
	float l = texture(lenguas, uv).r;
	float r2 = texture(ruido_a, vec2(uv.x * 0.7 + 0.37, uv.y * 0.55 + semilla * 0.5)).r;
	float cuerpo = max(dx, dy);
	float f = l * 0.9 + (r2 - 0.5) * 0.9 + 1.05 - pow(cuerpo, 2.2) * 1.25;
	float a = smoothstep(umbral, umbral + blandura, f);
	a *= (1.0 - smoothstep(0.9, 1.05, cuerpo)) * entra * sale;
	float idx = clamp((f - umbral) * 0.9 + 0.25 * (1.0 - cuerpo), 0.0, 1.0);
	vec3 col = texture(rampa, vec2(idx * tope_calor, 0.5)).rgb;
	col = mix(col, color_claro, nucleo_claro * smoothstep(0.6, 1.0, idx));
	ALBEDO = col * brillo;
	ALPHA = clamp(a * transparencia, 0.0, 1.0);
}
