class_name Posproceso3D
extends RefCounted
## POSPROCESADO DE LA MAQUETA (V1 de docs/PLAN_EOW_VISUAL.md, Pipeline, 21/10). SSAO, tonemap, viñeta y antialiasing de pantalla.
##
## POR QUÉ. En Echoes of Wisdom la malla es pobre y lo que da volumen es la luz y el posprocesado: el AO «apoya» cada pieza en el suelo, el
## tonemap suaviza los blancos quemados y la viñeta cierra el encuadre. Antes la maqueta tenía SOLO glow + ajuste de color (+ DOF); el resto
## de Godot estaba en «lineal, sin AO, sin viñeta, MSAA y nada más». Todo está aquí, en constantes con nombre, para que Pablo lo ajuste o lo apague.
##
## CÓMO SE APAGA.
##   · Todo de golpe: `Posproceso3D.activo = false` (antes de montar la escena) → el entorno queda EXACTAMENTE como antes de V1.
##   · Cada efecto por separado: su constante `*_ACTIVO` (o `TONEMAP_MODO = Environment.TONE_MAPPER_LINEAR` / `AA_MODO = SCREEN_SPACE_AA_DISABLED`).
##   · El tilt-shift y la sonda de reflejos tienen su propio interruptor en la maqueta (`tilt_shift`, `sonda_reflejos`, teclas RePág / Inicio).
##
## COMPATIBILIDAD. SSAO solo existe en Forward+ (en Compatibilidad / llvmpipe no hay): allí se salta y se dice UNA vez por consola; no revienta.
## El tonemap, la viñeta y el FXAA sí funcionan en todos los renderers.

## Interruptor general. Es `static var` y no `const` para que las herramientas de captura puedan sacar el «antes» sin editar el archivo.
static var activo: bool = true

## --- SSAO (oclusión ambiental en pantalla) ---
## Suave a propósito: que oscurezca el pie de los troncos, rocas y bloques sin ensuciar las superficies grandes. Valores de Godot por defecto:
## radio 1,0 · intensidad 2,0 · poder 1,5 · detalle 0,5. La casilla mide 2,3 u, así que un radio de 1,0 cubre media casilla alrededor de la pieza.
const SSAO_ACTIVO: bool = true
const SSAO_RADIO: float = 1.0            ## unidades de mundo en las que busca oclusores
const SSAO_INTENSIDAD: float = 1.2       ## cuánto oscurece (por defecto 2,0: aquí más suave)
const SSAO_PODER: float = 1.5            ## curva: más alto = el AO se concentra en las esquinas
const SSAO_DETALLE: float = 0.5
const SSAO_AFECTA_LUZ: float = 0.0       ## 0 = solo oscurece el AMBIENTE (no la luz directa del sol: la sombra del sol ya la pone la sombra)
const SSAO_AFECTA_REFLEJOS: float = 0.5  ## cuánto atenúa también la luz de la sonda de reflejos

## --- Tonemap ---
## «Como antes» = `Environment.TONE_MAPPER_LINEAR` (sin tonemap). ELEGIDO FILMIC con exposición 0,8, MEDIDO en la sala 1/2/5 del lab (docs/capturas/look_v1v2/MEDIDAS.txt):
## la hierba antes era S 0,61 · V 0,81 y la tierra S 0,58 · V 0,60. Con Filmic a 0,8 queda hierba S 0,57 · V 0,82 y tierra S 0,59 · V 0,62 (casi igual); con AgX
## (a cualquier exposición) la hierba baja a S 0,40-0,45 y se ve lavada: AgX desatura de por sí y la paleta cerrada de Paleta3D es saturada. Filmic además
## recupera el canal verde que antes se recortaba a 1,0 (nota de Paleta3D.aplicar_ajuste). ACES queda más brillante y verdoso (V 0,89): descartado.
const TONEMAP_MODO: int = Environment.TONE_MAPPER_FILMIC
const TONEMAP_EXPOSICION: float = 0.8    ## multiplicador de la luz ANTES del tonemap (1,0 = neutro): Filmic a 1,0 aclara la escena (V 0,88), a 0,8 la deja como estaba
const TONEMAP_BLANCO: float = 1.0        ## luminancia que se mapea a blanco (solo Filmic/ACES/AgX); 1,0 = el valor por defecto de Godot

## --- Viñeta ---
## Godot 4 no trae viñeta en el Environment: es un ColorRect con shader en un CanvasLayer (capa 0, por debajo del HUD), como el tilt-shift.
## No lee la pantalla (solo pinta un degradado con alfa), así que cuesta casi nada.
const VINETA_ACTIVA: bool = true
const VINETA_FUERZA: float = 0.28        ## opacidad máxima en las esquinas (0 = nada, 1 = negro)
const VINETA_RADIO: float = 0.62         ## a qué distancia del centro (0 = centro, 1 = esquina) empieza a oscurecer
const VINETA_SUAVIDAD: float = 0.55      ## ancho de la transición (más alto = más difusa)
const VINETA_COLOR: Color = Color(0.04, 0.06, 0.05)   ## casi negro verdoso: el mismo del fondo del proyecto

## --- Tilt-shift y sonda de reflejos: valor de serie de la maqueta (`tilt_shift` y `sonda_reflejos` de prueba_test2.gd). Como antes: false ambos. ---
const TILT_SHIFT_DEFECTO: bool = true
const SONDA_DEFECTO: bool = true

## --- Antialiasing de pantalla ---
## La maqueta ya usa MSAA 4×, que no toca los bordes de los shaders (hojas con alfa, brillos, bordes de tilt-shift). FXAA es barato, se suma a
## MSAA sin ghosting. TAA se descarta: con MSAA no se combina bien y dejaría estela en el fuego y los hechizos (partículas sin vectores de movimiento).
const AA_MODO: int = Viewport.SCREEN_SPACE_AA_FXAA

const _SHADER_VINETA: String = """
shader_type canvas_item;
uniform float fuerza = 0.28;
uniform float radio = 0.62;
uniform float suavidad = 0.55;
uniform vec4 color : source_color = vec4(0.04, 0.06, 0.05, 1.0);

void fragment() {
	// Distancia al centro, corregida por la proporción de pantalla para que el óvalo siga a la ventana y no sea un círculo recortado.
	vec2 p = (SCREEN_UV - 0.5) * 2.0;
	float d = length(p) / 1.41421356;
	float a = smoothstep(radio, radio + max(suavidad, 0.01), d) * fuerza;
	COLOR = vec4(color.rgb, a);
}
"""

static var _avisado_ssao: bool = false


## Aplica al Environment (y al viewport) todo el posprocesado de entorno: SSAO, tonemap y antialiasing. Con `activo = false` no toca nada.
static func aplicar_entorno(env: Environment, vp: Viewport) -> void:
	if not activo:
		return
	if env != null:
		_tonemap(env)
		_ssao(env)
	if vp != null:
		vp.screen_space_aa = AA_MODO as Viewport.ScreenSpaceAA


static func _tonemap(env: Environment) -> void:
	env.tonemap_mode = TONEMAP_MODO as Environment.ToneMapper
	env.tonemap_exposure = TONEMAP_EXPOSICION
	env.tonemap_white = TONEMAP_BLANCO


static func _ssao(env: Environment) -> void:
	if not SSAO_ACTIVO:
		return
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		# Compatibilidad (y Mobile): no hay SSAO. No se activa para no dejar un ajuste que no hace nada pero parece que sí.
		if not _avisado_ssao:
			_avisado_ssao = true
			print("Posproceso3D: SSAO no disponible con el renderer «%s» (solo Forward+): se omite." % RenderingServer.get_current_rendering_method())
		return
	env.ssao_enabled = true
	env.ssao_radius = SSAO_RADIO
	env.ssao_intensity = SSAO_INTENSIDAD
	env.ssao_power = SSAO_PODER
	env.ssao_detail = SSAO_DETALLE
	env.ssao_light_affect = SSAO_AFECTA_LUZ
	env.ssao_ao_channel_affect = 0.0
	env.set("ssao_sharpness", 0.98)


## Crea la viñeta como hija de `padre` (CanvasLayer capa 0). Devuelve el nodo o null si está apagada (o `activo = false`).
static func montar_vineta(padre: Node) -> CanvasLayer:
	if not activo or not VINETA_ACTIVA or VINETA_FUERZA <= 0.0:
		return null
	var capa := CanvasLayer.new()
	capa.name = "Vineta3D"
	capa.layer = 0                       # por debajo del HUD (capa 1)
	var sh := Shader.new()
	sh.code = _SHADER_VINETA
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("fuerza", VINETA_FUERZA)
	mat.set_shader_parameter("radio", VINETA_RADIO)
	mat.set_shader_parameter("suavidad", VINETA_SUAVIDAD)
	mat.set_shader_parameter("color", VINETA_COLOR)
	var rect := ColorRect.new()
	rect.name = "Vineta"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.material = mat
	capa.add_child(rect)
	padre.add_child(capa)
	return capa
