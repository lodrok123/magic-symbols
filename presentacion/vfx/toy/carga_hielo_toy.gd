extends Node3D

## CASTEO DEL HIELO (3/11/2026; el equivalente de carga_agua_toy.gd y carga_toy.gd). Lo que rodea a la mano mientras se carga el hechizo, sutil y SIN brillo (no hay halo, ni luz, ni aditivo):
##   · ESQUIRLAS pequeñas que aparecen en una esfera de ~0,6-1 m alrededor de la mano y CONVERGEN hacia el bloque de hielo que se va formando, en espiral y acelerando, girando sobre sí mismas.
##     Cuanto más avanza la carga, más esquirlas hay a la vez. Son un MultiMesh movido por la CPU: no cuentan como GPUParticles3D y son deterministas (hash) para medirlas con `estado_gotas()`.
##   · ÓRBITAS: tres cristales pequeños que giran alrededor de la mano y se van cerrando.
##   · ESCARCHA en el suelo bajo los pies: un disco blanco azulado que se extiende con la carga.
## Cuelga del nodo «Carga» de HieloToy (que no escala con la bola). HieloToy avisa cada fotograma con `poner(escala, progreso)`; `salir(t)` lo desvanece y se libera.

const HieloMallas = preload("res://presentacion/vfx/toy/hielo_mallas.gd")
const HieloEsquirlas = preload("res://presentacion/vfx/toy/hielo_esquirlas.gd")
const MAX_GOTAS: int = 36
const N_ORBITAS: int = 3

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
var _mm: MultiMeshInstance3D = null
var _orb: MultiMeshInstance3D = null
var _suelo: MeshInstance3D = null


func montar(r_final: float, n_gotas: int, brillo: float = 1.0, radio_mult: float = 1.0, pies: Vector3 = Vector3(0, -0.7, 0.5)) -> void:
	_r_final = r_final
	_n = clampi(n_gotas, 0, MAX_GOTAS)
	_brillo = brillo
	_radio_mult = radio_mult
	_pies = pies
	_mm = HieloEsquirlas.crear_mm("Esquirlas", MAX_GOTAS)
	add_child(_mm)
	_orb = HieloMallas.crear_mm("Orbitas", N_ORBITAS, HieloMallas.cristal(6, 3.0), 0.7, 2)
	add_child(_orb)
	_suelo = HieloMallas.escarcha("Escarcha", 0.6, randf())
	_suelo.position = _pies
	add_child(_suelo)
	actualizar(0.0, 0.12, 0.0)


func poner_gotas(n: int) -> void:
	_n = clampi(n, 0, MAX_GOTAS)


func poner_brillo(b: float) -> void:
	_brillo = b


func poner_radio(m: float) -> void:
	_radio_mult = m


func n_gotas() -> int:
	return _n


## Cuántas esquirlas hay a la vez (de las `n_gotas`) con el progreso actual: pocas al empezar, todas al final.
func n_visibles() -> int:
	return clampi(int(round(float(_n) * lerpf(0.25, 1.0, pow(clampf(_prog, 0.0, 1.0), 0.8)))), 0, MAX_GOTAS)


## HieloToy avisa del tamaño actual del bloque (`escala`, 0..1+) y del progreso 0..1; el nodo se anima solo con su propio _process (también mientras se desvanece).
func poner(escala: float, progreso: float) -> void:
	_esc = escala
	_prog = progreso


func _process(delta: float) -> void:
	actualizar(delta, _esc, _prog)


static func _hash(a: float) -> float:
	return fposmod(sin(a * 12.9898) * 43758.5453, 1.0)


## Estado de la esquirla `i` en el instante `t` con el progreso `p`: {pos, dir (hacia donde va), mov, u (edad 0..1), r0 (radio de nacimiento), rad (radio actual), vel}.
func _gotita(i: int, t: float, p: float) -> Dictionary:
	var periodo: float = lerpf(0.85, 0.5, p)
	var fase: float = float(i) / float(MAX_GOTAS) + _hash(float(i) * 7.3) * 0.5
	var x: float = t / periodo + fase
	var c: float = floorf(x)
	var u: float = x - c
	var sd: float = float(i) * 17.17 + c * 3.31
	var th: float = acos(2.0 * _hash(sd + 1.0) - 1.0)
	var fi: float = TAU * _hash(sd + 2.0)
	var d0: Vector3 = Vector3(sin(th) * cos(fi), cos(th), sin(th) * sin(fi))
	var r0: float = _r_final * lerpf(3.0, 2.1, p) * _radio_mult * (0.75 + 0.5 * _hash(sd + 3.0))
	var r_bola: float = _r_final * clampf(_esc, 0.05, 1.3) * 0.9           # hacia donde van: el borde del bloque de hielo que se está formando
	var k: float = u * u * (3.0 - 2.0 * u) * 0.55 + u * 0.45                    # acelera casi toda la caída
	var rad: float = lerpf(r0, r_bola, k)
	var giro: float = 1.7 * u * (0.6 + _hash(sd + 4.0))
	var d: Vector3 = d0.rotated(Vector3.UP, giro)
	var d1: Vector3 = d0.rotated(Vector3.UP, giro + 0.05)
	var pos: Vector3 = d * rad
	var v: Vector3 = (d1 * lerpf(r0, r_bola, k + 0.03) - pos) / 0.03 * 0.6
	return {"pos": pos, "dir": -d, "mov": v.normalized() if v.length() > 0.001 else -d, "u": u, "r0": r0, "rad": rad, "vel": v.length() / periodo}


## Medición para las pruebas: una entrada por esquirla VISIBLE con su estado actual.
func estado_gotas() -> Array:
	var res: Array = []
	for i in n_visibles():
		res.append(_gotita(i, _t, _prog))
	return res


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
			HieloMallas.ocultar(mm, i)
			continue
		var e: Dictionary = _gotita(i, _t, p)
		var u: float = float(e["u"])
		var alfa: float = smoothstep(0.0, 0.16, u) * (1.0 - smoothstep(0.86, 1.0, u)) * _vida * 0.9 * clampf(_brillo, 0.0, 1.0)
		var tam: float = (0.07 + 0.05 * _hash(float(i) * 3.7)) * sqrt(k) * (1.0 - 0.35 * smoothstep(0.5, 1.0, u))
		var rot: Basis = Basis(Quaternion(Vector3.UP, e["mov"])) * Basis(Vector3.UP, _t * 4.0 + float(i))
		HieloEsquirlas.poner(mm, i, e["pos"], rot, tam, alfa, 0.35 + 0.5 * _hash(float(i) * 5.1))
	# órbitas: tres cristales pequeños girando alrededor de la mano, cada vez más cerca
	var mo: MultiMesh = _orb.multimesh
	var vis: float = smoothstep(0.05, 0.4, p) * _vida * clampf(_brillo, 0.0, 1.0)
	for j in N_ORBITAS:
		var ang: float = _t * lerpf(2.2, 4.2, p) + TAU * float(j) / float(N_ORBITAS)
		var rr: float = _r_final * lerpf(1.9, 1.35, p)
		var pos2: Vector3 = Vector3(cos(ang) * rr, sin(ang * 0.7 + float(j)) * rr * 0.35, sin(ang) * rr)
		var rot2: Basis = Basis(Vector3(0, 0, 1), -PI * 0.5 + 0.3 * sin(_t * 3.0 + float(j))) * Basis(Vector3.UP, -ang)
		HieloMallas.poner(mo, j, pos2, rot2, _r_final * 0.14, _r_final * 0.62, _r_final * 0.14, 0.5, 0.85 * vis, float(j) * 0.31)
	# escarcha bajo los pies: se extiende con la carga
	var d: float = _r_final * lerpf(2.2, 3.4, p) * 2.0
	_suelo.scale = Vector3(d, 1.0, d)
	var ms: ShaderMaterial = _suelo.material_override as ShaderMaterial
	ms.set_shader_parameter("u", smoothstep(0.0, 0.8, p))
	ms.set_shader_parameter("vida", smoothstep(0.0, 0.25, p) * _vida * clampf(_brillo, 0.0, 1.0) * 0.8)


## Se desvanece en `dur` s y se libera.
func salir(dur: float = 0.12) -> void:
	if _salida < 0.0:
		_salida = 0.0
		_salida_dur = maxf(dur, 0.01)
