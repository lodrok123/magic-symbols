class_name ImpactoAguaToy
extends Node3D

## SALPICADURA DEL AGUA «TOY» (3/11/2026, fase 1 de docs/PROPUESTA_AGUA_TOY_2026-11-02.md; el equivalente de ImpactoFuegoToy). Misma API: `crear(variante, normal, radio)`, `tiempo()`, `duracion()`,
## `avanzar_a(t)`, `lanzar()` / `morir()` (contrato de EfectoVfx3D). Es AGUA: mezcla normal, sin luz, sin destello, sin aditivo. Todo se libera solo.
## Lo que lleva (GOLPE, contra una pared o el suelo; `normal` = normal de la superficie hacia fuera):
##   · CORONA DE GOTAS: un MultiMesh movido por la CPU (agua_gota.gdshader) con gotas que salen del punto de impacto HACIA FUERA, en el hemisferio de la normal (más abiertas que altas: corona baja),
##     y que CAEN con la gravedad real (9,8 m/s², con algo de rozamiento); desaparecen al volver a la superficie. Unas pocas burbujas que suben despacio. No son GPUParticles3D: `gotas_estado(t)` las mide.
##   · LÁMINA DE SALPICADURA: T_VFX_Ex1d recoloreada con la rampa de agua, en billboard (nunca tumbada plana), breve (~0,2 s): el primer instante.
##   · ANILLO / CHARCO DE ONDAS: un quad sobre la superficie con el shader agua_onda (charco con cáusticas + 2-3 anillos con borde de ruido) que se expande y se desvanece.
##   · VAHO: unas bocanadas de whitePuff (Kenney, CC0) teñidas de azul muy pálido que suben y se desvanecen.
## Variantes: GOLPE (todo), FIN (el hechizo se agota en el aire: la bola se deshace en gotas que caen, sin lámina ni anillo), REBOTE (salpicadura pequeña, la bola sigue).
## TAMAÑO: `radio` = radio de la bola que choca (m): la corona, la lámina y el anillo siguen a ese radio (referencia 0,4).

const SpriteToy = preload("res://presentacion/vfx/toy/sprite_toy.gd")
const AguaGotas = preload("res://presentacion/vfx/toy/agua_gotas.gd")
const AguaMallas = preload("res://presentacion/vfx/toy/agua_mallas.gd")

## AREA (fase 3): EXPLOSIÓN DE ÁREA sobre el suelo, `radio` = radio del área en m (referencia 1,8 m). Cuatro tiempos (ref_agua_bola_ola_pilar_a/b, 6,8 s / 8,8 s / 10,7 s / 12,7 s):
##   (a) 0 - 0,3 s     estallido blanco-celeste que sube: lámina T_VFX_Ex1d recoloreada + bocanadas de espuma + gotas que salen hacia arriba
##   (b) 0,1 - 0,55 s  de CHARCOS repartidos por el área (uno central y cuatro alrededor) suben columnas de lenguas (agua_lamina.gdshader, T_wavesKI96 en láminas Y-billboard), cada columna con su retraso
##   (c) 0,45 - 0,95 s las lenguas se CURVAN HACIA FUERA y se inclinan como cuernos; de 0,8 a 1,45 s caen y se acortan
##   (d) 0,6 - 1,7 s   charco grande con anillos de ondas (agua_onda.gdshader) que se expande y se desvanece; gotas que salen hacia fuera (0,78 - 1,0 s) y caen
## Solo suelo (la normal siempre es arriba). Sin luces, sin aditivo; ≤ 90 instancias de MultiMesh (gotas + lenguas + espuma) y 8 mallas (4 con material de agua propio).
enum Variante { GOLPE, FIN, REBOTE, AREA }

## Por variante: nº de gotas, de burbujas, tamaño de la lámina (× radio), radio del anillo (× radio), nº de anillos, nº de bocanadas de vaho, duración (s).
const PARAMS: Dictionary = {
	Variante.GOLPE: {"gotas": 36, "burbujas": 4, "lamina": 4.8, "anillo": 2.9, "anillos": 3.0, "vaho": 3, "espuma": 5, "dur": 0.8},
	Variante.FIN: {"gotas": 24, "burbujas": 5, "lamina": 0.0, "anillo": 0.0, "anillos": 0.0, "vaho": 2, "espuma": 0, "dur": 0.95},
	Variante.REBOTE: {"gotas": 15, "burbujas": 1, "lamina": 1.7, "anillo": 1.45, "anillos": 2.0, "vaho": 0, "espuma": 2, "dur": 0.55},
	Variante.AREA: {"gotas": 62, "burbujas": 4, "lamina": 1.9, "anillo": 2.72, "anillos": 3.0, "vaho": 0, "espuma": 0, "dur": 1.7}}
const RADIO_AREA_REF: float = 1.8
const N_COLUMNAS_AREA: int = 5
const N_ESPUMA_AREA: int = 8 + 3 * 5
const T_ESTALLIDO_AREA: float = 0.2
## Una superficie cuenta como SUELO (los anillos de ondas solo van ahí) si su normal apunta hacia arriba (cos ≥ 0,7 ≈ 45°); si no, es PARED (o techo): gotas que caen, lámina, mancha húmeda y, si llegan, un charquito en el suelo.
const COS_SUELO: float = 0.7
const T_ESPUMA: float = 0.45              ## s que dura cada bocanada de espuma de la corona
const T_CHARCO: float = 0.34              ## s a los que aparece el charquito del suelo tras un golpe en una pared
const GRAVEDAD: float = 9.8
const ROZAMIENTO: float = 0.6
const COS_ABERTURA: float = 0.18          ## cos del ángulo máximo respecto a la normal (≈ 80°): la corona sale abierta; todas las gotas quedan en el hemisferio de la normal
const COS_MIN_CORONA: float = 0.2
const T_LAMINA: float = 0.2               ## s que dura la lámina de salpicadura

@export var variante: Variante = Variante.GOLPE
@export var normal: Vector3 = Vector3.UP
@export_range(0.05, 4.0, 0.01, "or_greater") var radio: float = 0.4
## Altura (m) bajo el punto de la FIN a la que se supone el suelo: las gotas que caen hasta ahí desaparecen.
@export var altura_suelo: float = 0.7

var _t: float = -1.0
var _p: Dictionary = {}
var _dur: float = 0.8
var _plano: Node3D = null
var _lamina: MeshInstance3D = null
var _anillo: MeshInstance3D = null
var _vahos: Array = []
var _espumas: Array = []
var _mancha: MeshInstance3D = null        ## mancha húmeda en la pared (solo paredes y techos)
var _charco: MeshInstance3D = null        ## charquito en el suelo bajo una pared (solo paredes, GOLPE)
var _mm_gotas: MultiMeshInstance3D = null
var _gotas_c: Array = []                  ## [{p0, v0, vida, tam, burbuja, g, c, retraso, clar}] en el espacio local del nodo
var _tr_gotas: Array = []                 ## última transformación puesta a cada gota (para las pruebas: en headless el MultiMesh no guarda datos)
var _giro0: float = 0.0
var _fin_t: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _area_lam: MultiMeshInstance3D = null  ## AREA: lenguas de las columnas (láminas Y-billboard)
var _area_esp: MultiMeshInstance3D = null  ## AREA: bocanadas de espuma del estallido
var _area_fra: MultiMeshInstance3D = null  ## AREA: franjas de espuma en la base de las columnas (fase 4: ya no son bolas)
var _area_cols: Array = []                 ## AREA: [{centro, t0, charco}] las 5 columnas
var _area_pool: MeshInstance3D = null      ## AREA: charco grande con anillos
var _area_lenguas: Array = []              ## AREA: la lista de lenguas (AguaMallas.lengua)
var _area_esp_datos: Array = []            ## AREA (pruebas): [{pos, tam, alfa}] de la última espuma puesta


static func crear(var_: Variante, normal_: Vector3, radio_: float) -> ImpactoAguaToy:
	var i: ImpactoAguaToy = ImpactoAguaToy.new()
	i.configurar(var_, normal_, radio_)
	return i


## Se llama ANTES de añadirlo al árbol. La FIN siempre sube (normal arriba).
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


## ¿Es suelo (normal hacia arriba)? Solo ahí hay anillos de ondas.
func es_suelo() -> bool:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	return variante != Variante.FIN and n.dot(Vector3.UP) >= COS_SUELO


## ¿Es pared o techo (superficie no horizontal hacia arriba)?
func es_pared() -> bool:
	return variante != Variante.FIN and not es_suelo()


func _base_normal() -> Basis:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	if n.dot(Vector3.UP) < -0.999:
		return Basis(Quaternion(Vector3.RIGHT, PI))
	return Basis(Quaternion(Vector3.UP, n))


# ------------------------------------------------------------------ construcción ------------------------------------------------------------------

func _construir() -> void:
	FuegoToy._rampas()                    # SpriteToy.crear la necesita (la rampa se sustituye por la del agua)
	if variante == Variante.AREA:
		_construir_area()
		return
	var r: float = radio
	_plano = Node3D.new()
	_plano.name = "Plano"
	_plano.basis = _base_normal()
	add_child(_plano)
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	# lámina de salpicadura: Ex1d en billboard, un poco delante de la superficie
	if float(_p["lamina"]) > 0.0:
		_lamina = SpriteToy.crear("Lamina", SpriteToy.T_ESTALLIDO, SpriteToy.Modo.MEZCLA, false,
			{"recorte": Vector2(0.16, 0.7), "luminancia": Vector2(0.15, 0.95), "tramo": Vector2(0.3, 1.0), "brillo": 1.0, "giro": _giro0, "vida": 0.0}, 3)
		SpriteToy.mat(_lamina).set_shader_parameter("rampa", AguaMallas.rampa_sprites())
		_lamina.position = n * 0.3 * r
		_lamina.set_meta("tam", float(_p["lamina"]) * r)
		_lamina.scale = Vector3.ONE * 0.001
		add_child(_lamina)
	# anillo / charco de ondas: SOLO en suelo (en una pared los anillos pintados en vertical no tienen sentido)
	if float(_p["anillo"]) > 0.0 and es_suelo():
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2.ONE
		q.orientation = PlaneMesh.FACE_Y
		_anillo = MeshInstance3D.new()
		_anillo.name = "Anillo"
		_anillo.mesh = q
		_anillo.material_override = AguaMallas.material(AguaMallas.SH_ONDA, {"anillos": float(_p["anillos"]), "charco": 0.5, "u": 0.0, "vida": 1.0, "semilla": randf(), "se_va": 0.5,
			"fade_canto": 0.3, "suave_prof": 0.0}, 0)
		_anillo.position = Vector3(0, 0.012 + 0.01 * r, 0)
		_anillo.scale = Vector3(2.0 * float(_p["anillo"]) * r, 1.0, 2.0 * float(_p["anillo"]) * r)
		_anillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_plano.add_child(_anillo)
	# pared: mancha húmeda sutil que se desvanece y, bajo ella, un charquito donde caen las gotas
	if es_pared():
		var qm: QuadMesh = QuadMesh.new()
		qm.size = Vector2.ONE
		qm.orientation = PlaneMesh.FACE_Y
		_mancha = MeshInstance3D.new()
		_mancha.name = "Mancha"
		_mancha.mesh = qm
		var d_loc: Vector3 = _plano.basis.inverse() * Vector3.DOWN
		_mancha.material_override = AguaMallas.material(AguaMallas.SH_MANCHA, {"u": 0.0, "abajo": Vector2(d_loc.x, d_loc.z).normalized() if Vector2(d_loc.x, d_loc.z).length() > 0.01 else Vector2(0, 1),
			"semilla": randf(), "suave_prof": 0.0, "opacidad": 0.42 if variante == Variante.GOLPE else 0.3}, 0)
		_mancha.position = Vector3(0, 0.008 + 0.006 * r, 0)
		var lado_m: float = (2.0 if variante == Variante.GOLPE else 1.3) * r * 1.5
		_mancha.scale = Vector3(lado_m, 1.0, lado_m)
		_mancha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_plano.add_child(_mancha)
		if variante == Variante.GOLPE and absf(n.y) < COS_SUELO:
			var qc: QuadMesh = QuadMesh.new()
			qc.size = Vector2.ONE
			qc.orientation = PlaneMesh.FACE_Y
			_charco = MeshInstance3D.new()
			_charco.name = "Charquito"
			_charco.mesh = qc
			_charco.material_override = AguaMallas.material(AguaMallas.SH_ONDA, {"anillos": 1.0, "charco": 0.62, "u": 0.0, "vida": 1.0, "semilla": randf(), "se_va": 0.6, "fade_canto": 0.3, "suave_prof": 0.0,
				"grosor": 0.06, "radio_ini": 0.3}, 0)
			var hor: Vector3 = Vector3(n.x, 0.0, n.z)
			hor = hor.normalized() * r * 0.5 if hor.length() > 0.01 else Vector3.ZERO
			_charco.position = hor + Vector3(0, -altura_suelo + 0.012, 0)
			var lado_c: float = 1.6 * r
			_charco.scale = Vector3(lado_c, 1.0, lado_c)
			_charco.visible = false
			_charco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_charco)
	# espuma blanca en la corona: bocanadas pequeñas pegadas a la superficie
	for i in int(_p["espuma"]):
		var pf: MeshInstance3D = AguaMallas.puff("Espuma%d" % i, Vector2(0.66, 0.97))
		pf.set_meta("ang", TAU * (float(i) + randf_range(-0.3, 0.3)) / float(maxi(int(_p["espuma"]), 1)))
		pf.set_meta("rad", randf_range(0.35, 0.95))
		add_child(pf)
		_espumas.append(pf)
	# vaho
	for i in int(_p["vaho"]):
		var mv: MeshInstance3D = _crear_vaho("Vaho%d" % i)
		var ang: float = TAU * (float(i) / float(maxi(int(_p["vaho"]), 1))) + _giro0
		mv.set_meta("ang", ang)
		mv.set_meta("fase", float(i) * 0.04)
		add_child(mv)
		_vahos.append(mv)
	_montar_gotas()
	_poner_tiempo_cero()


func _crear_vaho(nombre: String) -> MeshInstance3D:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(AguaMallas.SH_SPRITE)
	m.render_priority = 1
	m.set_shader_parameter("tex", load(AguaMallas.PUFF))
	m.set_shader_parameter("rampa", AguaMallas.rampa_sprites())
	m.set_shader_parameter("usar_alfa", 1.0)
	m.set_shader_parameter("recorte", Vector2(0.0, 0.85))
	m.set_shader_parameter("luminancia", Vector2(0.0, 1.0))
	m.set_shader_parameter("tramo", Vector2(0.4, 0.78))
	m.set_shader_parameter("billboard", 1)
	m.set_shader_parameter("giro", randf() * TAU)
	m.set_shader_parameter("vida", 0.0)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * 0.001
	return mi


func _poner_tiempo_cero() -> void:
	_actualizar_gotas(0.0)


## Genera las gotas y las burbujas. Salpicadura (GOLPE, REBOTE): salen del punto de impacto dentro de un cono de ~80° alrededor de la normal, sobre todo abiertas (corona baja). FIN: nacen repartidas
## por el volumen de la bola, casi sin velocidad, y caen.
func _montar_gotas() -> void:
	if variante == Variante.AREA:
		_montar_gotas_area()
		return
	var k: float = radio / 0.4
	var kc: float = clampf(k, 0.5, 3.0)
	var n_g: int = clampi(int(round(float(_p["gotas"]) * clampf(sqrt(kc), 0.7, 1.6))), 4, 56)
	var n_b: int = int(_p["burbujas"])
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	var t1: Vector3 = n.cross(Vector3.UP)
	if t1.length() < 0.01:
		t1 = n.cross(Vector3.RIGHT)
	t1 = t1.normalized()
	var t2: Vector3 = n.cross(t1).normalized()
	_gotas_c.clear()
	var es_fin: bool = variante == Variante.FIN
	for i in n_g + n_b:
		var burbuja: bool = i >= n_g
		var fi: float = _rng.randf() * TAU
		var tang: Vector3 = t1 * cos(fi) + t2 * sin(fi)
		var d: Dictionary = {}
		if es_fin:
			var dir: Vector3 = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.6, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()
			var dentro: Vector3 = dir * radio * 0.7 * pow(_rng.randf(), 0.6)
			d = {"p0": dentro, "v0": dir * (_rng.randf_range(0.35, 1.25) * pow(kc, 0.5)) if not burbuja else dir * 0.3, "vida": _rng.randf_range(0.5, 0.85) if not burbuja else _rng.randf_range(0.7, 0.95),
				"tam": (_rng.randf_range(0.05, 0.1) * pow(kc, 0.6)) if not burbuja else _rng.randf_range(0.04, 0.06) * pow(kc, 0.5)}
		else:
			var cos_t: float = lerpf(COS_ABERTURA, 0.9, pow(_rng.randf(), 1.5)) if not burbuja else lerpf(0.5, 1.0, _rng.randf())
			var sin_t: float = sqrt(maxf(1.0 - cos_t * cos_t, 0.0))
			var dir2: Vector3 = n * cos_t + tang * sin_t
			var vel: float = (_rng.randf_range(1.9, 4.4) * pow(kc, 0.6)) if not burbuja else (_rng.randf_range(0.4, 0.9) * pow(kc, 0.5))
			d = {"p0": tang * radio * 0.12 + n * (0.03 * kc), "v0": dir2 * vel, "vida": _rng.randf_range(0.34, 0.6) if not burbuja else _rng.randf_range(0.5, 0.7),
				"tam": (_rng.randf_range(0.065, 0.135) * pow(kc, 0.6)) if not burbuja else _rng.randf_range(0.04, 0.065) * pow(kc, 0.5)}
		d["burbuja"] = burbuja
		d["g"] = 1.0 if not burbuja else -0.12
		d["c"] = ROZAMIENTO if not burbuja else 2.5
		d["retraso"] = _rng.randf_range(0.0, 0.03) if not es_fin else _rng.randf_range(0.0, 0.08)
		d["clar"] = _rng.randf_range(0.2, 0.9) if _rng.randf() > 0.4 else 1.0           # una parte de las gotas, casi blancas (espuma)
		_gotas_c.append(d)
	_mm_gotas = AguaGotas.crear_mm("Gotas", _gotas_c.size())
	add_child(_mm_gotas)


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


func _gravedad_local() -> Vector3:
	if is_inside_tree():
		return (global_transform.basis.inverse() * Vector3.DOWN).normalized()
	return Vector3.DOWN


## Posición (local), velocidad (local) y edad normalizada de la gota `d` al instante `t`. GOLPE y REBOTE nunca van por debajo de la superficie.
func _estado_gota(d: Dictionary, t: float, g_local: Vector3) -> Dictionary:
	var ta: float = maxf(t - float(d["retraso"]), 0.0)
	var c: float = float(d["c"])
	var v0: Vector3 = d["v0"]
	var gg: Vector3 = g_local * GRAVEDAD * float(d["g"])
	var p: Vector3 = (d["p0"] as Vector3) + v0 * ((1.0 - exp(-c * ta)) / c) + 0.5 * gg * ta * ta
	var v: Vector3 = v0 * exp(-c * ta) + gg * ta
	return {"pos": p, "vel": v, "u": ta / float(d["vida"]), "ta": ta}


func _altura(p: Vector3) -> float:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	return p.dot(n)


## ¿Está la gota por debajo de la superficie (GOLPE, REBOTE) o del suelo supuesto (FIN)?
func _hundida(p: Vector3) -> bool:
	if variante == Variante.FIN:
		return p.y < -altura_suelo
	if _altura(p) < -0.005:
		return true
	# contra una pared o un techo, las gotas que caen hasta el suelo (supuesto a `altura_suelo` bajo el punto de impacto) desaparecen allí
	if es_pared():
		var yw: float = (global_transform * p).y if is_inside_tree() else p.y
		var y0: float = global_position.y if is_inside_tree() else 0.0
		return yw < y0 - altura_suelo
	return false


func _actualizar_gotas(t: float) -> void:
	if _mm_gotas == null:
		return
	var g: Vector3 = _gravedad_local()
	var mm: MultiMesh = _mm_gotas.multimesh
	_tr_gotas.resize(_gotas_c.size())
	for i in _gotas_c.size():
		var d: Dictionary = _gotas_c[i]
		var e: Dictionary = _estado_gota(d, t, g)
		var u: float = float(e["u"])
		var burbuja: bool = bool(d["burbuja"])
		if u >= 1.0 or t <= float(d["retraso"]) or _hundida(e["pos"]):
			_tr_gotas[i] = AguaGotas.poner(mm, i, Vector3.ZERO, Vector3.UP, 0.0, 0.0, 0.0, 0.0, false)
			continue
		var v: Vector3 = e["vel"]
		var alfa: float = smoothstep(0.0, 0.05, u) * (1.0 - smoothstep(0.62, 1.0, u)) * (0.9 if not burbuja else 0.8)
		var tam: float = float(d["tam"]) * (1.0 - 0.3 * u * u)
		var largo: float = tam * clampf(1.0 + 0.22 * v.length(), 1.0, 2.4)
		_tr_gotas[i] = AguaGotas.poner(mm, i, e["pos"], v.normalized() if v.length() > 0.01 else Vector3.DOWN, largo, tam, float(d["clar"]), alfa, burbuja)


## Medición para las pruebas: una entrada por gota, con su posición y dirección en MUNDO, la distancia al punto de impacto, la altura sobre la superficie (a lo largo de la normal), su velocidad vertical
## en mundo y si sigue viva en `t`.
func gotas_estado(t: float) -> Array:
	var res: Array = []
	var g: Vector3 = _gravedad_local()
	for d in _gotas_c:
		var e: Dictionary = _estado_gota(d, t, g)
		var p: Vector3 = e["pos"]
		var v: Vector3 = e["vel"]
		var vm: Vector3 = global_transform.basis * v
		res.append({"pos": global_transform * p, "dir": vm.normalized(), "dist": p.length(), "altura": _altura(p), "vy": vm.y,
			"vivo": float(e["u"]) < 1.0 and t > float(d["retraso"]) and not _hundida(p), "burbuja": bool(d["burbuja"]), "vida": float(d["vida"])})
	return res


## Transformación (local) con la que se dibuja la gota `i` en el último `avanzar_a`.
func transformada_gota(i: int) -> Transform3D:
	return _tr_gotas[i] if i < _tr_gotas.size() else Transform3D.IDENTITY


## Gotas y burbujas generadas: [n_gotas, n_burbujas].
func recuento_gotas() -> Array:
	var b: int = 0
	for d in _gotas_c:
		if bool(d["burbuja"]):
			b += 1
	return [_gotas_c.size() - b, b]


static func _sal(u: float) -> float:
	return 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 3.0)


## Pone la animación en el instante `t` (s). `_process` la llama cada fotograma; las pruebas y las capturas pueden llamarla a mano.
func avanzar_a(t: float) -> void:
	if _p.is_empty() or _plano == null:
		return
	var dur: float = _dur
	if variante == Variante.AREA:
		_avanzar_area(t)
		_actualizar_gotas(t)
		return
	# lámina de salpicadura: aparece en el primer fotograma, se abre rápido y se va en ~0,2 s
	if _lamina != null:
		var u: float = clampf(t / T_LAMINA, 0.0, 1.0)
		var d: float = float(_lamina.get_meta("tam", 1.0))
		var s: float = d * lerpf(0.5, 1.12, _sal(u))
		_lamina.scale = Vector3(s, s, 1.0)
		SpriteToy.mat(_lamina).set_shader_parameter("vida", clampf(0.92 * (1.0 - smoothstep(0.25, 1.0, u)) * smoothstep(0.0, 0.012, t), 0.0, 1.0))
	# anillo / charco: u = edad normalizada
	if _anillo != null:
		var ua: float = clampf(t / dur, 0.0, 1.0)
		(_anillo.material_override as ShaderMaterial).set_shader_parameter("u", ua)
	# mancha húmeda de la pared: se extiende y se desvanece (u = edad normalizada)
	if _mancha != null:
		(_mancha.material_override as ShaderMaterial).set_shader_parameter("u", clampf(t / dur, 0.0, 1.0))
	# charquito bajo la pared: aparece cuando llegan las gotas y se desvanece
	if _charco != null:
		var tc: float = t - T_CHARCO
		_charco.visible = tc >= 0.0
		if tc >= 0.0:
			(_charco.material_override as ShaderMaterial).set_shader_parameter("u", clampf(tc / maxf(dur + 0.25 - T_CHARCO, 0.1), 0.0, 1.0))
	# espuma blanca de la corona: bocanadas bajas que se abren y se van pronto
	for pf in _espumas:
		var ue: float = clampf((t - 0.01) / T_ESPUMA, 0.0, 1.0)
		var ang_e: float = float(pf.get_meta("ang", 0.0))
		var n_e: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
		var t1e: Vector3 = n_e.cross(Vector3.UP)
		if t1e.length() < 0.01:
			t1e = n_e.cross(Vector3.RIGHT)
		t1e = t1e.normalized()
		var t2e: Vector3 = n_e.cross(t1e).normalized()
		var rad_e: float = radio * float(pf.get_meta("rad", 0.6)) * (0.5 + 1.1 * _sal(ue))
		(pf as Node3D).position = (t1e * cos(ang_e) + t2e * sin(ang_e)) * rad_e + n_e * radio * (0.12 + 0.35 * ue)
		var tam_e: float = radio * lerpf(0.7, 1.35, ue)
		(pf as Node3D).scale = Vector3(tam_e, tam_e, 1.0)
		((pf as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("vida", 0.36 * smoothstep(0.0, 0.08, ue) * (1.0 - smoothstep(0.3, 1.0, ue)))
	# vaho: sube y se abre; entra a los 0,05 s y se va hacia el final
	for mv in _vahos:
		var f: float = float(mv.get_meta("fase", 0.0))
		var uv: float = clampf((t - 0.04 - f) / (dur * 0.9), 0.0, 1.0)
		var ang: float = float(mv.get_meta("ang", 0.0))
		var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
		var t1: Vector3 = n.cross(Vector3.UP)
		if t1.length() < 0.01:
			t1 = n.cross(Vector3.RIGHT)
		t1 = t1.normalized()
		var t2: Vector3 = n.cross(t1).normalized()
		var lado: Vector3 = (t1 * cos(ang) + t2 * sin(ang)) * radio * (0.4 + 1.0 * uv)
		var sube: Vector3 = (Vector3.UP if variante == Variante.FIN else n) * radio * (0.4 + 1.3 * uv) + Vector3.UP * radio * 0.5 * uv
		(mv as Node3D).position = lado + sube
		var tam_v: float = radio * lerpf(0.8, 1.7, uv)
		(mv as Node3D).scale = Vector3(tam_v, tam_v, 1.0)
		((mv as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("vida", 0.17 * smoothstep(0.0, 0.2, uv) * (1.0 - smoothstep(0.35, 1.0, uv)))
	_actualizar_gotas(t)


# ------------------------------------------------------------------ AREA ------------------------------------------------------------------

## Las tres fases de las lenguas en el instante `t` (s): suben (0,1-0,55), se curvan hacia fuera (0,45-0,95) y caen (0,8-1,45).
static func area_subida(t: float) -> float:
	return smoothstep(0.1, 0.55, t)


static func area_curva(t: float) -> float:
	return smoothstep(0.45, 0.95, t)


static func area_caida(t: float) -> float:
	return smoothstep(0.8, 1.45, t)


## `u` (0..1) del charco grande en el instante `t`: empieza a los 0,6 s y se ensancha durante 1,1 s.
static func area_u_charco(t: float) -> float:
	return clampf((t - 0.6) / 1.1, 0.0, 1.0)


func _charco_quad(nombre: String, pos: Vector3, lado: float, anillos: float, charco: float, se_va: float) -> MeshInstance3D:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	q.orientation = PlaneMesh.FACE_Y
	var m: MeshInstance3D = MeshInstance3D.new()
	m.name = nombre
	m.mesh = q
	m.material_override = AguaMallas.material(AguaMallas.SH_ONDA, {"anillos": anillos, "charco": charco, "u": 0.0, "vida": 1.0, "semilla": _rng.randf(), "se_va": se_va, "fade_canto": 0.3, "suave_prof": 0.0}, 0)
	m.position = pos
	m.scale = Vector3(lado, 1.0, lado)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


func _construir_area() -> void:
	var r: float = radio
	_plano = Node3D.new()
	_plano.name = "Plano"
	add_child(_plano)
	# (a) estallido: Ex1d recoloreada en billboard
	_lamina = SpriteToy.crear("Lamina", SpriteToy.T_ESTALLIDO, SpriteToy.Modo.MEZCLA, false,
		{"recorte": Vector2(0.3, 0.85), "luminancia": Vector2(0.15, 0.95), "tramo": Vector2(0.15, 0.7), "brillo": 1.0, "giro": _giro0, "vida": 0.0}, 3)       # más agua que estrella: recorte alto (menos puntas) y tramo hacia el somero
	SpriteToy.mat(_lamina).set_shader_parameter("rampa", AguaMallas.rampa_sprites())
	_lamina.position = Vector3(0, 0.4 * r, 0)
	_lamina.set_meta("tam", float(_p["lamina"]) * r)
	_lamina.scale = Vector3.ONE * 0.001
	add_child(_lamina)
	# (b, c) columnas de lenguas: la central y cuatro repartidas por el área, cada una con su retraso
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261106 + int(round(r * 100.0))
	var fase: float = rng.randf() * TAU
	_area_cols.clear()
	_area_lenguas.clear()
	for ci in N_COLUMNAS_AREA:
		var centro: Vector3 = Vector3.ZERO
		if ci > 0:
			var a: float = fase + TAU * float(ci - 1) / float(N_COLUMNAS_AREA - 1) + rng.randf_range(-0.3, 0.3)
			centro = Vector3(cos(a), 0.0, sin(a)) * r * rng.randf_range(0.5, 0.68)
		var dly: float = 0.0 if ci == 0 else rng.randf_range(0.25, 0.65)
		var fuera_c: Vector3 = Vector3(centro.x, 0.0, centro.z)
		fuera_c = fuera_c.normalized() if fuera_c.length() > 0.01 else Vector3.ZERO
		var n_l: int = 6 if ci == 0 else 4
		for li in n_l:
			var al: float = TAU * float(li) / float(n_l) + rng.randf_range(-0.3, 0.3) + float(ci)
			var anillo_d: Vector3 = Vector3(cos(al), 0.0, sin(al))
			var fuera: Vector3 = anillo_d if ci == 0 else (anillo_d * 0.55 + fuera_c * 0.9).normalized()
			var h: float = r * (rng.randf_range(0.92, 1.2) if ci == 0 else rng.randf_range(0.5, 0.88))
			if ci == 0 and li % 2 == 1:
				h *= 0.7
			_area_lenguas.append(AguaMallas.lengua(centro + anillo_d * r * 0.1, h * 0.42 + 0.04, h, fuera, rng, clampf(dly * 0.9 + rng.randf_range(0.0, 0.15), 0.0, 1.0), 0.95))
		_area_cols.append({"centro": centro, "dly": dly, "t0": 0.06 + 0.35 * dly,
			"charco": _charco_quad("Charquito%d" % ci, centro + Vector3(0, 0.01 + 0.004 * float(ci), 0), r * (0.95 if ci == 0 else 0.8), 1.0, 0.62, 0.62)})
	_area_lam = AguaMallas.lenguas_mm("Lenguas", _area_lenguas, {"subida": 0.0, "curva": 0.0, "caida": 0.0, "suave_prof": 0.1, "opacidad": 0.85, "curva_fuerza": 0.85, "cuelga": 0.5})
	add_child(_area_lam)
	# (d) charco grande con anillos
	_area_pool = _charco_quad("Charco", Vector3(0, 0.006, 0), float(_p["anillo"]) * r, float(_p["anillos"]), 0.5, 0.6)
	_area_esp = AguaMallas.espuma_mm("Espuma", 8)
	add_child(_area_esp)
	_area_fra = AguaMallas.franjas_mm("Franjas", 3 * N_COLUMNAS_AREA)
	add_child(_area_fra)
	_montar_gotas()
	_poner_tiempo_cero()


## Gotas de la explosión de área, en tres tandas: (a) estallido (sale hacia arriba, 0-0,1 s), (b) desde las puntas de las columnas (0,22-0,55 s) y (c) corona hacia fuera (0,78-1,0 s). Todo cae con gravedad.
func _montar_gotas_area() -> void:
	var r: float = radio
	var kc: float = clampf(r / RADIO_AREA_REF, 0.45, 2.6)
	var sv: float = sqrt(kc)
	_gotas_c.clear()
	for i in 22:
		var fi: float = _rng.randf() * TAU
		var cos_t: float = _rng.randf_range(0.45, 0.97)
		var sin_t: float = sqrt(1.0 - cos_t * cos_t)
		var dir: Vector3 = Vector3(cos(fi) * sin_t, cos_t, sin(fi) * sin_t)
		_gotas_c.append(_gota_area(Vector3(cos(fi), 0.0, sin(fi)) * r * 0.08 + Vector3(0, 0.04 * r, 0), dir * _rng.randf_range(3.2, 6.8) * sv, _rng.randf_range(0.8, 1.15),
			_rng.randf_range(0.08, 0.15) * pow(kc, 0.5), _rng.randf_range(0.0, 0.1), false))
	for i in 18:
		var col: Dictionary = _area_cols[i % _area_cols.size()]
		var c: Vector3 = col["centro"]
		var fuera: Vector3 = Vector3(c.x, 0.0, c.z)
		fuera = fuera.normalized() if fuera.length() > 0.01 else Vector3(cos(float(i)), 0.0, sin(float(i)))
		var vel: Vector3 = (fuera * _rng.randf_range(0.5, 1.6) + Vector3(0, _rng.randf_range(3.0, 5.4), 0)) * sv
		_gotas_c.append(_gota_area(c + Vector3(_rng.randf_range(-0.1, 0.1), 0.3 * r, _rng.randf_range(-0.1, 0.1)) * r, vel, _rng.randf_range(0.8, 1.1),
			_rng.randf_range(0.07, 0.13) * pow(kc, 0.5), _rng.randf_range(0.22, 0.55), false))
	for i in 22:
		var ang: float = _rng.randf() * TAU
		var d: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		_gotas_c.append(_gota_area(d * r * _rng.randf_range(0.35, 0.9) + Vector3(0, 0.05 * r, 0), (d * _rng.randf_range(1.8, 3.8) + Vector3(0, _rng.randf_range(1.5, 3.2), 0)) * sv,
			_rng.randf_range(0.45, 0.7), _rng.randf_range(0.06, 0.12) * pow(kc, 0.5), _rng.randf_range(0.78, 1.0), false))
	for i in int(_p["burbujas"]):
		var ang2: float = _rng.randf() * TAU
		_gotas_c.append(_gota_area(Vector3(cos(ang2), 0.0, sin(ang2)) * r * _rng.randf_range(0.2, 0.8) + Vector3(0, 0.1, 0), Vector3(0, 0.4, 0), _rng.randf_range(0.7, 0.95),
			_rng.randf_range(0.05, 0.08) * pow(kc, 0.5), _rng.randf_range(0.5, 0.8), true))
	_mm_gotas = AguaGotas.crear_mm("Gotas", _gotas_c.size())
	add_child(_mm_gotas)


func _gota_area(p0: Vector3, v0: Vector3, vida: float, tam: float, retraso: float, burbuja: bool) -> Dictionary:
	return {"p0": p0, "v0": v0, "vida": vida, "tam": tam, "burbuja": burbuja, "g": 1.0 if not burbuja else -0.12, "c": ROZAMIENTO if not burbuja else 2.5, "retraso": retraso,
		"clar": _rng.randf_range(0.2, 0.9) if _rng.randf() > 0.4 else 1.0}


## Pone toda la explosión de área en el instante `t`.
func _avanzar_area(t: float) -> void:
	var r: float = radio
	# (a) estallido
	var ue: float = clampf(t / T_ESTALLIDO_AREA, 0.0, 1.0)
	var tam: float = float(_lamina.get_meta("tam", 1.0))
	var s: float = tam * lerpf(0.45, 1.1, _sal(ue))
	_lamina.scale = Vector3(s, s, 1.0)
	SpriteToy.mat(_lamina).set_shader_parameter("vida", clampf(0.62 * (1.0 - smoothstep(0.2, 1.0, ue)) * smoothstep(0.0, 0.012, t), 0.0, 1.0))
	# (b, c) lenguas
	var ml: ShaderMaterial = _area_lam.material_override as ShaderMaterial
	ml.set_shader_parameter("subida", area_subida(t))
	ml.set_shader_parameter("curva", area_curva(t))
	ml.set_shader_parameter("caida", area_caida(t))
	# charquitos de donde brotan las columnas
	for col in _area_cols:
		var cq: MeshInstance3D = col["charco"]
		var uc: float = clampf((t - float(col["t0"]) + 0.05) / 1.15, 0.0, 1.0)
		(cq.material_override as ShaderMaterial).set_shader_parameter("u", uc)
	# (d) charco grande
	(_area_pool.material_override as ShaderMaterial).set_shader_parameter("u", area_u_charco(t))
	# espuma: 8 del estallido que suben y 3 en la base de cada columna
	var mm: MultiMesh = _area_esp.multimesh
	_area_esp_datos.resize(N_ESPUMA_AREA)
	for i in 8:
		var f: float = float(i) / 8.0
		var ang: float = TAU * f + _giro0
		var u: float = clampf((t - 0.01 * float(i)) / 0.5, 0.0, 1.0)
		var pos: Vector3 = Vector3(cos(ang), 0.0, sin(ang)) * r * (0.1 + 0.4 * _sal(u) * (0.6 + 0.4 * fposmod(f * 5.3, 1.0))) + Vector3(0, r * (0.08 + 0.3 * _sal(u)), 0)
		var tm: float = r * 0.3 * (0.5 + 0.8 * u)
		var al: float = 0.85 * smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.35, 1.0, u))
		AguaMallas.espuma_poner(mm, i, pos, tm, al, 1.0, f * 5.0)
		_area_esp_datos[i] = {"pos": pos, "tam": tm, "alfa": al}
	for ci in _area_cols.size():
		var col2: Dictionary = _area_cols[ci]
		var c: Vector3 = col2["centro"]
		var uu: float = clampf((t - float(col2["t0"])) / 1.0, 0.0, 1.0)
		for k in 3:
			var ak: float = TAU * float(k) / 3.0 + float(ci) * 1.7
			var rr: float = r * (0.14 + 0.08 * float(k % 2)) * (1.0 + 0.8 * uu)
			var posk: Vector3 = c + Vector3(cos(ak), 0.0, sin(ak)) * rr * 1.5 + Vector3(0, 0.03 + 0.02 * float(k), 0)
			var tk: float = r * 0.42 * (0.6 + 0.6 * sin(clampf(uu * 1.3, 0.0, 1.0) * PI * 0.5))
			var alk: float = 0.9 * smoothstep(0.0, 0.15, uu) * (1.0 - smoothstep(0.5, 1.0, uu))
			AguaMallas.franja_poner(_area_fra.multimesh, ci * 3 + k, posk, tk, r * 0.1, alk, 0.8, -ak - PI * 0.5, float(ci * 3 + k) * 1.7)
			_area_esp_datos[8 + ci * 3 + k] = {"pos": posk, "tam": tk, "alfa": alk}


## Medición para las pruebas: altura visible máxima de las lenguas en `t` (m), cuántas lenguas hay, y la dirección hacia fuera media de su punta.
func area_alto_lenguas(t: float) -> float:
	var s0: float = area_subida(t)
	var f0: float = area_caida(t)
	var mx: float = 0.0
	for l in _area_lenguas:
		var d: float = float(l["dly"])
		var s: float = clampf(s0 * 1.5 - d * 0.5, 0.0, 1.0)
		var f: float = clampf(f0 * 1.5 - d * 0.5, 0.0, 1.0)
		var g: float = smoothstep(0.0, 1.0, s) * (1.0 + 0.1 * sin(s * 3.14159))
		mx = maxf(mx, float(l["h"]) * g * (1.0 - 0.85 * f * f))
	return mx


## Desplazamiento horizontal medio (m, hacia fuera) de la punta de las lenguas en `t`: sube con la curva.
func area_curva_fuera(t: float) -> float:
	var c0: float = area_curva(t)
	var tot: float = 0.0
	for l in _area_lenguas:
		var c: float = clampf(c0 * 1.5 - float(l["dly"]) * 0.5, 0.0, 1.0)
		tot += float(l["h"]) * 0.85 * c
	return tot / maxf(float(_area_lenguas.size()), 1.0)


func lenguas_area() -> Array:
	return _area_lenguas


func espuma_area_datos() -> Array:
	return _area_esp_datos
