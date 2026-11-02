shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled;

// RESPLANDOR ADITIVO (prueba 3 de VFX): un disco con caída suave. Con billboard completo detrás de la llama (halo) o tumbado en el suelo (charco de luz).
// `brillo` es el mando «halo» de EfectoToy.

uniform vec3 color : source_color = vec3(1.0, 0.28, 0.06);
uniform float brillo : hint_range(0.0, 3.0) = 0.8;
uniform float caida : hint_range(0.5, 6.0) = 2.4;     // más alto = más concentrado
uniform float tono : hint_range(0.0, 1.0) = 0.0;
uniform int billboard : hint_range(0, 2) = 2;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float latido : hint_range(0.0, 0.5) = 0.08;   // titileo suave
uniform float semilla = 0.0;
uniform float irreg : hint_range(0.0, 0.5) = 0.0;     // > 0: la forma del disco deja de ser un círculo (lóbulos de distinto tamaño que se mueven despacio)
uniform float anillo : hint_range(0.0, 1.0) = 0.0;    // 1 = disco hueco (para el borde de la barrera en el suelo)

// Suavizado (revisión de Pablo): apagado por defecto (0). `fade_canto` apaga el disco cuando se ve de canto (los discos tumbados en el suelo); `suave_prof` lo funde contra lo de detrás.
uniform float fade_canto : hint_range(0.0, 1.0) = 0.0;
uniform float suave_prof : hint_range(0.0, 3.0) = 0.0;
uniform sampler2D tex_prof : hint_depth_texture, repeat_disable, filter_nearest;

void vertex() {
	if (billboard == 2) {
		vec3 esc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(INV_VIEW_MATRIX[0].xyz * esc.x, 0.0), vec4(INV_VIEW_MATRIX[1].xyz * esc.y, 0.0), vec4(INV_VIEW_MATRIX[2].xyz * esc.z, 0.0), MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float borde_quad = 1.0 - smoothstep(0.78, 1.0, r);        // con `irreg` el disco puede crecer hasta el borde del quad: se funde antes para que no se vea el corte recto
	if (irreg > 0.0) {
		float ang = atan(p.y, p.x);
		r *= 1.0 + irreg * (0.5 * sin(ang * 3.0 + semilla * 6.28) + 0.3 * sin(ang * 5.0 - semilla * 11.0 + TIME * 0.4) + 0.2 * sin(ang * 9.0 + semilla * 3.0 - TIME * 0.7));
	}
	float f = pow(clamp(1.0 - r, 0.0, 1.0), caida);
	if (anillo > 0.0) {
		float k = exp(-pow((r - 0.68) / 0.2, 2.0));
		f = mix(f, k * 0.8, anillo);
	}
	if (irreg > 0.0) {
		f *= borde_quad;
	}
	float pulso = 1.0 + latido * sin(TIME * 5.3 + semilla * 6.28) + latido * 0.6 * sin(TIME * 9.1 + semilla * 3.0);
	vec3 c = mix(color, vec3(0.2, 0.5, 1.0), tono);
	float suave = 1.0;
	if (fade_canto > 0.0) {
		suave *= smoothstep(0.0, fade_canto, abs(dot(normalize(NORMAL), normalize(VIEW))));
	}
	if (suave_prof > 0.0) {
		float dp = texture(tex_prof, SCREEN_UV).r;
		if (dp > 0.00001) {
			vec4 w = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dp, 1.0);
			suave *= clamp((-w.z / w.w + VERTEX.z) / suave_prof, 0.0, 1.0);
		}
	}
	ALBEDO = c * f * brillo * 0.6 * pulso * vida * suave;
	ALPHA = 1.0;
}
