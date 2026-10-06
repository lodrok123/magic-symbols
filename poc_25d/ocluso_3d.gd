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
## Pj3D, VFX, suelo y hierba no pasan por aquí (no se vuelven translúcidos).

const PARAM: String = "oc_jugador"
const ALFA_MIN: float = 0.12            ## opacidad en el centro del círculo (0 = agujero limpio)
const MARGEN_PROFUNDIDAD: float = 0.5   ## lo que está a menos de esto por detrás del jugador no se recorta

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

void fragment() {
	vec2 uv = UV * uv_escala.xy + uv_desp.xy;
	vec4 a = texture(tex_albedo, uv) * color;
	if (usa_vertex > 0.5) {
		a *= COLOR;
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
	EMISSION = emision.rgb * emision_energia * texture(tex_emision, uv).rgb;

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
	return sm


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
