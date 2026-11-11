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
		for (int k = 0; k < pasos; k++) {
			vec3 c = linea(ro + rd * t);
			polvo += c.z * dl;
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
			float fuerza = smoothstep(UMBRAL, UMBRAL + 0.45, f.y);        // 0 en las puntas del trazo, 1 en su cuerpo
			float gr = GROSOR * (0.25 + 0.75 * fuerza);
			float trazo = (1.0 - smoothstep(gr * 0.7, gr, f.x)) * smoothstep(UMBRAL, UMBRAL + 0.08, f.y);
			float velo = (1.0 - smoothstep(gr, gr * 3.2, f.x)) * fuerza * K_VELO;
			a_v = max(trazo * OPACIDAD, velo);
			c_v = mix(color_paleta(1), color_paleta(2), trazo);
		}
		float a_p = smoothstep(0.06, 0.16, polvo) * K_POLVO;
		vec3 c_p = mix(color_paleta(4), color_paleta(3), smoothstep(0.16, 0.2, polvo));
		color = c_v * a_v + c_p * a_p * (1.0 - a_v);
		trans = (1.0 - a_v) * (1.0 - a_p);
	}
	imageStore(crudo, gid, vec4(color, trans));
}
