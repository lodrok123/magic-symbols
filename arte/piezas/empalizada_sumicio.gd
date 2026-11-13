@tool
extends Node3D
## Tramo de empalizada de Monte Sumicio: cinco postes en fila sobre el eje X local.
## Gira la pieza 90° para ponerla en un lado norte-sur. Cada tramo guarda sus
## alturas para que la valla no se vea repetida.

@export var alturas := PackedFloat32Array([2.15, 2.27, 2.39, 2.15, 2.27]):
	set(v):
		alturas = v
		_construir()

const SEPARACION := 0.46
const RADIO := 0.24
const PUNTA := 0.36
const COLOR_POSTE := Color(0.36862746, 0.27450982, 0.20784314)
const COLOR_PUNTA := Color(0.44439217, 0.36156863, 0.30290195)

static var _mat_poste: StandardMaterial3D
static var _mat_punta: StandardMaterial3D
static var _malla_punta: CylinderMesh
static var _mallas_poste := {}


func _ready() -> void:
	_construir()


func _construir() -> void:
	if not is_inside_tree():
		return
	for hijo in get_children():
		if hijo.has_meta("_poste"):
			remove_child(hijo)
			hijo.queue_free()
	_preparar_recursos()
	var mitad := (alturas.size() - 1) * 0.5
	for i in alturas.size():
		var h := alturas[i]
		var x := (i - mitad) * SEPARACION
		_poner(_malla_poste(h), _mat_poste, Vector3(x, h * 0.5, 0.0))
		_poner(_malla_punta, _mat_punta, Vector3(x, h + PUNTA * 0.5, 0.0))


func _poner(malla: Mesh, mat: Material, pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	m.mesh = malla
	m.material_override = mat
	m.position = pos
	m.set_meta("_poste", true)
	add_child(m)  # sin owner: no se guarda en la escena, se regenera al cargar


static func _preparar_recursos() -> void:
	if _mat_poste:
		return
	_mat_poste = StandardMaterial3D.new()
	_mat_poste.albedo_color = COLOR_POSTE
	_mat_punta = StandardMaterial3D.new()
	_mat_punta.albedo_color = COLOR_PUNTA
	_malla_punta = CylinderMesh.new()
	_malla_punta.top_radius = 0.0
	_malla_punta.bottom_radius = RADIO
	_malla_punta.height = PUNTA
	_malla_punta.radial_segments = 10
	_malla_punta.rings = 1


static func _malla_poste(h: float) -> CylinderMesh:
	var clave := snappedf(h, 0.001)
	if not _mallas_poste.has(clave):
		var c := CylinderMesh.new()
		c.top_radius = RADIO
		c.bottom_radius = RADIO
		c.height = clave
		c.radial_segments = 10
		c.rings = 1
		_mallas_poste[clave] = c
	return _mallas_poste[clave]
