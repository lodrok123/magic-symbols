shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

// SELLO DE HIELO (19/11/2026, Pablo, con un vídeo de un «ice breath»: «el cast debe extender la mano y aparecer este sello; desde ahí debe canalizarse un haz de hielo»).
// Un quad con un círculo mágico de copo de nieve dibujado por código: anillo doble, seis radios con sus ramas en V, un anillo interior y un hexágono en el centro. Gira despacio
// (`giro`, rad), se abre desde el centro (`abre` 0 → 1: escala del dibujo dentro del quad) y se apaga con `vida`. Mezcla normal, sin luz: el hielo no es luz.

uniform vec3 color : source_color = vec3(0.86, 0.97, 1.0);
uniform vec3 color_borde : source_color = vec3(0.3, 0.74, 1.0);
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float abre : hint_range(0.0, 1.3) = 1.0;
uniform float giro = 0.0;
uniform float grosor : hint_range(0.3, 3.0) = 1.0;
uniform float velo : hint_range(0.0, 1.0) = 0.22;        // relleno tenue dentro del sello

float linea(float d, float w) {
	return 1.0 - smoothstep(w * 0.45 * grosor, w * grosor, abs(d));
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q) / max(abre, 0.001);
	float a = atan(q.y, q.x) + giro;
	float sector = fract(a / TAU * 6.0);
	float ang_d = (0.5 - abs(sector - 0.5)) * TAU / 6.0;          // ángulo al radio más cercano (hay uno cada 60°)
	float arco = ang_d * r;                                       // …en distancia
	float f = 0.0;
	f = max(f, linea(r - 0.93, 0.03));
	f = max(f, linea(r - 0.83, 0.016));
	f = max(f, linea(r - 0.44, 0.02));
	f = max(f, linea(arco, 0.022) * step(0.1, r) * step(r, 0.93));
	// ramas en V a dos alturas de cada radio
	for (int k = 0; k < 2; k++) {
		float r0 = k == 0 ? 0.52 : 0.68;
		f = max(f, linea(arco - (r - r0) * 0.75, 0.02) * step(r0, r) * step(r, r0 + 0.15));
	}
	// hexágono del centro y puntas entre radios en el anillo de fuera
	float hex = r * cos(abs(sector - 0.5) * TAU / 6.0);
	f = max(f, linea(hex - 0.2, 0.02));
	float entre = abs(sector - 0.5) * TAU / 6.0 * r;
	f = max(f, linea(entre - (0.93 - r) * 0.5, 0.018) * step(0.83, r) * step(r, 0.93));
	float dentro = step(r, 1.0);
	float relleno = velo * (1.0 - smoothstep(0.0, 0.95, r)) * dentro;
	ALBEDO = mix(color_borde, color, clamp(f, 0.0, 1.0));
	ALPHA = clamp(max(f * dentro, relleno), 0.0, 1.0) * vida;
}
