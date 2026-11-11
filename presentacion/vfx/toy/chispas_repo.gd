class_name ChispasRepo
extends Node3D

## CHISPAS COMO LAS DEL REPO DE GAS (11/11/2026; https://github.com/lejrimostfa/force-field-vfx-threejs, src/render/sparks.js, MIT; técnica T30 de docs/TECNICAS_REPO_GAS_OTROS_ELEMENTOS_2026-11-10.md).
## La misma regla que el repo hace en GPU, aquí por la CPU (como `HazMasaSim._mover_chispas`) y dibujada con el MultiMesh de chispas de SpriteToy (chispa_impacto.gdshader):
##   · VIDAS ESCALONADAS: el hueco i espera (i / n) · `escalon` s antes de nacer por primera vez; no salen todas de golpe (repo: 2,3 s para 1000).
##   · NACEN EN LA PIEL del emisor: a R + 0,15 de una esfera, de una cápsula o de un plano (repo: shieldR + 0,15), con frente = normalizar(azar + normal · 1,2)
##     y v = frente · v_frente + azar · v_azar + empuje (repo: frente·3 + azar·6 + (−4, 2, 0); aquí ÷ 3,2 como HumoRegla).
##   · VIVEN en el aire: v ← mix(v, aire, 1,6 · dt) + gravedad · dt (inercia al aire del repo; −7 m/s²).
##   · REBOTAN 0,35 en el suelo (`y_suelo`) y en la piel del emisor (se proyectan fuera y pierden lo que entra, como el escudo del repo).
##   · SE ESTIRAN con la velocidad: el trazo mide |v| · `estira` (repo: cola = p − v · 0,028 s), un punto si va despacio.
##   · COLOR ∝ calor²: calor = vida que le queda / 1,2 (repo), por el tramo de la rampa de la paleta del elemento (nada nuevo):
##       RAYO  rampa hecha con RayoPaleta (HALO_HONDO → HALO → HALO_BORDE → CUERPO → NUCLEO): azul que se enfría, amarillo-blanco en caliente.
##       MAGMA la rampa de la bola de FuegoToy por su TRAMO BAJO (0,15 → 0,55, rojo → naranja, como las brasas de MagmaToy): sin amarillo.
## INTERRUPTORES (`capas`, una clave por efecto; todas son capas NUEVAS que se añaden a lo que ya había: apagadas, el efecto queda exactamente como estaba):
##   rayo_impacto   ImpactoRayoToy (GOLPE, REBOTE, FIN y AREA)            rayo_pilar      pie de la columna de RayoToy PILAR (desde que llega al suelo)
##   rayo_proyectil estela de la bola de RayoToy en vuelo                  electrificado   EstadoRayoToy (ENTIDAD: de la cápsula del cuerpo; SUPERFICIE: del agua)
##   magma_impacto  ImpactoMagmaToy (brasas que salen del cráter)          magma_proyectil estela de la bola de MagmaToy que rueda
##   electrificado_capsula  NO son chispas: los ARCOS de EstadoRayoToy ENTIDAD se agarran a la CapsuleShape3D real del cuerpo en vez del cilindro fijo. Cambia el dibujo de
##                  siempre, así que iba APAGADA de serie; desde el 11/11 (Pablo: «enciéndelas todas») va encendida como las demás.
## TOPES: `MAX_POR_EMISOR` chispas por emisor y `MAX_VIVAS` en toda la escena. El emisor cuelga de la ESCENA (no del efecto): si el efecto se va, lo ya soltado acaba solo.

const SpriteToy = preload("res://presentacion/vfx/toy/sprite_toy.gd")
const RayoPaleta = preload("res://presentacion/vfx/toy/rayo_paleta.gd")

enum Paleta { RAYO, MAGMA }
enum Piel { PLANO, ESFERA, CAPSULA }

const DE_SERIE: Dictionary = {"rayo_impacto": true, "rayo_pilar": true, "rayo_proyectil": true, "electrificado": true, "electrificado_capsula": true,     # 11/11 (Pablo: «enciéndelas todas»): los arcos en la cápsula de serie
	"magma_impacto": true, "magma_proyectil": true}
static var capas: Dictionary = DE_SERIE.duplicate()
static var _registro: Array = []
static var _rampa_rayo: GradientTexture1D = null

const MAX_POR_EMISOR: int = 60
const MAX_VIVAS: int = 360
# ---- la regla del repo (velocidades ÷ 3,2, como HumoRegla) ----
const SEPARA_PIEL: float = 0.15          ## nacen a R + esto
const FRENTE_NORMAL: float = 1.2         ## frente = normalizar(azar + normal · esto)
const INERCIA: float = 1.6               ## 1/s hacia el aire
const GRAVEDAD: float = 7.0
const REBOTE: float = 0.35
const ESTIRA: float = 0.028 * 3.2        ## s de cola (a nuestra escala de velocidades)
const CALOR_VIDA: float = 1.2            ## calor = vida que queda / esto

var paleta: int = Paleta.RAYO
var piel: int = Piel.PLANO
var piel_c: Vector3 = Vector3.ZERO       ## PLANO: punto; ESFERA: centro; CAPSULA: extremo a
var piel_b: Vector3 = Vector3.ZERO       ## CAPSULA: extremo b
var piel_n: Vector3 = Vector3.UP         ## PLANO: normal
var piel_r: float = 0.4                  ## ESFERA / CAPSULA: radio; PLANO: radio del disco donde nacen
var choca_piel: bool = true              ## rebotan en la piel (la esfera de la estela no: va con la bola)
var aire: Vector3 = Vector3.ZERO         ## velocidad del aire en el que van (m/s)
var empuje: Vector3 = Vector3.ZERO       ## se suma a la velocidad de salida (repo: (−4, 2, 0) ÷ 3,2)
var v_base: Vector3 = Vector3.ZERO       ## velocidad del emisor (estela: la de la bola; así se quedan atrás con inercia)
var k_base: float = 0.6                  ## fracción de v_base con la que salen
var v_frente: float = 3.0 / 3.2
var v_azar: float = 6.0 / 3.2
var vida_min: float = 0.5
var vida_max: float = 2.3
var escalon: float = 0.35                ## s en que se reparten las primeras vidas
var emite: float = 0.5                   ## s que renace un hueco muerto (< 0: hasta `cerrar`)
var y_suelo: float = -1000.0             ## altura del suelo (mundo) para el rebote
var ancho: float = 0.05
var estira: float = ESTIRA
var brillo_k: float = 1.0
var sigue: Node3D = null: set = _set_sigue  ## si se va, el emisor se cierra
var _sigue_puesto: bool = false
var al_paso: Callable = Callable()       ## (emisor, delta) cada paso, antes de mover: recoloca la piel, v_base...
var cerrado: bool = false
var nacidas: int = 0
var rebotes: int = 0
var _n: int = 0
var _t: float = 0.0
var _pos: PackedVector3Array = PackedVector3Array()
var _vel: PackedVector3Array = PackedVector3Array()
var _vida: PackedFloat32Array = PackedFloat32Array()     ## s que le quedan (≤ 0: muerta)
var _espera: PackedFloat32Array = PackedFloat32Array()   ## s hasta su (re)nacimiento
var _sem: PackedFloat32Array = PackedFloat32Array()
var _vivas: int = 0
var _cierre: float = -1.0                ## `cerrar_tras`: a los tantos s se cierra solo
var _mi: MultiMeshInstance3D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


# ====================================================================== interruptores ======================================================================

static func activa(clave: String) -> bool:
	return bool(capas.get(clave, false))


static func poner_todas(v: bool) -> void:
	for k in capas:
		capas[k] = v


static func de_serie() -> void:
	capas = DE_SERIE.duplicate()


static func hay_alguna() -> bool:
	for k in capas:
		if bool(capas[k]):
			return true
	return false


static func vivas_global() -> int:
	var k: int = 0
	for e in _registro:
		if is_instance_valid(e):
			k += (e as ChispasRepo)._vivas
	return k


static func emisores() -> int:
	return _registro.size()


# ====================================================================== el emisor ======================================================================

## Un emisor de `n` chispas de `paleta_` colgado de `padre` (en el árbol), con la piel ya puesta por quien lo llama. null si `padre` no vale.
static func crear(paleta_: int, padre: Node, n: int, q: Dictionary = {}) -> ChispasRepo:
	if padre == null or not padre.is_inside_tree():
		return null
	var e: ChispasRepo = ChispasRepo.new()
	e.name = "ChispasRepo"
	e.paleta = paleta_
	for k in q:
		e.set(k, q[k])
	e._montar(clampi(n, 1, MAX_POR_EMISOR))
	padre.add_child(e)
	return e


func poner_plano(punto: Vector3, normal: Vector3, radio_disco: float) -> void:
	piel = Piel.PLANO
	piel_c = punto
	piel_n = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	piel_r = maxf(radio_disco, 0.01)


func poner_esfera(centro: Vector3, radio: float) -> void:
	piel = Piel.ESFERA
	piel_c = centro
	piel_r = maxf(radio, 0.01)


func poner_capsula(a: Vector3, b: Vector3, radio: float) -> void:
	piel = Piel.CAPSULA
	piel_c = a
	piel_b = b
	piel_r = maxf(radio, 0.01)


func cerrar() -> void:
	cerrado = true
	emite = 0.0


func vivas() -> int:
	return _vivas


func multimesh() -> MultiMesh:
	return _mi.multimesh if _mi != null else null


func _set_sigue(v: Node3D) -> void:
	sigue = v
	_sigue_puesto = v != null


func _montar(n: int) -> void:
	_n = n
	_pos.resize(n)
	_vel.resize(n)
	_vida.resize(n)
	_espera.resize(n)
	_sem.resize(n)
	_rng.randomize()
	for i in n:
		_vida[i] = 0.0
		_espera[i] = float(i) / float(n) * escalon          # vidas escalonadas (repo: start.w = i / count · 2,3)
		_sem[i] = _rng.randf()
	_mi = SpriteToy.chispas_mm("Chispas", n, 1.3 if paleta == Paleta.MAGMA else 1.5)
	_mi.top_level = true
	_mi.transform = Transform3D.IDENTITY
	_mi.custom_aabb = AABB(Vector3.ONE * -2000.0, Vector3.ONE * 4000.0)       # va en coordenadas del mundo
	var m: ShaderMaterial = _mi.material_override as ShaderMaterial
	if paleta == Paleta.MAGMA:
		m.set_shader_parameter("tramo", Vector2(0.15, 0.55))                  # el tramo de las brasas de MagmaToy: rojo-naranja, sin amarillo
	else:
		m.set_shader_parameter("rampa", rampa_rayo())
		m.set_shader_parameter("tramo", Vector2(0.15, 1.0))
	m.set_shader_parameter("brillo", float(m.get_shader_parameter("brillo")) * brillo_k)
	add_child(_mi)


func _enter_tree() -> void:
	if not _registro.has(self):
		_registro.append(self)


func _exit_tree() -> void:
	_registro.erase(self)


## La rampa del rayo con los colores de RayoPaleta (de frío a caliente).
static func rampa_rayo() -> GradientTexture1D:
	if _rampa_rayo != null:
		return _rampa_rayo
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.55, 0.8, 1.0])
	g.colors = PackedColorArray([RayoPaleta.HALO_HONDO, RayoPaleta.HALO, RayoPaleta.HALO_BORDE, RayoPaleta.CUERPO, RayoPaleta.NUCLEO])
	_rampa_rayo = GradientTexture1D.new()
	_rampa_rayo.gradient = g
	_rampa_rayo.width = 64
	return _rampa_rayo


func _process(delta: float) -> void:
	avanzar(delta)


## Mueve todo `delta` s (las pruebas la llaman a mano).
func avanzar(delta: float) -> void:
	if _mi == null or delta <= 0.0:
		return
	_t += delta
	if _sigue_puesto and (not is_instance_valid(sigue) or not sigue.is_inside_tree()):         # (un objeto liberado compara igual a null: se mira con is_instance_valid)
		_sigue_puesto = false
		sigue = null
		al_paso = Callable()
		cerrar()
	if _cierre >= 0.0 and _t >= _cierre and not cerrado:
		cerrar()
	if al_paso.is_valid():
		al_paso.call(self, delta)
	var mm: MultiMesh = _mi.multimesh
	var naciendo: bool = not cerrado and (emite < 0.0 or _t <= emite + escalon)
	for i in _n:
		if _vida[i] <= 0.0:
			_espera[i] -= delta
			if naciendo and _espera[i] <= 0.0 and vivas_global() < MAX_VIVAS:
				_nacer(i)
			else:
				SpriteToy.poner_chispa(mm, i, Vector3.ZERO, Vector3.UP, 0.0, 0.0, 0.0, 0.0, false)
				continue
		_vida[i] -= delta
		if _vida[i] <= 0.0:
			_vivas -= 1
			_espera[i] = _rng.randf_range(0.0, 0.08)
			SpriteToy.poner_chispa(mm, i, Vector3.ZERO, Vector3.UP, 0.0, 0.0, 0.0, 0.0, false)
			continue
		_mover(i, delta)
		_dibujar(mm, i)
	if cerrado and _vivas <= 0:
		queue_free()


func _azar3() -> Vector3:
	return Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5) * 2.0


## Un punto de la piel y su normal hacia fuera.
func _punto_piel() -> Array:
	match piel:
		Piel.ESFERA:
			var d: Vector3 = _azar3()
			d = d.normalized() if d.length() > 0.05 else Vector3.UP
			return [piel_c + d * piel_r, d]
		Piel.CAPSULA:
			var eje: Vector3 = piel_b - piel_c
			var u: Vector3 = eje.normalized() if eje.length() > 0.001 else Vector3.UP
			var s: float = _rng.randf()
			var d2: Vector3 = _azar3()
			var nn: Vector3 = d2 - u * d2.dot(u)
			nn = nn.normalized() if nn.length() > 0.05 else u.cross(Vector3.RIGHT if absf(u.x) < 0.9 else Vector3.FORWARD).normalized()
			return [piel_c + eje * s + nn * piel_r, nn]
	# PLANO: un disco de radio piel_r en el plano
	var t1: Vector3 = piel_n.cross(Vector3.RIGHT if absf(piel_n.x) < 0.9 else Vector3.FORWARD).normalized()
	var t2: Vector3 = piel_n.cross(t1)
	var a: float = _rng.randf() * TAU
	var rr: float = piel_r * sqrt(_rng.randf())
	return [piel_c + (t1 * cos(a) + t2 * sin(a)) * rr, piel_n]


func _nacer(i: int) -> void:
	var pn: Array = _punto_piel()
	var n: Vector3 = pn[1]
	var rnd: Vector3 = _azar3()
	var frente: Vector3 = (rnd + n * FRENTE_NORMAL).normalized()
	_pos[i] = (pn[0] as Vector3) + n * SEPARA_PIEL
	_vel[i] = frente * v_frente + rnd * v_azar + empuje + v_base * k_base
	_vida[i] = _rng.randf_range(vida_min, vida_max)
	_vivas += 1
	nacidas += 1


## Distancia con signo a la piel (negativa dentro) y su normal.
func _sdf(p: Vector3) -> Array:
	match piel:
		Piel.ESFERA:
			var o: Vector3 = p - piel_c
			var d: float = o.length()
			return [d - piel_r, o / d if d > 0.0001 else Vector3.UP]
		Piel.CAPSULA:
			var eje: Vector3 = piel_b - piel_c
			var l2: float = maxf(eje.length_squared(), 0.000001)
			var s: float = clampf((p - piel_c).dot(eje) / l2, 0.0, 1.0)
			var o2: Vector3 = p - (piel_c + eje * s)
			var d2: float = o2.length()
			return [d2 - piel_r, o2 / d2 if d2 > 0.0001 else Vector3.UP]
	return [(p - piel_c).dot(piel_n), piel_n]


func _mover(i: int, dt: float) -> void:
	var p: Vector3 = _pos[i]
	var v: Vector3 = _vel[i]
	v = v.lerp(aire, minf(INERCIA * dt, 1.0))
	v.y -= GRAVEDAD * dt
	p += v * dt
	if p.y < y_suelo + 0.04:
		p.y = y_suelo + 0.04
		if v.y < 0.0:
			v.y = absf(v.y) * REBOTE
			rebotes += 1
	if choca_piel:
		var sd: Array = _sdf(p)
		var d: float = sd[0]
		if d < 0.02:
			var nn: Vector3 = sd[1]
			p += nn * (0.02 - d)
			var vn: float = v.dot(nn)
			if vn < 0.0:
				v -= nn * vn * (1.0 + REBOTE)
				rebotes += 1
	_pos[i] = p
	_vel[i] = v


func _dibujar(mm: MultiMesh, i: int) -> void:
	var calor: float = clampf(_vida[i] / CALOR_VIDA, 0.0, 1.0)
	var alfa: float = clampf(_vida[i] / 0.25, 0.0, 1.0)
	var lw: Vector2 = trazo(i)
	SpriteToy.poner_chispa(mm, i, _pos[i], _vel[i], lw.x, lw.y, calor * calor * (0.85 if paleta == Paleta.MAGMA else 1.0), alfa * 0.95, false)


## (largo, ancho) del trazo de la chispa i (m): estirada con la velocidad (repo: cola = p − v · 0,028 s); despacio, un punto (el largo nunca baja del ancho).
func trazo(i: int) -> Vector2:
	var calor: float = clampf(_vida[i] / CALOR_VIDA, 0.0, 1.0)
	var w: float = ancho * (0.7 + 0.6 * _sem[i]) * (0.6 + 0.4 * calor)
	return Vector2(maxf(_vel[i].length() * estira, w), w)


## Medición para las pruebas: una entrada por chispa viva {pos, vel, vida, calor}.
func estados() -> Array:
	var r: Array = []
	for i in _n:
		if _vida[i] > 0.0:
			var c: float = clampf(_vida[i] / CALOR_VIDA, 0.0, 1.0)
			r.append({"pos": _pos[i], "vel": _vel[i], "vida": _vida[i], "calor": c * c})
	return r


# ====================================================================== enganches (una línea en cada efecto; sin su interruptor no hacen nada) ======================================================================

static func _escena_de(nodo: Node) -> Node:
	return nodo.get_parent() if nodo.get_parent() != null else nodo


## ImpactoRayoToy: chispas que nacen en la superficie del choque (o en la bola que revienta, FIN), saltan, caen y rebotan.
static func enganchar_impacto_rayo(imp: Node3D) -> ChispasRepo:
	if not activa("rayo_impacto") or not imp.is_inside_tree() or imp.has_meta(&"chispas_repo"):
		return null
	imp.set_meta(&"chispas_repo", true)
	var r: float = float(imp.get("radio"))
	var k: float = clampf(r / 0.4, 0.5, 2.5)
	var var_: int = int(imp.get("variante"))
	var n_: Vector3 = (imp.get("normal") as Vector3).normalized()
	var pos: Vector3 = imp.global_position
	var suelo: bool = n_.dot(Vector3.UP) >= 0.7
	var cuantas: int = [36, 24, 16, 56][clampi(var_, 0, 3)]
	var e: ChispasRepo = crear(Paleta.RAYO, _escena_de(imp), cuantas, {"escalon": 0.22, "emite": 0.12 if var_ != 3 else 0.45, "vida_min": 0.35, "vida_max": 1.2, "ancho": 0.06 * sqrt(k),
		"v_frente": 1.6 * sqrt(k), "v_azar": 1.4 * sqrt(k), "y_suelo": pos.y if suelo else pos.y - float(imp.get("altura_suelo"))})
	if e == null:
		return null
	if var_ == 1:                                       # FIN: revienta en el aire, de la bola
		e.poner_esfera(pos, r * 0.6)
		e.choca_piel = false
	else:
		e.poner_plano(pos, n_, r * (2.0 if var_ == 3 else 0.5))
	e.cerrar_tras(e.escalon + e.emite)
	return e


## RayoToy PILAR: desde que la columna toca el suelo, chispas en su pie mientras vive (se calla al cortarse).
static func enganchar_pilar_rayo(toy: Node3D) -> ChispasRepo:
	if not activa("rayo_pilar") or not toy.is_inside_tree():
		return null
	var r: float = maxf(float(toy.get("semieje_x")), float(toy.get("semieje_z")))
	var e: ChispasRepo = crear(Paleta.RAYO, _escena_de(toy), 40, {"escalon": 0.5, "emite": -1.0, "vida_min": 0.35, "vida_max": 1.1, "ancho": 0.05, "v_frente": 1.8, "v_azar": 1.3,
		"y_suelo": toy.global_position.y, "choca_piel": false})
	if e == null:
		return null
	e.poner_plano(toy.global_position, Vector3.UP, r * 1.1)
	e.sigue = toy
	e.al_paso = func(em: ChispasRepo, _dt: float) -> void:
		if is_instance_valid(toy) and float(toy.get("corte")) > 0.05:
			em.cerrar()
		elif is_instance_valid(toy):
			em.piel_c = toy.global_position
			em.y_suelo = toy.global_position.y
	return e


## Estela de la bola en vuelo (rayo o magma): nacen en la piel de la bola con su velocidad (× k_base), el aire quieto las frena (inercia) y se quedan atrás, caen y rebotan.
## `vuela` (Callable → bool) dice si la bola sigue volando; cuando no, el emisor se cierra.
static func enganchar_estela(toy: Node3D, clave: String, paleta_: int, radio: float, suelo_y: float, vuela: Callable) -> ChispasRepo:
	if not activa(clave) or not toy.is_inside_tree():
		return null
	var magma: bool = paleta_ == Paleta.MAGMA
	var e: ChispasRepo = crear(paleta_, _escena_de(toy), 40 if magma else 32, {"escalon": 0.3, "emite": -1.0, "vida_min": 0.4 if magma else 0.25, "vida_max": 1.4 if magma else 0.8,
		"ancho": (0.065 if magma else 0.05) * clampf(radio / 0.4, 0.6, 2.0), "v_frente": 0.5, "v_azar": 0.6 if magma else 0.9, "k_base": 0.55, "choca_piel": false, "y_suelo": suelo_y,
		"estira": ESTIRA * (0.7 if magma else 1.0)})
	if e == null:
		return null
	e.poner_esfera(toy.global_position, radio * 0.8)
	e.sigue = toy
	var ult: Array = [toy.global_position]
	e.al_paso = func(em: ChispasRepo, dt: float) -> void:
		if not is_instance_valid(toy):
			return
		var p: Vector3 = toy.global_position
		var vb: Vector3 = (p - (ult[0] as Vector3)) / maxf(dt, 0.0001)
		ult[0] = p
		if vb.length() < 40.0:
			em.v_base = vb
		em.piel_c = p
		if not bool(vuela.call()):
			em.cerrar()
	return e


## ImpactoMagmaToy: brasas que salen de la piel del cráter (o de la roca que cae, FIN), botan 0,35 y se enfrían por el tramo bajo de la rampa.
static func enganchar_impacto_magma(imp: Node3D) -> ChispasRepo:
	if not activa("magma_impacto") or not imp.is_inside_tree() or imp.has_meta(&"chispas_repo"):
		return null
	imp.set_meta(&"chispas_repo", true)
	var r: float = float(imp.get("radio"))
	var k: float = clampf(r / 0.4, 0.5, 2.5)
	var var_: int = int(imp.get("variante"))
	var n_: Vector3 = (imp.get("normal") as Vector3).normalized()
	var pos: Vector3 = imp.global_position
	var suelo: bool = n_.dot(Vector3.UP) >= 0.7
	var cuantas: int = [40, 18, 14, 56][clampi(var_, 0, 3)]
	var e: ChispasRepo = crear(Paleta.MAGMA, _escena_de(imp), cuantas, {"escalon": 0.4, "emite": 0.35 if var_ != 3 else 0.7, "vida_min": 0.6, "vida_max": 1.9, "ancho": 0.075 * sqrt(k),
		"v_frente": 1.5 * sqrt(k), "v_azar": 1.1 * sqrt(k), "estira": ESTIRA * 0.7, "y_suelo": pos.y if suelo else pos.y - float(imp.get("altura_suelo"))})
	if e == null:
		return null
	if var_ == 1:
		e.poner_esfera(pos, r * 0.5)
		e.choca_piel = false
	else:
		e.poner_plano(pos, n_, r * (1.6 if var_ == 3 else 0.7))
	e.cerrar_tras(e.escalon + e.emite)
	return e


## EstadoRayoToy: chispitas que saltan de la piel del cuerpo (la cápsula real si la tiene) o del agua (SUPERFICIE), caen y rebotan en el suelo o en el agua. Sigue al estado.
static func enganchar_estado(est: Node3D) -> ChispasRepo:
	if not activa("electrificado") or not est.is_inside_tree() or not est.has_method("capsula_mundo"):
		return null
	var entidad: bool = int(est.get("modo")) == 0
	var e: ChispasRepo = crear(Paleta.RAYO, _escena_de(est) if not entidad else (_escena_de(est.get_parent()) if est.get_parent() != null else est), 24 if entidad else 18,
		{"escalon": 0.6, "emite": -1.0, "vida_min": 0.25, "vida_max": 0.9, "ancho": 0.045, "v_frente": 0.9, "v_azar": 0.8, "y_suelo": est.global_position.y})
	if e == null:
		return null
	e.sigue = est
	e.al_paso = func(em: ChispasRepo, _dt: float) -> void:
		if not is_instance_valid(est):
			return
		if bool(est.call("esta_apagando")):
			em.cerrar()
			return
		if entidad:
			var c: Array = est.call("capsula_mundo")
			em.poner_capsula(c[0], c[1], c[2])
			em.y_suelo = est.global_position.y
		else:
			em.poner_plano(est.global_position, Vector3.UP, minf(float(est.get("ancho_x")), float(est.get("ancho_z"))) * 0.45)
			em.y_suelo = est.global_position.y
	e.al_paso.call(e, 0.0)
	return e


## Deja de nacer a los `s` s (las ya nacidas acaban su vida y el nodo se libera).
func cerrar_tras(s: float) -> void:
	emite = maxf(s - escalon, 0.0)
	_cierre = s
