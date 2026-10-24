class_name TemaInterfaz
extends RefCounted

## TEMA COMÚN DE LA INTERFAZ (24/10; encargo de Pablo: «diseña marcos y pule la interfaz», referencia Zelda: Echoes of Wisdom).
## Un solo sitio con la paleta, las esquinas, la sombra, los márgenes y la fuente; todo lo que se pule lo lee de aquí en vez de repetir números:
##   · `tema()`         el Theme de Godot (Label, PanelContainer, Button, tooltip, ProgressBar). Se asigna con `control.theme = TemaInterfaz.tema()`.
##   · `caja_panel()`   el panel oscuro translúcido con borde cálido, esquinas redondas y sombra (rótulo de zona, pista «E», avisos).
##   · `contraste()`    la razón de contraste WCAG entre dos colores (la usan las pruebas y quien quiera comprobar un texto).
## Estilo EoW: iconos claros sobre fondo oscuro translúcido, marcos redondeados con borde dorado/cálido, texto claro con contorno oscuro.
## No cambia lógica ni tamaños de hit: solo cómo se pinta.

## --- Paleta ---
const FONDO_PANEL: Color = Color(0.05, 0.04, 0.08, 0.90)    ## oscuro translúcido: se lee sobre hielo, hierba, arena y cueva (prueba: contraste ≥ 7 en el peor caso)
const FONDO_PANEL_SUAVE: Color = Color(0.05, 0.04, 0.08, 0.78)
const BORDE_CALIDO: Color = Color(0.87, 0.71, 0.42)          ## el dorado cálido de los marcos
const BORDE_CALIDO_OSCURO: Color = Color(0.45, 0.32, 0.16)   ## el reborde de dentro, para dar relieve al marco
const TEXTO: Color = Color(1.0, 0.98, 0.94)                  ## texto claro, sin teñir de rosa ni de amarillo
const TEXTO_SUAVE: Color = Color(0.86, 0.82, 0.74)           ## texto secundario (sigue pasando el contraste 7 sobre FONDO_PANEL)
const CONTORNO: Color = Color(0.0, 0.0, 0.0, 0.95)
const SOMBRA: Color = Color(0.0, 0.0, 0.0, 0.55)
const TINTA_PERGAMINO: Color = Color("4e3a26")               ## texto sobre el pergamino de la mochila y el libro

## --- Medidas (px de diseño) ---
const ESQUINA_PX: int = 12
const BORDE_PX: int = 2
const SOMBRA_PX: int = 6
const MARGEN_X_PX: float = 14.0
const MARGEN_Y_PX: float = 7.0
const CONTORNO_PX: int = 5
const TAM_FUENTE: int = 18
const TAM_FUENTE_PEQUENO: int = 14

## Fuente: la primera de esta lista que tenga el sistema; si no hay ninguna, la de Godot (SystemFont cae sola a la de siempre).
const USAR_FUENTE_SISTEMA: bool = true
const FUENTES_PREFERIDAS: PackedStringArray = ["Trebuchet MS", "Segoe UI", "Noto Sans", "Verdana"]

static var _tema: Theme = null
static var _fuente: Font = null


## La fuente de la interfaz (compartida).
static func fuente() -> Font:
	if _fuente == null:
		if USAR_FUENTE_SISTEMA:
			var f := SystemFont.new()
			f.font_names = FUENTES_PREFERIDAS
			f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			f.hinting = TextServer.HINTING_LIGHT
			f.oversampling = 0.0
			_fuente = f
		else:
			_fuente = ThemeDB.fallback_font
	return _fuente


## Panel oscuro translúcido con borde cálido, esquinas redondas y sombra. `fondo` y `borde` se pueden cambiar (los avisos de calidad ponen el suyo).
static func caja_panel(fondo: Color = FONDO_PANEL, borde: Color = BORDE_CALIDO, ancho_borde: int = BORDE_PX) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(ancho_borde)
	s.set_corner_radius_all(ESQUINA_PX)
	s.anti_aliasing = true
	s.shadow_color = SOMBRA
	s.shadow_size = SOMBRA_PX
	s.shadow_offset = Vector2(0.0, 2.0)
	s.content_margin_left = MARGEN_X_PX
	s.content_margin_right = MARGEN_X_PX
	s.content_margin_top = MARGEN_Y_PX
	s.content_margin_bottom = MARGEN_Y_PX
	return s


## Botón en tres estados con la misma gramática que los paneles.
static func _caja_boton(fondo: Color, borde: Color) -> StyleBoxFlat:
	var s: StyleBoxFlat = caja_panel(fondo, borde, BORDE_PX)
	s.shadow_size = 0
	s.content_margin_top = 5.0
	s.content_margin_bottom = 5.0
	return s


## El Theme de Godot con todo lo anterior. Una sola instancia: todos los que lo piden comparten el recurso.
static func tema() -> Theme:
	if _tema != null:
		return _tema
	var t := Theme.new()
	t.default_font = fuente()
	t.default_font_size = TAM_FUENTE
	# Etiquetas: texto claro con contorno oscuro (se lee sobre cualquier fondo).
	t.set_color("font_color", "Label", TEXTO)
	t.set_color("font_outline_color", "Label", CONTORNO)
	t.set_constant("outline_size", "Label", CONTORNO_PX)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	# Paneles.
	t.set_stylebox("panel", "PanelContainer", caja_panel())
	t.set_stylebox("panel", "Panel", caja_panel())
	# Botones.
	t.set_stylebox("normal", "Button", _caja_boton(FONDO_PANEL, BORDE_CALIDO_OSCURO))
	t.set_stylebox("hover", "Button", _caja_boton(FONDO_PANEL.lightened(0.12), BORDE_CALIDO))
	t.set_stylebox("pressed", "Button", _caja_boton(FONDO_PANEL.darkened(0.2), BORDE_CALIDO))
	t.set_stylebox("focus", "Button", _caja_boton(Color(0, 0, 0, 0), BORDE_CALIDO))
	t.set_color("font_color", "Button", TEXTO)
	t.set_color("font_hover_color", "Button", Color(1.0, 1.0, 1.0))
	t.set_color("font_pressed_color", "Button", BORDE_CALIDO)
	t.set_color("font_outline_color", "Button", CONTORNO)
	t.set_constant("outline_size", "Button", 3)
	# Barras.
	var fondo_barra: StyleBoxFlat = caja_panel(Color(0.03, 0.03, 0.05, 0.85), BORDE_CALIDO_OSCURO, 2)
	fondo_barra.shadow_size = 0
	fondo_barra.content_margin_top = 0.0
	fondo_barra.content_margin_bottom = 0.0
	var relleno: StyleBoxFlat = caja_panel(Color(0.35, 0.85, 0.4), Color(0, 0, 0, 0), 0)
	relleno.shadow_size = 0
	t.set_stylebox("background", "ProgressBar", fondo_barra)
	t.set_stylebox("fill", "ProgressBar", relleno)
	# Tooltips (los de la mochila): el mismo panel y texto claro.
	var tip: StyleBoxFlat = caja_panel(FONDO_PANEL, BORDE_CALIDO)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXTO)
	t.set_color("font_outline_color", "TooltipLabel", Color(0, 0, 0, 0))
	t.set_constant("outline_size", "TooltipLabel", 0)
	t.set_font_size("font_size", "TooltipLabel", TAM_FUENTE_PEQUENO + 2)
	# Separadores.
	var linea := StyleBoxLine.new()
	linea.color = BORDE_CALIDO_OSCURO
	linea.thickness = 2
	t.set_stylebox("separator", "HSeparator", linea)
	_tema = t
	return t


## Luminancia relativa WCAG (sRGB lineal).
static func luminancia(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * float(f.call(c.r)) + 0.7152 * float(f.call(c.g)) + 0.0722 * float(f.call(c.b))


## Razón de contraste WCAG entre un texto y un fondo opaco (1..21).
static func contraste(texto: Color, fondo: Color) -> float:
	var l1: float = luminancia(texto)
	var l2: float = luminancia(fondo)
	return (maxf(l1, l2) + 0.05) / (minf(l1, l2) + 0.05)


## Contraste del texto contra un fondo translúcido en el PEOR caso: lo que haya detrás blanco puro o negro puro. Es el peor de los dos.
static func contraste_peor(texto: Color, fondo: Color) -> float:
	var peor: float = 1.0e9
	for detras in [Color.WHITE, Color.BLACK]:
		var f: Color = Color(fondo.r, fondo.g, fondo.b, 1.0).lerp(detras, 1.0 - fondo.a)
		peor = minf(peor, contraste(texto, f))
	return peor
