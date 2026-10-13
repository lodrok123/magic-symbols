class_name SpellBeam
extends Node2D

## EL HAZ DEL RAYO.
##
## El rayo no viaja: EXISTE de golpe entre quien lo lanza y lo primero que
## golpea. Se dibuja con el mismo arte de siempre (RuneData.vfx_sheet, un
## zigzag que cae desde arriba) GIRADO 90 grados, de modo que "arriba" queda
## en el origen y "abajo" en el objetivo.
##
## Un solo dibujo mide unos 90 px de largo, y un haz llega a 480. Se
## ENCADENAN varios, y uno de cada dos va en espejo: cada zigzag acaba
## desplazado de lado respecto a donde empezó, y con un espejo alterno esa
## deriva se cancela en vez de sumarse (el haz se iría de la línea recta).
##
## En modo silueta no hay arte: una barra blanca, que es lo que el sello
## dice (una línea de origen a impacto).

const CELDA: float = 128.0
const COLUMNAS: int = 6
## Lo que mide DE VERDAD el rayo dibujado dentro de su celda de 128. El
## resto de la celda es margen.
const LARGO_DIBUJO: float = 116.0
const ANCHO: float = 0.75
const FPS: float = 36.0

var _desde: Vector2 = Vector2.ZERO
var _hasta: Vector2 = Vector2.ZERO
var _runa: RuneData = null
var _ancho: float = 1.0
var _edad: float = 0.0
var _frames: int = 1
var _segmentos: Array[Sprite2D] = []


## `desde` y `hasta` son posiciones de MUNDO.
static func fire(padre: Node, desde: Vector2, hasta: Vector2, runa: RuneData, ancho: float = 1.0) -> SpellBeam:
	var b := SpellBeam.new()
	b._desde = desde
	b._hasta = hasta
	b._runa = runa
	b._ancho = ancho
	b._frames = maxi(runa.frames_for(1.0), 1)
	padre.add_child(b)
	b.global_position = desde
	b._montar()
	return b


func _montar() -> void:
	if SpellForm.silhouette or _runa.vfx_sheet == null:
		return

	var largo: float = _desde.distance_to(_hasta)
	var d: Vector2 = (_hasta - _desde).normalized()
	var util: float = LARGO_DIBUJO * ANCHO
	var n: int = maxi(1, roundi(largo / util))
	var largo_seg: float = largo / float(n)

	for i in range(n):
		var s := Sprite2D.new()
		s.texture = _runa.vfx_sheet
		s.region_enabled = true
		s.region_rect = Rect2(0.0, 0.0, CELDA, CELDA)
		# El zigzag original cae hacia +y; girado esto lo pone a lo largo
		# del haz. rotation = ángulo del haz - 90°.
		s.rotation = d.angle() - PI * 0.5
		# X es el ancho del rayo (transversal); Y es el largo, y se estira
		# lo justo para que los tramos encajen exactos en la distancia.
		s.scale = Vector2(ANCHO * _ancho, largo_seg / LARGO_DIBUJO)
		s.flip_h = (i % 2) == 1
		s.position = d * largo_seg * (float(i) + 0.5)
		add_child(s)
		_segmentos.append(s)


func _process(delta: float) -> void:
	_edad += delta
	var idx: int = int(_edad * FPS)
	if idx >= _frames:
		queue_free()
		return

	var col: int = idx % COLUMNAS
	var fila: int = idx / COLUMNAS
	for s in _segmentos:
		s.region_rect = Rect2(float(col) * CELDA, float(fila) * CELDA, CELDA, CELDA)

	if SpellForm.silhouette:
		queue_redraw()


func _draw() -> void:
	if not SpellForm.silhouette:
		return
	var fin: Vector2 = _hasta - _desde
	# La barra se afina al final de su vida, igual que el arte se apaga.
	var t: float = clampf(_edad * FPS / float(_frames), 0.0, 1.0)
	var grosor: float = 10.0 * _ancho * (1.0 - smoothstep(0.6, 1.0, t))
	if grosor < 0.5:
		return
	draw_line(Vector2.ZERO, fin, Color.WHITE, grosor, true)
	draw_circle(Vector2.ZERO, grosor * 0.6, Color.WHITE)
	draw_circle(fin, grosor * 0.6, Color.WHITE)
