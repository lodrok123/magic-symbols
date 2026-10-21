class_name VfxHielo
extends ElementoVfx

## HIELO del kit luminoso (19/10, VFX_RAYO_HIELO P5). Rampa azul hondo → hielo claro → blanco; no aditivo (copos que se ven sobre fondo
## claro), casi quieto (`velocidad` × 0,15) y facetado. Los cristales (forma `cristal` de Formas3D) y la escarcha los pone `VfxEstado3D`.
##
## MODELOS DE MESHY (22/10, `arte/meshy/PROMPTS_ELEMENTOS.md` §2): piezas con los MISMOS ids que los GLB de `arte/meshy/piezas/`, como `VfxTierra`:
##   esquirla_hielo          proyectil · 0,45 u de largo, origen en su centro, punta a +Z
##   racimo_hielo_p/m/g      impacto, barrera que brota, hielo que atrapa · 0,4 / 0,8 / 1,4 u de alto, origen en el centro de la base
##   placa_hielo_rota        placa del agua helada al romperse (entera: 2,2 × 0,12 × 2,2 u) y sus 4 trozos `placa_hielo_rota_0..3` (mismo origen: encajan)
##   pincho_escarcha_0..1    escarcha que sale al helar el suelo · 0,15 × 0,4 u, origen en la base
## `pieza(id)` da el modelo (GLB horneado a la medida con `ModeloElemento`, con el material de hielo de abajo) o, con `usar_modelos = false` o sin GLB,
## una PRIMITIVA: el cristal facetado de `Formas3D` a la misma medida. `VfxHielo.usar_modelos = false` además devuelve el dibujo de hielo de ANTES de los modelos
## (la bola del kit en vuelo y en volumen, sin impacto): lo mira `VfxElemento3D`. Ver `activo()`.
##
## MATERIAL: los GLB son azul saturado y opacos. `material_modelo` los aclara a blanco azulado con la textura del GLB casi desaturada y los hace translúcidos con
## fresnel (más opacos en el borde, más claros al centro) y un poco de luz propia; sin brillos pintados. No se anima: el hielo se funde por escala.
##
## QUÉ DIBUJA CADA MOMENTO (todo es visual: no cambia lógica ni colisiones):
##   · VUELO     `proyectil`: una esquirla orientada a donde va (punta delante) que gira despacio sobre su eje y copos que se quedan atrás.
##   · IMPACTO   `impacto`: un racimo mediano que brota donde choca, racimos pequeños y pinchos de escarcha alrededor; se quedan `T_REPOSO` s y se funden.
##   · QUIETAS   `emerger`: racimos grandes que BROTAN del suelo en la barrera (círculo), el pulso (círculo grande) o la esfera (uno central y tres pequeños).
##   · REACCIÓN  `escarcha_modelos`: lo que se congela (goblin atrapado): racimos pequeños y pinchos de escarcha alrededor del punto.
##   · AGUA      `placa_rota`: la placa helada del agua al romperse (4 trozos que se separan y se hunden). Todavía NO la llama nadie: el agua helada solo
##               suelta una onda (`AguaSim3D.EVENTO_HIELO_ROTO`); la función queda preparada para engancharla donde el agua pierda un trozo de hielo.

const MEDIDA: Dictionary = {
	"esquirla_hielo": Vector3(0.12, 0.12, 0.45),
	"racimo_hielo_p": Vector3(0.3, 0.4, 0.3), "racimo_hielo_m": Vector3(0.55, 0.8, 0.55), "racimo_hielo_g": Vector3(0.9, 1.4, 0.9),
	"placa_hielo_rota": Vector3(2.2, 0.12, 2.2),
	"placa_hielo_rota_0": Vector3(2.2, 0.12, 2.2), "placa_hielo_rota_1": Vector3(2.2, 0.12, 2.2), "placa_hielo_rota_2": Vector3(2.2, 0.12, 2.2), "placa_hielo_rota_3": Vector3(2.2, 0.12, 2.2),
	"pincho_escarcha_0": Vector3(0.15, 0.4, 0.15), "pincho_escarcha_1": Vector3(0.15, 0.4, 0.15),
}
## Centro (x, z) de cada trozo de la placa dentro de la entera, en unidades de la LÁMINA (sacado de las cajas de los GLB: la unión de los cuatro mide lo que la entera).
const TROZOS_CENTRO: Array = [Vector2(0.20, -0.01), Vector2(0.27, -0.12), Vector2(0.29, 0.08), Vector2(0.34, -0.08)]
const N_PINCHOS: int = 2
const N_TROZOS: int = 4

## VUELO
const ESQUIRLA_LARGO_K: float = 3.2        ## largo de la esquirla = r_u · esto (mínimo el de `MEDIDA`)
const ESQUIRLA_GIRO: float = 3.0           ## rad/s sobre su eje
const COPOS_VUELO: int = 10

## IMPACTO
const IMPACTO_PEQUENOS: int = 3
const IMPACTO_PINCHOS: int = 5
const T_BROTA: float = 0.3                 ## s que tarda un cristal en brotar
const T_REPOSO: float = 1.6                ## s que se queda el impacto antes de fundirse
const T_FUNDE: float = 0.6
const SUELO_FALTA: float = 0.9

## QUIETAS
const ALTO_G: float = 1.4                  ## alto del racimo grande: la escala crece con el alto del hechizo (límites abajo)
const ESCALA_MIN: float = 0.7
const ESCALA_MAX: float = 2.0
const MAX_RACIMOS: int = 16
const RETARDO_MAX: float = 0.3
const ANILLO_BARRERA: float = 1.3
const ANILLO_PULSO: float = 3.0
const ANILLO_MAX: float = 4.0
const PEQUENOS_ESFERA: int = 3

## REACCIÓN
const ESCARCHA_PINCHOS: int = 6
const ESCARCHA_RACIMOS: int = 2
const T_ESCARCHA: float = 1.8

## PLACA ROTA
const T_PLACA_SEPARA: float = 0.35
const T_PLACA_REPOSO: float = 1.2
const T_PLACA_HUNDE: float = 0.7

static var usar_modelos: bool = true
static var _modelos: Dictionary = {}       ## id -> Mesh o null (modelo horneado; las pruebas pueden poner uno)
static var _prim: Dictionary = {}          ## id -> ArrayMesh (primitivas)
static var _mats: Dictionary = {}          ## textura (instance id) -> material de hielo


## Gira sobre el eje Z local (la esquirla rueda sobre su eje de avance). Un nodo con _process: muere con su padre.
class Giro extends Node3D:
	var w: float = 3.0
	func _process(delta: float) -> void:
		rotate_object_local(Vector3.FORWARD, w * delta)


func rampa() -> Array:
	return [[0.0, Color(0.16, 0.34, 0.74)], [0.35, Color(0.45, 0.72, 0.95)], [0.7, Color(0.78, 0.92, 1.0)], [1.0, Color(1.0, 1.0, 1.0)]]


func perfil() -> Dictionary:
	return {"luz": Color(0.6, 0.85, 1.0), "charco": Color(0.5, 0.78, 1.0), "aro": Color(0.8, 0.94, 1.0),
		"particula": [Color(1.0, 1.0, 1.0, 1.0), Color(0.7, 0.9, 1.0, 1.0), Color(0.45, 0.7, 1.0, 0.0)],
		"particula_aditiva": false, "particula_albedo": Color(1.0, 1.0, 1.0, 1.0), "marca": "escarcha",
		"mult": {"velocidad": 0.15, "suave": 0.6, "ondula": 0.2}}


# ---------------------------------------------------------------------------------------------------------------------------------
# Piezas: modelo de Meshy o primitiva facetada
# ---------------------------------------------------------------------------------------------------------------------------------

static func ids() -> PackedStringArray:
	return PackedStringArray(MEDIDA.keys())


## ¿Se dibuja el hielo con los modelos? (el interruptor). Con false, `VfxElemento3D` vuelve al hielo del kit de antes.
static func activo() -> bool:
	return usar_modelos


## ¿Hay modelo de Meshy para esta pieza (y está encendido el interruptor)?
static func hay_modelo(id: String) -> bool:
	return usar_modelos and _modelo(id) != null


static func _origen_base(id: String) -> bool:
	return id != "esquirla_hielo"


static func _giro(id: String) -> Basis:
	return Basis(Vector3.RIGHT, PI * 0.5) if id == "esquirla_hielo" else Basis.IDENTITY      # la esquirla viene vertical: su punta (+Y) pasa a +Z


static func _ajuste(id: String) -> String:
	if id.begins_with("placa_"):
		return "caja"
	if id == "esquirla_hielo":
		return "mayor"
	return "alto"


## La pieza `id` como MeshInstance3D con el origen puesto y a su medida (`MEDIDA`). Marca `modelo` (meta) si salió de un GLB.
static func pieza(id: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = id
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m: Mesh = _modelo(id) if usar_modelos else null
	if m != null:
		mi.mesh = m
		mi.material_override = material_modelo(m)
		mi.set_meta("modelo", true)
		return mi
	mi.mesh = _primitiva(id)
	mi.material_override = Formas3D.material_tinte(Color(0.9, 0.96, 1.0), false, "cristal")
	mi.set_meta("modelo", false)
	return mi


## El Mesh del modelo horneado (o null si no hay GLB). Se cachea.
static func _modelo(id: String) -> Mesh:
	if _modelos.has(id):
		return _modelos[id]
	var m: Mesh = null
	var med: Vector3 = MEDIDA.get(id, Vector3.ONE)
	if id.begins_with("placa_hielo_rota_"):
		m = _trozo(int(id.substr(id.length() - 1)))
	else:
		var suelto: Mesh = ModeloElemento.malla_glb(id)
		if suelto != null:
			m = ModeloElemento.hornear(suelto, med, _ajuste(id), _origen_base(id), _giro(id))
	_modelos[id] = m
	return m


## Un trozo de la placa: se hornea con la escala de la ENTERA (para que encajen) y desplazado a su sitio dentro de ella.
static func _trozo(i: int) -> Mesh:
	var entera: Mesh = ModeloElemento.malla_glb("placa_hielo_rota")
	var suelto: Mesh = ModeloElemento.malla_glb("placa_hielo_rota_%d" % i)
	if entera == null or suelto == null:
		return null
	var ref: Vector3 = ModeloElemento.limites(entera).size
	var c: Vector2 = TROZOS_CENTRO[i] - _centro_union()
	return ModeloElemento.hornear(suelto, MEDIDA["placa_hielo_rota"], "caja", true, Basis.IDENTITY, ref, Vector3(c.x, 0.0, c.y))


## Centro (x, z) de la unión de los cuatro trozos en la lámina, = el de la placa entera.
static func _centro_union() -> Vector2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in range(N_TROZOS):
		var suelto: Mesh = ModeloElemento.malla_glb("placa_hielo_rota_%d" % i)
		if suelto == null:
			return Vector2.ZERO
		var b: AABB = ModeloElemento.limites(suelto)
		var c: Vector2 = TROZOS_CENTRO[i]
		lo = lo.min(c - Vector2(b.size.x, b.size.z) * 0.5)
		hi = hi.max(c + Vector2(b.size.x, b.size.z) * 0.5)
	return (lo + hi) * 0.5


## Desplazamiento (x, z) del trozo `i` respecto al centro de la placa entera, en unidades de JUEGO (lo que sale ya dentro de la malla horneada).
static func trozo_desplazamiento(i: int) -> Vector2:
	var entera: Mesh = ModeloElemento.malla_glb("placa_hielo_rota")
	if entera == null:
		return Vector2.ZERO
	var ref: Vector3 = ModeloElemento.limites(entera).size
	var s: Vector3 = ModeloElemento.escala_de(ref, MEDIDA["placa_hielo_rota"], "caja")
	var c: Vector2 = TROZOS_CENTRO[i] - _centro_union()
	return Vector2(c.x * s.x, c.y * s.z)


## Primitiva: el cristal facetado de Formas3D (base en y = 0, punta arriba) a la medida; la placa, losas planas.
static func _primitiva(id: String) -> ArrayMesh:
	if _prim.has(id):
		return _prim[id]
	var med: Vector3 = MEDIDA.get(id, Vector3.ONE)
	var m: ArrayMesh = null
	if id.begins_with("placa_hielo_rota"):
		var b := BoxMesh.new()
		if id == "placa_hielo_rota":
			b.size = med
			m = ModeloElemento.hornear(_como_array(b), med, "caja", true)
		else:
			var i: int = int(id.substr(id.length() - 1))
			var d := Vector3(1.0 if i % 2 == 1 else -1.0, 0.0, 1.0 if i >= 2 else -1.0) * med.x * 0.25
			b.size = Vector3(med.x * 0.5, med.y, med.z * 0.5)
			m = ModeloElemento.hornear(_como_array(b), b.size, "caja", true, Basis.IDENTITY, Vector3.ZERO, d)
	else:
		m = ModeloElemento.hornear(Formas3D.malla("cristal"), med, _ajuste(id), _origen_base(id), _giro(id))
	_prim[id] = m
	return m


## Una malla primitiva (BoxMesh...) como ArrayMesh de una superficie.
static func _como_array(p: PrimitiveMesh) -> ArrayMesh:
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, p.get_mesh_arrays())
	return am


## Material de hielo para un modelo: la textura del GLB casi sin color, aclarada a blanco azulado, translúcida con fresnel y un poco de luz propia.
static func material_modelo(m: Mesh) -> ShaderMaterial:
	var src: Material = m.surface_get_material(0) if m != null and m.get_surface_count() > 0 else null
	var tex: Texture2D = (src as StandardMaterial3D).albedo_texture if src is StandardMaterial3D else null
	var clave: int = tex.get_instance_id() if tex != null else 0
	if _mats.has(clave):
		return _mats[clave]
	var sm := ShaderMaterial.new()
	sm.shader = _shader()
	if tex != null:
		sm.set_shader_parameter("tex", tex)
	_mats[clave] = sm
	return sm


static var _sh: Shader = null


static func _shader() -> Shader:
	if _sh == null:
		_sh = Shader.new()
		_sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tinte : source_color = vec3(0.80, 0.92, 1.0);
uniform float satura = 0.2;            // cuánto del azul saturado del GLB se conserva
uniform float aclara = 0.5;            // cuánto se lleva hacia el blanco
uniform float alfa_centro = 0.6;
uniform float alfa_borde = 0.95;
uniform float luz_propia = 0.12;
void fragment() {
	vec3 t = texture(tex, UV).rgb;
	float l = dot(t, vec3(0.299, 0.587, 0.114));
	vec3 c = mix(vec3(l), t, satura);
	c = mix(c, tinte, 0.55);
	c = mix(c, vec3(1.0), aclara * (0.4 + 0.6 * l));
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = c;
	ROUGHNESS = 0.18;
	SPECULAR = 0.5;
	EMISSION = tinte * luz_propia + vec3(0.55, 0.82, 1.0) * f * 0.3;
	ALPHA = mix(alfa_centro, alfa_borde, f);
}
"""
	return _sh


# ---------------------------------------------------------------------------------------------------------------------------------
# VUELO
# ---------------------------------------------------------------------------------------------------------------------------------

## Dibuja el proyectil de hielo en `seg`: una esquirla con la punta hacia `d` (rueda sobre su eje) y copos detrás. `r_u` = la caja de golpe. Lo llama
## VfxElemento3D con `VfxKit3D.elemento` ya puesto a «hielo». Devuelve la esquirla.
static func proyectil(seg: Node3D, d: Vector3, r_u: float) -> MeshInstance3D:
	var giro := Giro.new()
	giro.name = "EsquirlaGiro"
	giro.w = ESQUIRLA_GIRO
	var dir: Vector3 = d.normalized() if d.length() > 0.001 else Vector3.RIGHT
	var arriba: Vector3 = Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	giro.basis = Basis.looking_at(-dir, arriba)         # -Z mira contra `dir`: la +Z de la esquirla (su punta) queda hacia donde va
	seg.add_child(giro)
	var mi: MeshInstance3D = pieza("esquirla_hielo")
	var largo: float = maxf(r_u * ESQUIRLA_LARGO_K, (MEDIDA["esquirla_hielo"] as Vector3).z)
	mi.scale = Vector3.ONE * (largo / (MEDIDA["esquirla_hielo"] as Vector3).z)
	giro.add_child(mi)
	VfxKit3D.particulas(seg, Vector3.ZERO, COPOS_VUELO, 0.8, 0.1, 0.5, false, true, r_u * 0.7, -0.5, Vector3.UP, 180.0)
	return mi


# ---------------------------------------------------------------------------------------------------------------------------------
# IMPACTO
# ---------------------------------------------------------------------------------------------------------------------------------

## El hielo choca en `pos` (`suelo` = y del suelo; NAN = sin dato): un racimo mediano brota, `IMPACTO_PEQUENOS` pequeños y `IMPACTO_PINCHOS` pinchos de escarcha
## alrededor; se quedan `T_REPOSO` s y se funden. `esc` = tamaño del impacto. Devuelve las piezas.
static func impacto(mundo: Node, pos: Vector3, esc: float, suelo: float = NAN) -> Array:
	var res: Array = []
	if mundo == null or not is_instance_valid(mundo) or not (mundo is Node3D):
		return res
	var y: float = suelo if not is_nan(suelo) else pos.y - SUELO_FALTA
	var k: float = clampf(esc, 0.6, 2.0)
	var base := Vector3(pos.x, y, pos.z)
	res.append(_brotar(mundo as Node3D, "racimo_hielo_m", base, k, randf() * TAU, 0.0, T_REPOSO))
	var a0: float = randf() * TAU
	for i in range(IMPACTO_PEQUENOS):
		var a: float = a0 + TAU * float(i) / float(IMPACTO_PEQUENOS) + randf_range(-0.3, 0.3)
		res.append(_brotar(mundo as Node3D, "racimo_hielo_p", base + Vector3(cos(a), 0.0, sin(a)) * 0.45 * k, k, randf() * TAU, randf() * 0.1, T_REPOSO * randf_range(0.85, 1.1)))
	for i in range(IMPACTO_PINCHOS):
		var a: float = a0 + TAU * (float(i) + 0.5) / float(IMPACTO_PINCHOS) + randf_range(-0.25, 0.25)
		res.append(_brotar(mundo as Node3D, "pincho_escarcha_%d" % (i % N_PINCHOS), base + Vector3(cos(a), 0.0, sin(a)) * randf_range(0.7, 0.95) * k, k, randf() * TAU, randf() * 0.15, T_REPOSO * randf_range(0.8, 1.05)))
	return res


## Un cristal `id` que brota del suelo en `base` (escala `k`), espera `reposo` s y se funde (se encoge y se hunde). Se libera solo.
static func _brotar(padre: Node3D, id: String, base: Vector3, k: float, giro_y: float, retardo: float, reposo: float, inclina: float = 0.12) -> MeshInstance3D:
	var m: MeshInstance3D = pieza(id)
	m.name = "%s_%d" % [id, padre.get_child_count()]
	m.position = base - Vector3(0.0, 0.3 * k, 0.0)
	m.rotation = Vector3(randf_range(-inclina, inclina), giro_y, randf_range(-inclina, inclina))
	m.scale = Vector3.ONE * k * 0.2
	padre.add_child(m)
	var tw: Tween = m.create_tween()
	tw.tween_interval(retardo)
	tw.tween_property(m, "position:y", base.y, T_BROTA).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "scale", Vector3.ONE * k, T_BROTA).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(reposo)
	tw.tween_property(m, "scale", Vector3.ONE * k * 0.1, T_FUNDE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(m, "position:y", base.y - 0.15 * k, T_FUNDE)
	tw.tween_callback(m.queue_free)
	return m


# ---------------------------------------------------------------------------------------------------------------------------------
# FORMAS QUIETAS: racimos que brotan
# ---------------------------------------------------------------------------------------------------------------------------------

## Monta en `raiz` (top_level, en coordenadas de mundo) los racimos de un volumen de hielo con los pies en `pie`: «esfera» → uno grande central y `PEQUENOS_ESFERA`
## pequeños alrededor; «barrera» → un círculo de racimos grandes (r_u · ANILLO_BARRERA); «pulso» → un círculo grande (r_u · ANILLO_PULSO). Cada racimo brota con
## un pequeño rebote, aguanta hasta casi `vida` y se funde. Devuelve los racimos.
static func emerger(raiz: Node3D, pie: Vector3, r_u: float, alto_u: float, vida: float, forma: String, _esc: float) -> Array:
	var res: Array = []
	var k: float = clampf(alto_u / ALTO_G, ESCALA_MIN, ESCALA_MAX)
	var ancho: float = (MEDIDA["racimo_hielo_g"] as Vector3).x * k
	var puestos: Array = []
	if forma == "esfera":
		puestos.append(Vector2.ZERO)
	else:
		var radio: float = minf(r_u * (ANILLO_PULSO if forma == "pulso" else ANILLO_BARRERA), ANILLO_MAX)
		var n: int = clampi(ceili(TAU * radio / (ancho * 0.9)), 5, 14)
		var a0: float = randf() * TAU
		for i in range(n):
			var a: float = a0 + TAU * float(i) / float(n)
			puestos.append(Vector2(cos(a), sin(a)) * radio)
	for xz in puestos:
		if res.size() >= MAX_RACIMOS:
			break
		var base := Vector3(pie.x + (xz as Vector2).x, pie.y, pie.z + (xz as Vector2).y)
		var retardo: float = randf() * RETARDO_MAX
		res.append(_brotar(raiz, "racimo_hielo_g", base, k * randf_range(0.9, 1.1), randf() * TAU, retardo, maxf(vida - retardo - T_BROTA - T_FUNDE, 0.1)))
	if forma == "esfera":
		var rp: float = maxf(r_u, 0.4) * 1.2 + ancho * 0.4
		for i in range(PEQUENOS_ESFERA):
			var a: float = TAU * (float(i) + randf_range(-0.2, 0.2)) / float(PEQUENOS_ESFERA)
			var retardo: float = 0.1 + randf() * RETARDO_MAX
			res.append(_brotar(raiz, "racimo_hielo_p", pie + Vector3(cos(a), 0.0, sin(a)) * rp, k, randf() * TAU, retardo, maxf(vida - retardo - T_BROTA - T_FUNDE, 0.1)))
	return res


# ---------------------------------------------------------------------------------------------------------------------------------
# REACCIÓN: lo que se congela
# ---------------------------------------------------------------------------------------------------------------------------------

## Algo se congela en `punto` (pies; `suelo` = y del suelo si se conoce): `ESCARCHA_RACIMOS` racimos pequeños y `ESCARCHA_PINCHOS` pinchos de escarcha
## alrededor, que brotan, duran `T_ESCARCHA` s y se funden. `esc` = tamaño relativo. Devuelve las piezas.
static func escarcha_modelos(padre: Node3D, punto: Vector3, esc: float = 1.0, suelo: float = NAN) -> Array:
	var res: Array = []
	if padre == null or not is_instance_valid(padre):
		return res
	var y: float = suelo if not is_nan(suelo) else punto.y
	var base := Vector3(punto.x, y, punto.z)
	var k: float = clampf(esc, 0.5, 2.0)
	var a0: float = randf() * TAU
	for i in range(ESCARCHA_RACIMOS):
		var a: float = a0 + PI * float(i) + randf_range(-0.4, 0.4)
		res.append(_brotar(padre, "racimo_hielo_p", base + Vector3(cos(a), 0.0, sin(a)) * 0.38 * k, k, randf() * TAU, randf() * 0.1, T_ESCARCHA))
	for i in range(ESCARCHA_PINCHOS):
		var a: float = a0 + TAU * (float(i) + 0.5) / float(ESCARCHA_PINCHOS) + randf_range(-0.2, 0.2)
		res.append(_brotar(padre, "pincho_escarcha_%d" % (i % N_PINCHOS), base + Vector3(cos(a), 0.0, sin(a)) * randf_range(0.3, 0.6) * k, k, randf() * TAU, randf() * 0.2, T_ESCARCHA * randf_range(0.8, 1.1)))
	return res


## Y del suelo bajo `punto` (rayo hacia abajo en el mundo físico de `nodo`) o `punto.y` si no hay.
static func suelo_bajo(nodo: Node3D, punto: Vector3) -> float:
	if nodo != null and is_instance_valid(nodo) and nodo.is_inside_tree():
		var w: World3D = nodo.get_world_3d()
		if w != null:
			var q := PhysicsRayQueryParameters3D.create(punto + Vector3.UP * 0.4, punto + Vector3.DOWN * 3.0)
			var r: Dictionary = w.direct_space_state.intersect_ray(q)
			if not r.is_empty():
				return (r["position"] as Vector3).y
	return punto.y


# ---------------------------------------------------------------------------------------------------------------------------------
# AGUA: la placa helada que se rompe
# ---------------------------------------------------------------------------------------------------------------------------------

## La placa de hielo de una casilla (`centro` = su centro, `y` = nivel del hielo) se rompe: los cuatro trozos (ya en su sitio, mismo origen) se separan
## hacia fuera, se ladean y se hunden. `esc` = 1 para una casilla de 2,2 u. Se libera sola. Devuelve la raíz. PREPARADA: nadie la llama todavía (ver cabecera).
static func placa_rota(mundo: Node, centro: Vector3, esc: float = 1.0) -> Node3D:
	if mundo == null or not is_instance_valid(mundo) or not (mundo is Node3D):
		return null
	var raiz := Node3D.new()
	raiz.name = "PlacaRota"
	raiz.position = centro
	raiz.scale = Vector3.ONE * esc
	(mundo as Node3D).add_child(raiz)
	for i in range(N_TROZOS):
		var t: MeshInstance3D = pieza("placa_hielo_rota_%d" % i)
		raiz.add_child(t)
		var d: Vector2 = trozo_desplazamiento(i) if hay_modelo(t.name) else Vector2(1.0 if i % 2 == 1 else -1.0, 1.0 if i >= 2 else -1.0) * 0.55
		var fuera := Vector3(d.x, 0.0, d.y).normalized() if d.length() > 0.01 else Vector3(cos(float(i) * 1.6), 0.0, sin(float(i) * 1.6))
		var tw: Tween = t.create_tween()
		tw.tween_property(t, "position", fuera * 0.18 + Vector3(0.0, -0.03, 0.0), T_PLACA_SEPARA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(t, "rotation", Vector3(randf_range(-0.18, 0.18), randf_range(-0.1, 0.1), randf_range(-0.18, 0.18)), T_PLACA_SEPARA)
		tw.tween_interval(T_PLACA_REPOSO)
		tw.tween_property(t, "position:y", -0.25, T_PLACA_HUNDE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t, "scale", Vector3.ONE * 0.6, T_PLACA_HUNDE)
	if raiz.is_inside_tree():
		raiz.get_tree().create_timer(T_PLACA_SEPARA + T_PLACA_REPOSO + T_PLACA_HUNDE + 0.2, false).timeout.connect(raiz.queue_free)
	return raiz
