#[compute]
#version 450
// PORT de src/gas/project.js: project (lejrimostfa/force-field-vfx-threejs, MIT). Resta el gradiente de presion; el fluido nunca empuja a traves del suelo. (vel1, prs0) -> vel0.
layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
#include "gas_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler3D vel_in;
layout(set = 0, binding = 1) uniform sampler3D prs;
layout(set = 0, binding = 2, rgba16f) uniform restrict writeonly image3D dst;

float grad(ivec3 c, vec4 me, int x, int y, int z, bool guarda_suelo) {
	vec4 a = texelFetch(prs, cerca(c, x, y, z), 0);
	vec4 b = texelFetch(prs, cerca(c, -x, -y, -z), 0);
	float pa = a.z > 0.5 ? me.x : a.x;
	float pb = (b.z > 0.5 || guarda_suelo) ? me.x : b.x;
	return pa - pb;
}

void main() {
	ivec3 c = celda();
	if (fuera_de_rejilla(c)) return;
	vec4 me = texelFetch(prs, c, 0);
	vec3 g3 = vec3(grad(c, me, 1, 0, 0, false), grad(c, me, 0, 1, 0, c.y == 0), grad(c, me, 0, 0, 1, false)) / (2.0 * H);
	vec4 v = texelFetch(vel_in, c, 0);
	vec3 o = (v.xyz - g3) * (1.0 - me.z);
	float y = c.y == 0 ? max(o.y, 0.0) : o.y;
	imageStore(dst, c, vec4(o.x, y, o.z, 0.0));
}
