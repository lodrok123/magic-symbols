class_name Ocluso3D
extends RefCounted

## TRANSPARENCIA ALREDEDOR DEL JUGADOR (y recorte del toldo del puesto).
##
## Lo que queda ENTRE la cámara y el jugador (árboles, setos, el puesto...) se vuelve translúcido en un círculo de
## pantalla centrado en él, para que no se pierda detrás del decorado. Es un descarte con trama (dither), sin mezcla
## alfa: no ordena nada, no cuesta overdraw y no rompe la sombra.
##
## Cómo funciona:
##   - `preparar()` registra UN parámetro de shader global ("oc_jugador": xyz = pecho del jugador, w = radio en metros,
##     0 = apagado). Se llama una vez antes de crear materiales.
##   - `convertir(material)` devuelve un ShaderMaterial equivalente al StandardMaterial3D de Meshy (albedo, color,
##     metálico/rugosidad, normal, emisión, culling) que además lee ese parámetro. Lo que no sea un material opaco
##     normal (transparente, sin sombreado) se deja como está.
##   - `actualizar(pos, radio)` se llama cada frame con la posición del jugador.
##   - `poner_color` / `poner_emision` tintan cualquiera de los dos tipos de material (Reactivo3D los usa).
##   - `recortar_toldo(malla)` quita del puesto de mercado la parte DELANTERA del toldo, que desde la cámara del juego
##     tapaba al tendero.
##
##   - V6: el mismo material trae los uniforms `quemado` y `disolver` (ver más abajo); `convertir_nodo` lo pone en una pieza ya montada (el escudo).
##
## Pj3D, VFX, suelo y hierba no pasan por aquí (no se vuelven translúcidos).

const PARAM: String = "oc_jugador"
const ALFA_MIN: float = 0.12            ## opacidad en el centro del círculo (0 = agujero limpio)
const MARGEN_PROFUNDIDAD: float = 0.5   ## lo que está a menos de esto por detrás del jugador no se recorta

## --- V6 (docs/PLAN_EOW_VISUAL.md): QUEMADO y DISOLVER POR CELDAS en el mismo material ---
## Dos uniforms 0..1 que el Juego anima desde `Reactivo3D` y `Escudo3D` (nada de partículas, igual que en EoW):
##   quemado   albedo × carbón con una máscara de ruido cuyo frente avanza (de abajo arriba y con ruido); en el frente, brasas naranjas
##             emisivas que parpadean; hacia el final lo ya quemado pasa de carbón a ceniza gris. 0 = sano (sin coste: el bloque no se ejecuta).
##   disolver  celdas Voronoi (en coordenadas del OBJETO, a escala de mundo) que desaparecen una a una con un borde brillante del color
##             `disolver_color`. Se descarta en el pipeline opaco (como el dither del jugador), así que la sombra se deshace a la vez.
## Por qué uniforms normales y no `instance uniform`: cada objeto reactivo YA trae sus copias de material (`Reactivo3D._recoger_materiales`) y el
## escudo se las pide aquí (`convertir_nodo`), así que no se duplica nada; y un instance uniform afectaría a todos los materiales de la malla.
## Con `usar_quemado_disolver = false` el Juego vuelve al comportamiento anterior (tinte uniforme CHAMUSCADO y encoger al consumirse).
static var usar_quemado_disolver: bool = true
const QUEMADO_CARBON: Color = Color(0.11, 0.095, 0.085)     ## lo que multiplica al albedo donde ya pasó el frente
const QUEMADO_CENIZA: Color = Color(0.52, 0.51, 0.49)       ## color al que tiende lo quemado al final (ceniza gris)
const QUEMADO_BRASA: Color = Color(1.0, 0.42, 0.08)         ## brasas en el frente
const QUEMADO_BRASA_ENERGIA: float = 2.0
const QUEMADO_ANCHO_FRENTE: float = 0.22                    ## grosor del frente (en unidades de la máscara 0..1; más = frente más difuso)
const QUEMADO_RUIDO_ESCALA: float = 4.0                     ## frecuencia del ruido de la máscara, en 1/m (mayor = manchas más pequeñas)
const DISOLVER_CELDA: float = 0.2                           ## tamaño de celda Voronoi en metros (objetos del decorado)
const DISOLVER_CELDA_ESCUDO: float = 0.085                  ## el escudo mide 0,55 m: con 0,2 serían dos celdas
const DISOLVER_BORDE: float = 0.2                           ## anchura del borde brillante (fracción de la «vida» de cada celda)
const DISOLVER_COLOR: Color = Color(1.0, 0.5, 0.12)         ## color del borde (se puede cambiar por material: `poner_disolver_color`)
const DISOLVER_ENERGIA: float = 1.8

static var _listo: bool = false
static var _shaders: Dictionary = {}    ## variante de culling -> Shader

const CODIGO: String = """
shader_type spatial;
render_mode CULL;

global uniform vec4 oc_jugador;

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 color : source_color = vec4(1.0);
uniform sampler2D tex_orm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_emision : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 emision : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emision_energia = 1.0;
uniform float metalico = 0.0;
uniform float rugosidad = 1.0;
uniform float especular = 0.5;
uniform float usa_orm = 0.0;
uniform float usa_normal = 0.0;
uniform float usa_vertex = 0.0;
uniform float alfa_min = 0.12;
uniform float margen = 0.5;
uniform vec3 uv_escala = vec3(1.0);
uniform vec3 uv_desp = vec3(0.0);

// V6: quemado y disolver por celdas (ver el comentario de la clase).
uniform float quemado : hint_range(0.0, 1.0) = 0.0;
uniform float disolver : hint_range(0.0, 1.0) = 0.0;
uniform vec4 carbon_color : source_color = vec4(0.11, 0.095, 0.085, 1.0);
uniform vec4 ceniza_color : source_color = vec4(0.52, 0.51, 0.49, 1.0);
uniform vec4 brasa_color : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform float brasa_energia = 2.0;
uniform float frente = 0.22;
uniform float ruido_escala = 4.0;
uniform float celda = 0.2;
uniform float borde = 0.2;
uniform vec4 disolver_color : source_color = vec4(1.0, 0.5, 0.12, 1.0);
uniform float disolver_energia = 3.0;
uniform float corte_y = -1000.0;        // V6 restos: por debajo de esta altura del MUNDO no se dibuja (la enredadera brota de la tierra). -1000 = sin efecto
uniform vec2 caja_y = vec2(0.0, 0.0);   // y mínima y alto de la malla (espacio local): da la altura para que el fuego suba
uniform float viento = 0.0;             // bloque 1 EoW: árboles y arbustos se mecen (0 = quieto). Necesita caja_y para saber qué es copa y qué es pie

varying vec3 po;    // posición en el objeto, a escala de mundo (la celda no cambia si lo escalan)
varying float vy;   // altura local
varying float wy;   // altura en el MUNDO (solo para corte_y)

float h31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 h33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float ruido3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1.0, 0.0, 0.0)), f.x), mix(h31(i + vec3(0.0, 1.0, 0.0)), h31(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
			mix(mix(h31(i + vec3(0.0, 0.0, 1.0)), h31(i + vec3(1.0, 0.0, 1.0)), f.x), mix(h31(i + vec3(0.0, 1.0, 1.0)), h31(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

// Voronoi 3D: x = identificador aleatorio de la celda (0..1), y = distancia al punto, z = distancia al borde de la celda.
vec3 voronoi(vec3 p) {
	vec3 ip = floor(p);
	vec3 fp = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int k = -1; k <= 1; k++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec3 g = vec3(float(i), float(j), float(k));
				float d = length(g + h33(ip + g) - fp);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					id = h31(ip + g + 17.0);
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec3(id, d1, d2 - d1);
}

void vertex() {
	po = VERTEX * length(MODEL_MATRIX[0].xyz);
	vy = VERTEX.y;
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	// VIENTO (como la vegetación de EoW: toda la mata se balancea y las puntas aletean). El peso sale de la altura dentro de la malla: el pie
	// no se mueve y la copa sí. Se mide en metros del mundo (sirve igual con piezas escaladas) y la fase sale de la posición de la copia, para
	// que dos árboles vecinos no se muevan a la vez. Va después de po/vy/wy: el quemado y el disolver no «bailan» con la copa.
	if (viento > 0.0 && caja_y.y > 0.0001) {
		float h = clamp((VERTEX.y - caja_y.x) / caja_y.y, 0.0, 1.0);
		vec3 base_w = MODEL_MATRIX[3].xyz;
		float fase = base_w.x * 0.31 + base_w.z * 0.47;
		float balanceo = sin(TIME * 1.3 + fase) * 0.7 + sin(TIME * 2.1 + fase * 1.9) * 0.3;
		float aleteo = sin(TIME * 5.7 + dot(VERTEX, vec3(4.1, 3.3, 3.7)) + fase);
		float esc = length(MODEL_MATRIX[0].xyz);
		float alto_m = caja_y.y * esc;
		vec3 dir = vec3(0.8, 0.0, 0.6);
		vec3 lado = vec3(-0.6, 0.0, 0.8);
		vec3 desp = (dir * balanceo * 0.035 * h * h + lado * aleteo * 0.012 * h) * alto_m * viento;
		VERTEX += (transpose(mat3(MODEL_MATRIX)) * desp) / max(esc * esc, 0.0001);
	}
}

void fragment() {
	if (wy < corte_y) {
		discard;
	}
	vec2 uv = UV * uv_escala.xy + uv_desp.xy;
	vec4 a = texture(tex_albedo, uv) * color;
	if (usa_vertex > 0.5) {
		a *= COLOR;
	}
	vec3 brillo_extra = vec3(0.0);

	// DISOLVER: cada celda tiene una «vida» aleatoria (con un sesgo para que lo alto se vaya antes); al avanzar `disolver` las celdas de vida
	// menor desaparecen y las que están a punto de hacerlo brillan. Descarta también en la pasada de sombras: la sombra se deshace con la pieza.
	if (disolver > 0.0) {
		vec3 v = voronoi(po / celda);
		float altura = caja_y.y > 0.0001 ? clamp((vy - caja_y.x) / caja_y.y, 0.0, 1.0) : 0.5;
		float vida = mix(v.x, 1.0 - altura, 0.25);
		float resto = vida - disolver * (1.0 + borde);
		if (resto < 0.0) {
			discard;
		}
		float brillo = 1.0 - smoothstep(0.0, borde, resto);
		float orilla = 1.0 - smoothstep(0.0, 0.18, v.z);
		brillo *= mix(0.7, 1.0, orilla);
		brillo_extra += disolver_color.rgb * brillo * disolver_energia;
	}

	// QUEMADO: el frente avanza con `quemado`; p es «cuándo le toca» a cada punto (ruido + altura: el fuego sube).
	if (quemado > 0.0) {
		float n = ruido3(po * ruido_escala) * 0.65 + ruido3(po * ruido_escala * 2.7 + 5.0) * 0.35;
		n = clamp((n - 0.2) / 0.6, 0.0, 1.0);
		float altura_q = caja_y.y > 0.0001 ? clamp((vy - caja_y.x) / caja_y.y, 0.0, 1.0) : 0.5;
		float p = mix(n, altura_q, 0.35);
		float m = quemado * (1.0 + 2.0 * frente) - p;
		float c = smoothstep(0.0, frente, m);
		float banda = smoothstep(-0.02, frente * 0.3, m) * (1.0 - smoothstep(frente * 0.3, frente * 1.0, m));
		float ceniza = smoothstep(0.8, 1.0, quemado) * c;
		float mota = ruido3(po * ruido_escala * 3.0 + 11.0);
		vec3 quemada = a.rgb * carbon_color.rgb * mix(0.6, 1.5, mota);
		quemada = mix(quemada, ceniza_color.rgb * mix(0.75, 1.2, mota), ceniza);
		a.rgb = mix(a.rgb, quemada, c);
		float parpadeo = 0.65 + 0.35 * ruido3(po * ruido_escala * 4.0 + vec3(TIME * 3.0));
		float brasa = banda * parpadeo * (1.0 - smoothstep(0.85, 1.0, quemado));
		// Algunas brasas sueltas detrás del frente, que se apagan antes de llegar a ceniza.
		brasa += c * (1.0 - smoothstep(0.5, 0.9, quemado)) * smoothstep(0.72, 0.9, mota) * parpadeo * 0.4;
		brillo_extra += brasa_color.rgb * brasa_energia * brasa;
	}

	ALBEDO = a.rgb;
	SPECULAR = especular;
	if (usa_orm > 0.5) {
		vec3 orm = texture(tex_orm, uv).rgb;
		ROUGHNESS = orm.g * rugosidad;
		METALLIC = orm.b * metalico;
	} else {
		ROUGHNESS = rugosidad;
		METALLIC = metalico;
	}
	if (usa_normal > 0.5) {
		NORMAL_MAP = texture(tex_normal, uv).rgb;
	}
	EMISSION = emision.rgb * emision_energia * texture(tex_emision, uv).rgb + brillo_extra;

	if (oc_jugador.w > 0.0 && !IN_SHADOW_PASS) {
		// Todo en espacio de cámara: el círculo es de pantalla y el radio va en metros (ortogonal o perspectiva).
		vec3 pv = (VIEW_MATRIX * vec4(oc_jugador.xyz, 1.0)).xyz;
		vec2 f = VERTEX.xy;
		if (PROJECTION_MATRIX[3][3] < 0.5) {
			f = VERTEX.xy * (pv.z / VERTEX.z);
		}
		float r = oc_jugador.w;
		float d = length(f - pv.xy);
		// Solo lo que está más cerca de la cámara que el jugador.
		bool delante = (-VERTEX.z) < (-pv.z - margen);
		if (delante && d < r) {
			float k = smoothstep(r * 0.55, r, d);
			float alfa = mix(alfa_min, 1.0, k);
			float ruido = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
			if (alfa < ruido) {
				discard;
			}
		}
	}
}
"""


static func preparar() -> void:
	if _listo:
		return
	_listo = true
	RenderingServer.global_shader_parameter_add(PARAM, RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, 0.0, 0.0, 0.0))


## Pecho del jugador (mundo) y radio del círculo en metros. radio <= 0 lo apaga.
static func actualizar(pos: Vector3, radio: float) -> void:
	if not _listo:
		return
	RenderingServer.global_shader_parameter_set(PARAM, Vector4(pos.x, pos.y, pos.z, radio))


static func _shader(cull: String) -> Shader:
	if not _shaders.has(cull):
		var sh := Shader.new()
		sh.code = CODIGO.replace("render_mode CULL;", "render_mode %s;" % cull)
		_shaders[cull] = sh
	return _shaders[cull]


## Un ShaderMaterial equivalente a `origen` con el círculo de transparencia, o `origen` tal cual si no se puede.
static func convertir(origen: Material) -> Material:
	if not _listo or not (origen is StandardMaterial3D):
		return origen
	var m: StandardMaterial3D = origen as StandardMaterial3D
	if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
			or m.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or m.next_pass != null:
		return origen
	var cull: String = "cull_back"
	match m.cull_mode:
		BaseMaterial3D.CULL_DISABLED:
			cull = "cull_disabled"
		BaseMaterial3D.CULL_FRONT:
			cull = "cull_front"
	var sm := ShaderMaterial.new()
	sm.shader = _shader(cull)
	sm.set_shader_parameter("color", m.albedo_color)
	if m.albedo_texture != null:
		sm.set_shader_parameter("tex_albedo", m.albedo_texture)
	else:
		sm.set_shader_parameter("tex_albedo", _blanca())
	sm.set_shader_parameter("metalico", m.metallic)
	sm.set_shader_parameter("rugosidad", m.roughness)
	sm.set_shader_parameter("especular", m.metallic_specular)
	# glTF: una sola imagen con rugosidad en G y metálico en B (Godot la deja en metallic_texture y roughness_texture).
	var orm: Texture2D = m.roughness_texture if m.roughness_texture != null else m.metallic_texture
	if orm != null:
		sm.set_shader_parameter("tex_orm", orm)
		sm.set_shader_parameter("usa_orm", 1.0)
		sm.set_shader_parameter("metalico", 1.0 if m.metallic_texture != null else m.metallic)
		sm.set_shader_parameter("rugosidad", 1.0 if m.roughness_texture != null else m.roughness)
	if m.normal_enabled and m.normal_texture != null:
		sm.set_shader_parameter("tex_normal", m.normal_texture)
		sm.set_shader_parameter("usa_normal", 1.0)
	if m.emission_enabled:
		sm.set_shader_parameter("emision", m.emission)
		sm.set_shader_parameter("emision_energia", m.emission_energy_multiplier)
		if m.emission_texture != null:
			sm.set_shader_parameter("tex_emision", m.emission_texture)
	if m.vertex_color_use_as_albedo:
		sm.set_shader_parameter("usa_vertex", 1.0)
	sm.set_shader_parameter("uv_escala", m.uv1_scale)
	sm.set_shader_parameter("uv_desp", m.uv1_offset)
	sm.set_shader_parameter("alfa_min", ALFA_MIN)
	sm.set_shader_parameter("margen", MARGEN_PROFUNDIDAD)
	sm.set_shader_parameter("carbon_color", QUEMADO_CARBON)
	sm.set_shader_parameter("ceniza_color", QUEMADO_CENIZA)
	sm.set_shader_parameter("brasa_color", QUEMADO_BRASA)
	sm.set_shader_parameter("brasa_energia", QUEMADO_BRASA_ENERGIA)
	sm.set_shader_parameter("frente", QUEMADO_ANCHO_FRENTE)
	sm.set_shader_parameter("ruido_escala", QUEMADO_RUIDO_ESCALA)
	sm.set_shader_parameter("celda", DISOLVER_CELDA)
	sm.set_shader_parameter("borde", DISOLVER_BORDE)
	sm.set_shader_parameter("disolver_color", DISOLVER_COLOR)
	sm.set_shader_parameter("disolver_energia", DISOLVER_ENERGIA)
	return sm


## --- V6: manejo del quemado y el disolver (cualquier otro material se ignora; quien llama decide el plan B con `es_comun`) ---

## ¿Es este material el común de arriba (el único que sabe quemarse y disolverse)?
static func es_comun(mat: Material) -> bool:
	return mat is ShaderMaterial and (mat as ShaderMaterial).shader != null and _shaders.values().has((mat as ShaderMaterial).shader)


static func poner_quemado(mat: Material, v: float) -> void:
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("quemado", clampf(v, 0.0, 1.0))


static func poner_disolver(mat: Material, v: float) -> void:
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("disolver", clampf(v, 0.0, 1.0))


static func quemado_de(mat: Material) -> float:
	if mat is ShaderMaterial:
		var v: Variant = (mat as ShaderMaterial).get_shader_parameter("quemado")
		return float(v) if v != null else 0.0
	return 0.0


static func disolver_de(mat: Material) -> float:
	if mat is ShaderMaterial:
		var v: Variant = (mat as ShaderMaterial).get_shader_parameter("disolver")
		return float(v) if v != null else 0.0
	return 0.0


## Color del borde brillante, tamaño de celda en metros (<= 0 deja el de serie).
static func configurar_disolver(mat: Material, color: Color, tam_celda: float = 0.0) -> void:
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("disolver_color", color)
		if tam_celda > 0.0:
			(mat as ShaderMaterial).set_shader_parameter("celda", tam_celda)


## Altura de la malla (y mínima y alto, en su espacio local) para que el frente del fuego suba por ella.
static func poner_caja(mat: Material, malla: Mesh) -> void:
	if mat is ShaderMaterial and malla != null:
		var c: AABB = malla.get_aabb()
		(mat as ShaderMaterial).set_shader_parameter("caja_y", Vector2(c.position.y, c.size.y))


## Bloque 1 EoW: la pieza se mece con el viento (`fuerza` 0 = quieta, 1 = árbol). Pone también la caja de la malla, que da la altura
## (el pie quieto, la copa moviéndose). Solo mueve lo que se VE: la colisión es otro cuerpo y no se entera.
static func poner_viento(mat: Material, fuerza: float, malla: Mesh) -> void:
	if mat is ShaderMaterial and es_comun(mat):
		poner_caja(mat, malla)
		(mat as ShaderMaterial).set_shader_parameter("viento", fuerza)


## Altura del MUNDO por debajo de la cual no se dibuja nada (la enredadera que brota del suelo). -1000 = sin recorte.
static func poner_corte_y(mat: Material, y: float) -> void:
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("corte_y", y)


## Pasa al material común TODAS las superficies de `nodo` (copias propias: el original no se toca, ni lo comparten otras piezas) y devuelve
## los materiales resultantes (los que no se pueden convertir —transparentes, sin sombreado— se quedan como estaban y no entran en la lista).
## Lo usa el escudo, que dibuja con `PiezaFuego3D` (materiales sin círculo de transparencia). Necesita `preparar()`.
static func convertir_nodo(nodo: Node) -> Array[ShaderMaterial]:
	var res: Array[ShaderMaterial] = []
	if not _listo or nodo == null:
		return res
	for n in nodo.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		if mi.material_override != null:
			# `material_override` MANDA sobre el de superficie: hay que sustituir ese (las primitivas de PiezaFuego3D lo usan).
			var c: Material = convertir(mi.material_override.duplicate() as Material)
			if c is ShaderMaterial:
				mi.material_override = c
				poner_caja(c, mi.mesh)
				res.append(c as ShaderMaterial)
			continue
		for s in range(mi.mesh.get_surface_count()):
			var base: Material = mi.get_active_material(s)
			if base == null:
				continue
			var c2: Material = convertir(base.duplicate() as Material)
			if c2 is ShaderMaterial:
				mi.set_surface_override_material(s, c2)
				poner_caja(c2, mi.mesh)
				res.append(c2 as ShaderMaterial)
	return res


static var _tex_blanca: ImageTexture = null

static func _blanca() -> Texture2D:
	if _tex_blanca == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_tex_blanca = ImageTexture.create_from_image(img)
	return _tex_blanca


## Una copia de `malla` con todos los materiales convertidos (la malla original no se toca).
static func malla_con_hueco(malla: Mesh) -> Mesh:
	if not _listo or malla == null:
		return malla
	var res: Mesh = malla.duplicate() as Mesh
	for i in range(res.get_surface_count()):
		var mat: Material = res.surface_get_material(i)
		if mat != null:
			res.surface_set_material(i, convertir(mat))
	return res


## --- Tinte: sirve para StandardMaterial3D y para el ShaderMaterial de arriba ---

static func poner_color(mat: Material, c: Color) -> void:
	if mat is StandardMaterial3D:
		(mat as StandardMaterial3D).albedo_color = c
	elif mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("color", c)


static func color_de(mat: Material) -> Color:
	if mat is StandardMaterial3D:
		return (mat as StandardMaterial3D).albedo_color
	if mat is ShaderMaterial:
		var v: Variant = (mat as ShaderMaterial).get_shader_parameter("color")
		return v if v is Color else Color.WHITE
	return Color.WHITE


static func poner_emision(mat: Material, c: Color, energia: float) -> void:
	if mat is StandardMaterial3D:
		var s: StandardMaterial3D = mat as StandardMaterial3D
		s.emission_enabled = energia > 0.001
		s.emission = c
		s.emission_energy_multiplier = energia
	elif mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("emision", c)
		(mat as ShaderMaterial).set_shader_parameter("emision_energia", maxf(energia, 0.0))


## --- Puesto de mercado: quita la mitad delantera del techo para que se vea al tendero ---

static func recortar_toldo(malla: Mesh) -> Mesh:
	if malla == null:
		return malla
	var res := ArrayMesh.new()
	var caja: AABB = malla.get_aabb()
	var y0: float = caja.position.y + caja.size.y * 0.55
	var z0: float = caja.position.z + caja.size.z * 0.5 - caja.size.z * 0.12
	for i in range(malla.get_surface_count()):
		var arr: Array = malla.surface_get_arrays(i)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(v.size())
			for k in range(v.size()):
				idx[k] = k
		var nuevo := PackedInt32Array()
		var t: int = 0
		while t + 2 < idx.size():
			var a: int = idx[t]
			var b: int = idx[t + 1]
			var c: int = idx[t + 2]
			var m: Vector3 = (v[a] + v[b] + v[c]) / 3.0
			if not (m.y > y0 and m.z > z0):
				nuevo.append(a)
				nuevo.append(b)
				nuevo.append(c)
			t += 3
		arr[Mesh.ARRAY_INDEX] = nuevo
		res.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		res.surface_set_material(res.get_surface_count() - 1, malla.surface_get_material(i))
	return res
