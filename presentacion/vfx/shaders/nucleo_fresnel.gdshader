// NÚCLEO CON FRESNEL (1/11, comparativa de VFX §1.2). La esfera del centro de la bola: blanco-amarillo que satura en el centro y se va
// al color del borde (y se abre) hacia la silueta; un ruido que sube por encima le da turbulencia. Aditivo (premultiplicado, ver flipbook_erosion).
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_opaque, cull_back, shadows_disabled;

uniform vec4 color_nucleo : source_color = vec4(1.0, 0.8, 0.45, 1.0);
uniform vec4 color_borde : source_color = vec4(0.9, 0.25, 0.03, 1.0);
uniform float potencia : hint_range(0.5, 8.0) = 1.6;
uniform float brillo : hint_range(0.0, 8.0) = 0.8;
uniform sampler2D ruido : hint_default_white, filter_linear, repeat_enable;
uniform float ruido_escala = 2.0;
uniform float ruido_velocidad = 0.8;
uniform float turbulencia : hint_range(0.0, 1.0) = 0.45;
uniform float aditivo : hint_range(0.0, 1.0) = 1.0;
uniform float intensidad : hint_range(0.0, 1.0) = 1.0;   // la anima la escena

void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), potencia);
	float n = texture(ruido, UV * ruido_escala + vec2(0.0, -TIME * ruido_velocidad)).r;
	f = clamp(f + (n - 0.5) * turbulencia, 0.0, 1.0);
	vec3 col = mix(color_nucleo.rgb, color_borde.rgb, f) * brillo * intensidad;
	float a = (1.0 - f * 0.85) * intensidad;
	ALBEDO = col * a;
	ALPHA = a * (1.0 - aditivo);
}
