#[compute]
#version 450
// PORT de src/gas/light.js: keyShadow (lejrimostfa/force-field-vfx-threejs, MIT). Media resolucion: transmitancia hacia la lampara azul.
// Un rayo corto por celda da al humo su sombreado de nube. gas0 -> keyT (r).
layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
#include "gas_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler3D gas;
layout(set = 0, binding = 1, rgba16f) uniform restrict writeonly image3D dst;

void main() {
	ivec3 c = celda();
	if (fuera_de_rejilla(c)) return;
	vec3 w = mundo_de(uvw_de(c));
	vec3 dir = normalize(P.key_pos.xyz - w);
	const float STEP = 0.42;
	float tau = 0.0;
	for (int i = 0; i < 14; i++) {
		vec3 at = w + dir * ((float(i) + 0.7) * STEP);
		tau += extincion(textureLod(gas, (at - WLO) / WTAM, 0.0));
	}
	imageStore(dst, c, vec4(exp(-tau * STEP * 1.7), 0.0, 0.0, 1.0));
}
