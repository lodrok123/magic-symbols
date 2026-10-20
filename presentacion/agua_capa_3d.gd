class_name AguaCapa3D
extends Node3D
## CAPA VISUAL DEL AGUA, PROTOTIPO W1 (Pipeline, 20/10; PLAN_TRES_FRENTES §3). SIGUE a la simulación (`AguaSim3D`) y no decide nada del gameplay: solo lee
## `imagen()`, `textura_caida()` y `textura_eventos()` (contrato W0, diario 197) y no escribe en la simulación.
##
## POR QUÉ existe: `AguaRender3D` pinta la simulación casi tal cual, un vértice por trocito de 0,77 u, con facetas planas; por eso el agua se ve «a celdas».
## Esta capa tiene una superficie con 4 × 4 vértices por trocito (`escala`) y la altura es el nivel de la simulación SUAVIZADO ENTRE TROCITOS (interpolación
## que solo promedia los trocitos con agua, para que la orilla no arrastre la altura del suelo) más un error que sigue a ese objetivo con un MUELLE.
##
## CÓMO (y por qué no es un compute shader como pedía el plan): son pasadas de shader de 2D sobre dos SubViewports que se turnan (ping-pong), una textura de
## `escala × w` por `escala × h` en RGBA16F (`use_hdr_2d`): R = error de altura (nivel dibujado − nivel objetivo, en u), G = su velocidad, B = ESPUMA.
## Motivos: (1) el proyecto es Forward+ pero mi entorno de pruebas solo tiene Compatibilidad, donde `RenderingDevice` no existe, y una capa que no puedo ver ni
## medir no se puede validar; esta funciona igual en los dos. (2) Es la misma matemática que un compute shader (una pasada por texel con la lectura anterior),
## y si en la medida de tu equipo no cabe en ≤ 1 ms se pasa a `RenderingDevice` sin cambiar nada de fuera.
## El error se guarda RELATIVO al objetivo (no la altura absoluta) por precisión: en media precisión una Y de 8 u solo distingue 0,008 u y el muelle se pararía.
##
## Qué lleva la superficie: normales SUAVES (no facetadas) sacadas de la altura; ESPUMA que se arrastra con la corriente de la simulación (advección
## semi-lagrangiana, con fuentes en la orilla, donde la corriente es fuerte, en las caídas > UMBRAL_CAIDA y en los eventos de entrada de agua); DETALLE de olas
## con flow map de dos fases arrastrado por la misma corriente, y brillos en bandas. Estilo de las referencias de Pablo (Link's Awakening): bandas de color por
## profundidad, brillos blancos y espuma nítida. W2 (20/10): ONDAS (el error de altura se propaga a los vecinos y nacen de los eventos de la simulación, de los pies de las cascadas y de `impulso()`),
## CASCADAS (cortina de agua vertical + salpicadura en el pie donde `textura_caida()` > UMBRAL_CAIDA), HIELO (se pinta donde `textura_hielo()` dice «helado»; no ondula,
## no tiene espuma y se agrieta cuando le queda poco) y ORILLA CON RUIDO (el borde del agua es irregular, como en AguaRender3D, 125).
## Sigue SIN hacer: paredes laterales ni topes del canal (eso sigue en AguaRender3D, 13.9) y no limita la malla a `caja_trabajo()` (la superficie cubre todo el mapa).
##
## Uso:   var c := AguaCapa3D.new(); add_child(c); c.enlazar(sim)     # sim: AguaSim3D; se actualiza sola
## Medida: `milisegundos_gpu()` (lo que tarda la pasada, medido por el motor), `milisegundos_lectura()` (CPU, leer la simulación).

## Vértices y texels por lado de trocito (el plan pide ×4).
@export var escala: int = 4
## Veces por segundo que se lee la simulación; entre lecturas el muelle y la espuma avanzan cada fotograma.
@export var hz_lectura: float = 12.0
## Debajo de esta profundidad (u) un trocito es suelo mojado, no agua (igual que AguaRender3D).
@export var profundidad_minima: float = 0.05
## Muelle del error de altura: rigidez (1/s²) y amortiguación (1/s). Con 70 y 11 el amortiguamiento es ~0,66 del crítico (teoría: se asienta en ~0,7 s con un rebote suave; la prueba mide que vuelve a < 0,02 u en 4 s).
@export var rigidez: float = 70.0
@export var amortiguacion: float = 11.0
## Segundos que tarda la espuma en apagarse sin fuente.
@export var vida_espuma: float = 1.6
## W2 · Velocidad (u/s) a la que viajan las ondas por la superficie. Con dt ≤ 0,05 s y texels de 0,19 u es estable hasta ~3,5 u/s (c·dt/dx < 0,707).
@export var velocidad_ondas: float = 2.0
## W2 · Lo que se apagan las ondas por segundo (1/s): con 0,9 a los 2 s queda un 16 % y a los 8 s casi nada.
@export var amortiguacion_ondas: float = 0.9
## W2 · Cuánto desordena el ruido el contorno del agua (u de profundidad; ~0,3 u de orilla). 0 = recto.
@export var ruido_orilla: float = 0.11
## W2 · Textura del hielo. Si es null se hace la MISMA que el bloque de hielo 3D de la maqueta (`prueba_test2._textura_hielo`): `hielo_arriba.png` de `arte/suelo_meshy/`
## si existe y, si no, `water_arriba.png` desaturada y aclarada. Se mezcla con el color del hielo (`mezcla_textura_hielo`, 0 = sin textura, como antes) y se repite
## `escala_textura_hielo` veces por u (en planta: el hielo del agua es plano).
@export var textura_hielo: Texture2D = null
@export_range(0.0, 1.0) var mezcla_textura_hielo: float = 0.8
@export var escala_textura_hielo: float = 0.3
## W2 · Tope de cascadas dibujadas a la vez (cada una es una cortina y un punto de salpicadura).
@export var max_cascadas: int = 24
## W2 · Partículas de salpicadura (todas las cascadas juntas): el plan limita a 400 por hechizo, esto es la mitad.
@export var particulas_salpicadura: int = 160

const MUESTRA: String = """
uniform sampler2D sim_a : filter_nearest, repeat_disable;       // lectura anterior de la simulación (R superficie Y, G profundidad, BA corriente u/s)
uniform sampler2D sim_b : filter_nearest, repeat_disable;       // lectura última
uniform vec2 sim_dim = vec2(48.0, 48.0);                        // trocitos de ancho y de alto
uniform float lado = 0.7667;                                    // lado de un trocito (u)
uniform float minima = 0.05;

vec4 tap(sampler2D ta, sampler2D tb, ivec2 p, float m) {
	p = clamp(p, ivec2(0), ivec2(sim_dim) - ivec2(1));
	return mix(texelFetch(ta, p, 0), texelFetch(tb, p, 0), m);
}

// Interpola la simulación en `uv`: x = nivel de la superficie, y = profundidad, zw = corriente. El nivel y la corriente promedian SOLO los trocitos con agua
// (si no, en la orilla el nivel se hunde hacia el suelo seco); la profundidad es la interpolación normal, que llega a 0 en seco. `peso` = cuánto de la
// vecindad es agua (0..1).
vec4 muestra(sampler2D ta, sampler2D tb, vec2 uv, float m, out float peso) {
	vec2 q = uv * sim_dim - vec2(0.5);
	ivec2 i0 = ivec2(floor(q));
	vec2 f = q - vec2(i0);
	vec4 s00 = tap(ta, tb, i0, m);
	vec4 s10 = tap(ta, tb, i0 + ivec2(1, 0), m);
	vec4 s01 = tap(ta, tb, i0 + ivec2(0, 1), m);
	vec4 s11 = tap(ta, tb, i0 + ivec2(1, 1), m);
	float w00 = (1.0 - f.x) * (1.0 - f.y);
	float w10 = f.x * (1.0 - f.y);
	float w01 = (1.0 - f.x) * f.y;
	float w11 = f.x * f.y;
	float a00 = s00.y > minima ? w00 : 0.0;
	float a10 = s10.y > minima ? w10 : 0.0;
	float a01 = s01.y > minima ? w01 : 0.0;
	float a11 = s11.y > minima ? w11 : 0.0;
	float sw = a00 + a10 + a01 + a11;
	vec4 liso = s00 * w00 + s10 * w10 + s01 * w01 + s11 * w11;
	vec4 mojado = (s00 * a00 + s10 * a10 + s01 * a01 + s11 * a11) / max(sw, 0.0001);
	vec4 r = sw > 0.0001 ? mojado : liso;
	r.y = liso.y;
	peso = sw;
	return r;
}
"""

const CODIGO_ESTADO: String = """
shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D previo : filter_linear, repeat_disable;       // el estado del paso anterior (la otra textura del ping-pong)
uniform sampler2D caida : filter_nearest, hint_default_black, repeat_disable;     // RF: salto de superficie hacia un vecino más bajo (u)
uniform sampler2D eventos : filter_nearest, hint_default_black, repeat_disable;   // RG8: R = tipo/255, G = intensidad
uniform float mezcla = 1.0;
uniform float mezcla_previa = 1.0;
uniform sampler2D sim_pa : filter_nearest, repeat_disable;      // el par (a, b) que se usó en el paso anterior: el objetivo de entonces se recalcula exacto
uniform sampler2D sim_pb : filter_nearest, repeat_disable;
uniform float dt = 0.016;
uniform float rigidez = 70.0;
uniform float amortiguacion = 11.0;
uniform float vida_espuma = 1.6;
uniform float umbral_caida = 0.5;
uniform float ganancia_eventos = 0.0;
uniform sampler2D hielo : filter_nearest, hint_default_black, repeat_disable;     // RG8 de textura_hielo(): R = helado (el hielo no ondula ni tiene espuma)
uniform vec4 imp[8];                                            // impulsos de onda (los mismos que ve el campo de ondas): aquí solo dan ESPUMA
uniform int n_imp = 0;
//@MUESTRA

void fragment() {
	ivec2 p = ivec2(FRAGCOORD.xy);
	vec4 pv = texelFetch(previo, p, 0);
	float peso;
	vec4 s = muestra(sim_a, sim_b, UV, mezcla, peso);
	float peso0;
	vec4 s0 = muestra(sim_pa, sim_pb, UV, mezcla_previa, peso0);
	// El objetivo se movió de s0 a s desde el paso anterior: el error absorbe lo que se movió y el muelle lo recupera (el nivel dibujado no salta).
	float e = clamp(pv.r + (s0.x - s.x), -1.5, 1.5);
	float ve = pv.g;
	ve += (-rigidez * e - amortiguacion * ve) * dt;
	e += ve * dt;
	float espuma_imp = 0.0;
	for (int k = 0; k < 8; k++) {
		if (k >= n_imp) {
			break;
		}
		vec2 d = (UV - imp[k].xy) * sim_dim * lado;
		float g = exp(-dot(d, d) / max(imp[k].w * imp[k].w, 0.0001));
		espuma_imp = max(espuma_imp, g * min(abs(imp[k].z) * 3.5, 1.0));      // solo los impulsos fuertes (≥ ~0,15 u) dejan espuma: las ondas suaves del pie de una cascada no
	}
	e = clamp(e, -1.5, 1.5);
	float helado = texture(hielo, UV).r > 0.5 ? 1.0 : 0.0;
	float vivo = step(0.01, s.y) * (1.0 - helado);
	e *= vivo;
	ve *= vivo;
	// Espuma: se arrastra con la corriente (de dónde vengo = aquí menos la velocidad × dt) y se apaga; las fuentes la renuevan.
	vec2 corriente = s.zw;
	vec2 atras = corriente * dt / (sim_dim * lado);
	float fo = texture(previo, UV - atras).b * exp(-dt / max(vida_espuma, 0.05));
	float prof = s.y;
	// La orilla es donde la VECINDAD tiene menos agua (no donde hay poca profundidad: un río somero entero no es orilla).
	float orilla = 1.0 - smoothstep(0.6, 0.98, peso);
	float rapido = smoothstep(0.9, 1.6, length(corriente));
	float cd = texture(caida, UV).r;
	float cascada = smoothstep(umbral_caida * 0.8, umbral_caida * 1.6, cd);
	vec2 ev = texture(eventos, UV).rg;
	float entra = ganancia_eventos * ((abs(ev.r * 255.0 - 1.0) < 0.5) ? ev.g : 0.0);
	float fuente = max(max(max(orilla * 0.7, rapido * 0.5), max(cascada, entra)), espuma_imp);
	fo = max(fo, fuente * vivo);
	fo *= vivo;
	COLOR = vec4(e, ve, clamp(fo, 0.0, 1.0), 0.0);
}
"""

const CODIGO_SUPERFICIE: String = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, unshaded;

uniform sampler2D estado : filter_linear, repeat_disable;      // R error de altura, G su velocidad, B espuma
uniform sampler2D ondas : filter_linear, hint_default_black, repeat_disable;   // W2: R altura de las ondas (u)
uniform sampler2D ruido : filter_linear, repeat_enable;        // ruido continuo para el detalle de las olas
uniform float mezcla = 1.0;
uniform vec2 fino_dim = vec2(192.0, 192.0);
uniform float escala = 4.0;
uniform float reloj = 0.0;
uniform vec3 color_somero : source_color = vec3(0.44, 0.80, 0.91);
uniform vec3 color_hondo : source_color = vec3(0.20, 0.52, 0.80);
uniform vec3 color_espuma : source_color = vec3(0.96, 0.99, 1.0);
uniform float prof_clara = 0.1;
uniform float prof_rio = 1.0;
uniform float prof_color = 0.9;
uniform float alfa_clara = 0.38;
uniform float alfa_rio = 0.95;
uniform float bandas = 3.0;
uniform float escala_olas = 0.22;      // ciclos de ruido por u
uniform float avance = 1.5;            // cuánto arrastra la corriente el detalle por ciclo
uniform float fuerza_olas = 0.35;
uniform vec3 sol = vec3(0.35, 0.8, 0.45);
uniform float ruido_orilla = 0.11;
uniform sampler2D hielo : filter_nearest, hint_default_black, repeat_disable;   // RG8 de textura_hielo(): R = 1 helado, G = lo que le queda (0 = a punto de soltarse)
uniform vec3 color_hielo_claro : source_color = vec3(0.78, 0.90, 0.98);
uniform vec3 color_hielo_hondo : source_color = vec3(0.50, 0.70, 0.90);
uniform vec3 color_grieta : source_color = vec3(0.25, 0.50, 0.85);
uniform sampler2D tex_hielo : source_color, filter_linear_mipmap, repeat_enable;
uniform float mezcla_tex_hielo = 0.8;
uniform float escala_tex_hielo = 0.3;
//@MUESTRA

varying vec3 n_mundo;
varying vec2 v_uv;
varying vec3 p_mundo;

// (hielo, aviso) en `uv`: bilineal entre los cuatro trocitos de alrededor; el aviso (0-1) sube cuando al hielo le queda poco y solo cuenta donde hay hielo.
vec2 hielo_ab(vec2 uv) {
	ivec2 sz = ivec2(sim_dim);
	vec2 q = uv * sim_dim - vec2(0.5);
	ivec2 i0 = ivec2(floor(q));
	vec2 f = q - vec2(i0);
	float sr = 0.0;
	float sg = 0.0;
	for (int k = 0; k < 4; k++) {
		ivec2 o = ivec2(k & 1, k >> 1);
		float w = (o.x == 1 ? f.x : 1.0 - f.x) * (o.y == 1 ? f.y : 1.0 - f.y);
		vec4 t = texelFetch(hielo, clamp(i0 + o, ivec2(0), sz - 1), 0);
		float r = t.r > 0.5 ? 1.0 : 0.0;
		sr += r * w;
		sg += t.g * r * w;
	}
	return vec2(sr, 1.0 - smoothstep(0.0, 0.2, sg / max(sr, 0.0001)));
}

float altura(vec2 uv) {
	float pe;
	return muestra(sim_a, sim_b, uv, mezcla, pe).x + texture(estado, uv).r + texture(ondas, uv).r;
}

void vertex() {
	vec2 d = 1.0 / fino_dim;
	float hc = altura(UV);
	float hx = altura(UV + vec2(d.x, 0.0)) - altura(UV - vec2(d.x, 0.0));
	float hz = altura(UV + vec2(0.0, d.y)) - altura(UV - vec2(0.0, d.y));
	float paso = 2.0 * lado / escala;
	VERTEX.y = hc;
	n_mundo = normalize(vec3(-hx / paso, 1.0, -hz / paso));
	v_uv = UV;
	p_mundo = vec3(VERTEX.x, hc, VERTEX.z);
}

void fragment() {
	float pe;
	vec4 s = muestra(sim_a, sim_b, v_uv, mezcla, pe);
	// ORILLA CON RUIDO (125): la profundidad se interpola entre trocitos de 0,77 u y su línea de cero sale recta; el ruido (quieto: no debe parpadear)
	// hace el borde irregular y, como también entra en el color, la franja clara de la orilla no sigue la rejilla.
	float rb = texture(ruido, p_mundo.xz * 0.3).r * 0.65 + texture(ruido, p_mundo.xz * 0.7 + 0.37).r * 0.35;
	// El ruido solo desordena el BORDE (vecindad con tierra, pe < 1): en una lámina fina que cubre un suelo entero lo rompería en manchas de agua y suelo.
	float prof = max(s.y + (rb - 0.5) * ruido_orilla * 2.0 * (1.0 - smoothstep(0.7, 0.97, pe)), 0.0);
	float vis = smoothstep(minima, minima + 0.05, prof);
	if (vis < 0.01) {
		discard;
	}
	vec2 corriente = s.zw;
	// Flow map de dos fases: el detalle se arrastra con la corriente y se re-inicia desacompasado para no verse correr siempre igual.
	float f1 = fract(reloj * 0.6);
	float f2 = fract(reloj * 0.6 + 0.5);
	float w1 = abs(2.0 * f1 - 1.0);
	vec2 q = p_mundo.xz * escala_olas;
	float r1 = texture(ruido, q - corriente * avance * f1).r;
	float r2 = texture(ruido, q * 1.37 + 0.31 - corriente * avance * f2).r;
	float detalle = mix(r1, r2, w1);
	// Normal: la de la altura más un empujón del detalle, más fuerte donde la corriente es rápida.
	vec2 gd = vec2(texture(ruido, q + vec2(0.01, 0.0)).r - texture(ruido, q - vec2(0.01, 0.0)).r, texture(ruido, q + vec2(0.0, 0.01)).r - texture(ruido, q - vec2(0.0, 0.01)).r);
	vec3 n = normalize(n_mundo + vec3(gd.x, 0.0, gd.y) * fuerza_olas * (0.4 + smoothstep(0.0, 1.0, length(corriente))));
	float t = clamp((prof - prof_clara) / max(prof_color - prof_clara, 0.01), 0.0, 1.0);
	t = floor(t * bandas + 0.5) / bandas;
	vec3 col = mix(color_somero, color_hondo, t);
	vec3 l = normalize(sol);
	float luz = 0.82 + 0.18 * smoothstep(0.0, 1.0, dot(n, l));
	col *= luz;
	vec3 vd = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float spec = dot(n, normalize(l + vd));
	col += vec3(1.0) * (smoothstep(0.992, 0.995, spec) * 0.55 + smoothstep(0.96, 0.963, spec) * 0.18);
	col += vec3(1.0) * smoothstep(0.78, 0.82, detalle) * 0.18;
	float fo = texture(estado, v_uv).b;
	float espuma = smoothstep(0.44, 0.56, fo + (detalle - 0.5) * 0.35);
	// Línea de espuma NÍTIDA justo en la orilla y un segundo filo más fino que se acerca y se aleja despacio (el «borde blanco» de Echoes of Wisdom / Link's Awakening).
	float orilla_real = 1.0 - smoothstep(0.7, 0.95, pe);     // solo donde la vecindad tiene tierra: una lámina fina que corre por una terraza no es orilla
	float linea = smoothstep(0.0, 0.015, prof) * (1.0 - smoothstep(0.045, 0.065, prof)) * orilla_real;
	float oleaje = 0.17 + 0.04 * sin(reloj * 0.9 + p_mundo.x * 1.3 + p_mundo.z * 0.9);
	float filo = (1.0 - smoothstep(0.008, 0.016, abs(prof - oleaje))) * smoothstep(0.1, 0.4, pe);
	espuma = max(espuma, max(linea * smoothstep(0.30, 0.45, detalle + 0.25), filo * 0.8 * smoothstep(0.3, 0.5, detalle)));
	// Las crestas de las ondas se dibujan como anillos blancos finos (los anillos de Echoes of Wisdom): donde la altura de onda pasa de un umbral, en una banda estrecha.
	float h_onda = texture(ondas, v_uv).r;
	float anillo = smoothstep(0.012, 0.02, abs(h_onda)) * (1.0 - smoothstep(0.035, 0.06, abs(h_onda)));
	espuma = max(espuma, anillo * 0.85);
	// HIELO: opaco, claro, sin olas ni espuma; las grietas (la línea donde otro ruido vale 0,5) se ensanchan y se saturan cuando le queda poco.
	vec2 ha = hielo_ab(v_uv);
	float hielo_m = smoothstep(0.36, 0.64, ha.x + (texture(ruido, p_mundo.xz * 0.45).r - 0.5) * 0.5);
	vec3 hc = mix(color_hielo_claro, color_hielo_hondo, 0.45 * smoothstep(0.4, 0.6, texture(ruido, p_mundo.xz * 0.18 + 0.2).r));
	hc = mix(hc, texture(tex_hielo, p_mundo.xz * escala_tex_hielo).rgb, mezcla_tex_hielo);
	float grieta = (1.0 - smoothstep(0.0, 0.006 + 0.04 * ha.y, abs(texture(ruido, p_mundo.xz * 0.5 + 0.7).r - 0.5))) * (0.25 + 0.75 * ha.y);
	hc = mix(hc, color_grieta, grieta);
	hc += vec3(1.0) * smoothstep(0.992, 0.995, spec) * 0.6;
	espuma *= 1.0 - hielo_m;
	col = mix(col, color_espuma, espuma);
	col = mix(col, hc, hielo_m);
	float a = mix(alfa_clara, alfa_rio, smoothstep(prof_clara, prof_rio, prof));
	ALBEDO = col;
	ALPHA = mix(max(a, espuma * 0.95), 0.97, hielo_m) * vis;
}
"""

## W2 · CAMPO DE ONDAS: una ecuación de ondas aparte (R = altura, G = velocidad) para que el muelle del nivel no las amortigüe (con su amortiguación de 11/s una onda
## moría antes de recorrer 1 u). Va a la misma resolución que el estado. Donde no hay agua o hay hielo vale 0: la orilla absorbe la onda y el hielo no ondula.
const CODIGO_ONDAS: String = """
shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D previo : filter_nearest, repeat_disable;
uniform sampler2D sim_b : filter_nearest, repeat_disable;        // la lectura última de la simulación (solo se mira G = profundidad)
uniform sampler2D hielo : filter_nearest, hint_default_black, repeat_disable;
uniform vec2 sim_dim = vec2(48.0, 48.0);
uniform float lado = 0.7667;
uniform float minima = 0.05;
uniform float dt = 0.016;
uniform float c2 = 4.0;                                          // (u/s)²
uniform float amort = 0.9;                                       // 1/s
uniform vec4 imp[8];                                             // xy uv, z altura (u, con signo), w radio (u)
uniform int n_imp = 0;

void fragment() {
	ivec2 p = ivec2(FRAGCOORD.xy);
	ivec2 tam = textureSize(previo, 0);
	vec4 pv = texelFetch(previo, p, 0);
	float dx = lado * sim_dim.x / float(tam.x);
	float lap = texelFetch(previo, clamp(p + ivec2(-1, 0), ivec2(0), tam - 1), 0).r + texelFetch(previo, clamp(p + ivec2(1, 0), ivec2(0), tam - 1), 0).r
		+ texelFetch(previo, clamp(p + ivec2(0, -1), ivec2(0), tam - 1), 0).r + texelFetch(previo, clamp(p + ivec2(0, 1), ivec2(0), tam - 1), 0).r - 4.0 * pv.r;
	float v = pv.g + (c2 * lap / (dx * dx) - amort * pv.g) * dt;
	float h = pv.r + v * dt;
	for (int k = 0; k < 8; k++) {
		if (k >= n_imp) {
			break;
		}
		vec2 d = (UV - imp[k].xy) * sim_dim * lado;
		h += imp[k].z * exp(-dot(d, d) / max(imp[k].w * imp[k].w, 0.0001));
	}
	h = clamp(h, -1.0, 1.0);
	float vivo = step(minima, texelFetch(sim_b, clamp(ivec2(UV * sim_dim), ivec2(0), ivec2(sim_dim) - 1), 0).g) * (1.0 - step(0.5, texture(hielo, UV).r));
	COLOR = vec4(h * vivo, v * vivo, 0.0, 0.0);
}
"""

## W2 · CORTINA de una cascada: un cuadrado vertical por caída (de la superficie de arriba a la de abajo) con hebras que bajan, más blancas hacia el pie.
const CODIGO_CORTINA: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D ruido : filter_linear, repeat_enable;
uniform float reloj = 0.0;
uniform vec3 color_agua : source_color = vec3(0.56, 0.84, 0.95);
uniform vec3 color_espuma : source_color = vec3(0.96, 0.99, 1.0);

void fragment() {
	float alto = length(MODEL_MATRIX[1].xyz);
	float ancho = length(MODEL_MATRIX[0].xyz);
	vec2 q = vec2(UV.x * ancho, UV.y * alto);
	float n1 = texture(ruido, vec2(q.x * 0.55, q.y * 0.30 - reloj * 1.7)).r;
	float n2 = texture(ruido, vec2(q.x * 1.10 + 0.31, q.y * 0.18 - reloj * 2.6)).r;
	float hebra = smoothstep(0.47, 0.56, n1 * 0.55 + n2 * 0.45);
	float pie = smoothstep(0.55, 1.0, UV.y);
	vec3 col = mix(color_agua, color_espuma, clamp(hebra * 0.8 + pie * 0.6, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = clamp(0.5 + 0.35 * hebra + 0.2 * pie, 0.0, 0.92);
}
"""

const RUTA_HIELO: String = "res://arte/suelo_meshy/hielo_arriba.png"
const RUTA_AGUA: String = "res://arte/suelo_meshy/water_arriba.png"
const DX: Array = [1, -1, 0, 0]
const DZ: Array = [0, 0, 1, -1]
const MAX_COLA_IMPULSOS: int = 64

var sim: AguaSim3D = null
var _vps: Array = []                    ## los dos SubViewports del ping-pong
var _mats: Array = []                   ## el material de estado de cada uno
var _turno: int = 0                     ## cuál se pinta en este paso
var _superficie: MeshInstance3D = null
var _mat_sup: ShaderMaterial = null
var _tex_a: ImageTexture = null
var _tex_b: ImageTexture = null
var _img_a: Image = null
var _img_b: Image = null
var _tex_pa: ImageTexture = null        ## el par (a, b) de ANTES de la última lectura: se necesita para recalcular exacto el objetivo del paso anterior
var _tex_pb: ImageTexture = null
var _tex_eventos: ImageTexture = null
var _desde: float = 0.0
var _intervalo: float = 1.0 / 12.0
var _mezcla_prev: float = 1.0
var _reloj: float = 0.0
var _ms_lectura: float = 0.0
var _ms_gpu: float = 0.0
var _pasos: int = 0
var _fw: int = 0
var _fh: int = 0
var _eventos_en_este_paso: bool = false
var _tex_caida: ImageTexture = null
var _vps_o: Array = []                  ## ping-pong del campo de ondas
var _mats_o: Array = []
var _turno_o: int = 0
var _cola_imp: Array = []               ## [Vector4(u, v, altura, radio_u)] por aplicar: como mucho 8 por paso
var _cascadas: Array = []               ## por cada caída: {pos: arista (Vector3, y = media), abajo: Vector3 pie, dir: Vector2, caida: float}
var _cortinas: MultiMeshInstance3D = null
var _mat_cortina: ShaderMaterial = null
var _salpicadura: CPUParticles3D = null
var _rng := RandomNumberGenerator.new()


## Engancha la capa a una simulación. Se puede volver a llamar con otra (rehace todo).
func enlazar(p_sim: AguaSim3D) -> void:
	_limpiar()
	sim = p_sim
	if sim == null or sim.w <= 0 or sim.h <= 0:
		return
	_fw = sim.w * escala
	_fh = sim.h * escala
	var estado_cod: String = CODIGO_ESTADO.replace("//@MUESTRA", MUESTRA)
	for i in range(2):
		var vp := SubViewport.new()
		vp.size = Vector2i(_fw, _fh)
		vp.disable_3d = true
		vp.transparent_bg = false
		vp.use_hdr_2d = true                       # RGBA16F sin recortar a 0–1 y en lineal; con el renderizador Mobile sería RGB10_A2 y no valdría (error negativo)
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		add_child(vp)
		var rect := ColorRect.new()
		rect.size = Vector2(_fw, _fh)
		var sh := Shader.new()
		sh.code = estado_cod
		var m := ShaderMaterial.new()
		m.shader = sh
		rect.material = m
		vp.add_child(rect)
		_vps.append(vp)
		_mats.append(m)
		RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	(_mats[0] as ShaderMaterial).set_shader_parameter("previo", (_vps[1] as SubViewport).get_texture())
	(_mats[1] as ShaderMaterial).set_shader_parameter("previo", (_vps[0] as SubViewport).get_texture())
	_montar_ondas()
	_montar_superficie()
	_montar_cascadas()
	_leer(true)
	for m in _mats:
		_parametros_comunes(m as ShaderMaterial)


func _limpiar() -> void:
	for n in _vps:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_vps.clear()
	_mats.clear()
	if _superficie != null and is_instance_valid(_superficie):
		_superficie.queue_free()
	_superficie = null
	_mat_sup = null
	for n in [_cortinas, _salpicadura]:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	_cortinas = null
	_salpicadura = null
	for n in _vps_o:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_vps_o.clear()
	_mats_o.clear()
	_mat_cortina = null
	_cascadas.clear()
	_cola_imp.clear()
	_tex_caida = null
	_tex_eventos = null
	_tex_a = null
	_tex_b = null
	_tex_pa = null
	_tex_pb = null
	_img_a = null
	_img_b = null
	_pasos = 0


func _parametros_comunes(m: ShaderMaterial) -> void:
	m.set_shader_parameter("sim_a", _tex_a)
	m.set_shader_parameter("sim_b", _tex_b)
	m.set_shader_parameter("sim_dim", Vector2(sim.w, sim.h))
	m.set_shader_parameter("lado", sim.l)
	m.set_shader_parameter("minima", profundidad_minima)
	for mo in _mats_o:
		(mo as ShaderMaterial).set_shader_parameter("sim_dim", Vector2(sim.w, sim.h))
		(mo as ShaderMaterial).set_shader_parameter("lado", sim.l)
		(mo as ShaderMaterial).set_shader_parameter("minima", profundidad_minima)


func _montar_superficie() -> void:
	var sh := Shader.new()
	sh.code = CODIGO_SUPERFICIE.replace("//@MUESTRA", MUESTRA)
	_mat_sup = ShaderMaterial.new()
	_mat_sup.shader = sh
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = 0.06
	var nt := NoiseTexture2D.new()
	nt.noise = nz
	nt.width = 128
	nt.height = 128
	nt.seamless = true
	_mat_sup.set_shader_parameter("ruido", nt)
	_mat_sup.set_shader_parameter("fino_dim", Vector2(_fw, _fh))
	if textura_hielo == null:
		textura_hielo = _textura_hielo_de_bloque()
	if textura_hielo != null:
		_mat_sup.set_shader_parameter("tex_hielo", textura_hielo)
	_mat_sup.set_shader_parameter("mezcla_tex_hielo", mezcla_textura_hielo if textura_hielo != null else 0.0)
	_mat_sup.set_shader_parameter("escala_tex_hielo", escala_textura_hielo)
	_mat_sup.set_shader_parameter("escala", float(escala))
	_superficie = MeshInstance3D.new()
	_superficie.mesh = _malla()
	_superficie.material_override = _mat_sup
	_superficie.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_superficie)


## La textura del bloque de hielo 3D de la maqueta (mismo proceso que `prueba_test2._textura_hielo`: la del agua, desaturada y aclarada), o `hielo_arriba.png` si existe.
func _textura_hielo_de_bloque() -> Texture2D:
	if ResourceLoader.exists(RUTA_HIELO):
		return load(RUTA_HIELO) as Texture2D
	if not ResourceLoader.exists(RUTA_AGUA):
		return null
	var agua := load(RUTA_AGUA) as Texture2D
	var img: Image = agua.get_image() if agua != null else null
	if img == null:
		return agua
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(256, 256)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c: Color = img.get_pixel(x, y)
			var g: float = c.get_luminance()
			img.set_pixel(x, y, Color(lerpf(c.r, g, 0.75), lerpf(c.g, g, 0.7), lerpf(c.b, g, 0.55)).lightened(0.35))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Enciende o apaga la textura del hielo (apagada = el hielo procedural de antes) para compararlas en el laboratorio.
func usar_textura_hielo(si: bool) -> void:
	if _mat_sup != null:
		_mat_sup.set_shader_parameter("mezcla_tex_hielo", mezcla_textura_hielo if si and textura_hielo != null else 0.0)


## W2 · El campo de ondas: otro ping-pong de dos SubViewports, con el mismo tamaño que el estado.
func _montar_ondas() -> void:
	var cod: String = CODIGO_ONDAS
	for i in range(2):
		var vp := SubViewport.new()
		vp.size = Vector2i(_fw, _fh)
		vp.disable_3d = true
		vp.transparent_bg = false
		vp.use_hdr_2d = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		add_child(vp)
		var rect := ColorRect.new()
		rect.size = Vector2(_fw, _fh)
		var sh := Shader.new()
		sh.code = cod
		var m := ShaderMaterial.new()
		m.shader = sh
		rect.material = m
		vp.add_child(rect)
		_vps_o.append(vp)
		_mats_o.append(m)
		RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	(_mats_o[0] as ShaderMaterial).set_shader_parameter("previo", (_vps_o[1] as SubViewport).get_texture())
	(_mats_o[1] as ShaderMaterial).set_shader_parameter("previo", (_vps_o[0] as SubViewport).get_texture())


## W2 · La cortina de las cascadas (un MultiMesh de cuadrados) y su salpicadura (una sola fuente de partículas con los pies de todas las cascadas como puntos de emisión).
func _montar_cascadas() -> void:
	_mat_cortina = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CODIGO_CORTINA
	_mat_cortina.shader = sh
	_mat_cortina.set_shader_parameter("ruido", _mat_sup.get_shader_parameter("ruido"))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _mat_cortina
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = maxi(max_cascadas, 1)
	mm.visible_instance_count = 0
	_cortinas = MultiMeshInstance3D.new()
	_cortinas.multimesh = mm
	_cortinas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cortinas.custom_aabb = AABB(Vector3(0.0, -20.0, 0.0), Vector3(sim.w * sim.l, 60.0, sim.h * sim.l))
	add_child(_cortinas)
	# Gotas: quads que miran a la cámara, blancos y azulados, que salen hacia arriba y hacia los lados del pie y caen con la gravedad.
	var gota := QuadMesh.new()
	gota.size = Vector2(0.12, 0.12)
	var mg := StandardMaterial3D.new()
	mg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mg.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mg.vertex_color_use_as_albedo = true
	mg.albedo_color = Color(0.93, 0.98, 1.0)
	gota.material = mg
	_salpicadura = CPUParticles3D.new()
	_salpicadura.mesh = gota
	_salpicadura.amount = maxi(particulas_salpicadura, 8)
	_salpicadura.lifetime = 0.8
	_salpicadura.local_coords = false
	_salpicadura.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	_salpicadura.emission_points = PackedVector3Array([Vector3.ZERO])
	_salpicadura.direction = Vector3.UP
	_salpicadura.spread = 65.0
	_salpicadura.initial_velocity_min = 1.0
	_salpicadura.initial_velocity_max = 2.6
	_salpicadura.gravity = Vector3(0.0, -7.0, 0.0)
	_salpicadura.scale_amount_min = 0.5
	_salpicadura.scale_amount_max = 1.3
	var rampa := Gradient.new()
	rampa.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
	rampa.set_color(1, Color(0.8, 0.93, 1.0, 0.0))
	_salpicadura.color_ramp = rampa
	_salpicadura.emitting = false
	add_child(_salpicadura)


## Rejilla con un vértice por texel de la capa (escala × escala por trocito). La altura la pone el sombreado, así que la caja de recorte es ancha.
func _malla() -> ArrayMesh:
	var paso: float = sim.l / float(escala)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(_fw * _fh)
	uvs.resize(_fw * _fh)
	for y in range(_fh):
		for x in range(_fw):
			var i: int = y * _fw + x
			verts[i] = Vector3((x + 0.5) * paso, 0.0, (y + 0.5) * paso)
			uvs[i] = Vector2((x + 0.5) / float(_fw), (y + 0.5) / float(_fh))
	var idx := PackedInt32Array()
	idx.resize((_fw - 1) * (_fh - 1) * 6)
	var k: int = 0
	for y in range(_fh - 1):
		for x in range(_fw - 1):
			var a: int = y * _fw + x
			var b: int = a + 1
			var c: int = a + _fw
			var d: int = c + 1
			idx[k] = a; idx[k + 1] = c; idx[k + 2] = b
			idx[k + 3] = b; idx[k + 4] = c; idx[k + 5] = d
			k += 6
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.custom_aabb = AABB(Vector3(0.0, -20.0, 0.0), Vector3(sim.w * sim.l, 60.0, sim.h * sim.l))
	return m


func _process(delta: float) -> void:
	if sim == null or _vps.is_empty():
		return
	_reloj += delta
	_intervalo = 1.0 / maxf(hz_lectura, 1.0)
	_desde += delta
	var leida: bool = false
	if _desde >= _intervalo:
		_leer(false)
		_desde = 0.0
		leida = true
	var mezcla: float = clampf(_desde / _intervalo, 0.0, 1.0)
	var vp: SubViewport = _vps[_turno]
	var m: ShaderMaterial = _mats[_turno]
	m.set_shader_parameter("mezcla", mezcla)
	# El objetivo del paso anterior, EXACTO: con el par de antes de la lectura si acaba de haberla, con el mismo par si no.
	m.set_shader_parameter("sim_pa", _tex_pa if leida else _tex_a)
	m.set_shader_parameter("sim_pb", _tex_pb if leida else _tex_b)
	m.set_shader_parameter("mezcla_previa", _mezcla_prev)
	m.set_shader_parameter("dt", minf(delta, 0.05))
	m.set_shader_parameter("rigidez", rigidez)
	m.set_shader_parameter("amortiguacion", amortiguacion)
	m.set_shader_parameter("vida_espuma", vida_espuma)
	m.set_shader_parameter("ganancia_eventos", 1.0 if _eventos_en_este_paso else 0.0)
	_eventos_en_este_paso = false
	var imp: Array = []
	var n_imp: int = mini(_cola_imp.size(), 8)
	for k in range(8):
		if k < n_imp:
			var q: Vector4 = _cola_imp[k]
			imp.append(Vector4(q.x, q.y, q.z, q.w))
		else:
			imp.append(Vector4(0.0, 0.0, 0.0, 0.001))
	m.set_shader_parameter("imp", imp)
	m.set_shader_parameter("n_imp", n_imp)
	_cola_imp = _cola_imp.slice(n_imp)
	# Campo de ondas: una pasada por fotograma con los mismos impulsos.
	var vpo: SubViewport = _vps_o[_turno_o]
	var mo: ShaderMaterial = _mats_o[_turno_o]
	mo.set_shader_parameter("dt", minf(delta, 0.05))
	mo.set_shader_parameter("c2", velocidad_ondas * velocidad_ondas)
	mo.set_shader_parameter("amort", amortiguacion_ondas)
	mo.set_shader_parameter("imp", imp)
	mo.set_shader_parameter("n_imp", n_imp)
	vpo.render_target_update_mode = SubViewport.UPDATE_ONCE
	_mat_sup.set_shader_parameter("ondas", vpo.get_texture())
	_turno_o = 1 - _turno_o
	_mezcla_prev = mezcla
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_mat_sup.set_shader_parameter("estado", vp.get_texture())
	_mat_sup.set_shader_parameter("mezcla", mezcla)
	_mat_sup.set_shader_parameter("reloj", _reloj)
	_mat_sup.set_shader_parameter("ruido_orilla", ruido_orilla)
	if _mat_cortina != null:
		_mat_cortina.set_shader_parameter("reloj", _reloj)
	_ms_gpu = lerpf(_ms_gpu, RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid()), 0.1)
	_turno = 1 - _turno
	_pasos += 1


## Lee la simulación como AguaRender3D: la lectura anterior pasa a `sim_a` y la nueva a `sim_b`; también la caída y los eventos (que consume).
func _leer(primera: bool) -> void:
	var t0: int = Time.get_ticks_usec()
	var img: Image = sim.imagen()
	if _tex_b == null or primera or _tex_b.get_width() != img.get_width() or _tex_b.get_height() != img.get_height():
		_tex_a = ImageTexture.create_from_image(img)
		_tex_b = ImageTexture.create_from_image(img)
		_tex_pa = ImageTexture.create_from_image(img)
		_tex_pb = ImageTexture.create_from_image(img)
		_img_a = img
	else:
		_tex_pa.update(_img_a)
		_tex_pb.update(_img_b)
		_tex_a.update(_img_b)
		_tex_b.update(img)
		_img_a = _img_b
	_img_b = img
	# La caída y los eventos se piden como imagen (no como textura de la simulación) porque aquí además se leen en la CPU: así se piden UNA vez.
	var img_caida: Image = sim.imagen_caida()
	if _tex_caida == null or _tex_caida.get_width() != img_caida.get_width() or _tex_caida.get_height() != img_caida.get_height():
		_tex_caida = ImageTexture.create_from_image(img_caida)
	else:
		_tex_caida.update(img_caida)
	var img_ev: Image = sim.imagen_eventos(true)
	if _tex_eventos == null or _tex_eventos.get_width() != img_ev.get_width() or _tex_eventos.get_height() != img_ev.get_height():
		_tex_eventos = ImageTexture.create_from_image(img_ev)
	else:
		_tex_eventos.update(img_ev)
	var tex_hielo: ImageTexture = sim.textura_hielo()
	for m in _mats:
		(m as ShaderMaterial).set_shader_parameter("sim_a", _tex_a)
		(m as ShaderMaterial).set_shader_parameter("sim_b", _tex_b)
		(m as ShaderMaterial).set_shader_parameter("caida", _tex_caida)
		(m as ShaderMaterial).set_shader_parameter("umbral_caida", AguaSim3D.UMBRAL_CAIDA)
	if _mat_sup != null:
		_mat_sup.set_shader_parameter("sim_a", _tex_a)
		_mat_sup.set_shader_parameter("sim_b", _tex_b)
		_mat_sup.set_shader_parameter("sim_dim", Vector2(sim.w, sim.h))
		_mat_sup.set_shader_parameter("lado", sim.l)
		_mat_sup.set_shader_parameter("minima", profundidad_minima)
	for m in _mats:
		(m as ShaderMaterial).set_shader_parameter("eventos", _tex_eventos)
		(m as ShaderMaterial).set_shader_parameter("hielo", tex_hielo)
	for mo in _mats_o:
		(mo as ShaderMaterial).set_shader_parameter("sim_b", _tex_b)
		(mo as ShaderMaterial).set_shader_parameter("hielo", tex_hielo)
	if _mat_sup != null:
		_mat_sup.set_shader_parameter("hielo", tex_hielo)
	_eventos_en_este_paso = true
	_explorar(img, img_caida, img_ev)
	_ms_lectura = lerpf(_ms_lectura, float(Time.get_ticks_usec() - t0) / 1000.0, 0.2)


## W2 · Una onda desde la CPU (un paso, un hechizo que cae, un objeto que flota): `altura` en u (con signo: negativa = el agua se hunde y rebota), `radio` en u.
## Como AguaOndas3D.impulso, pero sobre ESTA capa: se ve en la altura y en la normal de la superficie y deja un poco de espuma.
func impulso(pos: Vector3, fuerza: float, radio: float) -> void:
	if sim == null:
		return
	var uv := Vector2(pos.x / (sim.w * sim.l), pos.z / (sim.h * sim.l))
	if uv.x < -0.05 or uv.y < -0.05 or uv.x > 1.05 or uv.y > 1.05:
		return
	if _cola_imp.size() >= MAX_COLA_IMPULSOS:
		_cola_imp.pop_front()
	_cola_imp.append(Vector4(uv.x, uv.y, fuerza, maxf(radio, 0.05)))


## Cuántas cascadas hay dibujadas ahora (para la prueba y el laboratorio).
func cascadas() -> int:
	return _cascadas.size()


## Cuántos puntos de salpicadura tiene encendidos (uno por cascada).
func salpicaduras_activas() -> int:
	return _salpicadura.emission_points.size() if _salpicadura != null and _salpicadura.emitting else 0


## W2 · Recorre SOLO la caja de trabajo de la simulación (con un trocito de margen) una vez por lectura: de las caídas ≥ UMBRAL_CAIDA saca las cortinas, los pies
## de salpicadura y unas ondas suaves en el pie; de los eventos (entra agua, se rompe hielo, se evapora) saca el impulso de onda de cada uno.
func _explorar(img: Image, caida: Image, ev: Image) -> void:
	_cascadas.clear()
	var caja: Rect2i = sim.caja_trabajo()
	if caja.size.x > 0 and caja.size.y > 0:
		var x0: int = maxi(0, caja.position.x - 1)
		var y0: int = maxi(0, caja.position.y - 1)
		var x1: int = mini(sim.w - 1, caja.end.x)
		var y1: int = mini(sim.h - 1, caja.end.y)
		var d_s: PackedFloat32Array = img.get_data().to_float32_array()      # RGBAF: 4 floats por trocito (R = Y de la superficie)
		var d_c: PackedFloat32Array = caida.get_data().to_float32_array()    # RF
		var d_e: PackedByteArray = ev.get_data()                              # RG8: tipo, intensidad
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var i: int = y * sim.w + x
				var tipo: int = d_e[i * 2]
				if tipo != 0:
					_impulso_de_evento(x, y, tipo, float(d_e[i * 2 + 1]) / 255.0, d_s[i * 4])
				if d_c[i] < AguaSim3D.UMBRAL_CAIDA or _cascadas.size() >= max_cascadas:
					continue
				var sup: float = d_s[i * 4]
				var mejor: int = -1
				var salto: float = 0.0
				for k in range(4):
					var nx: int = x + int(DX[k])
					var ny: int = y + int(DZ[k])
					if nx < 0 or ny < 0 or nx >= sim.w or ny >= sim.h:
						continue
					var dr: float = sup - d_s[(ny * sim.w + nx) * 4]
					if dr > salto:
						salto = dr
						mejor = k
				if mejor < 0 or salto < AguaSim3D.UMBRAL_CAIDA * 0.8:
					continue
				var dir := Vector2(float(DX[mejor]), float(DZ[mejor]))
				var arista := Vector3((x + 0.5 + dir.x * 0.5) * sim.l, sup - salto * 0.5, (y + 0.5 + dir.y * 0.5) * sim.l)
				var pie := Vector3(arista.x + dir.x * sim.l * 0.3, sup - salto, arista.z + dir.y * sim.l * 0.3)
				_cascadas.append({"pos": arista, "pie": pie, "dir": dir, "caida": salto})
	_actualizar_cascadas()


## Lo que hace cada tipo de evento a la superficie: el agua que entra la hunde y rebota; el hielo que se suelta la levanta; el fuego casi no la mueve.
func _impulso_de_evento(x: int, y: int, tipo: int, intensidad: float, y_sup: float) -> void:
	var pos := Vector3((x + 0.5) * sim.l, y_sup, (y + 0.5) * sim.l)
	match tipo:
		AguaSim3D.EVENTO_ENTRA:
			impulso(pos, -0.10 * clampf(intensidad, 0.3, 2.0), sim.l * 0.6)
		AguaSim3D.EVENTO_HIELO_ROTO:
			impulso(pos, 0.12, sim.l * 0.7)
		AguaSim3D.EVENTO_EVAPORA:
			impulso(pos, -0.03, sim.l * 0.5)


## Pone las cortinas y los puntos de salpicadura de `_cascadas` y siembra ondas en cada pie (sin pasarse: 1-2 por lectura y cascada).
func _actualizar_cascadas() -> void:
	if _cortinas == null:
		return
	var mm: MultiMesh = _cortinas.multimesh
	mm.visible_instance_count = mini(_cascadas.size(), mm.instance_count)
	var puntos := PackedVector3Array()
	for k in range(mm.visible_instance_count):
		var c: Dictionary = _cascadas[k]
		var dir: Vector2 = c["dir"]
		var eje_x := Vector3(-dir.y, 0.0, dir.x) * sim.l
		var eje_y := Vector3(0.0, maxf(float(c["caida"]), 0.05), 0.0)
		var eje_z := Vector3(dir.x, 0.0, dir.y) * 0.05
		mm.set_instance_transform(k, Transform3D(Basis(eje_x, eje_y, eje_z), c["pos"]))
		puntos.append(c["pie"])
		if _rng.randf() < 0.6:
			impulso(c["pie"], -_rng.randf_range(0.02, 0.07), sim.l * 0.4)
	if puntos.is_empty():
		_salpicadura.emitting = false
	else:
		_salpicadura.emission_points = puntos
		_salpicadura.emitting = true


## Lo que tarda en la GPU la pasada de estado (ms, media móvil; 0 si el motor no sabe medirlo).
func milisegundos_gpu() -> float:
	return _ms_gpu


## Lo que cuesta en CPU leer la simulación y subirla (ms, media móvil).
func milisegundos_lectura() -> float:
	return _ms_lectura


func pasos() -> int:
	return _pasos


## Texturas por lado de la capa (para la prueba y la captura).
func dimension_fina() -> Vector2i:
	return Vector2i(_fw, _fh)


## El estado de la última pasada (R error de altura, G velocidad, B espuma): una imagen de la GPU, solo con ventana.
func imagen_estado() -> Image:
	if _vps.is_empty():
		return null
	var ultimo: SubViewport = _vps[1 - _turno]
	return ultimo.get_texture().get_image()


## W2 · El campo de ondas de la última pasada (R altura en u, G velocidad): una imagen de la GPU, solo con ventana.
func imagen_ondas() -> Image:
	if _vps_o.is_empty():
		return null
	return (_vps_o[1 - _turno_o] as SubViewport).get_texture().get_image()


func superficie() -> MeshInstance3D:
	return _superficie
