class_name BolsaUI
extends CanvasLayer

## LA MOCHILA: una cuadrícula de 4 columnas. Empieza con 8 huecos (2 filas) y el
## alquimista la amplía hasta 20 (5 filas); los huecos que aún no tienes salen como bloqueados.
## Se abre con I (o la X, o Esc), y al abrirla suena el ruido de la bolsa. Clic en una poción la bebe.
## El oro va DENTRO de la mochila, abajo a la derecha: la moneda y la cifra (sin la palabra «oro»). Ya no hay correa fija
## con los 8 huecos: Pablo (10/10) la quitó porque no servía para nada (los huecos 1–8 eran solo un reflejo de la cuadrícula).
##
## ASPECTO (9/10, encargo del Pipeline): cuero marrón con costura, interior de pergamino como el grimorio.
## Todo se dibuja en código con la paleta de abajo; si existe el arte de `res://presentacion/ui/laminas/` (mochila_panel,
## mochila_solapa, mochila_hueco, mochila_hueco_vacio, mochila_hueco_encima, mochila_hueco_bloqueado, mochila_cerrar,
## mochila_moneda) se usa en su lugar, pieza a pieza: esperar el arte no bloquea nada.
## La lógica (Estado, Objetos, huecos, beber) no cambia.
##
## APERTURA como el grimorio: tween de 0,35 s que ignora el time_scale, sube desde abajo y escala de 0,9 a 1
## con TRANS_BACK, con un velo negro al 35 % detrás; al cerrar, lo inverso en 0,25 s. El mundo se sigue pausando
## mientras está abierta (como antes) y se reanuda al cerrar y en _exit_tree.

const COLUMNAS: int = 4
const TAM: float = 66.0
const SEP: float = 6.0

const RUTA_ARTE: String = "res://presentacion/ui/laminas/"
const CUERO: Color = Color("7a4f2e")
const CUERO_SOMBRA: Color = Color("5a3820")
const COSTURA: Color = Color("d2b07a")
const PERGAMINO: Color = Color("efe7d3")
const PERGAMINO_SOMBRA: Color = Color("e3dcc9")
const PERGAMINO_CLARO: Color = Color("f3ebd7")
const LINEA: Color = Color("8b8273")
const TINTA: Color = Color("4e3a26")
## La solapa lleva la tinta oscura del encargo (#4e3a26), pero sobre el cuero #7a4f2e eso da un contraste de 1,5 (no se
## lee); se hace la solapa de un cuero más claro (contraste 5,6) para que el título se vea.
const SOLAPA: Color = Color("d6b883")
const HEBILLA: Color = Color("e0c26a")
const VELO_ALFA: float = 0.35
const T_ABRIR: float = 0.35
const T_CERRAR: float = 0.25
const SUBIDA: float = 90.0

## --- La bolsa por dentro (Fase 14.3, 16/10): en vez de una rejilla fría, los huecos se reparten por ANCLAS dentro de la silueta de una
## bolsa que se estrecha hacia el cuello: 2, 3, 4, 5 y 6 huecos por fila (20 en total = Estado.CAPACIDAD_MAX), de arriba abajo.
## Los objetos se colocan en orden de categoría (componentes, pociones, clave) rellenando anclas de arriba abajo y de izquierda a derecha.
## Las medidas son de DISEÑO (px); `silueta()` y `anclas()` son estáticas para que la prueba compruebe que cada hueco cabe dentro.
const FILAS_BOLSA: Array = [2, 3, 4, 5, 6]
const BOLSA_ANCHO: float = 410.0
const BOLSA_ALTO: float = 410.0
const SEP_X: float = 66.0                ## entre centros de huecos de la misma fila
const SEP_Y: float = 68.0                ## entre filas
const Y_PRIMERA_FILA: float = 62.0
const TAM_BOLSA: float = 58.0            ## lado de cada hueco en la bolsa (algo menor que TAM: se necesita aire entre ellos)
const COLOR_CORAZON: Color = Color("c0392b")
const COLOR_SILUETA: Color = Color("c9c2b0")            ## placeholder gris cálido hasta que llegue el PNG `mochila_silueta`
const COLOR_SILUETA_BORDE: Color = Color("8b8273")
const COLOR_ELEGIDO: Color = Color("e0a526")

var abierta: bool = false
## Heredado: la textura azul del panel antiguo. Ya no se usa (el panel es de cuero); se deja para no romper a quien la asigne.
var panel_textura: Texture2D = null
var _velo: ColorRect
var _marco: Control
var _panel: PanelContainer
var _solapa: Control
var _cerrar: Control
var _rejilla: Control                   ## la bolsa por dentro (clase Bolsa): los huecos cuelgan de aquí, colocados por anclas
var _huecos: Array = []                 ## Hueco, uno por ancla (20), en el orden de `anclas()`
var _sel: int = -1                      ## índice del hueco elegido (teclado o ratón); -1 = ninguno
var _info: Label
var _oro: Label
var _tween: Tween = null

static var _cache_tex: Dictionary = {}
## Solo para pruebas y capturas: id -> calidad que se usa en vez de la de `Objetos` (no hay legendarios en DATOS todavía).
static var calidad_prueba: Dictionary = {}


## Calidad con la que se enmarca el objeto `id` en la mochila.
static func calidad_de(id: String) -> String:
	return String(calidad_prueba[id]) if calidad_prueba.has(id) else Objetos.calidad(id)


## El arte de `poc_25d/ui/<nombre>.png` si existe, o null (entonces se dibuja en código).
static func tex(nombre: String) -> Texture2D:
	if _cache_tex.has(nombre):
		return _cache_tex[nombre]
	var ruta: String = RUTA_ARTE + nombre + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(ruta):
		t = load(ruta) as Texture2D
	_cache_tex[nombre] = t
	return t


static func _caja(fondo: Color, borde: Color, ancho: int, radio: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(ancho)
	s.set_corner_radius_all(radio)
	s.anti_aliasing = true
	return s


## Contorno de un rectángulo redondeado como lista de puntos (para trazarlo discontinuo: costura, hueco vacío).
static func camino(r: Rect2, radio: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rad: float = maxf(minf(radio, minf(r.size.x, r.size.y) * 0.5), 0.5)
	var centros: Array = [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	var arranque: Array = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for k in range(4):
		for s in range(7):
			var a: float = float(arranque[k]) + (PI * 0.5) * float(s) / 6.0
			pts.append((centros[k] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	pts.append(pts[0])
	return pts


## Traza `pts` a trozos: `on` px de línea y `off` de hueco.
static func discontinuo(c: CanvasItem, pts: PackedVector2Array, col: Color, ancho: float, on: float, off: float) -> void:
	var resto: float = on
	var dibuja: bool = true
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var largo: float = a.distance_to(b)
		var pos: float = 0.0
		while pos < largo:
			var paso: float = minf(resto, largo - pos)
			if dibuja:
				c.draw_line(a.lerp(b, pos / largo), a.lerp(b, (pos + paso) / largo), col, ancho, true)
			pos += paso
			resto -= paso
			if resto <= 0.001:
				dibuja = not dibuja
				resto = on if dibuja else off


static func _nueve(t: Texture2D, margen_x: float, margen_y: float) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = t
	s.texture_margin_left = margen_x
	s.texture_margin_right = margen_x
	s.texture_margin_top = margen_y
	s.texture_margin_bottom = margen_y
	return s


## Los centros de los 20 huecos, de arriba abajo y de izquierda a derecha, en coordenadas de la bolsa (0..BOLSA_ANCHO, 0..BOLSA_ALTO).
static func anclas() -> PackedVector2Array:
	var r := PackedVector2Array()
	for f in range(FILAS_BOLSA.size()):
		var n: int = int(FILAS_BOLSA[f])
		for i in range(n):
			r.append(Vector2(BOLSA_ANCHO * 0.5 + (float(i) - float(n - 1) * 0.5) * SEP_X, Y_PRIMERA_FILA + float(f) * SEP_Y))
	return r


## El contorno de la bolsa: cuello estrecho arriba que se ensancha hacia una panza redondeada. Medio ancho por altura (puntos de control,
## interpolados y suavizados). Tiene que contener TODAS las anclas con su hueco: lo comprueba la prueba.
static func silueta() -> PackedVector2Array:
	var control: Array = [Vector2(0.0, 46.0), Vector2(30.0, 56.0), Vector2(62.0, 76.0), Vector2(130.0, 114.0), Vector2(200.0, 148.0),
		Vector2(270.0, 178.0), Vector2(334.0, 206.0), Vector2(384.0, 204.0), Vector2(406.0, 160.0)]
	var cx: float = BOLSA_ANCHO * 0.5
	var pts := PackedVector2Array()
	for k in range(control.size()):
		pts.append(Vector2(cx + (control[k] as Vector2).y, (control[k] as Vector2).x))
	for k in range(control.size() - 1, -1, -1):
		pts.append(Vector2(cx - (control[k] as Vector2).y, (control[k] as Vector2).x))
	# Una pasada de Chaikin redondea las esquinas sin comerse los costados (las anclas siguen dentro: prueba).
	var suave := PackedVector2Array()
	for i in range(pts.size()):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		suave.append(a.lerp(b, 0.2))
		suave.append(a.lerp(b, 0.8))
	return suave


## Las pilas de la mochila en el orden de la bolsa: por categoría (componentes, pociones, clave) y dentro de cada una por nombre.
## Una pila nunca pasa de PILA_MAX: 12 pociones son [9, 3]. Devuelve [[id, cantidad], ...].
static func ordenar(items: Dictionary) -> Array:
	var ids: Array = items.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ca: int = Objetos.CATEGORIAS.find(Objetos.categoria(String(a)))
		var cb: int = Objetos.CATEGORIAS.find(Objetos.categoria(String(b)))
		if ca != cb:
			return ca < cb
		var na: String = Objetos.nombre(String(a))
		var nb: String = Objetos.nombre(String(b))
		return na < nb if na != nb else String(a) < String(b))
	var pilas: Array = []
	for id in ids:
		var n: int = int(items[id])
		while n > 0:
			pilas.append([String(id), mini(n, Estado.PILA_MAX)])
			n -= Estado.PILA_MAX
	return pilas


## Navegación con el teclado: de entre los huecos `validos` (bool por ancla), el más cercano a `desde` en la dirección `dir`
## (un cono de ±60°; la distancia cuenta más que el desvío). -1 si no hay ninguno en esa dirección.
static func vecino(desde: int, dir: Vector2, validos: Array) -> int:
	var a: PackedVector2Array = anclas()
	if desde < 0 or desde >= a.size() or dir == Vector2.ZERO:
		return -1
	var d: Vector2 = dir.normalized()
	var mejor: int = -1
	var mejor_coste: float = INF
	for j in range(a.size()):
		if j == desde or j >= validos.size() or not bool(validos[j]):
			continue
		var v: Vector2 = a[j] - a[desde]
		var largo: float = v.length()
		if largo < 0.001 or v.normalized().dot(d) < 0.5:
			continue
		var perpendicular: float = absf(v.cross(d))
		var coste: float = largo + 1.5 * perpendicular
		if coste < mejor_coste:
			mejor_coste = coste
			mejor = j
	return mejor


class Hueco extends Control:
	var id: String = ""
	var cantidad: int = 0
	var bloqueado: bool = false
	var cura: bool = false
	var elegido: bool = false
	var indice: int = -1
	var pulsado: Callable
	var al_pasar: Callable
	var _encima: bool = false
	var tam: float = BolsaUI.TAM
	var calidad: String = Objetos.CALIDAD_COMUN       ## la del objeto del hueco: decide el marco (MarcoCalidad)

	func _ready() -> void:
		custom_minimum_size = Vector2(tam, tam)
		calidad = BolsaUI.calidad_de(id) if id != "" else Objetos.CALIDAD_COMUN
		set_process(id != "" and not bloqueado and MarcoCalidad.anima(calidad))       # el brillo de épico y legendario se anima; el común no gasta redibujados
		mouse_entered.connect(func():
			_encima = true
			queue_redraw()
			if al_pasar.is_valid() and id != "":
				al_pasar.call(indice))
		mouse_exited.connect(func(): _encima = false; queue_redraw())

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var estado: String = "bloqueado" if bloqueado else ("encima" if _encima else ("lleno" if id != "" else "vacio"))
		var arte: Texture2D = BolsaUI.tex("mochila_hueco" if estado == "lleno" else "mochila_hueco_" + estado)
		if arte != null:
			draw_texture_rect(arte, r, false)
		else:
			var rad: float = clampf(size.x * 0.14, 5.0, 10.0)
			match estado:
				"bloqueado":
					# Borde al 25 % y sin relleno.
					draw_polyline(BolsaUI.camino(r.grow(-1.5), rad), Color(BolsaUI.LINEA, 0.25), 2.0, true)
				"lleno":
					BolsaUI._caja(BolsaUI.PERGAMINO_SOMBRA, BolsaUI.LINEA, 2, int(rad)).draw(get_canvas_item(), r)
				"encima":
					BolsaUI._caja(BolsaUI.PERGAMINO_CLARO, BolsaUI.LINEA, 3, int(rad)).draw(get_canvas_item(), r)
				_:
					BolsaUI.discontinuo(self, BolsaUI.camino(r.grow(-1.5), rad), BolsaUI.LINEA, 2.0, 6.0, 4.0)
		if bloqueado or id == "":
			return
		# El marco de la calidad del objeto, encima del hueco (común sobrio, épico morado, legendario dorado con destello).
		MarcoCalidad.dibujar(self, r, calidad)
		# Arte propio del objeto (poc_25d/ui/objeto_<id>.png) si existe; si no, el dibujo en código de Objetos.
		var icono: Texture2D = BolsaUI.tex("objeto_" + id)
		if icono != null:
			var lado: float = size.x * 0.62
			draw_texture_rect(icono, Rect2(size * 0.5 + Vector2(-lado * 0.5, -lado * 0.5 - 3.0), Vector2(lado, lado)), false)
		else:
			Objetos.dibujar(self, id, size * 0.5 + Vector2(0, -3), size.x * 0.26)
		if cura:
			BolsaUI.corazon(self, Vector2(size.x * 0.2, size.y * 0.2), size.x * 0.11)
		if elegido:
			draw_polyline(BolsaUI.camino(r.grow(-0.5), clampf(size.x * 0.14, 5.0, 10.0)), BolsaUI.COLOR_ELEGIDO, 3.0, true)
		if cantidad >= 1:
			var f: Font = TemaInterfaz.fuente()
			var cuerpo: int = maxi(13, int(size.x * 0.3))
			var pos := Vector2(0.0, size.y - 6.0)
			# Tinta oscura con halo de pergamino: se lee sobre el icono sea del color que sea.
			draw_string_outline(f, pos, str(cantidad), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6.0, cuerpo, 5, BolsaUI.PERGAMINO)
			draw_string(f, pos, str(cantidad), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6.0, cuerpo, BolsaUI.TINTA)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var m := event as InputEventMouseButton
		if m != null and m.pressed and m.button_index == MOUSE_BUTTON_LEFT and id != "" and pulsado.is_valid():
			pulsado.call(id)


## Un corazón rojo de radio `r` centrado en `p` (dos círculos y un triángulo), para los objetos que curan.
static func corazon(c: CanvasItem, p: Vector2, r: float) -> void:
	c.draw_circle(p + Vector2(-r * 0.5, -r * 0.25), r * 0.58, COLOR_CORAZON)
	c.draw_circle(p + Vector2(r * 0.5, -r * 0.25), r * 0.58, COLOR_CORAZON)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 1.04, -r * 0.05), p + Vector2(r * 1.04, -r * 0.05), p + Vector2(0.0, r * 1.15)]), COLOR_CORAZON)
	c.draw_circle(p + Vector2(-r * 0.6, -r * 0.5), r * 0.16, Color(1, 1, 1, 0.55))


## La bolsa de fondo: su silueta (el PNG `mochila_silueta` del Pipeline si existe; si no, un gris cálido con borde y la cuerda del cuello).
class Bolsa extends Control:
	func _draw() -> void:
		var arte: Texture2D = BolsaUI.tex("mochila_silueta")
		if arte != null:
			draw_texture_rect(arte, Rect2(Vector2.ZERO, size), false)
			return
		var s: PackedVector2Array = BolsaUI.silueta()
		draw_colored_polygon(s, BolsaUI.COLOR_SILUETA)
		var borde := PackedVector2Array(s)
		borde.append(s[0])
		draw_polyline(borde, BolsaUI.COLOR_SILUETA_BORDE, 3.0, true)
		# La cuerda del cuello.
		var cx: float = BolsaUI.BOLSA_ANCHO * 0.5
		draw_line(Vector2(cx - 58.0, 34.0), Vector2(cx + 58.0, 34.0), BolsaUI.COLOR_SILUETA_BORDE, 4.0, true)
		draw_circle(Vector2(cx, 38.0), 5.0, BolsaUI.COLOR_SILUETA_BORDE)


## El marco de cuero con el interior de pergamino y la costura. Se dibuja entero aquí (el estilo del contenedor va vacío:
## el `_draw` de un script se ejecuta ANTES que el estilo del PanelContainer y lo taparía).
class Cuero extends PanelContainer:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var arte: Texture2D = BolsaUI.tex("mochila_panel")
		if arte != null:
			draw_style_box(BolsaUI._nueve(arte, 48.0, 48.0), r)
			return
		BolsaUI._caja(BolsaUI.CUERO, BolsaUI.CUERO_SOMBRA, 3, 22).draw(get_canvas_item(), r)
		BolsaUI._caja(BolsaUI.PERGAMINO, BolsaUI.LINEA, 2, 12).draw(get_canvas_item(), r.grow(-20.0))
		BolsaUI.discontinuo(self, BolsaUI.camino(r.grow(-8.0), 16.0), BolsaUI.COSTURA, 2.0, 7.0, 5.0)


class Solapa extends Control:
	var texto: String = "Mochila"

	func _init() -> void:
		custom_minimum_size = Vector2(230.0, 48.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var arte: Texture2D = BolsaUI.tex("mochila_solapa")
		if arte != null:
			draw_texture_rect(arte, Rect2(Vector2.ZERO, size), false)
		else:
			var forma := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h - 14.0), Vector2(w * 0.5, h), Vector2(0, h - 14.0)])
			draw_colored_polygon(forma, BolsaUI.SOLAPA)
			var borde := PackedVector2Array(forma)
			borde.append(forma[0])
			draw_polyline(borde, BolsaUI.CUERO_SOMBRA, 3.0, true)
			var costura := PackedVector2Array([Vector2(7, 6), Vector2(w - 7.0, 6), Vector2(w - 7.0, h - 19.0), Vector2(w * 0.5, h - 9.0), Vector2(7, h - 19.0), Vector2(7, 6)])
			BolsaUI.discontinuo(self, costura, BolsaUI.CUERO, 1.5, 5.0, 4.0)
			# Hebilla pequeña en la punta.
			var hb := Rect2(Vector2(w * 0.5 - 7.0, h - 17.0), Vector2(14.0, 12.0))
			draw_rect(hb, BolsaUI.HEBILLA)
			draw_rect(hb, BolsaUI.CUERO_SOMBRA, false, 1.5)
			draw_rect(Rect2(hb.position + Vector2(5.0, 3.0), Vector2(4.0, 6.0)), BolsaUI.CUERO_SOMBRA)
		var f: Font = TemaInterfaz.fuente()
		draw_string(f, Vector2(0.0, h * 0.5 + 6.0), texto, HORIZONTAL_ALIGNMENT_CENTER, w, 22, BolsaUI.TINTA)


## El botón redondo de cuero con una X.
class Cerrar extends Control:
	signal pulsado
	var _encima: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(32.0, 32.0)
		size = Vector2(32.0, 32.0)
		tooltip_text = "Cerrar [I / Esc]"
		mouse_entered.connect(func(): _encima = true; queue_redraw())
		mouse_exited.connect(func(): _encima = false; queue_redraw())

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var arte: Texture2D = BolsaUI.tex("mochila_cerrar")
		if arte != null:
			draw_texture_rect(arte, Rect2(Vector2.ZERO, size), false, Color(1.15, 1.15, 1.15) if _encima else Color.WHITE)
			return
		var relleno: Color = BolsaUI.CUERO.lightened(0.18) if _encima else BolsaUI.CUERO
		draw_circle(c, 16.0, BolsaUI.CUERO_SOMBRA)
		draw_circle(c, 14.0, relleno)
		draw_arc(c, 11.0, 0.0, TAU, 24, BolsaUI.COSTURA, 1.2, true)
		draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), BolsaUI.PERGAMINO, 2.5, true)
		draw_line(c + Vector2(-5, 5), c + Vector2(5, -5), BolsaUI.PERGAMINO, 2.5, true)

	func _gui_input(event: InputEvent) -> void:
		var m := event as InputEventMouseButton
		if m != null and m.pressed and m.button_index == MOUSE_BUTTON_LEFT:
			pulsado.emit()


## La moneda del oro, abajo a la derecha del panel. El arte de Pablo (poc_25d/ui/mochila_moneda.png, 68×54) se pinta a la
## mitad de su tamaño para que quede nítido en pantallas de densidad normal; sin el PNG se dibuja la moneda de Objetos.
class Moneda extends Control:
	const ESCALA: float = 0.5

	func _init() -> void:
		custom_minimum_size = Vector2(34.0, 27.0)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var arte: Texture2D = BolsaUI.tex("mochila_moneda")
		if arte != null:
			draw_texture_rect(arte, Rect2((size - arte.get_size() * ESCALA) * 0.5, arte.get_size() * ESCALA), false)
		else:
			Objetos.dibujar(self, "oro", size * 0.5, size.y * 0.4)


static func _etiqueta(tam_fuente: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tam_fuente)
	l.add_theme_color_override("font_color", TINTA)
	l.add_theme_constant_override("outline_size", 0)         # el tema pone contorno oscuro a las etiquetas; sobre pergamino la tinta se lee sola
	return l


static func _margenes(s: StyleBox, izq: float, arr: float, der: float, aba: float) -> void:
	s.content_margin_left = izq
	s.content_margin_top = arr
	s.content_margin_right = der
	s.content_margin_bottom = aba


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Velo negro al 35 % detrás de la mochila (solo mientras está abierta: si no, no estorba al ratón).
	_velo = ColorRect.new()
	_velo.color = Color(0, 0, 0, 0)
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_velo.visible = false
	add_child(_velo)

	# La mochila abierta: _marco (se anima) -> _panel (cuero) + botón de cerrar.
	_marco = Control.new()
	_marco.theme = TemaInterfaz.tema()        # fuente, tooltips y paneles comunes de la interfaz (tema_interfaz.gd); los colores propios del cuero se quedan
	_marco.visible = false
	_marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marco)

	_panel = Cuero.new()
	var sb_panel := StyleBoxEmpty.new()
	_margenes(sb_panel, 36.0, 22.0, 36.0, 34.0)
	_panel.add_theme_stylebox_override("panel", sb_panel)
	_marco.add_child(_panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	_panel.add_child(caja)

	# La solapa cuelga del borde de arriba, centrada, y es el título.
	_solapa = Solapa.new()
	_solapa.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	caja.add_child(_solapa)

	# La bolsa: un solo control con la silueta, y los huecos colgando de él en sus anclas. Medida fija: el marco mide lo mismo al abrir.
	_rejilla = Bolsa.new()
	_rejilla.custom_minimum_size = Vector2(BOLSA_ANCHO, BOLSA_ALTO)
	_rejilla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(_rejilla)

	# La banda bajo la bolsa: el nombre del objeto elegido y, debajo, qué hace.
	_info = _etiqueta(15)
	_info.custom_minimum_size = Vector2(BOLSA_ANCHO, 44.0)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_info)

	# Última fila: la ayuda a la izquierda y, a la derecha, el oro (moneda + cifra).
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(fila)
	var pista := _etiqueta(13)
	pista.add_theme_color_override("font_color", TINTA)         # antes al 80 %: bajaba el contraste sobre el pergamino
	pista.text = "[I / Esc] cerrar   [↑↓←→] elegir   [Enter] beber"
	pista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pista.size_flags_vertical = Control.SIZE_SHRINK_END
	fila.add_child(pista)
	fila.add_child(Moneda.new())
	_oro = _etiqueta(20)
	_oro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_oro.tooltip_text = "Oro"
	_oro.mouse_filter = Control.MOUSE_FILTER_PASS
	fila.add_child(_oro)

	_cerrar = Cerrar.new()
	_cerrar.pulsado.connect(func(): if abierta: alternar())
	_marco.add_child(_cerrar)

	get_viewport().size_changed.connect(_colocar)
	Estado.i().cambiado.connect(_refrescar)
	_refrescar()


func _exit_tree() -> void:
	# Cambiar de escena con la mochila abierta no puede dejar el mundo pausado.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if abierta and is_inside_tree():
		get_tree().paused = false


## Mide el marco, lo centra y devuelve la posición de reposo.
func _colocar() -> Vector2:
	if _panel == null:
		return Vector2.ZERO
	_panel.size = _panel.get_combined_minimum_size()
	_marco.size = _panel.size
	_marco.pivot_offset = _marco.size * 0.5
	_cerrar.position = Vector2(_marco.size.x - 40.0, 3.0)
	var vista: Vector2 = get_viewport().get_visible_rect().size
	var reposo: Vector2 = ((vista - _marco.size) * 0.5).round()
	reposo.y = maxf(8.0, reposo.y)       # si la ventana es baja, que al menos no se salga por arriba
	if abierta and (_tween == null or not _tween.is_running()):
		_marco.position = reposo
	return reposo


func alternar() -> void:
	abierta = not abierta
	Sonidos.play(self, "bolsa", -4.0, 1.0 if abierta else 0.85)
	get_tree().paused = abierta
	_refrescar()
	_animar(abierta)


## Abre/cierra como el grimorio: sube desde abajo y escala de 0,9 a 1 con TRANS_BACK, con el velo; al cerrar, lo inverso
## más rápido. El tween ignora el time_scale y corre aunque el árbol esté pausado.
func _animar(abre: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var reposo: Vector2 = _colocar()
	var fuera: Vector2 = reposo + Vector2(0.0, SUBIDA)
	_tween = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	if abre:
		_marco.visible = true
		_velo.visible = true
		_velo.mouse_filter = Control.MOUSE_FILTER_STOP
		_marco.mouse_filter = Control.MOUSE_FILTER_PASS
		_marco.position = fuera
		_marco.scale = Vector2(0.9, 0.9)
		_marco.modulate.a = 0.0
		_velo.color.a = 0.0
		_tween.tween_property(_marco, "position", reposo, T_ABRIR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_marco, "scale", Vector2.ONE, T_ABRIR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_marco, "modulate:a", 1.0, T_ABRIR * 0.6)
		_tween.tween_property(_velo, "color:a", VELO_ALFA, T_ABRIR)
	else:
		_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tween.tween_property(_marco, "position", fuera, T_CERRAR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_tween.tween_property(_marco, "scale", Vector2(0.9, 0.9), T_CERRAR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_tween.tween_property(_marco, "modulate:a", 0.0, T_CERRAR)
		_tween.tween_property(_velo, "color:a", 0.0, T_CERRAR)
		_tween.chain().tween_callback(_ocultar)


func _ocultar() -> void:
	if abierta:
		return
	_marco.visible = false
	_velo.visible = false


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_I:
		get_viewport().set_input_as_handled()
		alternar()
	elif k.keycode == KEY_ESCAPE and abierta:
		get_viewport().set_input_as_handled()
		alternar()
	elif abierta:
		match k.keycode:
			KEY_UP:
				get_viewport().set_input_as_handled()
				mover(Vector2.UP)
			KEY_DOWN:
				get_viewport().set_input_as_handled()
				mover(Vector2.DOWN)
			KEY_LEFT:
				get_viewport().set_input_as_handled()
				mover(Vector2.LEFT)
			KEY_RIGHT:
				get_viewport().set_input_as_handled()
				mover(Vector2.RIGHT)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				get_viewport().set_input_as_handled()
				usar_elegido()


func _refrescar() -> void:
	var e: Estado = Estado.i()
	_oro.text = str(e.oro)
	if not abierta:
		return
	for h in _huecos:
		if is_instance_valid(h):
			(h as Node).queue_free()
	_huecos.clear()
	# Una entrada por pila (si hay más de 9, ocupa varios huecos), en orden de categoría; cada una en su ancla.
	var pilas: Array = _pilas(e)
	var anc: PackedVector2Array = anclas()
	for i in range(anc.size()):
		var h := Hueco.new()
		h.tam = TAM_BOLSA
		h.indice = i
		h.bloqueado = i >= e.capacidad
		if i < pilas.size() and not h.bloqueado:
			h.id = String(pilas[i][0])
			h.cantidad = int(pilas[i][1])
			h.cura = Objetos.cura(h.id)
			h.tooltip_text = "%s\n%s" % [Objetos.nombre(h.id), String(Objetos.DATOS.get(h.id, {}).get("desc", ""))]
			h.pulsado = _usar
			h.al_pasar = _elegir
		elif h.bloqueado:
			h.tooltip_text = "Hueco bloqueado: el alquimista puede ampliar la mochila"
		h.size = Vector2(TAM_BOLSA, TAM_BOLSA)
		h.position = anc[i] - Vector2(TAM_BOLSA, TAM_BOLSA) * 0.5
		_rejilla.add_child(h)
		_huecos.append(h)
	# La selección sigue en su hueco si aún tiene objeto; si no, pasa al primero con objeto.
	if _sel < 0 or _sel >= _huecos.size() or (_huecos[_sel] as Hueco).id == "":
		_sel = _primero_ocupado()
	_elegir(_sel)


## ¿Qué hueco está elegido? (-1 = ninguno). Para las pruebas y para quien quiera leerlo.
func elegido() -> int:
	return _sel


func hueco(i: int) -> Hueco:
	return _huecos[i] as Hueco if i >= 0 and i < _huecos.size() else null


func _primero_ocupado() -> int:
	for i in range(_huecos.size()):
		if (_huecos[i] as Hueco).id != "":
			return i
	return -1


## Elige un hueco (ratón o teclado): pinta su aro y pone su nombre en la banda de debajo de la bolsa.
func _elegir(i: int) -> void:
	_sel = i
	for k in range(_huecos.size()):
		var h: Hueco = _huecos[k]
		var ahora: bool = k == _sel and h.id != ""
		if h.elegido != ahora:
			h.elegido = ahora
			h.queue_redraw()
	_pintar_nombre()


## La banda: nombre del objeto elegido y su descripción; sin elegido, cuántos huecos se usan.
func _pintar_nombre() -> void:
	var e: Estado = Estado.i()
	var h: Hueco = hueco(_sel)
	if h != null and h.id != "":
		var cal: String = MarcoCalidad.normalizar(h.calidad)
		var rareza: String = "" if cal == Objetos.CALIDAD_COMUN else "  ·  " + String((Objetos.CALIDADES[cal] as Dictionary)["nombre"])
		_info.text = "%s%s\n%s" % [Objetos.nombre(h.id), rareza, String(Objetos.DATOS.get(h.id, {}).get("desc", ""))]
	else:
		_info.text = "%d/%d huecos" % [e.huecos_usados(), e.capacidad]


## Mueve la elección con las flechas: al hueco con objeto más cercano en esa dirección. Sin elegido, empieza por el primero.
func mover(dir: Vector2) -> void:
	if _huecos.is_empty():
		return
	if _sel < 0 or hueco(_sel).id == "":
		_elegir(_primero_ocupado())
		return
	var validos: Array = []
	for h in _huecos:
		validos.append((h as Hueco).id != "")
	var j: int = vecino(_sel, dir, validos)
	if j >= 0:
		_elegir(j)


## Usa el objeto elegido (Enter / Espacio / E): hoy solo las pociones se usan.
func usar_elegido() -> void:
	var h: Hueco = hueco(_sel)
	if h != null and h.id != "":
		_usar(h.id)


func _usar(id: String) -> void:
	if id == "pocion":
		var j: Node = get_tree().get_first_node_in_group("player")
		if j != null and j.has_method("usar_pocion"):
			# En 3D el jugador solo bebe con el árbol en marcha: se cierra la mochila antes (y se reanuda el mundo).
			if abierta and j.get("jugador") != null:
				alternar()
			j.call("usar_pocion")


func _pilas(e: Estado) -> Array:
	return ordenar(e.items)
