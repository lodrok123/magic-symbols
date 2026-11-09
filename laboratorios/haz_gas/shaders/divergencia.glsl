#[compute]
#version 450
// PORT de src/gas/project.js: divergence (lejrimostfa/force-field-vfx-threejs, MIT). Proyeccion de presion: el vecino solido refleja la presion y aporta velocidad 0,
// lo que da deslizamiento libre en el escudo. El suelo tambien es solido. Las otras caras estan abiertas (presion 0 alli).
// (vel1, prs0) -> prs1: x presion de arranque (la del paso anterior * 0,96), y divergencia - expansion, z solido.
layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
#include "gas_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler3D vel_in;
layout(set = 0, binding = 1) uniform sampler3D prs_prev;
layout(set = 0, binding = 2, rgba32f) uniform restrict writeonly image3D prs_out;

bool solido(vec3 w) { vec3 n; return obst_sd(w, n) < 0.0; }

float flujo_cara(ivec3 c, vec3 w, int x, int y, int z, int eje) {
	vec3 off = vec3(x, y, z) * H;
	vec4 v = texelFetch(vel_in, cerca(c, x, y, z), 0);
	return solido(w + off) ? 0.0 : v[eje];
}

void main() {
	ivec3 c = celda();
	if (fuera_de_rejilla(c)) return;
	vec3 w = mundo_de(uvw_de(c));
	float suelo = c.y == 0 ? 0.0 : flujo_cara(c, w, 0, -1, 0, 1);
	float div = (flujo_cara(c, w, 1, 0, 0, 0) - flujo_cara(c, w, -1, 0, 0, 0)
		+ flujo_cara(c, w, 0, 1, 0, 1) - suelo
		+ flujo_cara(c, w, 0, 0, 1, 2) - flujo_cara(c, w, 0, 0, -1, 2)) / (2.0 * H)
		- texelFetch(vel_in, c, 0).w;
	// Arranque en caliente: la presion del paso anterior es una buena primera aproximacion para un flujo que cambia despacio.
	imageStore(prs_out, c, vec4(texelFetch(prs_prev, c, 0).x * 0.96, div, solido(w) ? 1.0 : 0.0, 0.0));
}
