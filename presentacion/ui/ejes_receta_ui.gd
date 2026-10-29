class_name EjesRecetaUi
extends RefCounted

## EL LIBRO ENSEÑA LOS EJES DE LA RECETA V2 (Pipeline, 18/10; docs/GLIFOS_RECETA.md §2.1). Dibujo puro y SIN estado: cada función pinta en el
## `CanvasItem` que le pasen (hay que llamarlas desde su `_draw`) y no sabe nada del Spellcaster, del Repertoire ni de Sigils. Por eso vive
## aquí (Pipeline) y no en `spellbook.gd` (Juego): el Juego solo tiene que llamar y pasarle datos.
##
## Tres piezas, una por cada cosa que pidió Pablo:
##   1. `dibujar_casilla`      la chuleta de la página derecha: ᛁ se enseña con sus DOS orientaciones (ancho X y profundidad Z), ᛏ como altura Y,
##                              y las propiedades con lo que hacen (flecha → viaja, barrera → solidez…) y cuántas lleva la página.
##   2. `giro_linea`           el ángulo con el que se pinta ᛁ según su eje. `linea.png` es una raya VERTICAL (medido: x 43–52, y 10–85 de 96),
##                              así que la que se GIRA 90° es la X (horizontal); la Z (profundidad) va tal cual. No hace falta arte nuevo.
##   3. `dibujar_indicador`    un cubo esquemático con las dimensiones X·Y·Z de la página, para el núcleo.
## Los tres ejes tienen SIEMPRE el mismo color (COLOR_X/Y/Z) en la leyenda y en el cubo, para que el jugador una «ancho» con la arista roja
## sin leer nada: es la única conexión entre lo que dibuja y lo que ve.

const TINTA: Color = Color(0.24, 0.19, 0.16)
## Marca de agua de un glifo sin muestras grabadas: la misma que `Spellbook.LEGEND_FADED`.
const TINTA_APAGADA: Color = Color(0.24, 0.19, 0.16, 0.16)
## Colores de los ejes, sacados de la propia lámina del bosque (flores, hojas, cielo) para que no parezcan pegados encima.
const COLOR_X: Color = Color(0.70, 0.30, 0.20)
const COLOR_Y: Color = Color(0.27, 0.48, 0.25)
const COLOR_Z: Color = Color(0.20, 0.40, 0.58)
const PAPEL: Color = Color(0.96, 0.90, 0.78)

## `linea.png` mira hacia arriba (vertical): X (horizontal) = girada un cuarto de vuelta; Z (profundidad) = como viene.
const GIRO_LINEA: Dictionary = {"linea_x": PI * 0.5, "linea_z": 0.0}

## Lo que hace cada propiedad, en una palabra (es el parámetro de la receta, `Sigils.GLIFOS[...]["modificadores"][..]["campo"]`, dicho en llano).
const EFECTO: Dictionary = {"flecha": "viaja", "barrera": "solidez", "repeticion": "copias", "rebote": "rebotes", "pulso": "crecer", "raido": "pulso"}   # 23/10: ᚷ (id `pulso`) se ve como «crecer» y ᚱ (id `raido`) como «pulso» (Sigils.NOMBRE_VISIBLE)
## Lo más grande que puede medir un hechizo en casillas (X, Y, Z): 2 × los topes de `Sigils.GLIFOS` (3, 2, 3). Sirve para escalar el cubo.
const MAX_CASILLAS: Vector3 = Vector3(6.0, 4.0, 6.0)


## El ángulo (radianes, sentido horario) con el que hay que pintar ᛁ: 90° si es `linea_x`, 0 si es `linea_z`. Cualquier otro nombre, 0.
## ᛁ queda EXENTA del giro hacia el centro del sector (`GestureLibrary.giro_glifo`): su dirección la da el eje, no el hueco.
static func giro_linea(nombre: String) -> float:
	return float(GIRO_LINEA.get(nombre, 0.0))


## ¿Es un glifo cuya orientación NO depende del sector? (para que `Spellbook` se salte `giro_glifo`).
static func exenta_del_giro(nombre: String) -> bool:
	return GIRO_LINEA.has(nombre)


## Tamaño total (en casillas) del elipsoide `g` = {x, y, z: SEMIEJES}: una esfera base (semieje 0,5) mide 1 × 1 × 1.
static func dimensiones(g: Dictionary) -> Vector3:
	return Vector3(2.0 * float(g.get("x", 0.5)), 2.0 * float(g.get("y", 0.5)), 2.0 * float(g.get("z", 0.5)))


## «2» o «2,5»: el número en casillas con coma decimal y sin ceros de más.
static func texto_casillas(v: float) -> String:
	if absf(v - roundf(v)) < 0.05:
		return str(int(roundf(v)))
	return ("%.1f" % v).replace(".", ",")


## Dónde cae el cubo dentro del núcleo (centro `c`, radio `radio`): a la derecha del glifo y por encima del nombre, donde el glifo del elemento deja
## el papel libre (en la esquina de arriba a la derecha, que era lo primero que probé, el cubo se montaba sobre el borde del círculo). Es una sugerencia: el Juego puede ponerlo donde prefiera.
static func sitio_en_nucleo(c: Vector2, radio: float) -> Vector2:
	return c + Vector2(0.50, 0.12) * radio


## ============================== 1. LA CHULETA ==============================

## Pinta UNA casilla de la leyenda si es de las que cambian con la receta V2 (ᛁ, ᛏ/altura y las cinco propiedades) y devuelve true; para
## cualquier otro glifo devuelve false sin pintar nada, y el Spellbook sigue con su dibujo de siempre.
##   nombre     nombre del glifo en el libro: "linea", "levitacion" (o "altura"), "flecha", "barrera", "repeticion", "rebote", "pulso"
##   glifo      su textura (`Sigils.GLYPHS[nombre]`); para ᛁ, la de `linea`
##   centro     centro del óvalo en la pantalla; `tam` = lado del glifo (como `glifo_tam`)
##   tinta      color del glifo ya conocido; `conocida` = false → marca de agua, sin rótulos (como hoy)
##   usos       cuántas veces lleva la PÁGINA ABIERTA cada glifo: {"linea_x": 2, "linea_z": 0, "altura": 1, "flecha": 1, ...}; vacío = no marca nada
static func dibujar_casilla(canvas: CanvasItem, nombre: String, glifo: Texture2D, centro: Vector2, tam: float, tinta: Color, conocida: bool,
		usos: Dictionary = {}) -> bool:
	if glifo == null:
		return false
	var pinta: Color = tinta if conocida else TINTA_APAGADA
	match nombre:
		"linea":
			# Dos lecturas de la misma raya: horizontal = ancho (X), vertical = profundidad (Z).
			var sep: float = tam * 0.70
			_glifo(canvas, glifo, centro + Vector2(-sep, -tam * 0.04), tam * 0.92, giro_linea("linea_x"), pinta)
			_glifo(canvas, glifo, centro + Vector2(sep, -tam * 0.04), tam * 0.92, giro_linea("linea_z"), pinta)
			if conocida:
				_rotulo(canvas, centro + Vector2(-sep * 0.72, tam * 0.60), "ancho", tam * 0.82, COLOR_X)
				_rotulo(canvas, centro + Vector2(sep * 0.72, tam * 0.60), "fondo", tam * 0.82, COLOR_Z)
				_insignia(canvas, centro + Vector2(-sep - tam * 0.36, -tam * 0.52), int(usos.get("linea_x", 0)), tam, COLOR_X)
				_insignia(canvas, centro + Vector2(sep + tam * 0.36, -tam * 0.52), int(usos.get("linea_z", 0)), tam, COLOR_Z)
			return true
		"levitacion", "altura":
			_glifo(canvas, glifo, centro + Vector2(0.0, -tam * 0.04), tam, 0.0, pinta)
			if conocida:
				_rotulo(canvas, centro + Vector2(0.0, tam * 0.64), "altura", tam, COLOR_Y)
				_insignia(canvas, centro + Vector2(tam * 0.95, -tam * 0.52), int(usos.get("altura", usos.get("levitacion", 0))), tam, COLOR_Y)
			return true
		"flecha", "barrera", "repeticion", "rebote", "pulso", "raido":
			_glifo(canvas, glifo, centro + Vector2(0.0, -tam * 0.04), tam, 0.0, pinta)
			if conocida:
				_rotulo(canvas, centro + Vector2(0.0, tam * 0.64), String(EFECTO[nombre]), tam, tinta)
				_insignia(canvas, centro + Vector2(tam * 0.95, -tam * 0.52), int(usos.get(nombre, 0)), tam, tinta)
			return true
	return false


static func _glifo(canvas: CanvasItem, tex: Texture2D, centro: Vector2, lado: float, angulo: float, tinta: Color) -> void:
	canvas.draw_set_transform(centro, angulo, Vector2.ONE)
	canvas.draw_texture_rect(tex, Rect2(-lado * 0.5, -lado * 0.5, lado, lado), false, tinta)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _rotulo(canvas: CanvasItem, pos: Vector2, texto: String, tam: float, color: Color) -> void:
	var fuente: Font = ThemeDB.fallback_font
	var cuerpo: int = maxi(int(roundf(tam * 0.24)), 8)
	var ancho: float = fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, cuerpo).x
	canvas.draw_string(fuente, pos - Vector2(ancho * 0.5, 0.0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, cuerpo, Color(color, 0.9))


## Disco con el nº de glifos de ese tipo que lleva la página abierta. Con 0 no pinta nada (la casilla no «grita» lo que no se usa).
static func _insignia(canvas: CanvasItem, pos: Vector2, n: int, tam: float, color: Color) -> void:
	if n <= 0:
		return
	var r: float = tam * 0.17
	canvas.draw_circle(pos, r, Color(color, 0.92))
	var fuente: Font = ThemeDB.fallback_font
	var cuerpo: int = maxi(int(roundf(tam * 0.22)), 8)
	var t: String = str(n)
	var ancho: float = fuente.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, cuerpo).x
	canvas.draw_string(fuente, pos + Vector2(-ancho * 0.5, cuerpo * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, cuerpo, PAPEL)


## ============================== 3. EL CUBO ESQUEMÁTICO ==============================

## Caja isométrica con las proporciones de la página y debajo «x·y·z» en casillas, cada número del color de su eje.
##   centro   centro del dibujo en pantalla; `tam` = ALTO del cubo mayor posible (6 × 4 × 6 casillas): lo normal es mucho menor
##   g        {x, y, z: semiejes del elipsoide en casillas} (lo que da `Sigils.aplicar_v2` / `GeometriaV2.evaluar`)
## Cada arista se escala a su máximo (MAX_CASILLAS) con un mínimo del 22 % para que la esfera base (1 × 1 × 1) siga viéndose como cubo.
## Devuelve el tamaño total en casillas por si el Juego quiere usarlo (rótulo, tooltip).
static func dibujar_indicador(canvas: CanvasItem, centro: Vector2, tam: float, g: Dictionary, tinta: Color = TINTA, con_texto: bool = true) -> Vector3:
	var dim: Vector3 = dimensiones(g)
	var l := Vector3(
		clampf(dim.x / MAX_CASILLAS.x, 0.22, 1.0), clampf(dim.y / MAX_CASILLAS.y, 0.22, 1.0), clampf(dim.z / MAX_CASILLAS.z, 0.22, 1.0)) * tam * 0.5
	# (× 0,5: con las tres aristas al máximo la isométrica mide 1,73·s de ancho y 2·s de alto, así que `tam` = el alto máximo y el ancho máximo 0,87·tam)
	# Isométrica: X sube a la derecha, Z sube a la izquierda, Y sube recto. P0 = vértice de abajo, el más cercano.
	var ex := Vector2(0.866, -0.5) * l.x
	var ez := Vector2(-0.866, -0.5) * l.z
	var ey := Vector2(0.0, -1.0) * l.y
	var p0 := Vector2.ZERO
	var puntos: Array[Vector2] = [p0, ex, ez, ey, ex + ez, ex + ey, ez + ey, ex + ez + ey]
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in puntos:
		mn = mn.min(p)
		mx = mx.max(p)
	# El dibujo se centra en `centro`; el texto cuelga debajo de la caja, no del centro.
	var origen: Vector2 = centro - (mn + mx) * 0.5
	var grosor: float = maxf(tam * 0.035, 1.5)
	# Caras (de atrás hacia delante no hace falta: son tres y no se tapan): arriba, izquierda (Z·Y) y derecha (X·Y).
	canvas.draw_colored_polygon(PackedVector2Array([origen + ey, origen + ex + ey, origen + ex + ez + ey, origen + ez + ey]), Color(tinta, 0.10))
	canvas.draw_colored_polygon(PackedVector2Array([origen, origen + ez, origen + ez + ey, origen + ey]), Color(COLOR_Z, 0.16))
	canvas.draw_colored_polygon(PackedVector2Array([origen, origen + ex, origen + ex + ey, origen + ey]), Color(COLOR_X, 0.16))
	# Contorno fino, y encima las tres aristas que salen del vértice cercano con el color de su eje (se leen como «los tres ejes»).
	var fino := Color(tinta, 0.55)
	for par in [[ey, ex + ey], [ex + ey, ex + ez + ey], [ex + ez + ey, ez + ey], [ez + ey, ey], [ex, ex + ey], [ez, ez + ey], [ex, ex + ez], [ez, ex + ez], [ex + ez, ex + ez + ey]]:
		canvas.draw_line(origen + (par[0] as Vector2), origen + (par[1] as Vector2), fino, grosor * 0.6, true)
	canvas.draw_line(origen, origen + ex, COLOR_X, grosor * 1.6, true)
	canvas.draw_line(origen, origen + ez, COLOR_Z, grosor * 1.6, true)
	canvas.draw_line(origen, origen + ey, COLOR_Y, grosor * 1.6, true)
	if con_texto:
		_texto_dim(canvas, Vector2(centro.x, centro.y + (mx.y - mn.y) * 0.5 + tam * 0.19), dim, tam)
	return dim


static func _texto_dim(canvas: CanvasItem, pos: Vector2, dim: Vector3, tam: float) -> void:
	var fuente: Font = ThemeDB.fallback_font
	var cuerpo: int = maxi(int(roundf(tam * 0.17)), 8)
	var trozos: Array = [[texto_casillas(dim.x), COLOR_X], ["·", TINTA], [texto_casillas(dim.y), COLOR_Y], ["·", TINTA], [texto_casillas(dim.z), COLOR_Z]]
	var total: float = 0.0
	for t in trozos:
		total += fuente.get_string_size(String(t[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, cuerpo).x
	# Se corre a la derecha: centrado, el arranque del texto rozaba la punta del glifo
	# del núcleo (medido en la captura con el cubo grande, «3·2·2,5»).
	var x: float = pos.x - total * 0.38
	for t in trozos:
		canvas.draw_string(fuente, Vector2(x, pos.y), String(t[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, cuerpo, Color(t[1] as Color, 0.95))
		x += fuente.get_string_size(String(t[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, cuerpo).x
