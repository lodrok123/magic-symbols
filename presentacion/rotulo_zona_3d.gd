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
const COLOR_TEXTO: Color = TemaInterfaz.TEXTO          ## claro sobre el panel oscuro del tema (contraste ≥ 7 en el peor caso: lo mide prueba_tema_interfaz)
const FONDO: Color = TemaInterfaz.FONDO_PANEL
const BORDE_PANEL_PX: int = 3                           ## el cartel lleva un borde cálido más grueso que los paneles pequeños
const MARGEN_X_PX: float = 36.0
const MARGEN_Y_PX: float = 12.0

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
	etiqueta.theme = TemaInterfaz.tema()
	etiqueta.text = texto
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Un cartel que se encoge al texto (no una barra de lado a lado), centrado en el tercio de arriba.
	etiqueta.anchor_left = 0.5
	etiqueta.anchor_right = 0.5
	etiqueta.anchor_top = Y_RELATIVA
	etiqueta.anchor_bottom = Y_RELATIVA
	etiqueta.grow_horizontal = Control.GROW_DIRECTION_BOTH
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_size_override("font_size", TAMANO_FUENTE)
	etiqueta.add_theme_color_override("font_color", COLOR_TEXTO)
	etiqueta.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	etiqueta.add_theme_constant_override("outline_size", BORDE)
	var caja: StyleBoxFlat = TemaInterfaz.caja_panel(FONDO, TemaInterfaz.BORDE_CALIDO, BORDE_PANEL_PX)
	caja.content_margin_left = MARGEN_X_PX
	caja.content_margin_right = MARGEN_X_PX
	caja.content_margin_top = MARGEN_Y_PX
	caja.content_margin_bottom = MARGEN_Y_PX
	etiqueta.add_theme_stylebox_override("normal", caja)
	etiqueta.modulate.a = 0.0
	add_child(etiqueta)
	tween = create_tween()
	tween.tween_property(etiqueta, "modulate:a", 1.0, T_ENTRA).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(T_QUEDA)
	tween.tween_property(etiqueta, "modulate:a", 0.0, T_SALE).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(queue_free)
