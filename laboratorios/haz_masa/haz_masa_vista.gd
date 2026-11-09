class_name HazMasaVista
extends Node3D

## DIBUJO DE LA MASA DE FUEGO DEL HAZ (prototipo, docs/HAZ_FUEGO_VS_DEMO_2026-11-09.md): mueve un HazMasaSim y lo pinta con dos MultiMesh (bocanadas billboard con haz_masa.gdshader y chispas
## estiradas con el chispa_impacto.gdshader del juego). Es un nodo PROPIO (cuelga de la escena, no del toy: el dragon relanza el haz cada 0,8 s y el toy se rehace) que se alimenta con
## `alimentar()` cada fotograma que haya un haz vivo y, al dejar de recibirlo, deja de emitir en `GRACIA` s (la emision baja en rampa) y se borra solo cuando no queda nada.
## Va en el origen del mundo (identidad): las posiciones de la simulacion son de mundo.

const SpriteToy = preload("res://presentacion/vfx/toy/sprite_toy.gd")
const SH: String = "res://laboratorios/haz_masa/haz_masa.gdshader"
const TEX: String = "res://assets/vfx/lelu_noise/"
const GRACIA: float = 1.2                ## s de emision que sobreviven al ultimo haz
const AUTOBORRAR: bool = true

var sim: HazMasaSim = HazMasaSim.new()
var _mm: MultiMesh = null
var _chispas: MultiMeshInstance3D = null
var _desde_alimento: float = 99.0
var _ya_alimentado: bool = false
var visible_masa: bool = true


func _ready() -> void:
	FuegoToy._rampas()
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	_mm.mesh = q
	_mm.instance_count = HazMasaSim.MAX_BOCANADAS
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH)
	m.render_priority = 2
	m.set_shader_parameter("lenguas", load(TEX + "T_FirePanningCyl45.png"))
	m.set_shader_parameter("ruido_a", load(TEX + "T_PerlinNoise_Tiled.png"))
	m.set_shader_parameter("rampa", FuegoToy._rampa_de_bola())
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = "Bocanadas"
	mi.multimesh = _mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -30.0, Vector3.ONE * 60.0)
	add_child(mi)
	_chispas = SpriteToy.chispas_mm("Chispas", HazMasaSim.MAX_CHISPAS, 1.4)
	add_child(_chispas)
	_pintar()


## Hay un haz vivo este fotograma.
func alimentar() -> void:
	_desde_alimento = 0.0
	_ya_alimentado = true


func _process(delta: float) -> void:
	_desde_alimento += delta
	var f: float = clampf(1.0 - _desde_alimento / GRACIA, 0.0, 1.0) if _ya_alimentado else 0.0
	sim.paso(delta, f)
	_pintar()
	if AUTOBORRAR and _ya_alimentado and f <= 0.0 and sim.n == 0 and _desde_alimento > GRACIA + 0.5:
		queue_free()


func _pintar() -> void:
	if _mm == null:
		return
	for i in HazMasaSim.MAX_BOCANADAS:
		if i < sim.n and visible_masa:
			var s: float = sim.tam[i] * (1.0 - 0.25 * smoothstep(0.7, 1.0, sim.edad[i] / sim.vida[i]))
			_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, s)), sim.pos[i]))
			_mm.set_instance_custom_data(i, Color(sim.temp[i], sim.hollin[i], sim.semilla[i], clampf(sim.edad[i] / sim.vida[i], 0.0, 1.0)))
		else:
			_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -50, 0)))
			_mm.set_instance_custom_data(i, Color(0, 0, 0, 1))
	var mc: MultiMesh = _chispas.multimesh
	for i in HazMasaSim.MAX_CHISPAS:
		if sim.c_vida[i] > 0.0 and visible_masa:
			var v: Vector3 = sim.c_vel[i]
			var calor: float = clampf(sim.c_vida[i] / 1.2, 0.0, 1.0)
			SpriteToy.poner_chispa(mc, i, sim.c_pos[i], v, v.length() * 0.06, 0.07, calor * calor, minf(sim.c_vida[i] * 3.0, 1.0), false)
		else:
			SpriteToy.poner_chispa(mc, i, Vector3(0, -50, 0), Vector3.UP, 0.0, 0.0, 0.0, 0.0, false)
