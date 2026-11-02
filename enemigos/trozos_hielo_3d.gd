class_name TrozosHielo3D
extends Node3D
## GAMEFEEL, TAREA E1 (1/11): los trozos de un enemigo helado que se rompe al morir (`Combate3D._romper_hielo`). 6-8 cubitos del color del hielo salen de donde estaba el cuerpo,
## caen con una gravedad simple, rebotan un poco al tocar el suelo y se funden (alfa a 0) en `T_VIDA` s; el nodo se libera solo. Sin colisiones ni física: solo posición y velocidad.

const T_VIDA: float = 1.0                ## s que tarda en fundirse del todo (y en liberarse el nodo)
const GRAVEDAD: float = 9.0              ## u/s²
const REBOTE: float = 0.35               ## fracción de velocidad vertical que conserva al tocar el suelo

var color: Color = Color(0.7, 0.95, 1.0)
var n: int = 7
var alto: float = 0.85                   ## alto del cuerpo que se rompe (los trozos y su salida se escalan con él)
var suelo_y: float = 0.0

var _trozos: Array = []                  ## [{"m": MeshInstance3D, "v": Vector3, "w": Vector3 (giro)}]
var _t: float = 0.0


## Crea los trozos en `centro` (mundo) como hijos de `padre` y devuelve el nodo.
static func crear(padre: Node, centro: Vector3, color_: Color, cuantos: int, alto_: float) -> TrozosHielo3D:
	var t := TrozosHielo3D.new()
	t.name = "TrozosHielo3D"
	t.color = color_
	t.n = cuantos
	t.alto = alto_
	if padre != null and is_instance_valid(padre):
		padre.add_child(t)
	t.global_position = centro
	t.suelo_y = centro.y - alto_ * 0.5
	return t


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.75, 1.0)
	mat.emission_energy_multiplier = 0.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	for i in range(maxi(n, 0)):
		var m := MeshInstance3D.new()
		var cubo := BoxMesh.new()
		var lado: float = alto * randf_range(0.10, 0.2)
		cubo.size = Vector3(lado, lado * randf_range(0.7, 1.3), lado)
		m.mesh = cubo
		m.material_override = mat.duplicate()          # cada trozo se funde por su cuenta
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(randf_range(-0.2, 0.2), randf_range(-0.3, 0.3) * alto, randf_range(-0.2, 0.2))
		m.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		add_child(m)
		var fuera: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(0.6, 1.6)
		_trozos.append({"m": m, "v": fuera + Vector3(0.0, randf_range(1.2, 3.0), 0.0), "w": Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))})


func _process(delta: float) -> void:
	_t += delta
	var vivo: float = clampf(_t / T_VIDA, 0.0, 1.0)
	for d in _trozos:
		var m: MeshInstance3D = d["m"]
		if not is_instance_valid(m):
			continue
		var v: Vector3 = d["v"]
		v.y -= GRAVEDAD * delta
		m.global_position += v * delta
		if m.global_position.y < suelo_y:
			m.global_position.y = suelo_y
			v.y = absf(v.y) * REBOTE
			v.x *= 0.6
			v.z *= 0.6
		d["v"] = v
		m.rotation += (d["w"] as Vector3) * delta
		var mat: StandardMaterial3D = m.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color.a = 0.9 * (1.0 - vivo)
	if _t >= T_VIDA:
		queue_free()
