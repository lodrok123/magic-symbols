shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled;

// ARCOS DEL RAYO SOBRE LA SUPERFICIE GOLPEADA (9/11/2026, idea «lo que golpea envuelve el haz» de la demo de gas de three.js). Una lámina pegada a la superficie (o tumbada en el suelo delante)
// de la que salen unos arcos quebrados que reptan desde el punto de choque y cambian de sitio a saltos (20 veces por segundo, como el redibujo del propio rayo). Aditivo y unshaded: el rayo BRILLA
// (regla de rayo_paleta.gd). Colores de la paleta del rayo: hilo blanco (NUCLEO), cuerpo (CUERPO, solo en el centro) y halo azul (HALO_BORDE / HALO). `vida` lo baja el toy al morir.

uniform vec3 c_nucleo : source_color = vec3(1.0, 1.0, 0.90);       // RayoPaleta.NUCLEO
uniform vec3 c_cuerpo : source_color = vec3(1.0, 0.93, 0.40);      // RayoPaleta.CUERPO
uniform vec3 c_halo : source_color = vec3(0.35, 0.62, 1.0);        // RayoPaleta.HALO
uniform vec3 c_borde : source_color = vec3(0.5, 0.82, 1.0);        // RayoPaleta.HALO_BORDE
uniform float crece : hint_range(0.0, 1.0) = 1.0;
uniform float corte : hint_range(0.0, 1.0) = 0.0;
uniform float semilla = 0.0;
uniform float intensidad = 1.0;
uniform float suelo : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 q = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float vive = smoothstep(0.78, 1.0, crece) * (1.0 - smoothstep(0.0, 0.8, corte));
	float paso = floor(TIME * 20.0) + semilla * 17.0;
	float hilo = 0.0;
	float halo = 0.0;
	for (int k = 0; k < 6; k++) {
		float fk = float(k);
		float ang = hash(vec2(fk, paso)) * 6.2832;
		// por la superficie los arcos van sobre todo a los lados (en el suelo, a todos)
		ang = mix(ang * 0.5 + 0.0, ang, suelo);
		if (suelo < 0.5 && hash(vec2(fk + 7.0, paso)) > 0.5) {
			ang += 3.1416;
		}
		vec2 dir = vec2(cos(ang), sin(ang));
		float largo = 0.4 + 0.55 * hash(vec2(fk + 11.0, paso));
		float s = dot(q, dir);
		float perp = dot(q, vec2(-dir.y, dir.x));
		float quiebro = (hash(vec2(floor(s * 8.0) + fk * 3.0, paso)) - 0.5) * 0.16 * smoothstep(0.0, 0.3, s);
		float d = abs(perp - quiebro);
		float dentro = step(0.0, s) * (1.0 - smoothstep(largo - 0.1, largo, s));
		hilo = max(hilo, (1.0 - smoothstep(0.008, 0.026, d)) * dentro);
		halo = max(halo, (1.0 - smoothstep(0.02, 0.1, d)) * dentro);
	}
	float centro = 1.0 - smoothstep(0.0, 0.22, length(q));
	vec3 col = c_halo * halo * 0.5 + c_borde * hilo * 0.6 + c_nucleo * hilo * 0.7 + c_cuerpo * centro * 0.35 + c_nucleo * centro * hilo;
	float a = clamp(hilo + halo * 0.35 + centro * 0.4, 0.0, 1.0) * vive * intensidad;
	a *= 1.0 - smoothstep(0.8, 1.0, length(q));
	ALBEDO = col * a;
	ALPHA = a;
}
