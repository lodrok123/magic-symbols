class_name ImpactoVientoToy
extends Node3D

## IMPACTO DEL VIENTO «TOY» (6/11/2026; el equivalente de ImpactoHieloToy). Misma API: `crear(variante, normal, radio)`, `tiempo()`, `duracion()`, `avanzar_a(t)`, `lanzar()` / `morir()`.
## Es VIENTO: SOPLO radial de jirones de humo toon (humo_toy.gd) a ras de la superficie, en el plano de la normal, que se alargan hacia fuera y se erosionan; HOJAS que salen con él y caen
## despacio. SIN destello, sin luz, sin aditivos, sin GPUParticles3D. Todo se libera solo.
## Variantes: GOLPE (soplo + hojas), FIN (se agota en el aire: unos jirones que se dispersan, sin hojas), REBOTE (soplo pequeño), AREA (anillo ancho de jirones y muchas hojas; normal arriba).
## TAMAÑO: `radio` = radio de la ráfaga que choca (m; referencia 0,4; el AREA, 1,8).

const HumoToy = preload("res://presentacion/vfx/toy/humo_toy.gd")

enum Variante { GOLPE, FIN, REBOTE, AREA }

const PARAMS: Dictionary = {
	Variante.GOLPE: {"humo": 16, "hojas": 12, "dur": 1.0},
	Variante.FIN: {"humo": 8, "hojas": 0, "dur": 0.9},
	Variante.REBOTE: {"humo": 8, "hojas": 5, "dur": 0.8},
	Variante.AREA: {"humo": 24, "hojas": 18, "dur": 1.4}}
const COS_SUELO: float = 0.7

@export var variante: Variante = Variante.GOLPE
@export var normal: Vector3 = Vector3.UP
@export_range(0.05, 4.0, 0.01, "or_greater") var radio: float = 0.4
@export var altura_suelo: float = 0.7
var paleta_verde: bool = false

var _t: float = -1.0
var _p: Dictionary = {}
var _dur: float = 0.8
var _plano: Node3D = null
var _humo: Node3D = null
var _hojas: Node3D = null
var _fin_t: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func crear(var_: Variante, normal_: Vector3, radio_: float) -> ImpactoVientoToy:
	var i: ImpactoVientoToy = ImpactoVientoToy.new()
	i.configurar(var_, normal_, radio_)
	return i


func configurar(var_: Variante, normal_: Vector3, radio_: float) -> void:
	variante = var_
	normal = Vector3.UP if var_ == Variante.FIN or var_ == Variante.AREA or normal_.length() < 0.001 else normal_.normalized()
	radio = maxf(radio_, 0.05)


func _ready() -> void:
	_p = PARAMS[variante]
	_dur = float(_p["dur"])
	_fin_t = _dur + 0.1
	_rng.randomize()
	_construir()


func lanzar(_v: float = -1.0) -> void:
	pass


func morir() -> void:
	queue_free()


func tiempo() -> float:
	return maxf(_t, 0.0)


func duracion() -> float:
	if not _p.is_empty():
		return _dur
	return float(PARAMS[variante]["dur"])


func es_suelo() -> bool:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	return variante != Variante.FIN and n.dot(Vector3.UP) >= COS_SUELO


func es_pared() -> bool:
	return variante != Variante.FIN and not es_suelo()


func _base_normal() -> Basis:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	if n.dot(Vector3.UP) < -0.999:
		return Basis(Quaternion(Vector3.RIGHT, PI))
	return Basis(Quaternion(Vector3.UP, n))


## Todo se emite de golpe en el primer fotograma (un soplo es instantáneo) y luego vive por su cuenta.
func _construir() -> void:
	var r: float = radio
	_plano = Node3D.new()
	_plano.name = "Plano"
	_plano.basis = _base_normal()
	add_child(_plano)
	var k: float = pow(r / 0.4, 0.7)
	var n_h: int = int(_p["humo"])
	var n_hojas: int = int(_p["hojas"])
	_humo = HumoToy.new()
	_humo.name = "Soplo"
	_plano.add_child(_humo)
	var vida: float = 0.75 if variante != Variante.AREA else 1.0
	var humo: Dictionary = VientoToy.humo_params(r * 0.6, r * (1.9 if variante != Variante.AREA else 1.2),
		vida, Vector3(0, 0.3, 0), false, 0.5)
	if paleta_verde:
		humo.merge({"claro": Color("#dcffb0"), "sombra": Color("#83be70"), "viejo": Color("#adc989")}, true)
	_humo.call("montar", n_h, humo)
	for i in n_h:
		var ang: float = TAU * float(i) / float(n_h) + _rng.randf_range(-0.25, 0.25)
		var d: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		var pos: Vector3
		var vel: Vector3
		if variante == Variante.FIN:
			var d3: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
			pos = d3 * r * 0.4
			vel = d3 * _rng.randf_range(0.8, 1.8) * k
		elif variante == Variante.AREA:
			pos = d * r * _rng.randf_range(0.2, 0.6) + Vector3(0, 0.08, 0)
			vel = d * _rng.randf_range(2.0, 3.5) * k
		else:
			pos = d * r * 0.15 + Vector3(0, 0.05 + 0.1 * r, 0)
			vel = d * _rng.randf_range(2.2, 4.2) * k + Vector3(0, 0.3, 0)
		_humo.call("emitir", pos, vel, _rng.randf_range(0.8, 1.2), _rng.randf_range(0.8, 1.2), ang, 1.9)
	if n_hojas > 0:
		var h: VientoToy.Hojas = VientoToy.Hojas.new()
		h.name = "Hojas"
		h.gravedad = 2.2
		_plano.add_child(h)
		h.montar(n_hojas, true)
		_hojas = h
		var tr: Transform3D = global_transform * Transform3D(_plano.basis, Vector3.ZERO) if is_inside_tree() else Transform3D(_plano.basis, Vector3.ZERO)
		for j in n_hojas:
			var a2: float = TAU * float(j) / float(n_hojas) + _rng.randf_range(-0.3, 0.3)
			var d2: Vector3 = Vector3(cos(a2), _rng.randf_range(0.3, 0.9), sin(a2)).normalized()
			var p0: Vector3 = Vector3(cos(a2), 0.0, sin(a2)) * r * (0.2 if variante != Variante.AREA else _rng.randf_range(0.3, 0.9)) + Vector3(0, 0.05, 0)
			h.emitir(tr * p0, tr.basis * (d2 * _rng.randf_range(2.0, 4.0) * k), _rng.randf_range(0.7, 1.1), 0.15 * sqrt(maxf(r / 0.4, 0.5)), Vector3.ZERO, _rng.randf_range(-3.0, 3.0))
	_t = 0.0


## (bocanadas, hojas) que lleva.
func recuento() -> Array:
	return [int(_p.get("humo", 0)), int(_p.get("hojas", 0))]


## Medición: estado de las bocanadas del soplo (local al plano: y = altura sobre la superficie) y de las hojas (mundo).
func estado() -> Dictionary:
	return {"humo": _humo.call("estados") if _humo != null else [], "hojas": _hojas.call("estados") if _hojas != null else []}


func _process(delta: float) -> void:
	if _p.is_empty():
		return
	_t += delta
	if _t >= _fin_t:
		queue_free()


## Avanza las reservas hasta el instante `t` (solo hacia delante: el soplo no se rebobina).
func avanzar_a(t: float) -> void:
	if _p.is_empty():
		return
	var paso: float = 1.0 / 60.0
	while _t < t:
		var d: float = minf(paso, t - _t)
		_humo.call("avanzar", d)
		if _hojas != null:
			_hojas.call("avanzar", d)
		_t += d
