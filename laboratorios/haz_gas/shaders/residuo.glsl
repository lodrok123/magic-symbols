#[compute]
#version 450
// SOLO PARA LA PRUEBA (herramientas/prueba_gas_haz.gd): divergencia que queda tras proyectar, con la misma regla de caras que divergencia.glsl.
// (vel0 proyectada, vel1 con la expansion en w) -> dst: x = div(vel0) - expansion, y = |vel0|, z = solido.
layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
#include "gas_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler3D vel_fin;
layout(set = 0, binding = 1) uniform sampler3D vel_exp;
layout(set = 0, binding = 2, rgba32f) uniform restrict writeonly image3D dst;

bool solido(vec3 w) { vec3 n; return obst_sd(w, n) < 0.0; }

float flujo_cara(ivec3 c, vec3 w, int x, int y, int z, int eje) {
	vec4 v = texelFetch(vel_fin, cerca(c, x, y, z), 0);
	return solido(w + vec3(x, y, z) * H) ? 0.0 : v[eje];
}

void main() {
	ivec3 c = celda();
	if (fuera_de_rejilla(c)) return;
	vec3 w = mundo_de(uvw_de(c));
	float suelo = c.y == 0 ? 0.0 : flujo_cara(c, w, 0, -1, 0, 1);
	float div = (flujo_cara(c, w, 1, 0, 0, 0) - flujo_cara(c, w, -1, 0, 0, 0) + flujo_cara(c, w, 0, 1, 0, 1) - suelo
		+ flujo_cara(c, w, 0, 0, 1, 2) - flujo_cara(c, w, 0, 0, -1, 2)) / (2.0 * H) - texelFetch(vel_exp, c, 0).w;
	imageStore(dst, c, vec4(div, length(texelFetch(vel_fin, c, 0).xyz), solido(w) ? 1.0 : 0.0, 0.0));
}
