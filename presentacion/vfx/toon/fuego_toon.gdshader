// FUEGO TOON (1/11, prueba 2 de VFX, docs/PRUEBA2_VFX_TOON_2026-11-01.md §2). Para un PLANO vertical (PlaneMesh orientado en Z, subdividido).
// Estilo Breath of the Wild: lenguas como gotas invertidas, erosión dura, tres tonos planos (rampa en escalones) y TODO el movimiento cuantizado
// a `fps` fotogramas por segundo. Sin luz (unshaded) y sin sombra. Transparencia por descarte (alfa 0/1): sin mezcla, sin ordenar planos.
// Procedimental puro: no usa texturas de ruido (solo la rampa de colores).
//  - Tres capas de celdas a lo largo del muro; en cada celda una lengua con su altura (ruido de valor 1D en tiempo cuantizado), su ladeo y su forma.
//  - `v` = «profundidad» dentro de la lengua (1 en el corazón de la base, 0 en el borde): la rampa en escalones la convierte en amarillo/naranja/rojo.
//  - Gotas sueltas por encima de la punta (se separan y desaparecen de golpe) y banda brillante en la base.
//  - La malla ondula: los vértices se desplazan en X con el mismo ruido cuantizado (mando `desplazamiento`).
// El tamaño en metros sale de la escala del nodo (MODEL_MATRIX): un muro el doble de largo tiene el doble de lenguas, no lenguas el doble de anchas.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

// --- LOS DIEZ MANDOS ---
uniform float fps : hint_range(2.0, 60.0) = 12.0;                  // fotogramas por segundo del movimiento (todo se cuantiza a esto)
uniform float umbral : hint_range(0.0, 0.6) = 0.04;                // por debajo de este valor de profundidad no se pinta (silueta más gorda o más fina)
uniform float altura_llama : hint_range(0.2, 2.0) = 0.8;           // multiplicador de la altura de las lenguas (1 = las del tamaño del plano)
uniform float desplazamiento : hint_range(0.0, 1.0) = 0.45;        // cuánto se ladean y ondulan las lenguas y la malla
uniform float contorno : hint_range(0.0, 1.0) = 0.0;               // grosor de la línea oscura del borde (0 = sin contorno)
uniform sampler2D rampa : source_color, filter_nearest, repeat_disable;   // rampa en escalones: borde (izquierda) → corazón (derecha)
uniform float velocidad : hint_range(0.1, 6.0) = 1.4;              // cuántas veces por segundo cambia cada lengua (ritmo del titileo)
uniform float escala_ruido : hint_range(2.0, 24.0) = 9.0;          // lenguas por cada 6,9 m de muro y capa (más = lenguas más finas)
uniform float brillo : hint_range(0.2, 3.0) = 1.0;                 // multiplica el color; por encima de ~1,3 el brillo del lab desborda con resplandor
uniform float erosion : hint_range(0.0, 1.0) = 0.0;                // 0 llama viva, 1 apagada (lo anima nacer / morir)

// --- Ajustes finos (no entre los diez) ---
uniform float suavidad : hint_range(0.001, 0.03) = 0.01;          // ancho de la transición del borde; ≤ 0,03 = borde duro
uniform vec2 tam_malla = vec2(6.9, 1.5);                           // tamaño del plano en metros a escala 1
uniform float semilla : hint_range(0.0, 50.0) = 0.0;              // cada plano del muro lleva la suya
uniform float ancho_lengua : hint_range(0.3, 1.0) = 0.95;         // anchura máxima de la lengua respecto a su celda
uniform float base_brillante : hint_range(0.0, 0.5) = 0.11;       // altura (relativa) de la banda luminosa de la base
uniform float gotas : hint_range(0.0, 1.0) = 0.35;                // proporción de lenguas que sueltan una gota por encima
uniform float retroceso : hint_range(0.0, 1.0) = 0.0;                // billboard_y: cuánto se aleja el plano de la cámara (m), para ir detrás de otro cuerpo
uniform bool billboard_y = false;                                  // true: el plano gira siempre de frente a la cámara pero sin tumbarse (columna, bola, impacto)
uniform vec4 color_contorno : source_color = vec4(0.45, 0.1, 0.06, 1.0);

varying vec2 v_m;      // posición en metros en el plano del muro (x a lo largo, y hacia arriba)
varying vec2 v_tam;    // tamaño en metros del plano ya con la escala del nodo
varying float v_t;     // tiempo cuantizado

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Ruido de valor en tiempo para la celda c: suave entre retículos, y como t ya está cuantizado, a saltos de 1/fps.
float ruido_t(float c, float t, float capa) {
	float f = t * velocidad;
	float i = floor(f);
	float u = fract(f);
	u = u * u * (3.0 - 2.0 * u);
	return mix(hash21(vec2(c + capa * 17.0 + semilla * 3.1, i)), hash21(vec2(c + capa * 17.0 + semilla * 3.1, i + 1.0)), u);
}

void vertex() {
	v_t = floor(TIME * fps) / fps;
	vec3 esc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), 1.0);
	if (billboard_y) {
		vec3 a = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
		a.y = 0.0;
		a = normalize(a + vec3(0.0, 0.0, 0.0001));
		vec3 der = normalize(cross(vec3(0.0, 1.0, 0.0), a));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(der * esc.x, 0.0), vec4(0.0, esc.y, 0.0, 0.0), vec4(a, 0.0), MODEL_MATRIX[3]);
		MODELVIEW_MATRIX[3].z -= retroceso;
	}
	v_tam = tam_malla * esc.xy;
	// El plano mide tam_malla; VERTEX está en [-tam/2, tam/2].
	v_m = vec2(VERTEX.x + tam_malla.x * 0.5, VERTEX.y + tam_malla.y * 0.5) * esc.xy;
	// Ondulación de la malla (mismo ruido cuantizado): la parte alta se desplaza más.
	float h = clamp((VERTEX.y + tam_malla.y * 0.5) / tam_malla.y, 0.0, 1.0);
	float celda = floor((VERTEX.x / max(tam_malla.x, 0.001) + 0.5) * 8.0);
	float o = ruido_t(celda, v_t, 5.0) - 0.5;
	VERTEX.x += o * desplazamiento * 0.35 * h * h * tam_malla.y;
}

// Una capa de lenguas: devuelve la profundidad v (0 si fuera) en la posición p (metros) del plano.
float capa_lenguas(vec2 p, float capa, float n_celdas, float alto_m) {
	float desfase = capa * 0.37 + hash11(capa + semilla) * 0.5;
	float xs = p.x / v_tam.x * n_celdas * (1.0 + capa * 0.19) + desfase;
	float c = floor(xs);
	float lx = (fract(xs) - 0.5) * 2.0;                       // -1..1 dentro de la celda
	// Altura propia de esta lengua: base 40 % + hasta 60 % de ruido en tiempo.
	float r = ruido_t(c, v_t, capa);
	float r2 = ruido_t(c + 91.0, v_t * 0.7, capa);
	float u_x = p.x / v_tam.x;
	float afinar = mix(0.3, 1.0, smoothstep(0.0, 0.07, min(u_x, 1.0 - u_x)));   // los extremos del muro bajan
	float hl = alto_m * altura_llama * (0.38 + 0.62 * r) * (1.0 - erosion) * afinar;
	// Ladeo creciente con la altura (la llama se dobla, no se corta).
	float lado = (r2 - 0.5) * 2.0 * desplazamiento * 0.45;
	float yn = clamp(p.y / max(hl, 0.001), 0.0, 1.2);
	lx -= lado * yn * yn;
	lx += 0.14 * yn * sin(yn * 9.0 + r2 * 40.0 + v_t * velocidad * 2.0);   // borde ondulado, a saltos de fotograma
	// Anchura: ancha abajo, punta redondeada (gota invertida).
	float w = ancho_lengua * pow(max(1.0 - pow(yn, 2.4), 0.0), 0.5) * (0.75 + 0.25 * r2);
	float q = abs(lx) / max(w, 0.001);
	// La silueta es geometría (no depende del color): umbral la encoge o la engorda.
	float dentro = (yn < 1.0 - umbral && q < 1.0 - umbral) ? 1.0 : 0.0;
	float v = dentro * max(pow(max((1.0 - q) * (1.0 - yn) * 1.25, 0.0), 0.7), 0.001 + umbral);
	// Gota suelta sobre la punta: aparece a ratos, sube y se va de golpe.
	if (gotas > 0.0 && hash11(c * 3.7 + capa * 11.0 + floor(v_t * velocidad) * 0.37 + semilla) < gotas) {
		float fase = fract(v_t * velocidad * 0.5 + hash11(c + capa));
		float yb = hl * (1.08 + 0.35 * fase);
		float rb = 0.07 * alto_m / 1.5 * (1.0 - fase * 0.55);
		float d = length(vec2(lx * 0.5 * v_tam.x / (n_celdas * (1.0 + capa * 0.19)), p.y - yb)) / max(rb, 0.001);
		if (d < 1.0 && fase < 0.8) {
			v = max(v, 0.3);
		}
	}
	return v;
}

void fragment() {
	vec2 p = v_m;
	float n_celdas = max(2.0, floor(escala_ruido * v_tam.x / 6.9 + 0.5));
	float alto_m = v_tam.y;
	float v = 0.0;
	for (int k = 0; k < 3; k++) {
		v = max(v, capa_lenguas(p, float(k), n_celdas, alto_m) * (1.0 - 0.0 * float(k)));
	}
	// Banda brillante de la base: borde superior ondulado en pasos.
	float ond = ruido_t(floor(p.x / v_tam.x * n_celdas * 2.0), v_t, 7.0);
	float alto_base = alto_m * base_brillante * (0.6 + 0.8 * ond) * (1.0 - erosion);
	float vb = clamp(1.0 - p.y / max(alto_base, 0.001), 0.0, 1.0);
	if (p.y < alto_base) {
		v = max(v, 0.3 + 0.35 * vb);
	}
	// Silueta dura.
	float a = smoothstep(umbral * 0.5, umbral * 0.5 + suavidad, v);
	if (a < 0.5) {
		discard;
	}
	// Contorno: franja oscura donde v está por debajo de umbral + grosor (segundo umbral).
	float u_borde = umbral + contorno * 0.12;
	vec3 col = texture(rampa, vec2(clamp(v, 0.0, 0.999), 0.5)).rgb;
	if (contorno > 0.0 && v < u_borde) {
		col = color_contorno.rgb;
	}
	ALBEDO = col * brillo;
}
