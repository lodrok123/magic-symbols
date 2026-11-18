shader_type canvas_item;
// EL PAPEL DEL GENERADOR DE MAPAS (17/11/2026): dibuja el plano con el aspecto del Cave Generator de watabou, escrito desde cero.
// El plano llega como una textura de un píxel por casilla (R = se pisa, G = agua). Leída con filtro lineal da un campo suave: donde
// vale 0,5 está el contorno, así que las paredes salen redondeadas y a cualquier zoom, sin trazar polígonos.
//   modo 0 «cueva»: papel tostado, suelo claro, contorno grueso a tinta, rayado por fuera, sombra bajo las paredes y agua en gris azulado.
//   modo 1 «claro»: fondo de bosque oscuro, hierba, copas de árboles festoneando el borde y agua azul con orilla clara.
// `temblor`: cuánto se deforma el contorno (alto en las cuevas; casi nada en las mazmorras de salas, que solo quedan «a mano alzada»).

uniform sampler2D mapa : filter_linear, repeat_disable;
uniform vec2 tam = vec2(40.0, 34.0);          // casillas del plano
uniform vec2 tam_vista = vec2(800.0, 600.0);  // píxeles de la vista
uniform vec2 origen = vec2(0.0);              // píxel de la esquina del plano
uniform float escala = 16.0;                  // píxeles por casilla
uniform int modo = 0;
uniform float temblor = 0.25;

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(azar(i), azar(i + vec2(1.0, 0.0)), f.x), mix(azar(i + vec2(0.0, 1.0)), azar(i + vec2(1.0, 1.0)), f.x), f.y);
}

// (cuánto se pisa, cuánta agua) en un punto del plano, en casillas.
vec2 campo(vec2 p) {
	// Deformación fractal: tres octavas, cada una el doble de fina y la mitad de fuerte, para que el borde tenga entrantes grandes y dientes pequeños.
	vec2 d = vec2(0.0);
	float fuerza = 1.0;
	float fino = 0.9;
	for (int o = 0; o < 3; o++) {
		d += fuerza * (vec2(ruido(p * fino), ruido(p * fino + vec2(37.0, 11.0))) - 0.5);
		fuerza *= 0.5;
		fino *= 2.3;
	}
	vec2 q = p + temblor * d * 2.0;
	vec2 dentro = step(vec2(0.0), q) * step(q, tam);
	vec2 s = texture(mapa, (q + vec2(0.22, 0.22)) / tam).rg + texture(mapa, (q + vec2(-0.22, 0.22)) / tam).rg
		+ texture(mapa, (q + vec2(0.22, -0.22)) / tam).rg + texture(mapa, (q + vec2(-0.22, -0.22)) / tam).rg;
	return s * 0.25 * dentro.x * dentro.y;
}

// Lo mismo, pero promediado a más de una casilla de distancia: cae despacio al alejarse del suelo y sirve para las franjas
// anchas de fuera (el rayado de la roca, la orla de árboles).
float campo_ancho(vec2 p) {
	float s = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7854;
		s += campo(p + vec2(cos(ang), sin(ang)) * (i % 2 == 0 ? 0.9 : 1.6)).r;
	}
	return s / 8.0;
}

// Ruido celular: (distancia al punto más cercano, número al azar de ese punto). Cada punto es una copa.
vec2 celular(vec2 p) {
	vec2 i = floor(p);
	float md = 9.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(azar(i + g), azar(i + g + vec2(7.3, 2.1)));
			float d = length(g + o - fract(p));
			if (d < md) {
				md = d;
				id = azar(i + g + vec2(3.1, 9.7));
			}
		}
	}
	return vec2(md, id);
}

void fragment() {
	vec2 px = UV * tam_vista;
	vec2 p = (px - origen) / escala;
	vec2 c = campo(p);
	float f = c.r;
	float a = c.g;
	float paso = 1.0 / escala;                 // un píxel, en casillas
	vec2 gr = abs(fract(p) - 0.5);
	float rejilla = 1.0 - smoothstep(0.0, 1.3 * paso, 0.5 - max(gr.x, gr.y));
	float sombra = smoothstep(0.3, 0.62, campo(p - vec2(0.24, 0.24)).r);
	vec3 col;
	if (modo == 0) {
		vec3 tinta = vec3(0.07, 0.06, 0.05);
		vec3 papel = vec3(0.79, 0.72, 0.61) * (0.985 + 0.03 * ruido(px * 0.004));
		col = papel;
		// Rayado por fuera del contorno: manojos de trazos con una dirección por manojo.
		float banda = smoothstep(0.1, 0.3, campo_ancho(p) + 0.2 * (ruido(p * 1.7) - 0.5));
		vec2 t = floor(p * 1.5 + 2.5 * ruido(p * 0.8));
		float ang = floor(azar(t) * 4.0) * 0.785 + 0.4;
		float raya = smoothstep(0.5, 0.72, abs(fract(dot(p, vec2(cos(ang), sin(ang))) * 4.5 + azar(t + 1.7)) - 0.5) * 2.0);
		col = mix(col, tinta, banda * raya * 0.85 * step(f, 0.5));
		// Suelo.
		vec3 suelo = vec3(0.95, 0.92, 0.85) * mix(0.78, 1.0, sombra);
		suelo = mix(suelo, vec3(0.63, 0.69, 0.74) * mix(0.85, 1.0, sombra), smoothstep(0.42, 0.58, a));
		suelo = mix(suelo, tinta, (1.0 - smoothstep(0.0, 1.4, abs(a - 0.5) / max(fwidth(a), 0.0001))) * 0.65);
		suelo = mix(suelo, tinta, rejilla * 0.2);
		col = mix(col, suelo, step(0.5, f));
		// Contorno a tinta.
		float grosor = max(1.2, escala * 0.08);
		col = mix(col, tinta, 1.0 - smoothstep(grosor, grosor + 1.0, abs(f - 0.5) / max(fwidth(f), 0.0001)));
	} else {
		vec3 fondo = vec3(0.10, 0.18, 0.18);
		vec2 w1 = celular(p * 1.15);
		vec2 w2 = celular(p * 0.9 + vec2(5.0, 3.0));
		// Copas: cada celda del ruido es un árbol, más claro en el centro; cubren una franja junto al claro y se pierden hacia dentro del bosque.
		vec3 arbol = mix(vec3(0.15, 0.29, 0.25), vec3(0.31, 0.46, 0.33), w1.y) * (0.7 + 0.55 * smoothstep(0.55, 0.05, w1.x));
		arbol = mix(fondo * 1.25, arbol, smoothstep(0.62, 0.42, w1.x));              // copas redondas, con el hueco oscuro entre ellas
		float espesura = smoothstep(0.03, 0.22, campo_ancho(p) + 0.1 * (w2.x - 0.5));
		col = mix(fondo, arbol, espesura);
		// El borde del claro lo festonean las copas.
		float ff = f + 0.2 * (w1.x - 0.45);
		vec3 hierba = vec3(0.72, 0.76, 0.49) * (0.95 + 0.1 * ruido(p * 3.0)) * mix(0.8, 1.0, sombra);
		vec3 agua = vec3(0.24, 0.47, 0.70);
		agua = mix(agua, vec3(0.45, 0.66, 0.82), smoothstep(0.75, 0.5, a));        // orilla más clara
		hierba = mix(hierba, agua, smoothstep(0.48, 0.52, a));
		hierba = mix(hierba, vec3(0.15, 0.25, 0.2), rejilla * 0.22);
		col = mix(col, hierba, smoothstep(0.5 - 0.5 * fwidth(ff), 0.5 + 0.5 * fwidth(ff), ff));
	}
	COLOR = vec4(col, 1.0);
}
