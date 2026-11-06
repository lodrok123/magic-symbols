shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// GRIETAS DE TIERRA EN EL SUELO (6/11/2026, TierraToy HAZ; referencia docs/capturas/referencias/tierra_pack/LEEME.md §1, solo la SECUENCIA). Un quad tumbado (PlaneMesh) a lo largo
// del haz: UV.y = 0 en la mano, 1 en la punta. Tres grietas NEGRAS finas que serpentean a lo largo con ramitas cortas, y que CORREN de la mano a la punta con `avance` (0..1: hasta
// dónde han llegado) antes de que broten las púas; se desvanecen con `vida`. Sin disco oscuro debajo (no es el cráter de magma): solo las líneas, a ras de suelo, toon (borde duro).

uniform float avance : hint_range(0.0, 1.0) = 1.0;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float semilla = 0.0;
uniform float grosor : hint_range(0.002, 0.08) = 0.022;
uniform vec3 color_grieta : source_color = vec3(0.05, 0.035, 0.03);

float hash1(float n) {
	return fract(sin(n * 127.1 + semilla * 311.7) * 43758.5453);
}

void fragment() {
	float v = UV.y;                                         // 0 mano … 1 punta
	float x = UV.x * 2.0 - 1.0;                             // -1 … 1 a lo ancho
	float g = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float c0 = (fi - 1.0) * 0.42 + (hash1(fi) - 0.5) * 0.25;                                    // de dónde parte (abanico desde la mano)
		float abre = 0.35 + 0.5 * hash1(fi + 2.0);                                                 // cuánto se abre hacia la punta
		float cx = c0 * (0.35 + abre * v) + 0.13 * sin(v * (9.0 + 5.0 * hash1(fi + 4.0)) + hash1(fi + 5.0) * 6.28) * (0.3 + v);
		float largo = 0.75 + 0.25 * hash1(fi + 3.0);
		float fin = min(largo, avance);
		float w = grosor * (1.2 - 0.6 * v) * (0.7 + 0.5 * sin(v * 41.0 + fi * 2.0));              // más fina hacia la punta, grosor quebrado
		float d = abs(x - cx);
		float dentro = step(v, fin) * step(0.02, v);
		g = max(g, (1.0 - step(w, d)) * dentro);
		// ramita corta a media altura, hacia un lado
		float rv = 0.3 + 0.4 * hash1(fi + 11.0);
		float lado = hash1(fi + 7.0) > 0.5 ? 1.0 : -1.0;
		float t = (v - rv) * 6.0;
		if (t > 0.0 && t < 1.0 && v < fin) {
			float bx = cx + lado * t * 0.25;
			g = max(g, 1.0 - step(w * 0.7, abs(x - bx)));
		}
	}
	// la punta de cada grieta se afila: en el último 8 % del avance se corta
	g *= 1.0 - smoothstep(avance - 0.06, avance, v);
	if (g < 0.5 || vida < 0.02) {
		discard;
	}
	ALBEDO = color_grieta;
	ALPHA = vida;
}
