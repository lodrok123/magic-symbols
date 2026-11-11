class_name MaterialPersonaje3D
extends RefCounted
## Los dos pases extra que hacen que un personaje parezca «juguete» (V5 de docs/PLAN_EOW_VISUAL.md): el rim/fresnel de color y la silueta
## a través de lo que lo tapa. Los dos son ShaderMaterial en `next_pass` del material del modelo, NO sustituyen al StandardMaterial3D:
## así el tinte de `Combate3D` (quemado, congelado, golpe, que escribe `albedo_color` y la emisión) sigue funcionando sin enterarse.
##
## RIM. Aditivo y sin iluminar: suma `color * fresnel * intensidad` al píxel del borde. Se eligió esto en vez de `rim_enabled` del
## StandardMaterial3D porque ese rim toma el color de la LUZ (y se mezcla con el albedo), y aquí se quiere un color propio por rol
## (cálido la jugadora, el de su debilidad los enemigos). Con cámara ortogonal `VIEW` es constante, así que el brillo cae en las aristas
## que miran de lado: justo el contorno de plástico de Echoes of Wisdom.
##
## SILUETA. Un color plano semitransparente que se pinta SOLO donde el personaje está tapado. El truco: `depth_test_disabled` (se pinta encima
## de todo) y, en el fragmento, se lee la profundidad de la escena opaca (`hint_depth_texture`) y se descarta el píxel si lo que hay delante NO
## está claramente más cerca que el personaje. «Claramente» = `sesgo`: el propio personaje también está en esa textura, y un brazo detrás del
## torso quedaría «tapado» por el torso; el sesgo (una fracción de su altura) lo absorbe. Un árbol, un muro o un bloque suben mucho más que eso.
## POR QUÉ NO STENCIL: el «fallo de profundidad» del stencil también se activa con la autooclusión del propio modelo; habría el mismo problema
## y además solo existe desde 4.5 en Forward+/Mobile.

const CODIGO_RIM: String = """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform vec3 color : source_color = vec3(1.0, 0.75, 0.45);
uniform float potencia : hint_range(0.5, 8.0) = 2.2;
uniform float intensidad : hint_range(0.0, 3.0) = 0.7;
void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), potencia);
	ALBEDO = color * f * intensidad;
}
"""

## 4/11 (Pablo, tras el Bosque 02): «en vez de crear una transparencia haz un contorno para el personaje para que se pueda seguir viendo todo».
## El decorado ya no se agujerea (Ocluso3D.actualizar con radio 0); la jugadora se pinta en dos pases más, SOLO donde algo la tapa:
##   1. CONTORNO (prioridad 19): el mismo modelo inflado a lo largo de la normal (`grosor_px` píxeles de pantalla), solo las caras traseras (`cull_front`),
##      de un color plano claro. Asoma como un anillo alrededor de la silueta.
##   2. RELLENO (prioridad 20, el de siempre): la silueta de la jugadora en un color plano un poco apagado, con un leve claroscuro por la normal para que
##      se lean brazos y cabeza. Se pinta ENCIMA del contorno, así que del contorno solo queda el anillo.
## Los dos con `depth_test_disabled`, `depth_draw_never` y sin sombra, y los dos descartan el fragmento si la escena opaca no está claramente más cerca
## (misma prueba de profundidad por textura, ver el párrafo SILUETA de arriba). Godot 4.7 no trae `depth_test_inverted` (ver el informe del diario 351):
## el sesgo por textura es lo que permite distinguir «me tapa un árbol» de «mi brazo está detrás de mi torso».
## Los dos pases solo cuelgan de la JUGADORA (`Pj3D.set_rol_visual`): enemigos, NPC y VFX no los llevan.
##
## PLANTILLA (11/11, Pablo: «revisa la última prenda para ver por qué aparecen manchas violetas al hacer acciones»). Las manchas eran estos dos
## pases pintándose sobre la PROPIA jugadora: lavanda (relleno) con borde ciruela (contorno). El sesgo de arriba distingue «me tapa un árbol» de
## «mi brazo está detrás de mi torso» solo mientras ninguna parte del personaje tape a otra por más de 0,4 alturas, y el uniforme de Sumicio lo
## rompe: la punta caída de la capucha queda detrás de la capucha incluso en reposo, y agachada o rodando el cuerpo queda detrás de la capa.
## Medido con herramientas/medidas_manchas_color.gd: en reposo, 0 píxeles sin la capucha y 6000 con ella; rodando, el triple con el uniforme.
## Subir el sesgo lo taparía a costa de perder la silueta junto a muros cercanos. Lo correcto es no pintarla donde el personaje YA SE VE, y eso
## lo da el búfer de plantilla: el material de juguete escribe 1 en cada píxel donde se dibuja (o sea, donde supera la prueba de profundidad
## contra el decorado), y el relleno y el contorno solo pintan donde NO hay un 1. La prueba de profundidad con sesgo se queda: es la que evita
## que el anillo del contorno, que cae fuera de la figura, se pinte alrededor de la jugadora cuando nada la tapa.
## (El comentario de arriba descarta el stencil por la autooclusión: eso es el «fallo de profundidad». Escribir donde se ve y leer donde no
## es otra técnica y no lo sufre. Y el búfer existe desde Godot 4.5; el proyecto va en 4.7.)
const CODIGO_SILUETA: String = """
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
stencil_mode read, compare_not_equal, 1;    // nunca encima de donde el personaje ya se ve
uniform sampler2D profundidad : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.5, 0.42);
uniform float sesgo = 0.4;
uniform float claroscuro = 0.0;     // 0 = color plano; > 0 aclara lo que mira hacia arriba y oscurece lo que mira hacia abajo
void fragment() {
	float d = textureLod(profundidad, SCREEN_UV, 0.0).x;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float escena = -v.z / v.w;      // distancia (vista) a lo más cercano que hay en ese píxel
	float propio = -VERTEX.z;       // distancia (vista) de este fragmento del personaje
	if (escena > propio - sesgo) {
		discard;                    // nada lo tapa: no se ve silueta
	}
	ALBEDO = color.rgb * (1.0 + claroscuro * (normalize(NORMAL).y - 0.35));
	ALPHA = color.a;
}
"""

const CODIGO_CONTORNO: String = """
shader_type spatial;
render_mode skip_vertex_transform, unshaded, depth_test_disabled, depth_draw_never, cull_front, shadows_disabled, fog_disabled;
stencil_mode read, compare_not_equal, 1;    // nunca encima de donde el personaje ya se ve
uniform sampler2D profundidad : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 color : source_color = vec4(0.87, 0.71, 0.42, 1.0);
uniform float sesgo = 0.4;
uniform float grosor_px = 2.5;      // grosor del anillo en píxeles de pantalla (cámara ortogonal; con perspectiva, en metros)
void vertex() {
	vec3 p = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize((MODELVIEW_NORMAL_MATRIX * NORMAL));
	float m;
	if (PROJECTION_MATRIX[3][3] > 0.5) {
		m = grosor_px * (2.0 / PROJECTION_MATRIX[1][1]) / VIEWPORT_SIZE.y;      // cámara ortogonal: tamaño de la vista / alto de la ventana = metros por píxel
	} else {
		m = grosor_px * 0.01;
	}
	n.z = 0.0;                                                                 // se infla en el plano de la pantalla: no se acerca ni se aleja
	VERTEX = p + normalize(n + vec3(0.0001)) * m;
	NORMAL = n;
}
void fragment() {
	float d = textureLod(profundidad, SCREEN_UV, 0.0).x;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float escena = -v.z / v.w;
	float propio = -VERTEX.z;
	if (escena > propio - sesgo) {
		discard;
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
"""

## ---- V5 punto 5 «personaje de juguete» (Echoes of Wisdom): material casi plano con rampa suave y MATCAP, en vez de PBR ----
## El ShaderMaterial `juguete()` SUSTITUYE al StandardMaterial3D en las superficies opacas del modelo (las de alfa —pelo, hojas— se quedan con su
## StandardMaterial3D y su recorte). El StandardMaterial3D duplicado sigue existiendo como «material de control»: Combate3D le escribe el tinte
## (albedo_color, emisión) y `Pj3D.sincronizar_juguete()` lo copia cada fotograma a los uniforms de este shader. Así Combate3D no se toca.
##  - Color: textura del modelo × `albedo_color` (el tinte), sin normal map ni especular PBR (un normal map de Meshy ensucia el aspecto plano).
##  - Luz (función light()): half-lambert con rampa de 3 tonos suaves (smoothstep) × sombras del sol (ATTENUATION); la parte en sombra NO es negra:
##    recibe `amb_sombra_pers` (global de Ambiente3D; frío/cálido según la zona) × `piso_sombra`.
##  - MATCAP: textura de esfera PROCEDURAL (`textura_matcap()`, un lóbulo suave arriba-izquierda; ver su comentario) indexada por la normal en espacio de
##    vista. Se suma como emisión proporcional al color (no lava el color) con `matcap_intensidad`: el brillo ancho de plástico de juguete.
##  - `plano` = 1 (modo_luz 0 del laboratorio): sin luz, sin matcap, color puro (equivale al UNSHADED de antes).
const CODIGO_JUGUETE: String = """
shader_type spatial;
render_mode cull_back, specular_disabled, diffuse_lambert;
stencil_mode write, compare_always, 1;      // marca los píxeles donde el personaje SE VE: ver PLANTILLA más arriba
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool tiene_tex = true;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec4 emision : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emision_energia = 0.0;
uniform sampler2D matcap : filter_linear, repeat_disable;
uniform float matcap_intensidad : hint_range(0.0, 1.5) = 0.35;
global uniform vec4 amb_sombra_pers;   // lo que llega a la sombra del personaje (rgb) y contraste (a): Ambiente3D
uniform float piso_sombra : hint_range(0.0, 1.0) = 0.3;
uniform float brillo_luz : hint_range(0.3, 1.5) = 0.85;
uniform float plano = 0.0;
void fragment() {
	vec4 t = tiene_tex ? texture(albedo_tex, UV) : vec4(1.0);
	vec3 col = t.rgb * albedo_color.rgb;
	vec2 mc = NORMAL.xy * vec2(0.5, -0.5) + 0.5;
	float hl = texture(matcap, mc).r;
	vec3 brillo = mix(col, vec3(1.0), 0.35) * hl * matcap_intensidad * (1.0 - plano);
	ALBEDO = col * (1.0 - plano);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = col * plano + brillo + emision.rgb * emision_energia;
}
void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float tono = 0.5 * smoothstep(0.15, 0.40, w) + 0.5 * smoothstep(0.55, 0.80, w);
	float lit = tono * ATTENUATION;
	vec3 pasos = mix(amb_sombra_pers.rgb * piso_sombra, vec3(brillo_luz), lit);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * pasos * (1.0 - plano);
}
"""

## Cuánto brilla el matcap, el suelo de la sombra tintada y la compensación de brillo de la rampa (más generosa que Lambert).
const MATCAP_INTENSIDAD: float = 0.35
const PISO_SOMBRA: float = 0.3
const BRILLO_LUZ: float = 0.85
const MATCAP_TAMANO: int = 64
static var _matcap: ImageTexture = null


## MATCAP procedural: 64×64 gris. Valor = lóbulo suave de una esfera iluminada desde arriba a la izquierda y algo hacia la cámara
## (coseno elevado a 10); fuera del disco, 0. Es una textura de «cuánto brilla la esfera según hacia dónde mira la normal», no un color.
static func textura_matcap() -> ImageTexture:
	if _matcap != null:
		return _matcap
	var img := Image.create(MATCAP_TAMANO, MATCAP_TAMANO, false, Image.FORMAT_RGB8)
	var l: Vector3 = Vector3(-0.45, 0.55, 0.7).normalized()
	for y in range(MATCAP_TAMANO):
		for x in range(MATCAP_TAMANO):
			var p := Vector2((x + 0.5) / MATCAP_TAMANO * 2.0 - 1.0, 1.0 - (y + 0.5) / MATCAP_TAMANO * 2.0)
			var r2: float = p.length_squared()
			var v: float = 0.0
			if r2 < 1.0:
				var n := Vector3(p.x, p.y, sqrt(1.0 - r2))
				v = pow(maxf(n.dot(l), 0.0), 10.0)
			img.set_pixel(x, y, Color(v, v, v))
	_matcap = ImageTexture.create_from_image(img)
	return _matcap


## El material de juguete para una superficie opaca. `base` es el StandardMaterial3D duplicado del modelo (de él salen la textura y el color de partida).
static func juguete(base: StandardMaterial3D) -> ShaderMaterial:
	Ambiente3D.preparar_global()   # antes de compilar: el shader declara amb_sombra_pers
	var sh := Shader.new()
	sh.code = CODIGO_JUGUETE.replace("cull_back", "cull_disabled") if base.cull_mode == BaseMaterial3D.CULL_DISABLED else CODIGO_JUGUETE   # la elfa viene a doble cara
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tiene_tex", base.albedo_texture != null)
	if base.albedo_texture != null:
		m.set_shader_parameter("albedo_tex", base.albedo_texture)
	m.set_shader_parameter("matcap", textura_matcap())
	m.set_shader_parameter("matcap_intensidad", MATCAP_INTENSIDAD)
	m.set_shader_parameter("piso_sombra", PISO_SOMBRA)
	m.set_shader_parameter("brillo_luz", BRILLO_LUZ)
	copiar_estado(base, m)
	return m


## Copia el estado que Combate3D escribe en el material de control (tinte, emisión, luz plana) al shader.
static func copiar_estado(base: StandardMaterial3D, m: ShaderMaterial) -> void:
	m.set_shader_parameter("albedo_color", base.albedo_color)
	m.set_shader_parameter("emision", base.emission)
	m.set_shader_parameter("emision_energia", base.emission_energy_multiplier if base.emission_enabled else 0.0)
	m.set_shader_parameter("plano", 1.0 if base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED else 0.0)


## Hace que un StandardMaterial3D marque la plantilla igual que el material de juguete (ver PLANTILLA). Para lo que el personaje lleva y NO pasa
## por `juguete()`: el pelo y demás superficies con alfa, y las piezas de equipo (el grimorio en la cadera). Sin esto la silueta del cuerpo se
## pintaba encima del libro.
static func marcar_plantilla(m: BaseMaterial3D) -> void:
	m.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	m.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	m.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	m.stencil_reference = 1


## Prioridad de dibujo de la silueta: por encima de las transparencias normales (agua, humo, hierba) para que no la tape un velo.
const PRIORIDAD_SILUETA: int = 20


static func rim(color: Color, potencia: float, intensidad: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = CODIGO_RIM
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("color", Vector3(color.r, color.g, color.b))
	m.set_shader_parameter("potencia", potencia)
	m.set_shader_parameter("intensidad", intensidad)
	return m


const PRIORIDAD_CONTORNO: int = 19

static func contorno(color: Color, sesgo: float, grosor_px: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = CODIGO_CONTORNO
	var m := ShaderMaterial.new()
	m.shader = sh
	m.render_priority = PRIORIDAD_CONTORNO
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("sesgo", sesgo)
	m.set_shader_parameter("grosor_px", grosor_px)
	return m


static func silueta(color: Color, sesgo: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = CODIGO_SILUETA
	var m := ShaderMaterial.new()
	m.shader = sh
	m.render_priority = PRIORIDAD_SILUETA
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("sesgo", sesgo)
	return m
