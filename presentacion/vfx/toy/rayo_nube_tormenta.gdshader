shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled, cull_back;

uniform vec3 centros[10];
uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float relampago : hint_range(0.0, 1.0) = 0.0;
uniform vec4 sombra : source_color = vec4(0.105, 0.135, 0.24, 1.0);
uniform vec4 cuerpo : source_color = vec4(0.25, 0.325, 0.49, 1.0);
uniform vec4 velo : source_color = vec4(0.47, 0.57, 0.73, 1.0);

// Debe coincidir con la mitad del tamaño del BoxMesh en RayoToy.
const vec3 LIMITES = vec3(1.34, 0.58, 1.15);
const int PASOS = 24;
varying vec3 entrada;
varying vec3 camara_local;
varying vec3 frente_local;

void vertex() {
	entrada = VERTEX;
	mat4 a_local = inverse(MODEL_MATRIX);
	camara_local = (a_local * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	frente_local = (a_local * vec4(-INV_VIEW_MATRIX[2].xyz, 0.0)).xyz;
}

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.11369, 0.13787));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float ruido(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), u.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), u.x), u.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), u.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), u.x), u.y),
		u.z);
}

float contorno(vec3 p) {
	float d = 1.0;
	for (int i = 0; i < 10; i++) {
		float tam = 0.70 + 0.11 * float(i % 3);
		float lobo = (length((p - centros[i]) / (vec3(0.48, 0.22, 0.58) * tam)) - 1.0) * 0.18;
		float union_suave = max(0.055 - abs(d - lobo), 0.0);
		d = min(d, lobo) - union_suave * union_suave / 0.22;
	}
	return d;
}

void fragment() {
	vec3 dir = normalize(mix(entrada - camara_local, frente_local, PROJECTION_MATRIX[3][3]));
	vec3 inv_dir = sign(dir + vec3(0.000001)) / max(abs(dir), vec3(0.00001));
	vec3 salida = max((LIMITES - entrada) * inv_dir, (-LIMITES - entrada) * inv_dir);
	float tramo = max(0.0, min(salida.x, min(salida.y, salida.z))) / float(PASOS);
	vec4 acumulado = vec4(0.0);
	for (int i = 0; i < PASOS; i++) {
		vec3 p = entrada + dir * tramo * (float(i) + 0.5);
		float d = contorno(p);
		if (d > 0.10) {
			continue;
		}
		// Vetas de niebla curvadas y en deriva lenta dentro del mismo volumen.
		vec3 q = p + vec3(p.z, 0.0, -p.x) * (0.32 * dot(p.xz, p.xz));
		float capa = ruido(q * vec3(3.8, 7.4, 5.5) + TIME * vec3(-0.18, 0.12, 0.08));
		float veta = ruido(q * vec3(8.3, 13.0, 11.5) + TIME * vec3(-0.26, 0.15, -0.12));
		float borde = d + (capa - 0.5) * 0.145 + (veta - 0.5) * 0.04;
		float densidad = 1.0 - smoothstep(-0.085, 0.048, borde);
		float luz = smoothstep(-0.32, 0.46, p.y + 0.33 * p.z + 0.34 * (capa - 0.5));
		vec3 color = mix(sombra.rgb, cuerpo.rgb, luz);
		color = mix(color, velo.rgb, smoothstep(0.46, 0.91, luz + 0.38 * (veta - 0.5)));
		color += vec3(0.10, 0.19, 0.38) * relampago * (1.0 - 0.6 * luz) * (0.45 + capa);
		float alpha = 1.0 - exp(-densidad * tramo * 6.4);
		acumulado += vec4(color * alpha, alpha) * (1.0 - acumulado.a);
		if (acumulado.a > 0.99) {
			break;
		}
	}
	ALBEDO = acumulado.rgb / max(acumulado.a, 0.0001);
	ALPHA = acumulado.a * vida;
}
