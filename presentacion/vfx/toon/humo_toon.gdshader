// HUMO TOON (1/11, prueba 2). Para GPUParticles3D con un QuadMesh: bola de DOS tonos grises cálidos con el tono claro como media luna arriba a la izquierda
// (sombreado falso), borde ligeramente irregular (el radio ondula con una semilla por bola) y billboard. Sin luz. El movimiento a saltos de 1/12 s viene de
// `fixed_fps` de las partículas; sin degradado de alfa: la bola nace, crece y desaparece de golpe cuando muere la partícula.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

uniform vec4 tono_cuerpo : source_color = vec4(0.53, 0.50, 0.48, 1.0);   // gris cálido medio
uniform vec4 tono_luz : source_color = vec4(0.74, 0.72, 0.69, 1.0);      // gris cálido claro
uniform vec2 sombra_desfase = vec2(0.3, -0.34);                           // hacia dónde se corre el círculo de sombra (abajo a la derecha)
uniform float sombra_radio : hint_range(0.5, 1.4) = 0.95;                 // radio del círculo de sombra respecto a la bola
uniform float redondez : hint_range(0.5, 1.0) = 0.9;                      // radio de la bola dentro del quad
uniform float irregular : hint_range(0.0, 0.2) = 0.07;                    // cuánto ondula el borde

varying float v_sem;

void vertex() {
	vec3 centro = MODEL_MATRIX[3].xyz;
	v_sem = fract(sin(dot(centro.xz + vec2(centro.y, 0.0), vec2(12.9898, 78.233))) * 43758.5453);
	float s = (length(MODEL_MATRIX[0].xyz) + length(MODEL_MATRIX[1].xyz)) * 0.5;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float ang = atan(p.y, p.x);
	float radio = redondez * (1.0 + irregular * sin(ang * 5.0 + v_sem * 30.0) + irregular * 0.6 * sin(ang * 9.0 + v_sem * 17.0));
	if (length(p) > radio) {
		discard;
	}
	vec3 col = tono_luz.rgb;
	if (length(p - sombra_desfase) < sombra_radio * radio) {
		col = tono_cuerpo.rgb;
	}
	ALBEDO = col;
}
