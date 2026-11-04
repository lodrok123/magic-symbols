class_name ImpactoFuegoToy
extends Node3D

## IMPACTO DEL FUEGO «TOY» (3.ª versión, 2/11/2026, revisión de Pablo; la 2.ª es de 1/11/2026, rama fuego-toy-carga-impacto).
## ESTILO C (POR DEFECTO desde la revisión de Pablo): «no veo impact VFX; usa un golpe sutil y chispas desde el impacto hacia afuera». Un GOLPE breve y pequeño (destello hit22 de ~0,1 s, un halo
## pequeño y una luz que se apaga en 0,25 s; sin bola de fuego grande, sin nube, sin lámina tumbada en la superficie) y CHISPAS que salen DESDE el punto de impacto HACIA FUERA, en el hemisferio de la
## normal, con forma de trazo alargado en la dirección de su velocidad, algo de gravedad y rozamiento, que se apagan en 0,3-0,55 s, más unas pocas brasas pequeñas que caen. Todo en la paleta de la bola
## (blanco-amarillo → naranja), sin humo ni rojo oscuro. Paramétrico: el tamaño, el número y el alcance de las chispas siguen al radio del hechizo. Las chispas son un MultiMesh movido por la CPU
## (chispa_impacto.gdshader): no cuentan como GPUParticles3D y su posición y dirección se pueden medir (`chispas_estado(t)`). Los estilos A y B se conservan con la tecla Y del lab por si hay que volver.
##
## (2.ª versión) La 1.ª (corola de lenguas de Le Lu) salía como una corola de hebras radiales y no como un estallido;
## esta usa SPRITES del pack de Le Lu (assets/vfx/lelu_noise/, licencia libre) recoloreados SIEMPRE con la rampa de la bola (lelu_sprite.gdshaderinc: luminancia → rampa, sin rojo
## oscuro, gris ni negro). Estilos seleccionables para compararlos (ImpactoFuegoToy.estilo; el lab los alterna con Y):
##   · A (Estilo.A): ESTALLIDO CARTOON, T_VFX_Ex1d (picos, aro y gotas disparadas), tumbado en la superficie y orientado por su normal.
##   · B (Estilo.B): BOLA DE FUEGO REDONDA, T_fire_flipbook4_sm (flipbook 5×5; solo los fotogramas de fuego 0-14, los de humo gris/negro NO se usan) en billboard, centrada delante de la
##     superficie, que se expande y se enfría (tipo «Echoes of Wisdom»).
## En A y B: destello del primer instante con T_VFX_hit22 (estrella de 8 puntas, aditiva, ~0,14 s), mancha de calor T_VFX_CircleFit1 en la superficie, halo, pocas chispas (5) y UNA luz
## que se apaga en 0,3 s. Sin humo.
##   · FIN (el hechizo se agota sin chocar, siempre hacia arriba): remolino suave T_VFX_exp_dissapear que gira y se deshace; sin destello ni estallido.
##   · REBOTE (la bola no muere): salpicadura corta, hit22 pequeño + unas gotas.
## ORIENTACIÓN: `normal` es la normal de la superficie (hacia fuera). TAMAÑO: `radio` es el radio de la bola que choca (m); el estallido de A/B mide ≈ 6 × radio. Mandos estáticos para el lab:
## `tam_estallido` (× el tamaño de los sprites), `vel_flipbook` (× la velocidad del flipbook de B).
## Uso:  var i := ImpactoFuegoToy.crear(ImpactoFuegoToy.Variante.GOLPE, normal, radio); padre.add_child(i); i.global_position = punto      (se libera solo)
## `lanzar(v)` y `morir()` existen por el contrato de EfectoVfx3D (EfectoVfx3D.impactar llama a `lanzar`).

const SpriteToy = preload("res://presentacion/vfx/toy/sprite_toy.gd")

enum Variante { GOLPE, FIN, REBOTE }
enum Estilo { A, B, C }

const ESCENA: String = "res://presentacion/vfx/toy/ImpactoFuegoToy.tscn"
## Por variante: destello (hit22), nº de chispas, energía de la luz, brillo de la mancha, y por estilo la duración (s). El estilo C usa «streaks» (chispas con trazo), «brasas» (puntos que caen),
## «luz_c» y «flash_c».
const PARAMS: Dictionary = {
	Variante.GOLPE: {"flash": 1.0, "chispas": 5, "luz": 2.4, "mancha": 1.0, "dur_a": 0.6, "dur_b": 0.8, "dur_c": 0.62, "streaks": 22, "brasas": 5, "luz_c": 1.5, "flash_c": 1.0},
	Variante.FIN: {"flash": 0.0, "chispas": 2, "luz": 0.5, "mancha": 0.3, "dur_a": 0.7, "dur_b": 0.7, "dur_c": 0.7, "streaks": 0, "brasas": 0, "luz_c": 0.5, "flash_c": 0.0},
	Variante.REBOTE: {"flash": 0.7, "chispas": 4, "luz": 1.0, "mancha": 0.4, "dur_a": 0.35, "dur_b": 0.35, "dur_c": 0.4, "streaks": 9, "brasas": 2, "luz_c": 0.7, "flash_c": 0.6}}
const SH_HALO_I: String = "res://presentacion/vfx/toy/halo_impacto.gdshader"
const T_FLASH: float = 0.14               ## s que dura el destello hit22
const T_FLASH_C: float = 0.1              ## ... en el estilo C (golpe sutil)
const ABRE_A: float = 0.12                ## s que tarda el estallido A en abrirse
const ABRE_B: float = 0.18                ## s que tarda la bola B en llegar a su tamaño
const FOTOGRAMAS: int = SpriteToy.FOTOGRAMAS_FUEGO
const GRAVEDAD_C: float = 6.0             ## m/s² de las chispas del estilo C (mundo, hacia abajo)
const GRAVEDAD_BRASA_C: float = 9.0
const ROZAMIENTO_C: float = 1.7           ## 1/s: las chispas salen rápidas y se frenan
const COS_ABERTURA_C: float = 0.34        ## cos del ángulo máximo respecto a la normal (≈ 70°): todas las chispas quedan en el hemisferio de la normal

## Estilo por defecto de los impactos nuevos (el lab lo alterna con Y) y los mandos de tamaño y velocidad del flipbook.
static var estilo: int = Estilo.C
static var tam_estallido: float = 1.0
static var vel_flipbook: float = 1.0

## 4/11/2026 (explosión del barril, ExplosionFuegoToy): desplazamiento de la temperatura de la rampa (negativo = más rojo-naranja y menos amarillo) que se suma al `calor` de la bola (estilo B), a 1,6 veces en el
## destello y a la mitad en las chispas. 0 por defecto: el resto de los impactos no cambian.
var desp_calor: float = 0.0

## 4/11/2026 (explosión del barril, ExplosionFuegoToy): todos neutros por defecto, el resto de los impactos no cambia. `desp_calor` desplaza la temperatura de la rampa (negativo = más rojo; x1,6 en el destello, x0,5 en las chispas).
## `flash_k` y `flash_brillo`: tamaño y brillo del destello. `tramo_bola` y `recorte_bola`: tramo de la rampa y recorte de forma de la bola (más duro = lóbulos recortados). `aplasta_bola`: <1 = bola más ancha que alta.
## `dur_k`: factor de la duración del estilo B.
var flash_k: float = 1.0
var flash_brillo: float = 1.3
var tramo_bola: Vector2 = Vector2(0.3, 0.8)
var recorte_bola: Vector2 = Vector2(0.0, 1.0)
var aplasta_bola: float = 1.0
var dur_k: float = 1.0

@export var variante: Variante = Variante.GOLPE
@export var normal: Vector3 = Vector3.UP
@export_range(0.05, 4.0, 0.01, "or_greater") var radio: float = 0.4

var _estilo: int = Estilo.C
var _tam: float = 1.0
var _vel: float = 1.0
var _t: float = -1.0
var _p: Dictionary = {}
var _dur: float = 0.8
var _plano: Node3D = null
var _destello: MeshInstance3D = null
var _estallido: MeshInstance3D = null      ## A (o el remolino de FIN)
var _bola: MeshInstance3D = null           ## B
var _mancha: MeshInstance3D = null
var _mat_halo: ShaderMaterial = null
var _luz: OmniLight3D = null
var _chispas: GPUParticles3D = null        ## A y B
var _mm_chispas: MultiMeshInstance3D = null   ## C
var _tr_chispas: Array = []                ## última transformación puesta a cada chispa (para las pruebas: en headless el MultiMesh no guarda datos)
var _chispas_c: Array = []                 ## C: [{p0, v0, vida, brasa, largo, ancho, g, c}] en el espacio local del nodo
var _fin_t: float = 1.0
var _giro0: float = 0.0


static func crear(var_: Variante, normal_: Vector3, radio_: float, estilo_: int = -1) -> ImpactoFuegoToy:
	var i: ImpactoFuegoToy = (load(ESCENA) as PackedScene).instantiate() as ImpactoFuegoToy
	i.configurar(var_, normal_, radio_, estilo_)
	return i


## Se llama ANTES de añadirlo al árbol. La FIN siempre sube (normal arriba). `estilo_` < 0 = el estilo estático actual.
func configurar(var_: Variante, normal_: Vector3, radio_: float, estilo_: int = -1) -> void:
	variante = var_
	normal = Vector3.UP if var_ == Variante.FIN or normal_.length() < 0.001 else normal_.normalized()
	radio = maxf(radio_, 0.05)
	_estilo = estilo if estilo_ < 0 else estilo_
	_tam = tam_estallido
	_vel = vel_flipbook


func _ready() -> void:
	_p = PARAMS[variante]
	_dur = _duracion_de(_estilo)
	_fin_t = _dur + 0.45
	_giro0 = randf() * TAU
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
	return _duracion_de(_estilo)


func _duracion_de(est: int) -> float:
	var q: Dictionary = PARAMS[variante]
	return float(q["dur_a"] if est == Estilo.A else (q["dur_b"] * dur_k if est == Estilo.B else q["dur_c"]))


func estilo_actual() -> int:
	return _estilo


# ------------------------------------------------------------------ construcción ------------------------------------------------------------------

func _base_normal() -> Basis:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	if n.dot(Vector3.UP) < -0.999:
		return Basis(Quaternion(Vector3.RIGHT, PI))
	return Basis(Quaternion(Vector3.UP, n))


func _construir() -> void:
	FuegoToy._rampas()
	var r: float = radio
	var tam: float = _tam
	var es_c: bool = _estilo == Estilo.C
	_plano = Node3D.new()
	_plano.name = "Plano"
	_plano.basis = _base_normal()
	add_child(_plano)
	# mancha de calor (T_VFX_CircleFit1): disco suave tumbado en la superficie, con mezcla normal (no lava el suelo claro). El estilo C NO la lleva (nada de láminas tumbadas).
	if not es_c:
		_mancha = SpriteToy.crear("Mancha", SpriteToy.T_MANCHA, SpriteToy.Modo.MEZCLA, true, {"centro": 1.0, "brillo": 1.0, "tramo": Vector2(0.4, 0.55), "vida": 0.0}, -1)
		_mancha.position = Vector3(0, 0.03, 0)
		_mancha.scale = Vector3(5.5 * r * tam, 1.0, 5.5 * r * tam)
		_plano.add_child(_mancha)
	match variante:
		Variante.FIN:
			var rem: MeshInstance3D = SpriteToy.crear("Remolino", SpriteToy.T_DESHACER, SpriteToy.Modo.MEZCLA_SIN_PROF, false,
				{"centro": 0.85, "recorte": Vector2(0.12, 0.85), "luminancia": Vector2(0.1, 0.9), "tramo": Vector2(0.42, 0.95), "brillo": 1.05, "vida": 0.0}, 2)
			rem.position = Vector3(0, 0.35 * r, 0)
			_plano.add_child(rem)
			_estallido = rem
		_:
			var esc: float = 1.0 if variante == Variante.GOLPE else 0.5
			if es_c:
				pass
			elif _estilo == Estilo.A:
				var est: MeshInstance3D = SpriteToy.crear("Estallido", SpriteToy.T_ESTALLIDO, SpriteToy.Modo.MEZCLA, true,
					{"recorte": Vector2(0.16, 0.7), "luminancia": Vector2(0.15, 0.95), "tramo": Vector2(0.4, 1.0), "brillo": 1.0, "giro": _giro0, "vida": 0.0}, 1)
				est.position = Vector3(0, 0.06 * r, 0)
				est.set_meta("tam", 6.4 * r * tam * esc)
				_plano.add_child(est)
				_estallido = est
			else:
				var bola: MeshInstance3D = SpriteToy.crear("Bola", SpriteToy.T_FLIPBOOK, SpriteToy.Modo.MEZCLA_SIN_PROF, false,
					{"usar_alfa": 1.0, "fb_cols": 5, "fb_filas": 5, "fotograma": 0.0, "fotograma_max": float(FOTOGRAMAS - 1), "luminancia": Vector2(0.25, 0.85),
					"tramo": tramo_bola, "recorte": recorte_bola, "brillo": 0.95, "giro": 0.0, "vida": 0.0}, 1)
				bola.position = Vector3(0, 0.9 * r * esc * aplasta_bola, 0)
				bola.set_meta("tam", 5.2 * r * tam * esc)
				_plano.add_child(bola)
				_bola = bola
			# destello del primer instante: hit22 aditivo (en C, pequeño y corto)
			var fl: float = float(_p["flash_c"] if es_c else _p["flash"])
			if fl > 0.0:
				var d: MeshInstance3D = SpriteToy.crear("Destello", SpriteToy.T_DESTELLO, SpriteToy.Modo.ADITIVO, false,
					{"recorte": Vector2(0.04, 0.9), "luminancia": Vector2(0.2, 1.0), "tramo": Vector2(0.6, 1.0), "brillo": 1.3, "giro": _giro0 * 0.5, "vida": 0.0}, 4)
				d.position = Vector3(0, (0.22 if es_c else 0.3) * r, 0)
				if es_c:
					d.set_meta("tam", (2.5 if variante == Variante.GOLPE else 1.6) * r * tam * flash_k)
				else:
					d.set_meta("tam", (3.4 if variante == Variante.GOLPE else 2.0) * r * tam * flash_k)
				_plano.add_child(d)
				_destello = d
	# halo: resplandor aditivo detrás de todo
	var hq: QuadMesh = QuadMesh.new()
	hq.size = Vector2(5.0 * r, 5.0 * r) if not es_c else Vector2(3.4 * r, 3.4 * r)
	var hmi: MeshInstance3D = MeshInstance3D.new()
	hmi.name = "Halo"
	hmi.mesh = hq
	_mat_halo = ShaderMaterial.new()
	_mat_halo.shader = load(SH_HALO_I)
	_mat_halo.render_priority = -1
	_mat_halo.set_shader_parameter("brillo", 0.0)
	_mat_halo.set_shader_parameter("caida", 2.6)
	_mat_halo.set_shader_parameter("billboard", 2)
	_mat_halo.set_shader_parameter("color", Color(1.0, 0.3, 0.07))
	_mat_halo.set_shader_parameter("latido", 0.0)
	hmi.material_override = _mat_halo
	hmi.position = Vector3(0, 0.45 * r, 0)
	hmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plano.add_child(hmi)
	# luz breve
	var k: float = r / FuegoToy.REF_BOLA.x
	_luz = OmniLight3D.new()
	_luz.name = "Luz"
	_luz.light_color = Color(1.0, 0.5, 0.22)
	_luz.omni_attenuation = 1.4
	_luz.omni_range = (4.5 if not es_c else 3.4) * clampf(k, 0.4, 2.5)
	_luz.light_energy = 0.0
	_luz.shadow_enabled = false
	_luz.position = Vector3(0, 0.5 * r, 0)
	_plano.add_child(_luz)
	if es_c:
		_montar_chispas_c()
	_aplicar_tam(0.0)


# ------------------------------------------------------------------ estilo C: chispas desde el impacto hacia afuera ------------------------------------------------------------------

## Genera las chispas (trazos) y las brasas del estilo C: todas salen del punto de impacto, dentro de un cono de ~70° alrededor de la normal.
func _montar_chispas_c() -> void:
	var n_s: int = int(_p["streaks"])
	var n_b: int = int(_p["brasas"])
	if n_s + n_b <= 0:
		return
	var k: float = radio / FuegoToy.REF_BOLA.x
	var kc: float = clampf(k, 0.5, 3.0)
	var n_s2: int = clampi(int(round(float(n_s) * clampf(sqrt(kc), 0.7, 1.8))), 4, 40)
	var n_b2: int = clampi(int(round(float(n_b) * clampf(sqrt(kc), 0.7, 1.8))), 0, 12) if n_b > 0 else 0
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	var t1: Vector3 = n.cross(Vector3.UP)
	if t1.length() < 0.01:
		t1 = n.cross(Vector3.RIGHT)
	t1 = t1.normalized()
	var t2: Vector3 = n.cross(t1).normalized()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	_chispas_c.clear()
	for i in n_s2 + n_b2:
		var brasa: bool = i >= n_s2
		var cos_t: float = lerpf(COS_ABERTURA_C if not brasa else 0.1, 1.0, pow(rng.randf(), 0.8))
		var sin_t: float = sqrt(maxf(1.0 - cos_t * cos_t, 0.0))
		var fi: float = rng.randf() * TAU
		var dir: Vector3 = n * cos_t + (t1 * cos(fi) + t2 * sin(fi)) * sin_t
		var vel: float = (rng.randf_range(3.6, 7.6) * pow(kc, 0.6)) if not brasa else (rng.randf_range(1.0, 2.4) * pow(kc, 0.5))
		var vida: float = rng.randf_range(0.3, 0.55) if not brasa else rng.randf_range(0.42, 0.58)
		var off: Vector3 = (t1 * cos(fi) + t2 * sin(fi)) * radio * 0.12 + n * (0.04 * kc)
		_chispas_c.append({"p0": off, "v0": dir * vel, "vida": vida, "brasa": brasa,
			"largo": clampf(vel * 0.085, 0.09, 0.6) * pow(kc, 0.35), "ancho": (0.046 if not brasa else 0.075) * pow(kc, 0.5),
			"g": GRAVEDAD_C if not brasa else GRAVEDAD_BRASA_C, "c": ROZAMIENTO_C if not brasa else 1.0, "retraso": rng.randf_range(0.0, 0.025)})
	_mm_chispas = SpriteToy.chispas_mm("Chispas", _chispas_c.size(), 1.9)
	add_child(_mm_chispas)


## Posición (local), velocidad (local) y edad normalizada de la chispa `d` al instante `t`.
func _estado_chispa(d: Dictionary, t: float, g_local: Vector3) -> Dictionary:
	var ta: float = maxf(t - float(d["retraso"]), 0.0)
	var c: float = float(d["c"])
	var v0: Vector3 = d["v0"]
	var p: Vector3 = (d["p0"] as Vector3) + v0 * ((1.0 - exp(-c * ta)) / c) + 0.5 * g_local * float(d["g"]) * ta * ta
	var v: Vector3 = v0 * exp(-c * ta) + g_local * float(d["g"]) * ta
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	var h: float = p.dot(n)
	var h_min: float = 0.02 * clampf(radio / FuegoToy.REF_BOLA.x, 0.5, 3.0)
	if h < h_min:
		p += n * (h_min - h)                       # nunca por debajo de la superficie
	return {"pos": p, "vel": v, "u": ta / float(d["vida"]), "ta": ta}


func _gravedad_local() -> Vector3:
	if is_inside_tree():
		return (global_transform.basis.inverse() * Vector3.DOWN).normalized()
	return Vector3.DOWN


func _actualizar_chispas(t: float) -> void:
	if _mm_chispas == null:
		return
	var g: Vector3 = _gravedad_local()
	var mm: MultiMesh = _mm_chispas.multimesh
	_tr_chispas.resize(_chispas_c.size())
	for i in _chispas_c.size():
		var d: Dictionary = _chispas_c[i]
		var e: Dictionary = _estado_chispa(d, t, g)
		var u: float = float(e["u"])
		if u >= 1.0 or t <= float(d["retraso"]):
			_tr_chispas[i] = SpriteToy.poner_chispa(mm, i, Vector3.ZERO, Vector3.UP, 0.0, 0.0, 0.0, 0.0, false)
			continue
		var v: Vector3 = e["vel"]
		var brasa: bool = bool(d["brasa"])
		var alfa: float = smoothstep(0.0, 0.06, u) * (1.0 - smoothstep(0.55, 1.0, u))
		var calor: float = clampf(((1.0 - 0.6 * u) if not brasa else (0.6 - 0.45 * u)) + desp_calor * 0.5, 0.0, 1.0)
		var vel0: float = maxf((d["v0"] as Vector3).length(), 0.001)
		var largo: float = float(d["largo"]) * clampf(v.length() / vel0, 0.3, 1.0) * (1.0 - 0.5 * u * u)
		_tr_chispas[i] = SpriteToy.poner_chispa(mm, i, e["pos"], v.normalized(), largo, float(d["ancho"]) * (1.0 - 0.4 * u), calor, alfa, brasa)


## Medición para las pruebas (estilo C): una entrada por chispa, con su posición y dirección en MUNDO, la distancia al punto de impacto, la altura sobre la superficie (a lo largo de la normal)
## y si sigue viva en `t`.
func chispas_estado(t: float) -> Array:
	var res: Array = []
	var g: Vector3 = _gravedad_local()
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	for d in _chispas_c:
		var e: Dictionary = _estado_chispa(d, t, g)
		var p: Vector3 = e["pos"]
		var v: Vector3 = e["vel"]
		res.append({"pos": global_transform * p, "dir": (global_transform.basis * v).normalized(), "dist": p.length(), "altura": p.dot(n), "vivo": float(e["u"]) < 1.0 and t > float(d["retraso"]),
			"brasa": bool(d["brasa"]), "largo": float(d["largo"]), "vida": float(d["vida"])})
	return res


## Transformación (local) con la que se dibuja la chispa `i` en el último `avanzar_a`.
func transformada_chispa(i: int) -> Transform3D:
	return _tr_chispas[i] if i < _tr_chispas.size() else Transform3D.IDENTITY


## Chispas (trazos) y brasas generadas: [n_trazos, n_brasas].
func recuento_chispas() -> Array:
	var b: int = 0
	for d in _chispas_c:
		if bool(d["brasa"]):
			b += 1
	return [_chispas_c.size() - b, b]


## Chispas: pocas, hacia fuera de la superficie y hacia arriba, con gravedad; en coordenadas de mundo (la caja no gira con la normal). Solo estilos A y B.
func _arrancar() -> void:
	if _estilo == Estilo.C:
		return
	var cant: int = int(_p["chispas"])
	if cant <= 0:
		return
	var k: float = radio / FuegoToy.REF_BOLA.x
	var gp: GPUParticles3D = GPUParticles3D.new()
	gp.name = "Chispas"
	gp.top_level = true
	gp.amount = cant
	gp.lifetime = 0.75
	gp.one_shot = true
	gp.explosiveness = 0.95
	gp.local_coords = false
	gp.fixed_fps = 0
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-5, -3, -5), Vector3(10, 9, 10))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25 * radio
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	pm.direction = (n * 0.75 + Vector3.UP * 0.55).normalized()
	pm.spread = 38.0
	pm.initial_velocity_min = 1.3 * k
	pm.initial_velocity_max = 3.0 * k
	pm.gravity = Vector3(0, -3.2, 0)
	pm.damping_min = 0.4
	pm.damping_max = 1.0
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	pm.color_ramp = FuegoToy._gradiente([Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.74, 0.3, 1.0), Color(1.0, 0.58, 0.14, 0.9), Color(1.0, 0.5, 0.1, 0.0)], [0.0, 0.12, 0.6, 1.0])
	var curva: Curve = Curve.new()
	curva.add_point(Vector2(0, 0.0))
	curva.add_point(Vector2(0.12, 1.0))
	curva.add_point(Vector2(1, 0.15))
	var ct: CurveTexture = CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	gp.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.085 * k, 0.085 * k)
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = FuegoToy._textura_chispa()
	q.material = sm
	gp.draw_pass_1 = q
	add_child(gp)
	gp.global_position = global_position + n * 0.3 * radio
	gp.emitting = true
	_chispas = gp


# ------------------------------------------------------------------ animación ------------------------------------------------------------------

func _process(delta: float) -> void:
	if _p.is_empty():
		return
	if _t < 0.0:
		_t = 0.0
		_arrancar()
	_t += delta
	avanzar_a(_t)
	if _t >= _fin_t:
		queue_free()


func _aplicar_tam(s: float) -> void:
	if _estallido != null:
		var d: float = float(_estallido.get_meta("tam", 0.0))
		if d > 0.0:
			_estallido.scale = Vector3(d * s, 1.0, d * s) if _estilo == Estilo.A else Vector3(d * s, d * s, 1.0)
	if _bola != null:
		var d2: float = float(_bola.get_meta("tam", 1.0))
		_bola.scale = Vector3(d2 * s, d2 * s * aplasta_bola, 1.0)


static func _sal(u: float) -> float:
	return 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 3.0)


## Pone la animación en el instante `t` (s). `_process` la llama cada fotograma; las pruebas y las capturas pueden llamarla a mano.
func avanzar_a(t: float) -> void:
	if _p.is_empty() or _plano == null:
		return
	var es_c: bool = _estilo == Estilo.C
	var dur: float = _dur
	var flash: float = float(_p["flash_c"] if es_c else _p["flash"])
	# destello hit22: aparece en el primer fotograma, crece rápido y se va en ~0,14 s (0,1 s en el estilo C)
	if _destello != null:
		var tf: float = T_FLASH_C if es_c else T_FLASH
		var u: float = clampf(t / tf, 0.0, 1.0)
		var d: float = float(_destello.get_meta("tam", 1.0))
		var s: float = d * lerpf(0.4, 1.25 if not es_c else 1.15, _sal(u))
		_destello.scale = Vector3(s, s, 1.0)
		SpriteToy.mat(_destello).set_shader_parameter("vida", clampf(flash * (1.0 - smoothstep(0.1, 1.0, u)) * smoothstep(0.0, 0.012, t), 0.0, 1.0))
		if desp_calor != 0.0:
			SpriteToy.mat(_destello).set_shader_parameter("calor", desp_calor * 1.6)
			SpriteToy.mat(_destello).set_shader_parameter("brillo", flash_brillo)
		if desp_calor != 0.0:
			SpriteToy.mat(_destello).set_shader_parameter("calor", desp_calor * 1.6)
	var fade_fin: float = 1.0 - smoothstep(dur * 0.62, dur, t)
	match variante:
		Variante.FIN:
			var uf: float = clampf(t / dur, 0.0, 1.0)
			var tam_f: float = lerpf(3.6, 1.0, pow(uf, 1.4)) * radio * _tam
			_estallido.scale = Vector3(tam_f, tam_f, 1.0)
			var mf: ShaderMaterial = SpriteToy.mat(_estallido)
			mf.set_shader_parameter("giro", _giro0 + t * 6.5)
			mf.set_shader_parameter("vida", 0.8 * smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.3 * dur, dur, t)))
			mf.set_shader_parameter("calor", lerpf(0.1, -0.12, uf))
		_:
			if es_c:
				_actualizar_chispas(t)
			elif _estilo == Estilo.A:
				var ua: float = clampf(t / ABRE_A, 0.0, 1.0)
				var over: float = 1.0 + 0.1 * sin(ua * PI)
				_aplicar_tam(lerpf(0.4, 1.0, _sal(ua)) * over * (1.0 + 0.1 * smoothstep(ABRE_A, dur, t)))
				var ma: ShaderMaterial = SpriteToy.mat(_estallido)
				ma.set_shader_parameter("vida", smoothstep(0.0, 0.015, t) * (1.0 - smoothstep(0.22 * dur, dur, t)))
				ma.set_shader_parameter("calor", lerpf(0.22, -0.08, smoothstep(0.0, 0.45 * dur, t)))
			else:
				var ub: float = clampf(t / ABRE_B, 0.0, 1.0)
				_aplicar_tam(lerpf(0.4, 1.0, _sal(ub)) * (1.0 + 0.14 * clampf(t / dur, 0.0, 1.0)))
				var mb: ShaderMaterial = SpriteToy.mat(_bola)
				mb.set_shader_parameter("fotograma", clampf(t / dur * float(FOTOGRAMAS) * _vel, 0.0, float(FOTOGRAMAS) - 1.001))
				mb.set_shader_parameter("vida", smoothstep(0.0, 0.015, t) * fade_fin)
				mb.set_shader_parameter("calor", lerpf(0.06, -0.08, smoothstep(0.0, 0.5 * dur, t)) + desp_calor)
	if es_c:
		# halo pequeño y corto + luz que se apaga en ~0,25 s
		_mat_halo.set_shader_parameter("brillo", 0.55 * flash * (1.0 - smoothstep(0.0, 0.16, t)) + 0.12 * (1.0 - smoothstep(0.0, 0.35, t)) * smoothstep(0.0, 0.03, t) * (1.0 if flash > 0.0 else 0.5))
		_luz.light_energy = float(_p["luz_c"]) * exp(-t * 10.0) * smoothstep(0.0, 0.012, t)
		return
	_mat_halo.set_shader_parameter("brillo", 0.9 * flash * (1.0 - smoothstep(0.0, 0.3, t)) + 0.3 * (1.0 - smoothstep(0.0, dur, t)) * smoothstep(0.0, 0.05, t))
	if _mancha != null:
		SpriteToy.mat(_mancha).set_shader_parameter("vida", 0.4 * float(_p["mancha"]) * smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.1, dur + 0.1, t)))
	_luz.light_energy = float(_p["luz"]) * (exp(-t * 7.0) * 0.75 + 0.25 * (1.0 - smoothstep(0.05, dur * 0.7, t))) * smoothstep(0.0, 0.015, t)
