class_name TintaPluma2D
extends Node2D
## La tinta del trazo: grosor por velocidad y salpicadura al soltar (Fase 14.4 · 4.2, Pipeline).
##
## POR QUÉ. Una polilínea de ancho constante parece un rotulador. Una pluma de verdad deja más tinta cuando va despacio y adelgaza cuando
## corre, y al levantarla sale alguna gota. Es lo que hace que el trazo parezca escrito y no dibujado, y cuesta unas pocas líneas.
##
## USO (el Juego, en la capa de dibujo; esta clase no sabe de runas ni de reconocimiento):
##     tinta.empezar(punta, tiempo)          # al pulsar: `punta` = ManoPluma2D.punta(), `tiempo` en segundos
##     tinta.anadir(punta, tiempo)           # cada fotograma mientras se pulsa
##     tinta.soltar()                        # al soltar: remata y salpica
##     tinta.limpiar()                       # al borrar o lanzar el hechizo
##     tinta.dibujar_limpio(puntos)          # el redibujado «limpio» con la plantilla (0,2 s): trazo ya hecho, sin velocidades
## Cada llamada pide un redibujado; no hace nada por fotograma cuando no hay gotas volando.
##
## EL ANCHO. `ancho_por_velocidad(v)`: ANCHO_MAX parado y ANCHO_MIN a `VEL_MAX` px/s o más, con una curva suave (smoothstep), y luego se
## SUAVIZA entre puntos consecutivos (un filtro de paso bajo) para que el trazo no tenga escalones donde cambia la velocidad.
## LA PUNTA INICIAL: el primer punto lleva un pequeño borrón (la pluma toca el papel y suelta tinta).

const ANCHO_MAX: float = 7.0
const ANCHO_MIN: float = 2.4
const VEL_MAX: float = 900.0
const SUAVIZADO_ANCHO: float = 0.35         ## 0 = sin suavizar · 1 = se queda con el ancho del punto anterior
const BORRON_INICIAL: float = 1.35          ## el primer punto es así de ancho respecto a ANCHO_MAX
const GOTAS_MIN: int = 2
const GOTAS_MAX: int = 6
const GOTA_ALCANCE: float = 26.0            ## px que vuelan, como mucho
const T_GOTA: float = 0.10                  ## s que tarda una gota en llegar al papel
const MIN_DIST: float = 1.5                 ## px: puntos más juntos que esto no se añaden

@export var color: Color = Color(0.15, 0.25, 0.60)    ## la tinta azul de `spellbook.STROKE_INK`
@export var semilla: int = 11

var _puntos: PackedVector2Array = PackedVector2Array()
var _anchos: PackedFloat32Array = PackedFloat32Array()
var _t_ult: float = 0.0
var _gotas: Array = []                      ## [{pos, destino, radio, t}]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = semilla
	set_process(false)          # solo se procesa mientras vuela alguna gota


## Ancho de la línea para una velocidad en px/s. Estática y pura (se prueba sola).
static func ancho_por_velocidad(v: float) -> float:
	var k: float = smoothstep(0.0, VEL_MAX, absf(v))
	return lerpf(ANCHO_MAX, ANCHO_MIN, k)


func empezar(punto: Vector2, tiempo: float) -> void:
	limpiar()
	_puntos.append(punto)
	_anchos.append(ANCHO_MAX * BORRON_INICIAL)
	_t_ult = tiempo
	queue_redraw()


func anadir(punto: Vector2, tiempo: float) -> void:
	if _puntos.is_empty():
		empezar(punto, tiempo)
		return
	var d: float = _puntos[_puntos.size() - 1].distance_to(punto)
	if d < MIN_DIST:
		return
	var dt: float = maxf(tiempo - _t_ult, 0.001)
	var objetivo: float = ancho_por_velocidad(d / dt)
	var previo: float = _anchos[_anchos.size() - 1]
	# El primer ancho es el borrón: se sale de él suavemente, sin saltar al ancho de la velocidad.
	_anchos.append(lerpf(objetivo, previo, SUAVIZADO_ANCHO))
	_puntos.append(punto)
	_t_ult = tiempo
	queue_redraw()


## Remata el trazo y salpica: entre GOTAS_MIN y GOTAS_MAX gotas hacia delante, más y más lejos cuanto más deprisa iba.
func soltar() -> void:
	if _puntos.size() < 2:
		return
	var n: int = _puntos.size()
	var dir: Vector2 = (_puntos[n - 1] - _puntos[maxi(0, n - 4)]).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var rapidez: float = 1.0 - (_anchos[n - 1] - ANCHO_MIN) / (ANCHO_MAX - ANCHO_MIN)       # 0 = despacio · 1 = deprisa
	var cuantas: int = GOTAS_MIN + int(round(rapidez * float(GOTAS_MAX - GOTAS_MIN)))
	for i in cuantas:
		var ang: float = _rng.randf_range(-0.9, 0.9)
		var alc: float = _rng.randf_range(0.25, 1.0) * GOTA_ALCANCE * lerpf(0.5, 1.0, rapidez)
		_gotas.append({
			"pos": _puntos[n - 1],
			"destino": _puntos[n - 1] + dir.rotated(ang) * alc,
			"radio": _rng.randf_range(1.2, 3.0) * (1.0 - 0.5 * float(i) / float(maxi(cuantas, 1))),
			"t": 0.0,
		})
	set_process(true)
	queue_redraw()


func limpiar() -> void:
	_puntos = PackedVector2Array()
	_anchos = PackedFloat32Array()
	_gotas.clear()
	queue_redraw()


## Un trazo ya hecho (sin velocidades): ancho que crece al principio y adelgaza al final, como una pluma levantada.
func dibujar_limpio(puntos: PackedVector2Array) -> void:
	limpiar()
	_puntos = puntos
	var n: int = puntos.size()
	for i in n:
		var s: float = float(i) / float(maxi(n - 1, 1))
		_anchos.append(lerpf(ANCHO_MIN, ANCHO_MAX, sin(clampf(s, 0.0, 1.0) * PI) * 0.85 + 0.15))
	queue_redraw()


func n_puntos() -> int:
	return _puntos.size()


func n_gotas() -> int:
	return _gotas.size()


func anchos() -> PackedFloat32Array:
	return _anchos


func _process(delta: float) -> void:
	var vuelan: bool = false
	for g in _gotas:
		var gd: Dictionary = g
		if float(gd["t"]) < T_GOTA:
			gd["t"] = minf(float(gd["t"]) + delta, T_GOTA)
			var k: float = float(gd["t"]) / T_GOTA
			gd["pos"] = (gd["pos"] as Vector2).lerp(gd["destino"] as Vector2, 1.0 - pow(1.0 - k, 2.0))
			vuelan = true
	queue_redraw()
	if not vuelan:
		set_process(false)


func _draw() -> void:
	var n: int = _puntos.size()
	if n == 0:
		return
	# Cada tramo es un cuadrilátero entre los dos anchos, con un círculo en cada punto para que las uniones no dejen pico.
	for i in n:
		draw_circle(_puntos[i], _anchos[i] * 0.5, color)
	for i in range(1, n):
		var a: Vector2 = _puntos[i - 1]
		var b: Vector2 = _puntos[i]
		var d: Vector2 = b - a
		if d.length() < 0.001:
			continue
		var perp: Vector2 = Vector2(-d.y, d.x).normalized()
		var ha: float = _anchos[i - 1] * 0.5
		var hb: float = _anchos[i] * 0.5
		draw_colored_polygon(PackedVector2Array([a + perp * ha, b + perp * hb, b - perp * hb, a - perp * ha]), color)
	for g in _gotas:
		draw_circle((g as Dictionary)["pos"] as Vector2, float((g as Dictionary)["radio"]), color)
