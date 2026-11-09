#[compute]
#version 450
// PORT de src/gas/advect.js: advectGasForward (lejrimostfa/force-field-vfx-threejs, MIT). Paso adelante de MacCormack: gas0 -> gasTmp.
layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
#include "gas_comun.glslinc"
#include "advecta.glslinc"

layout(set = 0, binding = 0) uniform sampler3D vel;
layout(set = 0, binding = 1) uniform sampler3D src;
layout(set = 0, binding = 2) uniform sampler3D flujo;
layout(set = 0, binding = 3, rgba16f) uniform restrict writeonly image3D dst;

void main() {
	ivec3 c = celda();
	if (fuera_de_rejilla(c)) return;
	imageStore(dst, c, textureLod(src, retroceso_gas(vel, flujo, uvw_de(c)), 0.0));
}
