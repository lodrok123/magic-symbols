#[compute]
#version 450
// PORT de src/gas/forces.js: curl (lejrimostfa/force-field-vfx-threejs, MIT). Vorticidad por diferencias centradas: vel0 -> curl (xyz, w = longitud).
layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
#include "gas_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler3D vel_in;
layout(set = 0, binding = 1, rgba16f) uniform restrict writeonly image3D dst;

void main() {
	ivec3 c = celda();
	if (fuera_de_rejilla(c)) return;
	vec4 x0 = texelFetch(vel_in, cerca(c, -1, 0, 0), 0), x1 = texelFetch(vel_in, cerca(c, 1, 0, 0), 0);
	vec4 y0 = texelFetch(vel_in, cerca(c, 0, -1, 0), 0), y1 = texelFetch(vel_in, cerca(c, 0, 1, 0), 0);
	vec4 z0 = texelFetch(vel_in, cerca(c, 0, 0, -1), 0), z1 = texelFetch(vel_in, cerca(c, 0, 0, 1), 0);
	vec3 w = vec3((y1.z - y0.z) - (z1.y - z0.y), (z1.x - z0.x) - (x1.z - x0.z), (x1.y - x0.y) - (y1.x - y0.x)) / (2.0 * H);
	imageStore(dst, c, vec4(w, length(w)));
}
