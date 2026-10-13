class_name IsoGrid
extends RefCounted

## LA CONVERSIÓN ENTRE REJILLA Y PANTALLA.
##
## En isométrico, la casilla (3, 5) no está "tres a la derecha y cinco
## abajo": está donde diga el rombo. Toda la vista isométrica se reduce
## a esta función y a su inversa; el resto del juego sigue pensando en
## casillas, que es como se piensan los puzles.
##
## La geometría NO me la he inventado: viene del propio pack. El archivo
## Map/map_tiles.tsx de Sketch Town declara
##     <grid orientation="isometric" width="232" height="110"/>
## Medir el sprite a ojo habría salido mal, porque en estas piezas la
## hierba DESBORDA el borde del cubo: la parte verde mide 154 px de alto
## pero el rombo real son 110. Fiarme del recorte habría descuadrado el
## mapa entero por 44 px en cada casilla.

## A qué escala se usan las piezas. Las originales son de 256x352, que
## a tamaño completo solo dejarían ver cinco casillas en pantalla.
const SCALE: float = 0.5

## El rombo de una casilla, ya escalado: 232x110 a la mitad.
const TILE: Vector2 = Vector2(116.0, 55.0)

## Medio rombo. Es el paso real: moverse una casilla en X avanza media
## anchura a la derecha y media altura hacia abajo.
const STEP: Vector2 = Vector2(58.0, 27.5)

## Cuánto sube un nivel de altura. Es el lateral del cubo: el contenido
## del sprite mide 221 px, de los cuales 110 son la cara de arriba, así
## que el costado son 111 -> 55.5 a media escala.
const LEVEL: float = 55.5


## Casilla -> posición en pantalla del CENTRO DE LA CARA SUPERIOR, que
## es donde se pisa. `height` sube el bloque en niveles enteros.
##
## X positivo va hacia la derecha-abajo; Y positivo hacia la
## izquierda-abajo. Es el convenio isométrico de toda la vida, y el que
## usa el propio pack.
static func to_screen(cell: Vector2i, height: int = 0) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * STEP.x,
		(cell.x + cell.y) * STEP.y - height * LEVEL
	)


## La inversa: dónde ha pinchado el ratón, o en qué casilla está el
## jugador. Se despeja el sistema de dos ecuaciones de arriba.
static func to_cell(screen: Vector2) -> Vector2i:
	var fx: float = screen.x / STEP.x
	var fy: float = screen.y / STEP.y
	return Vector2i(
		int(round((fy + fx) * 0.5)),
		int(round((fy - fx) * 0.5))
	)


## La pisada de un ACTOR: el mismo rombo, encogido.
##
## Un círculo no vale, y no es un detalle estético. En un mundo aplastado
## 2:1 un círculo MIENTE: ocupa el doble de casillas a lo alto de las que
## aparenta, así que el personaje se engancha en bordes que no se ven y
## se cuela por huecos que parecen cerrados. La pisada tiene que estar
## aplastada igual que el suelo que pisa.
static func footprint(fraccion: float) -> ConvexPolygonShape2D:
	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([
		Vector2(0.0, -STEP.y * fraccion),
		Vector2(STEP.x * fraccion, 0.0),
		Vector2(0.0, STEP.y * fraccion),
		Vector2(-STEP.x * fraccion, 0.0),
	])
	return shape


## El rombo de la casilla, para usarlo de forma de colisión.
##
## Un rectángulo NO vale: dos casillas vecinas en diagonal comparten
## solo una esquina, y con rectángulos se solaparían. Además el jugador
## se quedaría enganchado en bordes que visualmente no existen.
static func diamond() -> ConvexPolygonShape2D:
	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([
		Vector2(0.0, -STEP.y),
		Vector2(STEP.x, 0.0),
		Vector2(0.0, STEP.y),
		Vector2(-STEP.x, 0.0),
	])
	return shape
