shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// SALPICADURA DEL HAZ DE AGUA (9/11/2026, idea «lo que golpea envuelve el chorro» de la demo de gas de three.js). Lámina pegada a la superficie golpeada (o tumbada en el suelo delante de ella)
// donde el chorro se abre en abanico: agua translúcida con tres tonos de la paleta del agua (HONDO → SOMERO → ESPUMA en el borde, nunca un brillo: el agua no emite). Mismo patrón que
// salpicadura_haz.gdshader (lo mismo en polar), pero con el ruido de agua: lengüetas finas que salen del punto de choque y un borde de espuma. `crece` / `corte` como el haz.

group_uniforms mandos;
uniform float velocidad : hint_range(0.1, 4.0) = 1.0;
group_uniforms;

uniform sampler2D ruido_a : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D ruido_fino : hint_default_white, filter_linear, repeat_enable;
uniform vec3 tono_a : source_color = vec3(0.12, 0.46, 0.50);       // AguaPaleta.HONDO
uniform vec3 tono_b : source_color = vec3(0.34, 0.74, 0.72);       // AguaPaleta.SOMERO
uniform vec3 tono_c : source_color = vec3(0.96, 0.99, 1.0);        // AguaPaleta.ESPUMA
uniform float crece : hint_range(0.0, 1.0) = 1.0;
uniform float corte : hint_range(0.0, 1.0) = 0.0;
uniform float semilla = 0.0;
uniform float opacidad : hint_range(0.0, 1.0) = 0.62;
uniform float suelo : hint_range(0.0, 1.0) = 0.0;                  // 1 = tumbada en el suelo (abanico redondo)

void fragment() {
	vec2 q = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float entra = smoothstep(0.78, 1.0, crece);
	float sale = 1.0 - smoothstep(0.05, 0.7, corte);
	float rx = mix(length(vec2(q.x * 0.82, q.y * 1.3)), length(q) * 0.95, suelo);
	float rr = rx / max(0.2 + 0.8 * entra, 0.01);
	float ang = atan(q.y, q.x);
	float t = TIME * velocidad;
	float l = texture(ruido_a, vec2(ang * 0.4775 + semilla, -rr * 0.9 + t * 1.1)).r;         // 3 repeticiones: la costura de atan cierra
	float fino = texture(ruido_fino, vec2(ang * 0.9549 + semilla * 0.5, -rr * 1.6 + t * 1.7)).r;
	float f = l * 0.9 + (fino - 0.5) * 0.5 + 0.95 - rr * 1.5;
	float a = smoothstep(0.28, 0.5, f);
	a *= (1.0 - smoothstep(0.8, 1.0, rr)) * entra * sale;
	// del centro (hondo) al borde (espuma): bandas suaves como el agua del mundo
	float k = clamp(rr * 1.1 + (fino - 0.5) * 0.3, 0.0, 1.0);
	vec3 col = mix(tono_a, tono_b, smoothstep(0.1, 0.55, k));
	col = mix(col, tono_c, smoothstep(0.62, 0.9, k));
	ALBEDO = col;
	ALPHA = clamp(a * opacidad, 0.0, 1.0);
}
