shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

// DISCO DE LUZ EN EL SUELO de la columna de viento (viento_corrientes.gd, _disco_suelo). Un quad de 2,6 x 2,6 cuyo semieje es la huella x 1,3: «rr» vale 1 en el borde de la huella.
// `abre` (0 -> 1 en 0,15 s) abre un anillo del centro a la huella; despues queda un disco tenue con rayas radiales que giran despacio. Es LUZ, no masa: alfa bajo y nada fuera de la
// huella (un poco mas alla, el anillo). Paleta del viento del proyecto (claro / sombra por uniforme), no un turquesa.
uniform vec4 claro : source_color = vec4(0.90, 0.99, 0.94, 1.0);
uniform vec4 sombra : source_color = vec4(0.68, 0.87, 0.77, 1.0);
uniform float tiempo = 0.0;
uniform float abre = 1.0;
uniform float opacidad = 1.0;

void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * 1.3;
	float rr = length(p);
	float ang = atan(p.y, p.x);
	float anillo_pos = abre * 1.05;
	float anillo = exp(-pow((rr - anillo_pos) / 0.07, 2.0)) * (1.0 - 0.6 * smoothstep(0.9, 1.0, abre));
	float dentro = 1.0 - smoothstep(0.92, 1.05, rr);
	float rayas = pow(0.5 + 0.5 * sin(ang * 14.0 + tiempo * 0.7 + rr * 4.0), 5.0) * smoothstep(0.08, 0.5, rr);
	float disco = dentro * smoothstep(anillo_pos - 0.02, anillo_pos - 0.3, rr) * (0.10 + 0.42 * rayas);
	float borde = exp(-pow((rr - 1.0) / 0.04, 2.0)) * 0.22 * abre;
	float a = clamp(disco + anillo * 0.75 + borde, 0.0, 1.0) * opacidad;
	ALBEDO = mix(sombra.rgb, claro.rgb, clamp(rayas * 0.6 + anillo, 0.0, 1.0));
	ALPHA = a * 0.85;
}
