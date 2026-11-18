shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_back, shadows_disabled;

// ARDIENDO (cuerpo): capa que se pone en `material_overlay` de cada malla de un enemigo que arde (ArdiendoToy). El cuerpo se ve incandescente:
// manchas de calor que suben (ruido 3D en el mundo, igual en todas las mallas), borde (fresnel) rojo, interior naranja intenso, y los picos de brillo
// llegan a un naranja claro, NUNCA a amarillo ni a blanco. Parpadea. `intensidad` (0-1) es el fundido de entrada y de salida.

uniform float intensidad : hint_range(0.0, 1.0) = 1.0;
uniform float fase = 0.0;
uniform vec3 color_borde : source_color = vec3(0.85, 0.12, 0.03);      // rojo del rim
uniform vec3 color_nucleo : source_color = vec3(1.0, 0.33, 0.05);      // naranja intenso del cuerpo
uniform vec3 color_pico : source_color = vec3(1.0, 0.5, 0.14);         // lo más claro: naranja claro, sin amarillo
uniform float potencia_borde = 2.2;
uniform float escala_ruido = 7.0;
uniform float sube = 0.9;                                              // m/s a los que suben las manchas de calor
uniform vec3 color_frio : source_color = vec3(0.55, 0.07, 0.02);      // rojo oscuro de las zonas frías
uniform float alfa_frio = 0.62;
uniform float alfa_base = 0.8;
uniform float alfa_borde = 0.85;
uniform float brillo = 1.0;                                           // × el color (HDR suave para el bloom)

varying vec3 vp;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float ruido(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	vp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 q = vp * escala_ruido + vec3(fase, -TIME * sube * escala_ruido * 0.5 + fase, fase * 0.7);
	float m = ruido(q) * 0.65 + ruido(q * 2.3 + vec3(5.2, 1.7, 3.1)) * 0.35;     // manchas de calor
	float parpadeo = 0.9 + 0.1 * sin(TIME * 17.0 + fase * 3.0) * sin(TIME * 7.3 + fase);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), potencia_borde);
	float calor = smoothstep(0.38, 0.8, m);
	// interior: rojo oscuro donde está más frío (oscurece el modelo y da contraste) y naranja intenso donde hay calor; los picos, naranja claro
	vec3 caliente = mix(color_nucleo, color_pico, smoothstep(0.72, 0.98, m));
	vec3 interior = mix(color_frio, caliente, calor);
	float alfa_int = mix(alfa_frio, alfa_base, calor);
	// borde: rojo vivo, y casi opaco
	float b = clamp(fres * 1.4, 0.0, 1.0);
	vec3 col = mix(interior, color_borde, b);
	float a = mix(alfa_int, alfa_borde, b);
	ALBEDO = col * brillo * parpadeo;
	ALPHA = clamp(a * parpadeo, 0.0, 0.95) * intensidad;
}
