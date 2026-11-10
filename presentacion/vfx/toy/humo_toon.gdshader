shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always, blend_mix, fog_disabled;

// HUMO TOON (6/11/2026, docs/HUMO_TOON_2026-11-06.md; la referencia es el «Stylized Smoke» de Gabriel Aguiar). Una BOCANADA por instancia de MultiMesh (quad billboard):
//   · SILUETA DE POMPAS: cuatro discos solapados (su reparto sale de la semilla de la instancia) con el borde «nuboso» por el ruido de nubes, y BORDE DURO (umbral + discard, sin alfa blanda).
//   · DOS TONOS PLANOS: color claro y UNA sombra de un solo tono, con luz fija arriba a la izquierda (la sombra es donde el campo desplazado hacia fuera de la luz se sale de la pompa).
//   · EROSIÓN AL MORIR: el umbral de disolución sube con la edad sobre el ruido: la bocanada se carcome desde los bordes y los últimos restos son jirones pequeños y oscuros.
//   · COLOR POR EDAD: vira del color de nacimiento al color «viejo» con la edad, no con la altura.
// INSTANCE_CUSTOM: r = edad 0..1, g = semilla 0..1 (reparto de las pompas y del ruido), b = giro (rad / TAU, 0..1) del billboard en pantalla, a = opacidad 0..1 (0 = oculta).
// Sin luz, sin emisión, sin GPUParticles3D: lo mueve humo_toy.gd por la CPU.

uniform vec3 color_claro : source_color = vec3(0.93, 0.93, 0.95);
uniform vec3 color_sombra : source_color = vec3(0.62, 0.62, 0.70);
uniform vec3 color_viejo : source_color = vec3(0.55, 0.52, 0.58);
uniform float erosion : hint_range(0.0, 1.0) = 0.8;             // cuánto se carcome al morir (0 = se encoge sin erosión)
uniform float umbral : hint_range(0.1, 0.9) = 0.42;             // umbral de la silueta (más alto = pompas más finas)
uniform float ruido_borde : hint_range(0.0, 0.6) = 0.22;        // cuánto rompe el ruido el borde de las pompas
uniform float sombra_desp : hint_range(0.0, 0.5) = 0.16;        // desplazamiento de la sombra (fracción del quad)
uniform float estirado : hint_range(0.2, 1.0) = 1.0;            // < 1: pompas más finas a lo ancho del quad (jirones de viento)
uniform float opacidad : hint_range(0.0, 1.0) = 1.0;           // < 1: el humo se ve a traves (el nucleo blando de la rafaga de viento); 1 = como siempre
uniform float edad_viejo : hint_range(0.0, 1.0) = 0.35;         // a partir de qué edad empieza a virar al color viejo
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;  // T_CloudNoise_Tiled

varying vec4 datos;

void vertex() {
	datos = INSTANCE_CUSTOM;
	float g = datos.b * 6.2831853;
	float cg = cos(g);
	float sg = sin(g);
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), 1.0);
	// billboard: ejes de la cámara, posición de la instancia, giro en pantalla y escala de la instancia
	mat4 giro = mat4(vec4(cg, sg, 0.0, 0.0), vec4(-sg, cg, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	mat4 esc = mat4(vec4(sc.x, 0.0, 0.0, 0.0), vec4(0.0, sc.y, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * bb * giro * esc;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

float hash1(float a) {
	return fract(sin(a * 12.9898) * 43758.5453);
}

// Campo de las pompas: 1 en el centro de cada disco, baja hacia su borde; la unión es el máximo (silueta de racimo, no de cuadrado).
float pompas(vec2 p, float sem) {
	float f = 0.0;
	for (int i = 0; i < 4; i++) {
		float k = float(i) * 1.37 + sem * 9.1;
		vec2 c = vec2(hash1(k + 1.0) - 0.5, hash1(k + 2.0) - 0.5) * 0.42;
		float r = 0.22 + 0.16 * hash1(k + 3.0);
		if (i == 0) {
			c *= 0.3;
			r = 0.34;
		}
		vec2 d = (p - c) / vec2(estirado, 1.0);
		f = max(f, 1.0 - length(d) / r);
	}
	return f;
}

void fragment() {
	if (datos.a < 0.01) {
		discard;
	}
	vec2 p = UV - 0.5;
	float sem = datos.g;
	float edad = datos.r;
	vec2 desp = vec2(sem * 3.7, sem * 5.3);
	float n = texture(ruido, UV * 0.9 + desp).r;
	float campo = pompas(p, sem) + (n - 0.5) * ruido_borde;
	// erosión: el umbral de disolución sube con la edad; se carcome donde el ruido es bajo
	float ero = smoothstep(0.45, 1.0, edad) * erosion;
	float n2 = texture(ruido, UV * 1.6 + desp.yx).r;
	float corte = umbral + ero * 0.5;
	if (campo < corte || n2 < ero) {
		discard;
	}
	// sombra plana de un solo tono: donde, desplazado hacia fuera de la luz (arriba-izquierda), se sale de la pompa
	vec2 luz = normalize(vec2(-0.6, 0.8));
	float f2 = pompas(p - luz * sombra_desp, sem) + (n - 0.5) * ruido_borde;
	float sombra = f2 < corte + 0.02 ? 1.0 : 0.0;
	// los restos finales se oscurecen
	float vieja = smoothstep(edad_viejo, 1.0, edad);
	vec3 claro = mix(color_claro, color_viejo, vieja);
	vec3 osc = mix(color_sombra, color_viejo * 0.72, vieja);
	ALBEDO = mix(claro, osc, sombra);
	ALPHA = 1.0;
	ALPHA *= opacidad;   // 1 salvo en el nucleo blando de la rafaga de viento
}
