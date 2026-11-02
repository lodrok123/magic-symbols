class_name ImpactoRayoToy
extends Node3D

## IMPACTO DEL RAYO «TOY» (3/11/2026, rama claude/b1-hielo-rayo; PRIMERA VERSIÓN SENCILLA; el equivalente de ImpactoAguaToy e ImpactoFuegoToy). Misma API: `crear(variante, normal, radio)`, `tiempo()`, `duracion()`,
## `avanzar_a(t)`, `lanzar()` / `morir()` (contrato de EfectoVfx3D). Es luz: ADITIVO, sin luces propias, DURA MUY POCO (0,3-0,8 s; el golpe, ~0,2 s). Todo se libera solo.
## Lo que lleva (GOLPE, contra una pared o el suelo; `normal` = normal de la superficie hacia fuera):
##   · DESCARGAS: 6 trazos quebrados (rayo_trazo.gdshader) que salen del punto de impacto hacia fuera, en el hemisferio de la normal, y SE REDIBUJAN cada 0,05 s (distintos cada vez) mientras se apagan en ~0,25 s.
##   · DESTELLO: estrella de T_flare8 de 3,4 radios y un halo redondo más grande y más breve (rayo_destello.gdshader): el primer instante, 0,16 s.
##   · CHISPAS: puntos brillantes que salen hacia fuera en el hemisferio de la normal y CAEN con la gravedad; al llegar a la superficie se apagan. No son GPUParticles3D: `chispas_estado(t)` las mide.
## Variantes: GOLPE (todo), FIN (el hechizo se agota en el aire: la bola revienta en chispas y tres arcos cortos, sin descargas contra la superficie), REBOTE (golpe pequeño, la bola sigue), AREA (zona: cinco
## descargas verticales que CAEN del cielo sobre el área, una tras otra cada 0,07 s, cada una con su destello en el suelo y sus chispas).
## TAMAÑO: `radio` = radio de la bola que choca (m): todo sigue a ese radio (referencia 0,4; el AREA, 1,8).

const RayoTrazos = preload("res://presentacion/vfx/toy/rayo_trazos.gd")

enum Variante { GOLPE, FIN, REBOTE, AREA }

## Por variante: nº de chispas, nº de descargas, tamaño del destello (× radio), duración (s).
const PARAMS: Dictionary = {
	Variante.GOLPE: {"chispas": 18, "descargas": 6, "dest": 3.4, "dur": 0.5},
	Variante.FIN: {"chispas": 16, "descargas": 3, "dest": 2.0, "dur": 0.45},
	Variante.REBOTE: {"chispas": 8, "descargas": 3, "dest": 1.8, "dur": 0.3},
	Variante.AREA: {"chispas": 30, "descargas": 5, "dest": 2.0, "dur": 0.8}}
const RADIO_AREA_REF: float = 1.8
const COS_SUELO: float = 0.7
const GRAVEDAD: float = 9.8
const T_REDIBUJO: float = 0.05            ## s entre redibujos de las descargas
const T_DESTELLO: float = 0.16
const T_DESCARGA: float = 0.26            ## s que tarda en apagarse una descarga
const T_ESCALONADO: float = 0.07          ## AREA: s entre una descarga vertical y la siguiente
const N_TRAZOS: int = 84

@export var variante: Variante = Variante.GOLPE
@export var normal: Vector3 = Vector3.UP
@export_range(0.05, 4.0, 0.01, "or_greater") var radio: float = 0.4
## Altura (m) bajo el punto de la FIN a la que se supone el suelo: las chispas que caen hasta ahí se apagan.
@export var altura_suelo: float = 0.7

var _t: float = -1.0
var _p: Dictionary = {}
var _dur: float = 0.5
var _plano: Node3D = null
var _trazos: MultiMeshInstance3D = null
var _brillos: MultiMeshInstance3D = null
var _chispas: Array = []                   ## [{p0, v0, vida, tam, retraso}] en el espacio local del plano
var _sitios: Array = []                    ## AREA: [{pos, t0}] dónde cae cada descarga vertical
var _lista: Array = []                     ## los tramos del último redibujo (pruebas)
var _fin_t: float = 0.6
var _giro0: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func crear(var_: Variante, normal_: Vector3, radio_: float) -> ImpactoRayoToy:
	var i: ImpactoRayoToy = ImpactoRayoToy.new()
	i.configurar(var_, normal_, radio_)
	return i


## Se llama ANTES de añadirlo al árbol. La FIN y el AREA siempre suben (normal arriba).
func configurar(var_: Variante, normal_: Vector3, radio_: float) -> void:
	variante = var_
	normal = Vector3.UP if var_ == Variante.FIN or var_ == Variante.AREA or normal_.length() < 0.001 else normal_.normalized()
	radio = maxf(radio_, 0.05)


func _ready() -> void:
	_p = PARAMS[variante]
	_dur = float(_p["dur"])
	_fin_t = _dur + 0.1
	_giro0 = randf() * TAU
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


# ------------------------------------------------------------------ construcción ------------------------------------------------------------------

func _construir() -> void:
	var r: float = radio
	_plano = Node3D.new()
	_plano.name = "Plano"
	_plano.basis = _base_normal()
	add_child(_plano)
	var k: float = pow(r / 0.4, 0.7)
	var n_ch: int = int(_p["chispas"])
	for i in n_ch:
		var ang: float = _rng.randf() * TAU
		var alto: float = _rng.randf_range(0.2, 1.0)                    # cos del ángulo con la normal (dentro del hemisferio: ≥ 0,2)
		var lado: float = sqrt(1.0 - alto * alto)
		var dir: Vector3 = Vector3(cos(ang) * lado, alto, sin(ang) * lado)
		var pos: Vector3 = Vector3(0, 0.03, 0)
		var vel: Vector3 = dir * _rng.randf_range(2.0, 5.5) * k
		var retraso: float = 0.0
		if variante == Variante.FIN:
			var d: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
			pos = d * r * _rng.randf_range(0.2, 0.8)
			vel = d * _rng.randf_range(1.0, 3.0) * k
		elif variante == Variante.AREA:
			var s: int = i % 5
			retraso = float(s) * T_ESCALONADO
			pos = Vector3(0, 0.03, 0)                                   # se recolocan sobre su sitio en `_sitios_area`
		_chispas.append({"p0": pos, "v0": vel, "vida": _rng.randf_range(0.22, 0.45), "tam": _rng.randf_range(0.07, 0.15) * sqrt(maxf(r / 0.4, 0.4)), "retraso": retraso})
	if variante == Variante.AREA:
		_sitios_area()
	_trazos = RayoTrazos.crear_trazos("Trazos", N_TRAZOS)
	_plano.add_child(_trazos)
	_brillos = RayoTrazos.crear_destellos("Chispas", n_ch + 12)
	_plano.add_child(_brillos)
	avanzar_a(0.0)


## AREA: una descarga en el centro y cuatro alrededor (a ~0,6 del radio), cada una con su hora; las chispas salen de su descarga.
func _sitios_area() -> void:
	_sitios = [{"pos": Vector3.ZERO, "t0": 0.0}]
	for j in 4:
		var a: float = TAU * float(j) / 4.0 + 0.5
		_sitios.append({"pos": Vector3(cos(a), 0.0, sin(a)) * radio * 0.62, "t0": float(j + 1) * T_ESCALONADO})
	for i in _chispas.size():
		var sit: Dictionary = _sitios[i % 5]
		_chispas[i]["p0"] = (sit["pos"] as Vector3) + Vector3(0, 0.03, 0)
		_chispas[i]["retraso"] = float(sit["t0"])


# ------------------------------------------------------------------ las chispas (fórmula cerrada) ------------------------------------------------------------------

func _gravedad_local() -> Vector3:
	var b: Basis = _plano.basis if _plano != null else _base_normal()
	if is_inside_tree():
		b = global_transform.basis * b
	return b.inverse() * Vector3(0, -GRAVEDAD, 0)


func _estado_chispa(d: Dictionary, t: float, g: Vector3) -> Dictionary:
	var tau: float = t - float(d["retraso"])
	if tau < 0.0:
		return {"pos": d["p0"], "vel": d["v0"], "u": 0.0, "vivo": false}
	var p: Vector3 = (d["p0"] as Vector3) + (d["v0"] as Vector3) * tau + 0.5 * g * tau * tau
	var v: Vector3 = (d["v0"] as Vector3) + g * tau
	var u: float = tau / float(d["vida"])
	var vivo: bool = u < 1.0
	if variante != Variante.FIN and p.y < 0.0:                         # llegó a la superficie: se apaga
		p.y = 0.0
		v = Vector3.ZERO
		vivo = false
	return {"pos": p, "vel": v, "u": u, "vivo": vivo}


## Medición para las pruebas: una entrada por chispa en `t`: {pos (mundo), dir, dist, altura (sobre la superficie), vy (vertical, mundo), vivo, vida}.
func chispas_estado(t: float) -> Array:
	var res: Array = []
	var g: Vector3 = _gravedad_local()
	for d in _chispas:
		var e: Dictionary = _estado_chispa(d, t, g)
		var p: Vector3 = e["pos"]
		var vm: Vector3 = global_transform.basis * (_plano.basis * (e["vel"] as Vector3))
		res.append({"pos": global_transform * (_plano.basis * p), "dir": vm.normalized(), "dist": p.length(), "altura": p.y, "vy": vm.y, "vivo": bool(e["vivo"]) and t > float(d["retraso"]), "vida": float(d["vida"])})
	return res


## (chispas, descargas) que lleva.
func recuento() -> Array:
	return [_chispas.size(), int(_p["descargas"])]


## Tramos que se dibujan en el último redibujo (pruebas): [{a, b, ancho, alfa, ...}] en el espacio local del plano.
func tramos_actuales() -> Array:
	return _lista


# ------------------------------------------------------------------ animación ------------------------------------------------------------------

func _process(delta: float) -> void:
	if _p.is_empty():
		return
	if _t < 0.0:
		_t = 0.0
	_t += delta
	avanzar_a(_t)
	if _t >= _fin_t:
		queue_free()


## Pone todo como en el instante `t` (s desde el impacto). Las descargas son distintas cada T_REDIBUJO s (la semilla es el índice de redibujo: determinista).
func avanzar_a(t: float) -> void:
	if _p.is_empty() or _plano == null:
		return
	var r: float = radio
	_rng.seed = 9000 + int(t / T_REDIBUJO) * 131 + int(variante) * 7
	var lista: Array = []
	var mb: MultiMesh = _brillos.multimesh
	var n_ch: int = _chispas.size()
	var grueso: float = 0.07 * sqrt(maxf(r / 0.4, 0.4)) + 0.04
	match variante:
		Variante.GOLPE, Variante.REBOTE:
			var env: float = 1.0 - smoothstep(0.1, T_DESCARGA, t)
			var hasta: float = clampf(t / 0.04, 0.0, 1.0)                 # salen disparadas en los primeros 0,04 s
			var nd: int = int(_p["descargas"])
			for k in nd:
				var ang: float = TAU * float(k) / float(nd) + _rng.randf_range(-0.4, 0.4)
				var elev: float = _rng.randf_range(0.12, 0.85)
				var dir: Vector3 = Vector3(cos(ang) * (1.0 - elev), elev, sin(ang) * (1.0 - elev)).normalized()
				var largo: float = r * _rng.randf_range(1.8, 3.2)
				var pts: PackedVector3Array = RayoTrazos.camino(Vector3(0, 0.03, 0), dir * largo, 5, 0.28 * r + 0.03, _rng)
				for q in pts.size():
					var pq: Vector3 = pts[q]
					pq.y = maxf(pq.y, 0.0)                                 # nada bajo la superficie
					pts[q] = pq
				RayoTrazos.trazar(lista, pts, grueso, env, hasta, 1.0, 0.5, float(k))
				RayoTrazos.ramas(lista, pts, 1, largo * 0.4, grueso * 0.6, env * 0.8, hasta, _rng, 2)
		Variante.FIN:
			var env2: float = 1.0 - smoothstep(0.08, T_DESCARGA, t)
			for k in int(_p["descargas"]):
				var d2: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
				var pts2: PackedVector3Array = RayoTrazos.camino(d2 * r * 0.3, d2 * r * _rng.randf_range(1.8, 2.8), 4, 0.3 * r, _rng)
				RayoTrazos.trazar(lista, pts2, grueso, env2, clampf(t / 0.04, 0.0, 1.0), 1.0, 0.5, float(k))
		Variante.AREA:
			for sit in _sitios:
				var tt: float = t - float(sit["t0"])
				if tt < 0.0 or tt > T_DESCARGA:
					continue
				var env3: float = 1.0 - smoothstep(0.05, T_DESCARGA, tt)
				var base: Vector3 = sit["pos"]
				var alto: float = radio * 3.2
				# cae del cielo: el trazo va de arriba abajo en los primeros 0,04 s
				var pts3: PackedVector3Array = RayoTrazos.camino(base + Vector3(0, alto, 0), base, 10, 0.16 * radio, _rng)
				RayoTrazos.trazar(lista, pts3, grueso * 1.4, env3, clampf(tt / 0.04, 0.0, 1.0), 1.0, 0.5, base.x)
				RayoTrazos.ramas(lista, pts3, 2, radio * 0.7, grueso * 0.8, env3 * 0.8, clampf(tt / 0.04, 0.0, 1.0), _rng, 3)
	RayoTrazos.volcar(_trazos.multimesh, lista)
	_lista = lista
	# destellos: la estrella de golpe, el halo redondo y el brillo de cada sitio
	var i_b: int = 0
	if variante == Variante.AREA:
		for sit2 in _sitios:
			var t2: float = t - float(sit2["t0"])
			var u2: float = clampf(t2 / T_DESTELLO, 0.0, 1.0)
			var vis: bool = t2 >= 0.0 and t2 < T_DESTELLO
			var pos_s: Vector3 = (sit2["pos"] as Vector3) + Vector3(0, 0.2 * r, 0)
			RayoTrazos.poner_destello(mb, n_ch + i_b, pos_s, r * float(_p["dest"]) * lerpf(0.6, 1.1, sqrt(u2)), (1.0 - u2) if vis else 0.0, 0.9, _giro0 + t * 2.0, 0.3)
			i_b += 1
	else:
		var u: float = clampf(t / T_DESTELLO, 0.0, 1.0)
		var d: float = r * float(_p["dest"])
		var pos_d: Vector3 = Vector3(0, 0.3 * r, 0) if variante != Variante.FIN else Vector3.ZERO
		RayoTrazos.poner_destello(mb, n_ch, pos_d, d * lerpf(0.5, 1.1, sqrt(u)), (1.0 - u) if u < 1.0 else 0.0, 0.9, _giro0 + t * 2.0, 0.2)
		var u_h: float = clampf(t / (T_DESTELLO * 0.8), 0.0, 1.0)
		RayoTrazos.poner_destello(mb, n_ch + 1, pos_d, d * 1.7 * lerpf(0.5, 1.0, u_h), 0.45 * (1.0 - u_h) if u_h < 1.0 else 0.0, 0.0, 0.0, 0.5)
		i_b = 2
	for q in range(i_b, 12):
		RayoTrazos.ocultar(mb, n_ch + q)
	var g: Vector3 = _gravedad_local()
	for i in n_ch:
		var e: Dictionary = _estado_chispa(_chispas[i], t, g)
		var u3: float = float(e["u"])
		var al: float = 0.95 * (1.0 - smoothstep(0.55, 1.0, u3)) if (bool(e["vivo"]) and t >= float(_chispas[i]["retraso"])) else 0.0
		RayoTrazos.poner_destello(mb, i, e["pos"], float(_chispas[i]["tam"]) * (1.0 - 0.4 * u3), al, 0.9, t * 6.0 + float(i), float(i) * 0.21)
