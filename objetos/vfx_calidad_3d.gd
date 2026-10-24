class_name VfxCalidad3D
extends RefCounted

## EL COLOR DE LA CALIDAD EN EL MUNDO (24/10, fase 3 del Pulso resonante; PLAN_PULSO_RESONANTE §7: «el color manda en todo» y «desde lejos, un cofre épico o legendario sin abrir echa
## una columna de luz de su color, visible desde la entrada de la sala»). Dos efectos, los dos con el color de `Objetos.CALIDADES`:
##   · `columna_luz`: un cilindro alto de luz aditiva (más fuerte al pie, se desvanece arriba y respira despacio) con un halo en el suelo y motas que suben. La cámara es cenital: la columna se
##     lee como un trazo vertical y el halo del suelo, como un anillo de color, desde cualquier punto de la sala. Se apaga con `apagar` (el cofre se abre).
##   · `motas`: una ráfaga de motas del color (al abrir el cofre, al coger un material).
## La interfaz (marcos, bolsa, avisos) es de otro agente y no se toca aquí: esto solo pinta el mundo.

const ALTO_COLUMNA: float = 6.0          ## u (unas dos casillas y media: se ve por encima de las paredes de la cueva)
const RADIO_COLUMNA: float = 0.42
const ENERGIA_COLUMNA: float = 1.25      ## multiplicador del color (HDR suave: el bloom lo recoge sin quemarlo)
const ALFA_COLUMNA: float = 0.62
const T_APAGAR: float = 0.7              ## s que tarda la columna en apagarse al abrir el cofre
const HALO_ENERGIA: float = 1.6          ## el halo del suelo (BrilloPulso3D.pintar_suelo) con el color de la calidad
const MOTAS_COLUMNA: int = 18
const GRUPO_MOTAS: String = "motas_calidad"   ## grupo de los emisores de motas (las pruebas los cuentan por él: dos nodos con el mismo nombre se renombran solos)
const LUZ_ENERGIA: float = 1.2           ## luz suave del color al pie de la columna
const LUZ_ALCANCE: float = 5.5

const CODIGO_COLUMNA: String = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 color : source_color = vec4(0.7, 0.4, 1.0, 1.0);
uniform float energia = 1.25;
uniform float alfa = 0.62;
uniform float alto = 6.0;
uniform float apagado = 0.0;
varying float h;
void vertex() {
	h = clamp(VERTEX.y / alto + 0.5, 0.0, 1.0);
}
void fragment() {
	float borde = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.2);
	float respira = 0.82 + 0.18 * sin(TIME * 2.0 + h * 5.0);
	float a = pow(1.0 - h, 1.35) * smoothstep(0.0, 0.03, h) * (0.35 + 0.65 * borde) * respira * alfa * (1.0 - apagado);
	ALBEDO = color.rgb * energia;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""
static var _shader_columna: Shader = null
static var _mat_motas: StandardMaterial3D = null


## Pone la columna de luz de `color` en el origen de `padre` (el cofre). Devuelve el nodo raíz de la columna; se apaga con `apagar(raiz)`.
static func columna_luz(padre: Node3D, color: Color) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "ColumnaLuz"
	padre.add_child(raiz)
	if _shader_columna == null:
		_shader_columna = Shader.new()
		_shader_columna.code = CODIGO_COLUMNA
	var cil := CylinderMesh.new()
	cil.top_radius = RADIO_COLUMNA * 0.7
	cil.bottom_radius = RADIO_COLUMNA
	cil.height = ALTO_COLUMNA
	cil.radial_segments = 14
	cil.rings = 1
	cil.cap_top = false
	cil.cap_bottom = false
	var m := ShaderMaterial.new()
	m.shader = _shader_columna
	m.set_shader_parameter("color", Color(color.r, color.g, color.b, 1.0))
	m.set_shader_parameter("energia", ENERGIA_COLUMNA)
	m.set_shader_parameter("alfa", ALFA_COLUMNA)
	m.set_shader_parameter("alto", ALTO_COLUMNA)
	m.set_shader_parameter("apagado", 0.0)
	var mi := MeshInstance3D.new()
	mi.name = "haz"
	mi.mesh = cil
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.0, ALTO_COLUMNA * 0.5, 0.0)
	raiz.add_child(mi)
	if Terreno3D.hay_mundo():
		var halo: MeshInstance3D = BrilloPulso3D.suelo_azul(raiz)
		if halo != null:
			halo.name = "halo"
			BrilloPulso3D.pintar_suelo(halo, color, HALO_ENERGIA / BrilloPulso3D.SUELO_ENERGIA_DESTELLO)
	var luz := OmniLight3D.new()
	luz.name = "luz"
	luz.light_color = color
	luz.light_energy = LUZ_ENERGIA
	luz.omni_range = LUZ_ALCANCE
	luz.shadow_enabled = false
	luz.position = Vector3(0.0, 1.4, 0.0)
	raiz.add_child(luz)
	var suben: GPUParticles3D = motas(raiz, raiz.global_position + Vector3(0.0, 0.3, 0.0), color, MOTAS_COLUMNA, 2.6, 0.075, 0.9, 0.32, true, Vector3.UP, 8.0)
	suben.name = "motas"
	return raiz


## La columna se apaga (el cofre se abre): el haz se desvanece, la luz baja y las motas paran. Se libera sola.
static func apagar(raiz: Variant) -> void:
	if raiz == null or not is_instance_valid(raiz) or not (raiz as Node).is_inside_tree():
		return
	var nodo: Node3D = raiz as Node3D
	var haz: MeshInstance3D = nodo.get_node_or_null("haz") as MeshInstance3D
	var luz: OmniLight3D = nodo.get_node_or_null("luz") as OmniLight3D
	var motas_c: GPUParticles3D = nodo.get_node_or_null("motas") as GPUParticles3D
	if motas_c != null:
		motas_c.emitting = false
	var tw: Tween = nodo.create_tween()
	tw.set_parallel(true)
	if haz != null:
		tw.tween_property(haz.material_override, "shader_parameter/apagado", 1.0, T_APAGAR)
	if luz != null:
		tw.tween_property(luz, "light_energy", 0.0, T_APAGAR)
	tw.chain().tween_callback(nodo.queue_free)


## ¿Sigue encendida? (las pruebas). Sin tipo en el argumento: una columna ya liberada (apagada del todo) también se pregunta, y es que no.
static func encendida(raiz: Variant) -> bool:
	if raiz == null or not is_instance_valid(raiz):
		return false
	var haz: MeshInstance3D = (raiz as Node).get_node_or_null("haz") as MeshInstance3D
	return haz != null and float((haz.material_override as ShaderMaterial).get_shader_parameter("apagado")) < 0.5


## Una ráfaga de motas del color en `pos` (GLOBAL). `continuo`: no se apaga sola (la columna de luz las lleva subiendo).
static func motas(padre: Node3D, pos: Vector3, color: Color, n: int = 26, vida: float = 1.1, tam: float = 0.1, vel: float = 1.8, radio: float = 0.4, continuo: bool = false,
		direccion: Vector3 = Vector3.UP, abanico: float = 55.0) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.name = "MotasCalidad"
	gp.add_to_group(GRUPO_MOTAS)
	gp.amount = n
	gp.lifetime = vida
	gp.one_shot = not continuo
	gp.explosiveness = 0.0 if continuo else 0.85
	gp.local_coords = false
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 8, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radio
	pm.direction = direccion
	pm.spread = abanico
	pm.initial_velocity_min = vel * 0.45
	pm.initial_velocity_max = vel
	pm.gravity = Vector3(0.0, 0.0 if continuo else -1.0, 0.0)
	pm.damping_min = 0.3
	pm.damping_max = 0.9
	pm.scale_min = tam * 0.6
	pm.scale_max = tam * 1.3
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.0))
	curva.add_point(Vector2(0.15, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([color.lightened(0.55), color, Color(color.r, color.g, color.b, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	gp.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.orientation = PlaneMesh.FACE_Z
	q.material = _material_motas()
	gp.draw_pass_1 = q
	padre.add_child(gp)
	gp.global_position = pos
	gp.emitting = true
	if not continuo:
		var tw: Tween = gp.create_tween()
		tw.tween_interval(vida + 0.3)
		tw.tween_callback(gp.queue_free)
	return gp


static func _material_motas() -> StandardMaterial3D:
	if _mat_motas == null:
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		sm.billboard_keep_scale = true
		sm.vertex_color_use_as_albedo = true
		sm.albedo_texture = VfxKit3D.mancha()
		sm.albedo_color = Color(1.8, 1.8, 1.8)                  # HDR: el bloom las recoge; el color lo pone la rampa de la partícula
		_mat_motas = sm
	return _mat_motas
