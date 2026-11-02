shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// BRIZNAS QUE CONVERGEN (carga del hechizo). Un MultiMesh de quads 1×1; cada instancia (INSTANCE_CUSTOM: xyz = dirección desde el centro, w = semilla) hace su propio viaje cíclico
// desde `radio_ext` hasta `radio_int` (acelerando, con un giro en espiral) y se dibuja como una brizna ALARGADA en pantalla, con la punta hacia la bola: se ve que van a la mano.
// La forma es el alfa de T_Windstreak3 (una gota de llama estirada); el color, la rampa de la bola. Sin humo, sin negro.

uniform sampler2D tex : filter_linear, repeat_disable;
uniform sampler2D rampa : source_color, filter_linear, repeat_disable;
uniform float radio_ext = 1.2;        // m: de dónde salen
uniform float radio_int = 0.3;        // m: dónde desaparecen (la superficie de la bola)
uniform float largo = 0.5;            // m: largo de la brizna al principio del viaje
uniform float ancho = 0.08;           // m
uniform float tasa = 1.6;             // viajes por segundo
uniform float remolino = 1.1;         // radianes que gira la dirección alrededor del eje de giro a lo largo del viaje
uniform vec3 eje = vec3(0.0, 1.0, 0.0);
uniform float brillo = 1.0;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float calor = 0.0;

varying float v_a;
varying float v_fase;

vec3 gira(vec3 v, vec3 k, float a) {
	return v * cos(a) + cross(k, v) * sin(a) + k * dot(k, v) * (1.0 - cos(a));
}

void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	float semilla = cd.w;
	float ph = fract(TIME * tasa * (0.85 + 0.3 * fract(semilla * 7.31)) + semilla);
	float e = ph * ph * (3.0 - 2.0 * ph) * 0.35 + ph * ph * 0.65;           // acelera hacia dentro
	float r = mix(radio_ext, radio_int, e);
	vec3 d = normalize(cd.xyz + vec3(0.0001));
	vec3 dr = gira(d, normalize(eje), remolino * e);
	vec3 mundo = (MODEL_MATRIX * vec4(dr * r, 1.0)).xyz;
	vec3 vc = (VIEW_MATRIX * vec4(mundo, 1.0)).xyz;
	vec2 dv = (VIEW_MATRIX * vec4(normalize((MODEL_MATRIX * vec4(dr, 0.0)).xyz), 0.0)).xy;
	float lon = length(dv);
	dv = lon > 0.02 ? dv / lon : vec2(0.0, 1.0);
	float esc = mix(1.0, 0.55, ph);
	float lg = largo * esc * (0.6 + 0.8 * fract(semilla * 3.7)) * mix(0.35, 1.0, lon);        // de cara a la cámara se acorta (perspectiva), no desaparece
	float an = ancho * esc;
	vec2 off = -dv * VERTEX.y * lg + vec2(-dv.y, dv.x) * VERTEX.x * an;       // la punta (arriba de la textura) mira hacia la bola
	POSITION = PROJECTION_MATRIX * vec4(vc + vec3(off, 0.0), 1.0);
	v_a = smoothstep(0.0, 0.18, ph) * (1.0 - smoothstep(0.78, 1.0, ph));
	v_fase = ph;
}

void fragment() {
	float forma = texture(tex, UV).a;
	forma = pow(forma, 0.8);
	float k = clamp(0.5 + 0.5 * forma + 0.15 * v_fase + calor, 0.0, 1.0);
	ALBEDO = texture(rampa, vec2(k, 0.5)).rgb * brillo;
	ALPHA = clamp(forma * v_a * vida, 0.0, 1.0);
}
