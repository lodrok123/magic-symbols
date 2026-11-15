// VALLA DE MADERA (14/11/2026, Pablo: «darle un aspecto más de madera a la textura»).
// La valla modular de Meshy llega con un naranja liso de juguete. Se le pone encima la veta de una corteza real
// (Poly Haven, metasequoia_bark, CC0) en triplanar sobre el modelo, estirada a lo largo de los postes, solo donde es madera:
// las cuerdas (amarillas) y los herrajes (grises) se quedan como venían. Además se apaga y se agrisa el naranja hacia madera curtida.
shader_type spatial;

uniform sampler2D textura : source_color, filter_linear_mipmap;          // la de Meshy
uniform sampler2D corteza : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D alto_corteza : filter_linear_mipmap, repeat_enable;
uniform float escala = 4.0;          // repeticiones por unidad del modelo (la pieza mide ~0,4)
uniform float estirar = 0.35;        // < 1: veta alargada en vertical, como un poste
uniform float veta = 0.45;          // cuánto manda la corteza en la madera
uniform vec3 curtido = vec3(0.62, 0.48, 0.36);   // tono de madera vieja hacia el que se lleva el naranja
uniform float curtir = 0.8;
uniform float relieve = 0.9;

// Variedad de color (14/11, Pablo: «meterle ruido para añadir variedad en el color»): cada poste/panel tira a un tono distinto
// (más gris de intemperie, más rojizo, más oscuro) y, dentro, manchas grandes y suaves en coordenadas de mundo.
uniform float var_panel = 0.55;      // diferencia de tono entre paneles
uniform float var_manchas = 0.35;    // manchas de humedad/sol dentro del panel
uniform float escala_manchas = 0.7;  // manchas por metro
uniform vec3 tono_gris = vec3(0.62, 0.6, 0.56);
uniform vec3 tono_rojo = vec3(0.72, 0.46, 0.32);

varying vec3 p_obj;
varying vec3 n_obj;
varying vec3 p_mundo;
varying float semilla;
varying float alto_pie;              // metros sobre el pie del panel (el origen de la malla está en su base)

// Pie de los postes (14/11, contra el efecto pegatina): los últimos centímetros se oscurecen y se manchan de barro y musgo.
uniform float pie_alto = 0.4;
uniform vec3 pie_color = vec3(0.32, 0.3, 0.2);
uniform float pie_fuerza = 0.75;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float ruido(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	p_obj = VERTEX;
	n_obj = NORMAL;
	p_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	semilla = hash(floor(MODEL_MATRIX[3].xyz * 3.0));
	alto_pie = p_mundo.y - MODEL_MATRIX[3].y;
}

vec3 tri(sampler2D t, vec3 p, vec3 w) {
	vec3 x = texture(t, vec2(p.z, p.y * estirar) * escala).rgb;
	vec3 y = texture(t, p.xz * escala).rgb;
	vec3 z = texture(t, vec2(p.x, p.y * estirar) * escala).rgb;
	return x * w.x + y * w.y + z * w.z;
}

void fragment() {
	vec3 base = texture(textura, UV).rgb;
	vec3 w = pow(abs(normalize(n_obj)), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 c = tri(corteza, p_obj, w);
	float h = tri(alto_corteza, p_obj, w).r;
	// Madera: naranja con poco verde frente al rojo. Cuerda: amarilla (verde alto). Hierro: gris (sin saturación).
	float sat = max(base.r, max(base.g, base.b)) - min(base.r, min(base.g, base.b));
	float madera = smoothstep(0.18, 0.3, sat) * (1.0 - smoothstep(0.62, 0.72, base.g / max(base.r, 0.01)));
	vec3 vieja = mix(base, curtido * dot(base, vec3(0.45, 0.4, 0.15)) * 2.0, curtir);
	// La corteza manda en el color (pardo grisáceo real) y en el dibujo; el naranja de Meshy queda solo como un tinte cálido.
	vec3 madera_c = mix(vieja, c * 1.5 * vec3(1.05, 0.95, 0.85), veta) * (0.8 + h * 0.4);
	// Cada poste dentro del panel (por su X en el modelo) y cada panel (semilla) con su tono; manchas suaves encima.
	float poste = hash(vec3(floor(p_obj.x * 14.0), semilla * 7.0, 0.0));
	float t = fract(semilla + poste * 0.6);
	vec3 tono = t < 0.4 ? mix(vec3(1.0), tono_gris / 0.6, (0.4 - t) * 2.5 * var_panel * 2.0)
		: mix(vec3(1.0), tono_rojo / 0.5, (t - 0.4) * 1.6 * var_panel);
	float m = ruido(p_mundo * escala_manchas) * 0.65 + ruido(p_mundo * escala_manchas * 3.1) * 0.35;
	madera_c *= tono * (1.0 + (m - 0.5) * 2.0 * var_manchas) * (0.78 + 0.44 * poste);
	ALBEDO = mix(base, madera_c, madera);
	// Pie: borde irregular (ruido) para que no sea una raya recta a la misma altura en todos los postes.
	float borde = pie_alto * (0.7 + 0.6 * ruido(p_mundo * vec3(6.0, 0.0, 6.0)));
	float pie = 1.0 - smoothstep(0.0, borde, alto_pie);
	ALBEDO = mix(ALBEDO, ALBEDO * pie_color * 1.6, pie * pie_fuerza);
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
	// Relieve: las grietas (alto bajo) se oscurecen un poco más, como oclusión.
	AO = mix(1.0, 0.8 + h * 0.3, madera * relieve);
	AO_LIGHT_AFFECT = 0.6;
}
