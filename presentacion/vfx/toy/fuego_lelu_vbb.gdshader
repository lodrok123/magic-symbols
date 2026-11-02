shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

// LÁMINAS DE FUEGO COMO BILLBOARD DE EJE VERTICAL (revisión de Pablo, 2/11/2026: «las láminas se notan muy 2D, sobre todo en las tomas horizontales»).
// El mismo fragment que las bandas (fuego_lelu.gdshaderinc, con VBB definido) pero sobre cuadrículas sueltas (MultiMesh): cada instancia es una lámina de w × h metros que
// GIRA alrededor de su eje Y para mirar a la cámara (la base se construye con el eje Y del modelo y la dirección de la cámara proyectada en el plano horizontal), repartidas por el
// volumen del hechizo (varias filas en profundidad), de modo que de canto se ve una masa y no una raya. Cada una lleva su semilla, su fase de tiempo, su calor y su opacidad
// en INSTANCE_CUSTOM = (semilla, calor, fase, opacidad).
// Con la cámara alta (la del juego) casi no se ven: `el_*` las atenúan según la elevación de la cámara, y ahí manda la banda de siempre.

#define VBB
varying float sem_i;
varying float fase_i;
varying float hot_i;
varying float alfa_i;
varying float el_i;
varying float canto_i;
varying float w_i;
varying float h_i;

group_uniforms volumen;
uniform float el_ini : hint_range(0.0, 1.0) = 0.2;        // sen(elevación de la cámara) hasta el que las láminas están a plena opacidad
uniform float el_fin : hint_range(0.0, 1.0) = 0.46;       // sen(elevación) a partir del que quedan en el mínimo (0,46 = 27°: la cámara del juego, a 30°, ya no las ve)
uniform float el_min : hint_range(0.0, 1.0) = 0.0;        // opacidad que conservan con la cámara alta SI la banda se ve de canto (solo con `usa_normal`)
uniform float usa_normal : hint_range(0.0, 1.0) = 0.0;    // 1 (muro): la banda tiene una cara (el eje Z del nodo); con la cámara alta las láminas solo ayudan al mirar a lo largo, que es donde la banda se desvanece
uniform float borde_u : hint_range(0.01, 0.5) = 0.3;      // fundido de los lados (para que no se vea el corte vertical de cada lámina)
uniform float afila : hint_range(0.2, 1.0) = 0.8;         // anchura relativa arriba (la lengua se estrecha hacia la punta)
group_uniforms;

float vbb_factor(vec2 uv) {
	float b = smoothstep(0.0, borde_u, uv.x) * (1.0 - smoothstep(1.0 - borde_u, 1.0, uv.x));
	float e = mix(1.0, el_min * canto_i * canto_i, smoothstep(el_ini, el_fin, el_i));
	return b * e * alfa_i;
}

#include "res://presentacion/vfx/toy/fuego_lelu.gdshaderinc"

void vertex() {
	vec3 esc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 to = vec3(INV_VIEW_MATRIX[2].x, 0.0, INV_VIEW_MATRIX[2].z);          // hacia la cámara, en el plano horizontal (vale para cámara ortogonal y en perspectiva)
	float lh = length(to);
	to = lh > 0.001 ? to / lh : vec3(0.0, 0.0, 1.0);
	vec3 der = vec3(to.z, 0.0, -to.x);                                        // arriba × hacia-la-cámara
	sem_i = INSTANCE_CUSTOM.x;
	hot_i = INSTANCE_CUSTOM.y;
	fase_i = INSTANCE_CUSTOM.z;
	alfa_i = INSTANCE_CUSTOM.w;
	el_i = INV_VIEW_MATRIX[2].y;
	vec3 nw = vec3(MODEL_MATRIX[2].x, 0.0, MODEL_MATRIX[2].z);                // cara de la banda del muro (Z local del nodo) en el plano horizontal
	nw = length(nw) > 0.001 ? normalize(nw) : to;
	canto_i = usa_normal * (1.0 - abs(dot(to, nw)));                         // 0 = de frente a la cara, 1 = a lo largo del muro
	w_i = esc.x * ancho * mix(1.0, afila, 0.5);
	h_i = esc.y * altura;
	vec2 uvn = vec2(UV.x * 3.0 + (semilla + sem_i) * 1.7, (1.0 - UV.y) * 1.5 + (TIME + fase_i) * velocidad * 0.5);
	float n = textureLod(ruido_v, uvn, 0.0).r;
	float sube = smoothstep(0.0, 0.8, UV.y);
	VERTEX.x *= mix(1.0, afila, UV.y);
	VERTEX.x += (n - 0.5) * 2.0 * amplitud_vert * ondulacion * sube / max(esc.x, 0.001);      // el balanceo de la lengua, en metros
	VERTEX.y *= altura;
	VERTEX.x *= ancho;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(der * esc.x, 0.0), vec4(0.0, esc.y, 0.0, 0.0), vec4(to * esc.z, 0.0), MODEL_MATRIX[3]);
}
