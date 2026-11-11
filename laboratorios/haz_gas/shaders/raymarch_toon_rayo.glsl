#[compute]
#version 450
// MODO TOON DEL RAYO (11/11/2026). La SIMULACION es la del port de lejrimostfa/force-field-vfx-threejs (MIT) en modo rayo (gas.x = ionizacion; ver RAYO en gas_comun.glslinc).
// Un rayo no es un gas: lo que se simula es el AIRE CARGADO, que dice DONDE puede haber electricidad (el nucleo del haz, la mancha del choque y la piel del solido que el
// gas rodea). El dibujo pone tres cosas, de dentro a fuera con RayoPaleta (NUCLEO blanco → CUERPO amarillo → HALO azul):
//   · el TRAZO principal y dos ramas: zigzag de la mano al contacto (desvio por ruido que SALTA cada 1/14 s, nulo en los extremos); a lo largo del rayo de vista se
//     busca la distancia minima al trazo y se afina (el trazo sale nitido aunque el paso sea de una celda);
//   · ARCOS que reptan dentro del aire cargado: la curva donde dos componentes del flujo sin divergencia horneado (flujo_48, el de la turbulencia del solver) se anulan
//     a la vez; como el gas envuelve el solido, los arcos se ciñen a su piel de verdad. Tambien se afinan.
//   · HALO: la ionizacion acumulada, en tres escalones planos de azul.
// Es el unico elemento que BRILLA: nucleo y cuerpo tapan el fondo (se leen sobre la hierba clara) y el halo se suma. Colores en «paleta» (8 x 1): 0 NUCLEO, 1 CUERPO,
// 2 HALO_BORDE, 3 HALO, 4 HALO_HONDO. Salida igual que los otros raymarch (rgb premultiplicado, a = lo que queda del fondo).
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
#include "gas_comun.glslinc"
#include "vista_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler3D gas;
layout(set = 0, binding = 1) uniform sampler3D flujo;        // flujo_48 (repite): aqui NO es la velocidad
layout(set = 0, binding = 2) uniform sampler2D profundidad;
layout(set = 0, binding = 3) uniform sampler2D ruido_a;      // T_PerlinNoise_Tiled
layout(set = 0, binding = 4) uniform sampler2D ruido_b;      // T_Noise1_tiled
layout(set = 0, binding = 5) uniform sampler2D ruido_c;
layout(set = 0, binding = 6) uniform sampler2D paleta;
layout(set = 0, binding = 7, rgba16f) uniform restrict writeonly image2D crudo;

#define GROSOR V.toon0.x          // radio del nucleo del trazo (u)
#define ZIGZAG V.toon0.y          // desvio del trazo (u, por M)
#define K_HALO V.toon0.z
#define K_ARCOS V.toon0.w
#define K_T V.toon1.x
#define SALTOS V.toon1.y          // redibujos por segundo
#define GROSOR_ARCO V.toon1.z
#define PERIODO V.toon1.w         // periodo del flujo de los arcos (u, por M)
#define UMBRAL_ARCO V.toon2.x
#define BRILLO V.toon2.y
#define RAMAS V.toon2.z
#define T_TOON V.toon2.w
#define OPACIDAD V.toon3.x

vec3 srgb_a_lineal(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 color_paleta(int i) { return srgb_a_lineal(textureLod(paleta, vec2((float(i) + 0.5) / 8.0, 0.5), 0.0).rgb); }
float hash1(float n) { return fract(sin(n * 127.1) * 43758.5453); }

vec3 g_noz, g_ab, g_e1, g_e2;
float g_salto;

vec2 hash2(float n) { return fract(sin(vec2(n * 127.1, n * 311.7 + 1.3)) * 43758.5453) * 2.0 - 1.0; }
// desvio lineal a trozos: valores al azar en los nudos enteros de k
vec2 nudo(float k, float semilla) {
	float i0 = floor(k);
	return mix(hash2(i0 + semilla * 13.0), hash2(i0 + 1.0 + semilla * 13.0), k - i0);
}

// Distancia de p a cada uno de los tres trazos (principal, rama 1, rama 2).
vec3 dist_trazos(vec3 p) {
	float tt = clamp(dot(p - g_noz, g_ab) / dot(g_ab, g_ab), 0.0, 1.0);
	vec3 base = g_noz + g_ab * tt;
	// lejos del eje no hay trazo posible (el desvio maximo es ZIGZAG · 2,2 · 1,28): ni se calcula
	if (length(p - base) > (ZIGZAG * 3.0 + GROSOR * 8.0) * ESC_M) return vec3(1e3);
	float env = pow(sin(3.14159 * tt), 0.55);
	vec3 d;
	for (int i = 0; i < 3; i++) {
		// tramos RECTOS entre nudos al azar (9 tramos gordos + 27 finos): un zigzag anguloso, no una onda
		float s = g_salto * 17.0 + float(i) * 71.0;
		vec2 o = nudo(tt * 9.0, s) + nudo(tt * 27.0, s + 5.0) * 0.28;
		float amp = ZIGZAG * ESC_M * env * (i == 0 ? 1.0 : 2.2);
		vec3 centro = base + (g_e1 * o.x + g_e2 * o.y) * amp;
		d[i] = length(p - centro);
	}
	return d;
}

// Arcos: g = a² + b² del flujo (0 en la curva donde las dos componentes se anulan). El flujo se desplaza a saltos (los arcos brincan) y deriva despacio (reptan).
float arco_g(vec3 p) {
	vec3 q = p / (PERIODO * ESC_M);
	vec2 zz = vec2(textureLod(ruido_b, q.xy * 1.9 + g_salto * 0.11, 0.0).r, textureLod(ruido_b, q.zy * 1.9 + 0.37 - g_salto * 0.07, 0.0).r) - 0.5;
	q += vec3(zz.x, zz.y, zz.x - zz.y) * 0.035;
	vec3 f = textureLod(flujo, q + vec3(hash1(g_salto) * 0.09, T_TOON * 0.05, hash1(g_salto + 7.0) * 0.09), 0.0).xyz * 2.0 - 1.0;
	return dot(f.xy, f.xy);
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
		g_noz = P.nozzle.xyz;
		g_ab = P.contacto.xyz - P.nozzle.xyz;
		vec3 dir = normalize(g_ab);
		g_e1 = normalize(cross(dir, vec3(0.0, 1.0, 0.0)));
		g_e2 = cross(g_e1, dir);
		g_salto = floor(T_TOON * SALTOS);
		int pasos = int(V.marcha.x);
		if (V.toon3.w > 0.0) pasos = clamp(int(ceil((tFar - tNear) / (1.3 * V.toon3.w))), 24, 160);
		float dl = (tFar - tNear) / float(pasos);
		float halo = 0.0;
		vec3 d_min = vec3(1e9);
		vec3 t_min = vec3(tNear);
		float arco_min = 1e9, t_arco = tNear, ion_arco = 0.0;
		float t = tNear + dl * 0.5;
		for (int k = 0; k < pasos; k++) {
			vec3 pos = ro + rd * t;
			float ion = textureLod(gas, (pos - WLO) / WTAM, 0.0).x * K_T;
			halo += ion * dl;
			vec3 d = dist_trazos(pos);
			for (int i = 0; i < 3; i++) if (d[i] < d_min[i]) { d_min[i] = d[i]; t_min[i] = t; }
			if (ion > UMBRAL_ARCO) {
				float g = arco_g(pos) / (ion - UMBRAL_ARCO + 0.05);
				if (g < arco_min) { arco_min = g; t_arco = t; ion_arco = ion; }
			}
			t += dl;
		}
		// afinar: busqueda ternaria en ± un paso alrededor del mejor punto de cada trazo y del arco
		for (int i = 0; i < 3; i++) {
			if (d_min[i] > GROSOR * ESC_M * 8.0 + dl) continue;          // este rayo de vista no pasa cerca del trazo: sin afinar
			float a = max(t_min[i] - dl, tNear), b = min(t_min[i] + dl, tFar);
			for (int j = 0; j < 5; j++) {
				float m1 = mix(a, b, 0.382), m2 = mix(a, b, 0.618);
				if (dist_trazos(ro + rd * m1)[i] < dist_trazos(ro + rd * m2)[i]) b = m2; else a = m1;
			}
			d_min[i] = min(d_min[i], dist_trazos(ro + rd * (0.5 * (a + b)))[i]);
		}
		float g_fin = 1e9;
		if (arco_min < 1e8) {
			float a = max(t_arco - dl, tNear), b = min(t_arco + dl, tFar);
			for (int j = 0; j < 5; j++) {
				float m1 = mix(a, b, 0.382), m2 = mix(a, b, 0.618);
				if (arco_g(ro + rd * m1) < arco_g(ro + rd * m2)) b = m2; else a = m1;
			}
			g_fin = arco_g(ro + rd * (0.5 * (a + b)));
		}
		// TRAZOS: nucleo (tapa), cuerpo (tapa a medias) y resplandor (se suma). Las ramas, mas finas, parpadean por redibujo.
		float nucleo = 0.0, cuerpo = 0.0, brillo = 0.0;
		for (int i = 0; i < 3; i++) {
			float on = BEAM_ON * (i == 0 ? 1.0 : RAMAS * step(0.35, hash1(g_salto + float(i) * 3.1)));
			float gr = GROSOR * ESC_M * (i == 0 ? 1.0 : 0.5);
			nucleo = max(nucleo, on * (1.0 - smoothstep(gr * 0.75, gr, d_min[i])));
			cuerpo = max(cuerpo, on * (1.0 - smoothstep(gr * 1.9, gr * 2.3, d_min[i])));
			brillo += on * gr * gr * 9.0 / (d_min[i] * d_min[i] + gr * gr * 9.0);
		}
		// ARCOS dentro del aire cargado
		float ga = GROSOR_ARCO * GROSOR_ARCO;
		float gate = smoothstep(UMBRAL_ARCO, UMBRAL_ARCO + 0.25, ion_arco) * K_ARCOS;
		float arco_n = gate * (1.0 - smoothstep(ga * 0.7, ga, g_fin));
		float arco_c = gate * (1.0 - smoothstep(ga * 3.0, ga * 4.0, g_fin));
		nucleo = max(nucleo, arco_n);
		cuerpo = max(cuerpo, arco_c);
		brillo += gate * ga * 10.0 / (g_fin + ga * 10.0) * 0.6;
		// HALO: ionizacion acumulada en tres escalones
		float h = 1.0 - exp(-halo * K_HALO);
		float h3 = (smoothstep(0.10, 0.14, h) + smoothstep(0.32, 0.36, h) + smoothstep(0.6, 0.64, h)) / 3.0;
		vec3 c_halo = mix(color_paleta(4), mix(color_paleta(3), color_paleta(2), smoothstep(0.5, 0.9, h3)), smoothstep(0.2, 0.5, h3)) * h3;
		vec3 c_brillo = color_paleta(3) * clamp(brillo, 0.0, 1.5) * 0.55;
		float tapa = clamp(max(nucleo, cuerpo * 0.8) * OPACIDAD, 0.0, 1.0);
		vec3 c_trazo = mix(color_paleta(1), color_paleta(0), nucleo) * BRILLO;
		color = c_trazo * tapa + (c_halo * 0.8 + c_brillo) * (1.0 - tapa);
		trans = (1.0 - tapa) * (1.0 - 0.35 * h3);
	}
	imageStore(crudo, gid, vec4(color, trans));
}
