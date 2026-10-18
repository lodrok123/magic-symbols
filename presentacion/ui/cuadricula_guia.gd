class_name CuadriculaGuia
extends RefCounted

## REJILLA GUÍA DEL TRAZO (17/10, Pipeline, a petición de Pablo).
##
## Qué es: una cuadrícula MUY tenue sobre la página izquierda del libro (donde se dibuja) que guía el trazo: las runas se construyen
## sobre los nodos (horizontales, verticales y diagonales a 45°, que es lo que el trazo recto en 8 direcciones, `GestureRectify`,
## ya entiende). Ayuda al jugador a hacer bien la línea desde el principio y, con ello, al reconocimiento. Es solo adorno visual:
## no cambia el reconocimiento ni los puntos del trazo.
##
## Qué lleva (ver `LIBROS`):
##   · una cuadrícula continua en toda la página, alineada con los 4 × 4 nodos del SELLO (el paso sale del sello), que se apaga hacia
##     la cenefa para no pelearse con las enredaderas;
##   · una rejilla de 4 × 4 nodos, más fina, dentro de cada CÍRCULO DE GLIFO ABIERTO (los cerrados no se ven, igual que su aro).
## Todo se dibuja por código a partir de coordenadas de la lámina: no hay asset. Si se mueve un hueco o cambia la lámina, se cambia el
## número aquí, no una imagen.
##
## Uso (lo llama el Juego en `Spellbook._draw`, justo después de `_draw_book()` y antes de `_draw_huecos()`, para que quede POR DEBAJO de
## los aros, la leyenda y el trazo):
##   CuadriculaGuia.dibujar(self, Repertoire.libro, _huecos_abiertos(), _libro().get("hueco_radios", {}), _on_page, _lam)
## `a_pantalla(Vector2 lámina) -> Vector2` es `Spellbook._on_page` y `medida(float lámina) -> float` es `Spellbook._lam`.
## Con una lámina que no esté en `LIBROS` no dibuja nada. `activa = false` la apaga entera (por si Pablo quiere una opción).

## Interruptor global.
static var activa: bool = true

## Por lámina (todo en px de lámina, medido por Pipeline sobre la imagen; ver ARTE §16).
##   sello      centro y radio del círculo del sello (núcleo).
##   papel      zona de la página izquierda por la que se extiende la cuadrícula (dentro de la cenefa).
##   apaga      a cuántos px del borde de `papel` se apaga del todo (los puntos y las líneas).
##   nodos      nodos por lado dentro del sello y de cada hueco de glifo.
##   fill_sello / fill_hueco   qué fracción del radio ocupa el cuadrado de nodos (el sello fija el paso de la cuadrícula de página).
const LIBROS: Dictionary = {
	"bosque": {
		"sello": {"c": Vector2(433.7, 383.1), "r": 119.6},
		"papel": Rect2(200.0, 160.0, 490.0, 610.0),
		"apaga": 70.0,
		"nodos": 4,
		"fill_sello": 0.66,
		"fill_hueco": 0.62,
	},
}

## Tinta (marrón, el del trazo y los aros) y su opacidad. Más baja = más sutil. Los puntos del hueco son un poco más finos que los de la página.
const TINTA: Color = Color(0.36, 0.235, 0.157)
const ALFA_LINEA: float = 0.09           ## líneas de la página
const ALFA_PUNTO: float = 0.23           ## nodos de la página
const RADIO_PUNTO: float = 2.0           ## px de lámina
const ALFA_LINEA_HUECO: float = 0.11
const ALFA_PUNTO_HUECO: float = 0.26
const RADIO_PUNTO_HUECO: float = 1.6


static func dibujar(ci: CanvasItem, libro: String, huecos: Dictionary, radios: Dictionary, a_pantalla: Callable, medida: Callable) -> void:
	if not activa or ci == null or not LIBROS.has(libro) or not a_pantalla.is_valid() or not medida.is_valid():
		return
	var d: Dictionary = LIBROS[libro]
	var n: int = int(d["nodos"])
	var sello: Dictionary = d["sello"]
	var c0: Vector2 = sello["c"]
	var mitad: float = float(sello["r"]) * float(d["fill_sello"])
	var paso: float = 2.0 * mitad / float(n - 1)
	var papel: Rect2 = d["papel"]
	var apaga: float = float(d["apaga"])

	# Cuadrícula de página: los nodos caen donde caen los del sello (origen = su esquina arriba-izquierda).
	var o: Vector2 = c0 - Vector2(mitad, mitad)
	var i0: int = int(ceil((papel.position.x - o.x) / paso))
	var i1: int = int(floor((papel.end.x - o.x) / paso))
	var j0: int = int(ceil((papel.position.y - o.y) / paso))
	var j1: int = int(floor((papel.end.y - o.y) / paso))
	# Dentro de cada círculo de glifo abierto manda su rejilla fina: la de la página se aparta (si no, se superponen y se ve sucio).
	var libres: Array = []
	for sector in huecos:
		libres.append([huecos[sector], float(radios.get(sector, 58.1)) * 1.04])
	var linea: Color = Color(TINTA, ALFA_LINEA)
	var punto: Color = Color(TINTA, ALFA_PUNTO)
	var grosor: float = maxf(1.0, medida.call(1.0))
	# Líneas: tramos de una casilla, cada uno con la opacidad que toca en su punto medio (así se apagan hacia la cenefa, sin degradado de vértices).
	for j in range(j0, j1 + 1):
		var y: float = o.y + float(j) * paso
		for i in range(i0, i1):
			var a := Vector2(o.x + float(i) * paso, y)
			var b := Vector2(a.x + paso, y)
			var k: float = _apagado((a + b) * 0.5, papel, apaga) * _fuera_de(libres, a, b)
			if k > 0.0:
				ci.draw_line(a_pantalla.call(a), a_pantalla.call(b), Color(linea, linea.a * k), grosor)
	for i in range(i0, i1 + 1):
		var x: float = o.x + float(i) * paso
		for j in range(j0, j1):
			var a := Vector2(x, o.y + float(j) * paso)
			var b := Vector2(x, a.y + paso)
			var k: float = _apagado((a + b) * 0.5, papel, apaga) * _fuera_de(libres, a, b)
			if k > 0.0:
				ci.draw_line(a_pantalla.call(a), a_pantalla.call(b), Color(linea, linea.a * k), grosor)
	var rp: float = maxf(1.0, medida.call(RADIO_PUNTO))
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := Vector2(o.x + float(i) * paso, o.y + float(j) * paso)
			var k2: float = _apagado(p, papel, apaga) * _fuera_de(libres, p, p)
			if k2 > 0.0:
				ci.draw_circle(a_pantalla.call(p), rp, Color(punto, punto.a * k2))

	# Círculos de glifo ABIERTOS: 4 × 4 nodos más finos. `huecos` = sector -> centro (lámina); `radios` = sector -> radio (lámina).
	var lh: Color = Color(TINTA, ALFA_LINEA_HUECO)
	var ph: Color = Color(TINTA, ALFA_PUNTO_HUECO)
	var rph: float = maxf(1.0, medida.call(RADIO_PUNTO_HUECO))
	for sector in huecos:
		var c: Vector2 = huecos[sector]
		var r: float = float(radios.get(sector, 58.1))
		var m: float = r * float(d["fill_hueco"])
		var st: float = 2.0 * m / float(n - 1)
		for t in range(n):
			var x2: float = c.x - m + float(t) * st
			ci.draw_line(a_pantalla.call(Vector2(x2, c.y - m)), a_pantalla.call(Vector2(x2, c.y + m)), lh, grosor)
			var y2: float = c.y - m + float(t) * st
			ci.draw_line(a_pantalla.call(Vector2(c.x - m, y2)), a_pantalla.call(Vector2(c.x + m, y2)), lh, grosor)
		for jj in range(n):
			for ii in range(n):
				ci.draw_circle(a_pantalla.call(Vector2(c.x - m + float(ii) * st, c.y - m + float(jj) * st)), rph, ph)


## 1 si ni los extremos ni el punto medio del tramo a-b caen dentro de un círculo de glifo; 0 si alguno cae.
static func _fuera_de(libres: Array, a: Vector2, b: Vector2) -> float:
	for h in libres:
		var c: Vector2 = h[0]
		var r: float = h[1]
		if a.distance_to(c) < r or b.distance_to(c) < r or ((a + b) * 0.5).distance_to(c) < r:
			return 0.0
	return 1.0


## 1 en el interior de `papel`, 0 a `apaga` px de su borde hacia dentro (lineal; 0 fuera).
static func _apagado(p: Vector2, papel: Rect2, apaga: float) -> float:
	var m: float = minf(minf(p.x - papel.position.x, papel.end.x - p.x), minf(p.y - papel.position.y, papel.end.y - p.y))
	return clampf(m / maxf(apaga, 0.001), 0.0, 1.0)
