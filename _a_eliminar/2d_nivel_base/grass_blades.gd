class_name GrassBlades
extends Node2D

## HIERBA ALTA: briznas dibujadas encima del bloque, para ver cómo arde una
## hierba crecida (no una alfombra plana). No decide nada del juego: solo
## dibuja. GrassBlock le pasa dónde prendió (`origen`, local) y hasta dónde ha
## llegado lo quemado (`radio`, en unidades de SUELO, igual que GrassBurn).
##
## Cada brizna, según lo cerca que la pille el frente:
##   lejos        verde, se mece con el viento
##   en el frente se enciende: naranja, se encoge y se retuerce
##   detrás       queda un tocón negro, casi a ras de suelo

const CUENTA: int = 64
const ALTO_MIN: float = 14.0
const ALTO_MAX: float = 30.0
const BANDA: float = 34.0            ## cuánto tarda una brizna en consumirse tras el frente (px de suelo)

const VERDES: Array = [Color(0.24, 0.52, 0.16), Color(0.32, 0.62, 0.20), Color(0.42, 0.70, 0.24), Color(0.20, 0.44, 0.14)]
const C_ASCUA: Color = Color(1.0, 0.50, 0.08)
const C_TOCON: Color = Color(0.10, 0.06, 0.04)

var origen: Vector2 = Vector2.ZERO
var radio: float = 0.0
var ardiendo: bool = false
var env: float = 1.0

var _b: Array = []   ## [base, alto, inclinación, fase, color, ancho]
var _tt: float = 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(get_parent().global_position.snapped(Vector2.ONE)))
	while _b.size() < CUENTA:
		var p := Vector2(rng.randf_range(-IsoGrid.STEP.x, IsoGrid.STEP.x), rng.randf_range(-IsoGrid.STEP.y, IsoGrid.STEP.y))
		if absf(p.x) / (IsoGrid.STEP.x - 8.0) + absf(p.y) / (IsoGrid.STEP.y - 4.0) > 1.0:
			continue
		_b.append([p, rng.randf_range(ALTO_MIN, ALTO_MAX), rng.randf_range(-5.0, 5.0),
			rng.randf() * TAU, VERDES[rng.randi() % VERDES.size()], rng.randf_range(2.6, 4.2)])
	_b.sort_custom(func(a, c): return a[0].y < c[0].y)


func _process(delta: float) -> void:
	if visible:
		_tt += delta
		queue_redraw()


func _dist(p: Vector2) -> float:
	var d: Vector2 = p - origen
	return Vector2(d.x, d.y / (IsoGrid.STEP.y / IsoGrid.STEP.x)).length()


func _draw() -> void:
	for b in _b:
		var base: Vector2 = b[0]
		var alto: float = b[1]
		var col: Color = b[4]
		var f: float = 0.0   # 0 = intacta, 1 = consumida
		if ardiendo:
			f = clampf((radio - _dist(base) + 6.0) / BANDA, 0.0, 1.0)
		var mece: float = sin(_tt * 2.2 + b[3] + base.x * 0.05) * 3.0 * (1.0 - f)
		if f > 0.0:
			# En el frente la brizna se retuerce con el calor.
			mece += sin(_tt * 14.0 + b[3]) * 3.0 * sin(f * PI)
		var h: float = alto * (1.0 - 0.82 * smoothstep(0.25, 1.0, f))
		if f > 0.0:
			var caliente: float = smoothstep(0.0, 0.35, f) * (1.0 - smoothstep(0.55, 1.0, f))
			col = col.lerp(C_ASCUA, caliente).lerp(C_TOCON, smoothstep(0.5, 1.0, f))
		col.a = env
		var w: float = b[5]
		var punta: Vector2 = base + Vector2(b[2] + mece, -h)
		var medio: Vector2 = base + Vector2((b[2] + mece) * 0.35, -h * 0.55)
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-w * 0.5, 0.0), medio + Vector2(-w * 0.32, 0.0), punta,
			medio + Vector2(w * 0.32, 0.0), base + Vector2(w * 0.5, 0.0)]), col)
		# Un filo más claro por delante da volumen.
		var claro: Color = col.lightened(0.25)
		draw_line(base + Vector2(w * 0.15, 0.0), punta, claro, 1.0)
		# El ascua en la punta mientras se quema.
		if f > 0.05 and f < 0.75:
			draw_circle(punta, 1.6, Color(1.0, 0.85, 0.35, 0.9 * env))
