shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled;

// RESPLANDOR ADITIVO (prueba 3 de VFX): un disco con caída suave. Con billboard completo detrás de la llama (halo) o tumbado en el suelo (charco de luz).
// `brillo` es el mando «halo» de EfectoToy.

uniform vec3 color : source_color = vec3(1.0, 0.55, 0.14);
uniform float brillo : hint_range(0.0, 3.0) = 0.8;
uniform float caida : hint_range(0.5, 6.0) = 2.4;     // más alto = más concentrado
uniform float tono : hint_range(0.0, 1.0) = 0.0;
uniform int billboard : hint_range(0, 2) = 2;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float latido : hint_range(0.0, 0.5) = 0.08;   // titileo suave
uniform float semilla = 0.0;
uniform float anillo : hint_range(0.0, 1.0) = 0.0;    // 1 = disco hueco (para el borde de la barrera en el suelo)

void vertex() {
	if (billboard == 2) {
		vec3 esc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(INV_VIEW_MATRIX[0].xyz * esc.x, 0.0), vec4(INV_VIEW_MATRIX[1].xyz * esc.y, 0.0), vec4(INV_VIEW_MATRIX[2].xyz * esc.z, 0.0), MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float f = pow(clamp(1.0 - r, 0.0, 1.0), caida);
	if (anillo > 0.0) {
		float k = exp(-pow((r - 0.68) / 0.2, 2.0));
		f = mix(f, k * 0.8, anillo);
	}
	float pulso = 1.0 + latido * sin(TIME * 5.3 + semilla * 6.28) + latido * 0.6 * sin(TIME * 9.1 + semilla * 3.0);
	vec3 c = mix(color, vec3(0.2, 0.5, 1.0), tono);
	ALBEDO = c * f * brillo * pulso * vida;
	ALPHA = 1.0;
}
