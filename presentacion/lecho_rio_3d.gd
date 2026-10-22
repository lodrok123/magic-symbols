extends RefCounted
class_name LechoRio3D
## LECHO REAL BAJO EL AGUA FILTRO (Pipeline, 22/10; referencia: un río de Echoes of Wisdom). Con `agua_filtro` el agua es un filtro turquesa casi transparente (AguaRender3D),
## así que lo que hay debajo se VE: aquí está ese fondo.
##   · MATERIAL del bloque del lecho (`crear_material`): textura de cantos rodados en coordenadas de mundo (baja de contraste) + CÁUSTICAS como luz suave y aditiva que se mueve
##     sobre el fondo (bordes blandos; más fuertes con poco fondo, nada donde no hay agua). Textura: `RUTA_TEXTURA` (la de Meshy, cuando Pablo la traiga) o, si no existe,
##     una procedural de cantos (Voronoi redondeado, colores de Paleta3D piedra/tierra).
##   · GUIJARROS del MultiMesh más pequeños y desaturados (constantes `GUIJARRO_*`); los pone la maqueta (`_construir_lecho_rio`).
##   · ADORNOS opcionales (algas, rocas de río): ids y rutas preparados para lo que pida Pablo a Meshy; si no hay modelos, no se pone nada.

## Textura de lecho de cantos de Meshy (sin ella, se usa la procedural). Mosaico: se repite cada `TAM_TEXTURA_U` u.
const RUTA_TEXTURA: String = "res://arte/suelo_meshy/lecho_rio.png"
const TAM_TEXTURA_U: float = 4.6            ## de la procedural
## De la textura de Meshy (512 px, un canto grande ocupa ~130 px): 2,0 u por mosaico = canto grande de ~0,5 u.
const TAM_TEXTURA_ARCHIVO_U: float = 2.0
## Textura procedural: lado en píxeles, cantos por lado del mosaico, cuánto contraste conserva (0 = todo al tono medio, 1 = sin tocar) y radio de redondeo (en celdas).
const PROC_PX: int = 160
const PROC_CELDAS: int = 7
const PROC_CONTRASTE: float = 0.55
const PROC_REDONDEO: float = 0.22
## Contraste que conserva la textura del lecho (1 = tal cual, 0 = color medio): se ve a través del agua y no debe competir con lo que pisa la chibi.
const LECHO_CONTRASTE: float = 0.6
## Cáusticas: fuerza de la luz (aditiva), escala de la red (u), velocidad y color. Con poco fondo (< CAUS_PROF_POCA) valen CAUS_POCA veces más.
const CAUS_FUERZA: float = 0.22
const CAUS_ESCALA: float = 1.25
const CAUS_VEL: float = 0.07
const CAUS_COLOR: Color = Color(0.70, 0.96, 1.0)
const CAUS_PROF_POCA: float = 0.25
const CAUS_POCA: float = 2.2
## Guijarros del lecho con el filtro: más pequeños, algo menos y desaturados hacia gris (1 = como antes / color de siempre).
const GUIJARRO_ESCALA: float = 0.7
const GUIJARRO_DENSIDAD: float = 0.6
const GUIJARRO_COLOR_PROPIO: float = 0.45       ## 1 = el color de la paleta; 0 = gris del mismo brillo
const GUIJARRO_BRILLO: float = 1.0

## --- Assets que pedirá Pablo a Meshy (ids). Se cargan de CARPETAS si existen; si no, no se esparce nada. ---
const IDS_ALGAS: Array = ["alga_0", "alga_1", "alga_2", "alga_3"]
const IDS_ROCAS: Array = ["roca_rio_0", "roca_rio_1", "roca_rio_2"]
const CARPETAS_ASSETS: Array = ["res://arte/meshy/piezas/", "res://arte/suelo_meshy/"]
## Alto objetivo de cada alga (u; las cuatro piezas no son igual de altas: la 2 es una mata baja y ancha) y diámetro de una roca de río (u): el modelo se escala a esto sea cual sea
## su tamaño de exportación. ALGA_ALTO es el de una pieza que no esté en la tabla y el máximo absoluto.
const ALGA_ALTO: float = 0.75
const ALGA_ALTOS: Dictionary = {"alga_0": 0.5, "alga_1": 0.75, "alga_2": 0.45, "alga_3": 0.75}
const ROCA_DIAM: float = 0.8
## Variación de tamaño por pieza (factor sobre el objetivo): algas 0,85–1,0 (nunca más altas que la tabla); rocas 0,75–1,25 (0,6–1,0 u de ancho).
const ALGA_ESCALA_MIN: float = 0.85
const ALGA_ESCALA_MAX: float = 1.0
const ROCA_ESCALA_MIN: float = 0.75
const ROCA_ESCALA_MAX: float = 1.25
## Margen bajo la superficie (u): ningún adorno pasa de (profundidad del agua − margen) de alto; si no cabe, se escala hacia abajo. Las olas suben hasta ~0,1 u.
const ADORNOS_MARGEN_SUPERFICIE: float = 0.15
## Cuánto se entierra la base en el lecho (u) para que no se vea un hueco: algas / rocas.
const ALGA_ENTIERRO: float = 0.01
const ROCA_ENTIERRO: float = 0.03
## Probabilidad por casilla de agua profunda de llevar una mata de algas / una roca, y cuántas piezas por casilla como mucho. Semilla por casilla (reproducible).
const ADORNOS_DENSIDAD_ALGAS: float = 0.55      ## (0,30 antes: con la cámara del juego casi no se veían)
const ADORNOS_DENSIDAD_ROCAS: float = 0.22      ## (0,14 antes)
const ADORNOS_ALGAS_POR_CASILLA: int = 4
## Balanceo de las algas (vertex shader; más arriba, más: crece con el cuadrado de la altura relativa del vértice). Todo en u de mundo en la punta.
const ALGA_BALANCEO: float = 0.045        ## vaivén propio (también con el agua quieta)
const ALGA_INCLINA: float = 0.10          ## cuánto se inclina la punta hacia donde corre el agua (por la fuerza del flow map, 0–1)
const ALGA_VEL: float = 1.3               ## rad/s del vaivén
const ALGA_FLUJO_MIN: float = 0.02        ## por debajo de esta fuerza de corriente se considera agua quieta (dirección al azar por mata)

const CODIGO: String = """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D t_lecho : source_color, repeat_enable, filter_linear_mipmap;
uniform float tam_tex = 4.6;
uniform float brillo = 0.78;
uniform float contraste = 1.2;
uniform float contraste_lecho = 0.6;           // 1 = la textura tal cual; 0 = todo al color medio (el fondo se ve con poco contraste bajo el agua)
uniform vec3 sombra_tinte : source_color = vec3(0.34, 0.36, 0.46);
// Cáusticas (luz aditiva y suave sobre el fondo).
uniform float causticas = 0.22;
uniform float caus_escala = 1.25;
uniform float caus_vel = 0.07;
uniform vec3 caus_color : source_color = vec3(0.70, 0.96, 1.0);
uniform float caus_prof_poca = 0.25;
uniform float caus_poca = 2.2;
// Profundidad del agua por trocito (la textura de datos de AguaSim3D: G); sin ella, caudal medio.
uniform sampler2D datos : filter_nearest, hint_default_black, repeat_disable;
uniform float lado_trocito = 0.7667;
uniform float usa_datos = 0.0;

varying vec3 v_pos;

void vertex() {
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Distancia a la arista de Voronoi (F2 - F1) con centros que se mueven despacio: bordes blandos, red de luz.
float arista(vec2 p, float t) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 9.0;
	float d2 = 9.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 17.3));
			o = 0.5 + 0.38 * sin(t * (0.6 + o) + 6.2831 * o);
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return d2 - d1;
}

void fragment() {
	vec2 xz = v_pos.xz;
	vec3 col = texture(t_lecho, xz / tam_tex).rgb;
	vec3 medio = textureLod(t_lecho, xz / tam_tex, 9.0).rgb;
	col = mix(medio, col, contraste_lecho);
	ALBEDO = col * brillo;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
	// Cáusticas: dos redes que se cruzan y se mueven en sentidos distintos; suma suave (no líneas duras), más fuertes donde hay poco agua.
	float prof = 0.9;
	if (usa_datos > 0.5) {
		ivec2 s = textureSize(datos, 0);
		prof = texelFetch(datos, clamp(ivec2(floor(xz / lado_trocito)), ivec2(0), s - 1), 0).g;
	}
	float hay = smoothstep(0.03, 0.14, prof);
	float t = TIME * caus_vel * 6.0;
	float a1 = 1.0 - smoothstep(0.0, 0.32, arista(xz / caus_escala + vec2(t * 0.15, -t * 0.1), t));
	float a2 = 1.0 - smoothstep(0.0, 0.32, arista(xz / (caus_escala * 0.73) + vec2(-t * 0.12, t * 0.17) + 3.7, t * 1.3 + 1.7));
	float c = smoothstep(0.2, 1.3, a1 + a2 * 0.85);
	float fuerte = mix(caus_poca, 1.0, smoothstep(caus_prof_poca, 0.9, prof));
	EMISSION = caus_color * c * causticas * fuerte * hay;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float luz = smoothstep(0.0, 1.0, clamp(dot(NORMAL, LIGHT) * contraste, 0.0, 1.0)) * ATTENUATION;
		DIFFUSE_LIGHT += mix(sombra_tinte, vec3(1.0), luz) * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / PI;
	}
}
"""

## Adornos (algas y rocas): albedo del .glb con la misma luz que el lecho (opacos: se dibujan antes que el agua, así que el filtro turquesa los tiñe y la refracción los ve).
## Algas: el vértice se desplaza en horizontal en proporción al cuadrado de su altura relativa en la malla (la base no se mueve), hacia donde corre el agua (flow map del agua:
## `flujo`, RG = dirección × fuerza) más un vaivén propio con fase por mata; con agua quieta la dirección es al azar por mata.
const CODIGO_ADORNO: String = """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D t_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tinte = vec3(1.0);
uniform float brillo = 0.78;
uniform float contraste = 1.2;
uniform vec3 sombra_tinte : source_color = vec3(0.34, 0.36, 0.46);
uniform float mece = 0.0;
uniform float base_malla = 0.0;
uniform float altura_malla = 0.4;
uniform float balanceo = 0.045;
uniform float inclina = 0.10;
uniform float vel = 1.3;
uniform float flujo_min = 0.02;
uniform sampler2D flujo : filter_nearest, hint_default_black, repeat_disable;
uniform float lado_trocito = 0.7667;
uniform float usa_flujo = 0.0;

void vertex() {
	if (mece > 0.5) {
		float h = clamp((VERTEX.y - base_malla) / max(altura_malla, 0.001), 0.0, 1.0);
		vec3 o = MODEL_MATRIX[3].xyz;
		float fase = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831;
		vec2 dir = vec2(cos(fase), sin(fase));
		float fuerza = 0.0;
		if (usa_flujo > 0.5) {
			ivec2 s = textureSize(flujo, 0);
			vec2 f = texelFetch(flujo, clamp(ivec2(floor(o.xz / lado_trocito)), ivec2(0), s - 1), 0).rg;
			float l = length(f);
			if (l > flujo_min) {
				dir = f / l;
				fuerza = min(l, 1.0);
			}
		}
		float t = TIME * vel + fase;
		vec2 d = dir * (inclina * fuerza + balanceo * sin(t)) + vec2(-dir.y, dir.x) * balanceo * 0.5 * sin(t * 0.73 + 1.7);
		vec3 dw = vec3(d.x, 0.0, d.y) * h * h;
		VERTEX += inverse(mat3(MODEL_MATRIX)) * dw;
	}
}

void fragment() {
	ALBEDO = texture(t_albedo, UV).rgb * tinte * brillo;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float luz = smoothstep(0.0, 1.0, clamp(dot(NORMAL, LIGHT) * contraste, 0.0, 1.0)) * ATTENUATION;
		DIFFUSE_LIGHT += mix(sombra_tinte, vec3(1.0), luz) * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / PI;
	}
}
"""

static var _tex_procedural: ImageTexture = null
static var _shader: Shader = null
static var _shader_adorno: Shader = null


## ¿Existe la textura de lecho de Meshy? (si no, se usa la procedural)
static func hay_textura_archivo() -> bool:
	return ResourceLoader.exists(RUTA_TEXTURA)


## La textura que se usa: la de Meshy si existe, si no la procedural (se genera una vez por proceso).
static func textura() -> Texture2D:
	if hay_textura_archivo():
		var t: Texture2D = load(RUTA_TEXTURA) as Texture2D
		if t != null:
			return t
	return textura_procedural()


## Mosaico de cantos rodados: Voronoi (con envoltura, repite sin costuras) con relleno redondeado (más claro en el centro del canto, más oscuro hacia las juntas), tono por canto
## entre piedra oscura y piedra (con un toque de tierra mojada) y juntas de tierra oscura. Baja de contraste hacia el tono medio (PROC_CONTRASTE).
static func textura_procedural() -> ImageTexture:
	if _tex_procedural != null:
		return _tex_procedural
	var n: int = PROC_CELDAS
	var centros: Array[Vector2] = []
	var tonos: Array[float] = []
	var tierras: Array[float] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for j in range(n):
		for i in range(n):
			centros.append(Vector2(float(i) + 0.18 + 0.64 * rng.randf(), float(j) + 0.18 + 0.64 * rng.randf()))
			tonos.append(rng.randf())
			tierras.append(0.3 if rng.randf() < 0.4 else 0.1)
	var junta: Color = Paleta3D.TIERRA * 0.6
	var medio: Color = Paleta3D.PIEDRA_OSCURA.lerp(Paleta3D.TIERRA, 0.5)
	var img := Image.create(PROC_PX, PROC_PX, true, Image.FORMAT_RGB8)
	for py in range(PROC_PX):
		for px in range(PROC_PX):
			var p := Vector2((float(px) + 0.5) / float(PROC_PX) * float(n), (float(py) + 0.5) / float(PROC_PX) * float(n))
			var ci: int = int(floorf(p.x))
			var cj: int = int(floorf(p.y))
			var d1: float = 9.0
			var d2: float = 9.0
			var mejor: int = 0
			for oj in range(-1, 2):
				for oi in range(-1, 2):
					var ii: int = posmod(ci + oi, n)
					var jj: int = posmod(cj + oj, n)
					var c: Vector2 = centros[jj * n + ii] + Vector2(float(ci + oi - ii), float(cj + oj - jj))
					var d: float = p.distance_to(c)
					if d < d1:
						d2 = d1
						d1 = d
						mejor = jj * n + ii
					elif d < d2:
						d2 = d
			var borde: float = d2 - d1
			var r: float = clampf(borde / PROC_REDONDEO, 0.0, 1.0)
			var altura: float = sqrt(maxf(1.0 - (1.0 - r) * (1.0 - r), 0.0))      # perfil redondo: plano arriba, cae hacia la junta
			var piedra: Color = Paleta3D.PIEDRA_OSCURA.lerp(Paleta3D.PIEDRA, tonos[mejor]).lerp(Paleta3D.TIERRA, tierras[mejor])
			var cuerpo: Color = piedra * (0.62 + 0.38 * altura)
			var col: Color = junta.lerp(cuerpo, smoothf(0.0, 0.07, borde))
			col = medio.lerp(col, PROC_CONTRASTE)
			img.set_pixel(px, py, Color(col.r, col.g, col.b, 1.0))
	img.generate_mipmaps()
	_tex_procedural = ImageTexture.create_from_image(img)
	return _tex_procedural


static func smoothf(a: float, b: float, x: float) -> float:
	var t: float = clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Material del bloque del lecho (sustituye al del suelo bajo el agua con el filtro). `brillo` = el del suelo (OSCURECER_SUELO).
static func crear_material(brillo: float = 0.78) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODIGO
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("t_lecho", textura())
	m.set_shader_parameter("tam_tex", TAM_TEXTURA_ARCHIVO_U if hay_textura_archivo() else TAM_TEXTURA_U)
	m.set_shader_parameter("brillo", brillo)
	m.set_shader_parameter("contraste_lecho", LECHO_CONTRASTE)
	m.set_shader_parameter("causticas", CAUS_FUERZA)
	m.set_shader_parameter("caus_escala", CAUS_ESCALA)
	m.set_shader_parameter("caus_vel", CAUS_VEL)
	m.set_shader_parameter("caus_color", CAUS_COLOR)
	m.set_shader_parameter("caus_prof_poca", CAUS_PROF_POCA)
	m.set_shader_parameter("caus_poca", CAUS_POCA)
	return m


## Color de un guijarro con el filtro: la paleta desaturada hacia su gris y un poco más oscuro.
static func color_guijarro(col: Color) -> Color:
	var g: float = col.get_luminance()
	var c: Color = Color(g, g, g).lerp(col, GUIJARRO_COLOR_PROPIO)
	return Color(c.r * GUIJARRO_BRILLO, c.g * GUIJARRO_BRILLO, c.b * GUIJARRO_BRILLO, 1.0)


# ---------------------------------------------------------------------------------------------------------------------
#  ADORNOS: algas y rocas de río (solo si hay modelos)
# ---------------------------------------------------------------------------------------------------------------------

## Ruta del modelo `id` (alga_0, roca_rio_1…) en las carpetas de assets, o "" si no existe.
static func ruta_modelo(id: String) -> String:
	for carpeta in CARPETAS_ASSETS:
		var r: String = String(carpeta) + id + ".glb"
		if ResourceLoader.exists(r):
			return r
	return ""


## Ids (de las dos listas) que tienen modelo.
static func modelos_disponibles() -> Array[String]:
	var res: Array[String] = []
	for id in IDS_ALGAS + IDS_ROCAS:
		if ruta_modelo(String(id)) != "":
			res.append(String(id))
	return res


## Esparce algas y rocas por las casillas de agua PROFUNDA. `casillas`: [{c: Vector2i, centro: Vector3 (en el centro de la casilla, a la Y del lecho), profunda: bool}].
## `hash_fn(x, y, sal) -> int` da la semilla por casilla. `prof_agua` = profundidad del agua sobre el lecho (u): ninguna pieza pasa de `prof_agua − ADORNOS_MARGEN_SUPERFICIE` de alto.
## `brillo` = el del suelo (OSCURECER_SUELO). Devuelve el nodo con los MultiMesh (null si no hay modelos o no tocó ninguna casilla) para que el llamador lo cuelgue; sin colisión ni
## nada que toque Terreno3D/Caminos3D. Metas del nodo: `instancias`, `triangulos` (añadidos a la escena), `materiales` (los ShaderMaterial, para enlazar la corriente).
static func construir_adornos(casillas: Array, lado_casilla: float, hash_fn: Callable, prof_agua: float = 0.9, brillo: float = 0.78) -> Node3D:
	var tope: float = maxf(prof_agua - ADORNOS_MARGEN_SUPERFICIE, 0.05)
	var algas: Array = []
	var rocas: Array = []
	for id in IDS_ALGAS:
		var m: Dictionary = _modelo(String(id), float(ALGA_ALTOS.get(id, ALGA_ALTO)), true, true, brillo)
		if not m.is_empty():
			algas.append(m)
	for id in IDS_ROCAS:
		var m: Dictionary = _modelo(String(id), ROCA_DIAM, false, false, brillo)
		if not m.is_empty():
			rocas.append(m)
	if algas.is_empty() and rocas.is_empty():
		return null
	var por_malla: Dictionary = {}       # (modelo, índice de malla) -> {m, i, tfs}
	var piezas: Array = []               # una por adorno (para medir: id, base, alto y ancho finales)
	var total: int = 0
	for cs in casillas:
		var d: Dictionary = cs
		if not bool(d["profunda"]):
			continue
		var c: Vector2i = d["c"]
		var centro: Vector3 = d["centro"]
		var h0: int = absi(int(hash_fn.call(c.x, c.y, 301)))
		if not algas.is_empty() and float(h0 % 1000) / 999.0 < ADORNOS_DENSIDAD_ALGAS:
			var n: int = 1 + (h0 >> 10) % ADORNOS_ALGAS_POR_CASILLA
			for k in range(n):
				var h: int = absi(int(hash_fn.call(c.x, c.y, 310 + k)))
				var m: Dictionary = algas[h % algas.size()]
				_poner(por_malla, m, centro, lado_casilla, h, lerpf(ALGA_ESCALA_MIN, ALGA_ESCALA_MAX, float((h >> 12) % 100) / 99.0), tope, ALGA_ENTIERRO, piezas)
				total += 1
		var h1: int = absi(int(hash_fn.call(c.x, c.y, 330)))
		if not rocas.is_empty() and float(h1 % 1000) / 999.0 < ADORNOS_DENSIDAD_ROCAS:
			var m2: Dictionary = rocas[h1 % rocas.size()]
			_poner(por_malla, m2, centro, lado_casilla, h1, lerpf(ROCA_ESCALA_MIN, ROCA_ESCALA_MAX, float((h1 >> 12) % 100) / 99.0), tope, ROCA_ENTIERRO, piezas)
			total += 1
	if total == 0:
		return null
	var raiz := Node3D.new()
	raiz.name = "adornos_lecho_rio"
	var tris: int = 0
	var mats: Array = []
	for clave in por_malla.keys():
		var e: Dictionary = por_malla[clave]
		var parte: Dictionary = ((e["m"] as Dictionary)["partes"] as Array)[int(e["i"])]
		var tfs: Array = e["tfs"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = parte["malla"]
		mm.instance_count = tfs.size()
		for k in range(tfs.size()):
			mm.set_instance_transform(k, (tfs[k] as Transform3D) * (parte["tf"] as Transform3D))
		var mi := MultiMeshInstance3D.new()
		mi.name = String(clave).replace("#", "_")
		mi.multimesh = mm
		mi.material_override = parte["mat"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mi)
		mats.append(parte["mat"])
		tris += int(parte["tris"]) * tfs.size()
	raiz.set_meta("instancias", total)
	raiz.set_meta("triangulos", tris)
	raiz.set_meta("materiales", mats)
	raiz.set_meta("piezas", piezas)
	return raiz


## Da a las algas la corriente del agua: `flujo` = la textura del flow map del agua (RG = dirección × fuerza por trocito) y `lado_trocito` su tamaño. Sin ella se balancean sin rumbo.
static func enlazar_flujo(raiz: Node3D, flujo: Texture2D, lado_trocito: float) -> void:
	if raiz == null or flujo == null or not raiz.has_meta("materiales"):
		return
	for m in raiz.get_meta("materiales"):
		var sm: ShaderMaterial = m as ShaderMaterial
		if sm != null:
			sm.set_shader_parameter("flujo", flujo)
			sm.set_shader_parameter("lado_trocito", lado_trocito)
			sm.set_shader_parameter("usa_flujo", 1.0)


## La pieza se apoya en el lecho (base en `centro.y`, enterrada `entierro`),
## con giro al azar y la escala dada, reducida si su alto pasa de `tope`.
static func _poner(por_malla: Dictionary, m: Dictionary, centro: Vector3, lado: float, h: int, escala: float, tope: float, entierro: float, piezas: Array) -> void:
	var f2: float = float((h >> 3) % 1000) / 999.0
	var f3: float = float((h >> 16) % 1000) / 999.0
	var pos := Vector3(centro.x + (f2 - 0.5) * lado * 0.7, centro.y - entierro, centro.z + (f3 - 0.5) * lado * 0.7)
	var esc: float = float(m["escala"]) * escala
	var alto: float = float(m["alto"]) * escala              # alto (u) de esta pieza una vez escalada
	var ancho: float = float(m["ancho"]) * escala
	if alto > tope:
		esc *= tope / alto
		ancho *= tope / alto
		alto = tope
	piezas.append({"id": m["id"], "base": pos, "alto": alto, "ancho": ancho, "escala": esc})
	var tf := Transform3D(Basis(Vector3.UP, float(h % 628) / 100.0).scaled(Vector3(esc, esc, esc)), pos)
	for i in range((m["partes"] as Array).size()):
		var clave: String = "%s#%d" % [m["id"], i]
		if not por_malla.has(clave):
			por_malla[clave] = {"m": m, "i": i, "tfs": []}
		((por_malla[clave] as Dictionary)["tfs"] as Array).append(tf)


## Carga un modelo y lo normaliza: partes [{malla, tf, mat, tris}], escala para que su alto (por_alto) o su mayor lado en planta valga `objetivo`, y su base apoyada en y=0.
## `mece`: las algas llevan el balanceo en el vertex shader (el cálculo usa la altura del vértice en la malla: `base_malla`, `altura_malla`).
static func _modelo(id: String, objetivo: float, por_alto: bool, mece: bool, brillo: float) -> Dictionary:
	var ruta: String = ruta_modelo(id)
	if ruta == "":
		return {}
	var ps: PackedScene = load(ruta) as PackedScene
	if ps == null:
		return {}
	var raiz: Node = ps.instantiate()
	var partes: Array = []
	var caja := AABB()
	var primero: bool = true
	var pila: Array = [[raiz, Transform3D.IDENTITY]]
	while not pila.is_empty():
		var e: Array = pila.pop_back()
		var n: Node = e[0]
		var tf: Transform3D = e[1]
		if n is Node3D and n != raiz:
			tf = tf * (n as Node3D).transform
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi: MeshInstance3D = n
			partes.append({"malla": mi.mesh, "tf": tf, "mat": _material_adorno(mi.mesh, mece, brillo), "tris": floori(mi.mesh.get_faces().size() / 3.0)})
			var a: AABB = tf * mi.mesh.get_aabb()
			caja = a if primero else caja.merge(a)
			primero = false
		for h in n.get_children():
			pila.append([h, tf])
	raiz.queue_free()
	if partes.is_empty() or caja.size == Vector3.ZERO:
		return {}
	var medida: float = caja.size.y if por_alto else maxf(caja.size.x, caja.size.z)
	var escala: float = objetivo / maxf(medida, 0.0001)
	# Apoyado: la base del AABB (ya escalada) a y = 0 y centrado en planta.
	var desp: Vector3 = -Vector3(caja.get_center().x, caja.position.y, caja.get_center().z)
	for p in partes:
		p["tf"] = Transform3D(Basis.IDENTITY, desp) * (p["tf"] as Transform3D)
	return {"id": id, "partes": partes, "escala": escala, "alto": caja.size.y * escala, "ancho": maxf(caja.size.x, caja.size.z) * escala}


## Material de un adorno: su textura de albedo (la del .glb), la luz de dibujo animado del lecho y, en las algas, el balanceo.
static func _material_adorno(malla: Mesh, mece: bool, brillo: float) -> ShaderMaterial:
	if _shader_adorno == null:
		_shader_adorno = Shader.new()
		_shader_adorno.code = CODIGO_ADORNO
	var m := ShaderMaterial.new()
	m.shader = _shader_adorno
	var tex: Texture2D = null
	var col := Color(1, 1, 1)
	if malla.get_surface_count() > 0:
		var b: BaseMaterial3D = malla.surface_get_material(0) as BaseMaterial3D
		if b != null:
			tex = b.albedo_texture
			col = b.albedo_color
	if tex != null:
		m.set_shader_parameter("t_albedo", tex)
	m.set_shader_parameter("tinte", Vector3(col.r, col.g, col.b))
	m.set_shader_parameter("brillo", brillo)
	var a: AABB = malla.get_aabb()
	m.set_shader_parameter("base_malla", a.position.y)
	m.set_shader_parameter("altura_malla", a.size.y)
	m.set_shader_parameter("mece", 1.0 if mece else 0.0)
	m.set_shader_parameter("balanceo", ALGA_BALANCEO)
	m.set_shader_parameter("inclina", ALGA_INCLINA)
	m.set_shader_parameter("vel", ALGA_VEL)
	m.set_shader_parameter("flujo_min", ALGA_FLUJO_MIN)
	return m