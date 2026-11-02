extends Node3D

## ESTÉTICA DE LA CARGA DEL HECHIZO, 3.ª versión (2/11/2026, revisión de Pablo: «un brillo sutil y pequeñas chispas aglutinándose alrededor de la mano»). Sustituye al remolino Spiral07 y a las briznas
## largas (Windstreak3) de la versión anterior, que tapaban la bola. Lo que rodea a la mano mientras se carga el hechizo:
##   · BRILLO: un halo cálido y pequeño, detrás de todo (sin prueba de profundidad), que crece un poco con la carga, y un PUNTO brillante al final (la bola no se ve: ver `carga_bola_visible`).
##   · CHISPAS: puntos alargados diminutos (chispa_impacto.gdshader, la rampa de la bola) que aparecen en una esfera de ~0,3-0,5 m alrededor de la mano y CAEN hacia ella acelerando, con un poco
##     de giro. Cuanto más avanza la carga, MÁS chispas hay a la vez, nacen MÁS cerca de la mano y el ciclo es más corto (más juntas).
## Cuelga del nodo «Carga» de FuegoToy (que no escala con la bola). Todo son 2 quads + 1 MultiMesh movido por la CPU: cuenta 0 en el presupuesto de GPUParticles3D.
## FuegoToy avisa cada fotograma con `poner(escala, progreso)`; `salir(t)` lo desvanece y se libera. Las chispas son deterministas (hash), así que las pruebas pueden medirlas con `estado_chispas()`.

const SpriteToy = preload("res://presentacion/vfx/toy/sprite_toy.gd")
const SH_HALO: String = "res://presentacion/vfx/toy/halo_impacto.gdshader"
const MAX_CHISPAS: int = 40

var _r_final: float = 0.4
var _t: float = 0.0
var _salida: float = -1.0
var _salida_dur: float = 0.12
var _vida: float = 1.0
var _n: int = 28
var _brillo: float = 1.0
var _radio_mult: float = 1.0
var _esc: float = 0.12
var _prog: float = 0.0
var _halo: MeshInstance3D = null
var _punto: MeshInstance3D = null
var _mm: MultiMeshInstance3D = null


func montar(r_final: float, n_chispas: int, brillo: float = 1.0, radio_mult: float = 1.0) -> void:
	FuegoToy._rampas()
	_r_final = r_final
	_n = clampi(n_chispas, 0, MAX_CHISPAS)
	_brillo = brillo
	_radio_mult = radio_mult
	_halo = _glow("Brillo", 2.4, Color(1.0, 0.42, 0.1), 0.0)
	_punto = _glow("Punto", 5.5, Color(1.0, 0.82, 0.45), 0.0)
	_mm = SpriteToy.chispas_mm("Chispas", MAX_CHISPAS, 2.0)
	add_child(_mm)
	actualizar(0.0, 0.12, 0.0)


func _glow(nombre: String, caida: float, color: Color, brillo: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_HALO)
	m.render_priority = 3
	m.set_shader_parameter("brillo", brillo)
	m.set_shader_parameter("caida", caida)
	m.set_shader_parameter("billboard", 2)
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("latido", 0.06)
	m.set_shader_parameter("semilla", randf())
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * 0.01
	add_child(mi)
	return mi


func poner_chispas(n: int) -> void:
	_n = clampi(n, 0, MAX_CHISPAS)


func poner_brillo(b: float) -> void:
	_brillo = b


func poner_radio(m: float) -> void:
	_radio_mult = m


func n_chispas() -> int:
	return _n


## Cuántas chispas hay a la vez (de las `n_chispas`) con el progreso actual: pocas al empezar, todas al final.
func n_visibles() -> int:
	return clampi(int(round(float(_n) * lerpf(0.2, 1.0, pow(clampf(_prog, 0.0, 1.0), 0.8)))), 0, MAX_CHISPAS)


## FuegoToy avisa del tamaño actual de la bola (`escala`, 0..1+) y del progreso 0..1; el nodo se anima solo con su propio _process (también mientras se desvanece).
func poner(escala: float, progreso: float) -> void:
	_esc = escala
	_prog = progreso


func _process(delta: float) -> void:
	actualizar(delta, _esc, _prog)


static func _hash(a: float) -> float:
	return fposmod(sin(a * 12.9898) * 43758.5453, 1.0)


## Estado de la chispa `i` en el instante `t` con el progreso `p`: {pos, dir (hacia la mano), u (edad 0..1), r0 (radio de nacimiento), rad (radio actual)}.
func _chispa(i: int, t: float, p: float) -> Dictionary:
	var periodo: float = lerpf(0.78, 0.45, p)
	var fase: float = float(i) / float(MAX_CHISPAS) + _hash(float(i) * 7.3) * 0.5
	var x: float = t / periodo + fase
	var c: float = floorf(x)
	var u: float = x - c
	var sd: float = float(i) * 17.17 + c * 3.31
	var th: float = acos(2.0 * _hash(sd + 1.0) - 1.0)
	var fi: float = TAU * _hash(sd + 2.0)
	var d0: Vector3 = Vector3(sin(th) * cos(fi), cos(th), sin(th) * sin(fi))
	var r0: float = _r_final * lerpf(1.3, 0.85, p) * _radio_mult * (0.75 + 0.5 * _hash(sd + 3.0))
	var rad: float = r0 * (1.0 - u * u)                                    # acelera hacia la mano (la velocidad crece con u)
	var giro: float = 1.1 * u * (0.6 + _hash(sd + 4.0))
	var d: Vector3 = d0.rotated(Vector3.UP, giro)
	return {"pos": d * rad, "dir": -d, "u": u, "r0": r0, "rad": rad, "vel": 2.0 * r0 * u / periodo}


## Medición para las pruebas: una entrada por chispa VISIBLE con su estado actual.
func estado_chispas() -> Array:
	var res: Array = []
	for i in n_visibles():
		res.append(_chispa(i, _t, _prog))
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
	var k: float = _r_final / FuegoToy.REF_BOLA.x
	# brillo pequeño y suave que crece un poco con la carga + punto brillante al final
	var tam_h: float = _r_final * lerpf(2.6, 4.4, p)
	_halo.scale = Vector3(tam_h, tam_h, 1.0)
	(_halo.material_override as ShaderMaterial).set_shader_parameter("brillo", lerpf(0.4, 1.25, p) * _brillo * _vida)
	var tam_p: float = _r_final * lerpf(0.7, 1.1, p)
	_punto.scale = Vector3(tam_p, tam_p, 1.0)
	(_punto.material_override as ShaderMaterial).set_shader_parameter("brillo", 2.2 * smoothstep(0.6, 1.0, p) * _brillo * _vida)
	# chispas
	var mm: MultiMesh = _mm.multimesh
	var nv: int = n_visibles()
	for i in MAX_CHISPAS:
		if i >= nv:
			SpriteToy.poner_chispa(mm, i, Vector3.ZERO, Vector3.UP, 0.0, 0.0, 0.0, 0.0, false)
			continue
		var e: Dictionary = _chispa(i, _t, p)
		var u: float = float(e["u"])
		var alfa: float = smoothstep(0.0, 0.14, u) * (1.0 - smoothstep(0.84, 1.0, u)) * _vida
		var largo: float = clampf(0.075 + 0.04 * float(e["vel"]), 0.075, 0.26) * pow(k, 0.5)
		var ancho: float = 0.031 * pow(k, 0.5) * (1.0 - 0.45 * smoothstep(0.6, 1.0, u))
		SpriteToy.poner_chispa(mm, i, e["pos"], e["dir"], largo, ancho, lerpf(0.95, 0.55, u), alfa, false)


## Se desvanece en `dur` s y se libera.
func salir(dur: float = 0.12) -> void:
	if _salida < 0.0:
		_salida = 0.0
		_salida_dur = maxf(dur, 0.01)
