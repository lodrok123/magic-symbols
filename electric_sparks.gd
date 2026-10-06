class_name ElectricSparks
extends Node2D

## LO QUE SE VE CUANDO ALGO ESTÁ ELECTRIFICADO.
##
## La corriente se PASA de pieza en pieza en 0,6 s (ver Circuit), pero lo que
## ve el jugador dura más: la pieza queda soltando chispas unos 5 s. Esto es
## solo el dibujo — no decide nada, no propaga nada — así que cada pieza
## electrificada lo anima a la vez y por su cuenta, sin cadena.
##
## Sirve para cualquier bloque con forma de rombo: agua, placas, y lo que se
## apunte mañana. Uso:   ElectricSparks.en(self).activar()
##
##   arcos del borde   zigzags que recorren el contorno del rombo
##   rayitos           dos o tres arcos cortos que cruzan la superficie
##   chispas           puntos brillantes que saltan hacia arriba
##
## El dibujo se "re-sortea" ~12 veces por segundo (así parpadea como una
## descarga y no se mece como una cinta). Al final del tiempo se hace más
## ralo y más débil hasta apagarse.

const DURACION: float = 5.0
const HZ: float = 12.0

const C_NUCLEO: Color = Color(1.0, 1.0, 0.88)
const C_HALO: Color = Color(0.45, 0.75, 1.0)

var _resto: float = 0.0
var _t: float = 0.0
var _dur: float = DURACION


## El componente de `nodo`, creado la primera vez que se pide.
static func en(nodo: Node2D) -> ElectricSparks:
	var e: Node = nodo.get_node_or_null("Chispas")
	if e is ElectricSparks:
		return e
	var n := ElectricSparks.new()
	n.name = "Chispas"
	n.z_index = 2
	nodo.add_child(n)
	return n


func activar(dur: float = DURACION) -> void:
	_dur = dur
	_resto = dur
	show()
	queue_redraw()


func apagar() -> void:
	_resto = 0.0
	queue_redraw()


func _ready() -> void:
	_resto = 0.0


func _process(delta: float) -> void:
	if _resto <= 0.0:
		return
	_resto -= delta
	_t += delta
	queue_redraw()


func _esq() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, -IsoGrid.STEP.y), Vector2(IsoGrid.STEP.x, 0.0),
		Vector2(0.0, IsoGrid.STEP.y), Vector2(-IsoGrid.STEP.x, 0.0)])


## Un zigzag de `a` a `b`; `sal` es cuánto se aparta de la recta.
func _zig(a: Vector2, b: Vector2, sal: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var d: Vector2 = b - a
	var n: int = maxi(3, int(d.length() / 9.0))
	var perp := Vector2(-d.y, d.x).normalized()
	for i in range(1, n):
		pts.append(a + d * (float(i) / float(n)) + perp * rng.randf_range(-sal, sal))
	pts.append(b)
	return pts


func _rayo(pts: PackedVector2Array, e: float) -> void:
	draw_polyline(pts, Color(C_HALO, 0.30 * e), 5.0, true)
	draw_polyline(pts, Color(C_HALO, 0.75 * e), 2.4, true)
	draw_polyline(pts, Color(C_NUCLEO, 0.95 * e), 1.1, true)


func _draw() -> void:
	if _resto <= 0.0:
		return
	# Envolvente: pleno casi todo el tiempo y se va apagando al final.
	var vida: float = clampf(_resto / _dur, 0.0, 1.0)
	var e: float = smoothstep(0.0, 0.35, vida)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_t * HZ) * 7919 + get_instance_id() % 1000

	var esq: PackedVector2Array = _esq()

	# 0) Un velo tenue que late: el bloque "vibra" de energía.
	var late: float = 0.5 + 0.5 * sin(_t * 30.0)
	draw_colored_polygon(esq, Color(0.55, 0.8, 1.0, (0.05 + 0.07 * late) * e))

	# 1) Arcos por el contorno: dos o tres tramos de arista con zigzag.
	for _i in range(3):
		if rng.randf() > 0.35 + 0.65 * e:
			continue
		var k: int = rng.randi() % 4
		var a: Vector2 = esq[k].lerp(esq[(k + 1) % 4], rng.randf_range(0.0, 0.5))
		var b: Vector2 = esq[k].lerp(esq[(k + 1) % 4], rng.randf_range(0.6, 1.0))
		_rayo(_zig(a, b, 3.5, rng), e)

	# 2) Rayitos que cruzan la superficie de un punto a otro.
	for _i in range(2):
		if rng.randf() > 0.25 + 0.75 * e:
			continue
		var a := Vector2(rng.randf_range(-0.7, 0.7) * IsoGrid.STEP.x, rng.randf_range(-0.6, 0.6) * IsoGrid.STEP.y)
		var b: Vector2 = a + Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(-10.0, 10.0))
		_rayo(_zig(a, b, 4.0, rng), e)

	# 3) Chispas: puntos brillantes que saltan un poco hacia arriba.
	for _i in range(6):
		if rng.randf() > 0.3 + 0.7 * e:
			continue
		var p := Vector2(rng.randf_range(-0.8, 0.8) * IsoGrid.STEP.x, rng.randf_range(-0.7, 0.7) * IsoGrid.STEP.y)
		var s: Vector2 = p + Vector2(rng.randf_range(-3.0, 3.0), -rng.randf_range(2.0, 14.0))
		draw_line(p, s, Color(C_NUCLEO, 0.8 * e), 1.2)
		draw_circle(s, 1.7, Color(0.65, 0.88, 1.0, 0.95 * e))
