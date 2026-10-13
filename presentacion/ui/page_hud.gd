extends Control

## LAS TRES PÁGINAS Y LA VOLTERETA, SIEMPRE A LA VISTA.
##
## El libro enseña las pestañas de las páginas, pero solo cuando está abierto, y
## la recarga corre con el libro CERRADO. Esto las repite abajo en el centro:
## de qué elemento es cada página, cuál está seleccionada, y cuánto le queda de
## recarga (un barrido oscuro que se va vaciando). A la derecha, la voltereta.
##
## Es solo interfaz: lee del Spellcaster y del jugador, no decide nada.

const RADIO: float = 17.0
const SEPARACION: float = 48.0
const TINTA: Color = Color(0.96, 0.94, 0.88, 0.95)
const TINTA_SUAVE: Color = Color(0.96, 0.94, 0.88, 0.55)
const VELO: Color = Color(0.0, 0.0, 0.0, 0.6)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var caster = get_tree().get_first_node_in_group("spellcaster")
	if caster == null:
		return

	var total: int = Repertoire.pages_available(caster.PAGES)
	var y: float = size.y - 44.0
	var x0: float = size.x * 0.5 - float(total - 1) * 0.5 * SEPARACION

	for i in range(total):
		var centro := Vector2(x0 + float(i) * SEPARACION, y)
		var activa: bool = i == caster.page
		var radio: float = RADIO * (1.15 if activa else 1.0)

		draw_circle(centro, radio + 2.0, Color(0.05, 0.05, 0.08, 0.65))
		var datos: RuneData = caster.page_element_data(i)
		if datos != null:
			var tinte: Color = datos.color
			if not caster.page_ready(i):
				tinte.a = 0.35
			draw_circle(centro, radio, tinte)
		else:
			draw_circle(centro, radio, Color(0.3, 0.3, 0.34, 0.5))

		# La recarga: un barrido oscuro sobre la parte que falta.
		var resto: float = caster.page_cooldown_fraction(i)
		if resto > 0.0:
			draw_arc(centro, radio * 0.5, -PI * 0.5, -PI * 0.5 + TAU * resto, 24, VELO, radio, true)

		draw_arc(centro, radio, 0.0, TAU, 24, TINTA if activa else TINTA_SUAVE,
			2.5 if activa else 1.5, true)
		_texto(centro + Vector2(0.0, 5.0), str(i + 1), TINTA)

	# La voltereta.
	var jugador = get_tree().get_first_node_in_group("player")
	if jugador != null and jugador.has_method("roll_cooldown_fraction"):
		var c := Vector2(x0 + float(total) * SEPARACION + 14.0, y)
		var listo: float = jugador.roll_cooldown_fraction()
		draw_circle(c, RADIO * 0.8, Color(0.05, 0.05, 0.08, 0.65))
		draw_circle(c, RADIO * 0.7, Color(0.62, 0.78, 0.95, 0.9 if listo <= 0.0 else 0.35))
		if listo > 0.0:
			draw_arc(c, RADIO * 0.35, -PI * 0.5, -PI * 0.5 + TAU * listo, 24, VELO, RADIO * 0.7, true)
		_texto(c + Vector2(0.0, 22.0 + RADIO * 0.5), "Espacio", TINTA_SUAVE)


func _texto(pos: Vector2, texto: String, color: Color) -> void:
	var fuente: Font = ThemeDB.fallback_font
	var ancho: float = fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(fuente, pos - Vector2(ancho * 0.5, 0.0), texto,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
