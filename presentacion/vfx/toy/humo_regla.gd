class_name HumoRegla
extends Node3D

## HUMO POR REGLA (9/11/2026, prototipo). La regla de la demo https://github.com/lejrimostfa/force-field-vfx-threejs (src/gas/sources.js) SIN simular gas, con bocanadas por la CPU como el resto de toys:
##   «el gas que se frena pierde calor más deprisa y el calor que pierde se convierte en hollín; el chorro rápido queda limpio» y «el aire rápido a ras de suelo levanta polvo».
## Cada BOCANADA lleva velocidad, temperatura T (1 → 0), hollín y edad. Por paso (los números de la demo; las velocidades, a nuestra escala ÷ 3,2):
##   lento   = 1 − smoothstep(1,6 ; 5 | |v − viento|)                                    (demo 5..16)
##   T      ← T · exp(−1,1 · (1 + 1,2 · lento) · dt) − 0,4 · T⁴ · dt                     (se enfría más deprisa lo lento, más una pérdida ∝ T⁴)
##   hollín += (T_antes − T) · rendimiento · lento · (1 − smoothstep(0,35 ; 0,95 | T))   (lo que pierde un gas LENTO y ya frío se vuelve hollín; lo rápido o muy caliente, no)
##   hollín ·= exp(−0,45 · dt)                                                           (se desvanece)
##   v       ← viento + (v − viento) · exp(−arrastre · dt) + (flotación · T + subida · hollín) · dt · ↑
## POLVO: `levantado = máx(|aire.xz| − 0,8 ; 0) · exp(−3,2 · y)` (y sobre el suelo, en m) modulado por un ruido; se desvanece a 0,35/s y MUCHO más deprisa con la altura.
## Lo que se VE: el tamaño y el tono salen del hollín (la cantidad de materia). Una bocanada limpia (hollín ≈ 0) no se dibuja: el chorro rápido queda limpio y el humo nace donde el fuego se frena.
## Se dibuja con el HUMO TOON del juego (humo_regla.gdshader = copia de humo_toon.gdshader con el tono por bocanada: pompas, dos tonos planos, borde duro, erosión al morir) en un MultiMesh.
## Tres MATERIAS: HUMO (pardo, fuego), VAPOR (blanco: agua sobre fuego) y POLVO (terroso: tierra y viento a ras de suelo).
## INTERRUPTORES: `capas` (una clave por efecto) TODAS APAGADAS por defecto en el juego; el lab las enciende con la tecla 8 (`poner_todas`). Ver `enganchar_*` (cada efecto llama a la suya con UNA línea).
## TOPES: `MAX_VIVAS` bocanadas vivas en toda la escena y `MAX_EMISORES` emisores a la vez.

const HumoToy = preload("res://presentacion/vfx/toy/humo_toy.gd")
const SH: String = "res://presentacion/vfx/toy/humo_regla.gdshader"
const GRUPO: StringName = &"humo_regla"
const MAX_VIVAS: int = 320
const MAX_EMISORES: int = 20

enum Materia { HUMO, VAPOR, POLVO }

## Una clave por capa nueva (todas false = el juego de siempre).
##   impacto_bola   la bola de fuego al chocar (ImpactoFuegoToy: solo GOLPE y FIN, no el barril ni el rebote)    muro / pilar   cima de MuroFuego y PilarFuego (FuegoToy)
##   barril         ExplosionFuegoToy                                                                           haz            el haz de fuego donde choca (FuegoToy HAZ con `choques`)
##   dragon         la punta del chorro de la trampa del dragón                                                 suelo          la hierba ardiendo (Vfx3D.llamas)
##   vapor          agua sobre fuego (Vfx3D.vapor, VfxPuzle3D.vapor e ImpactoAguaToy.sobre_fuego)               polvo_tierra / polvo_viento   impactos de tierra y viento contra el suelo
static var capas: Dictionary = {"impacto_bola": false, "muro": false, "pilar": false, "barril": false, "haz": false, "dragon": false, "suelo": false, "vapor": false,
	"polvo_tierra": false, "polvo_viento": false}
static var _registro: Array = []

# ---- la regla (números de la demo; velocidades ÷ 3,2) ----
const V_LENTO_A: float = 1.6
const V_LENTO_B: float = 5.0
const ENFRIAR: float = 1.1
const ENFRIAR_LENTO: float = 1.2
const PERDIDA_T4: float = 0.4
const OLVIDO_HOLLIN: float = 0.45
const POLVO_AIRE_MIN: float = 0.8
const POLVO_ALTURA: float = 3.2
const POLVO_OLVIDO: float = 0.35
const T_SALIDA: float = 0.78             ## temperatura con la que sale una bocanada de llama (la llama ya algo gastada: el hollín empieza en cuanto se frena)
const POLVO_OLVIDO_ALTO: float = 2.5     ## el polvo envejece (1 + esto · altura) veces más deprisa por encima del suelo

const PALETAS: Dictionary = {
	Materia.HUMO: {"claro": Color(0.62, 0.52, 0.46), "sombra": Color(0.42, 0.33, 0.30), "hollin": Color(0.30, 0.20, 0.16), "hollin_sombra": Color(0.17, 0.11, 0.10), "viejo": Color(0.27, 0.22, 0.21),
		"rend": 1.3, "olvido": OLVIDO_HOLLIN, "flota": 0.9, "sube": 0.35, "arrastre": 1.2, "tam_ini": 0.4, "tam_fin": 1.1, "vida": 2.4},
	Materia.VAPOR: {"claro": Color(0.97, 0.98, 1.0), "sombra": Color(0.76, 0.84, 0.93), "hollin": Color(0.97, 0.98, 1.0), "hollin_sombra": Color(0.76, 0.84, 0.93), "viejo": Color(0.84, 0.90, 0.96),
		"rend": 2.2, "olvido": 0.5, "flota": 0.9, "sube": 0.7, "arrastre": 1.0, "tam_ini": 0.4, "tam_fin": 1.2, "vida": 1.9},
	Materia.POLVO: {"claro": Color(0.82, 0.70, 0.52), "sombra": Color(0.56, 0.43, 0.28), "hollin": Color(0.82, 0.70, 0.52), "hollin_sombra": Color(0.56, 0.43, 0.28), "viejo": Color(0.50, 0.41, 0.31),
		"rend": 0.0, "olvido": POLVO_OLVIDO, "flota": 0.0, "sube": 0.12, "arrastre": 1.6, "tam_ini": 0.3, "tam_fin": 0.9, "vida": 1.5},
}
static var _materiales: Dictionary = {}

var materia: int = Materia.HUMO
var p: Dictionary = {}
var viento: Vector3 = Vector3.ZERO       ## aire en el que están las bocanadas (m/s). Si lo hay, deriva con él y «lento» se mide respecto a él
var y_suelo: float = 0.0                 ## altura del suelo para el polvo (m, mundo)
var fuentes: Array = []                  ## emisores continuos (ver `anadir_fuente`)
var sigue: Node3D = null                 ## si no es null, el emisor copia su transformada cada paso (cima de muro y pilar, choque del haz)
var cerrado: bool = false              ## true: no habrá más fuentes nuevas; el nodo se libera cuando se vaya la última bocanada
var emitidas: int = 0
var _n: int = 0
var _pos: PackedVector3Array = PackedVector3Array()
var _vel: PackedVector3Array = PackedVector3Array()
var _temp: PackedFloat32Array = PackedFloat32Array()
var _hollin: PackedFloat32Array = PackedFloat32Array()
var _edad: PackedFloat32Array = PackedFloat32Array()
var _vida: PackedFloat32Array = PackedFloat32Array()
var _sem: PackedFloat32Array = PackedFloat32Array()
var _giro: PackedFloat32Array = PackedFloat32Array()
var _giro_v: PackedFloat32Array = PackedFloat32Array()
var _tam_k: PackedFloat32Array = PackedFloat32Array()
var _vivo: PackedByteArray = PackedByteArray()
var _vivas: int = 0
var _mi: MultiMeshInstance3D = null
var _t: float = 0.0
var _cursor: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


# ====================================================================== la regla (funciones puras: las mide la prueba) ======================================================================

## 1 = va al ritmo del aire (se frena del todo), 0 = va muy por encima: el chorro rápido.
static func lento_de(v_rel: float) -> float:
	return 1.0 - smoothstep(V_LENTO_A, V_LENTO_B, v_rel)


## Un paso de calor y hollín: devuelve (T, hollín) nuevos.
static func paso_calor(temp: float, hollin: float, v_rel: float, dt: float, rend: float, olvido: float) -> Vector2:
	var lento: float = lento_de(v_rel)
	var antes: float = temp
	var t2: float = maxf(temp * exp(-ENFRIAR * (1.0 + ENFRIAR_LENTO * lento) * dt) - PERDIDA_T4 * pow(temp, 4.0) * dt, 0.0)
	var h: float = hollin + (antes - t2) * rend * lento * (1.0 - smoothstep(0.35, 0.95, t2))
	h *= exp(-olvido * dt)
	return Vector2(t2, h)


## Polvo que levanta un aire de rapidez horizontal `aire_xz` (m/s) a `y` m del suelo (sin ruido: el emisor lo modula).
static func polvo_alzado(aire_xz: float, y: float) -> float:
	return maxf(aire_xz - POLVO_AIRE_MIN, 0.0) * exp(-POLVO_ALTURA * maxf(y, 0.0))


## Cuánto se ve una bocanada con ese hollín (0 = no se dibuja).
static func visible_de(hollin: float) -> float:
	return smoothstep(0.02, 0.3, hollin)


static func vivas_global() -> int:
	var k: int = 0
	for e in _registro:
		if is_instance_valid(e):
			k += (e as HumoRegla)._vivas
	return k


static func emisores() -> int:
	return _registro.size()


static func poner_todas(v: bool) -> void:
	for k in capas:
		capas[k] = v


static func hay_alguna() -> bool:
	for k in capas:
		if bool(capas[k]):
			return true
	return false


# ====================================================================== el emisor ======================================================================

## Crea un emisor de `materia` en `pos` (mundo) colgado de `padre` (que debe estar en el árbol). null si se llegó a un tope.
## `q`: n (reserva de bocanadas), escala (tamaño ×), viento, y_suelo, y cualquier clave de PALETAS (tam_ini, tam_fin, vida, arrastre, flota, sube, rend, olvido).
static func crear(materia_: int, padre: Node, pos: Vector3, q: Dictionary = {}) -> HumoRegla:
	if padre == null or not padre.is_inside_tree() or _registro.size() >= MAX_EMISORES or vivas_global() >= MAX_VIVAS:
		return null
	var e: HumoRegla = HumoRegla.new()
	e.name = "HumoRegla"
	e.materia = materia_
	e.montar(int(q.get("n", 24)), q)
	padre.add_child(e)
	e.global_position = pos
	return e


func montar(n: int, q: Dictionary = {}) -> void:
	p = (PALETAS[materia] as Dictionary).duplicate()
	for k in q:
		p[k] = q[k]
	var esc: float = float(p.get("escala", 1.0))
	p["tam_ini"] = float(p["tam_ini"]) * esc
	p["tam_fin"] = float(p["tam_fin"]) * esc
	viento = p.get("viento", Vector3.ZERO)
	y_suelo = float(p.get("y_suelo", 0.0))
	_n = maxi(n, 1)
	_pos.resize(_n)
	_vel.resize(_n)
	_temp.resize(_n)
	_hollin.resize(_n)
	_edad.resize(_n)
	_vida.resize(_n)
	_sem.resize(_n)
	_giro.resize(_n)
	_giro_v.resize(_n)
	_tam_k.resize(_n)
	_vivo.resize(_n)
	_vivo.fill(0)
	_rng.randomize()
	_mi = HumoToy.crear_mm("Bocanadas", _n)
	_mi.top_level = true
	_mi.transform = Transform3D.IDENTITY
	_mi.material_override = material_de(materia)
	add_child(_mi)
	add_to_group(GRUPO)


func _enter_tree() -> void:
	if not _registro.has(self):
		_registro.append(self)


func _exit_tree() -> void:
	_registro.erase(self)


## ShaderMaterial compartido de cada materia (los colores salen de PALETAS).
static func material_de(m: int) -> ShaderMaterial:
	if _materiales.has(m) and is_instance_valid(_materiales[m]):
		return _materiales[m]
	var q: Dictionary = PALETAS[m]
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = load(SH)
	sm.render_priority = 1
	sm.set_shader_parameter("ruido", load(HumoToy.TEX_RUIDO))
	sm.set_shader_parameter("color_claro", q["claro"])
	sm.set_shader_parameter("color_sombra", q["sombra"])
	sm.set_shader_parameter("color_hollin", q["hollin"])
	sm.set_shader_parameter("color_hollin_sombra", q["hollin_sombra"])
	sm.set_shader_parameter("color_viejo", q["viejo"])
	sm.set_shader_parameter("erosion", 0.8)
	sm.set_shader_parameter("umbral", 0.42)
	sm.set_shader_parameter("ruido_borde", 0.22)
	_materiales[m] = sm
	return sm


func vivas() -> int:
	return _vivas


func multimesh() -> MultiMesh:
	return _mi.multimesh if _mi != null else null


## Una bocanada nueva en `pos` (mundo) con velocidad `vel`. Devuelve su hueco o −1 (reserva llena o tope global).
## `temp`: temperatura de salida (1 = recién salida de la llama); `masa`: hollín/vapor/polvo de salida (el polvo lo trae ya; el humo y el vapor lo crean al enfriarse).
func soltar(pos: Vector3, vel: Vector3, temp: float = 1.0, tam_k: float = 1.0, vida_k: float = 1.0, masa: float = 0.0) -> int:
	if _vivas >= _n or vivas_global() >= MAX_VIVAS:
		return -1
	var h: int = -1
	for k in _n:
		var j: int = (_cursor + k) % _n
		if _vivo[j] == 0:
			h = j
			break
	if h < 0:
		return -1
	_cursor = (h + 1) % _n
	_vivo[h] = 1
	_vivas += 1
	emitidas += 1
	_pos[h] = pos
	_vel[h] = vel
	_temp[h] = temp
	_hollin[h] = masa
	_edad[h] = 0.0
	_vida[h] = maxf(float(p["vida"]) * vida_k * _rng.randf_range(0.85, 1.15), 0.2)
	_sem[h] = _rng.randf()
	_giro[h] = _rng.randf() * TAU
	_giro_v[h] = _rng.randf_range(0.3, 0.7) * (1.0 if _rng.randf() < 0.5 else -1.0)
	_tam_k[h] = tam_k * _rng.randf_range(0.85, 1.2)
	return h


## Emisor continuo. `d`: local (Vector3 en el espacio de ESTE nodo), caja (semiextensión), dir (local), v (Vector2 min/máx m/s), abanico (grados), ritmo (bocanadas/s), temp, tam_k, vida_k,
## escala_fn (Callable → 0..1 que multiplica el ritmo; opcional), dura (s; <0 = hasta `cerrar`).
func anadir_fuente(d: Dictionary) -> void:
	var f: Dictionary = {"local": Vector3.ZERO, "caja": Vector3.ZERO, "dir": Vector3.UP, "v": Vector2(1.0, 2.0), "abanico": 25.0, "ritmo": 4.0, "temp": 1.0, "tam_k": 1.0, "vida_k": 1.0,
		"dura": -1.0, "acc": 0.0, "t": 0.0}
	for k in d:
		f[k] = d[k]
	fuentes.append(f)


## Fuente de AIRE RÁPIDO a ras de suelo que levanta polvo (solo materia POLVO): `centro` (mundo), `radio` (m), `aire` (m/s hacia fuera), `dura` (s, el aire se va apagando), `ritmo` (intentos/s).
func anadir_aire(centro: Vector3, radio: float, aire: float, dura: float, ritmo: float = 40.0) -> void:
	fuentes.append({"aire": true, "centro": centro, "radio": radio, "v_aire": aire, "dura": dura, "ritmo": ritmo, "acc": 0.0, "t": 0.0})


func cerrar() -> void:
	cerrado = true


func _process(delta: float) -> void:
	avanzar(delta)


## Mueve todo `delta` s. Las pruebas la llaman a mano.
func avanzar(delta: float) -> void:
	if _mi == null or delta <= 0.0:
		return
	_t += delta
	if sigue != null:
		if is_instance_valid(sigue) and sigue.is_inside_tree():
			global_transform = sigue.global_transform
		else:                                  # el toy se fue: no hay más fuentes, lo soltado se acaba
			sigue = null
			fuentes.clear()
			cerrar()
	_emitir_fuentes(delta)
	var mm: MultiMesh = _mi.multimesh
	var rend: float = float(p["rend"])
	var olvido: float = float(p["olvido"])
	var flota: float = float(p["flota"])
	var sube: float = float(p["sube"])
	var arr: float = exp(-float(p["arrastre"]) * delta)
	var polvo: bool = materia == Materia.POLVO
	for i in _n:
		if _vivo[i] == 0:
			continue
		var v: Vector3 = _vel[i]
		var ritmo_edad: float = 1.0
		if polvo:
			ritmo_edad += POLVO_OLVIDO_ALTO * clampf(_pos[i].y - y_suelo, 0.0, 2.0)
		_edad[i] += delta * ritmo_edad
		var u: float = _edad[i] / _vida[i]
		if u >= 1.0:
			_matar(i, mm)
			continue
		var h: float = _hollin[i]
		if polvo:
			h *= exp(-olvido * delta * ritmo_edad)
			v.y += sube * delta
		else:
			var r: Vector2 = paso_calor(_temp[i], h, (v - viento).length(), delta, rend, olvido)
			_temp[i] = r.x
			h = r.y
			v.y += (flota * r.x + sube * clampf(h, 0.0, 1.0)) * delta
		_hollin[i] = h
		v = viento + (v - viento) * arr
		_vel[i] = v
		_pos[i] += v * delta
		_giro[i] += _giro_v[i] * delta
		var vis: float = visible_de(h)
		var g: float = 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 2.2)
		var tam: float = lerpf(float(p["tam_ini"]), float(p["tam_fin"]), g) * _tam_k[i] * vis
		HumoToy.poner(mm, i, _pos[i], tam, tam, _giro[i], u, _sem[i], maxf(clampf(h / 0.8, 0.0, 1.0), 0.02))
	if cerrado and _vivas == 0 and fuentes.is_empty():
		queue_free()


func _matar(i: int, mm: MultiMesh) -> void:
	_vivo[i] = 0
	_vivas -= 1
	HumoToy.ocultar(mm, i)


func _emitir_fuentes(delta: float) -> void:
	var quitar: Array = []
	for f in fuentes:
		var fd: Dictionary = f
		fd["t"] = float(fd["t"]) + delta
		var dura: float = float(fd["dura"])
		if dura >= 0.0 and float(fd["t"]) > dura:
			quitar.append(f)
			continue
		var k: float = 1.0
		if fd.has("escala_fn") and (fd["escala_fn"] as Callable).is_valid():
			k = float((fd["escala_fn"] as Callable).call())
		fd["acc"] = float(fd["acc"]) + float(fd["ritmo"]) * k * delta
		while float(fd["acc"]) >= 1.0:
			fd["acc"] = float(fd["acc"]) - 1.0
			if bool(fd.get("aire", false)):
				_probar_polvo(fd)
			else:
				_soltar_de(fd)
	for f in quitar:
		fuentes.erase(f)


func _soltar_de(f: Dictionary) -> void:
	var caja: Vector3 = f["caja"]
	var loc: Vector3 = f["local"] + Vector3(_rng.randf_range(-1, 1) * caja.x, _rng.randf_range(-1, 1) * caja.y, _rng.randf_range(-1, 1) * caja.z)
	var dir: Vector3 = (global_transform.basis * (f["dir"] as Vector3)).normalized()
	var ab: float = deg_to_rad(float(f["abanico"]))
	var perp: Vector3 = dir.cross(Vector3.RIGHT if absf(dir.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	var d2: Vector3 = dir.rotated(perp, _rng.randf_range(0.0, ab)).rotated(dir, _rng.randf() * TAU)
	var vv: Vector2 = f["v"]
	soltar(global_transform * loc, d2 * _rng.randf_range(vv.x, vv.y), float(f["temp"]), float(f["tam_k"]), float(f["vida_k"]))


## Un intento de levantar polvo: aire radial que sale del centro, a una altura al azar sobre el suelo; la cantidad levantada sale de `polvo_alzado` y de un ruido.
func _probar_polvo(f: Dictionary) -> void:
	var c: Vector3 = f["centro"]
	var ang: float = _rng.randf() * TAU
	var rr: float = float(f["radio"]) * sqrt(_rng.randf())
	var dura: float = maxf(float(f["dura"]), 0.01)
	var apaga: float = 1.0 - clampf(float(f["t"]) / dura, 0.0, 1.0)
	var aire: float = float(f["v_aire"]) * apaga
	var y: float = _rng.randf() * 0.7
	var pos: Vector3 = c + Vector3(cos(ang) * rr, 0.0, sin(ang) * rr)
	var ruido: float = 0.5 + 0.5 * sin(pos.x * 3.1 + _t * 2.3) * sin(pos.z * 2.7 - _t * 1.7)
	var alzado: float = polvo_alzado(aire, y) * (0.4 + 0.6 * ruido)
	if _rng.randf() > clampf(alzado * 0.6, 0.0, 1.0):
		return
	var radial: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
	soltar(Vector3(pos.x, y_suelo + 0.05 + y * 0.35, pos.z), radial * aire * 0.7 + Vector3(0, 0.15, 0), 0.0, _rng.randf_range(0.8, 1.3), 1.0, clampf(0.5 + alzado, 0.3, 1.0))


## Medición para las pruebas: una entrada por bocanada viva.
func estados() -> Array:
	var r: Array = []
	for i in _n:
		if _vivo[i] != 0:
			var u: float = _edad[i] / _vida[i]
			r.append({"hueco": i, "pos": _pos[i], "vel": _vel[i], "temp": _temp[i], "hollin": _hollin[i], "u": u, "visible": visible_de(_hollin[i])})
	return r


func hollin_max() -> float:
	var m: float = 0.0
	for i in _n:
		if _vivo[i] != 0:
			m = maxf(m, _hollin[i])
	return m


# ====================================================================== enganches (cada efecto llama a UNO con una línea; sin su interruptor no hacen nada) ======================================================================

static func _activa(clave: String) -> bool:
	return bool(capas.get(clave, false))


static func _escena_de(nodo: Node) -> Node:
	return nodo.get_parent() if nodo.get_parent() != null else nodo


## Un emisor que SIGUE a `fuego` (sus fuentes se colocan con su transformada) pero cuelga de su padre: si el toy muere, deja de emitir y las bocanadas ya sueltas se acaban solas en vez de desaparecer de golpe.
static func _seguidor(fuego: Node3D, q: Dictionary) -> HumoRegla:
	quitar_de(fuego)
	var padre: Node = fuego.get_parent()
	if padre == null:
		return null
	var e: HumoRegla = crear(Materia.HUMO, padre, fuego.global_position, q)
	if e == null:
		return null
	e.name = "HumoReglaForma"
	e.sigue = fuego
	e.global_transform = fuego.global_transform
	fuego.set_meta(&"humo_regla_emisor", e)
	return e


## Cierra el emisor que sigue a `fuego` (al rehacer la figura): deja de emitir y lo ya soltado se va solo.
static func quitar_de(fuego: Node) -> void:
	var e: Variant = fuego.get_meta(&"humo_regla_emisor") if fuego.has_meta(&"humo_regla_emisor") else null
	if e != null and is_instance_valid(e):
		(e as HumoRegla).sigue = null
		(e as HumoRegla).fuentes.clear()
		(e as HumoRegla).cerrar()
	if fuego.has_meta(&"humo_regla_emisor"):
		fuego.remove_meta(&"humo_regla_emisor")


## La bola de fuego al CHOCAR (ImpactoFuegoToy, en su primer fotograma): salen bocanadas calientes y rápidas por la superficie; se frenan contra ella y AHÍ se vuelven humo. En vuelo no hay nada.
static func enganchar_impacto_fuego(imp: Node3D) -> HumoRegla:
	if not _activa("impacto_bola") or not imp.is_inside_tree() or imp.has_meta(&"humo_regla") or imp.get_parent() is ExplosionFuegoToy:
		return null
	if int(imp.get("variante")) != int(ImpactoFuegoToy.Variante.GOLPE):      # el rebote sigue su camino y el FIN se agota en el aire: nada se frena contra una superficie
		return null
	imp.set_meta(&"humo_regla", true)
	var n: Vector3 = (imp.get("normal") as Vector3).normalized()
	var r: float = float(imp.get("radio"))
	var k: float = clampf(r / 0.4, 0.6, 2.2)
	var e: HumoRegla = crear(Materia.HUMO, _escena_de(imp), imp.global_position, {"n": 18, "escala": k, "arrastre": 3.0, "vida": 2.2})
	if e == null:
		return null
	var base: Vector3 = imp.global_position + n * 0.12 * k
	var t1: Vector3 = n.cross(Vector3.UP)
	t1 = (t1 if t1.length() > 0.1 else n.cross(Vector3.RIGHT)).normalized()
	var t2: Vector3 = n.cross(t1).normalized()
	for i in 14:
		var a: float = TAU * float(i) / 14.0 + e._rng.randf_range(-0.3, 0.3)
		var lateral: Vector3 = t1 * cos(a) + t2 * sin(a)
		var d: Vector3 = (lateral * 0.85 + n * e._rng.randf_range(0.15, 0.5) + Vector3.UP * 0.2).normalized()
		e.soltar(base + lateral * 0.1 * k, d * e._rng.randf_range(3.6, 6.4) * k, T_SALIDA, e._rng.randf_range(0.8, 1.2))
	e.cerrar()
	return e


## CIMA de MURO y PILAR de fuego: la llama sube rápida y se frena arriba; donde se frena suelta hollín. Cuelga de la raíz del FuegoToy (sigue al toy) y se calla al apagarse él (`aparicion`).
static func enganchar_cima(fuego: Node3D, clave: String) -> HumoRegla:
	if not _activa(clave) or not fuego.is_inside_tree() or fuego.get_parent() is ExplosionFuegoToy:       # las lenguas del barril ya llevan su propia capa
		return null
	var sx: float = float(fuego.get("semieje_x"))
	var sy: float = float(fuego.get("semieje_y"))
	var sz: float = float(fuego.get("semieje_z"))
	var k: float = clampf(sy / 1.5, 0.6, 1.6)
	var ancho: float = sx * 0.8 if clave == "muro" else sx * 0.5
	var fondo: float = sz if clave == "muro" else sz * 0.5
	var e: HumoRegla = _seguidor(fuego, {"n": 48, "escala": k, "arrastre": 1.4, "vida": 2.4})
	if e == null:
		return null
	e.anadir_fuente({"local": Vector3(0, sy * 0.9, 0), "caja": Vector3(ancho, 0.05, fondo), "dir": Vector3.UP, "v": Vector2(0.9, 1.8) * k, "abanico": 22.0,
		"ritmo": clampf(4.0 + ancho * 2.0, 6.0, 16.0), "temp": T_SALIDA, "tam_k": 1.0,
		"escala_fn": func() -> float: return clampf((float(fuego.get("aparicion")) - 0.7) / 0.3, 0.0, 1.0) if is_instance_valid(fuego) else 0.0})
	return e


## HAZ de fuego contra un tope: en cada `choque` {d, x, n} (espacio local del toy) el chorro se frena y se abre: ahí sale el humo. Cuelga de la raíz del toy.
static func enganchar_haz(fuego: Node3D, choques: Array, h: float) -> HumoRegla:
	if not _activa("haz") or not fuego.is_inside_tree() or choques.is_empty():
		return null
	var e: HumoRegla = _seguidor(fuego, {"n": 40, "escala": 1.0, "arrastre": 2.4, "vida": 2.2})
	if e == null:
		return null
	var cuantos: int = 0
	for ch in choques:
		if cuantos >= 2 or not (ch is Dictionary) or not (ch as Dictionary).has("d"):
			continue
		cuantos += 1
		var n: Vector3 = (ch as Dictionary).get("n", Vector3(0, 0, 1)) as Vector3
		n.y = 0.0
		n = n.normalized() if n.length() > 0.01 else Vector3(0, 0, 1)
		e.anadir_fuente({"local": Vector3(float((ch as Dictionary).get("x", 0.0)), h, -float((ch as Dictionary)["d"])) + n * 0.15, "caja": Vector3(0.25, 0.3, 0.25), "dir": (n + Vector3(0, 0.5, 0)).normalized(),
			"v": Vector2(2.5, 4.5), "abanico": 55.0, "ritmo": 10.0, "temp": T_SALIDA, "tam_k": 0.9})
	return e


## EXPLOSIÓN del barril (ExplosionFuegoToy): la onda sale rápida (limpia) y se frena a unos metros: el anillo de humo nace ahí, no en el centro.
static func enganchar_barril(expl: Node3D) -> HumoRegla:
	if not _activa("barril") or not expl.is_inside_tree() or expl.has_meta(&"humo_regla"):
		return null
	expl.set_meta(&"humo_regla", true)
	var radio: float = float(expl.get("radio"))
	var k: float = clampf(radio / 2.6, 0.5, 2.0)
	var e: HumoRegla = crear(Materia.HUMO, _escena_de(expl), expl.global_position, {"n": 40, "escala": 1.2 * k, "arrastre": 2.0, "vida": 2.8})
	if e == null:
		return null
	for i in 26:
		var a: float = TAU * float(i) / 26.0 + e._rng.randf_range(-0.12, 0.12)
		var d: Vector3 = Vector3(cos(a), e._rng.randf_range(0.15, 0.45), sin(a)).normalized()
		e.soltar(expl.global_position + Vector3(0, 0.3 * k, 0) + d * 0.2 * k, d * e._rng.randf_range(5.0, 9.0) * k, T_SALIDA, e._rng.randf_range(0.9, 1.3))
	e.cerrar()
	return e


## Punta del chorro del DRAGÓN: `punta` (mundo) es donde el haz llega al tope; sale una tanda de bocanadas hacia atrás/arriba.
static func enganchar_dragon(padre: Node3D, punta: Vector3, dir: Vector3) -> HumoRegla:
	if not _activa("dragon") or padre == null or not padre.is_inside_tree():
		return null
	var e: HumoRegla = crear(Materia.HUMO, padre, punta, {"n": 14, "escala": 1.1, "arrastre": 2.4, "vida": 2.2})
	if e == null:
		return null
	for i in 5:
		var d: Vector3 = (-dir * e._rng.randf_range(0.2, 0.8) + Vector3(e._rng.randf_range(-0.5, 0.5), e._rng.randf_range(0.3, 0.9), e._rng.randf_range(-0.5, 0.5))).normalized()
		e.soltar(punta + Vector3(e._rng.randf_range(-0.2, 0.2), 0, e._rng.randf_range(-0.2, 0.2)), d * e._rng.randf_range(3.2, 5.2), T_SALIDA, e._rng.randf_range(0.8, 1.1))
	e.cerrar()
	return e


## SUELO ardiendo (Vfx3D.llamas con fuego pleno): cuelga de la raíz de las llamas y se va con ellas. Un hilo continuo de bocanadas pequeñas que suben despacio.
static func enganchar_suelo(raiz: Node3D, radio: float) -> HumoRegla:
	if not _activa("suelo") or raiz == null or not raiz.is_inside_tree():
		return null
	var e: HumoRegla = crear(Materia.HUMO, raiz, raiz.global_position, {"n": 20, "escala": clampf(0.5 + radio, 0.7, 1.3), "arrastre": 1.2, "vida": 2.4})
	if e == null:
		return null
	e.name = "HumoReglaSuelo"
	e.anadir_fuente({"local": Vector3(0, 0.55, 0), "caja": Vector3(maxf(radio, 0.2), 0.05, maxf(radio, 0.2)), "dir": Vector3.UP, "v": Vector2(0.8, 1.5), "abanico": 20.0, "ritmo": 4.0, "temp": T_SALIDA, "tam_k": 0.9})
	return e


## VAPOR (agua sobre fuego): una tanda de bocanadas calientes y lentas que suben; se enfrían y se vuelven vapor blanco. `esc` = tamaño (1 = el de Vfx3D.vapor).
static func enganchar_vapor(padre: Node, pos: Vector3, esc: float = 1.0) -> HumoRegla:
	if not _activa("vapor") or padre == null or not padre.is_inside_tree():
		return null
	var e: HumoRegla = crear(Materia.VAPOR, padre, pos, {"n": 14, "escala": clampf(esc, 0.4, 2.0), "arrastre": 1.1, "vida": 1.9})
	if e == null:
		return null
	for i in 8:
		var a: float = e._rng.randf() * TAU
		var d: Vector3 = Vector3(cos(a) * e._rng.randf_range(0.1, 0.5), 1.0, sin(a) * e._rng.randf_range(0.1, 0.5)).normalized()
		e.soltar(pos + Vector3(cos(a), 0, sin(a)) * 0.15 * esc, d * e._rng.randf_range(1.4, 2.6) * esc, T_SALIDA, e._rng.randf_range(0.8, 1.2))
	e.cerrar()
	return e


## POLVO en los impactos de TIERRA y de VIENTO contra el SUELO (su primer fotograma): el golpe saca un aire rápido a ras de suelo que se apaga en ~0,5 s y levanta polvo según `polvo_alzado`.
static func enganchar_polvo(imp: Node3D, clave: String) -> HumoRegla:
	if not _activa(clave) or not imp.is_inside_tree() or imp.has_meta(&"humo_regla"):
		return null
	var n: Vector3 = (imp.get("normal") as Vector3).normalized()
	if n.dot(Vector3.UP) < 0.7 or int(imp.get("variante")) == 1:       # solo contra el suelo (y no el FIN, que se agota en el aire)
		return null
	imp.set_meta(&"humo_regla", true)
	var r: float = float(imp.get("radio"))
	var k: float = clampf(r / 0.4, 0.7, 2.5)
	var e: HumoRegla = crear(Materia.POLVO, _escena_de(imp), imp.global_position, {"n": 22, "escala": k, "y_suelo": imp.global_position.y, "arrastre": 1.8, "vida": 1.5})
	if e == null:
		return null
	e.anadir_aire(imp.global_position, 0.25 * k + 0.1, (6.0 if clave == "polvo_viento" else 4.5) * sqrt(k), 0.55, 90.0)
	e.cerrar()
	return e
