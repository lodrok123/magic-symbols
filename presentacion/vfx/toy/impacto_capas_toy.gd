extends Node3D

## IMPACTO POR CAPAS (25/11/2026, prueba de traducir impactos de Effekseer a nuestros shaders).
## Un reproductor GENÉRICO: recibe una «receta» (lista de capas con tiempos, tamaños y fundidos, recetas_effekseer.gd) y la dibuja SOLO con piezas que ya existen en el juego:
##   · sprite  → SpriteToy (sprites de Le Lu recoloreados con la rampa del elemento: destello hit22, estallido, bola flipbook, mancha)
##   · halo    → halo_impacto.gdshader / halo_toy.gdshader (resplandor o anillo; billboard o tumbado en la superficie)
##   · chispas → chispa_impacto.gdshader (SpriteToy.chispas_mm: trazos y brasas movidos por la CPU)
##   · gotas   → agua_gota.gdshader (AguaGotas: gotas y burbujas con la paleta del agua)
##   · piedras → las piedrecitas de TierraToy (malla de terrón)
##   · humo    → HumoToy (humo_toon: bocanadas de dos tonos)
##   · grieta  → tierra_anillo.gdshader con la marca de suelo (TierraToy.crear_quad_suelo)
##   · onda    → agua_onda.gdshader (AguaMallas: charco con anillos)
##   · luz     → una OmniLight3D que se apaga
## Los COLORES salen de la paleta del elemento (`paleta()`): fuego = rampa de la bola (FuegoToy), agua = AguaPaleta, tierra = pardos de TierraToy / ImpactoTierraToy (regla de Pablo:
## los colores de cada elemento salen de lo que ya hay en el mundo). La receta solo dice la coreografía.
## Sin class_name (como sprite_toy.gd): se usa con `const ImpactoCapasToy = preload("res://presentacion/vfx/toy/impacto_capas_toy.gd")`.
## Uso:  var i := ImpactoCapasToy.crear(receta, "fuego", normal, radio); padre.add_child(i); i.global_position = punto      (se libera solo)
## Tamaños, distancias y velocidades de la receta están en metros para `radio` = 0,4 (la bola del lab) y escalan con radio / 0,4.

const SpriteToy = preload("res://presentacion/vfx/toy/sprite_toy.gd")
const HumoToy = preload("res://presentacion/vfx/toy/humo_toy.gd")
const AguaGotas = preload("res://presentacion/vfx/toy/agua_gotas.gd")
const AguaMallas = preload("res://presentacion/vfx/toy/agua_mallas.gd")
const AguaPaleta = preload("res://presentacion/vfx/toy/agua_paleta.gd")
const HieloMallas = preload("res://presentacion/vfx/toy/hielo_mallas.gd")
const SH_HALO_SIN_PROF: String = "res://presentacion/vfx/toy/halo_impacto.gdshader"
const SH_HALO_PROF: String = "res://presentacion/vfx/toy/halo_toy.gdshader"
const SH_ARO: String = "res://presentacion/vfx/toy/aro_choque.gdshader"
const SH_CALOR: String = "res://presentacion/vfx/shaders/calor.gdshader"
const SH_GRIETA: String = "res://presentacion/vfx/toy/tierra_anillo.gdshader"
const TEX_MARCA: String = "res://assets/vfx/lelu_noise/T_Groundmark19.png"
const RADIO_REF: float = 0.4
const GRAVEDAD: float = 9.8
const TEXTURAS: Dictionary = {"destello": SpriteToy.T_DESTELLO, "estallido": SpriteToy.T_ESTALLIDO, "bola": SpriteToy.T_FLIPBOOK, "mancha": SpriteToy.T_MANCHA,
	"remolino": SpriteToy.T_REMOLINO, "deshacer": SpriteToy.T_DESHACER,
	"rayos": "T_VFX_Flare_666.jpg"}       ## estrella de rayos finos (Le Lu): la más parecida a tx_hit01 de Effekseer

var receta: Dictionary = {}
var elemento: String = "fuego"
var normal: Vector3 = Vector3.UP
var radio: float = RADIO_REF
var suelo_y: float = -1.0e9                   ## altura (mundo) del suelo: chispas, gotas y piedras no bajan de aquí (el lab pone 0)

var _t: float = -1.0
var _dur: float = 1.0
var _k: float = 1.0
var _pal: Dictionary = {}
var _plano: Node3D = null
var _capas: Array = []                        ## [{def, nodos: [...], parts: [...], mm, humo, emitidas}]
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _giro_esfera: float = 0.0
static var _rampas_extra: Dictionary = {}


static func crear(receta_: Dictionary, elemento_: String, normal_: Vector3, radio_: float) -> Node3D:
	var i: Node3D = (load("res://presentacion/vfx/toy/impacto_capas_toy.gd") as GDScript).new()
	i.receta = receta_
	i.elemento = elemento_
	i.normal = normal_.normalized() if normal_.length() > 0.001 else Vector3.UP
	i.radio = maxf(radio_, 0.05)
	i.name = "ImpactoCapas_" + String(receta_.get("id", "receta"))
	return i


# ------------------------------------------------------------------ paleta del elemento ------------------------------------------------------------------

static func _gradiente(colores: Array) -> GradientTexture1D:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.22, 0.62, 0.9, 1.0])
	g.colors = PackedColorArray(colores)
	var t: GradientTexture1D = GradientTexture1D.new()
	t.gradient = g
	t.width = 128
	return t


## Colores de cada elemento, sacados de lo que ya hay en el juego. `aditivo` = false: lo que en la receta es luz (sprites aditivos, chispas) se dibuja con mezcla normal (la tierra no brilla).
static func paleta(el: String) -> Dictionary:
	FuegoToy._rampas()
	match el:
		"agua":
			if not _rampas_extra.has("agua"):
				_rampas_extra["agua"] = _gradiente([AguaPaleta.LECHO, AguaPaleta.HONDO, AguaPaleta.SOMERO, AguaPaleta.CAUSTICAS, AguaPaleta.ESPUMA])
			return {"rampa": _rampas_extra["agua"], "halo": AguaPaleta.CAUSTICAS, "luz": AguaPaleta.SOMERO, "aditivo": true,
				"humo": {"claro": AguaPaleta.ESPUMA, "sombra": AguaPaleta.CAUSTICAS, "viejo": AguaPaleta.SOMERO}}
		"tierra":
			if not _rampas_extra.has("tierra"):
				# marca de suelo → interior del anillo → púa → borde del anillo → centro claro del polvo (TierraToy / ImpactoTierraToy / tierra_anillo)
				_rampas_extra["tierra"] = _gradiente([Color(0.26, 0.16, 0.09), Color(0.40, 0.27, 0.16), TierraToy.COLOR_PUA, Color(0.76, 0.58, 0.40), ImpactoTierraToy.CENTRO_CLARO])
			return {"rampa": _rampas_extra["tierra"], "halo": Color(0.76, 0.58, 0.40), "luz": Color(0, 0, 0), "aditivo": false,
				"humo": {"claro": TierraToy.POLVO_CLARO, "sombra": TierraToy.POLVO_SOMBRA, "viejo": TierraToy.POLVO_VIEJO}}
	return {"rampa": FuegoToy._rampa_bola, "halo": Color(1.0, 0.3, 0.07), "luz": Color(1.0, 0.5, 0.22), "aditivo": true,
		"humo": {"claro": HumoToy.POR_DEFECTO["claro"], "sombra": HumoToy.POR_DEFECTO["sombra"], "viejo": HumoToy.POR_DEFECTO["viejo"]}}


# ------------------------------------------------------------------ ciclo ------------------------------------------------------------------

func _ready() -> void:
	_rng.randomize()
	_giro_esfera = _rng.randf() * TAU
	_k = radio / RADIO_REF
	_pal = paleta(elemento)
	_plano = Node3D.new()
	_plano.name = "Plano"
	_plano.basis = _base_normal()
	add_child(_plano)
	_dur = 0.0
	for c in receta.get("capas", []):
		var d: Dictionary = c
		_capas.append(_montar(d))
		_dur = maxf(_dur, _fin_capa(d))
	avanzar_a(0.0)


func lanzar(_v: float = -1.0) -> void:
	pass


func morir() -> void:
	queue_free()


func duracion() -> float:
	return _dur


func tiempo() -> float:
	return maxf(_t, 0.0)


func _process(delta: float) -> void:
	if _t < 0.0:
		_t = 0.0
	_t += delta
	avanzar_a(_t)
	if _t >= _dur + 0.1:
		queue_free()


func _base_normal() -> Basis:
	if normal.dot(Vector3.UP) < -0.999:
		return Basis(Quaternion(Vector3.RIGHT, PI))
	return Basis(Quaternion(Vector3.UP, normal))


## Último instante en que la capa enseña algo.
func _fin_capa(d: Dictionary) -> float:
	var vida: Variant = d.get("vida", 0.5)
	var v: float = float(vida[1]) if vida is Array else float(vida)
	return float(d.get("t0", 0.0)) + float(d.get("emision", 0.0)) + v


static func _rango(v: Variant, rng: RandomNumberGenerator) -> float:
	if v is Array:
		return rng.randf_range(float(v[0]), float(v[1]))
	return float(v)


static func _curva(u: float, cual: String) -> float:
	u = clampf(u, 0.0, 1.0)
	match cual:
		"lineal":
			return u
		"entra":
			return u * u * u
		"suave":
			return smoothstep(0.0, 1.0, u)
	return 1.0 - pow(1.0 - u, 3.0)          # "sal": rápido al principio y se asienta (Effekseer: StartSpeed > 0)


## Opacidad 0..1 de una pieza de vida `vida` a los `ta` s: aparece en `ap` s y se va en los últimos `va` s (como FadeIn / FadeOut de Effekseer).
static func _fundido(ta: float, vida: float, ap: float, va: float) -> float:
	if ta < 0.0 or ta > vida:
		return 0.0
	var a: float = 1.0 if ap <= 0.0 else clampf(ta / ap, 0.0, 1.0)
	var b: float = 1.0 if va <= 0.0 else clampf((vida - ta) / minf(va, vida), 0.0, 1.0)
	return a * b


## Una dirección en el espacio del plano (Y = normal): `cono` = [cos mín, cos máx] respecto a la normal (1 = recta, 0 = rasante, -1 = hacia dentro).
func _dir_cono(cono: Array) -> Vector3:
	var c: float = _rng.randf_range(float(cono[0]), float(cono[1]))
	var s: float = sqrt(maxf(1.0 - c * c, 0.0))
	var fi: float = _rng.randf() * TAU
	return Vector3(cos(fi) * s, c, sin(fi) * s)


func _gravedad_local() -> Vector3:
	var b: Basis = _plano.basis
	if is_inside_tree():
		b = global_transform.basis * b
	return b.inverse() * Vector3(0, -1, 0)


# ------------------------------------------------------------------ montaje de cada capa ------------------------------------------------------------------

func _montar(d: Dictionary) -> Dictionary:
	var c: Dictionary = {"def": d, "nodos": [], "parts": []}
	var pieza: String = String(d.get("pieza", "sprite"))
	var n: int = int(d.get("n", 1))
	match pieza:
		"sprite":
			for i in n:
				c["nodos"].append(_montar_sprite(d, i))
		"halo":
			for i in n:
				c["nodos"].append(_montar_halo(d, i))
		"aro":
			for i in n:
				c["nodos"].append(_montar_aro(d, i))
		"distorsion":
			for i in n:
				c["nodos"].append(_montar_distorsion(d, i))
		"chispas", "gotas", "piedras":
			n = maxi(int(round(float(n) * clampf(sqrt(_k), 0.6, 1.8))), 1)
			_montar_particulas(c, d, pieza, n)
		"humo":
			var h: Node3D = HumoToy.new()
			h.name = "Humo"
			_plano.add_child(h)
			var q: Dictionary = (_pal["humo"] as Dictionary).duplicate()
			q.merge(d.get("colores", {}), true)                 # la receta puede oscurecer el humo (hollín del fuego)
			q["tam_ini"] = float(d.get("tam", [0.25, 0.6])[0]) * _k
			q["tam_fin"] = float(d.get("tam", [0.25, 0.6])[1]) * _k
			q["vida"] = float(d.get("vida_media", 1.0))
			q["deriva"] = Vector3(0, float(d.get("deriva", 0.4)), 0)
			q["mundo"] = false
			q["friccion"] = float(d.get("friccion", 1.6))
			h.call("montar", n, q)
			c["humo"] = h
			for i in n:
				var dir: Vector3 = _dir_cono(d.get("cono", [0.0, 0.4]))
				var r0: float = _rango(d.get("r0", [0.0, 0.2]), _rng) * _k
				var lado: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 0.001 else Vector3.RIGHT
				c["parts"].append({"t": float(d.get("t0", 0.0)) + _rng.randf() * float(d.get("emision", 0.0)), "pos": lado * r0 + Vector3(0, float(d.get("h0", 0.05)) * _k, 0),
					"vel": dir * _rango(d.get("vel", [0.6, 1.4]), _rng) * _k, "vida_k": _rng.randf_range(0.8, 1.2), "tam_k": _rng.randf_range(0.8, 1.2)})
			c["emitidas"] = 0
		"grieta":
			var tam: float = float(d.get("tam", 1.6)) * _k
			var g: MeshInstance3D = TierraToy.crear_quad_suelo("Grieta", tam, tam, SH_GRIETA, {"apertura": 0.0, "vida": 1.0, "semilla": _rng.randf(), "lados": 9,
				"marca_tex": load(TEX_MARCA), "marca_peso": float(d.get("marca", 0.55)), "marca_giro": _rng.randf() * TAU, "color_grieta": Color(0.26, 0.16, 0.09)}, Vector3(0, 0.02, 0), -2)
			g.rotation.y = _rng.randf() * TAU
			_plano.add_child(g)
			c["nodos"].append(g)
		"onda":
			for i in n:
				var q2: QuadMesh = QuadMesh.new()
				q2.size = Vector2.ONE
				q2.orientation = PlaneMesh.FACE_Y
				var mi: MeshInstance3D = MeshInstance3D.new()
				mi.name = "Onda"
				mi.mesh = q2
				mi.material_override = AguaMallas.material(AguaMallas.SH_ONDA, {"anillos": float(d.get("anillos", 2.0)), "charco": float(d.get("charco", 0.4)), "u": 0.0, "vida": 0.0,
					"semilla": _rng.randf(), "se_va": 0.5, "fade_canto": 0.3, "suave_prof": 0.0}, 0)
				mi.position = Vector3(0, 0.025 + 0.004 * i, 0)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.set_meta("t0", float(d.get("t0", 0.0)) + float(d.get("escalonado", 0.0)) * i)
				_plano.add_child(mi)
				c["nodos"].append(mi)
		"luz":
			if (_pal["luz"] as Color).get_luminance() > 0.01:
				var l: OmniLight3D = OmniLight3D.new()
				l.name = "Luz"
				l.light_color = _pal["luz"]
				l.omni_range = float(d.get("rango", 3.4)) * clampf(_k, 0.4, 2.5)
				l.omni_attenuation = 1.4
				l.light_energy = 0.0
				l.shadow_enabled = false
				l.position = Vector3(0, 0.5 * radio, 0)
				_plano.add_child(l)
				c["nodos"].append(l)
	return c


## Dirección `i` de `n` repartidas por igual en la esfera (espiral de Fibonacci), con un giro al azar para que no salgan siempre iguales.
func _dir_esfera(i: int, n: int, giro: float) -> Vector3:
	var y: float = 1.0 - 2.0 * (float(i) + 0.5) / float(maxi(n, 1))
	var s: float = sqrt(maxf(1.0 - y * y, 0.0))
	var fi: float = giro + float(i) * PI * (3.0 - sqrt(5.0))
	return Vector3(cos(fi) * s, y, sin(fi) * s)


## `expande` = [r_ini, r_fin] (m): el sprite sale del foco (su `altura`) hacia fuera, en una dirección de la esfera repartida por igual entre los `n` (explosión que crece desde un punto en todos
## los ángulos, 25/11/2026, Pablo: «debería tener un foco y expandirse uniformemente desde el foco»). `aplasta` < 1 achata la esfera en vertical.
func _montar_sprite(d: Dictionary, i: int = 0) -> MeshInstance3D:
	var tex: String = TEXTURAS.get(String(d.get("tex", "destello")), SpriteToy.T_DESTELLO)
	var aditivo: bool = String(d.get("modo", "aditivo")) == "aditivo" and bool(_pal["aditivo"])
	var modo: int = SpriteToy.Modo.ADITIVO if aditivo else (SpriteToy.Modo.MEZCLA if bool(d.get("plano", false)) else SpriteToy.Modo.MEZCLA_SIN_PROF)
	var params: Dictionary = {"recorte": d.get("recorte", Vector2(0.04, 0.9)), "luminancia": d.get("luminancia", Vector2(0.15, 1.0)), "tramo": d.get("tramo", Vector2(0.5, 1.0)),
		"brillo": float(d.get("brillo", 1.0)), "giro": _rng.randf() * TAU, "vida": 0.0, "centro": float(d.get("centro", 0.0))}
	if String(d.get("tex", "")) == "bola":
		params.merge({"usar_alfa": 1.0, "fb_cols": 5, "fb_filas": 5, "fotograma": 0.0, "fotograma_max": float(SpriteToy.FOTOGRAMAS_FUEGO - 1)}, true)
	var s: MeshInstance3D = SpriteToy.crear("Sprite_" + String(d.get("nombre", "")), tex, modo, bool(d.get("plano", false)), params, int(d.get("prioridad", 3)))
	SpriteToy.mat(s).set_shader_parameter("rampa", _pal["rampa"])
	var disp: float = float(d.get("disperso", 0.0)) * _k
	var off: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0, 1), _rng.randf_range(-1, 1)).normalized() * disp * _rng.randf() if disp > 0.0 else Vector3.ZERO
	s.position = Vector3(0, float(d.get("altura", 0.2)) * radio, 0) + off
	s.set_meta("p0", s.position)
	if d.has("expande"):
		var de: Vector3 = _dir_esfera(i, int(d.get("n", 1)), _giro_esfera)
		de = (de + Vector3(_rng.randf_range(-0.12, 0.12), _rng.randf_range(-0.12, 0.12), _rng.randf_range(-0.12, 0.12))).normalized()
		s.set_meta("dir", Vector3(de.x, de.y * float(d.get("aplasta", 1.0)), de.z))
	s.set_meta("t0", float(d.get("t0", 0.0)) + _rng.randf() * float(d.get("emision", 0.0)))
	s.set_meta("vida", _rango(d.get("vida", 0.3), _rng))
	s.set_meta("tam_k", _rng.randf_range(0.85, 1.15) if int(d.get("n", 1)) > 1 else 1.0)
	s.set_meta("giro0", _rng.randf() * TAU)
	s.scale = Vector3.ZERO
	_plano.add_child(s)
	return s


func _montar_halo(d: Dictionary, i: int) -> MeshInstance3D:
	var plano: bool = bool(d.get("plano", false))
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	if plano:
		q.orientation = PlaneMesh.FACE_Y
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_HALO_PROF if plano else SH_HALO_SIN_PROF)
	m.render_priority = int(d.get("prioridad", -1))
	var col: Color = _pal["halo"]
	if d.has("tono"):                      # un punto de la rampa del elemento (0 oscuro .. 1 claro) en vez del color del halo
		col = (_pal["rampa"] as GradientTexture1D).gradient.sample(float(d["tono"]))
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("brillo", 0.0)
	m.set_shader_parameter("caida", float(d.get("caida", 2.4)))
	m.set_shader_parameter("anillo", float(d.get("anillo", 0.0)))
	m.set_shader_parameter("billboard", 0 if plano else 2)
	m.set_shader_parameter("latido", 0.0)
	if plano:
		m.set_shader_parameter("vida", 1.0)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Halo_" + String(d.get("nombre", ""))
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, (0.03 if plano else float(d.get("altura", 0.45)) * radio), 0)
	mi.set_meta("t0", float(d.get("t0", 0.0)) + float(d.get("escalonado", 0.0)) * float(i))
	mi.set_meta("vida", _rango(d.get("vida", 0.3), _rng))
	mi.set_meta("tam_k", _rng.randf_range(0.85, 1.15) if int(d.get("n", 1)) > 1 else 1.0)
	mi.scale = Vector3.ZERO
	_plano.add_child(mi)
	return mi


## ARO NÍTIDO (aro_choque.gdshader): anillo de borde duro en dos tonos de la rampa (`tono` cuerpo, `tono_filo` banda exterior), entero o en `arcos`. Crece de tam[0] a tam[1] (m, lado del
## quad) mientras su `grosor` pasa de grosor[0] a grosor[1] (fracción del radio). Billboard o, con `plano`, tumbado en la superficie.
func _montar_aro(d: Dictionary, i: int) -> MeshInstance3D:
	var plano: bool = bool(d.get("plano", false))
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	if plano:
		q.orientation = PlaneMesh.FACE_Y
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_ARO)
	m.render_priority = int(d.get("prioridad", 2))
	var gr: Gradient = (_pal["rampa"] as GradientTexture1D).gradient
	m.set_shader_parameter("color", gr.sample(float(d.get("tono", 0.55))))
	m.set_shader_parameter("color_filo", gr.sample(float(d.get("tono_filo", 0.85))))
	m.set_shader_parameter("filo", float(d.get("filo", 0.35)))
	m.set_shader_parameter("arcos", int(d.get("arcos", 0)))
	m.set_shader_parameter("hueco", float(d.get("hueco", 0.35)))
	m.set_shader_parameter("radio", 0.96)
	m.set_shader_parameter("billboard", 0 if plano else 2)
	m.set_shader_parameter("fade_canto", 0.25 if plano else 0.0)
	m.set_shader_parameter("vida", 0.0)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Aro_" + String(d.get("nombre", ""))
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, (0.035 + 0.004 * i if plano else float(d.get("altura", 0.45)) * radio), 0)
	mi.set_meta("t0", float(d.get("t0", 0.0)) + float(d.get("escalonado", 0.0)) * float(i))
	mi.set_meta("vida", _rango(d.get("vida", 0.3), _rng))
	mi.set_meta("tam_k", _rng.randf_range(0.85, 1.15) if int(d.get("n", 1)) > 1 else 1.0)
	mi.set_meta("giro0", _rng.randf() * TAU)
	mi.scale = Vector3.ZERO
	_plano.add_child(mi)
	return mi


## DISTORSIÓN (calor.gdshader, máscara de anillo): una banda que deforma lo que hay detrás y se abre de tam[0] a tam[1] (m). Siempre billboard.
func _montar_distorsion(d: Dictionary, i: int) -> MeshInstance3D:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_CALOR)
	m.render_priority = -3                                   # antes que lo transparente: deforma el fondo, no las llamas
	m.set_shader_parameter("mascara", 2)
	m.set_shader_parameter("billboard", true)
	m.set_shader_parameter("aro", 0.7)
	m.set_shader_parameter("aro_ancho", float(d.get("ancho", 0.16)))
	m.set_shader_parameter("fuerza", float(d.get("fuerza", 0.02)))
	m.set_shader_parameter("intensidad", 0.0)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Distorsion_" + String(d.get("nombre", ""))
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, float(d.get("altura", 0.45)) * radio, 0)
	mi.set_meta("t0", float(d.get("t0", 0.0)) + float(d.get("escalonado", 0.0)) * float(i))
	mi.set_meta("vida", _rango(d.get("vida", 0.3), _rng))
	mi.scale = Vector3.ZERO
	_plano.add_child(mi)
	return mi


## Partículas movidas por la CPU (fórmula cerrada, como ImpactoFuegoToy estilo C): salen de cerca del punto de impacto con una dirección del cono (o del anillo), se frenan con `roce`,
## caen con `g` (× gravedad, hacia abajo del MUNDO) y nunca bajan de la superficie ni del suelo.
func _montar_particulas(c: Dictionary, d: Dictionary, pieza: String, n: int) -> void:
	for i in n:
		var dir: Vector3 = _dir_cono(d.get("cono", [0.3, 1.0]))
		var lado: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 0.001 else Vector3.RIGHT
		var r0: float = _rango(d.get("r0", [0.0, 0.05]), _rng) * _k
		var vel: float = _rango(d.get("vel", [2.0, 5.0]), _rng) * pow(_k, 0.6)
		var brasa: bool = _rng.randf() < float(d.get("brasas", 0.0))
		c["parts"].append({"p0": lado * r0 + Vector3(0, float(d.get("h0", 0.03)) * _k, 0), "v0": dir * vel * (0.45 if brasa else 1.0),
			"t0": float(d.get("t0", 0.0)) + _rng.randf() * float(d.get("emision", 0.0)), "vida": _rango(d.get("vida", [0.3, 0.6]), _rng),
			"largo": _rango(d.get("largo", [0.1, 0.3]), _rng) * pow(_k, 0.35), "ancho": _rango(d.get("ancho", [0.03, 0.05]), _rng) * pow(_k, 0.5), "brasa": brasa,
			"g": float(d.get("g", 0.6)) * GRAVEDAD, "roce": float(d.get("roce", 1.7)), "tono": _rng.randf(),
			"eje": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized(), "vel_ang": _rng.randf_range(4.0, 12.0),
			"rot0": Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU))})
	var mmi: MultiMeshInstance3D
	match pieza:
		"gotas":
			mmi = AguaGotas.crear_mm("Gotas_" + String(d.get("nombre", "")), n)
			if elemento != "agua":                        # gotas de otro elemento: los tres tonos salen de su rampa
				var mg: ShaderMaterial = mmi.material_override as ShaderMaterial
				var gr: Gradient = (_pal["rampa"] as GradientTexture1D).gradient
				mg.set_shader_parameter("tono_a", gr.sample(0.22))
				mg.set_shader_parameter("tono_b", gr.sample(0.62))
				mg.set_shader_parameter("tono_c", gr.sample(1.0))
		"piedras":
			mmi = TierraToy.crear_mm("Piedras_" + String(d.get("nombre", "")), n, TierraToy.Piedras.malla_piedra(), 0.2)
		_:
			mmi = SpriteToy.chispas_mm("Chispas_" + String(d.get("nombre", "")), n, float(d.get("brillo", 1.9)))
			(mmi.material_override as ShaderMaterial).set_shader_parameter("rampa", _pal["rampa"])
			if not bool(_pal["aditivo"]):            # elemento sin luz (tierra): las chispas no se suman, se mezclan
				(mmi.material_override as ShaderMaterial).render_priority = 5
	_plano.add_child(mmi)
	c["mm"] = mmi


func _estado_part(p: Dictionary, t: float, g: Vector3) -> Dictionary:
	var ta: float = t - float(p["t0"])
	var cr: float = float(p["roce"])
	var v0: Vector3 = p["v0"]
	var gg: Vector3 = g * float(p["g"])
	var fr: float = ((1.0 - exp(-cr * ta)) / cr) if cr > 0.001 else ta
	var pos: Vector3 = (p["p0"] as Vector3) + v0 * fr + 0.5 * gg * ta * ta
	var v: Vector3 = (v0 * exp(-cr * ta) if cr > 0.001 else v0) + gg * ta
	var quieta: bool = false
	if pos.y < 0.0:                                    # nunca por debajo de la superficie
		pos.y = 0.0
		v = Vector3.ZERO
		quieta = true
	if is_inside_tree() and suelo_y > -1.0e8:
		var pm: Vector3 = global_transform * (_plano.basis * pos)
		if pm.y < suelo_y:
			pos += (global_transform.basis * _plano.basis).inverse() * Vector3(0, suelo_y - pm.y, 0)
			v = Vector3.ZERO
			quieta = true
	return {"pos": pos, "vel": v, "u": ta / float(p["vida"]), "ta": ta, "quieta": quieta}


# ------------------------------------------------------------------ animación ------------------------------------------------------------------

## Pone todas las capas en el instante `t` (s). `_process` la llama cada fotograma; las capturas pueden llamarla a mano.
func avanzar_a(t: float) -> void:
	if _plano == null:
		return
	var g: Vector3 = _gravedad_local()
	for c in _capas:
		var d: Dictionary = c["def"]
		match String(d.get("pieza", "sprite")):
			"sprite":
				for s in c["nodos"]:
					_animar_sprite(s, d, t)
			"halo":
				for h in c["nodos"]:
					_animar_halo(h, d, t)
			"aro":
				for h in c["nodos"]:
					_animar_aro(h, d, t)
			"distorsion":
				for h in c["nodos"]:
					var ta_d: float = t - float(h.get_meta("t0"))
					var vida_d: float = float(h.get_meta("vida"))
					var tam_d: Array = d.get("tam", [0.4, 1.6])
					var sz_d: float = lerpf(float(tam_d[0]), float(tam_d[1]), _curva(ta_d / vida_d, String(d.get("curva", "sal")))) * _k
					(h as MeshInstance3D).scale = Vector3(sz_d, sz_d, 1.0)
					(h as MeshInstance3D).visible = ta_d >= 0.0 and ta_d <= vida_d
					((h as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("intensidad",
						_fundido(ta_d, vida_d, float(d.get("aparece", 0.03)), float(d.get("se_va", vida_d * 0.6))))
			"chispas", "gotas", "piedras":
				_animar_particulas(c, d, t, g)
			"humo":
				var h2: Node3D = c["humo"]
				var parts: Array = c["parts"]
				var k: int = int(c["emitidas"])
				while k < parts.size() and float((parts[k] as Dictionary)["t"]) <= t:
					var p: Dictionary = parts[k]
					h2.call("emitir", p["pos"], p["vel"], float(p["vida_k"]), float(p["tam_k"]))
					k += 1
				c["emitidas"] = k
			"grieta":
				var gm: ShaderMaterial = (c["nodos"][0] as MeshInstance3D).material_override as ShaderMaterial
				var t0: float = float(d.get("t0", 0.0))
				var vida: float = float(d.get("vida", 1.5))
				gm.set_shader_parameter("apertura", smoothstep(0.0, float(d.get("abre", 0.15)), t - t0))
				gm.set_shader_parameter("vida", _fundido(t - t0, vida, 0.0, float(d.get("se_va", 0.6))))
			"onda":
				for o in c["nodos"]:
					var mi: MeshInstance3D = o
					var ta: float = t - float(mi.get_meta("t0"))
					var vida2: float = float(d.get("vida", 1.0))
					var u: float = clampf(ta / vida2, 0.0, 1.0)
					var tam: float = float(d.get("tam", 1.6)) * _k
					mi.scale = Vector3(tam, 1.0, tam)
					var om: ShaderMaterial = mi.material_override as ShaderMaterial
					om.set_shader_parameter("u", u)
					om.set_shader_parameter("vida", 1.0 if ta >= 0.0 and ta <= vida2 else 0.0)
			"luz":
				for l in c["nodos"]:
					var ta3: float = t - float(d.get("t0", 0.0))
					(l as OmniLight3D).light_energy = float(d.get("energia", 1.5)) * exp(-maxf(ta3, 0.0) * float(d.get("decae", 10.0))) * smoothstep(0.0, 0.012, ta3)


func _animar_sprite(s: MeshInstance3D, d: Dictionary, t: float) -> void:
	var ta: float = t - float(s.get_meta("t0"))
	var vida: float = float(s.get_meta("vida"))
	var u: float = clampf(ta / vida, 0.0, 1.0)
	var a: float = _fundido(ta, vida, float(d.get("aparece", 0.0)), float(d.get("se_va", vida * 0.4)))
	var tam: Array = d.get("tam", [0.4, 1.0])
	var sz: float = lerpf(float(tam[0]), float(tam[1]), _curva(u, String(d.get("curva", "sal")))) * _k * float(s.get_meta("tam_k"))
	s.scale = Vector3(sz, sz, 1.0) if not bool(d.get("plano", false)) else Vector3(sz, 1.0, sz)
	s.position = (s.get_meta("p0") as Vector3) + Vector3(0, float(d.get("sube", 0.0)) * maxf(ta, 0.0) * _k, 0)
	if s.has_meta("dir"):
		var ex: Array = d["expande"]
		s.position += (s.get_meta("dir") as Vector3) * lerpf(float(ex[0]), float(ex[1]), _curva(u, "sal")) * _k
		s.position.y = maxf(s.position.y, 0.35 * sz)          # la parte de abajo de la esfera no se mete en el suelo
	var m: ShaderMaterial = SpriteToy.mat(s)
	m.set_shader_parameter("vida", clampf(a * float(d.get("fuerza", 1.0)), 0.0, 1.0))
	var calor: Array = d.get("calor", [0.0, 0.0])
	m.set_shader_parameter("calor", lerpf(float(calor[0]), float(calor[1]), u))
	m.set_shader_parameter("giro", float(s.get_meta("giro0")) + float(d.get("giro", 0.0)) * maxf(ta, 0.0))
	if String(d.get("tex", "")) == "bola":
		m.set_shader_parameter("fotograma", clampf(u * float(SpriteToy.FOTOGRAMAS_FUEGO), 0.0, float(SpriteToy.FOTOGRAMAS_FUEGO) - 1.001))


func _animar_halo(h: MeshInstance3D, d: Dictionary, t: float) -> void:
	var ta: float = t - float(h.get_meta("t0"))
	var vida: float = float(h.get_meta("vida"))
	var u: float = clampf(ta / vida, 0.0, 1.0)
	var a: float = _fundido(ta, vida, float(d.get("aparece", 0.0)), float(d.get("se_va", vida * 0.6)))
	var tam: Array = d.get("tam", [0.4, 1.0])
	var sz: float = lerpf(float(tam[0]), float(tam[1]), _curva(u, String(d.get("curva", "sal")))) * _k * float(h.get_meta("tam_k"))
	h.scale = Vector3(sz, sz, 1.0) if not bool(d.get("plano", false)) else Vector3(sz, 1.0, sz)
	(h.material_override as ShaderMaterial).set_shader_parameter("brillo", float(d.get("brillo", 1.0)) * a)


func _animar_aro(h: MeshInstance3D, d: Dictionary, t: float) -> void:
	var ta: float = t - float(h.get_meta("t0"))
	var vida: float = float(h.get_meta("vida"))
	var u: float = clampf(ta / vida, 0.0, 1.0)
	var a: float = _fundido(ta, vida, float(d.get("aparece", 0.0)), float(d.get("se_va", vida * 0.5)))
	var tam: Array = d.get("tam", [0.2, 1.6])
	var sz: float = lerpf(float(tam[0]), float(tam[1]), _curva(u, String(d.get("curva", "sal")))) * _k * float(h.get_meta("tam_k"))
	h.scale = Vector3(sz, sz, 1.0) if not bool(d.get("plano", false)) else Vector3(sz, 1.0, sz)
	h.visible = ta >= 0.0 and ta <= vida
	var m: ShaderMaterial = h.material_override as ShaderMaterial
	var gros: Array = d.get("grosor", [0.5, 0.06])
	m.set_shader_parameter("grosor", lerpf(float(gros[0]), float(gros[1]), _curva(u, "sal")))
	m.set_shader_parameter("brillo", float(d.get("brillo", 1.4)))
	m.set_shader_parameter("vida", a)
	m.set_shader_parameter("giro", float(h.get_meta("giro0")) + float(d.get("giro", 0.0)) * maxf(ta, 0.0))


func _animar_particulas(c: Dictionary, d: Dictionary, t: float, g: Vector3) -> void:
	var mmi: MultiMeshInstance3D = c["mm"]
	var mm: MultiMesh = mmi.multimesh
	var pieza: String = String(d.get("pieza", "chispas"))
	var parts: Array = c["parts"]
	for i in parts.size():
		var p: Dictionary = parts[i]
		var e: Dictionary = _estado_part(p, t, g)
		var u: float = float(e["u"])
		var vivo: bool = float(e["ta"]) > 0.0 and u < 1.0
		match pieza:
			"piedras":
				if not vivo:
					HieloMallas.ocultar(mm, i)
					continue
				var rot: Basis = (Basis(p["eje"], float(p["vel_ang"]) * float(e["ta"]) * (0.0 if bool(e["quieta"]) else 1.0)) * (p["rot0"] as Basis)).orthonormalized()
				var s: float = float(p["ancho"]) * (1.0 - smoothstep(0.75, 1.0, u)) * 2.0 / TierraToy.lado_malla(mm.mesh)
				mm.set_instance_transform(i, TierraToy.centrar(mm.mesh, rot * Basis.from_scale(Vector3.ONE * s), e["pos"]))
				mm.set_instance_custom_data(i, Color(float(p["tono"]), 1.0, 0.0, 0.0))
			"gotas":
				if not vivo:
					AguaGotas.poner(mm, i, Vector3.ZERO, Vector3.DOWN, 0.0, 0.0, 0.0, 0.0, false)
					continue
				var v: Vector3 = e["vel"]
				var alfa: float = smoothstep(0.0, 0.06, u) * (1.0 - smoothstep(0.6, 1.0, u))
				var largo: float = float(p["largo"]) * clampf(v.length() / maxf((p["v0"] as Vector3).length(), 0.001), 0.35, 1.0)
				AguaGotas.poner(mm, i, e["pos"], v.normalized() if v.length() > 0.01 else Vector3.DOWN, largo, float(p["ancho"]) * (1.0 - 0.3 * u), float(p["tono"]), alfa, bool(p["brasa"]))
			_:
				if not vivo:
					SpriteToy.poner_chispa(mm, i, Vector3.ZERO, Vector3.UP, 0.0, 0.0, 0.0, 0.0, false)
					continue
				var v2: Vector3 = e["vel"]
				var brasa: bool = bool(p["brasa"])
				var alfa2: float = smoothstep(0.0, 0.06, u) * (1.0 - smoothstep(0.55, 1.0, u))
				var calor: float = clampf((1.0 - 0.6 * u) if not brasa else (0.6 - 0.45 * u), 0.0, 1.0)
				var largo2: float = float(p["largo"]) * clampf(v2.length() / maxf((p["v0"] as Vector3).length(), 0.001), 0.3, 1.0) * (1.0 - 0.5 * u * u)
				SpriteToy.poner_chispa(mm, i, e["pos"], v2.normalized() if v2.length() > 0.01 else Vector3.UP, largo2, float(p["ancho"]) * (1.0 - 0.4 * u), calor, alfa2, brasa)
