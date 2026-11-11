// MODO AGUA (10/11): las chispas GPU del port (chispas.glsl, basado en src/render/sparks.js de lejrimostfa/force-field-vfx-threejs, MIT) dibujadas como GOTAS del AguaToy:
// nacen en el choque, montan la velocidad del gas con inercia, caen y rebotan (0,35) en el suelo y en los sólidos. Trazos cortos estirados por su movimiento en pantalla,
// mezcla normal, sin luz; tono SOMERO con la cabeza de ESPUMA (los colores los pone HazGas desde AguaPaleta). Solo se dibuja 1 de cada `cada` (las 1000 del fuego son demasiadas gotas).
// 11/11 (choque con identidad, Pablo: «gotas de agua para el agua»), con `agua`: la gota tiene forma de LÁGRIMA (cabeza redonda con brillo de ESPUMA, cola SOMERO que
// se afila a lo largo de su velocidad) y, cuando el compute la marca como SALPICADURA (V.w < -0,5: ha tocado el suelo), es un ANILLO plano que se abre y se rompe en
// cuentas. El mismo shader dibuja las HOJAS del viento (sin `agua`) y, con `mechones`, los MECHONES de aire blancos del viento (chispa 2 de cada 8, chispas.glsl).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D estado : filter_nearest, repeat_disable;
uniform mat4 dominio_a_mundo;
uniform vec3 tono_b : source_color = vec3(0.34, 0.74, 0.72);
uniform vec3 tono_c : source_color = vec3(0.96, 0.99, 1.0);
uniform int cada = 3;
uniform float grosor = 1.0;        // 11/11: las hojas del viento, más gordas
uniform bool agua = false;
uniform bool mechones = false;
uniform vec3 tono_mechon : source_color = vec3(0.97, 1.0, 0.98);

varying float v_along;
varying float v_lado;
varying float v_modo;               // 0 trazo / gota, 1 salpicadura, 2 mechón
varying float v_edad;               // salpicadura: 0 al nacer, 1 al acabar; mechón: vida que queda (0-1)

void vertex() {
	vec4 P = texelFetch(estado, ivec2(INSTANCE_ID, 0), 0);
	vec4 V = texelFetch(estado, ivec2(INSTANCE_ID, 1), 0);
	v_modo = 0.0;
	v_edad = 0.0;
	bool es_mechon = mechones && INSTANCE_ID % 8 == 2;
	if (agua && V.w < -0.5) {
		// SALPICADURA: un quad plano sobre el suelo, centrado en la gota, que se abre en 0,3 s
		float edad = clamp(1.0 - P.w / 0.3, 0.0, 1.0);
		float g = -1.0 - V.w;
		float rad = (0.1 + 0.32 * sqrt(edad)) * (0.6 + 0.8 * g) * grosor * 0.8;
		vec3 c = P.xyz + vec3(VERTEX.x * 2.0 * rad, 0.01, VERTEX.y * 2.0 * rad);
		POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * (dominio_a_mundo * vec4(c, 1.0)));
		v_modo = 1.0;
		v_edad = edad;
		v_along = VERTEX.x * 2.0;
		v_lado = VERTEX.y * 2.0;
		if (INSTANCE_ID % max(cada, 1) != 0 || P.w <= 0.0) POSITION = vec4(0.0, 0.0, -2.0, 1.0);
	} else {
		float k_cola = es_mechon ? 0.09 : (agua ? 0.045 : 0.022);
		vec3 cabeza = (dominio_a_mundo * vec4(P.xyz, 1.0)).xyz;
		vec3 cola = (dominio_a_mundo * vec4(P.xyz - V.xyz * k_cola, 1.0)).xyz;
		vec4 a = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(cabeza, 1.0));
		vec4 b = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(cola, 1.0));
		float along = VERTEX.x + 0.5;
		vec4 clip = mix(a, b, along);
		vec2 na = a.xy / a.w, nb = b.xy / b.w;
		vec2 d = nb - na;
		vec2 dir = d / max(length(d), 0.0001);
		float gr = es_mechon ? 0.75 : grosor * (agua ? 2.8 : 1.0);
		float semi = 0.0042 * gr * (V.w * 0.6 + 0.6);
		vec2 lado = vec2(-dir.y, dir.x) * VERTEX.y * semi;
		// gota: el quad tiene al menos el largo de su ancho (una gota lenta es redonda, no un punto aplastado); la cabeza sobresale por delante
		if (agua) clip.xy += -dir * (along - 0.5) * semi * 1.2 * clip.w;
		// mechón: se curva (el centro del quad se desvía a un lado, como un jirón de tornado)
		if (es_mechon) clip.xy += vec2(-dir.y, dir.x) * sin(along * 3.1416) * 0.012 * (float(INSTANCE_ID % 3) - 1.0) * clip.w;
		clip.xy += lado * clip.w;
		bool ve = es_mechon || INSTANCE_ID % max(cada, 1) == 0;
		if (es_mechon && length(d) < 0.012) ve = false;              // un mechón lento sería un punto: no se dibuja
		if (!ve || P.w <= 0.0 || P.y < -5.0) clip = vec4(0.0, 0.0, -2.0, 1.0);
		POSITION = clip;
		v_along = along;
		v_lado = VERTEX.y * 2.0;
		if (es_mechon) {
			v_modo = 2.0;
			v_edad = clamp(P.w / 0.35, 0.0, 1.0);
		}
	}
}

void fragment() {
	if (v_modo > 1.5) {
		// MECHÓN: trazo blanco fino que se afila en las dos puntas y adelgaza al final de su vida
		float w = sin(clamp(v_along, 0.0, 1.0) * 3.1416) * (0.45 + 0.55 * v_edad);
		if (abs(v_lado) > w) discard;
		ALBEDO = tono_mechon;
		ALPHA = 0.9 * smoothstep(0.0, 0.35, v_edad);
	} else if (v_modo > 0.5) {
		// SALPICADURA: anillo que se abre y se adelgaza; al final se rompe en cuentas (gotitas)
		float r = length(vec2(v_along, v_lado));
		float ang = atan(v_lado, v_along);
		float centro = mix(0.45, 0.85, v_edad);
		float ancho_a = mix(0.26, 0.11, v_edad);
		float anillo = 1.0 - smoothstep(ancho_a * 0.7, ancho_a, abs(r - centro));
		float cuentas = step(0.3 + 0.45 * v_edad, 0.5 + 0.5 * cos(ang * 7.0));
		float a = anillo * mix(1.0, cuentas, smoothstep(0.3, 0.65, v_edad));
		if (a < 0.5 || v_edad > 0.97) discard;
		ALBEDO = r > centro ? tono_c : tono_b;
		ALPHA = 0.9;
	} else if (agua) {
		// GOTA en lágrima: cabeza redonda (along 0) que se afila hacia la cola, con un brillo de ESPUMA en la cabeza
		float x = v_along;
		float w = x < 0.3 ? sqrt(max(1.0 - pow((0.3 - x) / 0.3, 2.0), 0.0)) : pow(max(1.0 - (x - 0.3) / 0.7, 0.0), 1.3);
		if (abs(v_lado) > w) discard;
		bool brillo = x > 0.06 && x < 0.26 && v_lado < -0.1 && v_lado > -0.65;
		ALBEDO = brillo ? tono_c : tono_b;
		ALPHA = 0.92;
	} else {
		ALBEDO = mix(tono_c, tono_b, smoothstep(0.15, 0.6, v_along));
		ALPHA = 0.9;
	}
}
