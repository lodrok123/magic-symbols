class_name ImpactoHieloToy
extends Node3D

## IMPACTO DEL HIELO «TOY» (3/11/2026, rama claude/b1-hielo-rayo; PRIMERA VERSIÓN SENCILLA; el equivalente de ImpactoAguaToy e ImpactoFuegoToy). Misma API: `crear(variante, normal, radio)`, `tiempo()`, `duracion()`,
## `avanzar_a(t)`, `lanzar()` / `morir()` (contrato de EfectoVfx3D). Es HIELO: mezcla normal, sin luz, sin aditivo. Todo se libera solo.
## Lo que lleva (GOLPE, contra una pared o el suelo; `normal` = normal de la superficie hacia fuera):
##   · RÁFAGA DE ESQUIRLAS: un MultiMesh movido por la CPU (hielo_cristal.gdshader) con esquirlas que salen del punto de impacto HACIA FUERA, en el hemisferio de la normal, giran y CAEN con la gravedad real
##     (9,8 m/s²); al llegar a la superficie o al suelo se quedan quietas hasta desvanecerse. No son GPUParticles3D: `esquirlas_estado(t)` las mide.
##   · CRISTALES que brotan del punto (crecen en dos escalones en 0,12 s) y a los ~0,45 s SE ROMPEN en una segunda tanda de esquirlas.
##   · ESCARCHA: un disco de bordes rotos sobre la superficie que se extiende y se derrite (hielo_escarcha.gdshader).
##   · DESTELLO: estrella de T_VFX_hit22 blanco azulada, 0,14 s (blend_mix: un golpe de luz sobre el cristal, no una luz).
## Variantes: GOLPE (todo), FIN (el hechizo se agota en el aire: el bloque se deshace en esquirlas que caen, sin cristales ni escarcha), REBOTE (golpe pequeño, el bloque sigue), AREA (zona: una corona de cristales
## grandes que brotan alrededor, escarcha ancha y muchas esquirlas; el área es el suelo, la normal siempre es arriba).
## TAMAÑO: `radio` = radio del bloque que choca (m): todo sigue a ese radio (referencia 0,4; el AREA, 1,8).

const HieloMallas = preload("res://presentacion/vfx/toy/hielo_mallas.gd")
const HieloEsquirlas = preload("res://presentacion/vfx/toy/hielo_esquirlas.gd")

enum Variante { GOLPE, FIN, REBOTE, AREA }

## Por variante: nº de esquirlas, de cristales, tamaño del disco de escarcha (× radio, diámetro), del destello (× radio), duración (s).
const PARAMS: Dictionary = {
	Variante.GOLPE: {"esq": 36, "cris": 5, "disco": 3.4, "dest": 3.0, "dur": 1.1},
	Variante.FIN: {"esq": 24, "cris": 0, "disco": 0.0, "dest": 0.0, "dur": 1.0},
	Variante.REBOTE: {"esq": 14, "cris": 2, "disco": 1.6, "dest": 1.6, "dur": 0.8},
	Variante.AREA: {"esq": 60, "cris": 9, "disco": 2.6, "dest": 1.2, "dur": 1.7}}
const RADIO_AREA_REF: float = 1.8
const COS_SUELO: float = 0.7              ## una superficie cuenta como SUELO si su normal apunta hacia arriba (cos ≥ 0,7)
const GRAVEDAD: float = 9.8
const T_DESTELLO: float = 0.14
const T_CRECE: float = 0.12               ## s que tardan los cristales en brotar
const T_ROMPE: float = 0.45               ## s a los que se rompen (más su retraso)

@export var variante: Variante = Variante.GOLPE
@export var normal: Vector3 = Vector3.UP
@export_range(0.05, 4.0, 0.01, "or_greater") var radio: float = 0.4
## Altura (m) bajo el punto de la FIN a la que se supone el suelo: las esquirlas que caen hasta ahí se quedan.
@export var altura_suelo: float = 0.7

var _t: float = -1.0
var _p: Dictionary = {}
var _dur: float = 0.8
var _plano: Node3D = null
var _destello: MeshInstance3D = null
var _disco: MeshInstance3D = null
var _mm_esq: MultiMeshInstance3D = null
var _mm_cris: MultiMeshInstance3D = null
var _cris: Array = []                      ## cristales (HieloMallas._c) con su retraso y su hora de rotura
var _esq: Array = []                       ## [{p0, v0, vida, tam, retraso, eje, vel_ang, rot0, clar}] en el espacio local del plano
var _tr_esq: Array = []                    ## última transformación puesta a cada esquirla (pruebas)
var _giro0: float = 0.0
var _fin_t: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func crear(var_: Variante, normal_: Vector3, radio_: float) -> ImpactoHieloToy:
	var i: ImpactoHieloToy = ImpactoHieloToy.new()
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


## Instante actual de la animación (s desde que empezó).
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
	var k: float = pow(r / 0.4, 0.7)                         # las esquirlas van más rápido con un bloque más grande, sin pasarse en el AREA
	# esquirlas de la ráfaga
	var n_esq: int = int(_p["esq"])
	var n_cris: int = int(_p["cris"])
	var n_total: int = n_esq + n_cris * 2
	for i in n_esq:
		var dir: Vector3
		var pos: Vector3
		var vel: Vector3
		if variante == Variante.FIN:
			var d: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
			pos = d * r * _rng.randf_range(0.2, 0.9)
			vel = d * _rng.randf_range(0.3, 1.2) + Vector3(0, 0.4, 0)
		else:
			var ang: float = _rng.randf() * TAU
			var alto: float = _rng.randf_range(0.2, 1.0)                     # cos del ángulo con la normal (todas dentro del hemisferio: ≥ 0,2)
			var lado: float = sqrt(1.0 - alto * alto)
			dir = Vector3(cos(ang) * lado, alto, sin(ang) * lado)
			if variante == Variante.AREA:
				pos = Vector3(cos(ang), 0.0, sin(ang)) * r * _rng.randf_range(0.1, 1.0) + Vector3(0, 0.05, 0)
				vel = dir * _rng.randf_range(2.5, 6.0) * k
			else:
				pos = Vector3(0, 0.03, 0)
				vel = dir * _rng.randf_range(1.8, 4.6) * k
		_esq.append({"p0": pos, "v0": vel, "vida": _rng.randf_range(0.55, 0.95), "tam": _rng.randf_range(0.06, 0.14) * sqrt(maxf(r / 0.4, 0.4)), "retraso": 0.0,
			"eje": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized(), "vel_ang": _rng.randf_range(4.0, 12.0),
			"rot0": Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)), "clar": _rng.randf()})
	# cristales que brotan y se rompen
	for j in n_cris:
		var a: float = TAU * float(j) / float(n_cris) + _rng.randf_range(-0.3, 0.3)
		var d2: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var rr: float = r * (_rng.randf_range(0.25, 0.7) if variante != Variante.AREA else _rng.randf_range(0.55, 0.85))
		var w: float = r * (_rng.randf_range(0.16, 0.26) if variante != Variante.AREA else _rng.randf_range(0.11, 0.16))
		var h: float = r * (_rng.randf_range(0.8, 1.7) if variante != Variante.AREA else _rng.randf_range(0.7, 1.4))
		var c: Dictionary = HieloMallas._c(d2 * rr, HieloMallas._inclinar(d2, _rng.randf_range(0.2, 0.55), _rng.randf() * TAU), w, h, w, _rng.randf_range(0.0, 0.07), _rng, 2)
		c["rompe"] = T_ROMPE + _rng.randf_range(0.0, 0.18)
		_cris.append(c)
		for q in 2:                                                               # la segunda tanda: sale de la punta del cristal al romperse
			var tope: Vector3 = (c["pos"] as Vector3) + (c["rot"] as Basis) * Vector3(0, h * (0.35 + 0.4 * float(q)), 0)
			_esq.append({"p0": tope, "v0": d2 * _rng.randf_range(0.4, 1.4) + Vector3(0, _rng.randf_range(0.3, 1.2), 0), "vida": _rng.randf_range(0.4, 0.6), "tam": _rng.randf_range(0.07, 0.12) * sqrt(maxf(r / 0.4, 0.4)),
				"retraso": float(c["rompe"]), "eje": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized(), "vel_ang": _rng.randf_range(4.0, 10.0),
				"rot0": Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)), "clar": _rng.randf()})
	_mm_esq = HieloEsquirlas.crear_mm("Esquirlas", n_total)
	_plano.add_child(_mm_esq)
	if n_cris > 0:
		_mm_cris = HieloMallas.crear_mm("Cristales", n_cris, HieloMallas.cristal(6, 5.0), 0.66, 1)
		_plano.add_child(_mm_cris)
	# escarcha sobre la superficie
	if float(_p["disco"]) > 0.0:
		_disco = HieloMallas.escarcha("Escarcha", 0.7, randf())
		_disco.position = Vector3(0, 0.012 + 0.01 * r, 0)
		var lado_d: float = float(_p["disco"]) * r * (2.0 if variante == Variante.AREA else 1.0)
		_disco.scale = Vector3(lado_d, 1.0, lado_d)
		_plano.add_child(_disco)
	# destello
	if float(_p["dest"]) > 0.0:
		_destello = HieloMallas.destello("Destello")
		_destello.position = normal.normalized() * 0.3 * r if variante != Variante.AREA else Vector3(0, 0.4 * r, 0)
		_destello.set_meta("tam", float(_p["dest"]) * r)
		add_child(_destello)
	_tr_esq.resize(_esq.size())
	avanzar_a(0.0)


# ------------------------------------------------------------------ las esquirlas (fórmula cerrada) ------------------------------------------------------------------

func _gravedad_local() -> Vector3:
	var b: Basis = _plano.basis if _plano != null else _base_normal()
	if is_inside_tree():
		b = global_transform.basis * b
	return b.inverse() * Vector3(0, -GRAVEDAD, 0)


## Altura (m) de un punto del plano sobre la superficie.
func _altura(p: Vector3) -> float:
	return p.y


## Estado de la esquirla `d` en el instante `t`: {pos, vel (locales al plano), u, vivo, quieta}. Cae con la gravedad; al tocar la superficie (o el suelo del mundo, `altura_suelo` bajo el punto) se queda quieta.
func _estado_esq(d: Dictionary, t: float, g: Vector3) -> Dictionary:
	var tau: float = t - float(d["retraso"])
	if tau < 0.0:
		return {"pos": d["p0"], "vel": d["v0"], "u": 0.0, "vivo": false, "quieta": false}
	var p: Vector3 = (d["p0"] as Vector3) + (d["v0"] as Vector3) * tau + 0.5 * g * tau * tau
	var v: Vector3 = (d["v0"] as Vector3) + g * tau
	var quieta: bool = false
	if variante != Variante.FIN and p.y < 0.0:               # la superficie (la FIN no tiene: se deshace en el aire)
		p.y = 0.0
		v = Vector3.ZERO
		quieta = true
	# el suelo del mundo: un punto no baja más de `altura_suelo` por debajo de donde chocó
	if is_inside_tree():
		var pm: Vector3 = global_transform * (_plano.basis * p)
		var y_min: float = global_position.y - altura_suelo
		if pm.y < y_min:
			var corr: float = (y_min - pm.y)
			var dw: Vector3 = (global_transform.basis * _plano.basis).inverse() * Vector3(0, corr, 0)
			p += dw
			v = Vector3.ZERO
			quieta = true
	var u: float = tau / float(d["vida"])
	return {"pos": p, "vel": v, "u": u, "vivo": u < 1.0, "quieta": quieta}


## Medición para las pruebas: una entrada por esquirla con su estado en `t`: {pos (mundo), dir, dist (al punto de impacto), altura (sobre la superficie), vy (vertical, mundo), vivo, vida}.
func esquirlas_estado(t: float) -> Array:
	var res: Array = []
	var g: Vector3 = _gravedad_local()
	for d in _esq:
		var e: Dictionary = _estado_esq(d, t, g)
		var p: Vector3 = e["pos"]
		var v: Vector3 = e["vel"]
		var vm: Vector3 = global_transform.basis * (_plano.basis * v)
		res.append({"pos": global_transform * (_plano.basis * p), "dir": vm.normalized(), "dist": p.length(), "altura": _altura(p), "vy": vm.y,
			"vivo": bool(e["vivo"]) and t > float(d["retraso"]), "vida": float(d["vida"]), "retraso": float(d["retraso"])})
	return res


## (esquirlas, cristales) que lleva.
func recuento() -> Array:
	return [_esq.size(), _cris.size()]


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


## Pone todo como en el instante `t` (s desde el impacto). Las pruebas lo llaman a mano.
func avanzar_a(t: float) -> void:
	if _p.is_empty() or _plano == null:
		return
	var r: float = radio
	if _destello != null:
		var u: float = clampf(t / T_DESTELLO, 0.0, 1.0)
		var d: float = float(_destello.get_meta("tam", 1.0))
		var s: float = d * lerpf(0.5, 1.1, sqrt(u))
		_destello.scale = Vector3(s, s, 1.0) if u < 1.0 else Vector3.ONE * 0.001
		var md: ShaderMaterial = _destello.material_override as ShaderMaterial
		md.set_shader_parameter("vida", (1.0 - u) if u < 1.0 else 0.0)
		md.set_shader_parameter("giro", _giro0 + t * 1.2)
	if _disco != null:
		var u2: float = clampf(t / 0.28, 0.0, 1.0)
		var m: ShaderMaterial = _disco.material_override as ShaderMaterial
		m.set_shader_parameter("u", u2)
		m.set_shader_parameter("vida", smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(_dur * 0.55, _dur, t)))
	if _mm_cris != null:
		var mc: MultiMesh = _mm_cris.multimesh
		for j in _cris.size():
			var c: Dictionary = _cris[j]
			var s1: float = clampf((t - float(c["retraso"])) / T_CRECE, 0.0, 1.0)
			var etapa: float = 0.55 * smoothstep(0.0, 0.5, s1) + 0.45 * smoothstep(0.5, 1.0, s1)          # brota en dos escalones
			var rompe: float = 1.0 - smoothstep(float(c["rompe"]), float(c["rompe"]) + 0.06, t)
			var f: float = etapa * rompe
			HieloMallas.poner(mc, j, c["pos"], c["rot"], float(c["wx"]), float(c["h"]) * f, float(c["wz"]), float(c["claro"]), 0.95 if f > 0.001 else 0.0, float(c["fase"]))
	var g: Vector3 = _gravedad_local()
	var mm: MultiMesh = _mm_esq.multimesh
	for i in _esq.size():
		var d3: Dictionary = _esq[i]
		var e: Dictionary = _estado_esq(d3, t, g)
		var tau: float = maxf(t - float(d3["retraso"]), 0.0)
		var rot: Basis = (Basis(d3["eje"], float(d3["vel_ang"]) * tau * (0.0 if bool(e["quieta"]) else 1.0)) * (d3["rot0"] as Basis)).orthonormalized()
		var u3: float = float(e["u"])
		var al: float = 0.9 * smoothstep(0.0, 0.05, u3) * (1.0 - smoothstep(0.7, 1.0, u3)) if (bool(e["vivo"]) and t >= float(d3["retraso"])) else 0.0
		_tr_esq[i] = HieloEsquirlas.poner(mm, i, e["pos"], rot, float(d3["tam"]), al, float(d3["clar"]))
