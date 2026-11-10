extends Node2D
## La hoja toma su cara del libro ya dibujado, antes de la mano.

const TIRAS: int = 24
const MARGEN_LOMO: float = 16.0
const LOMO: float = 745.0
const BORDE_IZQ: float = 141.0
const BORDE_DER: float = 1339.0
const ARRIBA_LOMO: float = 112.0
const ABAJO_LOMO: float = 831.0
const ARRIBA_BORDE: float = 96.0
const ABAJO_BORDE: float = 817.0
const CARA = preload("res://presentacion/ui/hoja_grimorio.gdshader")

var _copia := BackBufferCopy.new()
var _papel := Node2D.new()
var _cara := Node2D.new()
var _lamina: Texture2D
var _libro: Rect2
var _factor: float
var _sentido: float
var _avance: float
var _contorno: Rect2


func _ready() -> void:
	_copia.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(_copia)
	_papel.draw.connect(_dibujar_papel)
	add_child(_papel)
	var material_cara := ShaderMaterial.new()
	material_cara.shader = CARA
	_cara.material = material_cara
	_cara.draw.connect(_dibujar_cara)
	add_child(_cara)
	hide()


func mostrar(lamina: Texture2D, libro: Rect2, factor: float, sentido: float, avance: float, contorno: Rect2) -> Vector2:
	_lamina = lamina
	_libro = libro
	_factor = factor
	_sentido = sentido
	_avance = avance
	_contorno = contorno
	visible = avance > 0.0 and avance < 1.0
	_papel.queue_redraw()
	_cara.queue_redraw()
	var superior := _proyectar(1.0, false)
	var inferior := _proyectar(1.0, true)
	return superior.lerp(inferior, 0.58)


func _lado() -> float:
	return _sentido if _avance < 0.5 else -_sentido


func _punto(u: float, abajo: bool) -> Vector2:
	if _contorno.has_area():
		var lado: float = _lado()
		var x: float = _contorno.end.x if lado > 0.0 else _contorno.position.x
		var y: float = _contorno.end.y if abajo else _contorno.position.y
		var lomo: float = _contorno.get_center().x + lado * MARGEN_LOMO
		return _libro.position + Vector2(lerpf(lomo, x, u), y) * _factor
	var borde: float = BORDE_DER if _lado() > 0.0 else BORDE_IZQ
	var y_lomo: float = ABAJO_LOMO if abajo else ARRIBA_LOMO
	var y_borde: float = ABAJO_BORDE if abajo else ARRIBA_BORDE
	return _libro.position + Vector2(lerpf(LOMO, borde, u), lerpf(y_lomo, y_borde, u)) * _factor


func _proyectar(u: float, abajo: bool) -> Vector2:
	var base := _punto(u, abajo)
	var lomo := _punto(0.0, abajo)
	var angulo: float = PI * _avance
	var alto: float = sin(angulo) * u
	var ancho: float = absf(cos(angulo)) * (1.0 + 0.4 * alto * (1.0 - u))
	return Vector2(lerpf(lomo.x, base.x, ancho), base.y + alto * (-40.0 if abajo else 17.0) * _factor)


func _dibujar_papel() -> void:
	# Repone el papel bajo la cara móvil para que la tinta no se vea dos veces.
	var puntos := PackedVector2Array([_punto(0.0, false), _punto(1.0, false), _punto(1.0, true), _punto(0.0, true)])
	var uv := PackedVector2Array()
	for punto in puntos:
		uv.append((punto - _libro.position) / _libro.size)
	_papel.draw_colored_polygon(puntos, Color.WHITE, uv, _lamina)

	var alto: float = sin(PI * _avance)
	var superior := _proyectar(1.0, false)
	var inferior := _proyectar(1.0, true)
	var alcance := Vector2(_lado() * 85.0, 18.0) * alto * _factor
	var sombra := Color(0.22, 0.12, 0.06, 0.32 * alto)
	var transparente := Color(sombra, 0.0)
	_papel.draw_polygon(PackedVector2Array([superior, superior + alcance, inferior + alcance, inferior]),
		PackedColorArray([sombra, transparente, transparente, sombra]))


func _dibujar_cara() -> void:
	var pantalla := get_viewport_rect().size
	var transformacion := get_global_transform_with_canvas()
	var alto: float = sin(PI * _avance)
	for i in TIRAS:
		var a := float(i) / TIRAS
		var b := float(i + 1) / TIRAS
		var puntos := PackedVector2Array([_proyectar(a, false), _proyectar(b, false), _proyectar(b, true), _proyectar(a, true)])
		if absf(puntos[1].x - puntos[0].x) < 0.01:
			continue
		var uv := PackedVector2Array()
		for punto in [_punto(a, false), _punto(b, false), _punto(b, true), _punto(a, true)]:
			uv.append((transformacion * punto) / pantalla)
		var luz: float = 1.0 - alto * (0.07 + 0.18 * sin((a + b) * PI * 0.5))
		_cara.draw_colored_polygon(puntos, Color(luz, luz, luz), uv, _lamina)
