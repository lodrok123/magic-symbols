// CUERPO COMÚN de las dos pasadas de la barrera (barrera_toy.gdshader = cara de delante, barrera_toy_trasera.gdshader = cara de atrás).
// Cáscara esférica translúcida: borde con resplandor (fresnel) y lenguas gordas y blandas que suben girando por la superficie. Sin cuantizar, sin contorno.

group_uniforms mandos;
uniform float altura : hint_range(0.3, 3.0) = 1.0;            // cuánto suben las lenguas por la cáscara
uniform float ancho : hint_range(0.3, 2.0) = 1.0;             // lo gordas que son
uniform float blandura : hint_range(0.05, 1.0) = 0.22;        // degradado del borde de cada lengua
uniform float ondulacion : hint_range(0.0, 1.5) = 0.6;        // cuánto se mecen las puntas
uniform float velocidad : hint_range(0.1, 4.0) = 1.0;         // velocidad del giro y de la subida
uniform float brillo : hint_range(0.3, 3.0) = 1.0;
uniform float tono : hint_range(0.0, 1.0) = 0.0;              // 0 fuego, 1 azul
uniform float transparencia : hint_range(0.2, 1.0) = 0.9;
group_uniforms;

group_uniforms forma;
uniform int lenguas : hint_range(3, 14) = 8;
uniform float giro : hint_range(-1.0, 1.0) = 0.3;             // vueltas por segundo (el signo cambia el sentido)
uniform float torsion : hint_range(0.0, 2.0) = 0.8;           // cuánto se enroscan al subir
uniform float resplandor_borde : hint_range(0.0, 1.0) = 0.35; // fuerza del borde luminoso de la cáscara
uniform float radio_esfera = 1.5;
uniform float y_suelo = -0.6;                                  // altura del suelo en coordenadas del objeto
uniform float vida : hint_range(0.0, 1.0) = 1.0;
group_uniforms;

varying vec3 pos_obj;

float hash(float x) {
	return fract(sin(x * 127.1 + 311.7) * 43758.5453);       // solo para elegir una cifra por lengua (valores sueltos, sin continuidad que cuidar)
}

float vnoise(vec2 p) {
	float a = sin(p.x * 1.3 + sin(p.y * 1.1 + 1.7) * 1.5);
	float b = sin(p.y * 1.9 + p.x * 0.7 + sin(p.x * 2.3 + 0.6) * 1.2);
	float c = sin((p.x + p.y) * 2.9 + 4.1);
	return clamp(0.5 + 0.27 * a + 0.2 * b + 0.07 * c, 0.0, 1.0);
}

void vertex() {
	pos_obj = VERTEX;
}

void fragment() {
	if (pos_obj.y < y_suelo) {
		discard;
	}
	vec3 n = normalize(pos_obj);
	float hy = clamp((pos_obj.y - y_suelo) / (radio_esfera - y_suelo), 0.0, 1.0);     // 0 en el suelo, 1 en lo alto
	float ang = atan(n.z, n.x) / 6.2831853;
	float t = TIME * velocidad;
	float k = float(lenguas);
	float a = ang + hy * torsion * 0.35 - t * giro;
	float cel = a * k;
	float id = floor(cel);
	float fx = fract(cel) - 0.5;                                                         // -0.5 .. 0.5 dentro de la lengua
	float azar = hash(id + 7.7);
	float alt = (0.45 + 0.4 * azar) * altura * (0.85 + 0.3 * vnoise(vec2(id * 3.1, t * 0.7)));
	alt = min(alt, 0.95);
	// la punta se mece a un lado
	float mece = (sin(t * 1.9 + id * 1.7) * 0.12 + (vnoise(vec2(id * 1.3 + 4.0, hy * 3.0 - t * 1.1)) - 0.5) * 0.45) * ondulacion * hy;
	float h_rel = clamp(hy / max(alt, 0.01), 0.0, 1.0);
	float semiancho = 0.44 * ancho * pow(1.0 - h_rel, 0.55) * (0.8 + 0.2 * azar);
	semiancho *= sqrt(max(0.0, 1.0 - pow(clamp((0.08 - hy) / 0.08, 0.0, 1.0), 2.0)));    // base redondeada
	float d = semiancho - abs(fx - mece);
	d += (vnoise(vec2(fx * 4.0 + id, hy * 5.0 - t * 1.4)) - 0.4) * 0.12 * ondulacion;
	float suave = blandura * 0.35 + 0.005;
	float lengua = smoothstep(0.0, suave, d) * smoothstep(0.0, 0.18, alt - hy + (vnoise(vec2(id, hy * 4.0 - t)) - 0.5) * 0.1);
	// franja de base continua (el anillo de fuego que toca el suelo)
	float franja = (1.0 - smoothstep(0.05, 0.16 + 0.07 * vnoise(vec2(ang * 18.0 - t * 1.5, 1.3)), hy));
	// borde de la cáscara: más luminoso donde la superficie se ve de canto
	float fres = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.4);
	float cascara = fres * resplandor_borde + 0.05 * (1.0 - hy);

	float dentro = clamp(d / 0.3, 0.0, 1.0);
	float calor = clamp(dentro * 0.42 + (1.0 - h_rel) * 0.28 - 0.06 + franja * 0.45, 0.0, 1.0);
	calor = pow(calor, 1.8);
	vec3 c_rojo = mix(vec3(0.85, 0.12, 0.03), vec3(0.05, 0.20, 0.85), tono);
	vec3 c_naranja = mix(vec3(1.0, 0.30, 0.03), vec3(0.15, 0.40, 1.0), tono);
	vec3 c_amarillo = mix(vec3(1.0, 0.62, 0.12), vec3(0.35, 0.75, 1.0), tono);
	vec3 c_blanco = mix(vec3(1.0, 0.88, 0.50), vec3(0.85, 0.97, 1.0), tono);
	vec3 col = mix(c_rojo, c_naranja, smoothstep(0.1, 0.72, calor));
	col = mix(col, c_amarillo, smoothstep(0.62, 0.9, calor));
	col = mix(col, c_blanco, smoothstep(0.88, 1.0, calor));
	float filo = smoothstep(0.0, suave * 0.6, d) * (1.0 - smoothstep(suave * 0.6, suave * 2.4, d));
	col = mix(col, vec3(1.0, 0.42, 0.06), filo * 0.4);
	vec3 col_cascara = mix(c_naranja, c_amarillo, 0.25);
	float a_len = max(lengua, franja * 0.9);
	vec3 c_fin = mix(col_cascara, col, clamp(a_len * 1.5, 0.0, 1.0));
	float alfa = max(a_len * 0.85, cascara) * transparencia * vida;
	ALBEDO = c_fin * brillo;
	ALPHA = clamp(alfa, 0.0, 1.0);
}
