shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;        // sin cull: las mallas facetadas (hielo_mallas._tri) no garantizan el sentido de giro de cada cara

// ROCA DE TIERRA «TOY» (6/11/2026; referencia Echoes of Wisdom): MACIZA, MATE, de SOMBRAS DURAS. Opaca (sin ALPHA: va por la pasada opaca), sin luz de la escena: tres tonos planos por
// orientación de cada CARA respecto a una luz fija arriba a la izquierda (claro / medio / sombra, escalones duros), con las aristas un poco más claras y la base un poco más oscura (tierra).
// Malla: normales planas por cara, COLOR.r = altura 0..1 (hielo_mallas.gd: bloque, cristal; TierraToy._prisma). Con `instancias` = 1 (MultiMesh) INSTANCE_CUSTOM: r = variación de tono 0..1.

uniform vec3 color_claro : source_color = vec3(0.85, 0.66, 0.40);     // Vfx3D.COLOR["tierra"]
uniform vec3 color_medio : source_color = vec3(0.66, 0.50, 0.31);
uniform vec3 color_sombra : source_color = vec3(0.46, 0.33, 0.21);
uniform vec3 color_base : source_color = vec3(0.52, 0.38, 0.22);      // Vfx3D perfil tierra «nucleo»
uniform float instancias : hint_range(0.0, 1.0) = 0.0;
uniform float oscurecer : hint_range(0.0, 1.0) = 0.0;                 // 1: toda la roca más oscura (fragmentos, polvo de la base)
uniform float brillo : hint_range(0.3, 3.0) = 1.0;

varying float altura;
varying float tono;

void vertex() {
	altura = COLOR.r;
	tono = instancias > 0.5 ? INSTANCE_CUSTOM.r : 0.5;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 luz = normalize(vec3(-0.45, 0.8, 0.4));
	float d = dot(n, (mat3(VIEW_MATRIX) * luz));
	vec3 col = d > 0.35 ? color_claro : (d > -0.15 ? color_medio : color_sombra);
	float arista = 1.0 - smoothstep(0.0, 0.06, min(UV.x, 1.0 - UV.x));
	col = mix(col, color_claro * 1.08, arista * 0.35 * step(0.35, d));
	col = mix(col, color_base, (1.0 - smoothstep(0.0, 0.25, altura)) * 0.45);
	col *= mix(0.9, 1.08, tono);
	col *= 1.0 - 0.35 * oscurecer;
	ALBEDO = col * brillo;
}
