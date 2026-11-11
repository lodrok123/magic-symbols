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

	if (VIENTO) {
		// MODO VIENTO (11/11, rehecho tras ver Pablo las capturas: «parece vapor... un fluido, no una rafaga sostenida de aire»). El aire NO se dibuja como masa.
		// Lo que se guarda son LINEAS DE CORRIENTE: dos ETIQUETAS (canales y, w) que valen la posicion de cada punto en la seccion del chorro (en radios) y que el gas
		// transporta sin cambiarlas: las curvas donde las dos etiquetas son constantes son, de verdad, los caminos del aire, tambien cuando rodea un solido.
		// El canal x es la RAFAGA: pulsos que nacen por linea en la mano y viajan con el aire (trazos largos que corren, aparecen y se van).
		// Dentro del chorro todo es analitico (nitido); fuera, lo que el aire se lleva queda libre.
		Haz hv = haz_en(w, ruido);
		vec3 ab_v = P.target.xyz - P.nozzle.xyz;
		vec3 r_v = w - (P.nozzle.xyz + ab_v * hv.t);
		r_v -= hv.dir * dot(r_v, hv.dir);
		vec3 e1 = normalize(cross(hv.dir, vec3(0.0, 1.0, 0.0)));
		vec3 e2 = cross(e1, hv.dir);
		float radio_l = mix(BEAM_R0, BEAM_R1, hv.t) * VIENTO_ANCHO;
		vec2 et = vec2(dot(r_v, e1), dot(r_v, e2)) / radio_l;
		// 11/11 (referencia de Pablo: jirones que se RETUERCEN alrededor del eje, como de tornado, no rectas paralelas): las etiquetas GIRAN con el recorrido
		// (VIENTO_HELICE vueltas de la mano al final) y con el tiempo, y mas deprisa por fuera que por dentro: cada linea de corriente es una HELICE que se
		// enrosca y corre; como el giro cambia con el radio, las lineas no son copias paralelas sino curvas de paso distinto.
		float giro_v = 6.2832 * VIENTO_HELICE * hv.t * (0.8 + 0.3 * length(et)) - TIEMPO * 2.4;      // refuerzo: casi el mismo giro a todos los radios (las cintas se enroscan juntas)
		et = mat2(vec2(cos(giro_v), sin(giro_v)), vec2(-sin(giro_v), cos(giro_v))) * et;
		float dentro_v = (1.0 - smoothstep(0.95, 1.2, length(et))) * BEAM_ON * step(0.02, hv.t) * step(hv.t, 0.985);
		// 11/11 (3070): junto a la cara del solido las etiquetas quedan LIBRES (antes se reponian hasta la cara, y los trazos acababan en ella): asi el aire que
		// el choque abre en abanico se lleva sus lineas por la pared y se ven doblarse y rizarse a los lados.
		vec3 n_v;
		float sd_v = obst_sd(w, n_v);
		float libre_v = smoothstep(0.35 * ESC_M, 1.4 * ESC_M, sd_v);
		vec2 celda_l = floor(et * VIENTO_LINEAS);
		float fase_v = TIEMPO - hv.t * length(ab_v) / (BEAM_SPEED * 0.9);
		float pulso = smoothstep(0.47, 0.57, textureLod(ruido, vec3(celda_l.x * 0.31 + 0.13, celda_l.y * 0.37 + 0.29, fase_v * 0.055), 0.0).x);      // refuerzo: cintas mas largas
		float rafaga = mix(T, pulso, dentro_v * 0.95) * exp(-COOL * DT);
		vec2 etq = mix(vec2(soot, fuel), et, dentro_v * libre_v);
		// polvo: la regla de la demo (el aire rapido a ras de suelo lo levanta en vetas y se despeja con la altura)
		vec3 aire_v = textureLod(vel, uvw, 0.0).xyz;
		float veta = textureLod(ruido, w * vec3(0.045, 0.1, 0.045) / ESC_M, 0.0).x;
		dust *= exp(-(DUST_FADE + smoothstep(0.15, 0.9, w.y / ESC_M) * 5.0) * DT);
		dust += max(length(aire_v.xz) - (WIND + 5.0), 0.0) * exp(-w.y * 3.2 / ESC_M) * veta * DT * 0.3;
		// 11/11 (3070): con el haz a la altura de la mano el aire rapido casi no llega al suelo y apenas salia polvo. La rafaga BARRE el suelo que tiene debajo:
		// una franja bajo el chorro que crece con el recorrido (el chorro se abre) y, en el choque, el pie del solido, donde el abanico baja hasta el suelo.
		float lado_v = dot(r_v, e1) / radio_l;
		float bajo_chorro = smoothstep(0.3, 0.8, hv.t) * step(hv.t, 0.97) * exp(-lado_v * lado_v * 0.8) * exp(-w.y * 4.0 / ESC_M) * BEAM_ON;
		vec3 off_v = w - P.contacto.xyz;
		float pie = (1.0 - smoothstep(0.0, 1.0 * ESC_M, sd_v)) * exp(-w.y * 3.0 / ESC_M) * exp(-dot(off_v.xz, off_v.xz) * 0.4 / (ESC_M * ESC_M)) * step(hv.t, 0.999) * BEAM_ON;   // solo la cara del choque, no detrás
		dust += (bajo_chorro * 2.6 + pie * 0.6) * veta * veta * veta * DT;          // veta³: vetas sueltas, no una manta
		float keep_v = fuera_obst(sd_v) * esponja(uvw);
		imageStore(gas_out, c, vec4(min(rafaga * keep_v, 4.0), etq.x, min(dust * keep_v, 4.0), etq.y));
		return;
	}

	if (RAYO) {
		// MODO RAYO (11/11): x = ionizacion (donde el dibujo puede encender arcos). Nucleo fino del chorro, mancha en el choque y carga que REPTA por la piel del
		// solido alrededor del contacto (a rafagas). Se apaga en decimas de segundo (COOL alto): al cortar el haz quedan unos arcos que se van.
		Haz hr = haz_en(w, ruido);
		float ion = max(T, hr.core * hr.core * (0.4 + 0.3 * hr.pulse));
		vec3 off_r = w - P.contacto.xyz;
		float d2 = dot(off_r, off_r) / (ESC_M * ESC_M);
		float gust_r = textureLod(ruido, w * (0.09 / ESC_M) + vec3(TIEMPO * 0.9, 0.6, 0.1), 0.0).x * 1.5;
		ion = max(ion, exp(d2 * -1.2) * BEAM_ON * gust_r * HEAT * 1.3);
		vec3 n_r;
		float sd_r = obst_sd(w, n_r);
		float piel_r = (1.0 - smoothstep(0.05, 0.5 * ESC_M, sd_r)) * exp(d2 * -0.09) * BEAM_ON;
		ion = max(ion, piel_r * smoothstep(0.45, 0.8, textureLod(ruido, w * (0.16 / ESC_M) + vec3(0.2, TIEMPO * 0.7, 0.4), 0.0).y) * HEAT);
		ion *= exp(-COOL * DT);
		imageStore(gas_out, c, vec4(min(ion * fuera_obst(sd_r) * esponja(uvw), 4.0), 0.0, 0.0, 0.0));
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
