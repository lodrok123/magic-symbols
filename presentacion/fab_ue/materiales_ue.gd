class_name MaterialesUE
extends RefCounted
## MATERIALES DE UNREAL EN GODOT (26/11/2026). Traduce una receta de material exportada de Unreal (informe.json de tools/ue_exportar_comun.py)
## a un material de Godot, según su MATERIAL MAESTRO. Calibrado en LabComparativaBosque contra fotos de Unreal (docs/capturas/comparativa_ue_godot).
## Lo usan el laboratorio y herramientas/generar_piezas_pure_nature.gd.
##
## Maestros que sabe traducir:
##   · BK (todos los «Pure Nature»): MM_BK_VegetationLeaves, MM_BK_Grass, MM_BK_Standard(Layered/Opacity/Emissive), MM_BK_VegetationTrunk.
##   · Stylescape: M_RuinsMaster (piedra y madera, SIN el beige del juego) y M_Ivy.
## Lo aprendido al calibrar (no tocar sin volver a comparar):
##   · Los colores de los parámetros de Unreal son LINEALES: en los shaders van sin `source_color`; en StandardMaterial3D se pasan con linear_to_srgb().
##   · Las hojas de BK son de una cara y salen ~10 veces más oscuras que en Unreal (que las aclara con su exposición): HOJAS_BRILLO.
##   · La rugosidad del AORM de Stylescape es muy baja (0,11): tal cual, la piedra refleja el cielo como mojada. Va mate.
##   · El musgo de Stylescape se decide con el relieve de la TEXTURA exagerado («Blend Normal»), no con la normal de la malla.

const SHADERS: String = "res://presentacion/fab_ue/"
const CM: float = 0.01
## Cuánto se aclaran las hojas de BK. Medido 26/11 en Cam_Juego: arbusto 19·65·18 en Unreal; aquí 0·12·0 a 1,0 y 14·76·11 a 6,0.
## 2.º (26/11): el «10 veces más oscuro» venía de pasar los tintes como Color a un vec3: Godot los convertía como si fueran sRGB
## (0,2 -> 0,033). Con Vector3 (v3) el color del pack ya sale bien y no hace falta aclarar: 1,0. Se deja el parámetro por si acaso.
const HOJAS_BRILLO: float = 1.0
## Desde qué inclinación hacia arriba coge musgo la piedra de Stylescape (más alto = menos musgo). 0,45 salía más verde que en Unreal.
const RUINAS_MUSGO_UMBRAL: float = 0.55

var informe: Dictionary
var dir_texturas: String
## Unidades del mundo por metro de Unreal. 1 en el laboratorio; las piezas del juego van a 0,575 u/m (como Stylescape). Afecta a lo que se
## mide en el mundo (alto del musgo de los troncos, tamaño del ruido de la hierba); lo que se mide en la malla no cambia.
var escala: float = 1.0
var _texs: Dictionary = {}
var _mats: Dictionary = {}
## Materiales de un maestro que no se sabe traducir (salen grises): para avisar.
var sin_receta: Dictionary = {}


func _init(informe_: Dictionary, dir_texturas_: String) -> void:
	informe = informe_
	dir_texturas = dir_texturas_


func tex(nombre) -> Texture2D:
	if nombre == null or String(nombre) == "":
		return null
	var k: String = String(nombre)
	if not _texs.has(k):
		var ruta: String = dir_texturas + k + ".png"
		_texs[k] = load(ruta) if ResourceLoader.exists(ruta) else null
	return _texs[k]


## Los parámetros de los shaders son vec3: se pasan como Vector3. Con Color funciona en memoria, pero al GUARDAR el material (.tres) y volver
## a cargarlo el valor no entra en el vec3 y queda el de por defecto (blanco): las hojas salían blancas en las piezas (26/11).
static func v3(v, por_defecto: Color = Color.WHITE) -> Vector3:
	var c: Color = col(v, por_defecto)
	return Vector3(c.r, c.g, c.b)


static func col(v, por_defecto: Color = Color.WHITE) -> Color:
	if v == null:
		return por_defecto
	return Color(float(v[0]), float(v[1]), float(v[2]))


## --- MATERIAL DEL JUEGO (26/11, decisión de Pablo) -----------------------------------------------------------------------------------
## La misma receta, pero como StandardMaterial3D, para las piezas que SUSTITUYEN vegetación del juego. El juego convierte los
## StandardMaterial3D a su material propio (Ocluso3D.convertir), que es el que sabe quemarse, mojarse, helarse, reaccionar y apartarse;
## con los shaders del pack (material()) todo eso dejaría de verse. A cambio se aproxima lo que el material del juego no tiene:
##   · hojas: el degradado Main→Gradient se queda en un tinte medio; la textura se multiplica una vez (el grafo de BK la multiplica dos:
##     se compensa con HOJAS_JUEGO_K).
##   · hierba: la mezcla de Color 01/02 por ruido, en su media.
##   · rocas: la capa de hierba de arriba y el detalle no se pintan (solo color, relieve y oclusión de la máscara).
## Los tintes de Unreal son lineales: albedo_color se escribe en sRGB (linear_to_srgb).
const HOJAS_JUEGO_K: float = 0.6
## 2.º (26/11, fotos del Bosque antes/después): con el tinte de Unreal las copas salían casi NEGRAS con la luz del juego. La paleta del
## juego (paleta_copa, VERDES_COPA de la maqueta) corrige el TONO pero conserva lo oscuro del albedo, y los modelos de Meshy traen texturas
## claras. Así que en el material del juego el tinte de hojas, hierba y troncos conserva su tono pero se lleva a esta luminosidad
## (el canal mayor, en sRGB). Las rocas, setas y flores no se tocan.
const JUEGO_LUMINOSIDAD: float = 0.82
const JUEGO_DESATURAR: float = 0.35
var _mats_juego: Dictionary = {}


## El tinte (lineal) en sRGB con el canal mayor a JUEGO_LUMINOSIDAD: mismo tono, tan claro como las piezas de Meshy.
static func _claro(tinte_lineal: Color) -> Color:
	var c: Color = Color(tinte_lineal.r, tinte_lineal.g, tinte_lineal.b).linear_to_srgb()
	var m: float = maxf(maxf(c.r, c.g), maxf(c.b, 0.001))
	var claro := Color(c.r / m * JUEGO_LUMINOSIDAD, c.g / m * JUEGO_LUMINOSIDAD, c.b / m * JUEGO_LUMINOSIDAD)
	# 3.º: los arbustos (que no pasan por la paleta de copa de la maqueta) salían verde chillón: un poco hacia el gris, como la paleta pastel
	var gris: float = (claro.r + claro.g + claro.b) / 3.0
	return claro.lerp(Color(gris, gris, gris), JUEGO_DESATURAR)


func material_juego(clave: String) -> Material:
	if _mats_juego.has(clave):
		return _mats_juego[clave]
	if not informe["materiales"].has(clave):
		return null
	var m: Dictionary = informe["materiales"][clave]
	var tx: Dictionary = m["texturas"]
	var es: Dictionary = m["escalares"]
	var ve: Dictionary = m["vectores"]
	var padre: String = String(m["padre"])
	var sm := StandardMaterial3D.new()
	sm.resource_name = clave
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	sm.roughness = 0.9
	match padre:
		"MM_BK_VegetationLeaves", "MM_BK_HillsLeaves":
			var tinte: Color = col(ve.get("Main Color")).lerp(col(ve.get("Gradient Color")), 0.5)
			sm.albedo_texture = tex(tx.get("Texture"))
			sm.albedo_color = _claro(tinte)
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			sm.alpha_scissor_threshold = 0.5
		"MM_BK_Grass":
			var mezcla: Color = col(ve.get("Color 01")).lerp(col(ve.get("Color 02")), 0.5)
			var tinte: Color = Color.WHITE.lerp(mezcla, clampf(float(es.get("Color Power", 0.0)), 0.0, 1.0))
			sm.albedo_texture = tex(tx.get("Albedo"))
			sm.albedo_color = _claro(tinte)
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			sm.alpha_scissor_threshold = 0.5
			sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		"MM_BK_VegetationTrunk":
			sm.albedo_texture = tex(tx.get("Albedo"))
			sm.albedo_color = _claro(col(ve.get("Main Color")))
			_relieve(sm, tex(tx.get("Normal")))
		"MM_BK_StandardLayered", "MM_BK_Standard", "MM_BK_StandardOpacity", "MM_BK_StandardEmissive", "MM_CoveredStandard", "MM_BK_Banks":
			sm.albedo_texture = tex(tx.get("Albedo"))
			sm.albedo_color = col(ve.get("Color")).linear_to_srgb()
			_relieve(sm, tex(tx.get("Normal")))
			if padre == "MM_BK_StandardOpacity":
				sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				sm.alpha_scissor_threshold = 0.5
		"MM_BK_Water":
			sm.albedo_color = Color(0.22, 0.48, 0.62, 0.65)
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sm.roughness = 0.1
		_:
			# Stylescape y lo que no se conozca: el material del pack tal cual (el juego lo deja como está)
			var otro: Material = material(clave)
			_mats_juego[clave] = otro
			return otro
	_mats_juego[clave] = sm
	return sm


static func _relieve(sm: StandardMaterial3D, normal: Texture2D) -> void:
	if normal != null:
		sm.normal_enabled = true
		sm.normal_texture = normal


## El material de Godot para la receta `clave` (p. ej. «PureNature_Meadows__MI_OakLeaves»). `alto_malla` (m) es para el degradado de las hojas.
## Devuelve null si la receta no está en el informe.
func material(clave: String, alto_malla: float = 10.0) -> Material:
	var k: String = clave + ("|%.2f" % alto_malla)
	if _mats.has(k):
		return _mats[k]
	if not informe["materiales"].has(clave):
		return null
	var m: Dictionary = informe["materiales"][clave]
	var tx: Dictionary = m["texturas"]
	var es: Dictionary = m["escalares"]
	var ve: Dictionary = m["vectores"]
	var padre: String = String(m["padre"])
	var sh := ShaderMaterial.new()
	var mat: Material = sh
	match padre:
		"MM_BK_VegetationLeaves", "MM_BK_HillsLeaves":     # 26/11: HillsLeaves (árboles de las colinas de Asian Valley) tiene los mismos parámetros
			sh.shader = load(SHADERS + "bk_follaje.gdshader")
			sh.set_shader_parameter("albedo", tex(tx.get("Texture")))
			sh.set_shader_parameter("normal_tex", tex(tx.get("NormalTex")))
			sh.set_shader_parameter("fuerza_normal", float(es.get("Normal Intensity", 0.2)))
			sh.set_shader_parameter("es_hoja", true)
			sh.set_shader_parameter("color_abajo", v3(ve.get("Main Color")))
			sh.set_shader_parameter("color_arriba", v3(ve.get("Gradient Color")))
			sh.set_shader_parameter("degradado_desplaz", float(es.get("Gradient Offset", 0.5)))
			sh.set_shader_parameter("degradado_contraste", float(es.get("Gradient Contrast", 1.5)))
			sh.set_shader_parameter("altura_malla", maxf(alto_malla, 0.5))
			sh.set_shader_parameter("brillo_hojas", HOJAS_BRILLO)
		"MM_BK_Grass":
			sh.shader = load(SHADERS + "bk_follaje.gdshader")
			sh.set_shader_parameter("albedo", tex(tx.get("Albedo")))
			sh.set_shader_parameter("normal_tex", tex(tx.get("Normal")))
			sh.set_shader_parameter("fuerza_normal", float(es.get("Normal Power", 0.0)))
			sh.set_shader_parameter("hay_normal", float(es.get("Normal Power", 0.0)) > 0.0)
			sh.set_shader_parameter("rugosidad", float(es.get("Roughness", 0.8)))
			sh.set_shader_parameter("es_hoja", false)
			sh.set_shader_parameter("color_abajo", v3(ve.get("Color 01")))
			sh.set_shader_parameter("color_arriba", v3(ve.get("Color 02")))
			sh.set_shader_parameter("fuerza_color", float(es.get("Color Power", 0.0)))
			sh.set_shader_parameter("ruido", tex(tx.get("Noise")))
			sh.set_shader_parameter("escala_ruido", float(es.get("Noise Scale", 10000.0)) * CM * escala)
		# 26/11: MM_CoveredStandard (colinas de Asian Valley) y MM_BK_Banks (orillas de Savanna) tienen los mismos parámetros que StandardLayered
		"MM_BK_StandardLayered", "MM_BK_Standard", "MM_BK_StandardOpacity", "MM_BK_StandardEmissive", "MM_CoveredStandard", "MM_BK_Banks":
			sh.shader = load(SHADERS + "bk_capas.gdshader")
			sh.set_shader_parameter("albedo", tex(tx.get("Albedo")))
			sh.set_shader_parameter("normal_tex", tex(tx.get("Normal")))
			sh.set_shader_parameter("mascara", tex(tx.get("Mask")))
			sh.set_shader_parameter("hay_mascara", tx.get("Mask") != null)
			sh.set_shader_parameter("tinte", v3(ve.get("Color")))
			sh.set_shader_parameter("fuerza_normal", float(es.get("Normal Power", 1.0)))
			sh.set_shader_parameter("oclusion", float(es.get("Occlusion", 0.7)))
			# 26/11, según el grafo de Unreal (docs/fab_ue/grafos): el detalle se mezcla al «Blend Normal» y la capa es WorldAlignedBlend
			# (Sharpness, Bias); en las orillas, la capa la marca el canal B de la máscara.
			if tx.get("Detail Albedo") != null:
				sh.set_shader_parameter("hay_detalle", true)
				sh.set_shader_parameter("detalle", tex(tx.get("Detail Albedo")))
				sh.set_shader_parameter("repeticion_detalle", float(es.get("Detail Tiling", 3.0)))
				sh.set_shader_parameter("detalle_mezcla", clampf(float(es.get("Blend Normal", 0.5)), 0.0, 1.0))
			if tx.get("Layer Albedo") != null:
				sh.set_shader_parameter("hay_capa", true)
				sh.set_shader_parameter("capa_albedo", tex(tx.get("Layer Albedo")))
				sh.set_shader_parameter("capa_tinte", v3(ve.get("Layer Color")))
				sh.set_shader_parameter("repeticion_capa", float(es.get("Layer Tiling", 5.0)))
				sh.set_shader_parameter("capa_dureza", float(es.get("Blend Sharpness", 2.0)))
				sh.set_shader_parameter("capa_sesgo", float(es.get("Blend Bias", 0.1)))
				sh.set_shader_parameter("capa_por_mascara", padre == "MM_BK_Banks" and tx.get("Mask") != null)
			if padre == "MM_BK_StandardOpacity":
				sh.set_shader_parameter("recorte_alfa", true)
			if padre == "MM_BK_StandardEmissive":
				sh.set_shader_parameter("emision", v3(ve.get("Emissive Color", ve.get("Emissive", [0, 0, 0, 1]))) * float(es.get("Emissive Power", es.get("Emissive Intensity", 1.0))))
		"MM_BK_VegetationTrunk":
			sh.shader = load(SHADERS + "bk_capas.gdshader")
			sh.set_shader_parameter("albedo", tex(tx.get("Albedo")))
			sh.set_shader_parameter("normal_tex", tex(tx.get("Normal")))
			sh.set_shader_parameter("mascara", tex(tx.get("Mask")))
			sh.set_shader_parameter("hay_mascara", tx.get("Mask") != null)
			sh.set_shader_parameter("tinte", v3(ve.get("Main Color")))
			sh.set_shader_parameter("oclusion", float(es.get("Ambient Occlusion", 0.5)))
			if tx.get("Layer Albedo") != null and tx.get("Layer Albedo") != tx.get("Albedo"):
				sh.set_shader_parameter("hay_capa", true)
				sh.set_shader_parameter("capa_por_altura", true)
				sh.set_shader_parameter("capa_albedo", tex(tx.get("Layer Albedo")))
				sh.set_shader_parameter("capa_alto", float(es.get("Offset", 40.0)) * CM * escala)
				sh.set_shader_parameter("capa_transicion", float(es.get("Falloff", 100.0)) * CM * escala)
				sh.set_shader_parameter("repeticion_capa", 1.0)
		"M_RuinsMaster":
			sh.shader = load(SHADERS + "ruinas_pack.gdshader")
			sh.set_shader_parameter("albedo", tex(tx.get("Diffuse")))
			sh.set_shader_parameter("normal_tex", tex(tx.get("Normal")))
			sh.set_shader_parameter("aorm", tex(tx.get("AO_R_S")))
			sh.set_shader_parameter("tinte", v3(ve.get("Tint")))
			sh.set_shader_parameter("ao_potencia", float(es.get("AO Power", 1.5)))
			sh.set_shader_parameter("rugosidad_potencia", float(es.get("Roughness Power", 1.0)))
			sh.set_shader_parameter("aplanar", clampf(float(es.get("Normal Flatness", 0.25)), 0.0, 1.0))
			sh.set_shader_parameter("capa_albedo", tex(tx.get("Top Layer Diffuse")))
			sh.set_shader_parameter("capa_repeticion", float(es.get("Top Layer Tiling", 10.0)))
			sh.set_shader_parameter("capa_opacidad", float(es.get("Top Layer Opacity", 1.0)))
			sh.set_shader_parameter("capa_relieve", float(es.get("Blend Normal", 50.0)))
			sh.set_shader_parameter("capa_umbral", RUINAS_MUSGO_UMBRAL)
			sh.set_shader_parameter("borde_color", v3(ve.get("Rim Lighting Color")))
		"M_Ivy":
			var sm := StandardMaterial3D.new()
			sm.albedo_texture = tex(tx.get("Diffuse"))
			sm.albedo_color = col(ve.get("Ivy Tint")).linear_to_srgb()
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			sm.alpha_scissor_threshold = 0.5
			sm.cull_mode = BaseMaterial3D.CULL_DISABLED
			sm.roughness = float(es.get("Roughness", 0.6))
			mat = sm
		"MM_BK_Water":
			# PROVISIONAL: azul translúcido. En el juego el agua es la del mundo (memoria «agua = agua del mundo»): no se traduce la de BK.
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color(0.22, 0.48, 0.62, 0.65)
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sm.roughness = 0.1
			mat = sm
		_:
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color(0.6, 0.6, 0.6)
			mat = sm
			sin_receta[clave] = padre
	_mats[k] = mat
	return mat
