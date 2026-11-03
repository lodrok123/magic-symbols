extends Node3D

## CASTEO DEL RAYO (2/11/2026; el equivalente de carga_agua_toy.gd y carga_toy.gd). Lo que rodea a la mano mientras se carga el hechizo (aditivo, como todo el rayo; sin luz propia):
##   · CHISPAS pequeñas (estrellas de T_flare8) que aparecen en una esfera de ~0,6-1 m alrededor de la mano y CONVERGEN hacia la bola que se va formando, en espiral y acelerando. Cuanto más avanza la carga,
##     más chispas hay a la vez. Son un MultiMesh movido por la CPU: no cuentan como GPUParticles3D y son deterministas (hash) para medirlas con `estado_gotas()`.
##   · ARCOS: tres arcos cortos de descarga que saltan de la mano a un punto cercano y se redibujan cada 0,06 s (quebrados, distintos cada vez), más frecuentes y largos cuanto más carga.
##   · BRILLO EN EL SUELO bajo los pies: un halo suave que late con la carga.
## Cuelga del nodo «Carga» de RayoToy (que no escala con la bola). RayoToy avisa cada fotograma con `poner(escala, progreso)`; `salir(t)` lo desvanece y se libera.

const RayoTrazos = preload("res://presentacion/vfx/toy/rayo_trazos.gd")
const MAX_GOTAS: int = 36
const N_ARCOS: int = 3
const SEG_ARCO: int = 4
const T_REDIBUJO: float = 0.06

var _r_final: float = 0.4
var _t: float = 0.0
var _salida: float = -1.0
var _salida_dur: float = 0.12
var _vida: float = 1.0
var _n: int = 28
var _radio_mult: float = 1.0
var _brillo: float = 1.0
var _esc: float = 0.12
var _prog: float = 0.0
var _pies: Vector3 = Vector3(0, -0.7, 0.5)
var _mm: MultiMeshInstance3D = null           ## chispas (MAX_GOTAS) + el brillo del suelo (la última)
var _arcos: MultiMeshInstance3D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _t_arco: float = 0.0
var _lista_arcos: Array = []


func montar(r_final: float, n_gotas: int, brillo: float = 1.0, radio_mult: float = 1.0, pies: Vector3 = Vector3(0, -0.7, 0.5)) -> void:
	_r_final = r_final
	_n = clampi(n_gotas, 0, MAX_GOTAS)
	_brillo = brillo
	_radio_mult = radio_mult
	_pies = pies
	_rng.seed = 4711
	_mm = RayoTrazos.crear_destellos("Chispas", MAX_GOTAS + 1)
	add_child(_mm)
	_arcos = RayoTrazos.crear_trazos("Arcos", N_ARCOS * SEG_ARCO)
	add_child(_arcos)
	actualizar(0.0, 0.12, 0.0)


func poner_gotas(n: int) -> void:
	_n = clampi(n, 0, MAX_GOTAS)


func poner_brillo(b: float) -> void:
	_brillo = b


func poner_radio(m: float) -> void:
	_radio_mult = m


func n_gotas() -> int:
	return _n


## Cuántas chispas hay a la vez (de las `n_gotas`) con el progreso actual: pocas al empezar, todas al final.
func n_visibles() -> int:
	return clampi(int(round(float(_n) * lerpf(0.25, 1.0, pow(clampf(_prog, 0.0, 1.0), 0.8)))), 0, MAX_GOTAS)


## RayoToy avisa del tamaño actual de la bola (`escala`, 0..1+) y del progreso 0..1; el nodo se anima solo con su propio _process (también mientras se desvanece).
func poner(escala: float, progreso: float) -> void:
	_esc = escala
	_prog = progreso


func _process(delta: float) -> void:
	actualizar(delta, _esc, _prog)


static func _hash(a: float) -> float:
	return fposmod(sin(a * 12.9898) * 43758.5453, 1.0)


## Estado de la chispa `i` en el instante `t` con el progreso `p`: {pos, dir, mov, u (edad 0..1), r0 (radio de nacimiento), rad (radio actual), vel}.
func _gotita(i: int, t: float, p: float) -> Dictionary:
	var periodo: float = lerpf(0.7, 0.4, p)
	var fase: float = float(i) / float(MAX_GOTAS) + _hash(float(i) * 7.3) * 0.5
	var x: float = t / periodo + fase
	var c: float = floorf(x)
	var u: float = x - c
	var sd: float = float(i) * 17.17 + c * 3.31
	var th: float = acos(2.0 * _hash(sd + 1.0) - 1.0)
	var fi: float = TAU * _hash(sd + 2.0)
	var d0: Vector3 = Vector3(sin(th) * cos(fi), cos(th), sin(th) * sin(fi))
	var r0: float = _r_final * lerpf(3.0, 2.1, p) * _radio_mult * (0.75 + 0.5 * _hash(sd + 3.0))
	var r_bola: float = _r_final * clampf(_esc, 0.05, 1.3) * 0.9
	var k: float = u * u * (3.0 - 2.0 * u) * 0.55 + u * 0.45
	var rad: float = lerpf(r0, r_bola, k)
	var giro: float = 1.7 * u * (0.6 + _hash(sd + 4.0))
	var d: Vector3 = d0.rotated(Vector3.UP, giro)
	var d1: Vector3 = d0.rotated(Vector3.UP, giro + 0.05)
	var pos: Vector3 = d * rad
	var v: Vector3 = (d1 * lerpf(r0, r_bola, k + 0.03) - pos) / 0.03 * 0.6
	return {"pos": pos, "dir": -d, "mov": v.normalized() if v.length() > 0.001 else -d, "u": u, "r0": r0, "rad": rad, "vel": v.length() / periodo}


## Medición para las pruebas: una entrada por chispa VISIBLE con su estado actual.
func estado_gotas() -> Array:
	var res: Array = []
	for i in n_visibles():
		res.append(_gotita(i, _t, _prog))
	return res


## Tramos de los arcos del último redibujo (pruebas): [{a, b, ...}].
func arcos_actuales() -> Array:
	return _lista_arcos


func actualizar(delta: float, escala: float, progreso: float) -> void:
	_t += delta
	_esc = escala
	_prog = progreso
	if _salida >= 0.0:
		_salida += delta
		_vida = 1.0 - clampf(_salida / _salida_dur, 0.0, 1.0)
		if _vida <= 0.0:
			queue_free()
			return
	var p: float = clampf(progreso, 0.0, 1.0)
	var k: float = _r_final / 0.4
	var mm: MultiMesh = _mm.multimesh
	var nv: int = n_visibles()
	for i in MAX_GOTAS:
		if i >= nv:
			RayoTrazos.ocultar(mm, i)
			continue
		var e: Dictionary = _gotita(i, _t, p)
		var u: float = float(e["u"])
		var alfa: float = smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.8, 1.0, u)) * _vida * clampf(_brillo, 0.0, 1.5) * 0.85
		RayoTrazos.poner_destello(mm, i, e["pos"], (0.1 + 0.08 * _hash(float(i) * 3.7)) * sqrt(k), alfa, 0.9, _t * 3.0 + float(i), float(i) * 0.13)
	# el halo del suelo late con la carga
	var late: float = 0.55 + 0.45 * sin(_t * lerpf(9.0, 18.0, p))
	RayoTrazos.poner_destello(mm, MAX_GOTAS, _pies, _r_final * lerpf(2.2, 3.4, p) * 2.0, smoothstep(0.0, 0.3, p) * late * _vida * clampf(_brillo, 0.0, 1.5) * 0.22, 0.0, 0.0, 0.0)
	# arcos: se redibujan cada T_REDIBUJO s
	_t_arco += delta
	if _t_arco >= T_REDIBUJO:
		_t_arco = 0.0
		_redibujar_arcos(p)


func _redibujar_arcos(p: float) -> void:
	_lista_arcos = []
	var vis: float = smoothstep(0.05, 0.35, p) * _vida * clampf(_brillo, 0.0, 1.5)
	if vis > 0.001:
		for j in N_ARCOS:
			if _rng.randf() > lerpf(0.5, 0.95, p):          # al principio saltan menos arcos
				continue
			var d: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 1.0), _rng.randf_range(-1, 1)).normalized()
			# los arcos salen de la SUPERFICIE de la esfera que se está formando (no de su centro) y saltan hacia fuera
			var r_bola: float = _r_final * clampf(_esc, 0.05, 1.3)
			var largo: float = r_bola + _r_final * _rng.randf_range(0.7, 1.5) * lerpf(0.8, 1.2, p)
			var pts: PackedVector3Array = RayoTrazos.camino(d * r_bola * 0.95, d * largo, SEG_ARCO, _r_final * 0.4, _rng)
			RayoTrazos.trazar(_lista_arcos, pts, 0.07 * sqrt(_r_final / 0.4) + 0.02, 0.9 * vis, 1.0, 1.0, 0.6, float(j))
	RayoTrazos.volcar(_arcos.multimesh, _lista_arcos)


## Se desvanece en `dur` s y se libera.
func salir(dur: float = 0.12) -> void:
	if _salida < 0.0:
		_salida = 0.0
		_salida_dur = maxf(dur, 0.01)
