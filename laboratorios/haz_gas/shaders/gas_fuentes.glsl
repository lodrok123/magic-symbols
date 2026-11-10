#[compute]
#version 450
// PORT de src/gas/sources.js: gasSources (lejrimostfa/force-field-vfx-threejs, MIT). Resolucion completa: chorro, combustion, polvo, escudo, esponja. gas1 -> gas0.
// El humo es en lo que se convierte el fuego: el gas que se frena pierde calor mas deprisa y el calor perdido se vuelve hollin negro y espeso.
// El chorro rapido queda limpio solo, sin zona puesta a mano, y el humo crece directamente de las llamas.
layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
#define CON_SOLIDO
#include "gas_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler3D gas_in;
layout(set = 0, binding = 1) uniform sampler3D vel;
layout(set = 0, binding = 2) uniform sampler3D ruido;
layout(set = 0, binding = 3, rgba16f) uniform restrict writeonly image3D gas_out;

void main() {
	ivec3 c = celda();
	if (fuera_de_rejilla(c)) return;
	vec3 uvw = uvw_de(c);
	vec3 w = mundo_de(uvw);
	vec4 gs = texelFetch(gas_in, c, 0);
	float T = gs.x, soot = gs.y, dust = gs.z, fuel = gs.w;

	if (AGUA) {
		// MODO AGUA (10/11): x = cantidad de agua. El chorro la pone en su nucleo; en el choque, el chorro que se APLASTA contra la cara alimenta una mancha en
		// la piel (la misma alimentacion que el fuego, sin calor) de la que nace la lamina que el peso hace caer por la pared. Sin combustion, ni hollin, ni polvo:
		// el agua solo se va despacio (COOL = evaporacion / lo que se escurre fuera de la vista).
		Haz ha = haz_en(w, ruido);
		float agua = max(T, ha.core * (0.85 + 0.25 * ha.pulse));
		vec3 off_a = w - P.contacto.xyz;
		float gust_a = textureLod(ruido, w * (0.05 / ESC_M) + vec3(TIEMPO * 0.25, 0.6, 0.1), 0.0).x * 1.4;
		agua = max(agua, exp(dot(off_a, off_a) * -0.9 / (ESC_M * ESC_M)) * BEAM_ON * gust_a * HEAT);
		agua *= exp(-COOL * DT);
		vec3 n_a;
		float keep_a = fuera_obst(obst_sd(w, n_a)) * esponja(uvw);
		imageStore(gas_out, c, vec4(min(agua * keep_a, 4.0), 0.0, 0.0, 0.0));
		return;
	}

	// El chorro se mantiene caliente en su nucleo y solo lleva combustible en su ultimo tramo: asi queda recto y limpio.
	Haz hz = haz_en(w, ruido);
	fuel = max(fuel, hz.core * hz.pulse * smoothstep(0.55, 0.9, hz.t));
	T = max(T, hz.core * 0.8 + smoothstep(0.65, 1.0, hz.core) * hz.pulse * 1.25);

	// Choque: el chorro alimenta un fuego en la piel del escudo. Las llamas que envuelven la esfera nacen aqui.
	vec3 off = w - P.contacto.xyz;
	float gust = textureLod(ruido, w * (0.05 / ESC_M) + vec3(TIEMPO * 0.25, 0.6, 0.1), 0.0).x * 1.4;
	float flare = exp(dot(off, off) * -0.9 / (ESC_M * ESC_M)) * BEAM_ON * gust;
	fuel = max(fuel, flare);
	T = max(T, flare * 1.9);

	float burn = min(fuel, BURN_RATE * DT * smoothstep(0.1, 0.28, T));
	fuel -= burn;
	T += burn * HEAT;

	// Rapidez respecto al viento: el gas que lleva el viento se ha frenado, para el fuego.
	vec3 air = textureLod(vel, uvw, 0.0).xyz - viento();
	float slow = 1.0 - smoothstep(5.0, 16.0, length(air));
	float before = T;
	T = max(T * exp(-COOL * (slow * 1.2 + 1.0) * DT) - T * T * T * T * DT * 0.4, 0.0);
	soot += (before - T) * SOOT_YIELD * slow * (1.0 - smoothstep(0.35, 0.95, T));
	soot *= exp(-SOOT_FADE * DT);
	// El polvo se queda en una capa fina en el suelo. Mas arriba se despeja deprisa, o el flujo llena la caja de una cortina oscura.
	float clearing = smoothstep(0.15, 0.9, w.y) * 7.0;
	dust *= exp(-(DUST_FADE + clearing) * DT);

	// El aire rapido junto al suelo levanta polvo. El ruido lo rompe en vetas.
	float lift = max(length(air.xz) - 2.5, 0.0) * exp(-w.y * 3.2);
	dust += lift * textureLod(ruido, w * vec3(0.045, 0.1, 0.045), 0.0).x * DT * 0.6;

	vec3 n;
	float keep = fuera_obst(obst_sd(w, n)) * esponja(uvw);
	vec4 o = vec4(T, soot, dust, fuel) * keep;
	imageStore(gas_out, c, vec4(min(o.xyz, vec3(4.0)), min(o.w, 1.0)));
}
