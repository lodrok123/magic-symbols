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

void fragment() {
	vec4 t = texture(t_albedo, UV);
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	float cristal = smoothstep(cian_min, cian_max, min(t.g, t.b) - t.r);
	vec3 apagado = mix(vec3(lum), t.rgb, sat_reposo) * oscurecer;
	ALBEDO = mix(t.rgb, apagado, cristal);
	ROUGHNESS = rugosidad;
	NORMAL_MAP = texture(t_normal, UV).rgb;
	EMISSION = color_pulso * cristal * energia;
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
			mi.set_surface_override_material(s, m)
			res.append(m)
	return res


## Pone color y energía de brillo en los materiales de `preparar`.
static func poner(mats: Array, color: Color, energia: float) -> void:
	for m in mats:
		var sm: ShaderMaterial = m as ShaderMaterial
		if sm != null:
			sm.set_shader_parameter("color_pulso", color)
			sm.set_shader_parameter("energia", energia)
