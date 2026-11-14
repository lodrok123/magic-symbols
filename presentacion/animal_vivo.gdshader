// ANIMAL VIVO (14/11/2026, Pablo: «los animales deben respirar o hacer alguna acción aunque sea en bucle; no deben ser muebles»).
// Los modelos de Meshy llegan sin esqueleto: el movimiento es una deformación por ZONAS en el espacio del modelo (la cabeza mira a −X, la cola a +X).
//   respirar   el tronco se hincha a lo largo de su normal (vientre y lomo), con un ciclo lento
//   cabeza     gira alrededor del cuello: cabeceo (pitch) + un poco de lado a lado (yaw); para el cerdo, hocicar el suelo
//   cola       barre de lado a lado a ráfagas irregulares (no como un reloj)
// `fase` desfasa cada animal (instance uniform: dos cerdos no respiran a la vez). Los números se ajustan desde el material de cada animal.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D textura : source_color, filter_linear_mipmap;
uniform vec3 tinte : source_color = vec3(1.0);
instance uniform float fase = 0.0;
// Lo que queda por debajo de esta altura no se mueve (la cama de paja de la vaca va en el mismo modelo).
uniform float suelo_y = -9.0;

// Respirar
uniform float resp_periodo = 4.0;           // s por respiración
uniform float resp_amp = 0.012;             // cuánto se hincha (unidades del modelo, que mide 1 de largo)
uniform vec2 resp_tronco = vec2(-0.3, 0.3); // franja en X que respira (el tronco)
// Cabeza
uniform float cabeza_x = -0.3;              // desde aquí hacia −X es cabeza (el cuello)
uniform float cabeza_suave = 0.08;
uniform vec3 cuello = vec3(-0.3, 0.05, 0.0);// pivote del giro de la cabeza
uniform float cabeceo_amp = 0.06;           // radianes
uniform float cabeceo_periodo = 5.0;
uniform float lado_amp = 0.04;
uniform float lado_periodo = 3.1;
uniform float hocicar = 0.0;                // 1 = el cerdo: baja la cabeza al suelo a golpes cortos además del cabeceo
// Cola
uniform float cola_x = 0.38;                // desde aquí hacia +X es cola
uniform float cola_suave = 0.06;
uniform vec3 raiz_cola = vec3(0.38, 0.1, 0.0);
uniform float cola_amp = 0.5;
uniform float cola_rapida = 9.0;            // rad/s del barrido
uniform float cola_cada = 7.0;              // s entre ráfagas

mat3 giro_y(float a) { float c = cos(a); float s = sin(a); return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c)); }
mat3 giro_z(float a) { float c = cos(a); float s = sin(a); return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0)); }

void vertex() {
	float t = TIME + fase * 17.0;
	vec3 p = VERTEX;
	float vivo = smoothstep(suelo_y, suelo_y + 0.03, p.y);
	// Respirar: solo el tronco, más en el centro.
	float tronco = smoothstep(resp_tronco.x - 0.1, resp_tronco.x, p.x) * (1.0 - smoothstep(resp_tronco.y, resp_tronco.y + 0.1, p.x)) * vivo;
	float r = 0.5 + 0.5 * sin(t * 6.2832 / resp_periodo);
	p += NORMAL * resp_amp * r * tronco;
	// Cabeza.
	float cab = (1.0 - smoothstep(cabeza_x - cabeza_suave, cabeza_x + cabeza_suave, p.x)) * vivo;
	float pitch = cabeceo_amp * sin(t * 6.2832 / cabeceo_periodo);
	if (hocicar > 0.0) {
		// golpes de hocico: baja rápido, sube despacio, cada ~1,6 s
		float g = fract(t / 1.6);
		pitch += hocicar * 0.12 * (g < 0.25 ? sin(g / 0.25 * 3.1416) : 0.0);
	}
	float yaw = lado_amp * sin(t * 6.2832 / lado_periodo + 1.3);
	vec3 q = p - cuello;
	q = giro_y(yaw) * giro_z(pitch) * q;
	p = mix(p, q + cuello, cab);
	// Cola: ráfagas.
	float cola = smoothstep(cola_x - cola_suave, cola_x + cola_suave, p.x) * vivo;
	float rafaga = smoothstep(0.75, 1.0, sin(t * 6.2832 / cola_cada)) ;
	float barrido = cola_amp * rafaga * sin(t * cola_rapida);
	vec3 c = p - raiz_cola;
	c = giro_y(barrido * (p.x - raiz_cola.x) * 6.0) * c;
	p = mix(p, c + raiz_cola, cola);
	VERTEX = p;
}

void fragment() {
	ALBEDO = texture(textura, UV).rgb * tinte;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
