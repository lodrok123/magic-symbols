#[compute]
#version 450
// PORT de src/gas/sources.js: velSources (lejrimostfa/force-field-vfx-threejs, MIT). Media resolucion: chorro, flotacion, arrastre al viento, empuje de un sentido,
// piel del escudo + wrap, expansion de la combustion y tope de velocidad (CFL). (gas0, vel1) -> vel0.
layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
#include "gas_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler3D vel_in;
layout(set = 0, binding = 1) uniform sampler3D gas_now;
layout(set = 0, binding = 2) uniform sampler3D ruido;
layout(set = 0, binding = 3, rgba16f) uniform restrict writeonly image3D vel_out;

void main() {
	ivec3 c = celda();
	if (fuera_de_rejilla(c)) return;
	vec3 uvw = uvw_de(c);
	vec3 w = mundo_de(uvw);
	vec3 u = texelFetch(vel_in, c, 0).xyz;
	vec4 gs = textureLod(gas_now, uvw, 0.0);

	Haz hz = haz_en(w, ruido);
	u = mix(u, hz.dir * BEAM_SPEED, hz.core * 0.92);

	u.y += (BUOYANCY * gs.x - WEIGHT * gs.y) * DT;
	vec3 wind = viento();
	u = mix(wind, u, exp(-DRAG * DT));
	// Empuje de UN sentido. Lo que se queda detras del viento o vuelve hacia el lanzador se empuja hacia delante, tambien tras el choque:
	// si no, el golpe contra el escudo devolveria llamas por el chorro. Al gas mas rapido no se le toca.
	// (La demo hace normalize(wind): con el mando de viento a 0 eso es NaN; aqui la direccion no depende del modulo. Con viento > 0 es identico.)
	vec3 ahead = dir_viento();
	float lag = max(WIND - dot(u, ahead), 0.0);
	u += ahead * lag * (1.0 - exp(-PUSH * DT));

	vec3 nrm;
	float d = obst_sd(w, nrm);
	float skin = 1.0 - smoothstep(0.0, 0.5 * ESC_M, d);
	u -= nrm * min(dot(u, nrm), 0.0) * skin;
	// Direccion de arte: un tiron suave hacia la piel mantiene las llamas envolviendo la esfera pasado su ecuador.
	u -= nrm * skin * WRAP * DT;
	// Las caras abiertas se relajan al viento, no a cero: un borde quieto taparia el flujo en la entrada de la caja.
	u = mix(wind, u, esponja(uvw) * 0.15 + 0.85);
	float keep = fuera_obst(d);

	// El gas que arde empuja hacia fuera. El mismo ritmo que gasSources, leido aqui del combustible y la temperatura.
	float burn = min(gs.w / DT, BURN_RATE * smoothstep(0.1, 0.28, gs.x));
	// El paso se queda por debajo de 6 celdas de gas para que la adveccion siga estable cuando el chorro golpea el escudo.
	float vmax = (H / 2.0) * 6.0 * 60.0;
	float speed = max(length(u), 0.001);
	imageStore(vel_out, c, vec4(u * (min(speed, vmax) / speed) * keep, burn * EXPANSION * keep));
}
