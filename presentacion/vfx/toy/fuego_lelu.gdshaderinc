// FUEGO POR TEXTURAS, ronda 3 de la prueba 3 de VFX (método del tutorial de Le Lu «GODOT - Tutorial Fuego (shader) VFX»). Cuerpo común de las variantes:
// fuego_lelu (cilindros, mezcla), fuego_lelu_add (aditivo), fuego_lelu_atras / fuego_lelu_delante (la esfera de la barrera, dos pasadas).
// Pasos: (1) malla abierta con V = 0 abajo y 1 arriba y U alrededor; (2) la textura de lenguas sube con el tiempo y gira un poco en U; (3) un segundo ruido
// con otra velocidad y escala, sumado; (4) se resta un gradiente vertical que erosiona hacia arriba; (5) ALPHA = smoothstep(umbral, umbral + blandura, f);
// (6) color por una rampa 1D indexada por f; (7) los vértices se desplazan con un ruido que sube, más cuanto más arriba; (8) fundido arriba.
// Texturas: pack gratuito de Le Lu (assets/vfx/lelu_noise/, uso libre sin acreditar según su readme.txt).

group_uniforms mandos;
uniform float altura : hint_range(0.3, 3.0) = 1.0;            // estira la malla hacia arriba
uniform float ancho : hint_range(0.3, 2.0) = 1.0;
uniform float blandura : hint_range(0.05, 1.0) = 0.22;        // anchura del smoothstep del borde (0,22: lenguas con punta, ni duro ni borroso)
uniform float ondulacion : hint_range(0.0, 1.5) = 0.6;        // desplazamiento de vértices y deformación del ruido
uniform float velocidad : hint_range(0.1, 4.0) = 1.0;
uniform float brillo : hint_range(0.3, 3.0) = 1.0;
uniform float tono : hint_range(0.0, 1.0) = 0.0;              // 0 fuego, 1 azul
uniform float transparencia : hint_range(0.2, 1.0) = 0.95;
uniform float chisporroteo : hint_range(0.0, 1.0) = 0.6;      // ruido fino y rápido que rompe las puntas + titileo
group_uniforms;

group_uniforms texturas;
uniform sampler2D lenguas : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D ruido_a : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D ruido_v : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D ruido_fino : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D rampa : source_color, filter_linear, repeat_disable;
uniform sampler2D rampa_azul : source_color, filter_linear, repeat_disable;
group_uniforms;

group_uniforms forma;
uniform vec2 repeticion = vec2(2.0, 1.0);        // veces que se repite la textura de lenguas (alrededor, en altura)
uniform float giro : hint_range(-1.0, 1.0) = 0.04;
uniform vec2 rep_ruido = vec2(3.0, 1.5);
uniform float vel_ruido = 0.55;
uniform float peso_ruido : hint_range(0.0, 1.5) = 0.5;
uniform float pot_grad = 1.3;                    // potencia del gradiente vertical (1 - V)
uniform float fuerza_grad = 1.1;
uniform float desfase = 0.3;                     // se suma a f para que la base no se erosione
uniform float umbral : hint_range(0.0, 1.0) = 0.3;
uniform float escala_rampa = 1.0;
uniform float contraste = 1.1;                   // pow de la rampa: baja el amarillo, sube el salto núcleo-cuerpo
uniform float calor_extra = 0.0;                 // sube la rampa (el cilindro de dentro es más caliente)
uniform float amplitud_vert = 0.16;
uniform float semilla = 0.0;
uniform float v_base : hint_range(0.0, 0.9) = 0.0;   // V a la que empieza el fuego (la esfera de la barrera: donde toca el suelo)
uniform float resplandor_borde : hint_range(0.0, 1.0) = 0.0;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
group_uniforms;

void vertex() {
	vec2 uvn = vec2(UV.x * 3.0 + semilla * 1.7, (1.0 - UV.y) * 1.5 + TIME * velocidad * 0.5);
	float n = textureLod(ruido_v, uvn, 0.0).r;
	float sube = smoothstep(0.0, 0.8, UV.y);
	VERTEX += NORMAL * (n - 0.5) * 2.0 * amplitud_vert * ondulacion * sube;
	VERTEX.y *= altura;
	VERTEX.xz *= ancho;
}

void fragment() {
	float t = TIME * velocidad;
	float vg = clamp((UV.y - v_base) / max(1.0 - v_base, 0.01), 0.0, 1.0);
	float v_inv = 1.0 - vg;
	// (2) lenguas que suben y giran un poco
	vec2 uvt = vec2(UV.x * repeticion.x + giro * t + semilla, v_inv * repeticion.y + t * 0.35);
	float l = texture(lenguas, uvt).r;
	// (3) segundo ruido, otra velocidad y escala
	float r2 = texture(ruido_a, vec2(UV.x * rep_ruido.x - giro * t * 1.7 + 0.37 + semilla * 0.5, v_inv * rep_ruido.y + t * vel_ruido)).r;
	// (4) gradiente vertical que erosiona
	float grad = pow(vg, pot_grad) * fuerza_grad;
	float f = l + (r2 - 0.5) * peso_ruido * (0.5 + ondulacion) - grad + desfase;
	// puntas rotas: ruido fino y rápido solo arriba
	float fino = texture(ruido_fino, vec2(UV.x * 6.0 + semilla * 3.0, v_inv * 3.5 + t * 2.4)).r;
	f -= (fino - 0.4) * 1.1 * chisporroteo * smoothstep(0.3, 0.85, vg);
	// (5) transparencia
	float a = smoothstep(umbral, umbral + blandura, f);
	a *= step(v_base, UV.y) * (1.0 - smoothstep(0.88, 1.0, vg));          // (8) fundido arriba
	// (6) color por rampa
	float idx = clamp((f - umbral) * escala_rampa + calor_extra, 0.0, 1.0);
	idx = pow(idx, contraste);
	vec3 col = mix(texture(rampa, vec2(idx, 0.5)).rgb, texture(rampa_azul, vec2(idx, 0.5)).rgb, tono);
	float titila = 1.0 + 0.14 * chisporroteo * (sin(TIME * 9.3 + semilla * 31.0) * 0.6 + sin(TIME * 14.1 + semilla * 17.0) * 0.4);
	float alfa = a * transparencia;
	if (resplandor_borde > 0.0) {
		float fres = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.4) * resplandor_borde * step(v_base, UV.y);
		col = mix(col, texture(rampa, vec2(0.3, 0.5)).rgb, clamp(fres * 2.0, 0.0, 1.0) * (1.0 - a));
		alfa = max(alfa, fres * 0.35);
	}
	ALBEDO = col * brillo * titila;
	ALPHA = clamp(alfa * vida, 0.0, 1.0);
}
