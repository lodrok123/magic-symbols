extends Control
## GENERADOR DE MAPAS — la herramienta visual (17/11/2026). Se abre como una escena más:
##   tools\Godot_v4.7.2-stable_win64.exe --path . res://herramientas/generador_mapas/GeneradorMapas.tscn
## Izquierda: los parámetros (cada cambio regenera al momento). Centro: la vista previa del mapa (rueda = zoom, botón derecho = mover,
## botón izquierdo = pintar con el pincel elegido). Derecha: resumen, validación y el texto exacto del .txt que se escribiría.
## Abajo: «Otra semilla» (F5), «Exportar a Godot» (escribe mundo/datos_nivel/mapas/<Nombre>.txt y escenas/Prueba<Nombre>.tscn) y
## «Probar en el juego» (exporta y abre el nivel en otra ventana). NADA se escribe en el proyecto hasta pulsar Exportar.
## El generador es `generador_mazmorra.gd` (datos puros) y lo que escribe los archivos, `exportador_mapa.gd`.

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")

const C_FONDO: Color = Color(0.13, 0.12, 0.11)
const C_PANEL: Color = Color(0.17, 0.16, 0.15)
const C_MURO: Color = Color(0.23, 0.2, 0.19)
const C_SUELO: Color = Color(0.93, 0.89, 0.8)
const C_AGUA: Color = Color(0.45, 0.68, 0.82)
const C_TINTA: Color = Color(0.12, 0.1, 0.09)
const ROLES: Dictionary = {
	"inicio": ["inicio", Color(0.35, 0.75, 0.4)], "tesoro": ["tesoro", Color(0.95, 0.75, 0.2)],
	"llave": ["llave", Color(0.65, 0.45, 0.9)], "combate": ["se cierra", Color(0.9, 0.35, 0.3)],
}
## tipo de objeto → [letra que se pinta, color, forma (0 círculo, 1 cuadrado), nombre]
const ICONOS: Dictionary = {
	"inicio": ["S", Color(0.2, 0.65, 0.3), 0, "inicio de la jugadora"], "salida": ["E", Color(0.25, 0.7, 0.8), 1, "salida a otro nivel"],
	"guerrero": ["W", Color(0.8, 0.25, 0.2), 0, "goblin guerrero"], "arquero": ["A", Color(0.85, 0.45, 0.15), 0, "goblin arquero"],
	"brasero": ["T", Color(0.95, 0.6, 0.15), 0, "brasero"], "jarron": ["j", Color(0.6, 0.5, 0.38), 0, "jarrón"],
	"cofre_tesoro": ["$", Color(0.9, 0.7, 0.1), 1, "cofre del tesoro"], "cofre_llave": ["K", Color(0.6, 0.4, 0.85), 1, "cofre de la llave"],
	"puerta_llave": ["L", Color(0.6, 0.4, 0.85), 1, "puerta con llave"], "cerrojo": ["X", Color(0.85, 0.3, 0.25), 1, "cerrojo de sala"],
}
## Cambiar uno de estos cambia la forma del mapa: los retoques pintados a mano dejan de tener sentido y se borran.
const CLAVES_FORMA: Array[String] = ["algoritmo", "semilla", "ancho", "alto", "sala_min", "sala_max", "reparto", "densidad_salas", "puertas", "recto", "callejones",
	"ancho_pasillo", "forma", "relleno", "suavizados", "region_min", "agua", "n_salas", "lado_min", "lado_max", "simetria", "pasillos", "bucles"]

## Los campos del panel. t: titulo | opcion | int | float | bool | texto. `alg`: solo se ve con ese algoritmo.
const CAMPOS: Array = [
	{"t": "titulo", "r": "MAPA"},
	{"k": "algoritmo", "r": "Algoritmo", "t": "opcion", "op": [["salas", "Salas y pasillos (donjon)"], ["cueva", "Cueva orgánica (autómata)"], ["pagina", "Una página (sala a sala)"]],
		"a": "Salas y pasillos: rejilla de salas unidas por un laberinto podado.\nCueva: roca natural por autómata celular, con agua.\nUna página: crece desde la entrada pegando salas, con simetría y bucles."},
	{"k": "semilla", "r": "Semilla", "t": "int", "min": 0, "max": 9999999, "a": "La misma semilla con los mismos parámetros da siempre el mismo mapa."},
	{"k": "ancho", "r": "Ancho (casillas)", "t": "int", "min": 12, "max": 120, "a": "Una casilla son 2,3 u del juego. La Cueva mide 27 × 25; el Bosque 02, 40 × 40."},
	{"k": "alto", "r": "Alto (casillas)", "t": "int", "min": 12, "max": 120},
	{"t": "titulo", "r": "SALAS Y PASILLOS", "alg": "salas"},
	{"k": "ancho_pasillo", "r": "Ancho de pasillo", "t": "int", "min": 1, "max": 3, "alg": "salas", "a": "Casillas de ancho de cada pasillo. Las salas crecen en la misma proporción. Con 1, los pasillos son de una sola casilla (difícil para combatir)."},
	{"k": "sala_min", "r": "Sala mínima (huecos)", "t": "int", "min": 1, "max": 8, "alg": "salas", "a": "Lado mínimo de una sala, en huecos de pasillo. Con pasillo de 2, una sala de 3 huecos mide 8 casillas."},
	{"k": "sala_max", "r": "Sala máxima (huecos)", "t": "int", "min": 1, "max": 10, "alg": "salas"},
	{"k": "reparto", "r": "Reparto de salas", "t": "opcion", "op": [["dispersas", "Dispersas"], ["densas", "Densas (llenan el mapa)"]], "alg": "salas"},
	{"k": "densidad_salas", "r": "Cantidad de salas", "t": "float", "min": 0.2, "max": 3.0, "paso": 0.1, "alg": "salas", "a": "1 = lo normal para el tamaño del mapa."},
	{"k": "puertas", "r": "Puertas por sala (%)", "t": "int", "min": 0, "max": 200, "paso": 10, "alg": "salas", "a": "50 = lo normal (según el tamaño de la sala). 0 = una sola puerta por sala."},
	{"k": "recto", "r": "Pasillos rectos (%)", "t": "int", "min": 0, "max": 100, "paso": 5, "alg": "salas", "a": "0 = laberinto retorcido; 100 = pasillos largos y rectos."},
	{"k": "callejones", "r": "Podar callejones (%)", "t": "int", "min": 0, "max": 100, "paso": 5, "alg": "salas", "a": "100 = no queda ningún pasillo sin salida; 0 = se queda el laberinto entero."},
	{"k": "forma", "r": "Forma del mapa", "t": "opcion", "op": [["rectangulo", "Rectángulo"], ["caja", "Caja (hueco central)"], ["cruz", "Cruz"], ["redonda", "Redonda"]], "alg": "salas"},
	{"t": "titulo", "r": "CUEVA", "alg": "cueva"},
	{"k": "relleno", "r": "Roca inicial (%)", "t": "int", "min": 30, "max": 60, "alg": "cueva", "a": "Menos = cueva abierta; más = galerías estrechas. Entre 42 y 48 da las mejores."},
	{"k": "suavizados", "r": "Suavizados", "t": "int", "min": 0, "max": 12, "alg": "cueva", "a": "Pasadas del autómata: más = paredes más redondas."},
	{"k": "region_min", "r": "Bolsa mínima (casillas)", "t": "int", "min": 1, "max": 80, "alg": "cueva", "a": "Las bolsas sueltas más pequeñas que esto se tapan; las demás se unen con un túnel."},
	{"k": "agua", "r": "Agua (%)", "t": "int", "min": 0, "max": 40, "alg": "cueva", "a": "Parte del suelo que se inunda (lo más bajo). Si el agua parte la cueva, se abre un vado."},
	{"t": "titulo", "r": "UNA PÁGINA", "alg": "pagina"},
	{"k": "n_salas", "r": "Número de salas", "t": "int", "min": 2, "max": 40, "alg": "pagina", "a": "Pequeña 3-6, mediana 6-12, grande 12-25. Si no caben, avisa."},
	{"k": "lado_min", "r": "Lado mínimo (casillas)", "t": "int", "min": 2, "max": 12, "alg": "pagina"},
	{"k": "lado_max", "r": "Lado máximo (casillas)", "t": "int", "min": 2, "max": 16, "alg": "pagina"},
	{"k": "simetria", "r": "Grupos simétricos", "t": "bool", "alg": "pagina", "a": "Las salas a los lados del eje de la entrada salen por parejas."},
	{"k": "pasillos", "r": "Pasillos (%)", "t": "int", "min": 0, "max": 90, "paso": 5, "alg": "pagina", "a": "Cuántas de las «salas» nuevas son pasillos largos y estrechos."},
	{"k": "bucles", "r": "Bucles (%)", "t": "int", "min": 0, "max": 100, "paso": 5, "alg": "pagina", "a": "Puertas de más entre salas vecinas, para que no sea un árbol puro."},
	{"t": "titulo", "r": "CONTENIDO"},
	{"k": "enemigos", "r": "Enemigos", "t": "float", "min": 0.0, "max": 4.0, "paso": 0.1, "a": "0 = ninguno; 1 = un goblin por cada ~22 casillas de sala (más en las lejanas); 5 por sala como mucho."},
	{"k": "arqueros", "r": "Arqueros (%)", "t": "int", "min": 0, "max": 100, "paso": 5, "a": "Parte de los goblins que son arqueros (letra A) en vez de guerreros (W)."},
	{"k": "salas_cerradas", "r": "Salas que se cierran (%)", "t": "int", "min": 0, "max": 100, "paso": 5, "a": "Salas con enemigos que cierran sus puertas al entrar y se abren al vencer (cerrojo + vigía)."},
	{"k": "tesoro", "r": "Sala del tesoro", "t": "bool", "a": "La sala más lejana lleva un cofre (60 de oro y una poción)."},
	{"k": "llave", "r": "Tesoro con llave", "t": "bool", "a": "La sala del tesoro se cierra con una puerta de llave; la llave está en el cofre de otra sala lejana, que aparece al limpiarla."},
	{"k": "charcas", "r": "Salas con charca (%)", "t": "int", "min": 0, "max": 100, "paso": 5, "a": "Salas de 5 × 5 o más con una charca de agua honda en medio."},
	{"k": "braseros", "r": "Braseros por sala", "t": "float", "min": 0.0, "max": 4.0, "paso": 0.5, "a": "En los rincones. Nacen apagados: se encienden con fuego."},
	{"k": "jarrones", "r": "Jarrones por sala", "t": "float", "min": 0.0, "max": 6.0, "paso": 0.5, "a": "Contra la pared del fondo. Dan oro (o poción, 1 de cada 5)."},
	{"t": "titulo", "r": "NIVEL"},
	{"k": "nombre", "r": "Nombre del nivel", "t": "texto", "a": "Letras sin acento, cifras y «_». Será mapas/<Nombre>.txt y escenas/Prueba<Nombre>.tscn."},
	{"k": "estilo", "r": "Estilo", "t": "opcion", "op": [["cueva", "Cueva (roca)"], ["bosque", "Bosque (árboles)"], ["pantano", "Pantano (barro)"]], "a": "Cómo dibuja la maqueta las paredes y el suelo."},
	{"k": "luz", "r": "Luz", "t": "opcion", "op": [], "a": "La fila de LuzZona3D.ZONAS que ilumina el nivel."},
	{"k": "rotulo", "r": "Rótulo al entrar", "t": "bool", "a": "Una zona que cubre el mapa y enseña el nombre la primera vez."},
	{"k": "salida_a", "r": "Salida a (Nivel:entrada)", "t": "texto", "a": "Vacío = sin salida. Ejemplo: Bosque_02:boca_cueva. Pone una salida en la sala de inicio."},
]


# =====================================================================================================================
#  La vista previa
# =====================================================================================================================

class Vista extends Control:
	signal pintada(c: Vector2i)
	signal sobre(c: Vector2i)

	var mapa: Dictionary = {}
	var escala: float = 16.0
	var origen: Vector2 = Vector2.ZERO
	var pincel: String = ""
	var _moviendo: bool = false
	var _pintando: bool = false
	var _tam: Vector2i = Vector2i.ZERO

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_CLICK

	func poner(m: Dictionary) -> void:
		mapa = m
		var t: Vector2i = Vector2i(int(m["ancho"]), int(m["alto"]))
		if t != _tam:
			_tam = t
			ajustar()
		queue_redraw()

	## Encaja el mapa entero en la vista.
	func ajustar() -> void:
		if _tam.x <= 0 or size.x < 20.0 or size.y < 20.0:
			return
		escala = clampf(floorf(minf((size.x - 24.0) / _tam.x, (size.y - 24.0) / _tam.y)), 3.0, 48.0)
		origen = ((size - Vector2(_tam) * escala) * 0.5).floor()
		queue_redraw()

	func _notification(que: int) -> void:
		if que == NOTIFICATION_RESIZED:
			ajustar()

	func celda_en(pos: Vector2) -> Vector2i:
		return Vector2i(((pos - origen) / escala).floor())

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var b: InputEventMouseButton = ev
			if b.pressed and (b.button_index == MOUSE_BUTTON_WHEEL_UP or b.button_index == MOUSE_BUTTON_WHEEL_DOWN):
				var antes: Vector2 = (b.position - origen) / escala
				escala = clampf(escala * (1.15 if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 3.0, 64.0)
				origen = b.position - antes * escala
				queue_redraw()
			elif b.button_index == MOUSE_BUTTON_RIGHT or b.button_index == MOUSE_BUTTON_MIDDLE:
				_moviendo = b.pressed
			elif b.button_index == MOUSE_BUTTON_LEFT:
				_pintando = b.pressed and pincel != ""
				if _pintando:
					pintada.emit(celda_en(b.position))
		elif ev is InputEventMouseMotion:
			var mm: InputEventMouseMotion = ev
			if _moviendo:
				origen += mm.relative
				queue_redraw()
			elif _pintando:
				pintada.emit(celda_en(mm.position))
			sobre.emit(celda_en(mm.position))

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), C_FONDO)
		if mapa.is_empty():
			return
		var filas: PackedStringArray = mapa["filas"]
		var w: int = int(mapa["ancho"])
		var h: int = int(mapa["alto"])
		var e: float = escala
		draw_rect(Rect2(origen, Vector2(w, h) * e), C_MURO)
		for y in range(h):
			var fila: String = filas[y]
			var x: int = 0
			while x < w:                                # tramos seguidos del mismo color en un solo rectángulo
				var ch: String = fila[x]
				var x0: int = x
				while x < w and (fila[x] == "~") == (ch == "~") and (fila[x] == "#") == (ch == "#"):
					x += 1
				if ch != "#":
					draw_rect(Rect2(origen + Vector2(x0, y) * e, Vector2(x - x0, 1) * e), C_AGUA if ch == "~" else C_SUELO)
		# Salas: tinte del papel que hacen y su número.
		var fuente: Font = get_theme_default_font()
		for s in mapa["salas"]:
			var r: Rect2i = s["rect"]
			var rol: String = String(s["rol"])
			if ROLES.has(rol):
				var col: Color = ROLES[rol][1]
				for sy in range(maxi(r.position.y, 0), mini(r.end.y, h)):          # solo lo que se pisa: en una cueva el «claro» pisa roca
					for sx in range(maxi(r.position.x, 0), mini(r.end.x, w)):
						if filas[sy][sx] != "#":
							draw_rect(Rect2(origen + Vector2(sx, sy) * e, Vector2(e, e)), Color(col, 0.3))
				if String((mapa["parametros"] as Dictionary)["algoritmo"]) != "cueva":
					draw_rect(Rect2(origen + Vector2(r.position) * e, Vector2(r.size) * e).grow(-1.0), Color(col, 0.9), false, 2.0)
		# Rejilla y trazo de tinta en el borde del suelo.
		if e >= 9.0:
			for y in range(h + 1):
				draw_line(origen + Vector2(0, y) * e, origen + Vector2(w, y) * e, Color(0, 0, 0, 0.07))
			for x in range(w + 1):
				draw_line(origen + Vector2(x, 0) * e, origen + Vector2(x, h) * e, Color(0, 0, 0, 0.07))
		var grosor: float = clampf(e * 0.14, 1.0, 3.0)
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				if filas[y][x] == "#":
					continue
				var p0: Vector2 = origen + Vector2(x, y) * e
				if filas[y - 1][x] == "#":
					draw_line(p0, p0 + Vector2(e, 0), C_TINTA, grosor)
				if filas[y + 1][x] == "#":
					draw_line(p0 + Vector2(0, e), p0 + Vector2(e, e), C_TINTA, grosor)
				if filas[y][x - 1] == "#":
					draw_line(p0, p0 + Vector2(0, e), C_TINTA, grosor)
				if filas[y][x + 1] == "#":
					draw_line(p0 + Vector2(e, 0), p0 + Vector2(e, e), C_TINTA, grosor)
		# Puertas sin pieza: una traviesa marrón.
		for pu in mapa["puertas"]:
			if String(pu["tipo"]) != "paso":
				continue
			var c: Vector2i = pu["c"]
			var horizontal: bool = filas[c.y][c.x - 1] == "#" and filas[c.y][c.x + 1] == "#"
			var centro: Vector2 = origen + (Vector2(c) + Vector2(0.5, 0.5)) * e
			var medio: Vector2 = Vector2(e * 0.5, e * 0.14) if horizontal else Vector2(e * 0.14, e * 0.5)
			draw_rect(Rect2(centro - medio, medio * 2.0), Color(0.5, 0.33, 0.18))
		# Objetos.
		var tam_letra: int = int(clampf(e * 0.62, 7.0, 26.0))
		for o in mapa["objetos"]:
			var ic: Array = ICONOS.get(String(o["tipo"]), ["?", Color.MAGENTA, 0, ""])
			var oc: Vector2i = o["c"]
			var cen: Vector2 = origen + (Vector2(oc) + Vector2(0.5, 0.5)) * e
			if int(ic[2]) == 1:
				draw_rect(Rect2(cen - Vector2(e, e) * 0.42, Vector2(e, e) * 0.84), ic[1])
			else:
				draw_circle(cen, e * 0.42, ic[1])
			if e >= 9.0:
				draw_string(fuente, cen + Vector2(-e * 0.5, tam_letra * 0.36), String(ic[0]), HORIZONTAL_ALIGNMENT_CENTER, e, tam_letra, Color.WHITE)
		if e >= 12.0:
			for s in mapa["salas"]:
				var r2: Rect2i = s["rect"]
				draw_string(fuente, origen + Vector2(r2.position) * e + Vector2(3, tam_letra * 0.8 + 1), str(int(s["id"])), HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam_letra * 0.75), Color(0, 0, 0, 0.45))


# =====================================================================================================================
#  La herramienta
# =====================================================================================================================

var _par: Dictionary = Generador.parametros_defecto()
var _retoques: Dictionary = {}
var _mapa: Dictionary = {}
var _sucio: bool = true
var _controles: Dictionary = {}          ## clave → control
var _filas: Array = []                   ## [nodo de la fila, algoritmo o ""]
var _vista: Vista = null
var _resumen: RichTextLabel = null
var _texto: TextEdit = null
var _estado: Label = null
var _bajo_cursor: Label = null
var _pincel: OptionButton = null
var _abrir: MenuButton = null
var _confirmar: ConfirmationDialog = null
var _tras_confirmar: Callable = Callable()
var _mono: SystemFont = SystemFont.new()
var _cargando: bool = false


func _ready() -> void:
	var v: Window = get_window()
	v.title = "Generador de mapas — Magic Symbols"
	v.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED       # interfaz a píxeles reales (el juego estira la suya)
	v.min_size = Vector2i(1100, 650)
	if DisplayServer.get_name() != "headless":
		v.mode = Window.MODE_MAXIMIZED
	_mono.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
	theme = Theme.new()
	theme.default_font_size = 17 if DisplayServer.screen_get_size().x >= 2200 else 14      # en un monitor de 2560 la letra de serie queda pequeña
	_par["semilla"] = int(Time.get_unix_time_from_system()) % 1000000
	_montar()
	_regenerar()


func _process(_delta: float) -> void:
	if _sucio:
		_regenerar()


func _unhandled_key_input(ev: InputEvent) -> void:
	var k: InputEventKey = ev as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F5:
		_otra_semilla()
		accept_event()


func _montar() -> void:
	var fondo: ColorRect = ColorRect.new()
	fondo.color = C_PANEL
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var margen: MarginContainer = MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 8)
	add_child(margen)
	var todo: VBoxContainer = VBoxContainer.new()
	todo.add_theme_constant_override("separation", 8)
	margen.add_child(todo)
	var cuerpo: HBoxContainer = HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 8)
	todo.add_child(cuerpo)
	# --- izquierda: parámetros ---
	var barra: ScrollContainer = ScrollContainer.new()
	barra.custom_minimum_size = Vector2(350, 0)
	barra.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cuerpo.add_child(barra)
	var lista: VBoxContainer = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 3)
	barra.add_child(lista)
	for campo in CAMPOS:
		_fila(lista, campo)
	# --- centro: vista ---
	_vista = Vista.new()
	_vista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vista.pintada.connect(_al_pintar)
	_vista.sobre.connect(_al_pasar)
	cuerpo.add_child(_vista)
	# --- derecha: resumen y texto ---
	var der: VBoxContainer = VBoxContainer.new()
	der.custom_minimum_size = Vector2(430, 0)
	der.add_theme_constant_override("separation", 6)
	cuerpo.add_child(der)
	_resumen = RichTextLabel.new()
	_resumen.bbcode_enabled = true
	_resumen.fit_content = true
	_resumen.custom_minimum_size = Vector2(0, 120)
	der.add_child(_resumen)
	var leyenda: RichTextLabel = RichTextLabel.new()
	leyenda.bbcode_enabled = true
	leyenda.fit_content = true
	var partes: PackedStringArray = PackedStringArray()
	for tipo in ICONOS:
		partes.append("[bgcolor=#%s][color=white] %s [/color][/bgcolor] %s" % [(ICONOS[tipo][1] as Color).to_html(false), String(ICONOS[tipo][0]), String(ICONOS[tipo][3])])
	for rol in ROLES:
		partes.append("[color=#%s]▣[/color] sala: %s" % [(ROLES[rol][1] as Color).to_html(false), String(ROLES[rol][0])])
	leyenda.text = "[b]Leyenda[/b]\n" + "   ".join(partes)
	der.add_child(leyenda)
	var rot: Label = Label.new()
	rot.text = "Lo que se escribiría en mapas/<Nombre>.txt:"
	der.add_child(rot)
	_texto = TextEdit.new()
	_texto.editable = false
	_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_texto.add_theme_font_override("font", _mono)
	_texto.add_theme_font_size_override("font_size", 13)
	der.add_child(_texto)
	# --- abajo: acciones ---
	var pie: HBoxContainer = HBoxContainer.new()
	pie.add_theme_constant_override("separation", 8)
	todo.add_child(pie)
	_boton(pie, "Otra semilla (F5)", _otra_semilla, "Genera otro mapa con los mismos parámetros.")
	_boton(pie, "Encajar vista", func() -> void: _vista.ajustar(), "Vuelve a ver el mapa entero.")
	var lp: Label = Label.new()
	lp.text = "   Pincel:"
	pie.add_child(lp)
	_pincel = OptionButton.new()
	for it in [["", "ninguno"], ["#", "# pared"], [".", ". suelo"], ["~", "~ agua"], ["borrar", "goma (quita el retoque)"]]:
		_pincel.add_item(String(it[1]))
		_pincel.set_item_metadata(_pincel.item_count - 1, String(it[0]))
	_pincel.tooltip_text = "Con un pincel elegido, el botón izquierdo pinta sobre la vista. El contenido (enemigos, cofres…) se recoloca solo."
	_pincel.item_selected.connect(func(i: int) -> void: _vista.pincel = String(_pincel.get_item_metadata(i)))
	pie.add_child(_pincel)
	_boton(pie, "Borrar retoques", _borrar_retoques, "Quita todo lo pintado a mano.")
	_abrir = MenuButton.new()
	_abrir.text = "Abrir mapa generado ▾"
	_abrir.flat = false
	_abrir.tooltip_text = "Recupera los parámetros (y los retoques) de un mapa que exportó esta herramienta."
	_abrir.about_to_popup.connect(_llenar_abrir)
	_abrir.get_popup().id_pressed.connect(_al_abrir)
	pie.add_child(_abrir)
	var hueco: Control = Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pie.add_child(hueco)
	_boton(pie, "Copiar texto", _copiar_texto, "Copia el .txt al portapapeles sin escribir nada.")
	_boton(pie, "Exportar a Godot", func() -> void: _exportar(false), "Escribe mapas/<Nombre>.txt y escenas/Prueba<Nombre>.tscn.")
	_boton(pie, "Probar en el juego", func() -> void: _exportar(true), "Exporta y abre el nivel en otra ventana.")
	var pie2: HBoxContainer = HBoxContainer.new()
	todo.add_child(pie2)
	_estado = Label.new()
	_estado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_estado.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pie2.add_child(_estado)
	_bajo_cursor = Label.new()
	_bajo_cursor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bajo_cursor.custom_minimum_size = Vector2(520, 0)
	pie2.add_child(_bajo_cursor)
	_confirmar = ConfirmationDialog.new()
	_confirmar.title = "Exportar"
	_confirmar.ok_button_text = "Sobrescribir"
	_confirmar.cancel_button_text = "Cancelar"
	_confirmar.confirmed.connect(_al_confirmar)
	add_child(_confirmar)
	_decir("Nada se escribe en el proyecto hasta pulsar «Exportar a Godot». Rueda = zoom · botón derecho = mover la vista.")


func _borrar_retoques() -> void:
	_retoques.clear()
	_sucio = true


func _copiar_texto() -> void:
	DisplayServer.clipboard_set(_texto.text)
	_decir("Texto del mapa copiado al portapapeles.")


func _al_confirmar() -> void:
	if _tras_confirmar.is_valid():
		_tras_confirmar.call()


func _boton(padre: Node, texto: String, al_pulsar: Callable, ayuda: String) -> Button:
	var b: Button = Button.new()
	b.text = texto
	b.tooltip_text = ayuda
	b.pressed.connect(al_pulsar)
	padre.add_child(b)
	return b


func _fila(lista: VBoxContainer, campo: Dictionary) -> void:
	var alg: String = String(campo.get("alg", ""))
	if String(campo["t"]) == "titulo":
		var t: Label = Label.new()
		t.text = String(campo["r"])
		t.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
		t.add_theme_font_size_override("font_size", 13)
		var caja: MarginContainer = MarginContainer.new()
		caja.add_theme_constant_override("margin_top", 10)
		caja.add_child(t)
		lista.add_child(caja)
		_filas.append([caja, alg])
		return
	var k: String = String(campo["k"])
	var fila: HBoxContainer = HBoxContainer.new()
	fila.tooltip_text = String(campo.get("a", ""))
	var r: Label = Label.new()
	r.text = String(campo["r"])
	r.custom_minimum_size = Vector2(175, 0)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	fila.add_child(r)
	var c: Control = null
	match String(campo["t"]):
		"opcion":
			var ob: OptionButton = OptionButton.new()
			var ops: Array = campo["op"]
			if k == "luz":
				ops = []
				for l in Exportador.LUCES:
					ops.append([l, l])
			for o in ops:
				ob.add_item(String(o[1]))
				ob.set_item_metadata(ob.item_count - 1, String(o[0]))
				if String(o[0]) == String(_par[k]):
					ob.select(ob.item_count - 1)
			ob.item_selected.connect(func(i: int) -> void: _cambio(k, String(ob.get_item_metadata(i))))
			c = ob
		"int", "float":
			var sb: SpinBox = SpinBox.new()
			sb.min_value = float(campo["min"])
			sb.max_value = float(campo["max"])
			sb.step = float(campo.get("paso", 1.0)) if String(campo["t"]) == "float" else 1.0
			sb.custom_arrow_step = float(campo.get("paso", 1.0))
			sb.value = float(_par[k])
			var entero: bool = String(campo["t"]) == "int"
			sb.value_changed.connect(func(val: float) -> void: _cambio(k, int(val) if entero else val))
			c = sb
		"bool":
			var cb: CheckBox = CheckBox.new()
			cb.button_pressed = bool(_par[k])
			cb.toggled.connect(func(si: bool) -> void: _cambio(k, si))
			c = cb
		"texto":
			var le: LineEdit = LineEdit.new()
			le.text = String(_par[k])
			le.text_changed.connect(func(txt: String) -> void: _cambio(k, txt))
			c = le
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.tooltip_text = fila.tooltip_text
	fila.add_child(c)
	lista.add_child(fila)
	_controles[k] = c
	_filas.append([fila, alg])


func _cambio(k: String, valor: Variant) -> void:
	if _cargando:
		return
	_par[k] = valor
	if CLAVES_FORMA.has(k) and not _retoques.is_empty():
		_retoques.clear()
		_decir("Ha cambiado la forma del mapa: los retoques pintados a mano se han borrado.")
	if k == "estilo" and Exportador.LUCES.has(String(valor)):
		_poner_control("luz", String(valor))          # la luz sigue al estilo (se puede cambiar después)
		_par["luz"] = String(valor)
	_sucio = true


## Pone un valor en su control sin que el control vuelva a avisar del cambio.
func _poner_control(k: String, valor: Variant) -> void:
	var c: Control = _controles.get(k)
	if c == null:
		return
	_cargando = true
	if c is OptionButton:
		for i in range((c as OptionButton).item_count):
			if String((c as OptionButton).get_item_metadata(i)) == String(valor):
				(c as OptionButton).select(i)
	elif c is SpinBox:
		(c as SpinBox).value = float(valor)
	elif c is CheckBox:
		(c as CheckBox).button_pressed = bool(valor)
	elif c is LineEdit:
		(c as LineEdit).text = String(valor)
	_cargando = false


func _otra_semilla() -> void:
	_retoques.clear()
	_par["semilla"] = randi() % 1000000
	_poner_control("semilla", _par["semilla"])
	_sucio = true


func _regenerar() -> void:
	_sucio = false
	for f in _filas:
		(f[0] as Control).visible = String(f[1]) == "" or String(f[1]) == String(_par["algoritmo"])
	var t0: int = Time.get_ticks_usec()
	_mapa = Generador.new().generar(_par, _retoques)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	_vista.poner(_mapa)
	_texto.text = Exportador.texto_mapa(_mapa)
	var st: Dictionary = _mapa["stats"]
	var l: PackedStringArray = PackedStringArray()
	l.append("[b]%s[/b] · %d × %d casillas (%.0f × %.0f u) · semilla %d · %.0f ms" % [String(_par["nombre"]), int(_mapa["ancho"]), int(_mapa["alto"]),
		int(_mapa["ancho"]) * 2.3, int(_mapa["alto"]) * 2.3, int(_par["semilla"]), ms])
	l.append("%d salas · %d puertas · %d enemigos · %d cofres · %d jarrones · %d casillas pisables (%d %% del mapa, %d de agua)" % [int(st["salas"]), int(st["puertas"]),
		int(st["enemigos"]), int(st["cofres"]), int(st["jarrones"]), int(st["suelo"]), int(round(float(st["ocupacion"]) * 100.0)), int(st["agua"])])
	if not _retoques.is_empty():
		l.append("%d casillas retocadas a mano." % _retoques.size())
	var errores: PackedStringArray = Exportador.validar(_mapa)
	var mal: String = Exportador.nombre_valido(String(_par["nombre"]))
	if errores.is_empty():
		l.append("[color=#7fd88a]✔ Mapa válido: todo se alcanza desde el inicio y ninguna pieza corta el paso.[/color]")
	for e in errores:
		l.append("[color=#ff7a6b]✖ %s[/color]" % e)
	if mal != "":
		l.append("[color=#ff7a6b]✖ %s[/color]" % mal)
	else:
		var est: Dictionary = Exportador.estado_destino(String(_par["nombre"]))
		if String(est["mapa"]) != "" and not bool(est["mapa_nuestro"]):
			l.append("[color=#ff7a6b]✖ Ya existe %s hecho a mano: no se pisará. Cambia el nombre.[/color]" % String(est["mapa"]).get_file())
		elif String(est["horneado"]) != "":
			l.append("[color=#ff7a6b]✖ Existe %s (horneado): la maqueta cargaría ese. Cambia el nombre.[/color]" % String(est["horneado"]).get_file())
		elif String(est["mapa"]) != "":
			l.append("[color=#e8c56a]● %s ya existe (lo generó esta herramienta): exportar lo sobrescribe.[/color]" % String(est["mapa"]).get_file())
	for a in _mapa["avisos"]:
		l.append("[color=#e8c56a]● %s[/color]" % a)
	_resumen.text = "\n".join(l)


func _al_pintar(c: Vector2i) -> void:
	if _mapa.is_empty() or c.x < 1 or c.y < 1 or c.x > int(_mapa["ancho"]) - 2 or c.y > int(_mapa["alto"]) - 2:
		return
	var letra: String = _vista.pincel
	if letra == "borrar":
		if _retoques.has(c):
			_retoques.erase(c)
			_sucio = true
	elif String(_retoques.get(c, "")) != letra:
		_retoques[c] = letra
		_sucio = true


func _al_pasar(c: Vector2i) -> void:
	if _mapa.is_empty() or c.x < 0 or c.y < 0 or c.x >= int(_mapa["ancho"]) or c.y >= int(_mapa["alto"]):
		_bajo_cursor.text = ""
		return
	var partes: PackedStringArray = PackedStringArray(["(%d, %d)" % [c.x, c.y]])
	var ch: String = (_mapa["filas"] as PackedStringArray)[c.y][c.x]
	partes.append({"#": "pared", "~": "agua honda"}.get(ch, "suelo"))
	for s in _mapa["salas"]:
		if (s["rect"] as Rect2i).has_point(c):
			var rol: String = String(s["rol"])
			partes.append("sala %d%s" % [int(s["id"]), " (%s)" % String(ROLES[rol][0]) if ROLES.has(rol) else ""])
			break
	for o in _mapa["objetos"]:
		if (o["c"] as Vector2i) == c:
			partes.append(String(ICONOS.get(String(o["tipo"]), ["", null, 0, String(o["tipo"])])[3]) + (" «%s»" % String(o["id"]) if String(o["id"]) != "" else ""))
	for pu in _mapa["puertas"]:
		if (pu["c"] as Vector2i) == c and String(pu["tipo"]) == "paso":
			partes.append("puerta abierta")
	if _retoques.has(c):
		partes.append("retocada")
	_bajo_cursor.text = " · ".join(partes)


func _decir(texto: String) -> void:
	_estado.text = texto


# --- exportar ---

func _exportar(probar: bool) -> void:
	if _sucio:
		_regenerar()
	var nombre: String = String(_par["nombre"])
	var mal: String = Exportador.nombre_valido(nombre)
	if mal != "":
		_decir("No se exporta: " + mal)
		return
	var est: Dictionary = Exportador.estado_destino(nombre)
	if String(est["mapa"]) != "" and bool(est["mapa_nuestro"]):
		_confirmar.dialog_text = "%s ya existe (lo generó esta herramienta).\n¿Sobrescribirlo con el mapa que estás viendo?\nSi lo habías retocado a mano se guarda antes una copia." % String(est["mapa"]).get_file()
		_tras_confirmar = _hacer_exportar.bind(probar)
		_confirmar.popup_centered()
		return
	_hacer_exportar(probar)


func _hacer_exportar(probar: bool) -> void:
	var res: Dictionary = Exportador.exportar(_mapa)
	if not bool(res["ok"]):
		_decir("NO exportado: " + String(res["error"]))
		return
	var nombre: String = String(_par["nombre"])
	var txt: String = "Exportado: " + " y ".join(PackedStringArray(res["escritos"]))
	if String(res["copia"]) != "":
		txt += " (copia del anterior: %s)" % String(res["copia"]).get_file()
	_decir(txt + ". Para viajar a él desde otro nivel, añade «%s» a Niveles.ESCENAS." % nombre)
	_sucio = true                  # el resumen pasa a decir que el archivo ya existe
	if probar:
		var pid: int = OS.create_process(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"), Exportador.ruta_escena(nombre)])
		if pid <= 0:
			_decir("Exportado, pero no se pudo abrir el juego. Ábrelo a mano: " + Exportador.ruta_escena(nombre))


# --- abrir un mapa generado ---

func _llenar_abrir() -> void:
	var menu: PopupMenu = _abrir.get_popup()
	menu.clear()
	var d: DirAccess = DirAccess.open(Exportador.DIR_MAPAS)
	if d != null:
		var archivos: PackedStringArray = d.get_files()
		archivos.sort()
		for f in archivos:
			if f.ends_with(".txt") and FileAccess.get_file_as_string(Exportador.DIR_MAPAS + f).contains(Exportador.MARCA):
				menu.add_item(f.get_basename())
	if menu.item_count == 0:
		menu.add_item("(todavía no hay ninguno)")
		menu.set_item_disabled(0, true)


func _al_abrir(id: int) -> void:
	var menu: PopupMenu = _abrir.get_popup()
	var nombre: String = menu.get_item_text(menu.get_item_index(id))
	var texto: String = FileAccess.get_file_as_string(Exportador.ruta_mapa(nombre))
	var par: Dictionary = Exportador._tipar(Exportador.parametros_de(texto))
	if par.is_empty():
		_decir("%s no guarda sus parámetros: no se puede abrir." % nombre)
		return
	_par = Generador.parametros_defecto()
	_par.merge(par, true)
	_retoques = Exportador.retoques_de(texto)
	for k in _controles:
		_poner_control(String(k), _par[k])
	_decir("Abierto %s: mismos parámetros, semilla y retoques con los que se exportó." % nombre)
	_sucio = true
