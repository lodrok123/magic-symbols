#[compute]
#version 450
// PORT de src/gas/advect.js: advectVel (lejrimostfa/force-field-vfx-threejs, MIT). Semi-Lagrangiana a proposito (ver advecta.glslinc): vel0 -> vel1.
layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
#include "gas_comun.glslinc"
#include "advecta.glslinc"

layout(set = 0, binding = 0) uniform sampler3D src;
layout(set = 0, binding = 1, rgba16f) uniform restrict writeonly image3D dst;

void main() {
	ivec3 c = celda();
	if (fuera_de_rejilla(c)) return;
	vec3 desde = retroceso(src, uvw_de(c), vec3(DT) / WTAM);
	imageStore(dst, c, vec4(textureLod(src, desde, 0.0).xyz, 0.0));
}
