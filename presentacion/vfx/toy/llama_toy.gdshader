shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// LLAMA BLANDA ESTILO LINK'S AWAKENING / ECHOES OF WISDOM (prueba 3 de VFX, 1/11/2026). Un plano con billboard en Y (o completo) en el que la silueta sale de
// un gradiente vertical menos dos ruidos que suben a distinta velocidad, con smoothstep ancho (nada de umbral duro), y un color en rampa continua
// blanco-amarillo -> amarillo -> naranja, con el borde translúcido y más claro. Sin cuantizar el tiempo, sin contorno, sin rojo oscuro.
// Los diez mandos que cambian el aspecto están en EfectoToy (el raíz de cada escena); aquí tienen el mismo nombre.

group_uniforms mandos;
uniform float altura : hint_range(0.3, 3.0) = 1.0;            // estira la llama hacia arriba
uniform float ancho : hint_range(0.3, 2.0) = 1.0;             // ensancha la llama
uniform float blandura : hint_range(0.05, 1.0) = 0.22;        // lo ancho del degradado del borde
uniform float ondulacion : hint_range(0.0, 1.5) = 0.6;        // cuánto se mecen y deforman las puntas
uniform float velocidad : hint_range(0.1, 4.0) = 1.0;         // velocidad a la que suben los ruidos
uniform float escala_ruido : hint_range(0.5, 6.0) = 2.2;      // tamaño de las ondas (más alto = más pequeñas)
uniform float brillo : hint_range(0.3, 3.0) = 1.0;            // intensidad del color (por encima de 1,3 entra en el resplandor)
uniform float tono : hint_range(0.0, 1.0) = 0.0;              // 0 fuego, 1 fuego azul
uniform float chisporroteo : hint_range(0.0, 1.0) = 0.6;   // ruido fino y rápido solo en las puntas (se rompen y desaparecen a saltos) y titileo rápido del brillo
uniform float transparencia : hint_range(0.2, 1.0) = 0.92;    // opacidad máxima del cuerpo
group_uniforms;

group_uniforms forma;
uniform vec2 tam = vec2(1.2, 1.6);                  // tamaño del plano en metros (sin altura ni ancho)
uniform float radio : hint_range(0.05, 3.0) = 0.42; // semiancho de la base en metros
uniform float punta_h : hint_range(0.1, 8.0) = 1.35;// altura de la punta en metros
uniform float afilado : hint_range(0.2, 3.0) = 0.7; // forma de la gota (bajo = rechoncha, alto = aguda)
uniform float radio_bola : hint_range(0.0, 2.0) = 0.0; // si > 0 el cuerpo es un círculo de ese radio (bola) con una punta pequeña
uniform float lobulos : hint_range(0.0, 1.0) = 0.30;     // cuánto muerde el ruido el borde (lóbulos redondos)
uniform float bultos : hint_range(0.0, 0.6) = 0.0;       // anchura que sube y baja en ondas (columna de bolas apiladas)
uniform float bultos_freq : hint_range(1.0, 14.0) = 6.0;  // bultos por metro
uniform float base_clara : hint_range(0.0, 1.0) = 0.6;   // cuánto se aclara el corazón de la base
uniform float borde_claro : hint_range(0.0, 1.0) = 0.5;  // cuánto se aclara el filo translúcido
uniform float semilla = 0.0;
uniform int billboard : hint_range(0, 2) = 1;        // 0 ninguno, 1 gira en Y hacia la cámara, 2 completo
uniform float vida : hint_range(0.0, 1.0) = 1.0;     // 0 apagado, 1 pleno (la animación nacer/morir)
group_uniforms;

varying vec2 v_tam;

// Ruido liso a base de senos con dominio deformado (sin celdas: el de valor con hash dejaba parches rectangulares). Devuelve ~0..1.
float vnoise(vec2 p) {
	float a = sin(p.x * 1.3 + sin(p.y * 1.1 + 1.7) * 1.5);
	float b = sin(p.y * 1.9 + p.x * 0.7 + sin(p.x * 2.3 + 0.6) * 1.2);
	float c = sin((p.x + p.y) * 2.9 + 4.1);
	return clamp(0.5 + 0.27 * a + 0.2 * b + 0.07 * c, 0.0, 1.0);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.65 + vnoise(p * 2.07 + 7.3) * 0.35;
}

#include "res://presentacion/vfx/toy/nucleo_toy.gdshaderinc"

void vertex() {
	VERTEX.y *= altura;
	VERTEX.x *= ancho;
	v_tam = tam;
	if (billboard > 0) {
		vec3 esc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		if (billboard == 1) {
			vec3 a = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
			a.y = 0.0;
			a = normalize(a + vec3(0.0, 0.0, 0.0001));
			vec3 der = normalize(cross(vec3(0.0, 1.0, 0.0), a));
			MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(der * esc.x, 0.0), vec4(0.0, esc.y, 0.0, 0.0), vec4(a * esc.z, 0.0), MODEL_MATRIX[3]);
		} else {
			MODELVIEW_MATRIX = nucleo_billboard(esc, VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
		}
	}
}

void fragment() {
	// posición en metros dentro del plano: x desde el centro, y desde la base
	vec2 m = vec2((UV.x - 0.5) * v_tam.x, (1.0 - UV.y) * v_tam.y);
	float t = TIME * velocidad;
	float yn = clamp(m.y / max(punta_h, 0.01), 0.0, 1.5);

	// dos ruidos que suben a distinta velocidad; el segundo se resta al primero
	float n1 = fbm(vec2(m.x * escala_ruido, m.y * escala_ruido * 0.75 - t * 0.9) + vec2(semilla * 13.0, 0.0));
	float n2 = fbm(vec2(m.x * escala_ruido * 1.7 + 3.1, m.y * escala_ruido * 1.3 - t * 1.6) + vec2(0.0, semilla * 7.0));
	float ru = n1 - n2 * 0.55;                      // ~ -0.3 .. 0.8

	// la llama se mece: la punta se ladea y se retuerce con más fuerza cuanto más arriba
	float mecer = (sin(t * 1.5 + semilla * 6.283 + yn * 2.2) * 0.16 + (n1 - 0.5) * 1.1) * ondulacion * yn * yn * radio * 2.4;

	// perfil de gota: semiancho que baja hasta cero en la punta, con la base redondeada
	float tope = 1.0 - clamp(yn, 0.0, 1.0);
	float hw = radio * pow(tope, afilado);
	float rb = radio * 0.95;
	float basey = clamp((rb - m.y) / rb, 0.0, 1.0);
	hw *= sqrt(max(0.0, 1.0 - basey * basey));
	hw *= 1.0 + bultos * sin(m.y * bultos_freq - t * 3.0 + semilla * 6.283) * (0.4 + ondulacion * 0.6);
	float dx = m.x - mecer;
	float ee = 0.12 * radio;
	float d = hw - (sqrt(dx * dx + ee * ee) - ee);        // valor absoluto suavizado: sin arruga en el eje de la llama
	// bola: un círculo que se pega a la base de la gota
	if (radio_bola > 0.0) {
		vec2 c = vec2(m.x - mecer * 0.3, m.y - radio_bola);
		float db = radio_bola - length(c);
		d = max(d, db * 0.95);
	}
	// el ruido muerde el borde y la punta (los lóbulos redondos de la referencia)
	d += (ru - 0.28) * lobulos * 1.6 * ondulacion * radio * (0.35 + yn);

	// chisporroteo: ruido de alta frecuencia, 2,5 veces más rápido que el grande, que solo actúa en el tercio de arriba de la lengua
	float arriba = smoothstep(0.5, 0.85, yn) * chisporroteo;
	float fino1 = vnoise(vec2(m.x * escala_ruido * 4.5 + semilla * 9.0, m.y * escala_ruido * 4.0 - t * 2.4 * 2.5));
	float fino2 = vnoise(vec2(m.x * escala_ruido * 7.0 + 3.7, m.y * escala_ruido * 6.0 - t * 2.4 * 3.2 + semilla * 5.0));
	d += (fino1 - 0.5) * 0.7 * radio * arriba;
	float suave = blandura * radio * 0.9 + 0.001;
	float cuerpo = smoothstep(0.0, suave, d);
	// la punta se deshace suavemente
	float punta = smoothstep(0.0, 0.35, (1.0 - yn) + (ru - 0.3) * 0.25 * ondulacion);
	float a = cuerpo * punta;
	a *= 1.0 - arriba * (1.0 - smoothstep(0.38, 0.5, fino2));         // pedacitos que se separan y se apagan a saltos

	// color: rampa continua naranja -> amarillo -> blanco amarillento, de dentro afuera y de abajo arriba
	float dentro = clamp(d / max(radio_bola, radio), 0.0, 1.0);
	float calor = clamp(dentro * 0.9 - yn * 0.3 + (ru - 0.25) * 0.3, 0.0, 1.0);
	calor = max(calor, base_clara * (1.0 - clamp(yn * 1.8, 0.0, 1.0)) * dentro);
	// ronda 2: borde rojo-anaranjado que se funde en transparencia, cuerpo naranja saturado, amarillo y blanco solo en un núcleo pequeño
	calor = pow(calor, 1.8);
	vec3 c_rojo = mix(vec3(0.85, 0.12, 0.03), vec3(0.05, 0.20, 0.85), tono);
	vec3 c_naranja = mix(vec3(1.0, 0.30, 0.03), vec3(0.15, 0.40, 1.0), tono);
	vec3 c_amarillo = mix(vec3(1.0, 0.62, 0.12), vec3(0.35, 0.75, 1.0), tono);
	vec3 c_blanco = mix(vec3(1.0, 0.88, 0.50), vec3(0.85, 0.97, 1.0), tono);
	vec3 col = mix(c_rojo, c_naranja, smoothstep(0.1, 0.72, calor));
	col = mix(col, c_amarillo, smoothstep(0.66, 0.92, calor));
	col = mix(col, c_blanco, smoothstep(0.88, 1.0, calor));
	// el filo translúcido más claro (el aro crema de la referencia)
	float filo = smoothstep(0.0, suave * 0.6, d) * (1.0 - smoothstep(suave * 0.6, suave * 2.2, d));
	col = mix(col, vec3(1.0, 0.42, 0.06), filo * borde_claro * 0.6);   // el filo es naranja intenso, no crema
	// el borde es más transparente que el centro: el cuerpo deja ver lo de detrás
	float a_final = a * mix(0.55, 1.0, smoothstep(0.0, 0.6, dentro)) * transparencia * vida;
	// que ningún borde del plano se vea nunca (el degradado llega a cero antes)
	float marco = smoothstep(0.0, 0.1, UV.x) * (1.0 - smoothstep(0.9, 1.0, UV.x)) * smoothstep(0.0, 0.08, UV.y) * (1.0 - smoothstep(0.97, 1.0, UV.y));
	a_final *= marco;
	float titila = 1.0 + 0.14 * chisporroteo * (sin(TIME * 9.3 + semilla * 31.0) * 0.6 + sin(TIME * 14.1 + semilla * 17.0) * 0.4);   // 8-15 Hz, irregular
	ALBEDO = col * brillo * titila;
	ALPHA = clamp(a_final, 0.0, 1.0);
}
