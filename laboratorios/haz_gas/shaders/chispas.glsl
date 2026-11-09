#[compute]
#version 450
// PORT de src/render/sparks.js: update (lejrimostfa/force-field-vfx-threejs, MIT). Chispas en GPU: nacen alrededor del choque, montan la velocidad del gas con inercia,
// caen y rebotan en el suelo y en el escudo. Estado en una imagen rgba32f de N x 2: fila 0 = posicion (w = vida que queda), fila 1 = velocidad (w = grosor aleatorio).
// Diferencia: el escudo es el obstaculo con SDF (esfera, caja o nada); la direccion «(1.2, 0, 0)» de la demo (hacia el lanzador) sale aqui de la boquilla.
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
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
		if (BEAM_ON < 0.5) Pp.y = -10.0;
	} else {
		vec3 uvw = (Pp.xyz - WLO) / WTAM;
		vec3 air = textureLod(vel, uvw, 0.0).xyz;
		vec3 v = mix(V.xyz, air, DT * 1.6) + vec3(0.0, -7.0, 0.0) * DT;
		Pp.xyz += v * DT;
		if (Pp.y < 0.04) { Pp.y = 0.04; v.y = abs(v.y) * 0.35; }
		if (Pp.z < WLO.z + 0.1) { v.z = abs(v.z) * 0.3; }
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
