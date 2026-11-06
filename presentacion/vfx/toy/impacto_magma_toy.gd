class_name ImpactoMagmaToy
extends Node3D

## IMPACTO DEL MAGMA «TOY» (6/11/2026; el equivalente de ImpactoFuegoToy / ImpactoRayoToy; concepto de Pablo en docs/capturas/referencias/magma_concepto/). Misma API:
## `crear(variante, normal, radio)`, `tiempo()`, `duracion()`, `avanzar_a(t)`, `lanzar()` / `morir()` (contrato de EfectoVfx3D). Todo se libera solo.
## Lo que lleva (GOLPE, contra una pared o el suelo; `normal` = normal de la superficie hacia fuera):
##   · DESTELLO corto (hit22 de ImpactoFuegoToy, ~0,1 s), un halo pequeño y UNA luz naranja que se apaga en 0,3 s.
##   · ESQUIRLAS: de 6 a 10 trozos de roca (MultiMesh con la malla `piedra_est_magma_2` y el MISMO material que la bola, magma_roca.gdshader, con el calor por instancia) que salen
##     hacia fuera en el hemisferio de la normal, GIRAN, CAEN con la gravedad, REBOTAN una vez en la superficie y se enfrían de 1 a 0 en ~1 s (amarillo → rojo → gris); al final se encogen.
##     No son GPUParticles3D: la CPU las mueve y `esquirlas_estado()` las mide.
##   · CRÁTER (solo en el suelo o la pared, no en la FIN): un quad con grietas radiales emisivas (grietas_magma.gdshader) que pasa de amarillo a rojo a gris en T_ENFRIAR s y se desvanece en
##     T_CRATER s, y PÉTALOS DE ROCA alrededor (4-6 piedras de magma inclinadas hacia fuera, con el mismo material) que se enfrían con él y se hunden al final. El color de la costra de
##     ArteEntorno3D es el mismo (las mismas piedras y texturas).
##   · BRASAS: unas pocas chispas redondas (MultiMesh de SpriteToy, tramo bajo de la rampa: naranja-rojo) que caen.
## Variantes: GOLPE (todo), FIN (el hechizo se agota en el aire: unas brasas y 3 esquirlas que caen, sin cráter), REBOTE (4 esquirlas y un destello pequeño, sin cráter; la bola sigue),
## AREA (zona: cráter grande y más esquirlas, normal arriba). TAMAÑO: `radio` = radio de la bola que choca (m; referencia 0,4; el AREA, 1,8).

const SpriteToy = preload("res://presentacion/vfx/toy/sprite_toy.gd")

enum Variante { GOLPE, FIN, REBOTE, AREA }

const SH_ROCA: String = "res://presentacion/vfx/toy/magma_roca.gdshader"
const SH_GRIETAS: String = "res://presentacion/vfx/toy/grietas_magma.gdshader"
const SH_HALO_I: String = "res://presentacion/vfx/toy/halo_impacto.gdshader"
const RUTA_PIEDRA: String = "res://arte/meshy/piezas/piedra_est_magma_%d.glb"
const TEX_ALBEDO: String = "res://arte/meshy/piezas/tex_rocas_est/rocas_magma_albedo.png"
const TEX_EMISIVO: String = "res://arte/meshy/piezas/tex_rocas_est/rocas_magma_emisivo.png"

## Por variante: nº de esquirlas, nº de brasas, tamaño del destello (× radio), energía de la luz, cráter sí/no, duración (s).
const PARAMS: Dictionary = {
	Variante.GOLPE: {"esquirlas": 8, "brasas": 10, "dest": 2.4, "luz": 1.6, "crater": true, "dur": 3.2},
	Variante.FIN: {"esquirlas": 3, "brasas": 6, "dest": 0.0, "luz": 0.4, "crater": false, "dur": 1.4},
	Variante.REBOTE: {"esquirlas": 4, "brasas": 4, "dest": 1.4, "luz": 0.8, "crater": false, "dur": 1.3},
	Variante.AREA: {"esquirlas": 12, "brasas": 16, "dest": 2.6, "luz": 2.0, "crater": true, "dur": 3.4}}
const GRAVEDAD: float = 9.8
const T_FLASH: float = 0.1
const T_LUZ: float = 0.3
const T_ESQUIRLA: float = 1.0           ## s en que una esquirla pasa de calor 1 a 0
const T_ESQUIRLA_FIN: float = 1.25      ## s en que se ha encogido y ya no se ve
const T_ENFRIAR: float = 2.0            ## s en que el cráter pasa de amarillo a gris
const T_CRATER: float = 3.0             ## s en que el cráter se ha desvanecido
const REBOTE_K: float = 0.32            ## cuánto conserva la esquirla al rebotar
const COS_SUELO: float = 0.7
const N_PETALOS: int = 5

static var _mallas: Dictionary = {}     ## índice → Mesh (las piedras de magma, cargadas una vez)

@export var variante: Variante = Variante.GOLPE
@export var normal: Vector3 = Vector3.UP
@export_range(0.05, 4.0, 0.01, "or_greater") var radio: float = 0.4
## Altura (m) bajo el punto de la FIN a la que se supone el suelo: las esquirlas que caen hasta ahí se paran.
@export var altura_suelo: float = 0.7

var _t: float = -1.0
var _p: Dictionary = {}
var _dur: float = 1.0
var _plano: Node3D = null
var _esq_mm: MultiMeshInstance3D = null
var _esq: Array = []                    ## [{p, v, eje, giro, ang, tam, calor, rebotado}] en el espacio local del plano
var _pet_mm: MultiMeshInstance3D = null
var _pet: Array = []                    ## pétalos: [{p, rot, tam}]
var _crater: MeshInstance3D = null
var _mat_crater: ShaderMaterial = null
var _destello: MeshInstance3D = null
var _mat_halo: ShaderMaterial = null
var _luz: OmniLight3D = null
var _brasas_mm: MultiMeshInstance3D = null
var _brasas: Array = []                 ## [{p0, v0, vida, tam, retraso}]
var _giro0: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func crear(var_: Variante, normal_: Vector3, radio_: float) -> ImpactoMagmaToy:
	var i: ImpactoMagmaToy = ImpactoMagmaToy.new()
	i.configurar(var_, normal_, radio_)
	return i


## Se llama ANTES de añadirlo al árbol. La FIN y el AREA siempre suben (normal arriba).
func configurar(var_: Variante, normal_: Vector3, radio_: float) -> void:
	variante = var_
	normal = Vector3.UP if var_ == Variante.FIN or var_ == Variante.AREA or normal_.length() < 0.001 else normal_.normalized()
	radio = maxf(radio_, 0.05)


## La malla de la piedra de magma `i` (0..4), cargada del GLB una vez (compartida con MagmaToy).
static func malla_piedra(i: int) -> Mesh:
	i = clampi(i, 0, 4)
	if _mallas.has(i):
		return _mallas[i]
	var m: Mesh = null
	var ps: PackedScene = load(RUTA_PIEDRA % i) as PackedScene
	if ps != null:
		var n: Node = ps.instantiate()
		var mi: MeshInstance3D = n if n is MeshInstance3D else (n.find_children("*", "MeshInstance3D", true, false)[0] if not n.find_children("*", "MeshInstance3D", true, false).is_empty() else null)
		if mi != null:
			m = mi.mesh
		n.free()
	if m == null:
		var s: SphereMesh = SphereMesh.new()
		s.radius = 0.35
		s.height = 0.7
		s.radial_segments = 8
		s.rings = 4
		m = s
	_mallas[i] = m
	return m


## La BOLA de magma: una esfera de pocos polígonos (14 × 8) con el relieve desplazado por un ruido continuo y las caras PLANAS (sin índices, normal por triángulo): se lee como una roca de
## celdas, no como una bola lisa ni como una gema. Las UV se llevan a las rocas de abajo a la izquierda del atlas rocas_magma_* (u 0,02-0,30, v 0,68-0,98: vetas gruesas y claras sobre negro;
## el recuadro grande de arriba se probó y es tan denso que la bola salía naranja entera), repetido dos veces alrededor. Se calcula una vez (compartida).
static func malla_bola() -> ArrayMesh:
	if _mallas.has("bola"):
		return _mallas["bola"]
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 11
	sm.rings = 7
	var a: Array = sm.get_mesh_arrays()
	var v0: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv0: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	for t in range(0, idx.size(), 3):
		var p: Array = []
		for j in 3:
			var v: Vector3 = v0[idx[t + j]]
			var n: Vector3 = v.normalized()
			# terrones: ruido continuo de tres octavas, con amplitud alta y el vértice también desplazado de lado (rompe la rejilla regular de la esfera)
			var ruido: float = 0.11 * sin(3.1 * n.x + 1.7) * sin(2.7 * n.y + 0.4) + 0.09 * sin(5.2 * n.z + 2.6 * n.x + 0.9) + 0.06 * sin(9.0 * n.y - 4.0 * n.z + 7.0 * n.x)
			var lado: Vector3 = Vector3(sin(7.0 * n.y + 2.0), sin(6.0 * n.z + 1.0), sin(8.0 * n.x + 3.0)) * 0.05
			p.append((n * 0.5 * (1.0 + ruido) + lado).limit_length(0.62))
		var fn: Vector3 = ((p[1] as Vector3) - (p[0] as Vector3)).cross((p[2] as Vector3) - (p[0] as Vector3)).normalized()
		var centro: Vector3 = ((p[0] as Vector3) + (p[1] as Vector3) + (p[2] as Vector3)) / 3.0
		if fn.dot(centro) < 0.0:
			fn = -fn                                                   # la normal plana siempre hacia fuera (si no, la luz de dentro de la bola la enciende entera)
		for j in 3:
			verts.append(p[j])
			norms.append(fn)
			var u: Vector2 = uv0[idx[t + j]]
			uvs.append(Vector2(0.02 + 0.28 * fposmod(u.x * 2.0, 1.0), 0.68 + 0.30 * u.y))
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var m: ArrayMesh = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_mallas["bola"] = m
	return m


## Lado mayor (x/z) de la huella de una malla, sin escalar.
static func lado_malla(m: Mesh) -> float:
	if m == null:
		return 1.0
	var s: Vector3 = m.get_aabb().size
	return maxf(s.x, s.z)


## Material de roca de magma (magma_roca.gdshader) con las texturas de las rocas estilizadas. `por_instancia`: el calor sale de INSTANCE_CUSTOM.r.
static func material_roca(por_instancia: bool) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_ROCA)
	m.set_shader_parameter("albedo_tex", load(TEX_ALBEDO))
	m.set_shader_parameter("emisivo_tex", load(TEX_EMISIVO))
	m.set_shader_parameter("por_instancia", por_instancia)
	m.set_shader_parameter("calor", 1.0)
	return m


## Un MultiMesh de `n` piedras (malla `idx`) con el material de roca por instancia, todas ocultas.
static func piedras_mm(nombre: String, n: int, idx: int) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = malla_piedra(idx)
	mm.instance_count = n
	for i in n:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nombre
	mi.multimesh = mm
	mi.material_override = material_roca(true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -12.0, Vector3.ONE * 24.0)
	return mi


func _ready() -> void:
	_p = PARAMS[variante]
	_dur = float(_p["dur"])
	_giro0 = randf() * TAU
	_rng.randomize()
	_construir()


func lanzar(_v: float = -1.0) -> void:
	pass


func morir() -> void:
	queue_free()


func tiempo() -> float:
	return maxf(_t, 0.0)


func duracion() -> float:
	if not _p.is_empty():
		return _dur
	return float(PARAMS[variante]["dur"])


func es_suelo() -> bool:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	return variante != Variante.FIN and n.dot(Vector3.UP) >= COS_SUELO


func _base_normal() -> Basis:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	if n.dot(Vector3.UP) < -0.999:
		return Basis(Quaternion(Vector3.RIGHT, PI))
	return Basis(Quaternion(Vector3.UP, n))


# ------------------------------------------------------------------ construcción ------------------------------------------------------------------

func _construir() -> void:
	var r: float = radio
	var k: float = pow(r / 0.4, 0.7)
	_plano = Node3D.new()
	_plano.name = "Plano"
	_plano.basis = _base_normal()
	add_child(_plano)
	# esquirlas
	var n_e: int = int(_p["esquirlas"])
	for i in n_e:
		var ang: float = TAU * float(i) / float(n_e) + _rng.randf_range(-0.3, 0.3)
		var alto: float = _rng.randf_range(0.25, 0.95) if variante != Variante.FIN else _rng.randf_range(-0.6, 0.4)
		var lado: float = sqrt(maxf(1.0 - alto * alto, 0.0))
		var dir: Vector3 = Vector3(cos(ang) * lado, alto, sin(ang) * lado)
		var eje: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
		_esq.append({"p": dir * r * 0.3 + Vector3(0, 0.05 * k, 0), "v": dir * _rng.randf_range(2.2, 4.6) * k, "eje": eje, "giro": _rng.randf_range(6.0, 14.0), "ang": _rng.randf() * TAU,
			"tam": r * _rng.randf_range(0.28, 0.5), "calor": 1.0, "rebotado": false, "idx": i})
	if n_e > 0:
		_esq_mm = piedras_mm("Esquirlas", n_e, 2)
		_plano.add_child(_esq_mm)
	# cráter y pétalos
	if bool(_p["crater"]):
		var rc: float = clampf(r * 3.6, 0.6, 2.6) if variante != Variante.AREA else r * 1.15
		var pm: PlaneMesh = PlaneMesh.new()
		pm.size = Vector2(2.0 * rc, 2.0 * rc)
		_crater = MeshInstance3D.new()
		_crater.name = "Crater"
		_crater.mesh = pm
		_mat_crater = ShaderMaterial.new()
		_mat_crater.shader = load(SH_GRIETAS)
		_mat_crater.render_priority = -2
		_mat_crater.set_shader_parameter("semilla", _rng.randf())
		_mat_crater.set_shader_parameter("brazos", 7 if variante != Variante.AREA else 9)
		_mat_crater.set_shader_parameter("calor", 1.0)
		_mat_crater.set_shader_parameter("vida", 1.0)
		_crater.material_override = _mat_crater
		_crater.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_crater.position = Vector3(0, 0.025, 0)
		_crater.rotation.y = _giro0
		_plano.add_child(_crater)
		var np: int = N_PETALOS if variante != Variante.AREA else 8
		for j in np:
			var a: float = TAU * float(j) / float(np) + _rng.randf_range(-0.2, 0.2)
			var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
			var rot: Basis = Basis(Vector3.UP, a + PI * 0.5).rotated(d.cross(Vector3.UP).normalized(), _rng.randf_range(-0.9, -0.5))    # inclinado hacia fuera: pétalo abierto
			_pet.append({"p": d * rc * _rng.randf_range(0.42, 0.6), "rot": rot, "tam": rc * _rng.randf_range(0.22, 0.34)})
		_pet_mm = piedras_mm("Petalos", np, 3)
		_plano.add_child(_pet_mm)
	# brasas
	var n_b: int = int(_p["brasas"])
	for i in n_b:
		var ang2: float = _rng.randf() * TAU
		var alto2: float = _rng.randf_range(0.3, 1.0)
		var lado2: float = sqrt(1.0 - alto2 * alto2)
		var dir2: Vector3 = Vector3(cos(ang2) * lado2, alto2, sin(ang2) * lado2)
		_brasas.append({"p0": Vector3(0, 0.04, 0), "v0": dir2 * _rng.randf_range(1.2, 3.4) * k, "vida": _rng.randf_range(0.35, 0.7), "tam": _rng.randf_range(0.05, 0.1) * sqrt(maxf(r / 0.4, 0.4)), "retraso": _rng.randf_range(0.0, 0.05)})
	if n_b > 0:
		_brasas_mm = SpriteToy.chispas_mm("Brasas", n_b, 1.3)
		(_brasas_mm.material_override as ShaderMaterial).set_shader_parameter("tramo", Vector2(0.15, 0.55))     # tramo bajo de la rampa: rojo-naranja, no amarillo
		_plano.add_child(_brasas_mm)
	# destello, halo y luz
	var fl: float = float(_p["dest"])
	if fl > 0.0:
		_destello = SpriteToy.crear("Destello", SpriteToy.T_DESTELLO, SpriteToy.Modo.ADITIVO, false,
			{"recorte": Vector2(0.04, 0.9), "luminancia": Vector2(0.2, 1.0), "tramo": Vector2(0.35, 0.8), "brillo": 1.0, "giro": _giro0 * 0.5, "vida": 0.0}, 4)
		_destello.position = Vector3(0, 0.25 * r, 0)
		_destello.set_meta("tam", fl * r)
		_plano.add_child(_destello)
	var hq: QuadMesh = QuadMesh.new()
	hq.size = Vector2(3.2 * r, 3.2 * r)
	var hmi: MeshInstance3D = MeshInstance3D.new()
	hmi.name = "Halo"
	hmi.mesh = hq
	_mat_halo = ShaderMaterial.new()
	_mat_halo.shader = load(SH_HALO_I)
	_mat_halo.render_priority = -1
	_mat_halo.set_shader_parameter("brillo", 0.0)
	_mat_halo.set_shader_parameter("caida", 2.6)
	_mat_halo.set_shader_parameter("billboard", 2)
	_mat_halo.set_shader_parameter("color", Color(1.0, 0.32, 0.06))
	_mat_halo.set_shader_parameter("latido", 0.0)
	hmi.material_override = _mat_halo
	hmi.position = Vector3(0, 0.4 * r, 0)
	hmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plano.add_child(hmi)
	_luz = OmniLight3D.new()
	_luz.name = "Luz"
	_luz.light_color = Color(1.0, 0.45, 0.14)
	_luz.omni_attenuation = 1.4
	_luz.omni_range = 3.4 * clampf(r / 0.4, 0.4, 2.5)
	_luz.light_energy = 0.0
	_luz.shadow_enabled = false
	_luz.position = Vector3(0, 0.45 * r, 0)
	_plano.add_child(_luz)
	avanzar_a(0.0)


# ------------------------------------------------------------------ animación ------------------------------------------------------------------

func _process(delta: float) -> void:
	if _p.is_empty():
		return
	if _t < 0.0:
		_t = 0.0
	_t += delta
	_avanzar_esquirlas(delta)
	avanzar_a(_t)
	if _t >= _dur:
		queue_free()


func _gravedad_local() -> Vector3:
	var b: Basis = _plano.basis if _plano != null else _base_normal()
	if is_inside_tree():
		b = global_transform.basis * b
	return b.inverse() * Vector3(0, -GRAVEDAD, 0)


## Mueve las esquirlas (integración simple: gravedad, un rebote en la superficie, giro) y las enfría.
func _avanzar_esquirlas(delta: float) -> void:
	if _esq_mm == null:
		return
	var g: Vector3 = _gravedad_local()
	var piso: float = 0.0 if variante != Variante.FIN else -altura_suelo
	var mm: MultiMesh = _esq_mm.multimesh
	for i in _esq.size():
		var s: Dictionary = _esq[i]
		var v: Vector3 = (s["v"] as Vector3) + g * delta
		var p: Vector3 = (s["p"] as Vector3) + v * delta
		var tam: float = float(s["tam"])
		if p.y < piso + tam * 0.5:
			p.y = piso + tam * 0.5
			if not bool(s["rebotado"]):
				v = Vector3(v.x * 0.6, absf(v.y) * REBOTE_K, v.z * 0.6)
				s["rebotado"] = true
				s["giro"] = float(s["giro"]) * 0.4
			else:
				v = Vector3(v.x * 0.85, 0.0, v.z * 0.85)         # se arrastra un poco y se para
				s["giro"] = float(s["giro"]) * 0.8
		s["v"] = v
		s["p"] = p
		s["ang"] = float(s["ang"]) + float(s["giro"]) * delta
		s["calor"] = clampf(1.0 - _t / T_ESQUIRLA, 0.0, 1.0)
		var enc: float = 1.0 - smoothstep(T_ESQUIRLA, T_ESQUIRLA_FIN, _t)      # al final se encoge y desaparece
		var b: Basis = Basis(s["eje"] as Vector3, float(s["ang"])).scaled(Vector3.ONE * tam * enc)
		mm.set_instance_transform(i, Transform3D(b, p - b * Vector3(0, 0.3, 0)))   # la malla tiene la base en el origen: se centra
		mm.set_instance_custom_data(i, Color(float(s["calor"]), 1.0, 0.0, 0.0))


## Pone el destello, la luz, el cráter, los pétalos y las brasas como en el instante `t` (s desde el impacto). Las esquirlas van en `_avanzar_esquirlas` (no tienen fórmula cerrada: rebotan).
func avanzar_a(t: float) -> void:
	if _p.is_empty() or _plano == null:
		return
	var r: float = radio
	var u: float = clampf(t / T_FLASH, 0.0, 1.0)
	if _destello != null and is_instance_valid(_destello):
		var tam: float = float(_destello.get_meta("tam", r)) * lerpf(0.5, 1.15, sqrt(u))
		_destello.scale = Vector3(tam, tam, tam)
		SpriteToy.mat(_destello).set_shader_parameter("vida", (1.0 - u) if u < 1.0 else 0.0)
	var ul: float = clampf(t / T_LUZ, 0.0, 1.0)
	if _luz != null:
		_luz.light_energy = float(_p["luz"]) * pow(1.0 - ul, 1.6)
		_luz.visible = _luz.light_energy > 0.01
	if _mat_halo != null:
		_mat_halo.set_shader_parameter("brillo", 0.45 * pow(1.0 - ul, 1.4))
	var calor_c: float = calor_crater(t)
	if _mat_crater != null:
		_mat_crater.set_shader_parameter("calor", calor_c)
		_mat_crater.set_shader_parameter("vida", smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(T_ENFRIAR, T_CRATER, t)))
	if _pet_mm != null:
		var mm: MultiMesh = _pet_mm.multimesh
		var sal: float = smoothstep(0.0, 0.12, t)                                 # los pétalos se levantan en 0,12 s
		var hunde: float = smoothstep(T_ENFRIAR, T_CRATER, t)                     # y al final se hunden en el suelo
		for j in _pet.size():
			var q: Dictionary = _pet[j]
			var tam2: float = float(q["tam"]) * sal
			var b: Basis = (q["rot"] as Basis).scaled(Vector3.ONE * tam2)
			mm.set_instance_transform(j, Transform3D(b, (q["p"] as Vector3) + Vector3(0, -tam2 * 0.15 - hunde * tam2 * 1.2, 0)))
			mm.set_instance_custom_data(j, Color(calor_c * 0.9, 1.0, 0.0, 0.0))
	if _brasas_mm != null:
		var g: Vector3 = _gravedad_local()
		var mmb: MultiMesh = _brasas_mm.multimesh
		for i in _brasas.size():
			var d: Dictionary = _brasas[i]
			var ta: float = t - float(d["retraso"])
			if ta <= 0.0 or ta >= float(d["vida"]):
				SpriteToy.poner_chispa(mmb, i, Vector3.ZERO, Vector3.UP, 0.0, 0.0, 0.0, 0.0, true)
				continue
			var p: Vector3 = (d["p0"] as Vector3) + (d["v0"] as Vector3) * ta + 0.5 * g * ta * ta
			var v: Vector3 = (d["v0"] as Vector3) + g * ta
			if variante != Variante.FIN and p.y < 0.0:
				p.y = 0.0
			var ub: float = ta / float(d["vida"])
			SpriteToy.poner_chispa(mmb, i, p, v.normalized(), 0.0, float(d["tam"]) * (1.0 - 0.4 * ub), 0.9 - 0.8 * ub, 1.0 - smoothstep(0.5, 1.0, ub), true)


## Calor del cráter en `t`: 1 (amarillo) → 0 (gris) en T_ENFRIAR s.
static func calor_crater(t: float) -> float:
	return clampf(1.0 - t / T_ENFRIAR, 0.0, 1.0)


# ------------------------------------------------------------------ medición (pruebas) ------------------------------------------------------------------

## Una entrada por esquirla: {pos (mundo), vel (mundo), altura (sobre la superficie), calor, tam, rebotado}.
func esquirlas_estado() -> Array:
	var res: Array = []
	for s in _esq:
		var p: Vector3 = s["p"]
		res.append({"pos": global_transform * (_plano.basis * p), "vel": global_transform.basis * (_plano.basis * (s["v"] as Vector3)), "altura": p.y, "calor": float(s["calor"]), "tam": float(s["tam"]), "rebotado": bool(s["rebotado"])})
	return res


func crater() -> MeshInstance3D:
	return _crater


func petalos() -> int:
	return _pet.size()


## (esquirlas, brasas) que lleva.
func recuento() -> Array:
	return [_esq.size(), _brasas.size()]
