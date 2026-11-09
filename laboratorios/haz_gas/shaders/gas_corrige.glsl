#[compute]
#version 450
// PORT de src/gas/advect.js: advectGasCorrect (lejrimostfa/force-field-vfx-threejs, MIT). Correccion de MacCormack recortada a las 8 celdas leidas: (gas0, gasTmp) -> gas1.
layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
#include "gas_comun.glslinc"
#include "advecta.glslinc"

layout(set = 0, binding = 0) uniform sampler3D vel;
layout(set = 0, binding = 1) uniform sampler3D src;
layout(set = 0, binding = 2) uniform sampler3D tmp;
layout(set = 0, binding = 3) uniform sampler3D flujo;
layout(set = 0, binding = 4, rgba16f) uniform restrict writeonly image3D dst;

void main() {
	ivec3 c = celda();
	if (fuera_de_rejilla(c)) return;
	vec3 uvw = uvw_de(c);
	vec3 desde = retroceso_gas(vel, flujo, uvw);
	vec4 hat = texelFetch(tmp, c, 0);
	vec4 bar = textureLod(tmp, uvw * 2.0 - desde, 0.0);
	vec4 arreglado = hat + (texelFetch(src, c, 0) - bar) * 0.5;
	// Recorte a las 8 celdas que leyo el retroceso; si no, la correccion hace ondas y crea gas de la nada.
	ivec3 base = ivec3(floor(desde * vec3(R.res.xyz) - 0.5));
	vec4 lo = texelFetch(src, cerca(base, 0, 0, 0), 0);
	vec4 hi = lo;
	for (int i = 1; i < 8; i++) {
		vec4 v = texelFetch(src, cerca(base, i & 1, (i >> 1) & 1, (i >> 2) & 1), 0);
		lo = min(lo, v);
		hi = max(hi, v);
	}
	imageStore(dst, c, max(min(arreglado, hi), lo));
}
