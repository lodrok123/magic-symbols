// VÉRTICES DEL TRAZO DE RAYO (los comparten rayo_trazo.gdshader y rayo_trazo_cuerpo.gdshader). Un quad por tramo que mira a la cámara y se ALARGA en pantalla a lo largo del tramo (si viene hacia la cámara se
// queda redondo); las puntas se prolongan un poco para que los tramos se solapen en los codos. MultiMesh movido por la CPU (RayoTrazos).
// INSTANCE_CUSTOM: r = grosor del halo respecto al ancho del quad (1 = tronco; 0,5 = rama), g = opacidad, b = parpadeo (0 = quieto, 1 = muy irregular), a = fase.
// En la transformación de la instancia: eje Y = el tramo (mundo) × largo, eje X/Z = ancho.

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
	float largo_vis = max(ancho, largo * (l2 / l3)) + ancho * 0.9;          // + las puntas: se solapan con el tramo siguiente
	vec2 lado = vec2(-dir.y, dir.x);
	vec2 q = vec2(VERTEX.x * ancho, VERTEX.y * largo_vis);
	POSITION = PROJECTION_MATRIX * vec4(centro + vec3(lado * q.x + dir * q.y, 0.0), 1.0);
}

// Distancia al eje del trazo (0 = eje, 1 = borde del quad), con las puntas redondeadas, y el parpadeo del tramo.
float trazo_d(vec2 uv) {
	float dx = abs(uv.x - 0.5) * 2.0;
	float dy = max(abs(uv.y - 0.5) * 2.0 - 0.72, 0.0) / 0.28;
	return length(vec2(dx, dy));
}

float trazo_par() {
	return clamp(1.0 - datos.b * 0.45 * (0.5 + 0.5 * sin(TIME * 90.0 * velocidad + datos.a * 40.0)), 0.0, 1.0);
}
