// PORT de src/render/stage.js: rockMaterial (lejrimostfa/force-field-vfx-threejs, MIT; aviso en laboratorios/haz_gas/LICENSE_force_field_vfx.txt).
// Suelo y acantilado (y aqui tambien el MURO del lab). Su luz sale directamente de los campos del gas: el campo de fuego da color y direccion, la transmitancia de la
// lampara azul da la sombra del humo en su charco. Ninguna luz de Godot: un solo material sin iluminar.
// modo 0 suelo (uv = xz), 1 acantilado (uv = xy * (0.9, 3.1), normal +z), 2 caja (base de la cara, para el muro).
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform sampler2D roca : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler3D luz : filter_linear, repeat_disable;
uniform sampler3D luz_lejos : filter_linear, repeat_disable;
uniform sampler3D clave : filter_linear, repeat_disable;
uniform mat4 mundo_a_dominio;
uniform vec3 mundo_lo = vec3(-12.0, 0.0, -6.0);
uniform vec3 mundo_tam = vec3(24.0, 12.0, 12.0);
uniform vec3 key_pos = vec3(-12.5, 1.8, 1.5);
uniform float fire_on_rock = 7.0;
uniform float lamp_on_rock = 3.2;
uniform int modo = 0;
uniform float llanura = 2.2;

varying vec3 pd;
varying vec3 nd;

void vertex() {
	vec3 pw = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	pd = (mundo_a_dominio * vec4(pw, 1.0)).xyz;
	nd = normalize(mat3(mundo_a_dominio) * (mat3(MODEL_MATRIX) * NORMAL));
}

vec3 a_dominio(vec3 n, vec3 T, vec3 B, vec3 N0) {
	if (modo == 0) return vec3(n.x, n.z, n.y);
	if (modo == 1) return n;
	return T * n.x + B * n.y + N0 * n.z;
}

vec3 suave(vec3 c) { return c / (c.x * 1.6 + 1.0); }

void fragment() {
	vec3 N0 = normalize(nd);
	vec3 T = normalize(cross(abs(N0.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0), N0));
	vec3 B = cross(N0, T);
	vec2 uv = modo == 0 ? pd.xz : (modo == 1 ? pd.xy * vec2(0.9, 3.1) : vec2(dot(pd, T), dot(pd, B)));
	vec4 tex = texture(roca, uv * 0.21);
	vec4 fino = texture(roca, uv * 0.83);
	vec3 nA = tex.xyz * 2.0 - 1.0, nB = fino.xyz * 2.0 - 1.0;
	vec3 N = normalize(a_dominio(vec3(nA.x + nB.x * 0.6, nA.y + nB.y * 0.6, llanura), T, B, N0));
	vec3 albedo = mix(vec3(0.1, 0.085, 0.075), vec3(0.2, 0.17, 0.145), tex.w);

	// Luz del fuego. El gradiente del campo apunta a las llamas. Fuera de la caja, el valor del borde sigue cayendo con la distancia: la luz no tiene borde en el suelo.
	vec3 en_caja = clamp(pd, mundo_lo, mundo_lo + mundo_tam);
	float pasado = length(pd - en_caja);
	vec3 uvw = (en_caja - mundo_lo) / mundo_tam;
	vec3 cerca = texture(luz, uvw).xyz;
	vec3 fuego = suave(cerca + texture(luz_lejos, uvw).xyz) / (pasado * pasado * 0.05 + 1.0);
	const float e = 0.05;
	#define LUM(o) dot(texture(luz_lejos, uvw + (o)).xyz, vec3(0.3, 0.6, 0.1))
	vec3 grad = vec3(LUM(vec3(e, 0.0, 0.0)) - LUM(vec3(-e, 0.0, 0.0)), LUM(vec3(0.0, e * 2.0, 0.0)) - LUM(vec3(0.0, -e * 2.0, 0.0)), LUM(vec3(0.0, 0.0, e * 2.0)) - LUM(vec3(0.0, 0.0, -e * 2.0)));
	// El gradiente inclina la normal en vez de sustituirla: solo, se da la vuelta bajo el pico de la luz y pinta una costura en el suelo.
	vec3 a_fuego = normalize(grad / (LUM(vec3(0.0)) + 0.002) * 0.35 + a_dominio(vec3(0.0, 0.0, 1.0), T, B, N0));
	float dif = max(dot(N, a_fuego) * 0.75 + 0.25, 0.0);
	vec3 cam = (mundo_a_dominio * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec3 vista = normalize(cam - pd);
	float spec = pow(max(dot(N, normalize(a_fuego + vista)), 0.0), 36.0) * 0.5;

	// Lampara azul, con la sombra del humo del campo clave.
	vec3 to_key = key_pos - pd;
	float d2 = dot(to_key, to_key);
	vec3 K = normalize(to_key);
	float sombra = texture(clave, uvw).x;
	vec3 lampara = vec3(0.03, 0.2, 1.0) * max(dot(N, K), 0.0) * sombra * lamp_on_rock * exp(d2 / -70.0);
	// Direccion de arte: la lampara cae deprisa y su charco aparta el naranja: cada color se queda en su lado.
	float frio = smoothstep(0.2, 0.9, sombra * exp(d2 / -70.0));
	float spec_l = pow(max(dot(N, normalize(K + vista)), 0.0), 30.0) * sombra * 8.0 / (d2 + 50.0);

	ALBEDO = albedo * (fuego * fire_on_rock * dif * ((1.0 - frio) * 0.85 + 0.15) + lampara) + fuego * spec * fire_on_rock * 0.08 + vec3(0.03, 0.2, 1.0) * spec_l + vec3(0.003, 0.004, 0.008);
}
