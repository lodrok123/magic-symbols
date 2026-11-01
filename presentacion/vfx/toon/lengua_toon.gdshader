// LENGUA TOON (1/11, prueba 2, ronda 2). Cada partícula (GPUParticles3D con QuadMesh, `fixed_fps` 12 sin interpolar) es UNA lengua de fuego: un quad que gira
// hacia la cámara sin tumbarse (billboard bloqueado en Y), con su forma, ladeo y altura propios (semilla = posición de nacimiento) y su vida: nace abajo, crece,
// se estrecha y se apaga de golpe cuando muere la partícula. Muchas lenguas de tamaños distintos y desordenadas en X y Z rompen el «plano»: el solapamiento
// lo resuelve el buffer de profundidad (alfa 0/1 por descarte, sin mezcla ni orden).
// Color por la altura dentro de la lengua (como en Breath of the Wild): crema solo en el corazón de la base, amarillo en la mitad inferior, naranja el cuerpo,
// rojo el borde fino de arriba y de los lados. Rampa de 5 escalones (`rampa`). Sin luz. Tiempo cuantizado a `fps`.
// Los diez mandos, con el mismo nombre que en fuego_toon.gdshader (para el panel del lab): fps, umbral, altura_llama, desplazamiento, contorno, rampa,
// velocidad (ritmo del ondular), escala_ruido (frecuencia del ondular), brillo, erosion.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

uniform float fps : hint_range(2.0, 60.0) = 12.0;
uniform float umbral : hint_range(0.0, 0.5) = 0.02;                // por debajo de este valor no se pinta (encoge la silueta)
uniform float altura_llama : hint_range(0.3, 1.0) = 1.0;           // fracción del quad que alcanza la lengua en su punto más alto
uniform float desplazamiento : hint_range(0.0, 1.0) = 0.5;         // ladeo y ondulación lateral
uniform float contorno : hint_range(0.0, 1.0) = 0.35;              // grosor del borde rojo oscuro (0 = solo el escalón de la rampa)
uniform sampler2D rampa : source_color, filter_nearest, repeat_disable;
uniform float velocidad : hint_range(0.1, 6.0) = 1.6;
uniform float escala_ruido : hint_range(2.0, 24.0) = 9.0;
uniform float brillo : hint_range(0.2, 3.0) = 0.86;
uniform float erosion : hint_range(0.0, 1.0) = 0.0;                // 0 viva, 1 apagada (nacer / morir)

uniform float suavidad : hint_range(0.001, 0.03) = 0.01;           // borde duro
uniform float pico_ancho : hint_range(0.1, 0.6) = 0.3;             // altura relativa donde la lengua es más ancha (30 %)
uniform float ancho_max : hint_range(0.4, 1.0) = 0.95;
uniform float cuerpo_amarillo : hint_range(0.0, 1.0) = 0.3;        // 0 todo naranja, 1 la mitad inferior amarilla

varying float v_fase;
varying float v_sem;
varying float v_t;

void vertex() {
	v_t = floor(TIME * fps) / fps;
	v_fase = INSTANCE_CUSTOM.y;
	vec3 centro = MODEL_MATRIX[3].xyz;
	v_sem = fract(sin(dot(centro.xz + vec2(centro.y, 0.0), vec2(12.9898, 78.233))) * 43758.5453);
	float s = length(MODEL_MATRIX[1].xyz);
	vec3 a = INV_VIEW_MATRIX[3].xyz - centro;
	a.y = 0.0;
	a = normalize(a + vec3(0.0001, 0.0, 0.0001));
	vec3 der = normalize(cross(vec3(0.0, 1.0, 0.0), a));
	VERTEX.y += 0.5;           // el origen del quad es la base de la lengua
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(der * s, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(a, 0.0), vec4(centro, 1.0));
}

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * 2.0, 1.0 - UV.y);          // x de −1 a 1, p.y de 0 (base) a 1
	float ph = clamp(v_fase, 0.0, 1.0);
	float crece = smoothstep(0.0, 0.3, ph);
	float hl = altura_llama * mix(0.7, 1.0, v_sem) * crece * (1.0 - 0.25 * smoothstep(0.5, 1.0, ph)) * (1.0 - erosion);
	hl = max(hl, 0.001);
	float hn = p.y / hl;                                    // 0 en la base de la lengua, 1 en la punta
	if (hn > 1.0) {
		discard;
	}
	float lx = p.x * 1.3;
	float lado = (fract(v_sem * 7.31) * 2.0 - 1.0) * desplazamiento * 0.5;
	lx -= lado * hn * hn;
	lx += 0.28 * desplazamiento * hn * sin(hn * escala_ruido * 0.6 + v_sem * 40.0 + v_t * velocidad * 6.0);
	float wmax = ancho_max * mix(0.5, 1.0, fract(v_sem * 3.7)) * mix(1.0, 0.6, smoothstep(0.4, 1.0, ph));
	float w;
	if (hn < pico_ancho) {
		float k = (pico_ancho - hn) / pico_ancho * 0.85;
		w = wmax * sqrt(max(1.0 - k * k, 0.0));              // base redonda
	} else {
		float u = (hn - pico_ancho) / (1.0 - pico_ancho);
		w = wmax * pow(max(1.0 - pow(u, 1.35), 0.0), 0.8);   // punta redondeada, no triángulo
	}
	float q = abs(lx) / max(w, 0.001);
	if (q >= 1.0) {
		discard;
	}
	// Valor de color: alto abajo, bajo arriba y en los bordes.
	float v = 1.0 - 0.9 * hn * mix(1.3, 0.8, cuerpo_amarillo) - 0.35 * pow(q, 2.5);
	if (v < umbral) {
		discard;
	}
	vec3 col = texture(rampa, vec2(clamp(v, 0.0, 0.999), 0.5)).rgb;
	if (v < contorno * 0.2) {
		col = texture(rampa, vec2(0.01, 0.5)).rgb;
	}
	ALBEDO = col * brillo;
}
