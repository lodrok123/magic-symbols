class_name PresentacionJefe
extends CanvasLayer

## PRESENTACIÓN DE JEFE (21/11/2026, Pablo; visto en Mages of Mystralia, docs/MAGES_OF_MYSTRALIA_2026-11-21.md O8). Solo para JEFES.
## Dos cosas en una capa de pantalla:
##   1. El RÓTULO: un epíteto pequeño encima («Guardián del foso») y el NOMBRE grande debajo, en el tercio de abajo de la pantalla. Entra con un fundido,
##      se queda DURA_S y se va. La cámara NO se mueve (decisión de Pablo: los cambios de vista marean); el jefe se presenta dentro de la vista de siempre.
##   2. La BARRA DE VIDA del jefe, arriba en el centro (la misma forma que la de `Combate3D._construir_barra_jefe`), que aparece cuando acaba el rótulo.
##      La parte blanca es la vida recién perdida: se queda un momento y baja despacio.
## Uso: `var p := PresentacionJefe.crear(nodo, "Guardián del foso", "Dragón")`, `p.mostrar_titulo()`, luego `p.mostrar_barra()` y `p.fijar_vida(fr)`.
## Todo lo que se ajusta está en `static var` (para tocarlo en vivo desde un laboratorio).

signal titulo_terminado

static var ENTRA_S: float = 0.6            ## fundido de entrada del rótulo
static var DURA_S: float = 3.2             ## tiempo que se queda entero
static var SALE_S: float = 0.8             ## fundido de salida
static var TAM_EPITETO: int = 30
static var TAM_NOMBRE: int = 66
static var ALTO_ROTULO: float = 0.66       ## dónde va el epíteto (fracción del alto de pantalla, desde arriba)
static var SEPARACION: float = 0.085       ## cuánto más abajo va el nombre (fracción del alto de pantalla)
static var PERDIDA_ESPERA_S: float = 0.5   ## lo que se queda la vida perdida (blanco) antes de bajar
static var PERDIDA_VEL: float = 0.6        ## fracción de barra por segundo a la que baja

const ANCHO_BARRA: float = 600.0
const COLOR_TEXTO: Color = Color(1.0, 0.97, 0.9)
const COLOR_CONTORNO: Color = Color(0.08, 0.05, 0.04)
const COLOR_VIDA: Color = Color(0.85, 0.22, 0.12)

var titulo_visible: bool = false
var barra_visible: bool = false
var vida_fr: float = 1.0
var _vida_mostrada: float = 1.0
var _espera_perdida: float = 0.0
var _rotulo: Control = null
var _epiteto: Label = null
var _nombre: Label = null
var _barra: Control = null
var _relleno: ColorRect = null
var _perdida: ColorRect = null
var _tween: Tween = null


## Crea la capa colgada de `padre` con el epíteto y el nombre ya puestos (los «_» se leen como espacios, para poder escribirlos en un mapa).
static func crear(padre: Node, epiteto: String, nombre: String) -> PresentacionJefe:
	var p := PresentacionJefe.new()
	p.name = "PresentacionJefe"
	p.layer = 21
	padre.add_child(p)
	p._montar(epiteto.replace("_", " "), nombre.replace("_", " "))
	return p


## Lo que dura el rótulo entero (entrar + quedarse + salir).
static func duracion_titulo() -> float:
	return ENTRA_S + DURA_S + SALE_S


func _montar(epiteto: String, nombre: String) -> void:
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Noto Serif", "DejaVu Serif"])
	serif.font_weight = 700
	_rotulo = Control.new()
	_rotulo.name = "Rotulo"
	_rotulo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotulo.modulate.a = 0.0
	add_child(_rotulo)
	_epiteto = _linea(epiteto, TAM_EPITETO, serif, ALTO_ROTULO, 6)
	_nombre = _linea(nombre.to_upper(), TAM_NOMBRE, serif, ALTO_ROTULO + SEPARACION, 12)
	_montar_barra(nombre)


func _linea(texto: String, tam: int, fuente: Font, alto: float, contorno: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = alto
	l.anchor_bottom = alto
	l.offset_top = -float(tam) * 0.6
	l.offset_bottom = float(tam) * 0.6
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", fuente)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", COLOR_TEXTO)
	l.add_theme_color_override("font_outline_color", COLOR_CONTORNO)
	l.add_theme_constant_override("outline_size", contorno)
	_rotulo.add_child(l)
	return l


func _montar_barra(nombre: String) -> void:
	_barra = Control.new()
	_barra.name = "Barra"
	_barra.set_anchors_preset(Control.PRESET_FULL_RECT)
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.visible = false
	add_child(_barra)
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.75)
	fondo.anchor_left = 0.5
	fondo.anchor_right = 0.5
	fondo.offset_left = -ANCHO_BARRA * 0.5
	fondo.offset_right = ANCHO_BARRA * 0.5
	fondo.offset_top = 30.0
	fondo.offset_bottom = 54.0
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.add_child(fondo)
	_perdida = ColorRect.new()
	_perdida.color = Color(1, 1, 1, 0.55)
	_perdida.position = Vector2(3, 3)
	_perdida.size = Vector2(ANCHO_BARRA - 6.0, 18)
	fondo.add_child(_perdida)
	_relleno = ColorRect.new()
	_relleno.color = COLOR_VIDA
	_relleno.position = Vector2(3, 3)
	_relleno.size = Vector2(ANCHO_BARRA - 6.0, 18)
	fondo.add_child(_relleno)
	var rotulo := Label.new()
	rotulo.text = nombre
	rotulo.anchor_left = 0.5
	rotulo.anchor_right = 0.5
	rotulo.offset_left = -ANCHO_BARRA * 0.5
	rotulo.offset_right = ANCHO_BARRA * 0.5
	rotulo.offset_top = 6.0
	rotulo.offset_bottom = 30.0
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.add_theme_color_override("font_outline_color", COLOR_CONTORNO)
	rotulo.add_theme_constant_override("outline_size", 6)
	_barra.add_child(rotulo)


## Enseña el rótulo (fundido, espera, fundido) y avisa con `titulo_terminado` al acabar.
func mostrar_titulo() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	titulo_visible = true
	_rotulo.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_rotulo, "modulate:a", 1.0, ENTRA_S)
	_tween.tween_interval(DURA_S)
	_tween.tween_property(_rotulo, "modulate:a", 0.0, SALE_S)
	_tween.tween_callback(_fin_titulo)


func _fin_titulo() -> void:
	titulo_visible = false
	titulo_terminado.emit()


func mostrar_barra() -> void:
	barra_visible = true
	_barra.visible = true


func ocultar_barra() -> void:
	barra_visible = false
	_barra.visible = false


## La vida que queda (0..1). La parte perdida se queda en blanco un momento.
func fijar_vida(fr: float) -> void:
	var nueva: float = clampf(fr, 0.0, 1.0)
	if nueva < vida_fr:
		_espera_perdida = PERDIDA_ESPERA_S
	vida_fr = nueva
	_relleno.size.x = (ANCHO_BARRA - 6.0) * vida_fr


func _process(delta: float) -> void:
	if _espera_perdida > 0.0:
		_espera_perdida -= delta
	elif _vida_mostrada > vida_fr:
		_vida_mostrada = maxf(vida_fr, _vida_mostrada - PERDIDA_VEL * delta)
	_perdida.size.x = (ANCHO_BARRA - 6.0) * _vida_mostrada
