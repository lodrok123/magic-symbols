#[compute]
#version 450
// MODO TOON DEL VIENTO (11/11/2026, rehecho: Pablo, al ver la primera version de «bruma» con superficie, «parece vapor... un fluido, no una rafaga sostenida de aire»).
// La SIMULACION es la del port de lejrimostfa/force-field-vfx-threejs (MIT) en modo viento (ver VIENTO en gas_comun.glslinc y gas_fuentes.glsl):
//   gas.x = RAFAGA (pulsos que viajan con el aire), gas.y / gas.w = ETIQUETAS de linea de corriente (posicion en la seccion del chorro, transportadas), gas.z = POLVO.
// El aire NO se pinta como masa: solo TRAZOS. Una linea de corriente es la curva donde las dos etiquetas valen el centro de su casilla (fract(etiqueta · N) = 0,5);
// como las etiquetas las lleva el gas, los trazos siguen el camino REAL del aire (rectos y largos en la rafaga, doblados alrededor del solido). A lo largo del rayo de
// vista se busca el punto mas cercano a una linea y se afina (trazo nitido de grosor constante); el grosor se afila donde la rafaga nace y muere (trazos con punta).
// El POLVO, franja terrosa plana a ras de suelo. Colores en «paleta» (8 x 1): 0 SOMBRA, 1 CLARO, 2 LINEA, 3 POLVO claro, 4 POLVO sombra.
// 11/11, refuerzo (Pablo: «refuerza el viento»): POCAS cintas ANCHAS (VIENTO_LINEAS 1,25) con borde toon en dos escalones, que se afilan en las dos puntas y se
// enroscan juntas; brillo grande en la mano; lazos del vortice gruesos, ladeados hacia la camara, que giran y sueltan jirones; al soltar, unos pocos trozos curvos
// que derivan y se apagan.
// Salida igual que los otros raymarch (rgb premultiplicado, a = lo que queda del fondo).
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
#include "gas_comun.glslinc"
#include "vista_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler3D gas;
layout(set = 0, binding = 1) uniform sampler3D vel;
layout(set = 0, binding = 2) uniform sampler2D profundidad;
layout(set = 0, binding = 3) uniform sampler2D rayas;
layout(set = 0, binding = 4) uniform sampler2D ruido_a;
layout(set = 0, binding = 5) uniform sampler2D ruido_b;
layout(set = 0, binding = 6) uniform sampler2D paleta;
layout(set = 0, binding = 7, rgba16f) uniform restrict writeonly image2D crudo;

#define UMBRAL V.toon0.x
#define GROSOR V.toon0.y
#define OPACIDAD V.toon0.w
#define K_VELO V.toon1.y
#define K_POLVO V.toon2.y
// 11/11 (referencia de Pablo, un video de un haz de viento; solo como referencia visual): brillo en la mano, anillos del vortice en el choque y disolucion al soltar.
#define T_CORTE V.toon3.x          // s desde que se solto el chorro (< 0 = sigue encendido)
#define K_MANO V.toon3.y           // brillo de la mano (0 = sin; 1 = radio de ~media altura de la mano)
#define K_ANILLOS V.toon3.z        // anillos del vortice del choque (0 = sin; solo si CHOQUE)
#define DISUELVE V.toon2.x         // s que tardan los trazos en romperse y desaparecer al soltar
#define TIEMPO_V V.toon2.w
// 11/11, mixto (Pablo: «deja el impacto como ahora pero el haz como sin el refuerzo»): interruptores. Con CINTAS_ON el cuerpo del haz es el del refuerzo (482:
// cintas analiticas, lineas de corriente solo junto al solido, deriva al soltar); sin el, el de la 481 (lineas de corriente en todo el haz, su disolucion). El
// choque (lazos gruesos ladeados) es el del refuerzo en los dos casos, con su propio grosor GROSOR_LAZO. MANO_GRANDE: el brillo grande del refuerzo.
#define CINTAS_ON (V.toon1.z > 0.5)
#define MANO_GRANDE (V.toon1.w > 0.5)
#define GROSOR_LAZO V.toon1.x

// Al soltar, los trozos DERIVAN: el dibujo lee el gas un poco por detras (el aire se los lleva hacia delante y hacia arriba).
vec3 DERIVA = vec3(0.0);

// Eje del haz (de la mano al objetivo).
vec3 eje_dir() { return normalize(P.target.xyz - P.nozzle.xyz); }

// ANILLOS DEL VORTICE: tres lazos que envuelven el contacto y GIRAN alrededor del eje del haz (cada uno a su ritmo), rotos en arcos que al final se abren hacia
// fuera (jirones arrancados). El plano de los lazos es casi perpendicular al haz pero se LADEA hacia la camara (`nrm`), para que desde la camara del juego no se
// vean de canto. Devuelve (distancia al lazo mas cercano en unidades del dominio, grosor relativo 0-1 a lo largo del arco: 0 en las puntas).
vec2 anillos(vec3 p, float abre, vec3 nrm) {
	vec3 d = eje_dir();
	vec3 ref = abs(nrm.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 e1 = normalize(cross(nrm, ref));
	vec3 e2 = cross(e1, nrm);
	float mejor = 1e9, gr = 0.0;
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		vec3 c = P.contacto.xyz - d * (0.15 + 0.4 * fk) * ESC_M;
		vec3 q = p - c;
		float ax = dot(q, nrm);
		vec2 s = vec2(dot(q, e1), dot(q, e2));
		float phi = atan(s.y, s.x);
		// arcos: 2 o 3 por lazo, que corren alrededor del eje (el giro del vortice, ~1-1,6 vueltas por segundo)
		float n_arcos = 2.0 + mod(fk, 2.0);
		float u = fract(phi / 6.2832 * n_arcos - TIEMPO_V * (1.0 + 0.3 * fk) * n_arcos + fk * 0.37);
		float tira = smoothstep(0.35, 0.8, u);                                   // la cola del arco se abre hacia fuera: un jiron que se suelta
		float rk = (1.0 + 0.55 * fk) * BEAM_R1 * VIENTO_ANCHO * (1.0 + 0.1 * sin(2.0 * phi + TIEMPO_V * (2.0 + fk)) + 0.55 * tira * tira) * abre;
		float ak = (0.25 * sin(phi + fk * 2.1 + TIEMPO_V * 1.3) + 0.5 * tira * tira) * ESC_M;
		float dist = length(vec2(length(s) - rk, ax - ak));
		float arco = smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.55, 0.85, u));
		if (arco > 0.02 && dist < mejor) { mejor = dist; gr = arco * (1.0 - 0.6 * tira); }
	}
	return vec2(mejor, gr);
}

vec3 srgb_a_lineal(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 color_paleta(int i) { return srgb_a_lineal(textureLod(paleta, vec2((float(i) + 0.5) / 8.0, 0.5), 0.0).rgb); }

// (distancia a la linea de corriente mas cercana, en unidades de etiqueta; rafaga; polvo)
vec3 linea(vec3 pos) {
	vec4 s = textureLod(gas, (pos - DERIVA - WLO) / WTAM, 0.0);
	vec2 l = fract(vec2(s.y, s.w) * VIENTO_LINEAS) - 0.5;
	return vec3(length(l) / VIENTO_LINEAS, s.x, s.z);
}

// CINTAS DEL CHORRO (refuerzo 11/11, Pablo: «refuerza el viento»; en la referencia hay POCAS cintas anchas y lisas que se enroscan JUNTAS alrededor del eje y
// corren hacia delante). Se dibujan analiticas, no con las etiquetas (que en el chorro daban muchas lineas finas que temblaban: un «garabato»): N_CINTAS helices
// alrededor del eje del haz, con el mismo giro (CINTAS_VUELTAS) y radios distintos, rotas en tramos que viajan a la velocidad del aire y se afilan en las dos
// puntas. Acaban en el contacto (ahi siguen las lineas de corriente de verdad, que rodean el solido). Devuelve (distancia en el dominio, grosor relativo 0-1).
#define N_CINTAS 5
#define CINTAS_VUELTAS 0.7     // vueltas de cada cinta de la mano al final (todas iguales: se enroscan juntas)
vec2 cintas(vec3 p) {
	vec3 ab = P.target.xyz - P.nozzle.xyz;
	float L = length(ab);
	vec3 d = ab / L;
	float s_fin = CHOQUE ? clamp(dot(P.contacto.xyz - P.nozzle.xyz, d) / L, 0.2, 1.0) : 1.0;
	float s = dot(p - P.nozzle.xyz, d) / L;
	if (s < 0.0 || s > s_fin) return vec2(1e9, 0.0);
	vec3 e1 = normalize(cross(d, vec3(0.0, 1.0, 0.0)));
	vec3 e2 = cross(e1, d);
	vec3 q = p - (P.nozzle.xyz + d * (s * L));
	vec2 sq = vec2(dot(q, e1), dot(q, e2));
	float R = mix(BEAM_R0, BEAM_R1, s) * VIENTO_ANCHO;
	float mejor = 1e9, gr = 0.0;
	for (int k = 0; k < N_CINTAS; k++) {
		float fk = float(k);
		float sem = fract(fk * 0.618 + 0.13);
		float rk = R * (0.3 + 0.55 * sem) * (1.0 + 0.12 * sin(s * 9.0 + TIEMPO_V * 1.7 + fk * 1.9));
		float th = 6.2832 * (fk / float(N_CINTAS) + CINTAS_VUELTAS * s) - TIEMPO_V * 2.4;
		float dist = length(sq - rk * vec2(cos(th), sin(th)));
		// tramos que corren con el aire (largo ~0,4 del haz, 70 % encendidos) y se afilan en las dos puntas
		float u = fract((s - TIEMPO_V * BEAM_SPEED * 0.85 / L) * 1.7 + sem * 3.7);
		float tramo = sin(3.1416 * clamp(u / 0.7, 0.0, 1.0));
		float g = tramo * smoothstep(0.0, 0.07, s) * smoothstep(s_fin, s_fin - 0.05, s);
		if (g > 0.03 && dist < mejor) { mejor = dist; gr = g; }
	}
	return vec2(mejor, gr);
}

// Las dos etiquetas de linea de corriente en bruto (sin fract), para su gradiente.
vec2 texture_lab(vec3 pos) {
	vec4 s = textureLod(gas, (pos - DERIVA - WLO) / WTAM, 0.0);
	return vec2(s.y, s.w);
}

// Mezcla "encima" de un color no premultiplicado (c, a) sobre lo que ya hay (c_v, a_v).
void encima(inout vec3 c_v, inout float a_v, vec3 c, float a) {
	c_v = (c_v * a_v * (1.0 - a) + c * a) / max(a_v + a - a_v * a, 1e-4);
	a_v = a_v + a - a_v * a;
}

void main() {
	ivec2 gid = ivec2(gl_GlobalInvocationID.xy);
	if (gid.x >= int(V.tam.x) || gid.y >= int(V.tam.y)) return;
	vec2 uv = (vec2(gid) + 0.5) / V.tam.xy;
	vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
	vec4 a4 = V.inv_vp * vec4(ndc, -1.0, 1.0);
	vec4 b4 = V.inv_vp * vec4(ndc, 1.0, 1.0);
	vec3 ro = a4.xyz / a4.w;
	vec3 rd = normalize(b4.xyz / b4.w - ro);
	// direccion de la camara (el rayo del centro de la pantalla): hacia ella se ladean los lazos
	vec4 c0 = V.inv_vp * vec4(0.0, 0.0, -1.0, 1.0);
	vec4 c1 = V.inv_vp * vec4(0.0, 0.0, 1.0, 1.0);
	vec3 cam_f = normalize(c1.xyz / c1.w - c0.xyz / c0.w);
	vec3 lo = WLO, hi = WLO + WTAM;
	vec3 inv = vec3(1.0) / (rd + vec3(0.00001));
	vec3 t0 = (lo - ro) * inv, t1 = (hi - ro) * inv;
	vec3 mn = min(t0, t1), mx = max(t0, t1);
	float tNear = max(max(max(mn.x, mn.y), mn.z), 0.0);
	float tFar = min(min(mx.x, mx.y), mx.z);
	float tEscena = 1e9;
	if (V.marcha.z > 0.5) {
		ivec2 pz = clamp(ivec2(uv * V.tam.zw), ivec2(0), ivec2(V.tam.zw) - 1);
		float d = texelFetch(profundidad, pz, 0).r;
		if (d > 0.0) {
			vec4 h4 = V.inv_vp * vec4(ndc, 1.0 - 2.0 * d, 1.0);
			tEscena = dot(h4.xyz / h4.w - ro, rd);
			tFar = min(tFar, tEscena);
		}
	}
	vec3 d_e = eje_dir();
	// disolucion al soltar: 0 con el chorro encendido, 1 cuando ya no queda trazo
	float dis = T_CORTE < 0.0 ? 0.0 : clamp(T_CORTE / max(DISUELVE, 0.05), 0.0, 1.0);
	if (CINTAS_ON) DERIVA = (d_e * 1.4 + vec3(0.0, 0.45, 0.0)) * ESC_M * dis;
	vec3 color = vec3(0.0);
	float trans = 1.0;
	float a_v = 0.0;
	vec3 c_v = vec3(0.0);
	float a_p = 0.0;
	vec3 c_p = vec3(0.0);
	if (tFar > tNear) {
		int pasos = int(V.marcha.x);
		if (V.toon3.w > 0.0) pasos = clamp(int(ceil((tFar - tNear) / (1.0 * V.toon3.w))), 24, 240);
		float dl = (tFar - tNear) / float(pasos);
		float mejor = 1e9, t_mejor = tNear;
		float polvo = 0.0;
		float t = tNear + dl * 0.5;
		bool con_anillos = CHOQUE && K_ANILLOS > 0.0 && dis < 1.0;
		float abre = 1.0 + 0.7 * dis;                                    // al soltar, los lazos se abren mientras se deshacen
		vec3 nrm = normalize(d_e + cam_f * (dot(d_e, cam_f) >= 0.0 ? 0.9 : -0.9));     // perpendicular al haz, ladeado para mirar a la camara
		float m_an = 1e9, t_an = tNear;
		float R2_ANILLOS = pow((2.1 * 1.6 * BEAM_R1 * VIENTO_ANCHO + 1.6 * ESC_M) * abre, 2.0);
		float m_ci = 1e9, t_ci = tNear;
		vec3 ab_m = P.target.xyz - P.nozzle.xyz;
		for (int k = 0; k < pasos; k++) {
			vec3 c = linea(ro + rd * t);
			polvo += c.z * dl;
			if (CINTAS_ON && dis < 1.0) {
				vec2 ci = cintas(ro + rd * t - DERIVA);
				if (ci.x < m_ci) { m_ci = ci.x; t_ci = t; }
			}
			// las lineas de corriente de verdad solo se dibujan con choque y cerca del final (donde rodean el solido y se abren en abanico): en el chorro
			// las sustituyen las cintas; al aire, al final se emborronaban en manchas
			float tt_k = dot(ro + rd * t - P.nozzle.xyz, ab_m) / dot(ab_m, ab_m);
			if (CINTAS_ON && (!CHOQUE || tt_k < 0.7)) c.y = 0.0;
			vec3 q_an = ro + rd * t - P.contacto.xyz;
			if (con_anillos && dot(q_an, q_an) < R2_ANILLOS) {        // solo cerca del contacto
				vec2 an = anillos(ro + rd * t, abre, nrm);
				if (an.x < m_an) { m_an = an.x; t_an = t; }
			}
			if (c.y > UMBRAL) {
				float punt = c.x / (c.y - UMBRAL + 0.05);
				if (punt < mejor) { mejor = punt; t_mejor = t; }
			}
			t += dl;
		}
		// tamano de un pixel del volumen a una distancia (con el rayo del pixel vecino: vale para la camara ortogonal del juego y la de perspectiva del lab)
		vec2 ndc2 = ndc + vec2(2.0 / V.tam.x, 0.0);
		vec4 a5 = V.inv_vp * vec4(ndc2, -1.0, 1.0);
		vec4 b5 = V.inv_vp * vec4(ndc2, 1.0, 1.0);
		vec3 ro2 = a5.xyz / a5.w;
		vec3 rd2 = normalize(b5.xyz / b5.w - ro2);
		if (mejor < 1e8) {
			// afinar: busqueda ternaria en ± un paso alrededor del mejor punto
			float a = max(t_mejor - dl, tNear), b = min(t_mejor + dl, tFar);
			for (int j = 0; j < 6; j++) {
				float m1 = mix(a, b, 0.382), m2 = mix(a, b, 0.618);
				if (linea(ro + rd * m1).x < linea(ro + rd * m2).x) b = m2; else a = m1;
			}
			vec3 f = linea(ro + rd * (0.5 * (a + b)));
			vec3 p_f = ro + rd * (0.5 * (a + b));
			float pix = length(p_f - (ro2 + rd2 * dot(p_f - ro2, rd2)));
			vec3 ab_f = P.target.xyz - P.nozzle.xyz;
			float tt_f = clamp(dot(p_f - P.nozzle.xyz, ab_f) / dot(ab_f, ab_f), 0.0, 1.0);
			if (!CINTAS_ON) {
				// CUERPO DE LA 481 (lo que Pablo prefiere): lineas de corriente finas en todo el haz, con su grosor en etiquetas, jirones y su disolucion
				float aa = 0.5 * pix / (mix(BEAM_R0, BEAM_R1, tt_f) * VIENTO_ANCHO);
				float fuerza = smoothstep(UMBRAL, UMBRAL + 0.45, f.y);        // 0 en las puntas del trazo, 1 en su cuerpo
				float jiron = textureLod(ruido_a, vec2(dot(p_f, d_e) * 0.11 / ESC_M - TIEMPO_V * 0.35, dot(p_f, vec3(0.31, 0.71, 0.13)) * 0.2 / ESC_M), 0.0).r;
				fuerza *= 0.45 + 0.9 * jiron;
				float rompe = 1.0;
				if (dis > 0.0) {
					float trozo = textureLod(ruido_b, p_f.xz * 0.21 / ESC_M + vec2(p_f.y * 0.17 / ESC_M, 0.0), 0.0).r;
					rompe = smoothstep(dis * 0.95 - 0.05, dis * 0.95 + 0.08, trozo) * (1.0 - smoothstep(0.75, 1.0, dis));
					fuerza *= 1.0 - 0.6 * dis;
				}
				float gr = GROSOR * (0.25 + 0.75 * min(fuerza, 1.0));
				float borde = max(gr * 0.85, aa);
				float cob = min(gr * 0.85 / borde, 1.0);
				float trazo = (1.0 - smoothstep(borde - max(gr * 0.15, aa), borde + aa, f.x)) * cob * smoothstep(UMBRAL, UMBRAL + 0.08, f.y);
				float velo = (1.0 - smoothstep(gr, gr * 3.2 + aa, f.x)) * fuerza * K_VELO;
				a_v = max(trazo * OPACIDAD, velo) * rompe;
				c_v = mix(color_paleta(1), color_paleta(2), trazo);
			} else {			// ANCHO EN EL MUNDO, no en etiquetas: la distancia en etiquetas se pasa a distancia real con el gradiente de las etiquetas. Dentro del chorro da lo
			// mismo que antes; donde el aire ha emborronado las etiquetas (gradiente pequeno, al final de la rafaga) la cinta NO engorda hasta hacerse una mancha.
			float hg = max(V.toon3.w, 1e-3);
			vec2 gx = (texture_lab(p_f + vec3(hg, 0.0, 0.0)) - texture_lab(p_f - vec3(hg, 0.0, 0.0))) / (2.0 * hg);
			vec2 gy = (texture_lab(p_f + vec3(0.0, hg, 0.0)) - texture_lab(p_f - vec3(0.0, hg, 0.0))) / (2.0 * hg);
			vec2 gz = (texture_lab(p_f + vec3(0.0, 0.0, hg)) - texture_lab(p_f - vec3(0.0, 0.0, hg))) / (2.0 * hg);
			float g_lab = sqrt(0.5 * (dot(gx, gx) + dot(gy, gy) + dot(gz, gz)));
			float r_ref = mix(BEAM_R0, BEAM_R1, tt_f) * VIENTO_ANCHO;            // a cuanto mundo equivale una etiqueta dentro del chorro
			f.x /= clamp(g_lab * r_ref, 0.15, 3.0);                              // distancia en el mundo (en radios de la rafaga): emborronadas = lejos = cinta fina
			float aa = 0.5 * pix / r_ref;
			// CINTA: ancha en su cuerpo y afilada en las dos puntas (donde la rafaga nace y muere), un poco mas fina junto a la mano; engorda y adelgaza despacio
			// a lo largo (ruido de baja frecuencia: la cinta se retuerce, no tiembla).
			float fuerza = smoothstep(UMBRAL, UMBRAL + 0.5, f.y) * smoothstep(0.0, 0.12, tt_f);
			float jiron = textureLod(ruido_a, vec2(dot(p_f, d_e) * 0.05 / ESC_M - TIEMPO_V * 0.25, 0.37), 0.0).r;
			fuerza *= 0.7 + 0.5 * jiron;
			float rompe = 1.0;
			if (dis > 0.0) {
				// al soltar: unos pocos TROZOS largos (ruido de baja frecuencia fijo en el aire) que quedan, derivan y se apagan
				float trozo = textureLod(ruido_b, vec2(dot(p_f, d_e), p_f.y + 0.5 * dot(p_f, vec3(-d_e.z, 0.0, d_e.x))) * 0.07 / ESC_M, 0.0).r;
				float corte = 0.25 + 0.3 * dis;
				rompe = smoothstep(corte - 0.03, corte + 0.03, trozo) * (1.0 - smoothstep(0.7, 1.0, dis));
				fuerza *= 1.0 - 0.3 * dis;
			}
			float gr = GROSOR * 0.6 * (0.3 + 0.7 * min(fuerza, 1.0));
			float borde = max(gr, aa);
			float cob = min(gr / borde, 1.0);
			float vivo = smoothstep(UMBRAL, UMBRAL + 0.06, f.y);
			// borde toon en dos escalones: alma blanca (LINEA) y orilla clara (CLARO) mas transparente
			float alma = (1.0 - smoothstep(borde * 0.62 - aa, borde * 0.62 + aa, f.x)) * cob * vivo;
			float orilla = (1.0 - smoothstep(borde - aa, borde + aa, f.x)) * cob * vivo;
			a_v = max(alma * OPACIDAD, orilla * 0.5) * rompe;
			c_v = mix(color_paleta(1), color_paleta(2), alma);
			}
		}
		// CINTAS del chorro: la mas cercana al rayo de vista, afinada, con el borde toon en dos escalones. Al soltar se rompen en unos pocos TROZOS largos
		// (ruido de baja frecuencia fijo en el aire), derivan con el aire (DERIVA) y se apagan.
		if (m_ci < 1e8) {
			float a = max(t_ci - dl, tNear), b = min(t_ci + dl, tFar);
			for (int j = 0; j < 6; j++) {
				float m1 = mix(a, b, 0.382), m2 = mix(a, b, 0.618);
				if (cintas(ro + rd * m1 - DERIVA).x < cintas(ro + rd * m2 - DERIVA).x) b = m2; else a = m1;
			}
			vec3 p_c = ro + rd * (0.5 * (a + b));
			vec2 ci = cintas(p_c - DERIVA);
			float pix_c = length(p_c - (ro2 + rd2 * dot(p_c - ro2, rd2)));
			float rompe_c = 1.0;
			if (dis > 0.0) {
				vec3 pq = p_c - DERIVA;
				float trozo = textureLod(ruido_b, vec2(dot(pq, d_e), pq.y + 0.5 * dot(pq, vec3(-d_e.z, 0.0, d_e.x))) * 0.22 / ESC_M, 0.0).r;
				float corte = 0.2 + 0.4 * dis;
				rompe_c = smoothstep(corte - 0.03, corte + 0.03, trozo) * (1.0 - smoothstep(0.7, 1.0, dis));
			}
			float gr_c = GROSOR * BEAM_R1 * VIENTO_ANCHO * 1.1 * (0.2 + 0.8 * ci.y) * (1.0 - 0.3 * dis);
			float borde_c = max(gr_c, 0.5 * pix_c);
			float cob_c = min(gr_c / borde_c, 1.0);
			float vivo_c = smoothstep(0.03, 0.15, ci.y) * rompe_c;
			float alma_c = (1.0 - smoothstep(borde_c * 0.62 - 0.5 * pix_c, borde_c * 0.62 + 0.5 * pix_c, ci.x)) * cob_c * vivo_c;
			float orilla_c = (1.0 - smoothstep(borde_c - 0.5 * pix_c, borde_c + 0.5 * pix_c, ci.x)) * cob_c * vivo_c;
			encima(c_v, a_v, mix(color_paleta(1), color_paleta(2), alma_c), max(alma_c * OPACIDAD, orilla_c * 0.5));
		}
		// ANILLOS del vortice: el lazo mas cercano al rayo de vista, afinado como el trazo, con el mismo borde toon
		if (con_anillos && m_an < 1e8) {
			float a = max(t_an - dl, tNear), b = min(t_an + dl, tFar);
			for (int j = 0; j < 6; j++) {
				float m1 = mix(a, b, 0.382), m2 = mix(a, b, 0.618);
				if (anillos(ro + rd * m1, abre, nrm).x < anillos(ro + rd * m2, abre, nrm).x) b = m2; else a = m1;
			}
			vec3 p_a = ro + rd * (0.5 * (a + b));
			vec2 an = anillos(p_a, abre, nrm);
			float pix_a = length(p_a - (ro2 + rd2 * dot(p_a - ro2, rd2)));
			float gr_a = GROSOR_LAZO * BEAM_R1 * VIENTO_ANCHO * 1.2 * (0.25 + 0.75 * an.y) * (1.0 - 0.6 * dis);
			float borde_a = max(gr_a, 0.5 * pix_a);
			float cob_a = min(gr_a / borde_a, 1.0);
			float vivo_a = smoothstep(0.02, 0.15, an.y) * K_ANILLOS * (1.0 - smoothstep(0.0, 0.45, dis));
			float alma_a = (1.0 - smoothstep(borde_a * 0.62 - 0.5 * pix_a, borde_a * 0.62 + 0.5 * pix_a, an.x)) * cob_a * vivo_a;
			float orilla_a = (1.0 - smoothstep(borde_a - 0.5 * pix_a, borde_a + 0.5 * pix_a, an.x)) * cob_a * vivo_a;
			encima(c_v, a_v, mix(color_paleta(1), color_paleta(2), alma_a), max(alma_a * OPACIDAD, orilla_a * 0.5));
		}
		a_p = smoothstep(0.06, 0.16, polvo) * K_POLVO;
		c_p = mix(color_paleta(4), color_paleta(3), smoothstep(0.16, 0.2, polvo));
	}
	// BRILLO EN LA MANO (referencia: un resplandor blanco grande donde nace el haz). Disco toon en tres escalones (nucleo blanco, halo claro, orla tenue) de radio
	// ~K_MANO · la altura de la mano (unos dos tercios del cuerpo de diametro), un poco por delante de ella, que respira; se apaga en un cuarto de segundo al soltar. Va fuera de la caja del
	// dominio (puede ser mas grande que ella) y lo tapa lo que haya delante.
	float k_m = K_MANO * (T_CORTE < 0.0 ? BEAM_ON : max(1.0 - T_CORTE / 0.25, 0.0));
	if (k_m > 0.0 && !MANO_GRANDE) {
		// el brillo pequeno de la 481 (el de serie desde el mixto): disco blanco de radio 1 M con halo blando, centrado en la boquilla
		float t_m = dot(P.nozzle.xyz - ro, rd);
		if (t_m > 0.0 && t_m < tEscena + 0.5 * ESC_M) {
			float dm = length(ro + rd * t_m - P.nozzle.xyz);
			float rm = 1.0 * ESC_M * (1.0 + 0.07 * sin(TIEMPO_V * 11.0)) * (0.7 + 0.3 * k_m);
			float nucleo_m = 1.0 - smoothstep(rm * 0.24, rm * 0.32, dm);
			float halo_m = 1.0 - smoothstep(rm * 0.3, rm, dm);
			float a_m = max(nucleo_m * 0.95, halo_m * halo_m * 0.6) * k_m;
			encima(c_v, a_v, mix(color_paleta(1), color_paleta(2), max(nucleo_m, 0.4)), a_m);
		}
	} else if (k_m > 0.0) {
		float rm = K_MANO * 1.0 * max(P.nozzle.y, 0.5 * ESC_M) * (1.0 + 0.06 * sin(TIEMPO_V * 9.0)) * (0.6 + 0.4 * k_m);
		vec3 cm = P.nozzle.xyz + d_e * 0.25 * rm;
		float t_m = dot(cm - ro, rd);
		if (t_m > 0.0 && t_m < tEscena + 0.6 * rm) {
			float dm = length(ro + rd * t_m - cm) / rm;
			float e = 0.05;
			float nucleo_m = 1.0 - smoothstep(0.3 - e, 0.3 + e, dm);
			float halo_m = 1.0 - smoothstep(0.6 - e, 0.6 + e, dm);
			float orla_m = 1.0 - smoothstep(0.75, 1.0, dm);
			float a_m = max(max(nucleo_m * 0.97, halo_m * 0.6), orla_m * 0.28) * k_m;
			vec3 c_m = mix(color_paleta(1), color_paleta(2), max(nucleo_m, halo_m * 0.6));
			encima(c_v, a_v, c_m, a_m);
		}
	}
	color = c_v * a_v + c_p * a_p * (1.0 - a_v);
	trans = (1.0 - a_v) * (1.0 - a_p);
	imageStore(crudo, gid, vec4(color, trans));
}
