class_name BrilloPulso3D
extends RefCounted

## EL BRILLO DEL PULSO sobre un MODELO (23/10, FASE 1 del Pulso resonante; docs/PLAN_PULSO_RESONANTE.md §3 y §9). Lo usan el cristal, el receptor y, en
## las fases siguientes, el prisma. Son modelos de Meshy con el cristal turquesa SATURADO (se pidió aguamarina apagado: arte/meshy/PROMPTS_CUEVA.md,
## «Estado»), pegado al resto de la roca en el MISMO atlas de textura. Sin regenerar ni tocar `Ocluso3D` (que no es de esta fase):
##   · se sustituye el material de cada superficie por un ShaderMaterial propio que lee la MISMA textura (albedo y normales) del material original;
##   · el «cristal» es lo que en el atlas es cian (verde y azul por encima del rojo): ahí se BAJA la saturación y el valor (`SAT_REPOSO`,
##     `OSCURECER_REPOSO`) para que en reposo se vea apagado, y ahí —solo ahí— se suma la EMISIÓN `color_pulso × energia`. El resto de la roca no brilla.
## `energia` va de 0 (apagado) a `ENERGIA_MAX`; quien llama la anima (el latido del cristal, el receptor activo). Un material por pieza: dos cristales
## no comparten brillo.

const SAT_REPOSO: float = 0.15          ## cuánto del color del cristal se conserva en reposo (1 = el turquesa saturado de la malla)
const OSCURECER_REPOSO: float = 0.55    ## cuánto de su valor (1 = igual): apagado y mate
const ENERGIA_MAX: float = 3.0          ## emisión del destello pleno (se ve por encima del bloom del juego sin quemar el modelo)
const CIAN_MIN: float = 0.12            ## umbral del «es cristal»: (mín(verde, azul) − rojo) del texel, suavizado entre MIN y MAX
const CIAN_MAX: float = 0.40
const RUGOSIDAD: float = 0.85

## LA CUEVA ILUMINADA EN AZUL (23/10, Pablo: «un brillo muy sutil a los cristales para que la cueva esté iluminada en azul»). En REPOSO el cristal lleva una emisión muy
## baja del azul claro del pulso base (`COLOR_REPOSO`) y los cristales GRANDES, además, una luz pequeña y tenue sin sombras. Todo muy por debajo del destello del pulso
## (`ENERGIA_MAX` 3,0 y las luces de 1,3–1,6) y de los braseros. Las luces cuestan: como mucho `MAX_LUCES_REPOSO` a la vez en todo el mapa (la Cueva tiene seis salas), y las
## piezas las piden con `reservar_luz` / devuelven con `liberar_luz` (una pieza sin luz sigue brillando por emisión).
const COLOR_REPOSO: Color = Color(0.62, 0.85, 1.0)   ## = Pulso3D.COLOR_BASE (#9ED9FF); se repite aquí para no depender del orden de carga
## Subida (23/10, 2.ª vuelta; Pablo: «en el SUELO casi nada»): emisión 0,16 → 0,22, luz 0,5 → 0,8, alcance 5,2 → 6,5 y tope 8 → 10. El destello suma `ENERGIA_LUZ` (1,6) a la luz de
## reposo, así que sigue en ~3× (la prueba exige ≥ 2,5×) y su emisión (3,0) sigue 14× por encima de la de reposo.
const ENERGIA_REPOSO: float = 0.22                   ## emisión del cristal en reposo (el destello pleno es 3,0)
const LUZ_REPOSO_ENERGIA: float = 0.8                ## energía de la luz azul de un cristal grande en reposo (0,32 y luego 0,5 apenas se veían en el suelo de la Cueva, que se lleva casi toda la luz)
const LUZ_REPOSO_ALCANCE: float = 6.5                ## u
const MAX_LUCES_REPOSO: int = 10                     ## tope de luces de reposo vivas a la vez
static var _luces_reposo: int = 0

const CODIGO: String = """
shader_type spatial;
uniform sampler2D t_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float rugosidad = 0.85;
uniform float sat_reposo = 0.15;
uniform float oscurecer = 0.55;
uniform float cian_min = 0.12;
uniform float cian_max = 0.40;
uniform vec3 color_pulso : source_color = vec3(0.62, 0.85, 1.0);
uniform float energia = 0.0;
uniform vec3 color_reposo : source_color = vec3(0.62, 0.85, 1.0);
uniform float energia_reposo = 0.0;

void fragment() {
	vec4 t = texture(t_albedo, UV);
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	float cristal = smoothstep(cian_min, cian_max, min(t.g, t.b) - t.r);
	vec3 apagado = mix(vec3(lum), t.rgb, sat_reposo) * oscurecer;
	ALBEDO = mix(t.rgb, apagado, cristal);
	ROUGHNESS = rugosidad;
	NORMAL_MAP = texture(t_normal, UV).rgb;
	EMISSION = (color_pulso * energia + color_reposo * energia_reposo) * cristal;
}
"""

static var _shader: Shader = null


## El modelo de la pieza `id` con su medida (la maqueta lo escala a `Pieza3D.MEDIDA`: `mundo._pieza`) o, sin maqueta, la escena horneada de `arte/piezas`. null si no hay.
static func modelo(id: String, mundo: Node) -> Node3D:
	if mundo != null and is_instance_valid(mundo) and mundo.has_method("_pieza"):
		var n: Node3D = mundo.call("_pieza", id) as Node3D
		if n != null:
			return n
	var ruta: String = "res://arte/piezas/%s.tscn" % id
	if ResourceLoader.exists(ruta):
		var escena: PackedScene = load(ruta) as PackedScene
		return escena.instantiate() as Node3D if escena != null else null
	return null


## Cambia el material de todas las superficies de `nodo` por el del pulso (conservando su textura) y devuelve los materiales nuevos.
## Un modelo sin texturas (primitiva) o sin StandardMaterial3D se deja como está: devuelve [] y no brilla.
static func preparar(nodo: Node) -> Array[ShaderMaterial]:
	var res: Array[ShaderMaterial] = []
	if nodo == null:
		return res
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODIGO
	for n in nodo.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var base: Material = mi.get_active_material(s)
			if not (base is StandardMaterial3D) or (base as StandardMaterial3D).albedo_texture == null:
				continue
			var sm: StandardMaterial3D = base as StandardMaterial3D
			var m := ShaderMaterial.new()
			m.shader = _shader
			m.set_shader_parameter("t_albedo", sm.albedo_texture)
			if sm.normal_texture != null:
				m.set_shader_parameter("t_normal", sm.normal_texture)
			m.set_shader_parameter("rugosidad", RUGOSIDAD)
			m.set_shader_parameter("sat_reposo", SAT_REPOSO)
			m.set_shader_parameter("oscurecer", OSCURECER_REPOSO)
			m.set_shader_parameter("cian_min", CIAN_MIN)
			m.set_shader_parameter("cian_max", CIAN_MAX)
			m.set_shader_parameter("color_reposo", COLOR_REPOSO)
			m.set_shader_parameter("energia_reposo", ENERGIA_REPOSO)
			mi.set_surface_override_material(s, m)
			res.append(m)
	return res


## ¿Cabe otra luz de reposo? Si sí, la reserva (quien la reserve debe llamar a `liberar_luz` al salir del árbol).
static func reservar_luz() -> bool:
	if _luces_reposo >= MAX_LUCES_REPOSO:
		return false
	_luces_reposo += 1
	return true


static func liberar_luz() -> void:
	_luces_reposo = maxi(_luces_reposo - 1, 0)


static func luces_reservadas() -> int:
	return _luces_reposo


## LA MANCHA DE LUZ AZUL EN EL SUELO (23/10, 2.ª vuelta; Pablo: «en el SUELO casi nada»). Medido en las capturas, subir la luz de las piezas apenas cambia el suelo de la Cueva
## (+4 de 255 en azul junto al cristal con luz 0,8): su material casi no responde a las luces puntuales. Así que cada pieza que brilla (cristal, receptor, prisma) pone en el suelo
## a su pie una mancha radial de luz azul (aditiva, sin sombra ni coste de luz): `SUELO_ENERGIA_REPOSO` en reposo y hasta `+ SUELO_ENERGIA_DESTELLO` en el destello del pulso.
const SUELO_RADIO: float = 2.6                       ## u de radio de la mancha (algo más de una casilla)
const SUELO_ENERGIA_REPOSO: float = 0.2              ## multiplicador del azul en el centro de la mancha en reposo (el suelo ronda 0,12–0,22 por canal: 0,2 lo hace claramente azul)
const SUELO_ENERGIA_DESTELLO: float = 1.0            ## lo que suma el destello pleno (5× el reposo)
const SUELO_ALTO: float = 0.045                      ## u sobre el suelo (sobre la veta, 0,03; bajo las grietas de la pared hueca, 0,05)
const CODIGO_SUELO: String = """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;
uniform vec3 color : source_color = vec3(0.62, 0.85, 1.0);
uniform float energia = 0.2;
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float cae = pow(1.0 - smoothstep(0.0, 1.0, d), 1.8);
	ALBEDO = color * energia * cae;
	ALPHA = 1.0;
}
"""
static var _shader_suelo: Shader = null


## Pone la mancha en el suelo bajo `padre` (su origen está en el suelo). null sin mundo (una prueba de lógica). Se actualiza con `pintar_suelo`.
static func suelo_azul(padre: Node3D) -> MeshInstance3D:
	if padre == null or not Terreno3D.hay_mundo():
		return null
	if _shader_suelo == null:
		_shader_suelo = Shader.new()
		_shader_suelo.code = CODIGO_SUELO
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(SUELO_RADIO * 2.0, SUELO_RADIO * 2.0)
	var m := ShaderMaterial.new()
	m.shader = _shader_suelo
	m.set_shader_parameter("color", COLOR_REPOSO)
	m.set_shader_parameter("energia", SUELO_ENERGIA_REPOSO)
	var mi := MeshInstance3D.new()
	mi.name = "suelo_azul"
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.0, SUELO_ALTO, 0.0)
	padre.add_child(mi)
	return mi


## `e` = 0 en reposo, 1 en el destello pleno (el mismo `e` con que la pieza pinta su luz).
static func pintar_suelo(mi: MeshInstance3D, color: Color, e: float) -> void:
	if mi == null:
		return
	var m: ShaderMaterial = mi.material_override as ShaderMaterial
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("energia", SUELO_ENERGIA_REPOSO + SUELO_ENERGIA_DESTELLO * clampf(e, 0.0, 1.5))


## Pone color y energía de brillo en los materiales de `preparar`.
static func poner(mats: Array, color: Color, energia: float) -> void:
	for m in mats:
		var sm: ShaderMaterial = m as ShaderMaterial
		if sm != null:
			sm.set_shader_parameter("color_pulso", color)
			sm.set_shader_parameter("energia", energia)
