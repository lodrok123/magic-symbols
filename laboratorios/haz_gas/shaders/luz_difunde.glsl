#[compute]
#version 450
// PORT de src/gas/light.js: lightDiffuse (lejrimostfa/force-field-vfx-threejs, MIT). Cuarto de resolucion: la luz del fuego cerca de las llamas.
// La emision se reparte por difusion y se apaga a traves del hollin. La luz que el fuego echa sobre las cosas es naranja puro (1, 0.3, 0.045):
// sumar aqui la emision blanca lavaria todo el escenario. src -> dst.
layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
#include "gas_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler3D gas;
layout(set = 0, binding = 1) uniform sampler3D src;
layout(set = 0, binding = 2, rgba16f) uniform restrict writeonly image3D dst;

const vec3 FIRE_TINT = vec3(1.0, 0.3, 0.045);

vec3 l_cerca(ivec3 c, int x, int y, int z) { return texelFetch(src, cerca(c, x, y, z), 0).xyz; }

void main() {
	ivec3 c = celda();
	if (fuera_de_rejilla(c)) return;
	vec4 s = textureLod(gas, uvw_de(c), 0.0);
	vec3 avg = (l_cerca(c, 1, 0, 0) + l_cerca(c, -1, 0, 0) + l_cerca(c, 0, 1, 0) + l_cerca(c, 0, -1, 0) + l_cerca(c, 0, 0, 1) + l_cerca(c, 0, 0, -1)) / 6.0;
	float dim = exp(-extincion(s) * H * 0.1);
	imageStore(dst, c, vec4(FIRE_TINT * color_fuego(s.x).x * 0.2 + avg * dim * 0.992, 1.0));
}
