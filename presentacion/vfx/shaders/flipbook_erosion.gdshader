// FLIPBOOK CON EROSIÓN (1/11, comparativa de VFX §1.2). Para billboards de GPUParticles3D con un QuadMesh.
// Lee un atlas de N×M fotogramas (el que espera `particles_anim`), le resta un ruido con un umbral que crece con la vida de la
// partícula (la llama «se come» por los bordes al morir) y colorea la intensidad con una rampa. Mezcla aditiva o normal según `aditivo`
// (se consigue con alfa premultiplicado: con alfa 0 la mezcla premultiplicada ES la suma). Se funde contra la geometría (`suavizado`).
// Lo que lee de la partícula: INSTANCE_CUSTOM.x giro, .y vida (0→1), .z fotograma (anim_offset / anim_speed del ParticleProcessMaterial), COLOR la rampa del material.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform int columnas = 8;
uniform int filas = 8;
uniform sampler2D ruido : hint_default_white, filter_linear, repeat_enable;
uniform float ruido_escala = 2.5;
uniform float ruido_velocidad = 0.35;
uniform float ruido_peso : hint_range(0.0, 1.0) = 0.75;     // cuánto manda el ruido en el borde (0 = solo el atlas)
uniform sampler2D rampa : source_color, filter_linear, repeat_disable;
uniform float erosion_min : hint_range(0.0, 1.0) = 0.05;   // umbral al nacer
uniform float erosion_max : hint_range(0.0, 1.0) = 0.95;   // umbral al morir
uniform float suavidad : hint_range(0.001, 0.5) = 0.22;    // anchura del borde
uniform float brillo : hint_range(0.0, 8.0) = 1.1;
uniform float color_por_alfa : hint_range(0.0, 1.0) = 0.7;  // de dónde sale el color: 0 = del brillo del atlas, 1 = de su densidad (alfa): denso = centro claro, fino = borde oscuro
uniform float aditivo : hint_range(0.0, 1.0) = 1.0;        // 1 = suma de luz, 0 = mezcla normal (humo)
uniform float suavizado = 0.6;                              // m hasta la geometría en los que la partícula se desvanece
uniform sampler2D textura_profundidad : hint_depth_texture, filter_nearest;

varying float vida;
varying float fotograma;

void vertex() {
	vida = INSTANCE_CUSTOM.y;
	fotograma = INSTANCE_CUSTOM.z;
	float a = INSTANCE_CUSTOM.x;
	mat4 giro = mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	mat4 mundo = mat4(normalize(INV_VIEW_MATRIX[0]) * length(MODEL_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]) * length(MODEL_MATRIX[1]),
		normalize(INV_VIEW_MATRIX[2]) * length(MODEL_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * mundo * giro;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	int total = columnas * filas;
	int f = int(floor(fotograma * float(total))) % total;
	vec2 celda = vec2(1.0 / float(columnas), 1.0 / float(filas));
	vec2 uv = UV * celda + vec2(float(f % columnas), float(f / columnas)) * celda;
	vec4 t = texture(atlas, uv);
	float intensidad = mix(max(t.r, max(t.g, t.b)), t.a, color_por_alfa);
	float n = texture(ruido, UV * ruido_escala + vec2(0.0, -TIME * ruido_velocidad)).r;
	float ero = mix(erosion_min, erosion_max, clamp(vida, 0.0, 1.0));
	float valor = t.a * mix(1.0, n, ruido_peso);
	float a = smoothstep(ero, ero + suavidad, valor) * COLOR.a;
	// fundido contra la geometría (partículas suaves)
	float z_fondo = texture(textura_profundidad, SCREEN_UV).r;
	vec4 p = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z_fondo, 1.0);
	float dist = (p.z / p.w) - VERTEX.z;   // VERTEX está en espacio de vista (z negativa hacia delante)
	a *= clamp(abs(dist) / max(suavizado, 0.001), 0.0, 1.0);
	vec3 col = texture(rampa, vec2(clamp(intensidad * (1.0 - vida * 0.5), 0.0, 1.0), 0.5)).rgb * COLOR.rgb * brillo;
	ALBEDO = col * a;
	ALPHA = a * (1.0 - aditivo);
}
