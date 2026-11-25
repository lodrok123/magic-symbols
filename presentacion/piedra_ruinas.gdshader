shader_type spatial;
// PIEDRA DE RUINAS (25/11/2026): la losa de una trampa de pared (mascarón, dragón) con la MISMA piedra que los muros del pack Stylescape del estilo
// «ruinas» (presentacion/paredes_stylescape.gd, `integrar_trampa`). Sustituye al StandardMaterial3D de la pieza: lee su color, normal y rugosidad, y
// lo que es PIEDRA (poco saturado) pasa al beige de los muros conservando su claroscuro (el relieve tallado se sigue leyendo). Lo que tiene color
// (la cabeza roja del dragón, las brasas, los ojos) no se toca.

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 color : source_color = vec4(1.0);
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float usa_normal = 0.0;
uniform float rugosidad = 0.9;
uniform vec4 piedra : source_color = vec4(0.72, 0.63, 0.55, 1.0);   // el color medio de la piedra de los muros
uniform float lum_ref = 0.45;          // luminancia media de la piedra de la pieza: lo que se lleva al color de `piedra`
uniform float fuerza = 0.9;            // 0 = la pieza tal cual; 1 = toda su piedra al beige
uniform float sat_piedra = 0.22;       // hasta esta saturación es piedra; a partir de sat_piedra + 0.15, color (no se toca)
// Piezas SIN textura (las de primitivas: la peana del tótem, las losas de las trampas viejas): el ladrillo de los muros en proyección triplanar,
// para que no quede un bloque liso. `usa_muro` lo pone `integrar_trampa` cuando el material no tiene textura.
uniform sampler2D tex_muro : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float usa_muro = 0.0;
uniform float muro_escala = 0.43;      // repeticiones por u (la textura del muro cubre 4 m = 2,3 u)

varying vec3 p_mundo;
varying vec3 n_mundo;

void vertex() {
	p_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	n_mundo = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
}

void fragment() {
	vec4 c = texture(tex_albedo, UV) * color;
	if (usa_muro > 0.5) {
		vec3 w = n_mundo / max(n_mundo.x + n_mundo.y + n_mundo.z, 0.001);
		vec3 tri = texture(tex_muro, p_mundo.zy * muro_escala).rgb * w.x + texture(tex_muro, p_mundo.xz * muro_escala).rgb * w.y + texture(tex_muro, p_mundo.xy * muro_escala).rgb * w.z;
		// el claroscuro del ladrillo, más claro u oscuro según lo era la pieza (0,124 = la luminancia lineal de la piedra clara de las trampas); el tono lo pone `piedra` más abajo
		c.rgb = tri * clamp(dot(color.rgb, vec3(0.2126, 0.7152, 0.0722)) / 0.124, 0.2, 2.0) * 0.5;
	}
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float es_piedra = 1.0 - smoothstep(sat_piedra, sat_piedra + 0.15, sat);
	float lum = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 nueva = piedra.rgb * clamp(lum / max(lum_ref, 0.02), 0.25, 1.8);
	ALBEDO = mix(c.rgb, nueva, es_piedra * fuerza);
	ROUGHNESS = rugosidad;
	SPECULAR = 0.3;
	if (usa_normal > 0.5) {
		NORMAL_MAP = texture(tex_normal, UV).rgb;
	}
}
