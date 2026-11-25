shader_type spatial;
// SOMBRA DE CONTACTO AL PIE DE LOS MUROS DE RUINAS (25/11/2026, Pablo: «la base del muro acaba recta, el encuentro se siente artificial; una sombra
// estrecha y suave pegada a la base, más oscura justo en el contacto»). Una franja plana sobre el suelo, pegada a la cara del muro, que OSCURECE
// lo que hay debajo: muy oscura en el contacto y se desvanece hacia fuera. El ancho ondula a lo largo del muro (ruido por posición en el mundo) para
// que el borde no sea una regla. La pieza (arte/stylescape/piezas/ss_sombra_base.tscn) la crea herramientas/generar_piezas_stylescape.gd: el eje Z
// local va de la cara del muro (z = 0) hacia fuera; la coloca presentacion/paredes_stylescape.gd (`sombras_base`).
render_mode blend_mix,unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// (Con blend_mul no oscurecía nada en Forward+: se mezcla hacia un pardo oscuro, que viene a ser lo mismo.)
uniform vec3 oscuro : source_color = vec3(0.16, 0.12, 0.09);   // pardo oscuro cálido, no negro
uniform float fuerza = 0.65;          // opacidad justo en el contacto
uniform float ancho = 0.42;            // u: hasta dónde llega como mucho
uniform float caida = 0.32;            // fracción del ancho en la que ya ha perdido casi todo (más chico = más pegada)
uniform float ondula = 0.35;           // cuánto varía el ancho a lo largo del muro

varying float dist;
varying vec3 p_mundo;

void vertex() {
	dist = VERTEX.z;
	p_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float r = sin(p_mundo.x * 3.7 + p_mundo.z * 2.9) * 0.5 + sin(p_mundo.x * 9.3 - p_mundo.z * 7.1) * 0.3 + sin((p_mundo.x + p_mundo.z) * 17.0) * 0.2;
	float a = ancho * (1.0 - ondula * 0.5 + ondula * 0.5 * r);
	float d = max(dist, 0.0) / max(a, 0.01);
	float f = exp(-d / caida) * (1.0 - smoothstep(0.7, 1.0, d));
	ALBEDO = oscuro;
	ALPHA = f * fuerza;
}
