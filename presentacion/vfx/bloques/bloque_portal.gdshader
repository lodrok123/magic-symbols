shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// PORTAL (25/11/2026, efectos «bloques», a partir de las capturas de la demo de EffectBlocks que pasó Pablo; hecho desde cero, nada de la demo).
// Un QUAD vertical con un disco de espirales que giran hacia dentro, hueco en el centro y un aro brillante en el borde. Mezcla NORMAL, no aditiva: lo aditivo lavaba el
// naranja a crema sobre suelo claro (lección de aro_choque.gdshader). Los colores los pone bloques_vfx.gd con la paleta del elemento.

uniform vec3 color_borde : source_color = vec3(1.0, 0.5, 0.15);
uniform vec3 color_dentro : source_color = vec3(1.0, 0.28, 0.06);
uniform float fuerza : hint_range(0.0, 4.0) = 1.4;          // brillo (más de 1 pasa el umbral del glow)
uniform float vueltas : hint_range(0.5, 8.0) = 3.0;         // cuántas bandas hay del centro al borde
uniform float brazos : hint_range(1.0, 6.0) = 3.0;          // brazos de la espiral (se redondea: tiene que ser entero para cerrar la vuelta)
uniform float velocidad : hint_range(-3.0, 3.0) = 0.55;     // bandas por segundo hacia dentro
uniform float hueco : hint_range(0.0, 0.8) = 0.22;          // radio del centro vacío (0..1)
uniform float opacidad : hint_range(0.0, 1.0) = 0.85;
uniform float apertura : hint_range(0.0, 1.0) = 1.0;        // 0 cerrado, 1 abierto: para que nazca y muera

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p) / max(apertura, 0.001);
	if (r > 1.0) {
		discard;
	}
	float a = atan(p.y, p.x);
	float v = r * vueltas * TAU + TIME * velocidad * TAU + a * floor(brazos + 0.5);
	float bandas = smoothstep(0.15, 0.85, 0.5 + 0.5 * sin(v));
	float cuerpo = smoothstep(hueco, hueco + 0.25, r) * (1.0 - smoothstep(0.86, 0.98, r));
	float aro = exp(-pow((r - 0.9) / 0.05, 2.0));
	vec3 c = mix(color_dentro, color_borde, smoothstep(0.3, 0.95, r));
	ALBEDO = c * fuerza * (0.7 + 0.6 * aro);
	ALPHA = clamp(bandas * cuerpo * opacidad + aro * 0.95, 0.0, 1.0);
}
