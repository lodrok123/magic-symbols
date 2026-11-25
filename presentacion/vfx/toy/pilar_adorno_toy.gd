extends Node3D

## ADORNO DEL PILAR DE FUEGO (25/11/2026, revisión de formas con Effekseer: «la columna sube recta y sola, sin movimiento alrededor»). Lo que aportan ef_holy01 y ef_wind03:
##   · BRASAS EN ESPIRAL: puntos de chispa que suben girando alrededor de la columna (holy01: partículas que orbitan; wind03: espirales), se abren un poco y se apagan arriba.
##   · AROS QUE LATEN en la base: aros nítidos (aro_choque.gdshader, el de los impactos) que salen del pie cada PERIODO s, se abren y se apagan (wind03: groundAura).
## Todo con la rampa de la bola de FuegoToy por su tramo rojo-naranja (nunca amarillo) y sin luz. Cuelga del FuegoToy y lee su `crece` / `corte`: sale con el pilar y se va con él.
## Sin class_name: preload("res://presentacion/vfx/toy/pilar_adorno_toy.gd").

const SpriteToy = preload("res://presentacion/vfx/toy/sprite_toy.gd")
const SH_ARO: String = "res://presentacion/vfx/toy/aro_choque.gdshader"
const N_BRASAS: int = 26
const VUELTAS_S: float = 0.9          ## vueltas por segundo de la espiral
const SUBE_S: float = 1.6             ## s que tarda una brasa en subir todo el pilar
const N_AROS: int = 2
const PERIODO: float = 0.75           ## s entre aro y aro
const VIDA_ARO: float = 0.6
const TONO_ARO: Vector2 = Vector2(0.28, 0.58)      ## puntos de la rampa: cuerpo y filo (rojo → naranja)

var radio: float = 0.5
var alto: float = 4.0
var dueno: Node3D = null

var _t: float = 0.0
var _mm: MultiMeshInstance3D = null
var _brasas: Array = []               ## [{fase (0..1 a lo largo de la subida), ang0, r_k, tam}]
var _aros: Array = []                 ## MeshInstance3D


static func crear(dueno_: Node3D, radio_: float, alto_: float) -> Node3D:
	var a: Node3D = (load("res://presentacion/vfx/toy/pilar_adorno_toy.gd") as GDScript).new()
	a.dueno = dueno_
	a.radio = maxf(radio_, 0.1)
	a.alto = maxf(alto_, 0.3)
	a.name = "Adorno"
	return a


func _ready() -> void:
	FuegoToy._rampas()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 91
	_mm = SpriteToy.chispas_mm("BrasasEspiral", N_BRASAS, 1.6)
	(_mm.material_override as ShaderMaterial).set_shader_parameter("rampa", FuegoToy._rampa_bola)
	add_child(_mm)
	for i in N_BRASAS:
		_brasas.append({"fase": float(i) / float(N_BRASAS) + rng.randf_range(-0.02, 0.02), "ang0": TAU * float(i % 2) * 0.5 + rng.randf_range(-0.3, 0.3),
			"r_k": rng.randf_range(1.05, 1.35), "tam": rng.randf_range(0.6, 1.1)})
	var gr: Gradient = (FuegoToy._rampa_bola as GradientTexture1D).gradient
	for k in N_AROS:
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2.ONE
		q.orientation = PlaneMesh.FACE_Y
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = load(SH_ARO)
		m.render_priority = 1
		m.set_shader_parameter("color", gr.sample(TONO_ARO.x))
		m.set_shader_parameter("color_filo", gr.sample(TONO_ARO.y))
		m.set_shader_parameter("radio", 0.96)
		m.set_shader_parameter("billboard", 0)
		m.set_shader_parameter("fade_canto", 0.25)
		m.set_shader_parameter("vida", 0.0)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "AroBase%d" % k
		mi.mesh = q
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0, 0.04 + 0.005 * float(k), 0)
		add_child(mi)
		_aros.append(mi)


## Cuánto se ve (0..1): crece con el pilar y se va cuando empieza a morir.
func intensidad() -> float:
	if dueno == null or not is_instance_valid(dueno):
		return 0.0
	var cr: float = clampf(float(dueno.get("crece")) if dueno.get("crece") != null else 1.0, 0.0, 1.0)
	var co: float = clampf(float(dueno.get("corte")) if dueno.get("corte") != null else 0.0, 0.0, 1.0)
	return smoothstep(0.5, 1.0, cr) * (1.0 - smoothstep(0.0, 0.35, co))


func _process(delta: float) -> void:
	_t += delta
	var k: float = intensidad()
	var mm: MultiMesh = _mm.multimesh
	for i in _brasas.size():
		var b: Dictionary = _brasas[i]
		var u: float = fposmod(float(b["fase"]) + _t / SUBE_S, 1.0)
		var ang: float = float(b["ang0"]) + TAU * VUELTAS_S * _t + u * TAU * 1.2
		var r: float = radio * float(b["r_k"]) * lerpf(0.9, 1.4, u)
		var pos: Vector3 = Vector3(cos(ang) * r, u * alto * 0.95, sin(ang) * r)
		var dir: Vector3 = Vector3(-sin(ang), 0.55, cos(ang)).normalized()
		var alfa: float = k * smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.7, 1.0, u))
		SpriteToy.poner_chispa(mm, i, pos, dir, 0.26 * float(b["tam"]) * sqrt(radio / 0.5), 0.075 * float(b["tam"]) * sqrt(radio / 0.5), 0.5 - 0.35 * u, alfa, false)
	for j in _aros.size():
		var mi: MeshInstance3D = _aros[j]
		var ta: float = fposmod(_t - float(j) * PERIODO / float(N_AROS), PERIODO)
		var u2: float = clampf(ta / VIDA_ARO, 0.0, 1.0)
		var sz: float = radio * lerpf(1.6, 5.0, 1.0 - pow(1.0 - u2, 2.0))
		mi.scale = Vector3(sz, 1.0, sz)
		var m: ShaderMaterial = mi.material_override as ShaderMaterial
		m.set_shader_parameter("grosor", lerpf(0.14, 0.03, u2))
		m.set_shader_parameter("vida", k * (1.0 - smoothstep(0.55, 1.0, u2)) * smoothstep(0.0, 0.08, u2) * 0.6)
