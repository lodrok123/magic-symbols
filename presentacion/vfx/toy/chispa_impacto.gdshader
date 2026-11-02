shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled;

// CHISPAS DEL IMPACTO Y DE LA CARGA (rama fuego-toy-carga-impacto, revisión de Pablo del 2/11/2026). Un MultiMesh de quads en el que CADA instancia es una chispa: la CPU (ImpactoFuegoToy / CargaToy)
// pone en su transformación el eje Y = dirección de su velocidad (en mundo) × largo, y el eje X/Z = ancho, así que aquí solo hay que dibujar el trazo mirando a la cámara:
//   · el trazo se tumba en pantalla a lo largo de la velocidad proyectada (si la chispa viene hacia la cámara, se acorta hasta ser un punto: no hay láminas de canto);
//   · la cabeza (donde está la chispa) es la parte más brillante, la cola se desvanece; el color sale de la rampa de la bola (blanco-amarillo → naranja), sin rojo oscuro.
// INSTANCE_CUSTOM: r = calor (1 blanco-amarillo, 0 naranja), g = opacidad, b = 1 para una brasa (punto redondo, sin trazo), a = reservado.

uniform sampler2D rampa : source_color, filter_linear, repeat_disable;
uniform float brillo : hint_range(0.0, 4.0) = 1.4;
uniform vec2 tramo = vec2(0.5, 1.0);        // tramo de la rampa que se usa (0.5 ≈ naranja; por debajo se iría al rojo)

varying vec4 datos;

void vertex() {
	datos = INSTANCE_CUSTOM;
	vec3 centro = MODELVIEW_MATRIX[3].xyz;
	vec3 yv = (VIEW_MATRIX * vec4(MODEL_MATRIX[1].xyz, 0.0)).xyz;
	float largo = length(MODEL_MATRIX[1].xyz);
	float ancho = length(MODEL_MATRIX[0].xyz);
	float l3 = max(length(yv), 0.00001);
	vec2 d2 = yv.xy;
	float l2 = length(d2);
	vec2 dir = l2 > 0.00001 ? d2 / l2 : vec2(0.0, 1.0);
	float largo_vis = max(ancho, largo * (l2 / l3));            // largo proyectado: viniendo hacia la cámara se queda en un punto
	vec2 lado = vec2(-dir.y, dir.x);
	vec2 q = vec2(VERTEX.x * ancho, (VERTEX.y - 0.5) * largo_vis + 0.5 * ancho);     // la cabeza (VERTEX.y = 0,5) queda en el centro de la instancia
	POSITION = PROJECTION_MATRIX * vec4(centro + vec3(lado * q.x + dir * q.y, 0.0), 1.0);
}

void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float y = UV.y;                                              // 0 = cabeza, 1 = cola
	float a;
	if (datos.b > 0.5) {
		float r = length(vec2(x, UV.y * 2.0 - 1.0));
		a = pow(clamp(1.0 - r, 0.0, 1.0), 1.4);
	} else {
		float ancho_y = mix(1.0, 0.12, pow(y, 0.7));
		float across = 1.0 - smoothstep(0.0, ancho_y, x);
		a = across * pow(1.0 - y, 1.5);
	}
	float cabeza = exp(-y * y * 26.0) * (1.0 - smoothstep(0.0, 1.0, x));
	float k = clamp(mix(tramo.x, tramo.y, datos.r), 0.0, 1.0);
	vec3 col = texture(rampa, vec2(k, 0.5)).rgb;
	col = mix(col, vec3(1.0, 0.95, 0.78), cabeza * 0.7 * datos.r);
	ALBEDO = col * brillo;
	ALPHA = clamp(a * datos.g, 0.0, 1.0);
}
