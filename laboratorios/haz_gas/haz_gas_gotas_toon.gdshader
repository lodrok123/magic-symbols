// MODO AGUA (10/11): las chispas GPU del port (chispas.glsl, basado en src/render/sparks.js de lejrimostfa/force-field-vfx-threejs, MIT) dibujadas como GOTAS del AguaToy:
// nacen en el choque, montan la velocidad del gas con inercia, caen y rebotan (0,35) en el suelo y en los sólidos. Trazos cortos estirados por su movimiento en pantalla,
// mezcla normal, sin luz; tono SOMERO con la cabeza de ESPUMA (los colores los pone HazGas desde AguaPaleta). Solo se dibuja 1 de cada `cada` (las 1000 del fuego son demasiadas gotas).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D estado : filter_nearest, repeat_disable;
uniform mat4 dominio_a_mundo;
uniform vec3 tono_b : source_color = vec3(0.34, 0.74, 0.72);
uniform vec3 tono_c : source_color = vec3(0.96, 0.99, 1.0);
uniform int cada = 3;

varying float v_along;

void vertex() {
	vec4 P = texelFetch(estado, ivec2(INSTANCE_ID, 0), 0);
	vec4 V = texelFetch(estado, ivec2(INSTANCE_ID, 1), 0);
	vec3 cabeza = (dominio_a_mundo * vec4(P.xyz, 1.0)).xyz;
	vec3 cola = (dominio_a_mundo * vec4(P.xyz - V.xyz * 0.022, 1.0)).xyz;
	vec4 a = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(cabeza, 1.0));
	vec4 b = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(cola, 1.0));
	float along = VERTEX.x + 0.5;
	vec4 clip = mix(a, b, along);
	vec2 na = a.xy / a.w, nb = b.xy / b.w;
	vec2 d = nb - na;
	vec2 dir = d / max(length(d), 0.0001);
	vec2 lado = vec2(-dir.y, dir.x) * VERTEX.y * 0.0042 * (V.w * 0.6 + 0.6);
	clip.xy += lado * clip.w;
	if (INSTANCE_ID % max(cada, 1) != 0 || P.w <= 0.0) clip = vec4(0.0, 0.0, -2.0, 1.0);
	POSITION = clip;
	v_along = along;
}

void fragment() {
	ALBEDO = mix(tono_c, tono_b, smoothstep(0.15, 0.6, v_along));
	ALPHA = 0.9;
}
