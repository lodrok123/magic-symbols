shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled;

// ARO DE LA BASE DE LA BARRERA (ronda de Pablo, 2/11/2026): un anillo brillante y fino, amarillo-blanco con halo naranja, que ondula despacio (el ruido recorre el aro y lo
// hace grueso y fino) y un velo tenue dentro. Es un quad tumbado en el suelo de tamaño (2·rx·k, 2·rz·k): el aro cae donde la cúpula corta el suelo (`radio_aro` en unidades del quad).

uniform sampler2D ruido_a : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D rampa : source_color, filter_linear, repeat_disable;
uniform float radio_aro : hint_range(0.1, 1.0) = 0.8;
uniform float grosor : hint_range(0.005, 0.2) = 0.03;
uniform float brillo : hint_range(0.0, 3.0) = 1.0;
uniform float velocidad : hint_range(0.1, 4.0) = 1.0;
uniform float tono : hint_range(0.0, 1.0) = 0.0;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float semilla = 0.0;
uniform float fade_canto : hint_range(0.0, 1.0) = 0.0;
uniform float recorrido : hint_range(0.0, 1.0) = 1.0;   // 21/11 (inicio de la barrera): fracción del perímetro ya encendida; sale de +X y rodea hasta -X (1 = el aro entero, como siempre)
uniform float enfria : hint_range(0.0, 1.0) = 0.0;      // 21/11 (final de la barrera): el rescoldo pasa del blanco-naranja al rojo oscuro

void fragment() {
	float t = TIME * velocidad;
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x) / 6.28318;
	float n1 = texture(ruido_a, vec2(a * 3.0 + semilla, t * 0.12)).r;
	float n2 = texture(ruido_a, vec2(a * 3.0 - t * 0.12, 0.3 + t * 0.03)).r;
	float rr = r - (n1 - 0.5) * 0.025;                                  // el aro ondula
	float g = grosor * (0.7 + 0.9 * n2);
	float d = (rr - radio_aro) / g;
	float nucleo = exp(-d * d);
	float halo = exp(-pow((rr - radio_aro) / (g * 3.2), 2.0)) * 0.4 * (1.0 - smoothstep(0.82, 1.0, r));
	float velo_i = (1.0 - smoothstep(radio_aro - 0.08, radio_aro, r)) * 0.07 * (0.6 + 0.8 * n1);
	float f = nucleo + halo + velo_i;
	float an = abs(a) * 2.0;
	f *= 1.0 - smoothstep(recorrido * 1.1 - 0.1, recorrido * 1.1, an);
	f *= 1.0 + 1.2 * exp(-pow((an - recorrido) / 0.07, 2.0)) * (1.0 - step(0.999, recorrido));       // cabeza más brillante donde va el recorrido
	vec3 cn = texture(rampa, vec2(0.97 - 0.5 * enfria, 0.5)).rgb;
	vec3 ch = texture(rampa, vec2(0.52 - 0.3 * enfria, 0.5)).rgb;
	vec3 col = mix(ch, cn, clamp(nucleo, 0.0, 1.0));
	col = mix(col, col.bgr * vec3(0.4, 0.8, 1.0), tono);
	float s = 1.0;
	if (fade_canto > 0.0) {
		s = smoothstep(0.0, fade_canto, abs(dot(normalize(NORMAL), normalize(VIEW))));
	}
	ALBEDO = col * f * brillo * vida * s * 1.3;
	ALPHA = 1.0;
}
