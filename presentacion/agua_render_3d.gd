extends MeshInstance3D
class_name AguaRender3D
## DIBUJO DEL AGUA DESDE LA SIMULACIÓN (Fase 11.7, 12/10). Lo escribe el Pipeline; la simulación (AguaSim3D) es del Juego.
##
## Qué hace: lee `AguaSim3D.imagen()` (un texel por trocito de suelo: R = Y de la superficie, G = profundidad, B/A = corriente
## en u/s) y dibuja el agua como una malla de rejilla con UN VÉRTICE POR CENTRO DE TROCITO. Así se VE llenarse (los vértices
## suben con la superficie), rebosar y nivelarse, y el borde del agua sigue la orilla real de la simulación, no una letra.
##
## Por qué una rejilla y no el plano de antes: el plano de CODIGO_AGUA era un bloque por casilla «~» con la superficie fija;
## aquí la superficie la manda la simulación, trocito a trocito (0,77 u), y la profundidad y la corriente llegan al sombreado.
##
## Aspecto: el estilizado que aprobó Pablo (13/10 (8)): facetas planas que se inclinan, dos tonos en bandas por la
## profundidad, espuma nítida en la orilla y manchas de espuma de dos ruidos. Añade lo que la simulación sabe y la letra no:
## franjas que corren hacia donde va el agua de verdad (flow map de dos fases) y espuma donde la corriente es fuerte.
##
## Uso:
##   var r := AguaRender3D.new(); add_child(r); r.enlazar(sim)      # sim: AguaSim3D
## Se actualiza solo (`hz_actualizacion` veces por segundo, no cada fotograma: el agua no cambia tan deprisa, y el
## sombreado interpola entre dos actualizaciones para que no se vea a saltos).
## `fuente_ondas(textura, origen_xz, lado)` enchufa las ondas de AguaOndas3D (11.8; mejor `ondas.conectar(render)`); sin ellas, el agua queda lisa.
##
## HIELO (11.14, 12/10): si la simulación tiene `textura_hielo()` (RG8: R = 1 helado, G = lo que le queda, 0-1; mismo origen y texel
## que `imagen()`), los trocitos helados se pintan como hielo: blanco azulado y opaco, en facetas con grietas, un poco más alto que el
## agua y sin franjas, espuma ni ondas. Al helarse CRECE desde el punto del impacto en ~0,3 s; al derretirse se deshace en ~0,3 s;
## con G < 0,15 se abren grietas y se oscurece (avisa de que se va a romper). El tiempo de cada trocito (cuándo se heló, cuándo se
## soltó) se guarda aquí, en una textura propia, porque la simulación solo dice «helado sí/no». El punto del impacto se deduce del
## centro de lo que se heló de golpe; si el Juego quiere dar el exacto, llama a `hielo_desde(pos)` justo antes de helar.

## Veces por segundo que se lee la simulación (el contrato del Juego pide 10–15).
@export var hz_actualizacion: float = 12.0
## Debajo de esta profundidad (u) un trocito es lámina de suelo mojado, no agua que se vea como tal (contrato: ~0,05).
@export var profundidad_minima: float = 0.05

const CODIGO: String = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D datos_a : filter_nearest, repeat_disable;     // lectura anterior de la simulación (R altura, G prof, BA corriente)
uniform sampler2D datos_b : filter_nearest, repeat_disable;     // lectura última
uniform float mezcla = 1.0;                                     // 0 = a, 1 = b (interpola entre dos lecturas)
uniform float minima = 0.05;

uniform vec3 color_somero_est : source_color = vec3(0.44, 0.80, 0.91);
uniform vec3 color_hondo_est : source_color = vec3(0.20, 0.52, 0.80);
uniform vec3 color_espuma : source_color = vec3(0.96, 0.99, 1.0);
uniform float hondura = 1.5;                  // cuánto tarda el color en pasar de somero a hondo (más = antes)
uniform float bandas = 3.0;                   // escalones entre somero y hondo
uniform float faceta = 0.75;                  // lado de los triángulos de las olas (u)
uniform float altura_ola = 0.32;
uniform float contraste_faceta = 0.2;
uniform float espuma_manchas = 0.5;
uniform float transicion_orilla = 0.08;       // profundidad (u) en la que la espuma de la orilla se funde con el agua
uniform float vel_espuma = 1.1;               // desde esta corriente (u/s) rompe en espuma
uniform float tam_franja = 0.8;               // tamaño de las franjas de la corriente (u)
uniform float vel_franja = 0.55;              // ciclos por segundo del flow map
uniform float brillo = 1.0;
uniform float contraste = 1.2;
uniform vec3 sombra_tinte : source_color = vec3(0.34, 0.36, 0.46);

// Ondas que reaccionan (11.8): textura de AguaOndas3D, R = altura (u). La pendiente y las crestas salen de ella. Sin ella, quedan a cero.
uniform sampler2D ondas : filter_linear, hint_default_black, repeat_disable;
uniform vec3 ondas_rect = vec3(0.0, 0.0, 1.0);   // x0, z0 y lado (u) de la zona que cubre la textura
uniform float ondas_fuerza = 0.0;                // 0 = sin ondas

// Hielo (11.14): hielo_t por trocito, RGF: R = segundo en que empezó a helarse, G = segundo en que empezó a soltarse (solo cambia al helar o soltar).
// hielo_g es la textura_hielo() tal cual (RG8): su G = lo que le queda al hielo (0-1), que baja sola con el tiempo.
uniform sampler2D hielo_t : filter_nearest, hint_default_black, repeat_disable;
uniform sampler2D hielo_g : filter_nearest, hint_default_white, repeat_disable;
uniform float hielo_activo = 0.0;
uniform float reloj = 0.0;                    // segundos propios del dibujo (los de hielo_t van con este reloj)
uniform float lado_trocito = 0.7667;
uniform float alto_hielo = 0.07;              // cuánto sobresale el hielo del agua (u)
uniform float crece_s = 0.1;                  // lo que tarda un trocito en pasar de agua a hielo una vez le toca
uniform float funde_s = 0.2;                  // y en deshacerse una vez le toca (cada trocito con un retraso al azar de hasta 0,12 s)
uniform float aviso_umbral = 0.15;            // por debajo de este G aparecen las grietas grandes
uniform vec3 color_hielo_claro : source_color = vec3(0.70, 0.84, 0.96);
uniform vec3 color_hielo_hondo : source_color = vec3(0.46, 0.66, 0.88);
uniform vec3 color_grieta : source_color = vec3(0.30, 0.50, 0.76);
uniform float tam_faceta_hielo = 1.3;         // tamaño de las facetas del hielo (u)

varying float v_prof;
varying vec2 v_corr;
varying vec3 v_pos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Cuánto hielo hay en un trocito ahora (0-1): crece desde su segundo de inicio y se deshace desde el de fin, cada uno con un retraso propio.
float hielo_f(ivec2 p) {
	ivec2 s = textureSize(hielo_t, 0);
	p = clamp(p, ivec2(0), s - 1);
	vec4 h = texelFetch(hielo_t, p, 0);
	float crece = clamp((reloj - h.r) / crece_s, 0.0, 1.0);
	float funde = clamp((reloj - h.g - hash(vec2(p) * 0.37) * 0.12) / funde_s, 0.0, 1.0);
	return crece * (1.0 - funde);
}

// (hielo, aviso) en un punto del mundo: bilineal entre los cuatro trocitos de alrededor.
vec2 hielo_ab(vec2 xz) {
	vec2 tp = xz / lado_trocito - 0.5;
	ivec2 i0 = ivec2(floor(tp));
	vec2 f = fract(tp);
	ivec2 s = textureSize(hielo_t, 0);
	float h00 = hielo_f(i0);
	float h10 = hielo_f(i0 + ivec2(1, 0));
	float h01 = hielo_f(i0 + ivec2(0, 1));
	float h11 = hielo_f(i0 + ivec2(1, 1));
	float a00 = texelFetch(hielo_g, clamp(i0, ivec2(0), s - 1), 0).g;
	float a10 = texelFetch(hielo_g, clamp(i0 + ivec2(1, 0), ivec2(0), s - 1), 0).g;
	float a01 = texelFetch(hielo_g, clamp(i0 + ivec2(0, 1), ivec2(0), s - 1), 0).g;
	float a11 = texelFetch(hielo_g, clamp(i0 + ivec2(1, 1), ivec2(0), s - 1), 0).g;
	// El aviso se pondera por cuánto hielo hay en cada trocito (un trocito sin hielo no debe contagiar su G).
	float w00 = (1.0 - f.x) * (1.0 - f.y) * h00;
	float w10 = f.x * (1.0 - f.y) * h10;
	float w01 = (1.0 - f.x) * f.y * h01;
	float w11 = f.x * f.y * h11;
	float sw = w00 + w10 + w01 + w11;
	float hielo = sw;
	float g = sw > 0.0001 ? (w00 * a00 + w10 * a10 + w01 * a01 + w11 * a11) / sw : 1.0;
	return vec2(hielo, 1.0 - smoothstep(0.0, aviso_umbral, g));
}

vec4 dato(ivec2 p) {
	ivec2 s = textureSize(datos_a, 0);
	p = clamp(p, ivec2(0), s - 1);
	return mix(texelFetch(datos_a, p, 0), texelFetch(datos_b, p, 0), mezcla);
}

void vertex() {
	ivec2 s = textureSize(datos_a, 0);
	ivec2 p = ivec2(floor(UV * vec2(s)));
	vec4 d = dato(p);
	float y = d.r;
	float prof = d.g;
	vec2 corr = d.ba;
	if (d.g < minima) {
		// Trocito seco: baja el vértice a la altura del agua vecina (si no, la orilla de tierra más alta lo levantaría y
		// el borde saldría torcido) y su profundidad pasa a NEGATIVA: así el borde del agua cae en medio, entre el último
		// trocito mojado y el primero seco, en vez de pegarse al centro del seco.
		float mejor = -1.0;
		float hs = 0.0;
		vec2 cs = vec2(0.0);
		ivec2 dirs[4] = ivec2[4](ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1));
		for (int k = 0; k < 4; k++) {
			vec4 n = dato(p + dirs[k]);
			if (n.g >= minima && n.g > mejor) {
				mejor = n.g;
				hs = n.r;
				cs = n.ba;
			}
		}
		if (mejor > 0.0) {
			y = min(d.r, hs);
			prof = -mejor;
			corr = cs;
		} else {
			prof = -1.0;
		}
	}
	if (hielo_activo > 0.5) {
		y += alto_hielo * hielo_f(p);                  // el hielo sobresale un poco: se ve una losa, no una mancha
	}
	VERTEX.y = y;
	v_prof = prof;
	v_corr = corr;
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float ola_est(vec2 p, float t) {
	return sin(p.x * 1.9 + t * 1.1) * 0.5 + sin(p.y * 2.3 - t * 0.9) * 0.35 + sin((p.x + p.y) * 1.3 + t * 0.7) * 0.25;
}

// Normal plana del triángulo de la rejilla de olas en el que cae `p` (la misma rejilla girada y sesgada del agua estilizada
// de antes: triángulos casi equiláteros, sin cuadros alineados con las casillas).
const mat2 GIRO_FACETA = mat2(vec2(0.90, 0.43), vec2(-0.43, 0.90));
const mat2 SESGO_FACETA = mat2(vec2(1.0, 0.0), vec2(-0.577, 1.155));
vec3 normal_faceta(vec2 p, float t) {
	vec2 g = SESGO_FACETA * (GIRO_FACETA * p) / faceta;
	vec2 b = floor(g);
	vec2 f = fract(g);
	vec2 a1 = f.x > f.y ? b + vec2(1.0, 0.0) : b + vec2(1.0, 1.0);
	vec2 a2 = f.x > f.y ? b + vec2(1.0, 1.0) : b + vec2(0.0, 1.0);
	vec3 v0 = vec3(b.x, ola_est(b * faceta, t) * altura_ola / faceta, b.y);
	vec3 v1 = vec3(a1.x, ola_est(a1 * faceta, t) * altura_ola / faceta, a1.y);
	vec3 v2 = vec3(a2.x, ola_est(a2 * faceta, t) * altura_ola / faceta, a2.y);
	vec3 n = normalize(cross(v2 - v0, v1 - v0));
	return n.y < 0.0 ? -n : n;
}

// Celdas de Voronoi: x = distancia al centro de la celda más cercana, y = distancia a la arista (F2 - F1), z = número al azar de la celda.
vec3 celdas(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 9.0;
	float d2 = 9.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 17.3));
			float d = length(g + o * 0.85 + 0.075 - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = hash(i + g + 5.7);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(d1, d2 - d1, id);
}

// Franjas alargadas en el sentido de la corriente: ruido estirado a lo largo de `dir`.
float franja(vec2 uv, vec2 dir) {
	vec2 per = vec2(-dir.y, dir.x);
	float a = dot(uv, dir);
	float b = dot(uv, per);
	return ruido(vec2(a * 0.45, b * 3.2));
}

void fragment() {
	if (v_prof < 0.0) {
		discard;                       // fuera del agua: el borde sigue la orilla de la simulación
	}
	vec3 pm = v_pos;
	vec2 corr = v_corr;
	float vel = length(corr);

	// Hielo (11.14): cuánto hay aquí y cuánto avisa de que se rompe. El borde es irregular (ruido) y suave (smoothstep).
	float hielo = 0.0;
	float aviso = 0.0;
	if (hielo_activo > 0.5) {
		vec2 ha = hielo_ab(pm.xz);
		hielo = smoothstep(0.36, 0.64, ha.x + (ruido(pm.xz * 2.6) - 0.5) * 0.32);
		aviso = ha.y;
	}

	// Inclinación real de la superficie (una caída o una pendiente) + olas en facetas planas.
	vec3 gn = normalize(cross(dFdx(pm), dFdy(pm)));
	if (gn.y < 0.0) {
		gn = -gn;
	}
	vec3 nm = normal_faceta(pm.xz, TIME);
	nm = normalize(nm + (gn - vec3(0.0, 1.0, 0.0)) * 2.0);
	// Ondas que reaccionan: su pendiente se suma a la normal.
	float cresta = 0.0;
	if (ondas_fuerza > 0.0) {
		vec2 uvo = (pm.xz - ondas_rect.xy) / ondas_rect.z;
		if (uvo.x > 0.0 && uvo.y > 0.0 && uvo.x < 1.0 && uvo.y < 1.0) {
			// La textura guarda solo la altura (R); la pendiente sale de las diferencias con los vecinos (texel = lado / tamaño).
			vec2 px = 1.0 / vec2(textureSize(ondas, 0));
			float h0 = texture(ondas, uvo).r;
			float dx = texture(ondas, uvo + vec2(px.x, 0.0)).r - texture(ondas, uvo - vec2(px.x, 0.0)).r;
			float dz = texture(ondas, uvo + vec2(0.0, px.y)).r - texture(ondas, uvo - vec2(0.0, px.y)).r;
			vec2 pend = vec2(dx, dz) / (2.0 * ondas_rect.z * px.x);
			nm = normalize(nm + vec3(-pend.x, 0.0, -pend.y) * ondas_fuerza * (1.0 - hielo));   // el hielo no se ondula
			cresta = clamp(abs(h0) * ondas_fuerza * 3.0 - 0.3, 0.0, 1.0) * (1.0 - hielo);
		}
	}

	// Color: somero -> hondo por la profundidad, en bandas.
	float hondo = 1.0 - exp(-v_prof * hondura);
	float hondo_b = floor(hondo * bandas + 0.5) / bandas;
	vec3 ce = mix(color_somero_est, color_hondo_est, hondo_b);
	float lf = clamp(dot(nm, normalize(vec3(0.45, 1.0, 0.3))), 0.0, 1.0);
	ce *= 1.0 - contraste_faceta + contraste_faceta * 1.3 * smoothstep(0.7, 1.0, lf);

	// Franjas que corren con la corriente (flow map de dos fases desfasadas medio ciclo y mezcladas).
	vec2 uv = pm.xz / tam_franja;
	float efecto_flujo = smoothstep(0.04, 0.3, vel);
	vec2 dir = vel > 0.001 ? corr / vel : vec2(1.0, 0.0);
	float fase0 = fract(TIME * vel_franja);
	float fase1 = fract(TIME * vel_franja + 0.5);
	float peso0 = 1.0 - abs(2.0 * fase0 - 1.0);
	float avance = clamp(vel, 0.0, 2.0) * 0.9;
	float fr = franja(uv - dir * avance * fase0 / tam_franja, dir) * peso0
			+ franja(uv + 0.37 - dir * avance * fase1 / tam_franja, dir) * (1.0 - peso0);
	float franjas = smoothstep(0.62, 0.70, fr) * efecto_flujo;
	ce = mix(ce, color_espuma, franjas * 0.32);

	// Espuma: manchas de dos ruidos que corren en sentidos opuestos, más abundantes donde la corriente es fuerte.
	float s1 = ruido(pm.xz * 0.95 + TIME * vec2(0.09, 0.05));
	float s2 = ruido(pm.xz * 1.35 - TIME * vec2(0.06, 0.08) + 7.3);
	float suma = s1 + s2 - 1.0;
	float rompe = smoothstep(vel_espuma, vel_espuma + 0.9, vel);
	float manchas = step(espuma_manchas - rompe * 0.3, suma) + step(0.22, suma) * (1.0 - step(0.3, suma)) * 0.12;
	manchas *= step(0.12, v_prof);
	// Orilla: espuma nítida donde la profundidad (interpolada hasta el borde) es casi cero; se funde con el agua hacia dentro.
	float linea = 1.0 - smoothstep(0.0, transicion_orilla, v_prof + (ruido(pm.xz * 2.2 + TIME * 0.2) - 0.5) * 0.04);
	linea *= linea;
	float espuma = clamp(max(linea, max(manchas * 0.85, cresta * 0.8)), 0.0, 1.0);
	ce = mix(ce, color_espuma, espuma);

	float alfa_agua = mix(0.62, 0.96, hondo) + espuma;
	float rugosidad = 0.18;
	if (hielo > 0.0) {
		// Facetas: celdas grandes, cada una con su tono y su inclinación (se ve tallado, no liso).
		vec3 fa = celdas(pm.xz / tam_faceta_hielo);
		vec2 incl = vec2(hash(vec2(fa.z * 17.1, 3.3)), hash(vec2(fa.z * 9.7, 5.1))) - 0.5;
		vec3 ni = normalize(vec3(incl.x * 0.9, 1.0, incl.y * 0.9));
		ni = normalize(ni + (gn - vec3(0.0, 1.0, 0.0)) * 2.0);
		float li = clamp(dot(ni, normalize(vec3(0.45, 1.0, 0.3))), 0.0, 1.0);
		vec3 ci = mix(color_hielo_hondo, color_hielo_claro, 0.35 + 0.65 * fa.z);
		ci *= 0.70 + 0.26 * smoothstep(0.5, 1.0, li);
		// Grietas: las finas de siempre (otra malla de celdas, girada, y cortadas por ruido para que no sean una cuadrícula);
		// con el aviso se abren más, se juntan con las aristas de las facetas y todo el hielo se oscurece.
		float pulso = 0.85 + 0.15 * sin(TIME * 13.0);
		vec3 gr = celdas((GIRO_FACETA * pm.xz) / (tam_faceta_hielo * 0.62) + 3.1);
		float corta = smoothstep(0.30 - aviso * 0.25, 0.55 - aviso * 0.25, ruido(pm.xz * 1.4 + 9.0));
		float ancho = 0.035 + aviso * 0.07 * pulso;
		float grieta = (1.0 - smoothstep(ancho, ancho + 0.03, gr.y)) * corta;
		float arista = (1.0 - smoothstep(0.02, 0.05 + aviso * 0.05, fa.y)) * aviso * 0.8;
		ci = mix(ci, color_grieta * (1.0 - 0.2 * aviso), clamp(grieta * 0.75 + arista, 0.0, 1.0));
		ci *= 1.0 - 0.28 * aviso;
		ce = mix(ce, ci, hielo);
		nm = normalize(mix(nm, ni, hielo));
		alfa_agua = mix(alfa_agua, 1.0, hielo);
		rugosidad = mix(rugosidad, 0.12, hielo);
	}

	NORMAL = normalize((VIEW_MATRIX * vec4(nm, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(VIEW, NORMAL), 0.0, 1.0), 4.0);
	ce = mix(ce, vec3(0.88, 0.94, 1.0), fres * 0.25);
	ALBEDO = ce * brillo;
	ALPHA = clamp(alfa_agua, 0.0, 1.0);
	ROUGHNESS = rugosidad;
	SPECULAR = 0.5;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float luz = smoothstep(0.0, 1.0, clamp(dot(NORMAL, LIGHT) * contraste, 0.0, 1.0)) * ATTENUATION;
		DIFFUSE_LIGHT += mix(sombra_tinte, vec3(1.0), luz) * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / PI;
	}
	vec3 h = normalize(VIEW + LIGHT);
	SPECULAR_LIGHT += pow(max(dot(NORMAL, h), 0.0), 60.0) * 0.5 * LIGHT_COLOR * ATTENUATION;
}
"""

## Si no se llama a `enlazar` a mano, se pregunta a este Callable cada fotograma hasta que devuelva la simulación (el Lanzador la
## crea al cargar el nivel, después de que existan los nodos).
var proveedor: Callable = Callable()
var sim: AguaSim3D = null
var _mat: ShaderMaterial = null
var _tex_a: ImageTexture = null
var _tex_b: ImageTexture = null
var _img_b: Image = null
var _desde: float = 0.0               ## segundos desde la última lectura
var _intervalo: float = 1.0 / 12.0
var _ms_lectura: float = 0.0          ## media de lo que cuesta leer la simulación (ms), para medirlo

# Hielo (11.14)
const SEG_CRECE: float = 0.3          ## lo que tarda el hielo en cubrir la zona del impacto
const SEG_NUNCA: float = 1.0e8
var _reloj: float = 0.0
var _hielo_r_prev := PackedByteArray() ## el canal R (helado sí/no) de la lectura anterior: si no cambia, no hay nada que calcular
var _hielo_ceros := PackedByteArray()
var _hielo_g_tex: ImageTexture = null
var _hielo_est := PackedByteArray()   ## 1 = estaba helado en la lectura anterior
var _hielo_ini := PackedFloat32Array()
var _hielo_fin := PackedFloat32Array()
var _hielo_datos := PackedFloat32Array()   ## RG por trocito (inicio, fin), persistente: solo se tocan los que cambian
var _hielo_tex: ImageTexture = null
var _hielo_w: int = 0
var _hielo_h: int = 0
var _hielo_vivo_hasta: float = -1.0   ## mientras haya hielo o se esté deshaciendo, el sombreado lo dibuja
var _hielo_origen: Vector2 = Vector2.ZERO
var _hielo_origen_ok: bool = false
var _ms_hielo: float = 0.0


## Enlaza con la simulación y construye la malla (un vértice por centro de trocito). Se puede llamar otra vez al cambiar de nivel.
func enlazar(p_sim: AguaSim3D) -> void:
	sim = p_sim
	if sim == null or sim.w <= 0:
		mesh = null
		return
	_construir_malla()
	if _mat == null:
		var sh := Shader.new()
		sh.code = CODIGO
		_mat = ShaderMaterial.new()
		_mat.shader = sh
	material_override = _mat
	_mat.set_shader_parameter("minima", profundidad_minima)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_leer(true)


## Enchufa las ondas de AguaOndas3D (11.8): `textura` R = altura (u); cubre el cuadrado de lado `lado` desde `origen_xz`.
func fuente_ondas(textura: Texture2D, origen_xz: Vector2, lado: float, fuerza: float = 1.0) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("ondas", textura)
	_mat.set_shader_parameter("ondas_rect", Vector3(origen_xz.x, origen_xz.y, lado))
	_mat.set_shader_parameter("ondas_fuerza", fuerza)


## Cambia un parámetro del sombreado (colores, bandas, espuma…).
func ajustar(nombre: String, valor: Variant) -> void:
	if _mat != null:
		_mat.set_shader_parameter(nombre, valor)


## La última lectura de la simulación como textura (R altura, G profundidad, BA corriente): AguaOndas3D la usa de máscara de agua.
func textura_datos() -> Texture2D:
	return _tex_b


func milisegundos_lectura() -> float:
	return _ms_lectura


## Lo que cuesta leer el hielo en cada lectura (ms), aparte de la lectura del agua.
func milisegundos_hielo() -> float:
	return _ms_hielo


## El Juego, si sabe dónde cayó el hechizo, lo dice justo antes de helar: el hielo crecerá desde ahí. Si no, crece desde el centro de lo helado.
func hielo_desde(pos: Vector3) -> void:
	_hielo_origen = Vector2(pos.x, pos.z)
	_hielo_origen_ok = true


func _process(delta: float) -> void:
	if sim == null and proveedor.is_valid():
		var s: Variant = proveedor.call()
		if s is AguaSim3D:
			enlazar(s)
	if sim == null or _mat == null:
		return
	_reloj += delta
	_mat.set_shader_parameter("reloj", _reloj)
	_mat.set_shader_parameter("hielo_activo", 1.0 if _reloj < _hielo_vivo_hasta else 0.0)
	_intervalo = 1.0 / maxf(hz_actualizacion, 1.0)
	_desde += delta
	if _desde >= _intervalo:
		_leer(false)
		_desde = 0.0
	_mat.set_shader_parameter("mezcla", clampf(_desde / _intervalo, 0.0, 1.0))


## Lee la simulación: la lectura anterior pasa a `datos_a` y la nueva a `datos_b`; el sombreado interpola entre las dos.
func _leer(primera: bool) -> void:
	var t0: int = Time.get_ticks_usec()
	var img: Image = sim.imagen()
	if _tex_b == null or primera or _tex_b.get_width() != img.get_width() or _tex_b.get_height() != img.get_height():
		_tex_a = ImageTexture.create_from_image(img)
		_tex_b = ImageTexture.create_from_image(img)
	else:
		_tex_a.update(_img_b)
		_tex_b.update(img)
	_img_b = img
	_mat.set_shader_parameter("datos_a", _tex_a)
	_mat.set_shader_parameter("datos_b", _tex_b)
	_mat.set_shader_parameter("mezcla", 1.0 if primera else 0.0)
	_mat.set_shader_parameter("lado_trocito", sim.l)
	var t1: int = Time.get_ticks_usec()
	_leer_hielo(primera)
	_ms_hielo = lerpf(_ms_hielo, float(Time.get_ticks_usec() - t1) / 1000.0, 0.2)
	_ms_lectura = lerpf(_ms_lectura, float(Time.get_ticks_usec() - t0) / 1000.0, 0.2)


## Hielo (11.14): lee `imagen_hielo()` y guarda por trocito CUÁNDO empezó a helarse y CUÁNDO a soltarse (en el reloj propio), para que el
## sombreado pueda hacer crecer el hielo desde el impacto y deshacerlo en ~0,3 s. Si la simulación no tiene hielo, no hace nada.
## Coste: por lectura solo se copia el canal R y se compara con el anterior (nativo, sin bucle); el bucle por trocitos solo corre cuando
## algo se hiela o se suelta. El G («lo que le queda») va a la tarjeta tal cual, sin procesar.
func _leer_hielo(primera: bool) -> void:
	if sim == null or not (sim.has_method("imagen_hielo") or sim.has_method("textura_hielo")):
		return
	var fuente: Variant = sim.call("imagen_hielo") if sim.has_method("imagen_hielo") else sim.call("textura_hielo")
	var img: Image = null
	if fuente is Image:
		img = fuente
	elif fuente is Texture2D:
		img = (fuente as Texture2D).get_image()
	if img == null or img.is_empty():
		return
	if img.get_format() != Image.FORMAT_RG8:
		img = img.duplicate()
		img.convert(Image.FORMAT_RG8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var n: int = w * h
	var reinicio: bool = primera or w != _hielo_w or h != _hielo_h or _hielo_ini.size() != n
	if reinicio:
		_hielo_w = w
		_hielo_h = h
		_hielo_r_prev.resize(n)
		_hielo_r_prev.fill(0)
		_hielo_ceros.resize(n)
		_hielo_ceros.fill(0)
		_hielo_ini.resize(n)
		_hielo_ini.fill(SEG_NUNCA)
		_hielo_fin.resize(n)
		_hielo_fin.fill(SEG_NUNCA)
		_hielo_datos.resize(n * 2)
		for i in range(n):
			_hielo_datos[i * 2] = SEG_NUNCA
			_hielo_datos[i * 2 + 1] = SEG_NUNCA
		_hielo_tex = null
		_hielo_g_tex = null
	# El canal R solo (conversión nativa): ¿helado o no?
	var solo_r: Image = img.duplicate()
	solo_r.convert(Image.FORMAT_R8)
	var r: PackedByteArray = solo_r.get_data()
	var hay: bool = r != _hielo_ceros
	var cambio: bool = r != _hielo_r_prev
	if not hay and not cambio and not reinicio and _reloj >= _hielo_vivo_hasta:
		return                                   # sin hielo y sin cambios: nada que leer ni subir
	if hay:
		_hielo_vivo_hasta = _reloj + 1.0         # tras soltarse el último, sigue dibujándose 1 s: lo que tarda en deshacerse
	# G (lo que le queda) a la tarjeta, tal cual.
	if _hielo_g_tex == null:
		_hielo_g_tex = ImageTexture.create_from_image(img)
	else:
		_hielo_g_tex.update(img)
	_mat.set_shader_parameter("hielo_g", _hielo_g_tex)
	if not cambio and not reinicio:
		return
	# Algo se heló o se soltó: el bucle por trocitos (solo ahora).
	var nuevos := PackedInt32Array()
	for i in range(n):
		var ahora: int = r[i]
		if ahora == _hielo_r_prev[i]:
			continue
		if ahora >= 128:
			if reinicio:
				_hielo_ini[i] = -SEG_NUNCA          # ya estaba helado al cargar: sin animación
				_hielo_datos[i * 2] = -SEG_NUNCA
			else:
				nuevos.append(i)
			_hielo_fin[i] = SEG_NUNCA
			_hielo_datos[i * 2 + 1] = SEG_NUNCA
		else:
			_hielo_fin[i] = _reloj
			_hielo_datos[i * 2 + 1] = _reloj
	_hielo_r_prev = r
	# Los recién helados crecen desde el impacto: cada uno empieza en proporción a su distancia, para cubrirlo todo en SEG_CRECE.
	if nuevos.size() > 0:
		var c := Vector2.ZERO
		if _hielo_origen_ok:
			c = _hielo_origen / sim.l - Vector2(0.5, 0.5)
		else:
			for i in nuevos:
				c += Vector2(float(i % w), float(i / w))
			c /= float(nuevos.size())
		var dmax: float = 1.0
		for i in nuevos:
			dmax = maxf(dmax, c.distance_to(Vector2(float(i % w), float(i / w))))
		for i in nuevos:
			var dist: float = c.distance_to(Vector2(float(i % w), float(i / w)))
			_hielo_ini[i] = _reloj + SEG_CRECE * dist / dmax
			_hielo_datos[i * 2] = _hielo_ini[i]
		_hielo_origen_ok = false
	var im := Image.create_from_data(w, h, false, Image.FORMAT_RGF, _hielo_datos.to_byte_array())
	if _hielo_tex == null:
		_hielo_tex = ImageTexture.create_from_image(im)
	else:
		_hielo_tex.update(im)
	_mat.set_shader_parameter("hielo_t", _hielo_tex)


func _construir_malla() -> void:
	var w: int = sim.w
	var h: int = sim.h
	var l: float = sim.l
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(w * h)
	uvs.resize(w * h)
	for y in range(h):
		for x in range(w):
			var i: int = y * w + x
			verts[i] = Vector3((x + 0.5) * l, 0.0, (y + 0.5) * l)
			uvs[i] = Vector2((x + 0.5) / float(w), (y + 0.5) / float(h))
	var idx := PackedInt32Array()
	idx.resize((w - 1) * (h - 1) * 6)
	var k: int = 0
	for y in range(h - 1):
		for x in range(w - 1):
			var a: int = y * w + x
			var b: int = a + 1
			var c: int = a + w
			var d: int = c + 1
			# Diagonal que alterna (como un tablero) para que las facetas del borde no se alineen siempre igual.
			if (x + y) % 2 == 0:
				idx[k] = a; idx[k + 1] = c; idx[k + 2] = b
				idx[k + 3] = b; idx[k + 4] = c; idx[k + 5] = d
			else:
				idx[k] = a; idx[k + 1] = c; idx[k + 2] = d
				idx[k + 3] = a; idx[k + 4] = d; idx[k + 5] = b
			k += 6
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# Los vértices suben y bajan en el sombreado: la caja de recorte debe cubrir cualquier altura del nivel.
	m.custom_aabb = AABB(Vector3(0.0, -20.0, 0.0), Vector3(w * l, 60.0, h * l))
	mesh = m
