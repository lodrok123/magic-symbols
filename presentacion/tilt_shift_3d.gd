class_name TiltShift3D
extends CanvasLayer
## BANDA DE TILT-SHIFT (F2 de PLAN_EOW, Pipeline, 21/10). Desenfoque de pantalla en bandas: nítido en una franja horizontal y cada vez más
## borroso hacia arriba y hacia abajo. Es la otra mitad del look «maqueta» de Echoes of Wisdom (centro + ancho + gamma).
##
## POR QUÉ ADEMÁS DEL DIORAMA. El diorama de `prueba_test2.gd` (`CameraAttributesPractical`) desenfoca por PROFUNDIDAD, solo el fondo lejano
## (`dof_blur_far`): lo de delante, el borde de abajo de la pantalla, queda nítido a propósito. El tilt-shift de EoW es por POSICIÓN EN PANTALLA:
## borra también la franja de abajo, que es lo que da la sensación de miniatura. Son efectos distintos y se suman.
##
## CÓMO. Un ColorRect a pantalla completa con un shader que lee la pantalla ya dibujada (`hint_screen_texture`) y la mezcla con una versión
## difuminada según la distancia vertical al `centro`. El desenfoque son 9 muestras en anillo con el radio creciendo con la distancia: barato y sin
## cuadrículas (los mipmaps solos se ven a bloques). Va en la capa 0, POR DEBAJO del HUD (capa 1), así que el texto no se emborrona.
##
## PARÁMETROS (todos en fracción de la altura de pantalla salvo gamma y fuerza):
##   · `centro`: dónde está la franja nítida (0 = arriba, 1 = abajo). 0,5 = a mitad (el jugador va centrado por la cámara).
##   · `ancho`: semialtura de la franja del todo nítida. 0,2 = el 40 % central.
##   · `transicion`: lo que tarda en llegar al desenfoque máximo.
##   · `gamma`: curva de esa subida (1 = lineal; 2 = tarda más en empezar, luego rápido).
##   · `fuerza`: radio máximo del desenfoque en píxeles de pantalla. 0 lo apaga.
## Sin cambios para el Juego: es solo dibujo.

const SHADER: String = """
shader_type canvas_item;
uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float centro = 0.5;
uniform float ancho = 0.2;
uniform float transicion = 0.3;
uniform float gamma = 1.5;
uniform float fuerza = 6.0;

void fragment() {
	float d = abs(SCREEN_UV.y - centro);
	float t = pow(clamp((d - ancho) / max(transicion, 0.001), 0.0, 1.0), max(gamma, 0.01));
	vec2 px = SCREEN_PIXEL_SIZE * fuerza * t;
	vec3 c = textureLod(pantalla, SCREEN_UV, 0.0).rgb;
	if (t > 0.0) {
		// 8 muestras en anillo + la central. El LOD sube con t para no ver puntos sueltos cuando el radio es grande.
		float lod = t * 1.5;
		vec3 s = textureLod(pantalla, SCREEN_UV, lod).rgb;
		for (int i = 0; i < 8; i++) {
			float a = 6.2831853 * float(i) / 8.0;
			s += textureLod(pantalla, SCREEN_UV + vec2(cos(a), sin(a)) * px, lod).rgb;
		}
		c = mix(c, s / 9.0, smoothstep(0.0, 0.15, t));
	}
	COLOR = vec4(c, 1.0);
}
"""

var centro: float = 0.5: set = set_centro
var ancho: float = 0.2: set = set_ancho
var transicion: float = 0.3: set = set_transicion
var gamma: float = 1.5: set = set_gamma
var fuerza: float = 6.0: set = set_fuerza
## Apagado de serie en la maqueta (`encendido = false`): se enciende a propósito para compararlo.
var encendido: bool = false: set = set_encendido

var _rect: ColorRect = null
var _mat: ShaderMaterial = null


func _init() -> void:
	name = "TiltShift3D"
	layer = 0                       # por debajo del HUD (capa 1): el texto no se difumina
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect = ColorRect.new()
	_rect.name = "Banda"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.material = _mat
	add_child(_rect)
	_rect.visible = false
	_aplicar()


func _aplicar() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("centro", centro)
	_mat.set_shader_parameter("ancho", ancho)
	_mat.set_shader_parameter("transicion", transicion)
	_mat.set_shader_parameter("gamma", gamma)
	_mat.set_shader_parameter("fuerza", fuerza)
	# fuerza 0 = apagado de verdad: ni se dibuja el rectángulo (cero coste), no «dibujado sin efecto».
	_rect.visible = encendido and fuerza > 0.0


func set_centro(v: float) -> void:
	centro = clampf(v, 0.0, 1.0)
	_aplicar()


func set_ancho(v: float) -> void:
	ancho = clampf(v, 0.0, 0.5)
	_aplicar()


func set_transicion(v: float) -> void:
	transicion = clampf(v, 0.01, 1.0)
	_aplicar()


func set_gamma(v: float) -> void:
	gamma = clampf(v, 0.2, 4.0)
	_aplicar()


func set_fuerza(v: float) -> void:
	fuerza = clampf(v, 0.0, 24.0)
	_aplicar()


func set_encendido(v: bool) -> void:
	encendido = v
	_aplicar()


## ¿Se está dibujando la banda ahora mismo? (para pruebas y para el HUD).
func activo() -> bool:
	return _rect != null and _rect.visible
