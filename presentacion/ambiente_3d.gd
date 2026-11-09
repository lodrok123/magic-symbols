class_name Ambiente3D
extends RefCounted

## BLOQUE DE AMBIENTE: la sombra del mundo, en UN sitio (7/11, docs/estudios/BLOQUE_AMBIENTE_COMPARACION_2026-11-07.md).
##
## Antes, el color que llega a la sombra (`sombra_tinte`) estaba copiado literalmente en seis shaders (suelo, agua, lecho).
## Ahora son uniforms globales que leen todos los shaders con rampa toon (y `amb_rampa`, el interruptor de la rampa del decorado):
##   amb_sombra       vec4  rgb = lo que llega a la sombra del MUNDO (suelo, agua, lecho, decorado); a = contraste base de la rampa.
##   amb_sombra_pers  vec4  lo mismo para personajes y criaturas. Es distinto del mundo A PROPOSITO (como el bloque `_ES_Character*`
##                          de Genshin): el personaje tiene que leerse mejor que el mundo. No se igualan.
##
## Uso en un shader:  `global uniform vec4 amb_sombra;`  y  `amb_sombra.rgb` / `amb_sombra.a`.
## `preparar_global()` tiene que haber corrido ANTES de compilar cualquier shader que los declare (si no, Godot da «uniform desconocido»).
## Es idempotente: llamarlo desde cada sitio que crea uno de esos shaders es seguro.

const PARAM_SOMBRA: String = "amb_sombra"
const PARAM_SOMBRA_PERS: String = "amb_sombra_pers"
const PARAM_RAMPA: String = "amb_rampa"      ## vec4: x = 1 rampa toon en el decorado (Ocluso3D), 0 luz Lambert de antes. Es el interruptor `Ocluso3D.usar_rampa`

const SOMBRA_MUNDO: Vector4 = Vector4(0.34, 0.36, 0.46, 1.2)
const SOMBRA_PERS: Vector4 = Vector4(0.810, 0.810, 0.931, 2.0)

## OJO con el espacio de color (medido el 7/11 con un quad unshaded): el `uniform vec3 ... : source_color = vec3(..)` que había en suelo/agua/lecho
## pasaba su valor por defecto de sRGB a LINEAL (0,34 -> 0,095); un uniform global no pasa por esa conversión. Por eso la sombra del MUNDO se
## escribe aquí en sRGB (como se veía en el editor) y se sube ya en lineal. La del personaje venía de `set_shader_parameter("sombra_color", Vector3)`, que no se convertía: su valor LINEAL era (0,62, 0,62, 0,85),
## así que ahora se escribe en sRGB (0,810, 0,810, 0,931) y se convierte al subir. Los dos cambios dejan la imagen exactamente como estaba.
static var _registrado: bool = false
static var _sombra: Vector4 = SOMBRA_MUNDO       ## como se escribe (sRGB, los dos)
static var _sombra_pers: Vector4 = SOMBRA_PERS
static var _rampa: bool = true


static func _subir_mundo() -> Vector4:
	var l: Color = Color(_sombra.x, _sombra.y, _sombra.z).srgb_to_linear()
	return Vector4(l.r, l.g, l.b, _sombra.w)


static func _subir_pers() -> Vector4:
	var l: Color = Color(_sombra_pers.x, _sombra_pers.y, _sombra_pers.z).srgb_to_linear()
	return Vector4(l.r, l.g, l.b, _sombra_pers.w)


static func preparar_global() -> void:
	if _registrado:
		return
	_registrado = true
	RenderingServer.global_shader_parameter_add(PARAM_SOMBRA, RenderingServer.GLOBAL_VAR_TYPE_VEC4, _subir_mundo())
	RenderingServer.global_shader_parameter_add(PARAM_SOMBRA_PERS, RenderingServer.GLOBAL_VAR_TYPE_VEC4, _subir_pers())
	RenderingServer.global_shader_parameter_add(PARAM_RAMPA, RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(1.0 if _rampa else 0.0, 0.0, 0.0, 0.0))


## Mueve la sombra del mundo en vivo (para una herramienta de ajuste). `rgb` en sRGB, como un color del editor.
static func poner_sombra(rgb: Color, contraste: float) -> void:
	_sombra = Vector4(rgb.r, rgb.g, rgb.b, contraste)
	if _registrado:
		RenderingServer.global_shader_parameter_set(PARAM_SOMBRA, _subir_mundo())


## Igual, para personajes y criaturas. `rgb` en sRGB, igual que `poner_sombra` (se convierte a lineal al subirlo).
static func poner_sombra_pers(rgb: Color, contraste: float) -> void:
	_sombra_pers = Vector4(rgb.r, rgb.g, rgb.b, contraste)
	if _registrado:
		RenderingServer.global_shader_parameter_set(PARAM_SOMBRA_PERS, _subir_pers())


## Enciende o apaga la rampa toon del decorado en vivo, sin recompilar (todos los materiales a la vez).
static func poner_rampa(encendida: bool) -> void:
	_rampa = encendida
	if _registrado:
		RenderingServer.global_shader_parameter_set(PARAM_RAMPA, Vector4(1.0 if encendida else 0.0, 0.0, 0.0, 0.0))


static func sombra() -> Vector4:
	return _sombra


static func sombra_pers() -> Vector4:
	return _sombra_pers
