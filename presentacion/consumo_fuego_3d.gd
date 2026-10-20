class_name ConsumoFuego3D
extends Node3D
## CONSUMO POR FUEGO (Pipeline, 20/10): cómo se destruye de verdad lo que arde. Sustituye el «aplastar en Y en 0,5 s» de `Reactivo3D._consumir`.
##
## Qué se ve (dura `duracion` s, 1,6 por defecto):
##   · un FRENTE DE BRASA sube por el modelo desde donde prendió (o desde la base): lo que queda detrás ya no existe (se descarta), el borde brilla
##     naranja→rojo y lo que está a punto de arder se carboniza. El frente no es una línea recta: lo desordena un ruido (a trozos va más deprisa),
##     y deja los bordes rotos como una hoja quemada, no un corte limpio.
##   · el modelo se HUNDE un poco (pierde sustento) y tiembla al principio; no se aplasta.
##   · brasas que suben desde el frente, humo oscuro que sube y se ensancha y, al final, un montón de ceniza plano que se desvanece.
## Es solo presentación: no toca colisión ni lógica. Funciona con cualquier modelo de `Pieza3D` (toma el color/textura de cada superficie).
##
## Uso (lo llama el Juego desde `Reactivo3D._consumir`, en lugar del tween de escala):
##   var c := ConsumoFuego3D.consumir(visual, 1.6)          # `visual` = el Node3D del modelo (puede seguir siendo hijo del Reactivo)
##   await c.terminado                                      # después de esto: liberar el Reactivo (queue_free)
## `origen` (global) es el punto donde prendió; si no se pasa, el frente sube desde la base de abajo arriba.
## Los materiales se SUSTITUYEN por uno propio durante el consumo (con el color de la textura y el chamuscado ya puesto): el círculo de transparencia
## del jugador (`Ocluso3D`) no se aplica en esos ~1,6 s.

signal terminado

const CODIGO: String = """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float usar_tex = 0.0;
uniform vec4 tinte : source_color = vec4(0.30, 0.25, 0.22, 1.0);   // el CHAMUSCADO de Reactivo3D
uniform float chamusc = 1.0;                                       // cuánto del tinte lleva ya (1 = chamuscado entero)
uniform float quema = 0.0;                                         // 0 = entero, 1 = consumido
uniform vec3 origen = vec3(0.0);
uniform float y0 = 0.0;
uniform float alto = 1.0;
uniform float radio = 1.0;
uniform float desde_punto = 0.0;                                   // 1 = el frente nace en `origen` y se extiende; 0 = sube desde la base
uniform float borde = 0.09;
uniform vec3 brasa_clara : source_color = vec3(1.0, 0.62, 0.18);
uniform vec3 brasa_honda : source_color = vec3(0.85, 0.12, 0.02);
uniform vec3 carbon : source_color = vec3(0.07, 0.05, 0.045);

varying vec3 v_mundo;

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float ruido(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	v_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 c = albedo;
	if (usar_tex > 0.5) {
		c *= texture(albedo_tex, UV);
	}
	vec3 col = mix(c.rgb, c.rgb * tinte.rgb, chamusc);
	// Distancia del frente: 0 en el origen/la base, 1 en el punto más lejano. El ruido (dos escalas) lo desordena.
	float d_base = clamp((v_mundo.y - y0) / max(alto, 0.01), 0.0, 1.0);
	float d_punto = clamp(length(v_mundo - origen) / max(radio, 0.01), 0.0, 1.0);
	float d = mix(d_base, d_punto, desde_punto);
	float n = ruido(v_mundo * 4.5) * 0.65 + ruido(v_mundo * 11.0) * 0.35;
	float frente = d * 0.7 + (1.0 - n) * 0.3;
	float u = frente - (quema * (1.0 + 2.0 * borde) - borde);        // < 0: ya no existe
	if (u < 0.0) {
		discard;
	}
	float en_borde = 1.0 - smoothstep(0.0, borde, u);                 // 1 justo en el frente
	float carbon_k = 1.0 - smoothstep(borde, borde * 3.2, u);         // la franja que está a punto de arder
	col = mix(col, carbon, carbon_k * 0.85);
	vec3 brillo = mix(brasa_honda, brasa_clara, smoothstep(0.0, 0.7, en_borde)) * (0.7 + 0.6 * n);
	ALBEDO = mix(col, carbon, en_borde * 0.6);
	EMISSION = brillo * en_borde * 2.2;
	ROUGHNESS = 0.95;
}
"""

const COLOR_CENIZA: Color = Color(0.17, 0.16, 0.16, 0.8)
const TIEMBLA: float = 0.012          ## amplitud (u) del temblor del principio

static var _shader: Shader = null
static var _tex_suave: Texture2D = null

var duracion: float = 1.6
var _visual: Node3D = null
var _mats: Array = []                 ## ShaderMaterial por superficie
var _t: float = 0.0
var _escala0: Vector3 = Vector3.ONE
var _pos0: Vector3 = Vector3.ZERO
var _caja: AABB = AABB()
var _brasas: CPUParticles3D = null
var _bocanadas: Array = []            ## humo: {nodo, mat, t0, vida, p0, tam}
var _ceniza: MeshInstance3D = null
var _fin: bool = false
var _origen_global: Vector3 = Vector3.INF


## Empieza el consumo de `visual` y devuelve el nodo que lo gobierna (cuelga de `visual.get_parent()` salvo que se pase otro padre).
static func consumir(visual: Node3D, dur: float = 1.6, origen: Vector3 = Vector3.INF, padre: Node = null) -> ConsumoFuego3D:
	var c := ConsumoFuego3D.new()
	c.duracion = maxf(0.3, dur)
	c._origen_global = origen
	var anfitrion: Node = padre if padre != null else (visual.get_parent() if visual.get_parent() != null else visual)
	anfitrion.add_child(c)
	c._empezar(visual)
	return c


static func _shader_comun() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODIGO
	return _shader


static func _textura_suave() -> Texture2D:
	if _tex_suave == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_tex_suave = t
	return _tex_suave


func _empezar(visual: Node3D) -> void:
	_visual = visual
	_escala0 = visual.scale
	_pos0 = visual.position
	# Caja global de todo lo que se dibuja (para saber dónde está la base y cuánto mide el frente).
	var primera: bool = true
	for n in visual.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var caja: AABB = mi.global_transform * mi.get_aabb()
		_caja = caja if primera else _caja.merge(caja)
		primera = false
		for s in range(mi.mesh.get_surface_count()):
			var origen_mat: Material = mi.get_active_material(s)
			var m := ShaderMaterial.new()
			m.shader = _shader_comun()
			if origen_mat is StandardMaterial3D:
				var sm: StandardMaterial3D = origen_mat
				m.set_shader_parameter("albedo", sm.albedo_color)
				if sm.albedo_texture != null:
					m.set_shader_parameter("albedo_tex", sm.albedo_texture)
					m.set_shader_parameter("usar_tex", 1.0)
			else:
				m.set_shader_parameter("albedo", Color(0.45, 0.4, 0.35))
			mi.set_surface_override_material(s, m)
			_mats.append(m)
	if primera:
		_caja = AABB(visual.global_position - Vector3(0.4, 0.0, 0.4), Vector3(0.8, 0.8, 0.8))
	var desde_punto: bool = _origen_global.is_finite()
	var radio: float = _caja.size.length() * 0.6
	for m in _mats:
		(m as ShaderMaterial).set_shader_parameter("y0", _caja.position.y)
		(m as ShaderMaterial).set_shader_parameter("alto", _caja.size.y)
		(m as ShaderMaterial).set_shader_parameter("radio", radio)
		(m as ShaderMaterial).set_shader_parameter("origen", _origen_global if desde_punto else Vector3.ZERO)
		(m as ShaderMaterial).set_shader_parameter("desde_punto", 1.0 if desde_punto else 0.0)
	_montar_particulas()
	set_process(true)


func _montar_particulas() -> void:
	var centro: Vector3 = _caja.get_center()
	var vol: float = clampf(_caja.size.x * _caja.size.z * maxf(_caja.size.y, 0.3), 0.1, 12.0)
	# Brasas: puntos naranjas que suben y se apagan; salen de todo el volumen (el frente las suelta donde está).
	_brasas = CPUParticles3D.new()
	_brasas.top_level = true
	_brasas.amount = clampi(int(14.0 + vol * 10.0), 14, 60)
	_brasas.lifetime = 1.1
	_brasas.explosiveness = 0.0
	_brasas.randomness = 0.6
	_brasas.local_coords = false
	_brasas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_brasas.emission_box_extents = Vector3(maxf(_caja.size.x * 0.5, 0.1), 0.05, maxf(_caja.size.z * 0.5, 0.1))
	_brasas.direction = Vector3.UP
	_brasas.spread = 35.0
	_brasas.gravity = Vector3(0.0, 0.8, 0.0)
	_brasas.initial_velocity_min = 0.5
	_brasas.initial_velocity_max = 1.5
	_brasas.scale_amount_min = 0.6
	_brasas.scale_amount_max = 1.4
	var gr := Gradient.new()
	gr.set_color(0, Color(1.0, 0.8, 0.3, 1.0))
	gr.add_point(0.55, Color(1.0, 0.3, 0.05, 0.9))
	gr.set_color(gr.get_point_count() - 1, Color(0.3, 0.05, 0.0, 0.0))
	_brasas.color_ramp = gr
	var qm := QuadMesh.new()
	qm.size = Vector2(0.06, 0.06)                              # el tamaño real va en el quad; `scale_amount` solo da variedad
	var mb := StandardMaterial3D.new()
	mb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mb.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES          # con ENABLED el quad ignora la escala de la partícula y sale de 1 u
	mb.particles_anim_h_frames = 1
	mb.particles_anim_v_frames = 1
	mb.vertex_color_use_as_albedo = true
	mb.albedo_texture = _textura_suave()
	mb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA          # sin esto el aditivo ignora el alfa y salen cuadrados
	mb.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mb.no_depth_test = false
	qm.material = mb
	_brasas.mesh = qm
	_brasas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_brasas.emitting = false
	add_child(_brasas)
	_brasas.global_position = Vector3(centro.x, _caja.position.y, centro.z)
	# Humo: bocanadas grises que suben, crecen y se desvanecen, escalonadas a lo largo del consumo. Son quads con billboard animados a mano
	# (con CPUParticles3D salía una bola negra fija en el emisor que no supe quitar; así es determinista y no cuesta nada: ≤ 24 quads).
	var n_humo: int = clampi(int(6.0 + vol * 4.0), 6, 24)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_caja.position.x * 1000.0) ^ int(_caja.position.z * 1000.0)
	var qh := QuadMesh.new()
	qh.size = Vector2(0.5, 0.5)
	for i in range(n_humo):
		var mh := StandardMaterial3D.new()
		mh.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mh.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mh.albedo_texture = _textura_suave()
		mh.albedo_color = Color(0.40, 0.38, 0.37, 0.0)
		mh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var mi := MeshInstance3D.new()
		mi.mesh = qh
		mi.material_override = mh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.top_level = true
		add_child(mi)
		var inicio := Vector3(centro.x + rng.randf_range(-0.35, 0.35) * _caja.size.x, _caja.position.y + rng.randf_range(0.2, 0.8) * _caja.size.y, centro.z + rng.randf_range(-0.35, 0.35) * _caja.size.z)
		mi.global_position = inicio
		_bocanadas.append({"nodo": mi, "mat": mh, "t0": rng.randf_range(0.0, duracion * 0.85), "vida": rng.randf_range(1.2, 1.7), "p0": inicio, "tam": rng.randf_range(0.7, 1.3)})
	_brasas.emitting = true


func _process(delta: float) -> void:
	if _fin:
		# Ya terminó el consumo: solo queda el humo (y la ceniza que se apaga sola). Se libera cuando la última bocanada se ha ido.
		_t += delta
		_animar_humo()
		if _t > duracion * 0.85 + 1.8:
			queue_free()
		return
	if _visual == null or not is_instance_valid(_visual):
		_terminar()
		return
	_t += delta
	var k: float = clampf(_t / duracion, 0.0, 1.0)
	var q: float = k * k * (3.0 - 2.0 * k)                   # ease-in-out: arranca lento, corre en medio, remata despacio
	for m in _mats:
		(m as ShaderMaterial).set_shader_parameter("quema", q)
	# El frente de brasas: las partículas siguen la altura del frente (sube de la base a la cima).
	var y_frente: float = _caja.position.y + _caja.size.y * clampf(q, 0.0, 1.0)
	if is_instance_valid(_brasas):
		_brasas.global_position.y = y_frente
		if k > 0.85:
			_brasas.emitting = false                             # las últimas brasas ya no salen: no queda frente que las suelte
	_animar_humo()
	# Se hunde un poco (pierde sustento) y tiembla al principio.
	var hundido: float = 1.0 - 0.22 * q * q
	_visual.scale = Vector3(_escala0.x * (1.0 + 0.04 * q), _escala0.y * hundido, _escala0.z * (1.0 + 0.04 * q))
	var temblor: float = TIEMBLA * (1.0 - k) * sin(_t * 47.0)
	_visual.position = _pos0 + Vector3(temblor, 0.0, temblor * 0.6)
	if k >= 1.0:
		_terminar()


## Cada bocanada vive `vida` s desde su `t0` (también después de terminar el consumo): sube, crece y se desvanece (alfa: sube rápido y cae despacio).
func _animar_humo() -> void:
	for b in _bocanadas:
		var e: float = (_t - float(b["t0"])) / float(b["vida"])
		var mi: MeshInstance3D = b["nodo"]
		if not is_instance_valid(mi):
			continue
		if e < 0.0 or e > 1.0:
			mi.visible = false
			continue
		mi.visible = true
		var p: Vector3 = b["p0"]
		mi.global_position = p + Vector3(0.0, 0.9 * e, 0.0)
		var tam: float = float(b["tam"]) * (0.6 + 1.3 * e)
		mi.scale = Vector3(tam, tam, tam)
		var alfa: float = 0.34 * smoothstep(0.0, 0.18, e) * (1.0 - smoothstep(0.35, 1.0, e))
		(b["mat"] as StandardMaterial3D).albedo_color.a = alfa


func _terminar() -> void:
	if _fin:
		return
	_fin = true
	if is_instance_valid(_visual):
		_visual.visible = false
	if is_instance_valid(_brasas):
		_brasas.emitting = false
	_poner_ceniza()
	terminado.emit()


## Un montón plano y oscuro donde estaba: se aplasta desde el centro y se desvanece en ~2 s (no deja nada permanente).
func _poner_ceniza() -> void:
	var r: float = clampf(maxf(_caja.size.x, _caja.size.z) * 0.30, 0.12, 0.9)
	_ceniza = MeshInstance3D.new()
	_ceniza.top_level = true
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.55
	cm.bottom_radius = r
	cm.height = 0.05
	cm.radial_segments = 14
	_ceniza.mesh = cm
	_ceniza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := StandardMaterial3D.new()
	mm.albedo_color = COLOR_CENIZA
	mm.roughness = 1.0
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ceniza.material_override = mm
	add_child(_ceniza)
	_ceniza.global_position = Vector3(_caja.get_center().x, _caja.position.y + 0.025, _caja.get_center().z)
	_ceniza.scale = Vector3(0.3, 0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(_ceniza, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mm, "albedo_color:a", 0.0, 1.7).set_delay(0.2)
