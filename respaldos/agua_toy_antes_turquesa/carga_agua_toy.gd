extends Node3D

## CASTEO DEL AGUA (3/11/2026, fase 1; el equivalente de carga_toy.gd). Lo que rodea a la mano mientras se carga el hechizo, sutil y SIN brillo (no hay halo, ni luz, ni aditivo):
##   · GOTITAS pequeñas que aparecen en una esfera de ~0,6-1 m alrededor de la mano y CONVERGEN hacia la bola de agua que se va formando, en espiral y acelerando. Cuanto más avanza la carga, más
##     gotitas hay a la vez y el ciclo es más corto. Son un MultiMesh movido por la CPU (agua_gota.gdshader): no cuentan como GPUParticles3D, y son deterministas (hash) para medirlas con `estado_gotas()`.
##   · REMOLINO pequeño de cintas de agua (agua_cinta.gdshader) que gira alrededor de la mano y se va cerrando.
##   · ANILLO DE ONDAS en el suelo bajo los pies (agua_onda.gdshader): dos ondas desfasadas que nacen, se expanden y se desvanecen, en bucle.
## Cuelga del nodo «Carga» de AguaToy (que no escala con la bola). AguaToy avisa cada fotograma con `poner(escala, progreso)`; `salir(t)` lo desvanece y se libera.

const AguaGotas = preload("res://presentacion/vfx/toy/agua_gotas.gd")
const AguaMallas = preload("res://presentacion/vfx/toy/agua_mallas.gd")
const MAX_GOTAS: int = 36

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
var _remolino: Node3D = null
var _ondas: Array = []                  ## [MeshInstance3D, MeshInstance3D]
var _cintas_mat: Array = []


func montar(r_final: float, n_gotas: int, brillo: float = 1.0, radio_mult: float = 1.0, pies: Vector3 = Vector3(0, -0.7, 0.5)) -> void:
	_r_final = r_final
	_n = clampi(n_gotas, 0, MAX_GOTAS)
	_brillo = brillo
	_radio_mult = radio_mult
	_pies = pies
	_mm = AguaGotas.crear_mm("Gotitas", MAX_GOTAS)
	add_child(_mm)
	# remolino: dos cintas finas que giran alrededor de la mano (eje Y del nodo: la malla es de eje Z y se tumba 90° en X)
	_remolino = Node3D.new()
	_remolino.name = "Remolino"
	_remolino.rotation_degrees = Vector3(-90, 0, 0)
	add_child(_remolino)
	for k in 2:
		var f: float = float(k) * 0.5
		var r0: float = r_final
		var malla: ArrayMesh = AguaMallas.cinta(-0.55 * r0, 0.75 * r0, 1.25, f, 36,
			func(u: float, _z: float) -> float: return r0 * lerpf(2.0, 1.25, u),
			func(u: float) -> float: return r0 * 0.15 * (1.0 - 0.5 * u))
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Cinta%d" % k
		mi.mesh = malla
		var m: ShaderMaterial = AguaMallas.material(AguaMallas.SH_CINTA, {"fase": f * 1.3, "repeticion": 1.1, "opacidad": 0.0, "suave_prof": 0.2, "extremos": 0.25, "punta": 0.5}, 1)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_remolino.add_child(mi)
		_cintas_mat.append(m)
	# ondas en el suelo bajo los pies
	for k in 2:
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2.ONE
		q.orientation = PlaneMesh.FACE_Y
		var mo: MeshInstance3D = MeshInstance3D.new()
		mo.name = "Onda%d" % k
		mo.mesh = q
		mo.material_override = AguaMallas.material(AguaMallas.SH_ONDA, {"anillos": 2.0, "charco": 0.22, "grosor": 0.05, "separacion": 0.2, "radio_ini": 0.2, "radio_fin": 0.96,
			"se_va": 0.4, "semilla": float(k) * 0.37, "fade_canto": 0.3, "u": 0.0, "vida": 0.0}, 0)
		mo.position = _pies
		mo.scale = Vector3(1, 1, 1)
		mo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mo)
		_ondas.append(mo)
	actualizar(0.0, 0.12, 0.0)


func poner_gotas(n: int) -> void:
	_n = clampi(n, 0, MAX_GOTAS)


func poner_brillo(b: float) -> void:
	_brillo = b


func poner_radio(m: float) -> void:
	_radio_mult = m


func n_gotas() -> int:
	return _n


## Cuántas gotitas hay a la vez (de las `n_gotas`) con el progreso actual: pocas al empezar, todas al final.
func n_visibles() -> int:
	return clampi(int(round(float(_n) * lerpf(0.25, 1.0, pow(clampf(_prog, 0.0, 1.0), 0.8)))), 0, MAX_GOTAS)


## AguaToy avisa del tamaño actual de la bola (`escala`, 0..1+) y del progreso 0..1; el nodo se anima solo con su propio _process (también mientras se desvanece).
func poner(escala: float, progreso: float) -> void:
	_esc = escala
	_prog = progreso


func _process(delta: float) -> void:
	actualizar(delta, _esc, _prog)


static func _hash(a: float) -> float:
	return fposmod(sin(a * 12.9898) * 43758.5453, 1.0)


## Estado de la gotita `i` en el instante `t` con el progreso `p`: {pos, dir (hacia donde va), u (edad 0..1), r0 (radio de nacimiento), rad (radio actual), vel}.
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
	var r_bola: float = _r_final * clampf(_esc, 0.05, 1.3) * 0.9           # hacia donde van: el borde de la bola de agua que se está formando
	var k: float = u * u * (3.0 - 2.0 * u) * 0.55 + u * 0.45                    # acelera casi toda la caída
	var rad: float = lerpf(r0, r_bola, k)
	var giro: float = 1.7 * u * (0.6 + _hash(sd + 4.0))
	var d: Vector3 = d0.rotated(Vector3.UP, giro)
	var d1: Vector3 = d0.rotated(Vector3.UP, giro + 0.05)
	var pos: Vector3 = d * rad
	var v: Vector3 = (d1 * lerpf(r0, r_bola, k + 0.03) - pos) / 0.03 * 0.6
	return {"pos": pos, "dir": -d, "mov": v.normalized() if v.length() > 0.001 else -d, "u": u, "r0": r0, "rad": rad, "vel": v.length() / periodo}


## Medición para las pruebas: una entrada por gotita VISIBLE con su estado actual.
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
			AguaGotas.poner(mm, i, Vector3.ZERO, Vector3.DOWN, 0.0, 0.0, 0.0, 0.0, false)
			continue
		var e: Dictionary = _gotita(i, _t, p)
		var u: float = float(e["u"])
		var alfa: float = smoothstep(0.0, 0.16, u) * (1.0 - smoothstep(0.86, 1.0, u)) * _vida * 0.9
		var ancho: float = (0.038 + 0.026 * _hash(float(i) * 3.7)) * sqrt(k) * (1.0 - 0.35 * smoothstep(0.5, 1.0, u))
		var largo: float = ancho * clampf(1.0 + 0.5 * float(e["vel"]), 1.0, 2.2)
		AguaGotas.poner(mm, i, e["pos"], e["mov"], largo, ancho, 0.35 + 0.5 * _hash(float(i) * 5.1), alfa, i % 7 == 3)
	# remolino: gira y se va cerrando y apareciendo con la carga
	_remolino.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_remolino.rotate_object_local(Vector3(0, 0, 1), -_t * lerpf(2.6, 5.0, p))
	var vis: float = smoothstep(0.05, 0.4, p) * _vida * _brillo
	for m in _cintas_mat:
		(m as ShaderMaterial).set_shader_parameter("opacidad", 0.62 * vis)
	_remolino.scale = Vector3.ONE * lerpf(1.05, 0.8, p)
	# ondas bajo los pies: dos fases desfasadas medio ciclo
	var ciclo: float = lerpf(1.5, 1.0, p)
	for j in 2:
		var o: MeshInstance3D = _ondas[j]
		var uu: float = fposmod(_t / ciclo + float(j) * 0.5, 1.0)
		var d: float = _r_final * lerpf(2.2, 3.0, p) * 2.0
		o.scale = Vector3(d, 1.0, d)
		var m2: ShaderMaterial = o.material_override as ShaderMaterial
		m2.set_shader_parameter("u", uu)
		m2.set_shader_parameter("vida", smoothstep(0.0, 0.25, p) * _vida * _brillo * 0.55)


## Se desvanece en `dur` s y se libera.
func salir(dur: float = 0.12) -> void:
	if _salida < 0.0:
		_salida = 0.0
		_salida_dur = maxf(dur, 0.01)
