#[compute]
#version 450
// PORT de src/gas/light.js: lightFar (lejrimostfa/force-field-vfx-threejs, MIT). Octavo de resolucion: la misma luz a traves del escenario.
// La difusion solo avanza una celda por pasada y una perdida l por pasada limita su alcance a ~h*sqrt(1/(6 l)): el largo alcance pide celdas grandes y perdida minima.
// Su gradiente da la direccion del fuego (los mapas de normales reaccionan a las llamas sin pasada de sombra). src -> dst.
layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
#include "gas_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler3D luz_cerca;
layout(set = 0, binding = 1) uniform sampler3D src;
layout(set = 0, binding = 2, rgba16f) uniform restrict writeonly image3D dst;

// Tras una cara abierta el vecino cuenta como mas oscuro que esta celda: con bordes recortados la luz rebotaria y llenaria la caja por igual.
// El suelo queda reflectante: y por debajo de 0 no es cara abierta.
vec3 cara(ivec3 c, vec3 me, int x, int y, int z, bool borde) { return borde ? me * 0.6 : texelFetch(src, cerca(c, x, y, z), 0).xyz; }

void main() {
	ivec3 c = celda();
	if (fuera_de_rejilla(c)) return;
	vec3 me = texelFetch(src, c, 0).xyz;
	ivec3 top = R.res.xyz - 1;
	vec3 avg = (cara(c, me, 1, 0, 0, c.x == top.x) + cara(c, me, -1, 0, 0, c.x == 0)
		+ cara(c, me, 0, 1, 0, c.y == top.y) + texelFetch(src, cerca(c, 0, -1, 0), 0).xyz
		+ cara(c, me, 0, 0, 1, c.z == top.z) + cara(c, me, 0, 0, -1, c.z == 0)) / 6.0;
	imageStore(dst, c, vec4(textureLod(luz_cerca, uvw_de(c), 0.0).xyz * 0.02 + avg * 0.995, 1.0));
}
