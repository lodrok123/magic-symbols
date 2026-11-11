#[compute]
#version 450
// PORT de src/gas/sources.js: velSources (lejrimostfa/force-field-vfx-threejs, MIT). Media resolucion: chorro, flotacion, arrastre al viento, empuje de un sentido,
// piel del escudo + wrap, expansion de la combustion y tope de velocidad (CFL). (gas0, vel1) -> vel0.
layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
#define CON_SOLIDO
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
	vec3 u_chorro = hz.dir * BEAM_SPEED;
	if (VIENTO) {
		// Viento (11/11): el chorro GIRA alrededor de su eje (REMOLINO, u/s en el borde): las vetas de bruma salen en helice y se abren en rizos.
		vec3 ab_v = P.target.xyz - P.nozzle.xyz;
		vec3 r_v = w - (P.nozzle.xyz + ab_v * hz.t);
		r_v -= hz.dir * dot(r_v, hz.dir);
		u_chorro += cross(hz.dir, r_v) / max(mix(BEAM_R0, BEAM_R1, hz.t), 0.05) * REMOLINO;
	}
	u = mix(u, u_chorro, hz.core * 0.92);
	if (VIENTO) {
		// 11/11 (3070): contra un solido el aire se ABRE EN ABANICO por la cara (desde el contacto hacia fuera, por el plano de la pared) y gira un poco
		// alrededor de la normal: las lineas de corriente se reparten y se rizan a lo largo del muro en vez de acabar en el.
		vec3 n_f;
		float d_f = obst_sd(w, n_f);
		float cara = (1.0 - smoothstep(0.0, 1.3 * ESC_M, d_f)) * BEAM_ON;
		vec3 r_c = w - P.contacto.xyz;
		r_c -= n_f * dot(r_c, n_f);
		float l_c = length(r_c);
		vec3 tg_c = r_c / max(l_c, 1e-3);
		float cerca_c = exp(-l_c * l_c / (9.0 * ESC_M * ESC_M)) * smoothstep(0.0, 0.4 * ESC_M, l_c);
		u += (tg_c * 0.9 + cross(n_f, tg_c) * 0.35) * BEAM_SPEED * cara * cerca_c * DT * 9.0;
	}

	// Fuego: flota con el calor y pesa el hollin. Agua (10/11): no flota; pesa el AGUA (canal x), asi que cae y se escurre por la pared.
	u.y += (BUOYANCY * gs.x - WEIGHT * (AGUA ? gs.x : gs.y)) * DT;
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
