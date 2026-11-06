class_name ImpactoTierraToy
extends Node3D

## IMPACTO DE LA TIERRA «TOY» (6/11/2026; el equivalente de ImpactoHieloToy). Misma API: `crear(variante, normal, radio)`, `tiempo()`, `duracion()`, `avanzar_a(t)`, `lanzar()` / `morir()`.
## Es TIERRA: PIEDRECITAS (MultiMesh de piedra_est_1, la piedra pequeña del mapa, con tierra_roca.gdshader: textura gris de las rocas + luz de la escena) que salen del punto HACIA FUERA en el
## hemisferio de la normal, giran y CAEN con la gravedad real (fórmula cerrada,
## `piedras_estado(t)` las mide), se quedan en la superficie o en el suelo del mundo y se hunden al final; y una NUBE DE POLVO pardo de dos tonos (humo toon, humo_toy.gd) a ras de la
## superficie que se abre en radial y se erosiona. SIN destello, sin luz, sin aditivos, sin GPUParticles3D. Todo se libera solo.
## Variantes: GOLPE (todo), FIN (se agota en el aire: terrones que caen y un poco de polvo), REBOTE (pequeño), AREA (zona: polvo ancho y muchas piedrecitas; la normal siempre es arriba).
## TAMAÑO: `radio` = radio de la roca que choca (m; referencia 0,4; el AREA, 1,8).

const HumoToy = preload("res://presentacion/vfx/toy/humo_toy.gd")
const HieloMallas = preload("res://presentacion/vfx/toy/hielo_mallas.gd")

enum Variante { GOLPE, FIN, REBOTE, AREA }

const PARAMS: Dictionary = {
	Variante.GOLPE: {"piedras": 28, "polvo": 14, "dur": 1.3},
	Variante.FIN: {"piedras": 18, "polvo": 5, "dur": 1.1},
	Variante.REBOTE: {"piedras": 12, "polvo": 6, "dur": 0.9},
	Variante.AREA: {"piedras": 48, "polvo": 22, "dur": 1.8}}
const COS_SUELO: float = 0.7
const GRAVEDAD: float = 9.8

@export var variante: Variante = Variante.GOLPE
@export var normal: Vector3 = Vector3.UP
@export_range(0.05, 4.0, 0.01, "or_greater") var radio: float = 0.4
@export var altura_suelo: float = 0.7

var _t: float = -1.0
var _p: Dictionary = {}
var _dur: float = 0.8
var _plano: Node3D = null
var _mm: MultiMeshInstance3D = null
var _polvo: Node3D = null
var _pie: Array = []                       ## [{p0, v0, vida, tam, eje, vel_ang, rot0, tono}] en el espacio local del plano
var _fin_t: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func crear(var_: Variante, normal_: Vector3, radio_: float) -> ImpactoTierraToy:
	var i: ImpactoTierraToy = ImpactoTierraToy.new()
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


func _construir() -> void:
	var r: float = radio
	_plano = Node3D.new()
	_plano.name = "Plano"
	_plano.basis = _base_normal()
	add_child(_plano)
	var k: float = pow(r / 0.4, 0.7)
	var n_p: int = int(_p["piedras"])
	for i in n_p:
		var pos: Vector3
		var vel: Vector3
		if variante == Variante.FIN:
			var d: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
			pos = d * r * _rng.randf_range(0.2, 0.9)
			vel = d * _rng.randf_range(0.3, 1.2) + Vector3(0, 0.3, 0)
		else:
			var ang: float = _rng.randf() * TAU
			var alto: float = _rng.randf_range(0.25, 1.0)
			var lado: float = sqrt(1.0 - alto * alto)
			var dir: Vector3 = Vector3(cos(ang) * lado, alto, sin(ang) * lado)
			if variante == Variante.AREA:
				pos = Vector3(cos(ang), 0.0, sin(ang)) * r * _rng.randf_range(0.1, 1.0) + Vector3(0, 0.05, 0)
				vel = dir * _rng.randf_range(2.0, 5.0) * k
			else:
				pos = Vector3(0, 0.03, 0)
				vel = dir * _rng.randf_range(1.6, 4.2) * k
		_pie.append({"p0": pos, "v0": vel, "vida": _rng.randf_range(0.7, 1.2), "tam": _rng.randf_range(0.04, 0.11) * sqrt(maxf(r / 0.4, 0.4)),
			"eje": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized(), "vel_ang": _rng.randf_range(4.0, 12.0),
			"rot0": Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)), "tono": _rng.randf()})
	_mm = TierraToy.crear_mm("Piedrecitas", n_p, TierraToy.Piedras.malla_piedra(), 0.2)
	_plano.add_child(_mm)
	# nube de polvo a ras de la superficie (local al plano: la deriva es a lo largo de la normal)
	var n_h: int = int(_p["polvo"])
	_polvo = HumoToy.new()
	_polvo.name = "Polvo"
	_plano.add_child(_polvo)
	var esc: float = sqrt(maxf(r / 0.4, 0.4)) if variante != Variante.AREA else 1.4
	_polvo.call("montar", n_h, TierraToy.polvo_params(0.3 * esc, 0.85 * esc, 0.95 if variante != Variante.AREA else 1.3, Vector3(0, 0.3, 0), false))
	for j in n_h:
		var a2: float = TAU * float(j) / float(n_h) + _rng.randf_range(-0.25, 0.25)
		var d2: Vector3 = Vector3(cos(a2), 0.0, sin(a2))
		if variante == Variante.FIN:
			var d3: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
			_polvo.call("emitir", d3 * r * 0.3, d3 * 0.8, 1.0, 0.8)
		elif variante == Variante.AREA:
			_polvo.call("emitir", d2 * r * _rng.randf_range(0.2, 0.7) + Vector3(0, 0.08, 0), d2 * _rng.randf_range(1.2, 2.4) * k, _rng.randf_range(0.8, 1.2), _rng.randf_range(0.8, 1.3))
		else:
			_polvo.call("emitir", d2 * r * 0.2 + Vector3(0, 0.05 + 0.08 * r, 0), d2 * _rng.randf_range(1.4, 2.6) * k + Vector3(0, 0.2, 0), _rng.randf_range(0.8, 1.2), _rng.randf_range(0.8, 1.2))
	avanzar_a(0.0)


func _gravedad_local() -> Vector3:
	var b: Basis = _plano.basis if _plano != null else _base_normal()
	if is_inside_tree():
		b = global_transform.basis * b
	return b.inverse() * Vector3(0, -GRAVEDAD, 0)


## Estado de la piedra `d` en el instante `t`: cae con la gravedad; al tocar la superficie (o el suelo del mundo) se queda quieta.
func _estado_pie(d: Dictionary, t: float, g: Vector3) -> Dictionary:
	var p: Vector3 = (d["p0"] as Vector3) + (d["v0"] as Vector3) * t + 0.5 * g * t * t
	var v: Vector3 = (d["v0"] as Vector3) + g * t
	var quieta: bool = false
	if variante != Variante.FIN and p.y < 0.0:
		p.y = 0.0
		v = Vector3.ZERO
		quieta = true
	if is_inside_tree():
		var pm: Vector3 = global_transform * (_plano.basis * p)
		var y_min: float = global_position.y - altura_suelo
		if pm.y < y_min:
			p += (global_transform.basis * _plano.basis).inverse() * Vector3(0, y_min - pm.y, 0)
			v = Vector3.ZERO
			quieta = true
	var u: float = t / float(d["vida"])
	return {"pos": p, "vel": v, "u": u, "vivo": u < 1.0, "quieta": quieta}


## Medición para las pruebas: una entrada por piedra con su estado en `t`: {pos (mundo), dir, dist, altura (sobre la superficie), vy (mundo), vivo, vida}.
func piedras_estado(t: float) -> Array:
	var res: Array = []
	var g: Vector3 = _gravedad_local()
	for d in _pie:
		var e: Dictionary = _estado_pie(d, t, g)
		var p: Vector3 = e["pos"]
		var vm: Vector3 = global_transform.basis * (_plano.basis * (e["vel"] as Vector3))
		res.append({"pos": global_transform * (_plano.basis * p), "dir": vm.normalized(), "dist": p.length(), "altura": p.y, "vy": vm.y, "vivo": bool(e["vivo"]), "vida": float(d["vida"])})
	return res


## (piedras, bocanadas de polvo) que lleva.
func recuento() -> Array:
	return [_pie.size(), int(_p.get("polvo", 0))]


func _process(delta: float) -> void:
	if _p.is_empty():
		return
	if _t < 0.0:
		_t = 0.0
	_t += delta
	avanzar_a(_t)
	if _t >= _fin_t:
		queue_free()


## Pone las piedras como en el instante `t` (fórmula cerrada). El polvo se mueve solo (humo_toy.gd).
func avanzar_a(t: float) -> void:
	if _p.is_empty() or _plano == null:
		return
	var g: Vector3 = _gravedad_local()
	var mm: MultiMesh = _mm.multimesh
	for i in _pie.size():
		var d: Dictionary = _pie[i]
		var e: Dictionary = _estado_pie(d, t, g)
		var u: float = float(e["u"])
		if not bool(e["vivo"]):
			HieloMallas.ocultar(mm, i)
			continue
		var rot: Basis = (Basis(d["eje"], float(d["vel_ang"]) * t * (0.0 if bool(e["quieta"]) else 1.0)) * (d["rot0"] as Basis)).orthonormalized()
		var s: float = float(d["tam"]) * (1.0 - smoothstep(0.75, 1.0, u)) * 2.0 / TierraToy.lado_malla(mm.mesh)   # `tam` = radio; al final se hunde en el suelo (encoge)
		mm.set_instance_transform(i, TierraToy.centrar(mm.mesh, rot * Basis.from_scale(Vector3.ONE * s), e["pos"]))
		mm.set_instance_custom_data(i, Color(float(d["tono"]), 1.0, 0.0, 0.0))
