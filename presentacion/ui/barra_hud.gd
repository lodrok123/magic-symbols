class_name BarraHud
extends Control

## BARRA DE VIDA / TINTA AL ESTILO DE LA INTERFAZ (24/10): pista redondeada oscura, relleno del color de la barra con un brillo arriba y borde cálido,
## y el rótulo ENCIMA con contorno oscuro (así se lee aunque el relleno sea verde claro). Pieza suelta y barata de montar:
##     var b := BarraHud.new(); capa.add_child(b); b.configurar("Vida", Color(0.35, 0.85, 0.4), 0.8)
##     b.poner_fraccion(0.5)     # cada vez que cambie
## Desde el 24/10 la usa `HudEoW` (vida y tinta en pantalla, con los frascos y el consumible equipado). Esta pieza no decide nada del juego.

const ANCHO_PX: float = 244.0
const ALTO_PX: float = 14.0
const ALTO_ROTULO_PX: float = 18.0
const TAM_ROTULO: int = 14
const ESQUINA_PX: int = 7
const BORDE_PX: int = 2
const MARGEN_RELLENO_PX: float = 2.0
const FONDO_PISTA: Color = Color(0.03, 0.03, 0.05, 0.88)
const BRILLO_ARRIBA: Color = Color(1, 1, 1, 0.28)           ## banda clara en la mitad de arriba del relleno
const T_SUAVIZADO_S: float = 0.18

var rotulo: String = ""
var color: Color = Color(0.35, 0.85, 0.4)
var fraccion: float = 1.0
var _mostrada: float = 1.0                                   ## la fracción que se ve (se acerca a `fraccion` suavemente)


func _init() -> void:
	custom_minimum_size = Vector2(ANCHO_PX, ALTO_ROTULO_PX + ALTO_PX)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configurar(p_rotulo: String, p_color: Color, p_fraccion: float) -> void:
	rotulo = p_rotulo
	color = p_color
	fraccion = clampf(p_fraccion, 0.0, 1.0)
	_mostrada = fraccion
	queue_redraw()


func poner_fraccion(f: float) -> void:
	fraccion = clampf(f, 0.0, 1.0)
	set_process(true)


## 24/10 (HUD estilo Echoes of Wisdom, `HudEoW`): cambiar rótulo, color o ancho sin reiniciar la animación de la barra. Solo redibujan si algo cambió.
func poner_rotulo(p_rotulo: String) -> void:
	if p_rotulo != rotulo:
		rotulo = p_rotulo
		queue_redraw()


func poner_color(p_color: Color) -> void:
	if not p_color.is_equal_approx(color):
		color = p_color
		queue_redraw()


func poner_ancho(ancho: float) -> void:
	custom_minimum_size.x = ancho
	size.x = ancho
	queue_redraw()


func _process(delta: float) -> void:
	_mostrada = move_toward(_mostrada, fraccion, delta / T_SUAVIZADO_S)
	queue_redraw()
	if is_equal_approx(_mostrada, fraccion):
		set_process(false)


func _draw() -> void:
	var f: Font = TemaInterfaz.fuente()
	if rotulo != "":
		draw_string_outline(f, Vector2(2.0, ALTO_ROTULO_PX - 4.0), rotulo, HORIZONTAL_ALIGNMENT_LEFT, size.x, TAM_ROTULO, TemaInterfaz.CONTORNO_PX, TemaInterfaz.CONTORNO)
		draw_string(f, Vector2(2.0, ALTO_ROTULO_PX - 4.0), rotulo, HORIZONTAL_ALIGNMENT_LEFT, size.x, TAM_ROTULO, TemaInterfaz.TEXTO)
	var pista := Rect2(0.0, ALTO_ROTULO_PX, size.x, ALTO_PX)
	var caja := StyleBoxFlat.new()
	caja.bg_color = FONDO_PISTA
	caja.border_color = TemaInterfaz.BORDE_CALIDO
	caja.set_border_width_all(BORDE_PX)
	caja.set_corner_radius_all(ESQUINA_PX)
	caja.anti_aliasing = true
	caja.draw(get_canvas_item(), pista)
	var dentro: Rect2 = pista.grow(-(float(BORDE_PX) + MARGEN_RELLENO_PX - 1.0))
	var ancho: float = dentro.size.x * _mostrada
	if ancho >= 1.0:
		var rel := StyleBoxFlat.new()
		rel.bg_color = color
		rel.set_corner_radius_all(maxi(ESQUINA_PX - BORDE_PX - 1, 2))
		rel.anti_aliasing = true
		var r := Rect2(dentro.position, Vector2(ancho, dentro.size.y))
		rel.draw(get_canvas_item(), r)
		var brillo := StyleBoxFlat.new()
		brillo.bg_color = BRILLO_ARRIBA
		brillo.set_corner_radius_all(2)
		brillo.draw(get_canvas_item(), Rect2(r.position + Vector2(2.0, 1.0), Vector2(maxf(r.size.x - 4.0, 0.0), r.size.y * 0.4)))
