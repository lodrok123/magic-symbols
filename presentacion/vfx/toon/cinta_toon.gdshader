// CINTA TOON (1/11, prueba 2, ronda 3). El cuerpo del muro como una CINTA continua: varios planos largos solapados a distintas profundidades. No hay ninguna forma
// fija: las lenguas salen del ruido. Ruido celular (Voronoi) 2D estirado en vertical y desplazado hacia arriba con el tiempo cuantizado a `fps`; la máscara es
// (gradiente vertical con envolvente irregular) × (ruido elevado a una potencia) + una franja brillante continua en la base; un umbral DURO recorta las puntas
// (alfa 0/1 por descarte, sin mezcla). El color depende del valor de la máscara (≈ altura sobre el suelo + ruido): crema abajo en franja continua, amarillo, naranja
// el cuerpo y rojo solo en la punta erosionada (banda fina); opcional un contorno oscuro. Sin luz. Cada plano lleva su `semilla` (offset de UV distinto).
// Los diez mandos (mismo nombre que en los otros shaders toon, para el panel del lab): fps, umbral, altura_llama, desplazamiento (deformación del ruido),
// contorno, rampa, velocidad (subida del ruido), escala_ruido (celdas en 6,9 m), brillo, erosion.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

uniform float fps : hint_range(2.0, 60.0) = 12.0;
uniform float umbral : hint_range(0.0, 0.7) = 0.3;                 // corte duro de la máscara: más alto = lenguas más finas y bajas
uniform float altura_llama : hint_range(0.2, 1.5) = 1.0;           // multiplicador de la altura del plano
uniform float desplazamiento : hint_range(0.0, 1.0) = 0.5;         // cuánto se deforma el ruido (ondulación lateral)
uniform float contorno : hint_range(0.0, 1.0) = 0.0;               // grosor del borde oscuro (0 = sin contorno)
uniform sampler2D rampa : source_color, filter_nearest, repeat_disable;
uniform float velocidad : hint_range(0.1, 6.0) = 1.4;              // metros por segundo a los que sube el ruido
uniform float escala_ruido : hint_range(2.0, 24.0) = 9.0;          // celdas del ruido en 6,9 m de largo
uniform float brillo : hint_range(0.2, 3.0) = 0.86;
uniform float erosion : hint_range(0.0, 1.0) = 0.0;

uniform float suavidad : hint_range(0.001, 0.03) = 0.01;          // borde duro
uniform float estirado : hint_range(0.15, 1.0) = 0.25;              // 1 celdas redondas; menos = más estiradas en vertical
uniform float contraste : hint_range(0.5, 4.0) = 3.2;              // potencia aplicada al ruido
uniform float base_altura : hint_range(0.0, 0.4) = 0.12;           // m de la franja brillante continua de la base
uniform vec2 tam_malla = vec2(6.9, 1.3);
uniform float semilla : hint_range(0.0, 50.0) = 0.0;

varying vec2 v_m;
varying vec2 v_tam;
varying float v_t;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vn(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), f);
}

// Distancia al punto de rasgo más cercano; los puntos se mueven con el tiempo cuantizado.
float voronoi(vec2 p, float tq) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash22(i + g);
			o = 0.5 + 0.5 * sin(tq + 6.2831 * o);
			vec2 r = g + o - f;
			d = min(d, dot(r, r));
		}
	}
	return sqrt(d);
}

void vertex() {
	v_t = floor(TIME * fps) / fps;
	vec2 esc = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	v_tam = tam_malla * esc;
	v_m = vec2(VERTEX.x + tam_malla.x * 0.5, VERTEX.y + tam_malla.y * 0.5) * esc;
}

void fragment() {
	vec2 m = v_m;
	float t = v_t;
	float alto = v_tam.y * altura_llama * (1.0 - erosion);
	// Envolvente irregular de la línea de fuego: no es recta, sube y baja a lo largo del muro.
	float env = mix(0.55, 1.0, vn(m.x * 0.8 + semilla * 3.1 + t * 0.3)) * alto;
	float ux = m.x / v_tam.x;
	env *= mix(0.3, 1.0, smoothstep(0.0, 0.06, min(ux, 1.0 - ux)));   // los extremos del muro bajan
	float y01 = m.y / max(env, 0.001);
	if (y01 > 1.0) {
		discard;
	}
	float dens = escala_ruido / 6.9;
	float xw = m.x + desplazamiento * 0.3 * sin(m.y * 3.1 + t * velocidad * 2.0 + m.x * 1.7 + semilla) + desplazamiento * 0.07 * sin(m.y * 13.0 - t * velocidad * 5.0 + m.x * 6.0 + semilla * 2.0);   // la segunda onda deshilacha el borde
	vec2 q = vec2(xw * dens, (m.y - t * velocidad) * dens * estirado) + vec2(semilla * 7.3, semilla * 3.7);
	float n = 1.0 - clamp(voronoi(q, t * velocidad * 1.5 + semilla), 0.0, 1.0);
	float g = 1.0 - y01;
	float base = clamp(1.0 - m.y / max(base_altura, 0.001), 0.0, 1.0);
	float mk = g * (0.2 + 0.9 * pow(n, contraste)) + 0.45 * base;
	float a = smoothstep(umbral, umbral + suavidad, mk);
	if (a < 0.5) {
		discard;
	}
	// Color por el valor de la máscara (altura + ruido): crema, amarillo, naranja y rojo fino solo en la punta.
	float x = 0.12;                                   // rojo (punta)
	if (mk > umbral + 0.05) {
		x = 0.35;                                      // naranja
	}
	if (mk > umbral + 0.42) {
		x = 0.62;                                      // amarillo
	}
	if (mk > umbral + 0.85) {
		x = 0.92;                                      // crema, solo la base
	}
	vec3 col = texture(rampa, vec2(x, 0.5)).rgb;
	if (contorno > 0.0 && mk < umbral + contorno * 0.12) {
		col = texture(rampa, vec2(0.02, 0.5)).rgb;
	}
	ALBEDO = col * brillo;
}
