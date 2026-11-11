#[compute]
#version 450
// PORT de src/render/sparks.js: update (lejrimostfa/force-field-vfx-threejs, MIT). Chispas en GPU: nacen alrededor del choque, montan la velocidad del gas con inercia,
// caen y rebotan en el suelo y en el escudo. Estado en una imagen rgba32f de N x 2: fila 0 = posicion (w = vida que queda), fila 1 = velocidad (w = grosor aleatorio).
// Diferencia: el escudo es el obstaculo con SDF (esfera, caja o nada); la direccion «(1.2, 0, 0)» de la demo (hacia el lanzador) sale aqui de la boquilla.
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
#define CON_SOLIDO
#include "gas_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler3D vel;
layout(set = 0, binding = 1, rgba32f) uniform restrict image2D estado;

// hash() de three/tsl (PCG, shadertoy XlGcRh): el mismo numero para la misma semilla.
float hash_tsl(float seed) {
	uint state = uint(seed) * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	uint result = (word >> 22u) ^ word;
	return float(result) * (1.0 / 4294967296.0);
}

// Si p esta dentro del obstaculo, lo saca moviendolo solo en x y z (sin bajarlo del suelo) y quita a v lo que entra.
vec3 sacar_en_horizontal(vec3 p, inout vec3 v) {
	vec3 n;
	if (obst_sd(p, n) >= 0.0 || OBST_TIPO > 1.5) return p;
	vec3 d = p - P.obst_c.xyz;
	if (OBST_TIPO < 0.5) {
		vec2 dh = d.xz;
		float rh = sqrt(max(OBST_R * OBST_R - d.y * d.y, 0.0)) + 0.002;
		vec2 u = length(dh) > 1e-4 ? normalize(dh) : vec2(1.0, 0.0);
		p.xz = P.obst_c.xz + u * rh;
		vec3 nh = vec3(u.x, 0.0, u.y);
		v -= nh * min(dot(v, nh), 0.0) * 1.5;
		return p;
	}
	// caja: por el eje horizontal (x o z de la caja) que menos tiene que salir
	vec3 q = vec3(dot(d, P.obst_ex.xyz), dot(d, P.obst_ey.xyz), dot(d, P.obst_ez.xyz));
	vec3 h = P.obst_h.xyz;
	vec3 eje = (h.x - abs(q.x)) < (h.z - abs(q.z)) ? P.obst_ex.xyz * sign(q.x) : P.obst_ez.xyz * sign(q.z);
	float falta = (h.x - abs(q.x)) < (h.z - abs(q.z)) ? h.x - abs(q.x) : h.z - abs(q.z);
	p += eje * (falta + 0.002);
	v -= eje * min(dot(v, eje), 0.0) * 1.5;
	return p;
}

void main() {
	int i = int(gl_GlobalInvocationID.x);
	if (i >= R.res.x) return;
	vec4 Pp = imageLoad(estado, ivec2(i, 0));
	vec4 V = imageLoad(estado, ivec2(i, 1));
	Pp.w -= DT;
	vec3 hacia = normalize((P.nozzle.xyz - P.obst_c.xyz) * vec3(1.0, 0.0, 1.0));
	if (Pp.w <= 0.0) {
		float seed = float(i) + TIEMPO * 61.7;
		vec3 rnd = (vec3(hash_tsl(seed), hash_tsl(seed + 13.1), hash_tsl(seed + 29.3)) - 0.5) * 2.0;
		vec3 front = normalize(rnd + hacia * 1.2);
		// Demo: shieldC + front * (R + 0.15). Con SDF: se lleva el punto a 0,15 de la piel por su gradiente (con la esfera es lo mismo).
		vec3 p0 = P.obst_c.xyz + front * (OBST_TIPO < 0.5 ? OBST_R : max(P.obst_h.x, max(P.obst_h.y, P.obst_h.z)));
		if (OBST_TIPO > 1.5) p0 = P.contacto.xyz;
		vec3 n;
		float sd = obst_sd(p0, n);
		if (OBST_TIPO < 1.5) p0 -= n * (sd - 0.15);
		// Diferencia: en la demo las que nacen por debajo de la esfera (centro a 2 m, radio 2,1) pasan un fotograma bajo el suelo, tapadas por el.
		// Aqui nacen ya encima (la prueba pide que ninguna atraviese el suelo).
		p0.y = max(p0.y, 0.04);
		vec3 v_tmp = vec3(0.0);
		p0 = sacar_en_horizontal(p0, v_tmp);
		Pp = vec4(p0, hash_tsl(seed + 47.7) * 1.8 + 0.5);
		V = vec4(front * 3.0 + rnd * 6.0 - hacia * 4.0 + vec3(0.0, 2.0, 0.0), hash_tsl(seed + 3.3));
		// 11/11 (choque con identidad, Pablo: «en vez de los puntitos del fuego, chispas para el rayo y gotas de agua para el agua»). El FUEGO no pasa por aqui.
		vec3 dir_h = normalize(P.target.xyz - P.nozzle.xyz);
		if (RAYO) {
			// CHISPAS ELECTRICAS: nacen en el punto de contacto, salen muy deprisa y viven poco (0,12-0,45 s); al vuelo QUIEBRAN la direccion (zigzag, ver abajo)
			vec3 q0 = P.contacto.xyz + rnd * 0.12 * ESC_M;
			vec3 nq;
			float sq = obst_sd(q0, nq);
			if (sq < 0.08 * ESC_M) q0 += nq * (0.08 * ESC_M - sq);
			q0.y = max(q0.y, 0.04);
			q0 = sacar_en_horizontal(q0, v_tmp);
			Pp = vec4(q0, hash_tsl(seed + 47.7) * 0.35 + 0.15);
			V = vec4(normalize(rnd + hacia * 0.9 + vec3(0.0, 0.35, 0.0)) * (15.0 + hash_tsl(seed + 5.1) * 10.0), hash_tsl(seed + 3.3));
		} else if (AGUA) {
			// GOTAS: nacen en la salpicadura del contacto y saltan en corona (hacia arriba y hacia los lados, de vuelta hacia el lanzador)
			vec3 q0 = P.contacto.xyz + rnd * 0.22 * ESC_M;
			vec3 nq;
			float sq = obst_sd(q0, nq);
			if (sq < 0.1 * ESC_M) q0 += nq * (0.1 * ESC_M - sq);
			q0.y = max(q0.y, 0.04);
			q0 = sacar_en_horizontal(q0, v_tmp);
			Pp = vec4(q0, hash_tsl(seed + 47.7) * 1.4 + 0.7);
			V = vec4(front * 2.0 + rnd * vec3(3.2, 1.5, 3.2) + hacia * 1.5 + vec3(0.0, 3.6 + hash_tsl(seed + 8.8) * 2.0, 0.0), hash_tsl(seed + 3.3));
		} else if (VIENTO && i % 8 == 2) {
			// MECHONES de aire (dibujados como trazos blancos curvos): con choque, la mitad salen despedidos del CONTACTO, girando alrededor del eje del haz (el
			// vortice); el resto, y todos al aire, nacen a lo largo del chorro y viajan con el.
			float sale = hash_tsl(seed + 61.0);
			vec3 e1 = normalize(cross(dir_h, vec3(0.0, 1.0, 0.0)));
			vec3 e2 = cross(e1, dir_h);
			float ang = hash_tsl(seed + 71.0) * 6.2832;
			vec3 radial = e1 * cos(ang) + e2 * sin(ang);
			vec3 q0;
			vec3 v0;
			if (CHOQUE && sale < 0.5) {
				q0 = P.contacto.xyz - dir_h * 0.25 * ESC_M + radial * (0.35 + 0.4 * hash_tsl(seed + 81.0)) * ESC_M;
				v0 = radial * 4.5 + cross(dir_h, radial) * 9.0 - dir_h * 1.5;
			} else {
				float tt = 0.08 + 0.85 * hash_tsl(seed + 91.0);
				vec3 ab = P.target.xyz - P.nozzle.xyz;
				q0 = P.nozzle.xyz + ab * tt + radial * mix(BEAM_R0, BEAM_R1, tt) * (0.6 + 0.9 * hash_tsl(seed + 81.0));
				v0 = dir_h * BEAM_SPEED * 0.55 + cross(dir_h, radial) * 6.0 + radial * 1.0;
			}
			q0.y = max(q0.y, 0.04);
			q0 = sacar_en_horizontal(q0, v_tmp);
			Pp = vec4(q0, hash_tsl(seed + 47.7) * 0.35 + 0.35);
			V = vec4(v0, hash_tsl(seed + 3.3));
		}
		if (BEAM_ON < 0.5) Pp.y = -10.0;
	} else if ((RAYO || AGUA || (VIENTO && i % 8 == 2)) && Pp.y < -5.0) {
		// nacio con el chorro apagado: sigue escondida hasta su proxima vida (no se sube al suelo)
	} else if (RAYO) {
		// CHISPA ELECTRICA: casi no la frena el aire, cae poco, y cada 1/24 s de vida QUIEBRA su direccion (un tramo recto y un codo: zigzag). Rebota viva.
		vec3 v = V.xyz + vec3(0.0, -3.0, 0.0) * DT;
		if (floor(Pp.w * 24.0) != floor((Pp.w + DT) * 24.0)) {
			float s2 = float(i) * 7.31 + floor(Pp.w * 24.0) * 3.17 + TIEMPO;
			vec3 q = (vec3(hash_tsl(s2 * 97.0), hash_tsl(s2 * 97.0 + 11.0), hash_tsl(s2 * 97.0 + 23.0)) - 0.5) * 2.0;
			float l = length(v);
			v = normalize(v / max(l, 1e-4) + q * 1.1) * l * 0.93;
		}
		Pp.xyz += v * DT;
		if (Pp.y < 0.04) { Pp.y = 0.04; v.y = abs(v.y) * 0.6; }
		vec3 n;
		float d = obst_sd(Pp.xyz, n);
		if (d < 0.0) {
			Pp.xyz -= n * d;
			v -= n * min(dot(v, n), 0.0) * 1.8;
		}
		Pp.xyz = sacar_en_horizontal(Pp.xyz, v);
		V.xyz = v;
	} else if (AGUA) {
		// GOTA: gravedad de verdad y un poco de aire. Al tocar el SUELO se vuelve una SALPICADURA (anillo plano que se abre, 0,3 s: V.w < -0,5 la marca, con su
		// grosor en -(1 + V.w)); al tocar el SOLIDO se parte en una gotita mas pequena (la mitad de gruesa) que sale despedida por la cara.
		if (V.w < -0.5) {
			// salpicadura: quieta en el suelo hasta que se acaba su vida
		} else {
			vec3 uvw = (Pp.xyz - WLO) / WTAM;
			vec3 air = textureLod(vel, uvw, 0.0).xyz;
			vec3 v = mix(V.xyz, air, DT * 0.7) + vec3(0.0, -11.0, 0.0) * DT;
			Pp.xyz += v * DT;
			vec3 n;
			float d = obst_sd(Pp.xyz, n);
			if (d < 0.0) {
				Pp.xyz -= n * d;
				float s3 = float(i) * 3.7 + TIEMPO * 13.0;
				vec3 q = (vec3(hash_tsl(s3 * 31.0), hash_tsl(s3 * 31.0 + 5.0), hash_tsl(s3 * 31.0 + 9.0)) - 0.5) * 2.0;
				v -= n * min(dot(v, n), 0.0) * 1.3;
				v += (n * 1.5 + (q - n * dot(q, n)) * 2.5 + vec3(0.0, 1.2, 0.0));
				V.w = max(V.w * 0.5, 0.0);
			}
			Pp.xyz = sacar_en_horizontal(Pp.xyz, v);
			if (Pp.y < 0.04) {
				Pp.y = 0.04;
				Pp.w = min(Pp.w, 0.3);
				V.w = -1.0 - clamp(V.w, 0.0, 0.999);
				v = vec3(0.0);
			}
			V.xyz = v;
		}
	} else if (VIENTO && i % 8 == 2) {
		// MECHON: sin peso, sigue al aire de cerca (el vortice del choque lo hace girar y lo despide)
		vec3 uvw = (Pp.xyz - WLO) / WTAM;
		vec3 air = textureLod(vel, uvw, 0.0).xyz;
		vec3 v = mix(V.xyz, air, DT * 2.5);
		Pp.xyz += v * DT;
		if (Pp.y < 0.04) { Pp.y = 0.04; v.y = abs(v.y) * 0.5; }
		vec3 n;
		float d = obst_sd(Pp.xyz, n);
		if (d < 0.0) {
			Pp.xyz -= n * d;
			v -= n * min(dot(v, n), 0.0);
		}
		Pp.xyz = sacar_en_horizontal(Pp.xyz, v);
		V.xyz = v;
	} else {
		vec3 uvw = (Pp.xyz - WLO) / WTAM;
		vec3 air = textureLod(vel, uvw, 0.0).xyz;
		vec3 v = mix(V.xyz, air, DT * 1.6) + vec3(0.0, -7.0, 0.0) * DT;
		Pp.xyz += v * DT;
		if (Pp.y < 0.04) { Pp.y = 0.04; v.y = abs(v.y) * 0.35; }
		if (P.k4.z > 0.5 && Pp.z < WLO.z + 0.1) { v.z = abs(v.z) * 0.3; }        // el acantilado (k4.z = 0 en la vista de juego, donde no se dibuja)
		vec3 n;
		float d = obst_sd(Pp.xyz, n);
		if (d < 0.0) {
			Pp.xyz -= n * d;
			v -= n * min(dot(v, n), 0.0) * 1.5;
		}
		// Diferencia con la demo: su esfera (centro a 2 m, radio 2,1) entra 0,1 m en el suelo, asi que hay un disco del suelo DENTRO del escudo; empujar por la
		// normal ahi mete la chispa bajo el suelo (en la demo no se ve: el suelo la tapa). Aqui: suelo primero y, si sigue dentro, se saca EN HORIZONTAL.
		if (Pp.y < 0.04) { Pp.y = 0.04; v.y = abs(v.y) * 0.35; }
		Pp.xyz = sacar_en_horizontal(Pp.xyz, v);
		V.xyz = v;
	}
	imageStore(estado, ivec2(i, 0), Pp);
	imageStore(estado, ivec2(i, 1), V);
}
