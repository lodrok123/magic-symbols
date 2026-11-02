extends RefCounted

## Fabrica de sprites de Le Lu recoloreados con la rampa de la bola (lelu_sprite.gdshaderinc). Se usa con `const SpriteToy = preload(...)` (sin class_name para no depender de la
## caché de clases). Cada sprite es un MeshInstance3D con un QuadMesh de 1 m y su ShaderMaterial; el tamaño se da con `scale` del nodo (así el destello puede crecer sin tocar la malla).
##   TEX_*  : texturas de assets/vfx/lelu_noise/ (licencia libre, readme.txt) y para qué sirve cada una.

const DIR: String = "res://presentacion/vfx/toy/"
const TEX: String = "res://assets/vfx/lelu_noise/"
const SH_MEZCLA: String = DIR + "lelu_sprite_mix.gdshader"
const SH_MEZCLA_ND: String = DIR + "lelu_sprite_mix_nd.gdshader"
const SH_ADITIVO: String = DIR + "lelu_sprite_add.gdshader"
const SH_BRIZNAS: String = DIR + "briznas_toy.gdshader"
const T_DESTELLO: String = "T_VFX_hit22.jpg"             ## estrella de golpe de 8 puntas: el destello del primer instante
const T_ESTALLIDO: String = "T_VFX_Ex1d.jpg"            ## explosión cartoon (picos, aro, gotas): impacto A
const T_FLIPBOOK: String = "T_fire_flipbook4_sm.png"    ## bola de fuego que se expande (5×5; solo se usan los fotogramas de fuego): impacto B
const T_REMOLINO: String = "T_VFX_Spiral07.jpg"         ## remolino que gira: la carga
const T_BRIZNA: String = "T_Windstreak3.png"            ## gota de llama alargada (alfa): briznas que convergen en la carga
const T_DESHACER: String = "T_VFX_exp_dissapear.png"    ## remolino suave: el fin sin choque, se deshace girando
const T_MANCHA: String = "T_VFX_CircleFit1.png"         ## disco suave: la mancha de calor del suelo
const FOTOGRAMAS_FUEGO: int = 15                         ## del flipbook solo los fotogramas 0..14 (las dos últimas filas acaban en humo gris/negro y no se usan)

enum Modo { MEZCLA, MEZCLA_SIN_PROF, ADITIVO }


## Un quad de 1 m con el sprite. `plano` = true: tumbado en el plano XZ del nodo (se orienta con la normal de la superficie); false: billboard.
static func crear(nombre: String, textura: String, modo: int, plano: bool, params: Dictionary = {}, prioridad: int = 0) -> MeshInstance3D:
	FuegoToy._rampas()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	if plano:
		q.orientation = PlaneMesh.FACE_Y
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load([SH_MEZCLA, SH_MEZCLA_ND, SH_ADITIVO][modo])
	m.render_priority = prioridad
	m.set_shader_parameter("tex", load(TEX + textura))
	m.set_shader_parameter("rampa", FuegoToy._rampa_bola)
	m.set_shader_parameter("billboard", 0 if plano else 1)
	for k in params:
		m.set_shader_parameter(k, params[k])
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func mat(mi: MeshInstance3D) -> ShaderMaterial:
	return mi.material_override as ShaderMaterial


# ------------------------------------------------------------------ chispas con trazo (impacto y carga) ------------------------------------------------------------------
## Un MultiMesh de `cantidad` quads de chispa (chispa_impacto.gdshader, rampa de la bola): lo mueve la CPU con `poner_chispa`, así que no es un GPUParticles3D (no cuenta en el presupuesto de
## partículas) y se puede comprobar su posición y dirección en las pruebas.
const SH_CHISPAS: String = DIR + "chispa_impacto.gdshader"


static func chispas_mm(nombre: String, cantidad: int, brillo: float = 1.4) -> MultiMeshInstance3D:
	FuegoToy._rampas()
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = cantidad
	for i in cantidad:
		poner_chispa(mm, i, Vector3.ZERO, Vector3.UP, 0.0, 0.0, 0.0, 0.0, false)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_CHISPAS)
	m.render_priority = 5
	m.set_shader_parameter("rampa", FuegoToy._rampa_bola)
	m.set_shader_parameter("brillo", brillo)
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nombre
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -12.0, Vector3.ONE * 24.0)
	return mi


## Pone la chispa `i`: `pos` y `dir` (unitaria, hacia donde va) en el espacio del MultiMeshInstance3D, `largo` (m) del trazo, `ancho` (m), `calor` 0..1 (1 blanco-amarillo), `alfa` 0..1.
static func poner_chispa(mm: MultiMesh, i: int, pos: Vector3, dir: Vector3, largo: float, ancho: float, calor: float, alfa: float, brasa: bool) -> Transform3D:
	var y: Vector3 = dir.normalized() if dir.length() > 0.0001 else Vector3.UP
	var x: Vector3 = y.cross(Vector3.FORWARD)
	if x.length() < 0.001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z: Vector3 = x.cross(y).normalized()
	var vivo: bool = alfa > 0.001 and ancho > 0.0
	var w: float = ancho if vivo else 0.0
	var l: float = (maxf(largo, ancho) if not brasa else ancho) if vivo else 0.0
	var tr: Transform3D = Transform3D(Basis(x * w, y * l, z * w), pos)
	mm.set_instance_transform(i, tr)
	mm.set_instance_custom_data(i, Color(clampf(calor, 0.0, 1.0), clampf(alfa, 0.0, 1.0), 1.0 if brasa else 0.0, 0.0))
	return tr
