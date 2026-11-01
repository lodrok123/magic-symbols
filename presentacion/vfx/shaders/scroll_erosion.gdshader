// SCROLL CON EROSIÓN (1/11, comparativa de VFX §1.2). Para MALLAS: el plano del muro y el cilindro de la columna.
// Dos capas de ruido que suben (TIME × velocidad) se multiplican por un gradiente vertical (más llama abajo, más nada arriba);
// de ahí sale un «valor» que la rampa colorea y un umbral recorta. `erosion` (0 → 1) lo mueve el AnimationPlayer al morir.
// La altura se lee de UV.y dentro de `uv_rango` (QuadMesh: 0 arriba, 1 abajo; CylinderMesh sin tapas: 0 arriba, 1 abajo).
// Aditivo o mezcla normal con el mismo truco premultiplicado que flipbook_erosion.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D ruido_a : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D ruido_b : hint_default_white, filter_linear, repeat_enable;
uniform vec2 escala_a = vec2(1.0, 0.5);
uniform vec2 escala_b = vec2(2.3, 1.1);
uniform float velocidad_a = 0.55;      // UV/s hacia arriba
uniform float velocidad_b = 0.9;
uniform sampler2D rampa : source_color, filter_linear, repeat_disable;
uniform vec2 uv_rango = vec2(0.0, 1.0);
uniform float altura_llama : hint_range(0.2, 6.0) = 1.6;   // exponente del gradiente: más alto = llama más baja
uniform float umbral : hint_range(0.0, 1.0) = 0.28;
uniform float suavidad : hint_range(0.001, 0.5) = 0.18;
uniform float erosion : hint_range(0.0, 1.0) = 0.0;       // 0 vivo, 1 muerto (lo anima la escena)
uniform float bordes_x : hint_range(0.0, 0.5) = 0.08;     // desvanecido en los extremos horizontales (0 = sin él)
uniform float brillo : hint_range(0.0, 8.0) = 0.8;
uniform float rampa_tope : hint_range(0.0, 1.0) = 0.7;   // hasta dónde se lee la rampa: por debajo de 1 el blanco solo sale al sumarse capas
uniform float aditivo : hint_range(0.0, 1.0) = 1.0;
uniform float repeticion_x = 1.0;                          // cuántas veces se repite el ruido a lo largo (muros largos)
uniform float silueta : hint_range(0.0, 4.0) = 0.0;       // cilindros: se apaga hacia el contorno (0 = plano, no se aplica)
uniform float base : hint_range(0.0, 0.5) = 0.0;          // desvanecido en la base (h < base), para que no se vea el aro o la línea de abajo
uniform float ruido_base : hint_range(0.0, 1.0) = 0.35;   // valor mínimo abajo sin contar el ruido (más alto = base más llena y sólida)

void fragment() {
	float h = 1.0 - clamp((UV.y - uv_rango.x) / max(uv_rango.y - uv_rango.x, 0.001), 0.0, 1.0);   // 0 abajo, 1 arriba
	vec2 u = vec2(UV.x * repeticion_x, UV.y);
	float na = texture(ruido_a, u * escala_a + vec2(0.0, TIME * velocidad_a)).r;
	float nb = texture(ruido_b, u * escala_b + vec2(0.13, TIME * velocidad_b)).r;
	float n = na * 0.6 + nb * 0.4;
	float g = pow(1.0 - h, altura_llama);
	float valor = g * (ruido_base + n * 0.9) - erosion;
	float lado = bordes_x > 0.0 ? smoothstep(0.0, bordes_x, UV.x) * smoothstep(0.0, bordes_x, 1.0 - UV.x) : 1.0;
	float a = smoothstep(umbral, umbral + suavidad, valor) * lado;
	if (silueta > 0.0) {
		a *= pow(abs(dot(normalize(NORMAL), normalize(VIEW))), silueta);
	}
	if (base > 0.0) {
		a *= smoothstep(0.0, base, h);
	}
	vec3 col = texture(rampa, vec2(clamp(valor * 1.4, 0.0, rampa_tope), 0.5)).rgb * brillo;
	ALBEDO = col * a;
	ALPHA = a * (1.0 - aditivo);
}
