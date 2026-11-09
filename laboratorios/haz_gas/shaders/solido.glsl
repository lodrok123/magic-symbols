#[compute]
#version 450
// CAMPO DE SÓLIDOS del haz de gas EN EL JUEGO (9/11/2026). Distancia con signo (negativa dentro) y normal hacia fuera de los sólidos REALES del mundo, en coordenadas
// del dominio y a la resolución del gas: el mínimo sobre una lista de primitivas analíticas que monta HazGasMundo en la CPU:
//   · tipo 0 CAJA orientada (giro en y): las casillas sólidas del nivel (muros, rocas, árboles, cornisas y escalones hasta su altura), los bloques empujables y las
//     barreras / topes que la rejilla no explica;
//   · tipo 1 CÁPSULA vertical: los enemigos (su CapsuleShape3D).
// Es EXACTO fuera de los sólidos (unión de primitivas) y barato (cientos de primitivas por celda, una vez por cambio): por eso no hace falta un salto de inundación (JFA).
// Dentro de una unión de cajas la distancia puede quedarse corta en las caras interiores, pero el signo es el bueno, que es lo que usan la piel, la proyección y las chispas.
// Salida: rgba16f = (sd, normal.xyz). Lo leen gas_fuentes, vel_fuentes, divergencia, residuo y chispas a través de obst_sd (OBST_TIPO 3).
layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
#include "gas_comun.glslinc"

struct Prim { vec4 a; vec4 b; vec4 c; };
// a: xyz centro de la caja / extremo A de la cápsula, w tipo · b: xyz semiejes de la caja / extremo B, w radio · c: (ex.x, ex.z, ez.x, ez.z) ejes de la caja en el plano xz
layout(set = 0, binding = 0, std430) restrict readonly buffer Prims { vec4 n; Prim p[]; } prims;
layout(set = 0, binding = 1, rgba16f) uniform restrict writeonly image3D dst;

void main() {
	ivec3 c = celda();
	if (fuera_de_rejilla(c)) return;
	vec3 w = mundo_de(uvw_de(c));
	float mejor = 1000.0;
	vec3 nm = vec3(0.0, 1.0, 0.0);
	int cuenta = int(prims.n.x);
	for (int i = 0; i < cuenta; i++) {
		Prim q = prims.p[i];
		float sd;
		vec3 n;
		if (q.a.w < 0.5) {
			vec3 ex = vec3(q.c.x, 0.0, q.c.y), ez = vec3(q.c.z, 0.0, q.c.w);
			vec3 d = w - q.a.xyz;
			vec3 l = vec3(dot(d, ex), d.y, dot(d, ez));
			vec3 hq = abs(l) - q.b.xyz;
			float afuera = length(max(hq, vec3(0.0)));
			float dentro = min(max(hq.x, max(hq.y, hq.z)), 0.0);
			vec3 gl;
			if (afuera > 0.0) gl = sign(l) * max(hq, vec3(0.0)) / afuera;
			else if (hq.x > hq.y && hq.x > hq.z) gl = vec3(sign(l.x), 0.0, 0.0);
			else if (hq.y > hq.z) gl = vec3(0.0, sign(l.y), 0.0);
			else gl = vec3(0.0, 0.0, sign(l.z));
			n = ex * gl.x + vec3(0.0, gl.y, 0.0) + ez * gl.z;
			sd = afuera + dentro;
		} else {
			vec3 pa = w - q.a.xyz, ba = q.b.xyz - q.a.xyz;
			float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
			vec3 v = pa - ba * h;
			float l = length(v);
			n = l > 1e-4 ? v / l : vec3(0.0, 1.0, 0.0);
			sd = l - q.b.w;
		}
		if (sd < mejor) {
			mejor = sd;
			nm = n;
		}
	}
	imageStore(dst, c, vec4(mejor, nm));
}
