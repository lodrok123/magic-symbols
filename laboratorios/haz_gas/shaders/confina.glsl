#[compute]
#version 450
// PORT de src/gas/forces.js: confine (lejrimostfa/force-field-vfx-threejs, MIT). Confinamiento de vorticidad (fuerza del gradiente de |curl|), turbulencia sin divergencia
// que escala con el calor y la rapidez, y viscosidad de verdad (nu laplaciano(v)) en un paso explicito; el gas caliente es mas viscoso: pliegues gordos rodantes.
// (curl, gas0, vel0) -> vel1.
layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
#include "gas_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler3D curl_tex;
layout(set = 0, binding = 1) uniform sampler3D gas_now;
layout(set = 0, binding = 2) uniform sampler3D vel_in;
layout(set = 0, binding = 3) uniform sampler3D flujo;
layout(set = 0, binding = 4, rgba16f) uniform restrict writeonly image3D dst;

vec3 vec_cerca(ivec3 c, int x, int y, int z) { return texelFetch(vel_in, cerca(c, x, y, z), 0).xyz; }

void main() {
	ivec3 c = celda();
	if (fuera_de_rejilla(c)) return;
	vec4 wv = texelFetch(curl_tex, c, 0);
	vec3 grad = vec3(
		texelFetch(curl_tex, cerca(c, 1, 0, 0), 0).w - texelFetch(curl_tex, cerca(c, -1, 0, 0), 0).w,
		texelFetch(curl_tex, cerca(c, 0, 1, 0), 0).w - texelFetch(curl_tex, cerca(c, 0, -1, 0), 0).w,
		texelFetch(curl_tex, cerca(c, 0, 0, 1), 0).w - texelFetch(curl_tex, cerca(c, 0, 0, -1), 0).w);
	vec3 N = grad / max(length(grad), 0.0001);
	vec3 force = cross(N, wv.xyz) * CONFINE * H;

	// Se muestrea en uvw, nunca por indice de celda: gas y velocidad tienen rejillas distintas.
	vec3 uvw = uvw_de(c);
	vec4 gs = textureLod(gas_now, uvw, 0.0);
	vec4 v = texelFetch(vel_in, c, 0);
	vec3 w = mundo_de(uvw);
	float t = TIEMPO;
	vec3 eddies = FLUJO(flujo, w, 16.0 * ESC_M, vec3(0.0, t * -0.05, t * 0.03)) + FLUJO(flujo, w.yzx, 9.0 * ESC_M, vec3(t * 0.07, 0.0, t * -0.04)) * 0.7;
	float stir = gs.x + gs.y * 0.3 + length(v.xyz) * 0.04;
	vec3 shred = eddies * stir * TURBULENCE;

	vec3 avg = (vec_cerca(c, 1, 0, 0) + vec_cerca(c, -1, 0, 0) + vec_cerca(c, 0, 1, 0) + vec_cerca(c, 0, -1, 0) + vec_cerca(c, 0, 0, 1) + vec_cerca(c, 0, 0, -1)) / 6.0;
	float nu = VISCOSITY * (gs.x * 2.0 + 1.0);
	float blend = clamp(nu * DT * 6.0 / (H * H), 0.0, 0.8);
	imageStore(dst, c, vec4(mix(v.xyz, avg, blend) + (force + shred) * DT, v.w));
}
