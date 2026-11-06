class_name NieblaCanouro3D
extends Node3D
## EL CANOURO COMO SOMBRA DE HUMO NEGRO (5/11, encargo de Pablo; 2.ª versión tras ver la primera: «debería oscurecerse todo y no poderse distinguir
## la forma», con referencias de un perro-sombra negro de ojos blancos y de un espectro de humo). Tres piezas, todas afinables en `static var`:
##  1. CUERPO NEGRO: la malla del animal se pinta sin luz y de negro casi puro (`material_override`): no se le ve ni el pelaje ni el volumen.
##  2. HUMO DEL CUERPO: emisores de bocanadas negras colgados de los huesos (lomo, cuello, cabeza, cola, muslos y pies), en coordenadas del
##     MUNDO: el humo se queda atrás y se deshace cuando el animal se mueve, y envolviéndolo borra su silueta.
##  3. OJOS: dos puntos blancos que brillan, atados al hueso de la cabeza (lo único que se distingue de la masa negra).
##  Y debajo sigue la NIEBLA A RAS DE SUELO de la 1.ª versión: láminas horizontales muy bajas con ruido que deriva en el mundo y se funde
##  contra suelo y patas (técnica de `presentacion/niebla_foso_3d.gd`). El nodo sigue al animal con un pequeño retraso (SUAVIZADO).
##
## Referencias: `presentacion/vfx_canouro_3d.gd` (humo de pies del laboratorio, de donde salen el negro y el emisor) y `niebla_foso_3d.gd`.
## Ojo: con el cuerpo negro el destello de color de Combate3D al recibir un golpe (tiñe `_materiales`) no se ve: lo tapa el override.
##
## Uso: `NieblaCanouro3D.poner(pj, alto)` (lo hace Combate3D para el id "canouro"); se cuelga del Pj3D y se libera con él.

## --- cuerpo ---
## Pintar la malla de negro sin luz. false = el modelo se ve como siempre, solo con el humo encima.
static var CUERPO_NEGRO: bool = true
## Color del cuerpo (un poco por encima del humo para que la masa no sea plana del todo).
static var CUERPO_COLOR: Color = Color(0.035, 0.035, 0.045)

## --- humo del cuerpo ---
## Huesos del rig «Wolf» de los que sale humo, con el tamaño de la bocanada (en alturas del modelo) y las bocanadas vivas de cada uno.
static var HUMO_HUESOS: Array = [["Torso", 0.7, 40], ["Torso3", 0.65, 36], ["Neck2", 0.55, 28], ["Head", 0.55, 30], ["Tail1", 0.5, 24], ["Tail4", 0.42, 22], ["Tail7", 0.34, 18],
	["FrontUpperLeg.L", 0.38, 18], ["FrontUpperLeg.R", 0.38, 18], ["BackUpperLeg.L", 0.42, 18], ["BackUpperLeg.R", 0.42, 18],
	["FF.L", 0.3, 14], ["FF.R", 0.3, 14], ["FFB.L", 0.3, 14], ["FFB.R", 0.3, 14]]
## Vida de cada bocanada (s): cuanto más larga, más humo queda atrás.
static var HUMO_VIDA: float = 1.3
## Velocidad de salida de la bocanada (u/s, hacia arriba con dispersión) y empuje hacia arriba.
static var HUMO_VELOCIDAD: float = 0.12
static var HUMO_SUBIDA: float = 0.08
## Opacidad máxima de la bocanada (negro casi puro, mezcla normal: oscurece lo que hay detrás).
static var HUMO_OPACIDAD: float = 0.85
## Colores de la bocanada (nace, plena, sigue plena, se deshace) y en qué punto de su vida está cada uno (0..1).
static var HUMO_COLORES: Array = [Color(0.02, 0.02, 0.03, 0.0), Color(0.02, 0.02, 0.03, 1.0), Color(0.03, 0.03, 0.04, 1.0), Color(0.05, 0.05, 0.07, 0.0)]
static var HUMO_TIEMPOS: Array = [0.0, 0.1, 0.55, 1.0]

## --- ojos ---
static var OJOS: bool = true
## Posición de cada ojo en el marco del hueso «Head» del rig (medida en los vértices blancos de la textura: X = su derecha, Y = hacia delante, Z = arriba).
static var OJO_IZQ: Vector3 = Vector3(-0.04, 0.097, -0.003)
static var OJO_DER: Vector3 = Vector3(0.04, 0.097, -0.003)
## Radio del ojo (u del modelo a escala 1), color y tamaño del halo (× radio).
static var OJO_RADIO: float = 0.011
static var OJO_COLOR: Color = Color(0.85, 0.95, 1.0)
static var OJO_HALO: float = 4.0

## --- niebla a ras de suelo ---

## Radio de la niebla en ALTURAS del modelo (×0,55 en el juego ≈ 0,72 u).
static var RADIO_ALTURAS: float = 1.3
## Altura de cada lámina sobre los pies, en alturas del modelo (la más alta ≈ 0,08 u: por debajo de la rodilla, no tapa el cuerpo).
static var ALTURAS_CAPAS: Array = [0.03, 0.07, 0.11, 0.15]
## Opacidad máxima en el centro de la lámina baja.
static var OPACIDAD: float = 0.85
## Cada lámina superior lleva esta fracción de la anterior.
static var OPACIDAD_POR_CAPA: float = 0.7
## Negro casi puro (como HUMO_COLORES del humo de pies).
static var COLOR: Color = Color(0.02, 0.02, 0.03)
## u/s a la que deriva el ruido (en coordenadas del MUNDO: el animal arrastra la niebla, no la lleva pegada).
static var VELOCIDAD: float = 0.35
## Repeticiones del ruido por unidad de mundo.
static var ESCALA_RUIDO: float = 2.2
## Fracción del radio donde la opacidad empieza a caer hacia el borde (borde suave, nada de disco recortado).
static var BORDE: float = 0.45
## 1/s con que la niebla sigue al animal (va un pelín rezagada: pesada).
static var SUAVIZADO: float = 12.0
## Distancia (u) en la que la lámina se funde contra lo que tiene detrás (suelo, patas). Con 0,15 (como la niebla del foso) la lámina baja,
## a 1,6 cm del suelo, quedaba casi transparente y la niebla parecía una sombra tenue: tiene que ser menor que la altura de la primera lámina.
static var FUNDIDO: float = 0.025
## Interruptor: false = no se monta.
static var ACTIVA: bool = true

const CODIGO: String = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D profundidad : hint_depth_texture, filter_linear;
uniform vec4 color : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform float alfa = 0.85;
uniform float velocidad = 0.35;
uniform float escala_ruido = 2.2;
uniform float borde = 0.45;
uniform float fundido = 0.025;
varying vec3 pw;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	pw = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Ruido en coordenadas del mundo, dos octavas que derivan en direcciones distintas.
	vec2 base = pw.xz * escala_ruido;
	float n = ruido(base + TIME * velocidad * vec2(1.0, 0.6)) * 0.6 + ruido(base * 2.3 - TIME * velocidad * vec2(0.8, -0.4)) * 0.4;
	float densidad = mix(0.55, 1.0, smoothstep(0.25, 0.75, n));
	// Caida radial hacia el borde de la lamina.
	float dist = length(UV * 2.0 - 1.0);
	float radial = 1.0 - smoothstep(borde, 1.0, dist);
	// Se funde donde toca las patas o el suelo (profundidad de la escena frente a la de la lamina).
	float z_escena = texture(profundidad, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, z_escena, 1.0);
	vec4 v = INV_PROJECTION_MATRIX * ndc;
	v.xyz /= v.w;
	float suave = clamp((VERTEX.z - v.z) / fundido, 0.0, 1.0);
	ALBEDO = color.rgb;
	ALPHA = alfa * densidad * radial * suave;
}
"""

var pj: Node3D = null
var alto: float = 0.55
var capas: Array[MeshInstance3D] = []
var emisores: Array[GPUParticles3D] = []     ## humo del cuerpo (uno por hueso de HUMO_HUESOS que exista, colgado de un BoneAttachment3D)
var ojos: Array[MeshInstance3D] = []         ## los dos ojos (hijos de un BoneAttachment3D del esqueleto)
var cuerpo: Array[MeshInstance3D] = []       ## mallas del animal pintadas de negro
var _sk: Skeleton3D = null
var _huesos: Array[int] = []
var _atadura: BoneAttachment3D = null        ## la de los ojos
var _ataduras: Array[BoneAttachment3D] = []  ## una por emisor de humo
var _mat_negro: StandardMaterial3D = null
var _override_antes: Array[Material] = []    ## el override que tenía cada malla de `cuerpo` antes de pintarla (se devuelve al disiparse)
## 6/11 (Pablo, canouro v2): cuánta niebla hay ahora (1 = entera, 0 = disipada). `disipar` la apaga con un fundido y `rebrotar` la devuelve:
## las láminas bajan su opacidad con ella, el humo de los huesos sale en proporción (`amount_ratio`) y por debajo de la mitad el cuerpo deja de
## ir pintado de negro (se ve el animal: está expuesto, y vuelve a verse el destello de los golpes). Los ojos no cambian.
var densidad: float = 1.0
var _densidad_meta: float = 1.0
var _t_fundido: float = 0.5   ## s que tarda en ir de 0 a 1 (o al revés) la última orden


## Crea la niebla y la cuelga del Pj3D seguido. Devuelve null si ACTIVA es false.
static func poner(p_pj: Node3D, p_alto: float) -> NieblaCanouro3D:
	if not ACTIVA:
		return null
	var n := NieblaCanouro3D.new()
	n.name = "NieblaCanouro3D"
	n.pj = p_pj
	n.alto = p_alto
	p_pj.add_child(n)
	n.montar()
	if n.is_inside_tree():
		n.global_position = p_pj.global_position
	else:
		n.position = p_pj.position
	return n


func _ready() -> void:
	top_level = true


func montar() -> void:
	top_level = true
	var r: float = radio()
	var sh := Shader.new()
	sh.code = CODIGO
	for k in range(ALTURAS_CAPAS.size()):
		var q := QuadMesh.new()
		q.orientation = PlaneMesh.FACE_Y
		q.size = Vector2(2.0 * r, 2.0 * r)
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("color", COLOR)
		mat.set_shader_parameter("alfa", OPACIDAD * pow(OPACIDAD_POR_CAPA, float(k)))
		mat.set_shader_parameter("velocidad", VELOCIDAD)
		mat.set_shader_parameter("escala_ruido", ESCALA_RUIDO)
		mat.set_shader_parameter("borde", BORDE)
		mat.set_shader_parameter("fundido", FUNDIDO)
		q.material = mat
		var mi := MeshInstance3D.new()
		mi.name = "capa%d" % k
		mi.mesh = q
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0.0, float(ALTURAS_CAPAS[k]) * alto, 0.0)
		add_child(mi)
		capas.append(mi)
	_montar_cuerpo()
	_montar_humo()
	_montar_ojos()


## Esqueleto del animal (el Pj3D lo da con `_esqueleto`; si no, se busca).
func _esqueleto() -> Skeleton3D:
	if _sk != null:
		return _sk
	if pj != null and pj.has_method("_esqueleto"):
		_sk = pj.call("_esqueleto") as Skeleton3D
	if _sk == null and pj != null:
		var l: Array[Node] = pj.find_children("*", "Skeleton3D", true, false)
		if not l.is_empty():
			_sk = l[0] as Skeleton3D
	return _sk


## 1. Cuerpo negro sin luz: override en cada malla del animal (no en la sombra de contacto ni en lo nuestro).
func _montar_cuerpo() -> void:
	if not CUERPO_NEGRO or pj == null:
		return
	var modelo: Node = pj.get("_modelo") if "_modelo" in pj else pj
	if modelo == null:
		modelo = pj
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = CUERPO_COLOR
	_mat_negro = mat
	for n in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.name == "sombra_contacto" or mi.get_parent() is BoneAttachment3D:
			continue
		_override_antes.append(mi.material_override)
		mi.material_override = mat
		cuerpo.append(mi)


## 2. Humo del cuerpo: un emisor por hueso, colgado de un BoneAttachment3D (va con el hueso ya modificado por la marcha).
func _montar_humo() -> void:
	var sk: Skeleton3D = _esqueleto()
	if sk == null:
		push_warning("NieblaCanouro3D: el modelo no tiene esqueleto; sin humo del cuerpo ni ojos")
		return
	# Cada emisor cuelga de un BoneAttachment3D del esqueleto: va con el hueso sin ningún retraso (colocarlos a mano desde `_process` o desde
	# `skeleton_updated` los dejaba un fotograma por detrás del animal, 2-8 cm según corriera). Las bocanadas son del MUNDO (`local_coords`
	# false), así que se quedan atrás igual. El tamaño se divide por la escala heredada (Pj3D × esqueleto) para que `tam` sea en u del mundo.
	for h in HUMO_HUESOS:
		var i: int = sk.find_bone(String(h[0]))
		if i < 0:
			continue
		var at := BoneAttachment3D.new()
		at.name = "humo_" + String(h[0]).replace(".", "_")
		sk.add_child(at)
		at.bone_name = String(h[0])          # después de colgarla: antes de estar en el árbol no encuentra el hueso
		var esc: float = maxf(at.global_transform.basis.get_scale().x, 0.0001)
		var e: GPUParticles3D = crear_emisor(float(h[1]) * alto / esc, int(h[2]))
		e.name = "emisor"
		at.add_child(e)
		_huesos.append(i)
		emisores.append(e)
		_ataduras.append(at)


## Un emisor de bocanadas negras de tamaño `tam` (u del mundo) con `n` bocanadas vivas. Mezcla normal: el negro OSCURECE lo que hay detrás.
static func crear_emisor(tam: float, n: int) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.amount = n
	gp.lifetime = HUMO_VIDA
	gp.preprocess = HUMO_VIDA            # nace ya lleno de bocanadas: el canouro no aparece «limpio» el primer segundo
	gp.local_coords = false
	gp.emitting = true
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 5, 8))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 80.0
	pm.initial_velocity_min = HUMO_VELOCIDAD * 0.4
	pm.initial_velocity_max = HUMO_VELOCIDAD
	pm.gravity = Vector3(0.0, HUMO_SUBIDA, 0.0)
	pm.damping_min = 0.3
	pm.damping_max = 0.7
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = tam * 0.25
	pm.scale_min = tam * 0.7
	pm.scale_max = tam * 1.1
	# Crece mientras se deshace.
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.55))
	curva.add_point(Vector2(0.4, 1.0))
	curva.add_point(Vector2(1.0, 1.5))
	var ct := CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(HUMO_TIEMPOS)
	var cols: PackedColorArray = PackedColorArray()
	for c in HUMO_COLORES:
		var cc: Color = c
		cc.a *= HUMO_OPACIDAD
		cols.append(cc)
	g.colors = cols
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -25.0
	pm.angular_velocity_max = 25.0
	gp.process_material = pm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.billboard_keep_scale = true
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = _mancha_densa()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.orientation = PlaneMesh.FACE_Z
	q.material = sm
	gp.draw_pass_1 = q
	return gp


static var _t_densa: Texture2D = null

## Mancha radial más cerrada que `VfxKit3D.mancha()` (alfa 0,45 a mitad de radio: las bocanadas salían GRISES, más claras que el cuerpo):
## con HUMO_MANCHA el alfa se mantiene casi pleno hasta el 55 % del radio y cae en el borde.
static var HUMO_MANCHA: Array = [[0.0, 0.55, 1.0], [1.0, 0.8, 0.0]]

static func _mancha_densa() -> Texture2D:
	if _t_densa == null:
		_t_densa = VfxKit3D._radial(HUMO_MANCHA[0], HUMO_MANCHA[1])
	return _t_densa


## 3. Ojos: dos esferas sin luz con un halo (quad billboard aditivo), colgadas del hueso «Head» con un BoneAttachment3D (siguen a la animación y a la escala).
func _montar_ojos() -> void:
	var sk: Skeleton3D = _esqueleto()
	if not OJOS or sk == null or sk.find_bone("Head") < 0:
		return
	_atadura = BoneAttachment3D.new()
	_atadura.name = "OjosCanouro"
	sk.add_child(_atadura)
	_atadura.bone_name = "Head"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = OJO_COLOR
	mat.render_priority = 10
	var halo := StandardMaterial3D.new()
	halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo.albedo_color = Color(OJO_COLOR.r, OJO_COLOR.g, OJO_COLOR.b, 0.6)
	halo.albedo_texture = VfxKit3D.mancha()
	halo.render_priority = 9
	# OJO_IZQ/OJO_DER y OJO_RADIO están medidos en u del MODELO (Pj3D a escala 1), pero el esqueleto del GLB lleva su propia escala y lo que
	# cuelga de un hueso la hereda: se divide por ella para que el ojo caiga en la cuenca y no por delante del morro.
	var esc_sk: float = sk.global_transform.basis.get_scale().x / maxf(pj.global_transform.basis.get_scale().x, 0.0001)
	if esc_sk < 0.0001:
		esc_sk = 1.0
	for p in [OJO_IZQ, OJO_DER]:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = OJO_RADIO / esc_sk
		s.height = OJO_RADIO * 2.0 / esc_sk
		s.radial_segments = 12
		s.rings = 6
		mi.mesh = s
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = (p as Vector3) / esc_sk
		_atadura.add_child(mi)
		ojos.append(mi)
		var h := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE * OJO_RADIO * OJO_HALO / esc_sk
		h.mesh = q
		h.material_override = halo
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(h)


func radio() -> float:
	return RADIO_ALTURAS * alto


## Apaga todo (el canouro muere): niebla, humo (las bocanadas vivas terminan), ojos. El cuerpo negro se queda: un cadáver negro.
func apagar() -> void:
	visible = false
	for e in emisores:
		e.emitting = false
	if _atadura != null and is_instance_valid(_atadura):
		_atadura.visible = false
	set_process(false)


## Lo que cuelga del esqueleto no se libera con este nodo sino con el Pj3D; si alguien quita la niebla sola, que se lo lleve todo.
func _exit_tree() -> void:
	for a in _ataduras:
		if is_instance_valid(a) and a.get_parent() != null and not a.is_queued_for_deletion():
			a.queue_free()
	if _atadura != null and is_instance_valid(_atadura) and not _atadura.is_queued_for_deletion():
		_atadura.queue_free()


## 6/11: la niebla se disipa (el fuego se la lleva) con un fundido de `t` s. Sigue en el árbol, solo invisible.
func disipar(t: float = 0.6) -> void:
	_densidad_meta = 0.0
	_t_fundido = maxf(t, 0.01)


## 6/11: la niebla vuelve a crecer hasta su densidad entera en `t` s.
func rebrotar(t: float = 1.5) -> void:
	_densidad_meta = 1.0
	_t_fundido = maxf(t, 0.01)


func _aplicar_densidad() -> void:
	for k in range(capas.size()):
		var mat: ShaderMaterial = capas[k].mesh.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("alfa", OPACIDAD * pow(OPACIDAD_POR_CAPA, float(k)) * densidad)
		capas[k].visible = densidad > 0.002
	for e in emisores:
		if is_instance_valid(e):
			e.amount_ratio = densidad
	var negro: bool = densidad >= 0.5
	for k in range(cuerpo.size()):
		if is_instance_valid(cuerpo[k]):
			cuerpo[k].material_override = _mat_negro if negro else _override_antes[k]


func _process(delta: float) -> void:
	if pj == null or not is_instance_valid(pj):
		return
	global_position = global_position.lerp(pj.global_position, clampf(SUAVIZADO * delta, 0.0, 1.0))
	global_rotation = Vector3.ZERO
	if not is_equal_approx(densidad, _densidad_meta):
		densidad = move_toward(densidad, _densidad_meta, delta / _t_fundido)
		_aplicar_densidad()
