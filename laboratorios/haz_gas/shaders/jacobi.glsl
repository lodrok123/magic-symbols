#[compute]
#version 450
// PORT de src/gas/project.js: jacobi (lejrimostfa/force-field-vfx-threejs, MIT). Una iteracion de Jacobi de la ecuacion de Poisson de la presion: src -> dst.
layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
#include "gas_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler3D src;
layout(set = 0, binding = 1, rgba32f) uniform restrict writeonly image3D dst;

float abierta(ivec3 c, vec4 me, int x, int y, int z, bool borde) {
	vec4 n = texelFetch(src, cerca(c, x, y, z), 0);
	float dentro = n.z > 0.5 ? me.x : n.x;
	return borde ? 0.0 : dentro;
}

void main() {
	ivec3 c = celda();
	if (fuera_de_rejilla(c)) return;
	vec4 me = texelFetch(src, c, 0);
	ivec3 top = R.res.xyz - 1;
	float xLo = abierta(c, me, -1, 0, 0, c.x == 0);
	float xHi = abierta(c, me, 1, 0, 0, c.x == top.x);
	float yLo = c.y == 0 ? me.x : abierta(c, me, 0, -1, 0, false);
	float yHi = abierta(c, me, 0, 1, 0, c.y == top.y);
	float zLo = abierta(c, me, 0, 0, -1, c.z == 0);
	float zHi = abierta(c, me, 0, 0, 1, c.z == top.z);
	float p = (xLo + xHi + yLo + yHi + zLo + zHi - me.y * H * H) / 6.0;
	imageStore(dst, c, vec4(p, me.y, me.z, 0.0));
}
