class_name Barril3D
extends Area3D

## BARRIL DE PÓLVORA (15/10, Juego; referencia de Pablo: «un barril que explota destruyendo una roca» para abrir o cerrar el curso del
## agua). El FUEGO lo enciende; `T_MECHA` s después EXPLOTA: emite `explota(punto, radio)` y avisa a todo lo que esté a `RADIO` u y
## tenga `recibir_explosion(punto)` (una Compuerta3D de tipo roca con `abre_con = "explosion"`, otro barril: reacción en cadena…).
## Después desaparece. El rayo también lo prende (chispa). El agua apaga la mecha si llega a tiempo.
## Qué NO hace: daño a goblins ni al jugador (eso es de Combate3D cuando se decida); dibujo bueno (el Pipeline tiene «barril»).

signal explota(punto: Vector3, radio: float)

const T_MECHA: float = 1.2
const RADIO: float = 2.6                ## u (algo más de una casilla): la roca de al lado, no la de dos más allá
const ALTO: float = 0.95

var celda: Vector2i = Vector2i.ZERO
var encendido: bool = false
var explotado: bool = false
var _t: float = 0.0
var _cuerpo: MeshInstance3D = null
var _mat: StandardMaterial3D = null


func preparar(p_celda: Vector2i) -> void:
	celda = p_celda
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))
	Terreno3D.bloquear_celda(celda)


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(1.0, ALTO, 1.0)
	forma.shape = caja
	forma.position = Vector3(0.0, ALTO * 0.5, 0.0)
	add_child(forma)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.45, 0.3, 0.15)
	_cuerpo = MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.42
	cil.bottom_radius = 0.42
	cil.height = ALTO
	_cuerpo.mesh = cil
	_cuerpo.position = Vector3(0.0, ALTO * 0.5, 0.0)
	_cuerpo.material_override = _mat
	add_child(_cuerpo)
	var aro := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.4
	t.outer_radius = 0.47
	aro.mesh = t
	aro.position = Vector3(0.0, ALTO * 0.5, 0.0)
	var ma := StandardMaterial3D.new()
	ma.albedo_color = Color(0.3, 0.3, 0.32)
	aro.material_override = ma
	add_child(aro)
	set_process(true)


## --- Contrato con los hechizos ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> void:
	if rune_data == null or explotado:
		return
	if rune_data.tags.has("calor") or rune_data.tags.has("rayo") or rune_data.tags.has("electrico"):
		encender()
	elif encendido and rune_data.tags.has("agua"):
		apagar()


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	if rune_data == null or explotado:
		return false
	if rune_data.tags.has("calor") or rune_data.tags.has("rayo") or rune_data.tags.has("electrico"):
		return not encendido
	return encendido and rune_data.tags.has("agua")


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


func punto_activacion() -> Vector3:
	return to_global(Vector3(0.0, ALTO, 0.0))


func encender() -> void:
	if encendido or explotado:
		return
	encendido = true
	_t = T_MECHA
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.4, 0.1)
	_mat.emission_energy_multiplier = 0.6


func apagar() -> void:
	encendido = false
	_mat.emission_enabled = false


func _process(delta: float) -> void:
	if not encendido or explotado:
		return
	_t -= delta
	_mat.emission_energy_multiplier = 0.6 + 0.6 * absf(sin(_t * 20.0))     # parpadea cada vez más deprisa
	if _t <= 0.0:
		_explotar()


func _explotar() -> void:
	explotado = true
	encendido = false
	var punto: Vector3 = global_position
	Terreno3D.liberar_celda(celda)
	# Lo que está al alcance y sabe recibir una explosión.
	for n in get_tree().get_nodes_in_group("explosionable"):
		if is_instance_valid(n) and n != self and n is Node3D and (n as Node3D).global_position.distance_to(punto) <= RADIO and n.has_method("recibir_explosion"):
			n.call("recibir_explosion", punto)
	explota.emit(punto, RADIO)
	# Un fogonazo sencillo: una esfera naranja que crece y se desvanece.
	var fog := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.3
	esf.height = 0.6
	fog.mesh = esf
	var mf := StandardMaterial3D.new()
	mf.albedo_color = Color(1.0, 0.6, 0.2, 0.9)
	mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mf.emission_enabled = true
	mf.emission = Color(1.0, 0.5, 0.1)
	mf.emission_energy_multiplier = 2.0
	fog.material_override = mf
	fog.position = Vector3(0.0, ALTO * 0.5, 0.0)
	add_child(fog)
	_cuerpo.visible = false
	var tw: Tween = create_tween()
	tw.tween_property(fog, "scale", Vector3.ONE * (RADIO / 0.3), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mf, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(fog.queue_free)
	collision_layer = 0                                     # el nodo se queda (los puzles y las pruebas lo siguen consultando), pero ya no se golpea
