class_name RotuloZona3D
extends CanvasLayer

## RÓTULO DE ENTRADA A UNA ZONA (23/10, el `RegionEntryDemo` de EoW: el nombre del sitio al entrar por primera vez). Un texto grande centrado en el tercio de arriba que
## entra, se queda y se va solo. Lo pide Zonas3D con la clave `rotulo=` de una línea `; zona`; «ya visto» es una flag (ver Zonas3D), así que no se repite.
##
## Un rótulo nuevo sustituye al que aún se esté viendo.

const NOMBRE: String = "RotuloZona"
const CAPA: int = 6
const T_ENTRA: float = 0.6
const T_QUEDA: float = 2.4
const T_SALE: float = 1.0
const TAMANO_FUENTE: int = 46
const BORDE: int = 10
const Y_RELATIVA: float = 0.2             ## fracción de la altura de la pantalla donde va el texto
const COLOR_TEXTO: Color = Color(1.0, 0.95, 0.8)

var etiqueta: Label = null
var texto: String = ""
var tween: Tween = null


## Pone el rótulo en la ventana del árbol de `donde`. Devuelve el nodo (null si `donde` no está en un árbol).
static func mostrar(donde: Node, p_texto: String) -> RotuloZona3D:
	if donde == null or not donde.is_inside_tree():
		return null
	var raiz: Node = donde.get_tree().root
	var previo: Node = raiz.get_node_or_null(NOMBRE)
	if previo != null:
		raiz.remove_child(previo)
		previo.queue_free()
	var r := RotuloZona3D.new()
	r.name = NOMBRE
	r.layer = CAPA
	r.texto = p_texto
	raiz.add_child(r)
	r._montar()
	return r


func _montar() -> void:
	etiqueta = Label.new()
	etiqueta.text = texto
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	etiqueta.anchor_top = Y_RELATIVA
	etiqueta.anchor_bottom = Y_RELATIVA
	etiqueta.offset_top = 0.0
	etiqueta.offset_bottom = float(TAMANO_FUENTE) * 1.6
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_size_override("font_size", TAMANO_FUENTE)
	etiqueta.add_theme_color_override("font_color", COLOR_TEXTO)
	etiqueta.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	etiqueta.add_theme_constant_override("outline_size", BORDE)
	etiqueta.modulate.a = 0.0
	add_child(etiqueta)
	tween = create_tween()
	tween.tween_property(etiqueta, "modulate:a", 1.0, T_ENTRA).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(T_QUEDA)
	tween.tween_property(etiqueta, "modulate:a", 0.0, T_SALE).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(queue_free)
