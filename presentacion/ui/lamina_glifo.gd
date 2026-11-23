class_name LaminaGlifo
extends CanvasLayer

## LA FICHA DE GLIFO (23/11, sesión HECHIZOS; PLAN_HECHIZOS §4 H5, H6 y H8): una página CORTA que enseña UNA runa (glifo o sello): la runa grande en su disco, el nombre de la runa del futhark como título,
## su verbo en el color de la runa y una frase que se escribe letra a letra (el «has conseguido…» de Zelda; la lámina de «nuevo objeto» de Mages of Mystralia). Nada de antes/después dibujados ni
## de combinaciones: el uso se aprende en la sala, con `PistaGlifo`. Los textos salen de `FichasGlifo` (PROVISIONALES; los decide Pablo).
##
##   LaminaGlifo.mostrar(padre, id, nueva, cierre_propio)
##     nueva         true = «NUEVA RUNA» / «NUEVO SELLO» (se acaba de conseguir) · false = «RUNA» / «SELLO» (consulta)
##     cierre_propio false = la cierra quien la mostró (`cerrar()`); la ceremonia del cofre lo hace así y pone su botón «Continuar» (capa 80) encima, en la franja libre de abajo.
##                   true  = pausa el árbol, enseña su propio «Continuar» y se cierra con E / Espacio / Intro / A o con clic (la 1.ª pulsación completa el texto si va a medias).
## Se dibuja desde una referencia de 1920×1080 escalada al viewport sin deformar. Capa 79.

signal cerrada

const REF: Vector2 = Vector2(1920.0, 1080.0)
const CARTA: Vector2 = Vector2(1000.0, 400.0)
const CARTA_Y: float = 400.0
const T_ENTRADA: float = 0.25
const T_SALIDA: float = 0.2
const LETRAS_POR_S: float = 60.0
const T_GUARDA: float = 0.2                     ## s tras abrirse en los que una pulsación aún no cuenta (la que la abrió)
const PERGAMINO: Color = Color(0.96, 0.91, 0.79)
const BRONCE: Color = Color(0.72, 0.52, 0.25)
const ORO: Color = Color(0.95, 0.78, 0.38)
const TINTA: Color = Color(0.17, 0.10, 0.07)
const COLOR_FORMA: Color = Color(0.13, 0.46, 0.60)
const COLOR_POTENCIA: Color = Color(0.72, 0.22, 0.14)
const COLORES_SELLO: Dictionary = {
	"fuego": Color(1.0, 0.55, 0.2), "agua": Color(0.25, 0.55, 1.0), "tierra": Color(0.78, 0.55, 0.28), "viento": Color(0.6, 0.9, 0.55),
	"rayo": Color(1.0, 0.9, 0.25), "hielo": Color(0.55, 0.85, 1.0),
}

var id: String = ""
var nueva: bool = true
var cierre_propio: bool = false

var _lienzo: Control
var _fondo: Control
var _carta: Panel
var _disco: _Disco
var _frase: Label
var _t: float = 0.0
var _letras: float = 0.0
var _cerrando: bool = false
var _t_cierre: float = 0.0
var _pauso: bool = false
var _congelada: bool = false


static func mostrar(padre: Node, p_id: String, p_nueva: bool = true, p_cierre_propio: bool = false) -> LaminaGlifo:
	var l := LaminaGlifo.new()
	l.id = p_id
	l.nueva = p_nueva
	l.cierre_propio = p_cierre_propio
	l.name = "LaminaGlifo"
	padre.add_child(l)
	return l


## El TÍTULO de la lámina: el nombre de la runa del futhark con mayúscula inicial («Eihwaz»), de `GestureLibrary.BIBLIA[id].nombre_runa` (solo la primera palabra: viento es «uruz (variante…)»).
## `altura` no está en la biblia: usa la de `levitacion` («Tiwaz»). Sin entrada, el nombre visible del glifo.
static func titulo_de(p_id: String) -> String:
	if FichasGlifo.titulo(p_id) != "":
		return FichasGlifo.titulo(p_id)
	var clave: String = "levitacion" if p_id == "altura" else p_id
	var n: String = String((GestureLibrary.BIBLIA.get(clave, {}) as Dictionary).get("nombre_runa", "")).strip_edges().split(" ")[0]
	if n == "":
		n = Sigils.nombre_visible(p_id)
	return n.substr(0, 1).to_upper() + n.substr(1)


## Color de la runa: el del elemento (sellos) o el de su familia.
static func color_de(p_id: String) -> Color:
	match FichasGlifo.familia(p_id):
		"sello":
			return Pulso3D.COLORES.get(p_id, COLORES_SELLO.get(p_id, Color(1.0, 0.6, 0.2)))
		"potencia":
			return COLOR_POTENCIA
	return COLOR_FORMA


func _ready() -> void:
	layer = 79
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir()
	_ajustar()
	get_viewport().size_changed.connect(_ajustar)
	if cierre_propio and is_inside_tree() and not get_tree().paused:
		get_tree().paused = true
		_pauso = true


func _exit_tree() -> void:
	_soltar_pausa()


func _soltar_pausa() -> void:
	if _pauso and is_inside_tree():
		get_tree().paused = false
	_pauso = false


# ---------------------------------------------------------------------------------------------------------------------
#  Construcción
# ---------------------------------------------------------------------------------------------------------------------

func _etiqueta(p_nombre: String, texto: String, pos: Vector2, tam: Vector2, tam_fuente: int, col: Color, centrado: bool = false, ajuste: bool = false) -> Label:
	var l := Label.new()
	l.name = p_nombre
	if ajuste:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART      # ANTES del texto y del tamaño: si no, el mínimo es la línea entera y el Label se ensancha
	l.text = texto
	l.position = pos
	l.size = tam
	l.add_theme_font_override("font", TemaInterfaz.fuente())
	l.add_theme_font_size_override("font_size", tam_fuente)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centrado else HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ajuste:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		l.clip_text = true
	return l


func _construir() -> void:
	var sello: bool = FichasGlifo.es_sello(id)
	var col: Color = color_de(id)
	var col_texto: Color = col.darkened(0.25) if sello else col
	# Fondo oscurecido (~55 %) con viñeta.
	_fondo = Control.new()
	_fondo.name = "Fondo"
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fondo.mouse_filter = Control.MOUSE_FILTER_STOP if cierre_propio else Control.MOUSE_FILTER_IGNORE
	add_child(_fondo)
	var vel := ColorRect.new()
	vel.color = Color(0.02, 0.01, 0.01, 0.55)
	vel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fondo.add_child(vel)
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.45, 1.0])
	gr.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.55)])
	var tex := GradientTexture2D.new()
	tex.gradient = gr
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var vineta := TextureRect.new()
	vineta.texture = tex
	vineta.stretch_mode = TextureRect.STRETCH_SCALE
	vineta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vineta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fondo.add_child(vineta)
	# El lienzo de referencia.
	_lienzo = Control.new()
	_lienzo.name = "Lienzo"
	_lienzo.size = REF
	_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lienzo)
	# Rótulo entre dos líneas doradas.
	var rotulo: String = ("NUEVO SELLO" if nueva else "SELLO") if sello else ("NUEVA RUNA" if nueva else "RUNA")
	_lienzo.add_child(_etiqueta("Rotulo", rotulo, Vector2(760.0, 318.0), Vector2(400.0, 48.0), 34, ORO, true))
	for x in [500.0, 1170.0]:
		var linea := ColorRect.new()
		linea.color = Color(ORO, 0.85)
		linea.position = Vector2(x, 340.0)
		linea.size = Vector2(250.0, 2.0)
		linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lienzo.add_child(linea)
	# La tarjeta de pergamino con borde de bronce.
	_carta = Panel.new()
	_carta.name = "Carta"
	var sb := StyleBoxFlat.new()
	sb.bg_color = PERGAMINO
	sb.border_color = BRONCE
	sb.set_border_width_all(7)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 24
	_carta.add_theme_stylebox_override("panel", sb)
	_carta.position = Vector2((REF.x - CARTA.x) * 0.5, CARTA_Y)
	_carta.size = CARTA
	_carta.pivot_offset = CARTA * 0.5
	_carta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.add_child(_carta)
	# Columna izquierda: la runa sobre un disco que brilla.
	_disco = _Disco.new()
	_disco.name = "Disco"
	_disco.position = Vector2(30.0, 35.0)
	_disco.size = Vector2(330.0, 330.0)
	_disco.color = col
	_disco.textura = _textura(id)
	_disco.futhark = _futhark(id)
	_disco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carta.add_child(_disco)
	# Columna derecha: el TÍTULO (el nombre de la runa del futhark), el VERBO en el color de la runa y la FRASE que se escribe sola.
	_carta.add_child(_etiqueta("Nombre", titulo_de(id), Vector2(390.0, 56.0), Vector2(570.0, 84.0), 68, TINTA))
	_carta.add_child(_etiqueta("Verbo", FichasGlifo.verbo(id), Vector2(390.0, 148.0), Vector2(570.0, 50.0), 38, col_texto))
	var sep := ColorRect.new()
	sep.color = Color(BRONCE, 0.7)
	sep.position = Vector2(390.0, 208.0)
	sep.size = Vector2(570.0, 2.0)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carta.add_child(sep)
	_frase = _etiqueta("Frase", FichasGlifo.frase(id), Vector2(390.0, 226.0), Vector2(570.0, 130.0), 31, TINTA, false, true)
	_frase.visible_characters = 0
	_carta.add_child(_frase)
	# Su propio «Continuar» (solo con cierre propio; si no, lo pone quien la muestra en la franja libre de abajo).
	if cierre_propio:
		var aviso := Button.new()
		aviso.name = "Continuar"
		aviso.text = "Continuar  ·  E / Espacio / Intro / A"
		aviso.focus_mode = Control.FOCUS_NONE
		aviso.position = Vector2(REF.x * 0.5 - 230.0, 960.0)
		aviso.size = Vector2(460.0, 52.0)
		aviso.pressed.connect(_pulsar)
		_lienzo.add_child(aviso)



## La runa que se dibuja y se nombra: `altura` no tiene PNG ni entrada en la biblia (se traza como ᛏ `levitacion`, su alias en Sigils.ALIAS_V2).
func _runa_de(p_id: String) -> String:
	return "levitacion" if p_id == "altura" else p_id


func _textura(p_id: String) -> Texture2D:
	var t: Texture2D = Sigils.GLYPHS.get(_runa_de(p_id)) as Texture2D
	if t == null:
		var ruta: String = "res://art/ui/glyphs/%s.png" % p_id          # los elementos tienen su PNG aparte
		if ResourceLoader.exists(ruta):
			t = load(ruta) as Texture2D
	return t


func _futhark(p_id: String) -> String:
	return String((GestureLibrary.BIBLIA.get(_runa_de(p_id), {}) as Dictionary).get("futhark", ""))


func _ajustar() -> void:
	if _lienzo == null or not is_inside_tree():
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var s: float = minf(vp.x / REF.x, vp.y / REF.y)
	_lienzo.scale = Vector2(s, s)
	_lienzo.position = (vp - REF * s) * 0.5


# ---------------------------------------------------------------------------------------------------------------------
#  Vida
# ---------------------------------------------------------------------------------------------------------------------

func texto_completo() -> bool:
	return _frase == null or _frase.visible_characters < 0 or _frase.visible_characters >= _frase.text.length()


func completar_texto() -> void:
	if _frase != null:
		_frase.visible_characters = -1
		_letras = float(_frase.text.length())


## Para las fotos: congela la lámina con el texto completo (`t` ya no se usa: se queda por las capturas de ayer).
func fijar_tiempo(_t_bucle: float = 0.0) -> void:
	_congelada = true
	_t = T_ENTRADA + 1.0
	_aplicar_entrada()
	completar_texto()


func _aplicar_entrada() -> void:
	var k: float = clampf(_t / T_ENTRADA, 0.0, 1.0)
	var e: float = ease(k, -2.0)
	_carta.scale = Vector2.ONE * lerpf(0.92, 1.0, e)
	_carta.modulate.a = k
	_disco.latido = 1.0 + 0.04 * (0.5 + 0.5 * sin(_t * 2.4))
	_disco.destello = clampf(1.0 - _t / 0.6, 0.0, 1.0)
	_disco.queue_redraw()


func _process(delta: float) -> void:
	if _cerrando:
		_t_cierre += delta
		var a: float = 1.0 - clampf(_t_cierre / T_SALIDA, 0.0, 1.0)
		_fondo.modulate.a = a
		_lienzo.modulate.a = a
		if _t_cierre >= T_SALIDA:
			_terminar()
		return
	if _congelada:
		return
	_t += delta
	_aplicar_entrada()
	if _t >= T_ENTRADA * 0.6 and _frase.visible_characters >= 0:
		_letras += delta * LETRAS_POR_S
		if int(_letras) >= _frase.text.length():
			_frase.visible_characters = -1
		else:
			_frase.visible_characters = int(_letras)


func cerrar() -> void:
	if _cerrando:
		return
	_cerrando = true
	_t_cierre = 0.0
	if _fondo != null:
		_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _terminar() -> void:
	_soltar_pausa()
	cerrada.emit()
	queue_free()


## Una pulsación de «continuar»: completa el texto si va a medias; si no, cierra.
func _pulsar() -> void:
	if _t < T_GUARDA or _cerrando:
		return
	if not texto_completo():
		completar_texto()
	else:
		cerrar()


func _input(ev: InputEvent) -> void:
	if not cierre_propio or _cerrando:
		return
	var pulsa: bool = false
	if ev is InputEventKey:
		pulsa = ev.pressed and not ev.echo and (ev.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or ev.is_action_pressed("interactuar") or ev.is_action_pressed("ui_accept"))
	elif ev is InputEventJoypadButton:
		pulsa = ev.pressed and ev.button_index == JOY_BUTTON_A
	elif ev is InputEventMouseButton:
		pulsa = ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT
	if pulsa:
		_pulsar()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------------------------------------------------
#  Piezas dibujadas
# ---------------------------------------------------------------------------------------------------------------------

## El disco de la runa: halo en el color, disco oscuro, aro de bronce y la runa (textura o carácter futhark).
class _Disco extends Control:
	var color: Color = Color.WHITE
	var textura: Texture2D = null
	var futhark: String = ""
	var latido: float = 1.0
	var destello: float = 0.0

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = 118.0 * latido
		for i in range(8):
			var f: float = float(i) / 8.0
			draw_circle(c, r + 46.0 * (1.0 - f), Color(color, 0.05 + 0.04 * f))
		draw_circle(c, r, Color(0.13, 0.09, 0.07))
		draw_arc(c, r, 0.0, TAU, 64, color, 6.0, true)
		draw_arc(c, r - 12.0, 0.0, TAU, 64, Color(color, 0.45), 2.0, true)
		var lado: float = r * 1.35
		if textura != null:
			draw_texture_rect(textura, Rect2(c - Vector2(lado, lado) * 0.5, Vector2(lado, lado)), false, Color(1.0, 0.97, 0.88))
		else:
			var f: Font = TemaInterfaz.fuente()
			var tam: int = int(lado * 0.85)
			var s: Vector2 = f.get_string_size(futhark, HORIZONTAL_ALIGNMENT_LEFT, -1, tam)
			draw_string(f, c + Vector2(-s.x * 0.5, f.get_ascent(tam) * 0.5 - 6.0), futhark, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(1.0, 0.97, 0.88))
		if destello > 0.0:
			draw_circle(c, r * (1.0 + 0.25 * (1.0 - destello)), Color(1, 1, 1, 0.55 * destello))
