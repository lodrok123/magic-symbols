class_name BastonChaman3D
extends Node3D

## BASTÓN DEL CHAMÁN GOBLIN como pieza de Equipo3D (28/10): envuelve arte/modelos/baston_chaman_equipo.glb (tools/separar_orbe_baston.py: el palo de Meshy y el ORBE de cristal en dos mallas) con la
## PUNTA en el origen y el palo hacia +Y (el GLB va centrado: se sube medio palo). Así PiezaApoyada3D lo planta con el origen en el suelo y `punta_global()` es la propia posición del nodo.
## El orbe es blanco neutro: `teñir(color, energia)` le pone un material propio (albedo = color, emisión = color × energia) y una luz del mismo color; el juego lo tiñe de verde (naturaleza)
## mientras traza y lo apaga al acabar (`apagar()`).

const GLB: String = "res://arte/modelos/baston_chaman_equipo.glb"
const LARGO_GLB: float = 1.0               ## alto del GLB (sin escala)
const LUZ_ALCANCE: float = 1.2             ## u (del mundo) que alcanza la luz del orbe
const LUZ_ENERGIA_POR_ENERGIA: float = 0.15

var orbe: MeshInstance3D = null
var color_orbe: Color = Color(1, 1, 1)
var energia_orbe: float = 0.0
var _material: StandardMaterial3D = null
var _luz: OmniLight3D = null


## El bastón listo para colgarlo de la mano (Equipo3D.pieza lo llama).
static func crear() -> BastonChaman3D:
	var b := BastonChaman3D.new()
	b.name = "baston_chaman"
	var ps: PackedScene = load(GLB) as PackedScene
	if ps != null:
		var modelo: Node3D = ps.instantiate() as Node3D
		modelo.name = "Modelo"
		modelo.position = Vector3(0.0, LARGO_GLB * 0.5, 0.0)
		b.add_child(modelo)
		var o: Node = modelo.find_child("Orbe", true, false)
		if o is MeshInstance3D:
			b.orbe = o as MeshInstance3D
	b._preparar_orbe()
	return b


func _preparar_orbe() -> void:
	if orbe == null:
		return
	var base: Material = orbe.get_active_material(0)
	_material = (base.duplicate() as StandardMaterial3D) if base is StandardMaterial3D else StandardMaterial3D.new()
	_material.emission_enabled = true
	_material.emission = Color(0, 0, 0)
	_material.emission_energy_multiplier = 1.0
	orbe.material_override = _material
	_luz = OmniLight3D.new()
	_luz.name = "LuzOrbe"
	_luz.shadow_enabled = false
	_luz.omni_range = LUZ_ALCANCE
	_luz.light_energy = 0.0
	_luz.visible = false
	orbe.add_child(_luz)


## Tiñe el orbe: `color` y `energia` (0 = solo el tinte, sin brillo; ~2 = brilla). Una luz del mismo color lo acompaña mientras `energia` > 0.
func teñir(color: Color, energia: float = 0.0) -> void:
	color_orbe = color
	energia_orbe = energia
	if _material == null:
		return
	_material.albedo_color = color
	_material.emission = color
	_material.emission_energy_multiplier = energia
	_material.emission_enabled = energia > 0.0
	_luz.light_color = color
	_luz.light_energy = energia * LUZ_ENERGIA_POR_ENERGIA
	_luz.visible = energia > 0.0


## Orbe blanco y apagado, como viene del GLB.
func apagar() -> void:
	teñir(Color(1, 1, 1), 0.0)


## La punta del palo (el origen del nodo), en el mundo.
func punta_global() -> Vector3:
	return global_position


## El extremo de arriba del palo (el centro del orbe), en el mundo.
func cima_global() -> Vector3:
	return global_transform * Vector3(0.0, LARGO_GLB * 0.88, 0.0)


## Dirección en el mundo de la punta hacia el orbe (unitaria).
func eje_global() -> Vector3:
	return global_basis.y.normalized()
