shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

// ESFERA «toy» de naturaleza (5/11/2026): el núcleo de la bola de veneno (opaca, en bandas: centro casi blanco verdoso, cuerpo verde, canto verde hondo) y la cúpula tenue del escudo
// (casi transparente en el centro, más visible en el canto, para leer que cubre por todos lados sin tapar al goblin). Sin luz, sin emisión.
uniform vec3 color_centro : source_color = vec3(0.86, 1.0, 0.68);
uniform vec3 color_medio : source_color = vec3(0.55, 0.92, 0.3);
uniform vec3 color_borde : source_color = vec3(0.16, 0.52, 0.2);
uniform float alfa_centro : hint_range(0.0, 1.0) = 1.0;
uniform float alfa_borde : hint_range(0.0, 1.0) = 1.0;
uniform float bandas : hint_range(0.0, 1.0) = 1.0;   // 1 = dos cortes duros (toon), 0 = degradado
uniform float brillo : hint_range(0.0, 3.0) = 1.0;
uniform float destello : hint_range(0.0, 1.0) = 0.0; // 1 = todo hacia el color del centro (golpe, impacto)
uniform float tiempo = 0.0;                          // para el pulso de la cúpula

void fragment() {
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float k = ndv;
	float c_medio = mix(smoothstep(0.30, 0.62, k), step(0.45, k), bandas);
	float c_centro = mix(smoothstep(0.62, 0.92, k), step(0.78, k), bandas);
	vec3 col = mix(color_borde, color_medio, c_medio);
	col = mix(col, color_centro, c_centro);
	col = mix(col, color_centro, destello);
	ALBEDO = col * brillo;
	float pulso = 1.0 + 0.12 * sin(tiempo * 2.6);
	ALPHA = clamp(mix(alfa_borde, alfa_centro, smoothstep(0.1, 0.9, k)) * pulso + destello * 0.25, 0.0, 1.0);
}
