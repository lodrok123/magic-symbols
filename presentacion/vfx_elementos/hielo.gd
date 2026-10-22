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
##   · AGUA      `placa_rota`: la placa helada del agua al romperse (4 trozos que se separan y se hunden). La llama `VfxElemento3D` al oír
##               `Mundo3D.impacto(punto, "hielo_roto", casilla)`, que avisa `Lanzador3D._hielo_cambio` cuando una casilla pierde su hielo.
##   · VUELO     (nota) el proyectil de hielo es la esquirla; con `proyectil_esquirla = false` vuelve el cometa del kit.
##   · RAYO      `rayo(padre, desde, hasta, dura, esc, suelo)`: haz de cristal (cilindros con el MISMO shader translúcido y la textura de la esquirla, estirada y
##               corriendo a lo largo), esquirlas pequeñas que lo acompañan y racimos p + pinchos de escarcha donde da. Lo llama `Vfx3D._chorro_forma` (línea sola de hielo).

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

## HIELO TEXTURA (material del hielo del juego)
const HIELO_TILE_RECT: Rect2 = Rect2(258.0 / 2048.0, 1710.0 / 2048.0, 204.0 / 2048.0, 204.0 / 2048.0)   ## el panel de cristales de la compuerta dentro de la hoja de 2048 px de puzle_terrain
const HIELO_TILE_U: float = 0.6            ## u de la pieza que cubre UNA repetición del panel (triplanar en coordenadas de objeto)
const HIELO_MEZCLA_TRI: float = 0.7        ## cuánto manda el panel de la compuerta sobre la textura propia del GLB
const HIELO_ALFA: float = 0.82             ## translucidez (la de la compuerta); el borde sube a HIELO_ALFA_BORDE
const HIELO_ALFA_BORDE: float = 0.95
const HIELO_LUZ: float = 0.2               ## luz propia fría (la de la compuerta)
const RAYO_NUCLEO_ACLARA: float = 0.3      ## cuánto se aclara el corazón del haz hacia el blanco (con la textura del juego)
const HIELO_EMISION: Color = Color(0.45, 0.8, 1.0)
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

## RAYO (haz de cristal)
const RAYO_RADIO: float = 0.22            ## radio del haz en el extremo lejano (u, × esc); en la mano es RAYO_RADIO_MANO_K veces eso
const RAYO_RADIO_MANO_K: float = 0.35
const RAYO_NUCLEO_K: float = 0.45          ## el corazón claro mide esto del radio del haz
const RAYO_TEXEL: float = 0.6              ## largo (u) del haz que cubre UNA repetición de la textura de la esquirla
const RAYO_REPITE_X: int = 2               ## repeticiones alrededor del haz (entero: sin costura)
const RAYO_ACLARA: float = 0.12            ## cuánto se lleva el cristal exterior hacia el blanco (el modelo usa 0,5)
const RAYO_SATURA: float = 0.7             ## cuánto del azul de la textura se conserva (el modelo, 0,2)
const RAYO_SCROLL: float = 1.1            ## repeticiones/s que corre la textura de la mano hacia la punta
const RAYO_SCROLL_NUCLEO: float = 2.2
const RAYO_T_CRECE: float = 0.2            ## s que tarda el haz en crecer desde la mano
const RAYO_T_FUNDE: float = 0.35           ## s que tarda en desvanecerse al final
const RAYO_ESQUIRLAS_POR_U: float = 1.6    ## esquirlas pequeñas por unidad de largo
const RAYO_ESQUIRLAS_MIN: int = 4
const RAYO_ESQUIRLAS_MAX: int = 14
const RAYO_ESQUIRLA_ESC_MIN: float = 0.45  ## escala respecto a la esquirla del proyectil (0,45 u de largo)
const RAYO_ESQUIRLA_ESC_MAX: float = 0.85
const RAYO_ESQUIRLA_LATERAL: float = 1.9   ## cuánto se apartan del eje, en radios del haz
const RAYO_ESQUIRLA_DERIVA: float = 1.2    ## u/s que avanzan hacia la punta
const RAYO_IMPACTO_PEQUENOS: int = 2       ## racimos pequeños donde da
const RAYO_IMPACTO_PINCHOS: int = 4
const RAYO_IMPACTO_RADIO: float = 0.4      ## a qué distancia (× esc) del punto brotan

## PLACA ROTA
const T_PLACA_SEPARA: float = 0.35
const T_PLACA_REPOSO: float = 1.2
const T_PLACA_HUNDE: float = 0.7
const PLACA_SEPARACION: float = 0.3        ## u que se aparta cada trozo del centro (en unidades de la placa; antes 0,18: se leía poco)
const PLACA_INCLINA: float = 0.3           ## rad máx. que se ladea cada trozo (antes 0,18)

static var usar_modelos: bool = true
## hielo textura (22/10): el hielo de los hechizos usa el MISMO material que el hielo del juego: la textura de cristales de la hoja de la compuerta de hielo
## (compuerta_hoja_hielo de puzle_terrain.glb, ARTE §12; el agua helada y el tapón usan la misma hoja), en triplanar sobre la pieza, mezclada con la textura de su
## propio GLB, con el tono azul sin aclarar, translúcida (0,82) y luz fría suave, como PiezaPuzle3D._hielo_modelo. false = el blanco azulado translúcido de antes.
static var textura_hielo_juego: bool = true## Proyectil de hielo con la esquirla de Meshy girando (DECISIÓN DE PABLO, 22/10, tras ver las capturas: «mejor que la bola»). true (por defecto): la esquirla.
## false: vuelve el cometa brillante del kit (`VfxKit3D.bola` con cola). Impacto, barrera, escarcha y reacción usan los modelos en los dos casos.
static var proyectil_esquirla: bool = true
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


## ¿Vuela el proyectil como esquirla del modelo? (modelos encendidos Y `proyectil_esquirla`). Si no, es el cometa del kit.
static func proyectil_con_esquirla() -> bool:
	return usar_modelos and proyectil_esquirla


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
	var tj: Texture2D = tex_hielo_juego()      # hielo textura
	var clave: int = (tex.get_instance_id() if tex != null else 0) * 2 + (1 if tj != null else 0)
	if _mats.has(clave):
		return _mats[clave]
	var sm := ShaderMaterial.new()
	sm.shader = _shader()
	if tex != null:
		sm.set_shader_parameter("tex", tex)
	_params_hielo_juego(sm, tj, false)
	_mats[clave] = sm
	return sm


static var _tex_juego: Texture2D = null


## La hoja de textura de la compuerta de hielo (puzle_terrain), o null si el interruptor 	extura_hielo_juego está apagado o no hay GLB. hielo textura
static func tex_hielo_juego() -> Texture2D:
	if not textura_hielo_juego:
		return null
	if _tex_juego == null:
		var m: Mesh = PiezaPuzle3D.malla_modelo("compuerta_hoja_hielo")
		var src: Material = m.surface_get_material(0) if m != null and m.get_surface_count() > 0 else null
		if src is StandardMaterial3D:
			_tex_juego = (src as StandardMaterial3D).albedo_texture
	return _tex_juego


## Pone en sm los parámetros del hielo del juego (o, con 	j null, los del blanco azulado de antes). haz = el cristal/núcleo del rayo los retoca después.
static func _params_hielo_juego(sm: ShaderMaterial, tj: Texture2D, _haz: bool) -> void:
	if tj == null:
		sm.set_shader_parameter("mezcla_tri", 0.0)
		return
	sm.set_shader_parameter("tex_hielo", tj)
	sm.set_shader_parameter("rect", Vector4(HIELO_TILE_RECT.position.x, HIELO_TILE_RECT.position.y, HIELO_TILE_RECT.size.x, HIELO_TILE_RECT.size.y))
	sm.set_shader_parameter("tile_u", HIELO_TILE_U)
	sm.set_shader_parameter("mezcla_tri", HIELO_MEZCLA_TRI)
	sm.set_shader_parameter("tinte_mezcla", 0.0)
	sm.set_shader_parameter("satura", 1.0)
	sm.set_shader_parameter("aclara", 0.0)
	sm.set_shader_parameter("alfa_centro", HIELO_ALFA)
	sm.set_shader_parameter("alfa_borde", HIELO_ALFA_BORDE)
	sm.set_shader_parameter("luz_propia", HIELO_LUZ)
	sm.set_shader_parameter("emi", Vector3(HIELO_EMISION.r, HIELO_EMISION.g, HIELO_EMISION.b))


static var _sh: Shader = null

static func _shader() -> Shader:
	if _sh == null:
		_sh = Shader.new()
		_sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_hielo : source_color, filter_linear_mipmap, repeat_enable;   // hoja de la compuerta de hielo
uniform vec4 rect = vec4(0.126, 0.835, 0.0996, 0.0996);   // panel de cristales dentro de la hoja
uniform float tile_u = 0.6;            // u de objeto por repetición del panel
uniform float mezcla_tri = 0.0;        // 0 = solo la textura del GLB (hielo de antes); >0 mezcla el panel de la compuerta en triplanar
uniform vec3 tinte : source_color = vec3(0.80, 0.92, 1.0);
uniform vec3 emi = vec3(0.80, 0.92, 1.0);
uniform float tinte_mezcla = 0.55;
uniform float satura = 0.2;            // cuánto del azul saturado del GLB se conserva
uniform float aclara = 0.5;            // cuánto se lleva hacia el blanco
uniform float alfa_centro = 0.6;
uniform float alfa_borde = 0.95;
uniform float luz_propia = 0.12;
varying vec3 opos;
varying vec3 onor;
vec3 panel(vec2 p) {
	vec2 m = abs(mod(p, 2.0) - 1.0);   // espejo: sin costuras
	return texture(tex_hielo, rect.xy + (m * 0.96 + 0.02) * rect.zw).rgb;
}
void vertex() {
	opos = VERTEX;
	onor = NORMAL;
}
void fragment() {
	vec3 t = texture(tex, UV).rgb;
	if (mezcla_tri > 0.0) {
		vec3 w = pow(abs(normalize(onor)), vec3(4.0));
		w /= (w.x + w.y + w.z);
		vec3 p = opos / tile_u;
		vec3 tri = panel(p.yz) * w.x + panel(p.xz) * w.y + panel(p.xy) * w.z;
		t = mix(t, tri, mezcla_tri);
	}
	float l = dot(t, vec3(0.299, 0.587, 0.114));
	vec3 c = mix(vec3(l), t, satura);
	c = mix(c, tinte, tinte_mezcla);
	c = mix(c, vec3(1.0), aclara * (0.4 + 0.6 * l));
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = c;
	ROUGHNESS = 0.18;
	SPECULAR = 0.5;
	EMISSION = emi * luz_propia + vec3(0.55, 0.82, 1.0) * f * 0.3;
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
# RAYO: haz de cristal de la mano al punto
# ---------------------------------------------------------------------------------------------------------------------------------

static var _sh_haz: Shader = null


## La textura de la esquirla (la del GLB de Meshy), o null si no hay modelo / están apagados. Es la que lleva el haz.
static func textura_esquirla() -> Texture2D:
	var m: Mesh = _modelo("esquirla_hielo") if usar_modelos else null
	if m != null and m.get_surface_count() > 0:
		var src: Material = m.surface_get_material(0)
		if src is StandardMaterial3D:
			return (src as StandardMaterial3D).albedo_texture
	return null


## Material de un cilindro del haz: el MISMO tratamiento que `material_modelo` (textura casi sin color, aclarada a blanco azulado, translúcida con fresnel) pero la
## textura se repite a lo largo (`RAYO_TEXEL`) y corre hacia la punta. `fade` (0–1) lo sube y baja al nacer y morir. Uno por haz (no se comparte: cada haz se desvanece solo).
static func material_haz(tex: Texture2D, largo: float, nucleo: bool) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = _shader_haz()
	if tex != null:
		sm.set_shader_parameter("tex", tex)
	sm.set_shader_parameter("repite", Vector2(1.0 if nucleo else float(RAYO_REPITE_X), maxf(largo / RAYO_TEXEL, 1.0) * (0.7 if nucleo else 1.0)))
	sm.set_shader_parameter("scroll", RAYO_SCROLL_NUCLEO if nucleo else RAYO_SCROLL)
	sm.set_shader_parameter("fade", 0.0)
	var tj: Texture2D = tex_hielo_juego()      # hielo textura: el panel de la compuerta (espejado) en vez de la textura de la esquirla
	if tj != null:
		sm.set_shader_parameter("tex_hielo", tj)
		sm.set_shader_parameter("rect", Vector4(HIELO_TILE_RECT.position.x, HIELO_TILE_RECT.position.y, HIELO_TILE_RECT.size.x, HIELO_TILE_RECT.size.y))
		sm.set_shader_parameter("mezcla_tri", 1.0)
		sm.set_shader_parameter("emi", Vector3(HIELO_EMISION.r, HIELO_EMISION.g, HIELO_EMISION.b))
	if nucleo:
		sm.set_shader_parameter("tinte", Vector3(0.92, 0.98, 1.0))
		if tj == null:
			sm.set_shader_parameter("emi", Vector3(0.92, 0.98, 1.0))
		sm.set_shader_parameter("aclara", 0.8)
		sm.set_shader_parameter("alfa_centro", 0.8)
		sm.set_shader_parameter("alfa_borde", 0.95)
		sm.set_shader_parameter("luz_propia", 0.35)
		if tj != null:                                          # hielo textura: el corazón es el mismo hielo, solo más claro (no blanco puro)
			sm.set_shader_parameter("satura", 1.0)
			sm.set_shader_parameter("aclara", RAYO_NUCLEO_ACLARA)
			sm.set_shader_parameter("tinte_mezcla", 0.0)
			sm.set_shader_parameter("luz_propia", HIELO_LUZ * 1.5)
	else:
		sm.set_shader_parameter("aclara", RAYO_ACLARA)         # menos blanco que el modelo: que se lea la textura del cristal
		sm.set_shader_parameter("satura", RAYO_SATURA)
		sm.set_shader_parameter("alfa_centro", 0.5)
		sm.set_shader_parameter("alfa_borde", 0.9)
		sm.set_shader_parameter("luz_propia", HIELO_LUZ * 0.6 if tj != null else 0.1)
		if tj != null:
			sm.set_shader_parameter("satura", 1.0)
			sm.set_shader_parameter("aclara", 0.0)
			sm.set_shader_parameter("tinte_mezcla", 0.0)
			sm.set_shader_parameter("alfa_centro", HIELO_ALFA * 0.7)
	return sm


static func _shader_haz() -> Shader:
	if _sh_haz == null:
		_sh_haz = Shader.new()
		_sh_haz.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_hielo : source_color, filter_linear_mipmap, repeat_enable;\nuniform vec4 rect = vec4(0.126, 0.835, 0.0996, 0.0996);\nuniform float mezcla_tri = 0.0;        // 1 = textura del panel de la compuerta (espejada) en vez de la de la esquirla\nuniform vec3 emi = vec3(0.80, 0.92, 1.0);\nuniform float tinte_mezcla = 0.55;\nuniform vec3 tinte : source_color = vec3(0.80, 0.92, 1.0);
uniform vec2 repite = vec2(2.0, 4.0);  // repeticiones alrededor y a lo largo
uniform float scroll = 1.1;            // repeticiones por segundo hacia la punta (el v del cilindro crece hacia la mano)
uniform float satura = 0.2;
uniform float aclara = 0.5;
uniform float alfa_centro = 0.5;
uniform float alfa_borde = 0.9;
uniform float luz_propia = 0.2;
uniform float fade = 1.0;
void fragment() {
	vec2 uv = vec2(UV.x * repite.x, UV.y * repite.y + TIME * scroll);
	vec3 t = texture(tex, uv).rgb;
	if (mezcla_tri > 0.0) {
		vec2 m = abs(mod(uv, 2.0) - 1.0);
		t = texture(tex_hielo, rect.xy + (m * 0.96 + 0.02) * rect.zw).rgb;
	}
	float l = dot(t, vec3(0.299, 0.587, 0.114));
	vec3 c = mix(vec3(l), t, satura);
	c = mix(c, tinte, tinte_mezcla);
	c = mix(c, vec3(1.0), aclara * (0.4 + 0.6 * l));
	float f = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.5);
	ALBEDO = c;
	ROUGHNESS = 0.18;
	SPECULAR = 0.5;
	EMISSION = emi * luz_propia + vec3(0.55, 0.82, 1.0) * f * 0.35;
	ALPHA = mix(alfa_centro, alfa_borde, f) * fade;
}
"""
	return _sh_haz


## RAYO de hielo de `desde` (la mano) a `hasta`, de `dura` s: un haz de cristal (dos cilindros de la textura de la esquirla, estirada y corriendo hacia la punta;
## el interior más claro), esquirlas pequeñas que giran y avanzan a lo largo, y donde da brotan racimos pequeños y pinchos de escarcha (`suelo` = y del suelo;
## NAN = la del punto). `esc` = tamaño (1 = normal). Crece desde la mano en `RAYO_T_CRECE` s y se desvanece al final. Devuelve la raíz (+Z = hacia `hasta`);
## el impacto cuelga de `padre` y se libera solo.
static func rayo(padre: Node3D, desde: Vector3, hasta: Vector3, dura: float = 1.0, esc: float = 1.0, suelo: float = NAN) -> Node3D:
	if padre == null or not is_instance_valid(padre) or not padre.is_inside_tree():
		return null
	var d: Vector3 = hasta - desde
	var largo: float = maxf(d.length(), 0.5)
	var dir: Vector3 = d.normalized() if d.length() > 0.001 else Vector3.RIGHT
	var k: float = maxf(esc, 0.3)
	var vida: float = maxf(dura, 0.3)
	var raiz := Node3D.new()
	raiz.name = "RayoHielo"
	padre.add_child(raiz)
	var arriba: Vector3 = Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	raiz.transform = Transform3D(Basis.looking_at(-dir, arriba), desde)         # la +Z de la raíz (y de las esquirlas) apunta hacia donde va el haz
	# El haz: cilindros con el eje Y girado a +Z; la mano en el origen, la punta (más gruesa) en `largo`.
	var haz := Node3D.new()
	haz.name = "Haz"
	haz.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	raiz.add_child(haz)
	var tex: Texture2D = textura_esquirla()
	var mats: Array[ShaderMaterial] = []
	for nucleo in [false, true]:
		var mesh := CylinderMesh.new()
		var r: float = RAYO_RADIO * k * (RAYO_NUCLEO_K if nucleo else 1.0)
		mesh.top_radius = r
		mesh.bottom_radius = r * RAYO_RADIO_MANO_K
		mesh.height = largo
		mesh.radial_segments = 12
		mesh.rings = 1
		mesh.cap_top = false
		mesh.cap_bottom = false
		var mat: ShaderMaterial = material_haz(tex, largo, nucleo)
		mats.append(mat)
		var mi := MeshInstance3D.new()
		mi.name = "Nucleo" if nucleo else "Cristal"
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0.0, largo * 0.5, 0.0)
		haz.add_child(mi)
	haz.scale = Vector3(1.0, 0.04, 1.0)
	var tc: Tween = haz.create_tween().set_parallel(true)
	tc.tween_property(haz, "scale:y", 1.0, RAYO_T_CRECE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for m in mats:
		tc.tween_property(m, "shader_parameter/fade", 1.0, RAYO_T_CRECE)
	# Esquirlas pequeñas a lo largo del haz: aparecen según crece, giran sobre su eje y derivan hacia la punta.
	var n: int = clampi(roundi(largo * RAYO_ESQUIRLAS_POR_U), RAYO_ESQUIRLAS_MIN, RAYO_ESQUIRLAS_MAX)
	for i in range(n):
		var t: float = (float(i) + 0.1 + randf() * 0.8) / float(n)
		var giro := Giro.new()
		giro.name = "EsquirlaRayoGiro%d" % i
		giro.w = randf_range(-3.5, 3.5)
		var a: float = randf() * TAU
		var lat: float = RAYO_RADIO * k * RAYO_ESQUIRLA_LATERAL * randf_range(0.6, 1.4) * (RAYO_RADIO_MANO_K + (1.0 - RAYO_RADIO_MANO_K) * t)
		var z0: float = largo * t
		giro.position = Vector3(cos(a) * lat, sin(a) * lat, z0)
		giro.scale = Vector3.ZERO
		raiz.add_child(giro)
		var e: MeshInstance3D = pieza("esquirla_hielo")
		e.name = "esquirla_hielo_rayo"
		e.scale = Vector3.ONE * randf_range(RAYO_ESQUIRLA_ESC_MIN, RAYO_ESQUIRLA_ESC_MAX) * k
		e.rotation = Vector3(randf_range(-0.35, 0.35), randf_range(-0.35, 0.35), 0.0)
		giro.add_child(e)
		var espera: float = t * RAYO_T_CRECE
		var tw: Tween = giro.create_tween()
		tw.tween_interval(espera)
		tw.tween_property(giro, "scale", Vector3.ONE, 0.12)
		tw.tween_interval(maxf(vida - espera - 0.12, 0.0))
		tw.tween_property(giro, "scale", Vector3.ZERO, RAYO_T_FUNDE)
		var tp: Tween = giro.create_tween()
		tp.tween_property(giro, "position:z", minf(z0 + RAYO_ESQUIRLA_DERIVA * (vida + RAYO_T_FUNDE), largo), vida + RAYO_T_FUNDE)
	# Impacto: racimos pequeños y pinchos de escarcha donde da (brotan cuando el haz llega).
	var y_s: float = suelo if not is_nan(suelo) else hasta.y
	var base := Vector3(hasta.x, y_s, hasta.z)
	var ki: float = clampf(k, 0.6, 2.0)
	var reposo: float = maxf(vida - RAYO_T_CRECE - T_BROTA, 0.2)
	var a0: float = randf() * TAU
	for i in range(RAYO_IMPACTO_PEQUENOS):
		var a: float = a0 + TAU * float(i) / float(RAYO_IMPACTO_PEQUENOS)
		_brotar(padre, "racimo_hielo_p", base + Vector3(cos(a), 0.0, sin(a)) * RAYO_IMPACTO_RADIO * 0.5 * ki, ki, randf() * TAU, RAYO_T_CRECE + randf() * 0.1, reposo)
	for i in range(RAYO_IMPACTO_PINCHOS):
		var a: float = a0 + TAU * (float(i) + 0.5) / float(RAYO_IMPACTO_PINCHOS) + randf_range(-0.25, 0.25)
		_brotar(padre, "pincho_escarcha_%d" % (i % N_PINCHOS), base + Vector3(cos(a), 0.0, sin(a)) * RAYO_IMPACTO_RADIO * ki * randf_range(1.0, 1.5), ki, randf() * TAU, RAYO_T_CRECE + randf() * 0.15, reposo)
	# Fin: el haz se desvanece y la raíz se libera.
	var tf: Tween = raiz.create_tween()
	tf.tween_interval(vida)
	tf.tween_property(mats[0], "shader_parameter/fade", 0.0, RAYO_T_FUNDE)
	tf.parallel().tween_property(mats[1], "shader_parameter/fade", 0.0, RAYO_T_FUNDE)
	tf.tween_callback(raiz.queue_free)
	return raiz


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
		tw.tween_property(t, "position", fuera * PLACA_SEPARACION + Vector3(0.0, -0.03, 0.0), T_PLACA_SEPARA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(t, "rotation", Vector3(randf_range(-PLACA_INCLINA, PLACA_INCLINA), randf_range(-0.1, 0.1), randf_range(-PLACA_INCLINA, PLACA_INCLINA)), T_PLACA_SEPARA)
		tw.tween_interval(T_PLACA_REPOSO)
		tw.tween_property(t, "position:y", -0.25, T_PLACA_HUNDE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t, "scale", Vector3.ONE * 0.6, T_PLACA_HUNDE)
	if raiz.is_inside_tree():
		raiz.get_tree().create_timer(T_PLACA_SEPARA + T_PLACA_REPOSO + T_PLACA_HUNDE + 0.2, false).timeout.connect(raiz.queue_free)
	return raiz
