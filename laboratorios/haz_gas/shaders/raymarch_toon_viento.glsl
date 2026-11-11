#[compute]
#version 450
// MODO TOON DEL VIENTO (11/11/2026, rehecho: Pablo, al ver la primera version de «bruma» con superficie, «parece vapor... un fluido, no una rafaga sostenida de aire»).
// La SIMULACION es la del port de lejrimostfa/force-field-vfx-threejs (MIT) en modo viento (ver VIENTO en gas_comun.glslinc y gas_fuentes.glsl):
//   gas.x = RAFAGA (pulsos que viajan con el aire), gas.y / gas.w = ETIQUETAS de linea de corriente (posicion en la seccion del chorro, transportadas), gas.z = POLVO.
// El aire NO se pinta como masa: solo TRAZOS. Una linea de corriente es la curva donde las dos etiquetas valen el centro de su casilla (fract(etiqueta · N) = 0,5);
// como las etiquetas las lleva el gas, los trazos siguen el camino REAL del aire (rectos y largos en la rafaga, doblados alrededor del solido). A lo largo del rayo de
// vista se busca el punto mas cercano a una linea y se afina (trazo nitido de grosor constante); el grosor se afila donde la rafaga nace y muere (trazos con punta).
// Alrededor, una funda muy tenue. El POLVO, franja terrosa plana a ras de suelo. Colores en «paleta» (8 x 1): 0 SOMBRA, 1 CLARO, 2 LINEA, 3 POLVO claro, 4 POLVO sombra.
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
#define K_MANO V.toon3.y           // brillo de la mano (0 = sin)
#define K_ANILLOS V.toon3.z        // anillos del vortice del choque (0 = sin; solo si CHOQUE)
#define DISUELVE V.toon2.x         // s que tardan los trazos en romperse y desaparecer al soltar
#define TIEMPO_V V.toon2.w

// Eje del haz (de la mano al objetivo).
vec3 eje_dir() { return normalize(P.target.xyz - P.nozzle.xyz); }

// ANILLOS DEL VORTICE (11/11): tres lazos alrededor del eje del haz que envuelven el contacto, perpendiculares al haz, que GIRAN (cada uno a su ritmo) y estan
// rotos en arcos (jirones). Devuelve (distancia al lazo mas cercano en unidades del dominio, grosor relativo 0-1 a lo largo del arco: 0 en las puntas).
vec2 anillos(vec3 p, float abre) {
	vec3 d = eje_dir();
	vec3 e1 = normalize(cross(d, vec3(0.0, 1.0, 0.0)));
	vec3 e2 = cross(e1, d);
	float mejor = 1e9, gr = 0.0;
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		vec3 c = P.contacto.xyz - d * (0.1 + 0.45 * fk) * ESC_M;
		vec3 q = p - c;
		float ax = dot(q, d);
		vec2 s = vec2(dot(q, e1), dot(q, e2));
		float phi = atan(s.y, s.x);
		float rk = (1.05 + 0.4 * fk) * BEAM_R1 * VIENTO_ANCHO * (1.0 + 0.12 * sin(2.0 * phi + TIEMPO_V * (2.0 + fk))) * abre;
		float ak = 0.38 * ESC_M * sin(phi + fk * 2.1 + TIEMPO_V * 1.3);          // el lazo no es plano: se ladea y ondula
		float dist = length(vec2(length(s) - rk, ax - ak));
		// arcos: 2 o 3 por lazo, que corren alrededor del eje (el giro del vortice)
		float n_arcos = 2.0 + mod(fk, 2.0);
		float u = fract(phi / 6.2832 * n_arcos - TIEMPO_V * (1.1 + 0.35 * fk) * n_arcos * 0.5 + fk * 0.37);
		float arco = smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.55, 0.8, u));
		if (arco > 0.02 && dist < mejor) { mejor = dist; gr = arco; }
	}
	return vec2(mejor, gr);
}

vec3 srgb_a_lineal(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 color_paleta(int i) { return srgb_a_lineal(textureLod(paleta, vec2((float(i) + 0.5) / 8.0, 0.5), 0.0).rgb); }

// (distancia a la linea de corriente mas cercana, en unidades de etiqueta; rafaga; polvo)
vec3 linea(vec3 pos) {
	vec4 s = textureLod(gas, (pos - WLO) / WTAM, 0.0);
	vec2 l = fract(vec2(s.y, s.w) * VIENTO_LINEAS) - 0.5;
	return vec3(length(l) / VIENTO_LINEAS, s.x, s.z);
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
	vec3 lo = WLO, hi = WLO + WTAM;
	vec3 inv = vec3(1.0) / (rd + vec3(0.00001));
	vec3 t0 = (lo - ro) * inv, t1 = (hi - ro) * inv;
	vec3 mn = min(t0, t1), mx = max(t0, t1);
	float tNear = max(max(max(mn.x, mn.y), mn.z), 0.0);
	float tFar = min(min(mx.x, mx.y), mx.z);
	if (V.marcha.z > 0.5) {
		ivec2 pz = clamp(ivec2(uv * V.tam.zw), ivec2(0), ivec2(V.tam.zw) - 1);
		float d = texelFetch(profundidad, pz, 0).r;
		if (d > 0.0) {
			vec4 h4 = V.inv_vp * vec4(ndc, 1.0 - 2.0 * d, 1.0);
			tFar = min(tFar, dot(h4.xyz / h4.w - ro, rd));
		}
	}
	vec3 color = vec3(0.0);
	float trans = 1.0;
	if (tFar > tNear) {
		int pasos = int(V.marcha.x);
		if (V.toon3.w > 0.0) pasos = clamp(int(ceil((tFar - tNear) / (1.0 * V.toon3.w))), 24, 240);
		float dl = (tFar - tNear) / float(pasos);
		float mejor = 1e9, t_mejor = tNear;
		float polvo = 0.0;
		float t = tNear + dl * 0.5;
		// disolucion al soltar: 0 con el chorro encendido, 1 cuando ya no queda trazo
		float dis = T_CORTE < 0.0 ? 0.0 : clamp(T_CORTE / max(DISUELVE, 0.05), 0.0, 1.0);
		bool con_anillos = CHOQUE && K_ANILLOS > 0.0 && dis < 1.0;
		float abre = 1.0 + 0.7 * dis;                                    // al soltar, los lazos se abren mientras se deshacen
		float m_an = 1e9, t_an = tNear;
		float R2_ANILLOS = pow((2.4 * BEAM_R1 * VIENTO_ANCHO + 1.2 * ESC_M) * abre, 2.0);
		for (int k = 0; k < pasos; k++) {
			vec3 c = linea(ro + rd * t);
			polvo += c.z * dl;
			vec3 q_an = ro + rd * t - P.contacto.xyz;
			if (con_anillos && dot(q_an, q_an) < R2_ANILLOS) {        // solo cerca del contacto (los lazos no pasan de ~2,5 R1 de el)
				vec2 an = anillos(ro + rd * t, abre);
				if (an.x < m_an) { m_an = an.x; t_an = t; }
			}
			if (c.y > UMBRAL) {
				float punt = c.x / (c.y - UMBRAL + 0.05);
				if (punt < mejor) { mejor = punt; t_mejor = t; }
			}
			t += dl;
		}
		float a_v = 0.0;
		vec3 c_v = vec3(0.0);
		if (mejor < 1e8) {
			// afinar: busqueda ternaria en ± un paso alrededor del mejor punto
			float a = max(t_mejor - dl, tNear), b = min(t_mejor + dl, tFar);
			for (int j = 0; j < 6; j++) {
				float m1 = mix(a, b, 0.382), m2 = mix(a, b, 0.618);
				if (linea(ro + rd * m1).x < linea(ro + rd * m2).x) b = m2; else a = m1;
			}
			vec3 f = linea(ro + rd * (0.5 * (a + b)));
			// 11/11 (3070): ANTIALIAS. A media resolucion el trazo (unos 0,06 radios de grueso) cae en uno o dos pixeles y el borde duro salia en escalera.
			// Se mide lo que ocupa un pixel del volumen a esa distancia (con el rayo del pixel vecino: vale para la camara ortogonal del juego y la de perspectiva
			// del lab), se pasa a unidades de etiqueta (radios de la rafaga) y el borde se suaviza en ese ancho; si el trazo es mas fino que el pixel, se ensancha
			// hasta el pixel y se aclara en la misma proporcion (cobertura), en vez de romperse en puntos.
			vec3 p_f = ro + rd * (0.5 * (a + b));
			vec2 ndc2 = ndc + vec2(2.0 / V.tam.x, 0.0);
			vec4 a5 = V.inv_vp * vec4(ndc2, -1.0, 1.0);
			vec4 b5 = V.inv_vp * vec4(ndc2, 1.0, 1.0);
			vec3 ro2 = a5.xyz / a5.w;
			vec3 rd2 = normalize(b5.xyz / b5.w - ro2);
			float pix = length(p_f - (ro2 + rd2 * dot(p_f - ro2, rd2)));
			vec3 ab_f = P.target.xyz - P.nozzle.xyz;
			float tt_f = clamp(dot(p_f - P.nozzle.xyz, ab_f) / dot(ab_f, ab_f), 0.0, 1.0);
			float aa = 0.5 * pix / (mix(BEAM_R0, BEAM_R1, tt_f) * VIENTO_ANCHO);
			float fuerza = smoothstep(UMBRAL, UMBRAL + 0.45, f.y);        // 0 en las puntas del trazo, 1 en su cuerpo
			// 11/11: JIRONES. El trazo engorda y adelgaza a lo largo (como una tira que se retuerce) y, al soltar, se rompe en trozos que se adelgazan y se van
			// en DISUELVE s (los trozos los marca un ruido fijo en el espacio; el aire se lleva lo que queda).
			vec3 d_e = eje_dir();
			float jiron = textureLod(ruido_a, vec2(dot(p_f, d_e) * 0.11 / ESC_M - TIEMPO_V * 0.35, dot(p_f, vec3(0.31, 0.71, 0.13)) * 0.2 / ESC_M), 0.0).r;
			fuerza *= 0.45 + 0.9 * jiron;
			float rompe = 1.0;
			if (dis > 0.0) {
				float trozo = textureLod(ruido_b, p_f.xz * 0.21 / ESC_M + vec2(p_f.y * 0.17 / ESC_M, 0.0), 0.0).r;
				rompe = smoothstep(dis * 0.95 - 0.05, dis * 0.95 + 0.08, trozo) * (1.0 - smoothstep(0.75, 1.0, dis));
				fuerza *= 1.0 - 0.6 * dis;
			}
			float gr = GROSOR * (0.25 + 0.75 * min(fuerza, 1.0));
			float borde = max(gr * 0.85, aa);                               // radio del trazo (el de antes: la mitad del borde entre 0,7 y 1 gr), al menos medio pixel
			float cob = min(gr * 0.85 / borde, 1.0);
			float trazo = (1.0 - smoothstep(borde - max(gr * 0.15, aa), borde + aa, f.x)) * cob * smoothstep(UMBRAL, UMBRAL + 0.08, f.y);
			float velo = (1.0 - smoothstep(gr, gr * 3.2 + aa, f.x)) * fuerza * K_VELO;
			a_v = max(trazo * OPACIDAD, velo) * rompe;
			c_v = mix(color_paleta(1), color_paleta(2), trazo);
		}
		// ANILLOS del vortice: el lazo mas cercano al rayo de vista, afinado como el trazo, con su propio antialias (en unidades del dominio)
		if (con_anillos && m_an < 1e8) {
			float a = max(t_an - dl, tNear), b = min(t_an + dl, tFar);
			for (int j = 0; j < 6; j++) {
				float m1 = mix(a, b, 0.382), m2 = mix(a, b, 0.618);
				if (anillos(ro + rd * m1, abre).x < anillos(ro + rd * m2, abre).x) b = m2; else a = m1;
			}
			vec3 p_a = ro + rd * (0.5 * (a + b));
			vec2 an = anillos(p_a, abre);
			vec2 ndc3 = ndc + vec2(2.0 / V.tam.x, 0.0);
			vec4 a6 = V.inv_vp * vec4(ndc3, -1.0, 1.0);
			vec4 b6 = V.inv_vp * vec4(ndc3, 1.0, 1.0);
			vec3 ro3 = a6.xyz / a6.w;
			vec3 rd3 = normalize(b6.xyz / b6.w - ro3);
			float pix_a = length(p_a - (ro3 + rd3 * dot(p_a - ro3, rd3)));
			float gr_a = GROSOR * BEAM_R1 * VIENTO_ANCHO * 1.5 * (0.3 + 0.7 * an.y) * (1.0 - 0.7 * dis);
			float borde_a = max(gr_a, 0.5 * pix_a);
			float cob_a = min(gr_a / borde_a, 1.0);
			float lazo = (1.0 - smoothstep(borde_a - 0.5 * pix_a, borde_a + 0.5 * pix_a, an.x)) * cob_a * smoothstep(0.02, 0.2, an.y)
				* K_ANILLOS * (1.0 - smoothstep(0.0, 0.7, dis));
			float velo_a = (1.0 - smoothstep(gr_a, gr_a * 3.0 + pix_a, an.x)) * an.y * K_VELO * (1.0 - dis);
			float a_l = max(lazo * OPACIDAD, velo_a);
			c_v = (c_v * a_v * (1.0 - a_l) + mix(color_paleta(1), color_paleta(2), lazo) * a_l) / max(a_v + a_l - a_v * a_l, 1e-4);
			a_v = a_v + a_l - a_v * a_l;
		}
		// BRILLO EN LA MANO (referencia: un resplandor blanco donde nace el haz): disco blando alrededor de la boquilla, en dos escalones (nucleo blanco y halo
		// claro), que respira un poco; se apaga en un cuarto de segundo al soltar. Lo tapa lo que haya delante (profundidad de la escena).
		float k_m = K_MANO * (T_CORTE < 0.0 ? BEAM_ON : max(1.0 - T_CORTE / 0.25, 0.0));
		if (k_m > 0.0) {
			float t_m = dot(P.nozzle.xyz - ro, rd);
			if (t_m > 0.0 && t_m < tFar + 0.5 * ESC_M) {
				float dm = length(ro + rd * t_m - P.nozzle.xyz);
				float rm = 1.0 * ESC_M * (1.0 + 0.07 * sin(TIEMPO_V * 11.0)) * (0.7 + 0.3 * k_m);
				float nucleo_m = 1.0 - smoothstep(rm * 0.24, rm * 0.32, dm);
				float halo_m = 1.0 - smoothstep(rm * 0.3, rm, dm);
				float a_m = max(nucleo_m * 0.95, halo_m * halo_m * 0.6) * k_m;          // nucleo blanco y halo blando
				vec3 c_m = mix(color_paleta(1), color_paleta(2), max(nucleo_m, 0.4));
				c_v = (c_v * a_v * (1.0 - a_m) + c_m * a_m) / max(a_v + a_m - a_v * a_m, 1e-4);
				a_v = a_v + a_m - a_v * a_m;
			}
		}
		float a_p = smoothstep(0.06, 0.16, polvo) * K_POLVO;
		vec3 c_p = mix(color_paleta(4), color_paleta(3), smoothstep(0.16, 0.2, polvo));
		color = c_v * a_v + c_p * a_p * (1.0 - a_v);
		trans = (1.0 - a_v) * (1.0 - a_p);
	}
	imageStore(crudo, gid, vec4(color, trans));
}
