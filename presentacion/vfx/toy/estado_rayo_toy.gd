class_name EstadoRayoToy
extends Node3D

## ESTADO «ELECTRIFICADO» DEL RAYO (5/11/2026; referencia en vídeo de Pablo: el «Status» del paquete de rayo son arcos y chispitas que RECORREN el cuerpo, y el agua electrificada es el mismo recurso sobre la superficie).
## Mismos trazos y destellos que RayoToy (RayoTrazos, rayo_trazo.gdshader y rayo_destello.gdshader: paleta del rayo del juego, aditivo, sin partículas de GPU, sin luz). Dos modos:
##   ENTIDAD     arcos cortos (de 0,12 a 0,3 m) que se agarran a la piel de un cilindro de `alto` × `radio` y la recorren, y chispitas que saltan. Cuelga del propio nodo electrificado (lo sigue). Dura `dur` s y se apaga
##               en T_APAGAR; `renovar(dur)` lo alarga (una descarga nueva). El orden de las cosas lo manda la lógica (la reacción «electrocutado» de Mundo3D): aquí solo se dibuja.
##   SUPERFICIE  la misma cosa tendida sobre un rectángulo `ancho_x` × `ancho_z` a ras de agua (una casilla de agua electrificada): arcos que saltan por la superficie y chispas INTERMITENTES (cada hueco se enciende
##               y se apaga al azar). No se apaga solo: lo quita quien lo puso (`apagar()`) cuando el estado del suelo caduca (reloj oficial: 2 s).
## Parpadea: la línea se redibuja cada T_REDIBUJO s (otras posiciones, otros arcos; cada hueco de arco se apaga un 40 % de las veces).

const RayoTrazos = preload("res://presentacion/vfx/toy/rayo_trazos.gd")

enum Modo { ENTIDAD, SUPERFICIE }

const T_REDIBUJO: float = 0.07
const T_APAGAR: float = 0.15
const HUECOS_ENTIDAD: int = 8              ## arcos a la vez sobre un cuerpo
const HUECOS_SUPERFICIE: int = 4           ## arcos a la vez por casilla de agua
const N_TRAZOS: int = 48
const N_BRILLOS: int = 12
const P_ENCENDIDO: float = 0.6             ## probabilidad de que un hueco esté encendido en un redibujo (intermitente)

@export var modo: Modo = Modo.ENTIDAD
@export_range(0.1, 6.0, 0.01, "or_greater") var alto: float = 1.0
@export_range(0.05, 3.0, 0.01, "or_greater") var radio: float = 0.35
@export_range(0.2, 8.0, 0.01, "or_greater") var ancho_x: float = 2.0
@export_range(0.2, 8.0, 0.01, "or_greater") var ancho_z: float = 2.0
@export_range(0.0, 3.0, 0.05) var brillo: float = 1.0
## Segundos de vida (ENTIDAD). 0 o menos = no se apaga solo (SUPERFICIE).
@export var dur: float = 1.2

var _t: float = 0.0
var _t_red: float = 0.0
var _apagando: bool = false
var _t_apagar: float = 0.0
var _trazos: MultiMeshInstance3D = null
var _brillos: MultiMeshInstance3D = null
var _lista: Array = []
var _bril: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _n_red: int = 0
var _huecos_vivos: int = 0


static func para_entidad(alto_: float, radio_: float, dur_: float = 1.2) -> EstadoRayoToy:
	var e := EstadoRayoToy.new()
	e.modo = Modo.ENTIDAD
	e.alto = maxf(alto_, 0.1)
	e.radio = maxf(radio_, 0.05)
	e.dur = dur_
	return e


static func para_superficie(x: float, z: float) -> EstadoRayoToy:
	var e := EstadoRayoToy.new()
	e.modo = Modo.SUPERFICIE
	e.ancho_x = maxf(x, 0.2)
	e.ancho_z = maxf(z, 0.2)
	e.dur = 0.0
	return e


func _ready() -> void:
	_rng.randomize()
	_trazos = RayoTrazos.crear_trazos("Trazos", N_TRAZOS)
	add_child(_trazos)
	_brillos = RayoTrazos.crear_destellos("Chispas", N_BRILLOS)
	add_child(_brillos)
	_redibujar()


## Una descarga nueva: lo alarga `d` s más desde ahora (y lo reenciende si se estaba apagando).
func renovar(d: float = -1.0) -> void:
	_t = 0.0
	_apagando = false
	_t_apagar = 0.0
	if d > 0.0:
		dur = d


## Lo apaga en T_APAGAR s y se libera.
func apagar() -> void:
	_apagando = true


func esta_apagando() -> bool:
	return _apagando


func _process(delta: float) -> void:
	_t += delta
	if not _apagando and dur > 0.0 and _t >= dur:
		_apagando = true
	if _apagando:
		_t_apagar += delta
		if _t_apagar >= T_APAGAR:
			queue_free()
			return
	_t_red += delta
	if _t_red >= T_REDIBUJO:
		_redibujar()


## Intensidad del conjunto (1 → 0 al apagarse).
func vida() -> float:
	return 1.0 - clampf(_t_apagar / T_APAGAR, 0.0, 1.0) if _apagando else 1.0


## Redibujos que lleva (pruebas).
func redibujos() -> int:
	return _n_red


## Los tramos del último redibujo (pruebas): [{a, b, ancho, alfa, ...}] en el espacio local del nodo.
func trazos_actuales() -> Array:
	return _lista


func brillos_actuales() -> Array:
	return _bril


## Cuántos arcos están encendidos ahora (pruebas: intermitentes).
func huecos_encendidos() -> int:
	return _huecos_vivos


func _redibujar() -> void:
	if _trazos == null:
		return
	_t_red = 0.0
	_n_red += 1
	var env: float = vida() * (0.7 + 0.3 * _rng.randf()) * brillo
	var lista: Array = []
	var bril: Array = []
	_huecos_vivos = 0
	if modo == Modo.ENTIDAD:
		_dibujar_entidad(lista, bril, env)
	else:
		_dibujar_superficie(lista, bril, env)
	RayoTrazos.volcar(_trazos.multimesh, lista)
	_lista = lista
	_bril = bril
	for i in N_BRILLOS:
		if i < bril.size():
			var b: Dictionary = bril[i]
			RayoTrazos.poner_destello(_brillos.multimesh, i, b["pos"], float(b["tam"]), float(b["alfa"]), float(b["estrella"]), _rng.randf() * TAU, float(i) * 0.17)
		else:
			RayoTrazos.ocultar(_brillos.multimesh, i)


## Punto de la piel del cilindro a la altura `h` y el ángulo `a`, a `k` radios.
func _piel(a: float, h: float, k: float = 1.08) -> Vector3:
	return Vector3(cos(a) * radio * k, h, sin(a) * radio * k)


## ENTIDAD: arcos que se agarran a la piel y la recorren (de lado, o subiendo y bajando), con la desviación de un rayo.
func _dibujar_entidad(lista: Array, bril: Array, env: float) -> void:
	var g: float = 0.07 + 0.025 * clampf(radio / 0.4, 0.5, 2.0)
	for k in HUECOS_ENTIDAD:
		if _rng.randf() > P_ENCENDIDO:
			continue
		_huecos_vivos += 1
		var a0: float = _rng.randf() * TAU
		var h0: float = _rng.randf_range(0.08, 0.92) * alto
		var recorrido: float = _rng.randf_range(0.2, 0.45)
		var vertical: bool = _rng.randf() < 0.4
		var da: float = 0.0 if vertical else (recorrido / maxf(radio, 0.05)) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var dh: float = (recorrido * (1.0 if _rng.randf() < 0.5 else -1.0)) if vertical else _rng.randf_range(-0.06, 0.06)
		var pts: PackedVector3Array = PackedVector3Array()
		var n: int = 3
		for i in n + 1:
			var u: float = float(i) / float(n)
			var desv: float = _rng.randf_range(-1.0, 1.0) * 0.04 * (sin(PI * u) + 0.2)
			var p: Vector3 = _piel(a0 + da * u, clampf(h0 + dh * u, 0.02, alto), 1.08 + desv * 3.0)
			pts.append(p)
		RayoTrazos.trazar(lista, pts, g, 0.95 * env, 1.0, 0.8, 0.6, float(k))
		if _rng.randf() < 0.4:
			bril.append({"pos": pts[n], "tam": 0.22 + 0.06 * alto, "alfa": 0.95 * env, "estrella": 0.9})
	# chispitas sueltas que saltan de la piel
	for s in 3:
		if _rng.randf() < 0.5 and bril.size() < N_BRILLOS:
			var q: Vector3 = _piel(_rng.randf() * TAU, _rng.randf_range(0.0, 1.0) * alto, 1.4)
			bril.append({"pos": q, "tam": 0.07 + 0.03 * _rng.randf(), "alfa": 0.9 * env, "estrella": 0.9})


## SUPERFICIE: arcos que saltan por una casilla de agua (a ras: y = 0) y chispas intermitentes.
func _dibujar_superficie(lista: Array, bril: Array, env: float) -> void:
	var g: float = 0.05
	for k in HUECOS_SUPERFICIE:
		if _rng.randf() > P_ENCENDIDO:
			continue
		_huecos_vivos += 1
		var a: Vector3 = Vector3(_rng.randf_range(-0.5, 0.5) * ancho_x, 0.03, _rng.randf_range(-0.5, 0.5) * ancho_z)
		var ang: float = _rng.randf() * TAU
		var largo: float = _rng.randf_range(0.4, 0.9)
		var b: Vector3 = a + Vector3(cos(ang), 0.0, sin(ang)) * largo
		b.x = clampf(b.x, -0.5 * ancho_x, 0.5 * ancho_x)
		b.z = clampf(b.z, -0.5 * ancho_z, 0.5 * ancho_z)
		var pts: PackedVector3Array = RayoTrazos.camino(a, b, 4, 0.07, _rng)
		for q in pts.size():
			var pq: Vector3 = pts[q]
			pq.y = 0.03 + (0.04 * sin(PI * float(q) / float(pts.size() - 1)) if _rng.randf() < 0.5 else 0.0)
			pts[q] = pq
		RayoTrazos.trazar(lista, pts, g, 0.9 * env, 1.0, 0.8, 0.6, float(k))
		bril.append({"pos": pts[0], "tam": 0.16, "alfa": 0.8 * env, "estrella": 0.9})
	for s in 4:
		if _rng.randf() < 0.45 and bril.size() < N_BRILLOS:
			bril.append({"pos": Vector3(_rng.randf_range(-0.5, 0.5) * ancho_x, 0.05, _rng.randf_range(-0.5, 0.5) * ancho_z), "tam": 0.09 + 0.05 * _rng.randf(), "alfa": 0.85 * env, "estrella": 0.9})
