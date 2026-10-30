class_name NexoRayo3D
extends Area3D

## NEXO ELÉCTRICO (16/10, Juego; pedido de Pablo sobre Q7: «falta un elemento en medio que haga de nexo y restaure la conexión eléctrica»).
## Una PILA de piedra en una casilla seca entre dos aguas. Vacía, corta la corriente; MOJADA (un hechizo de agua), conduce durante
## `T_MOJADO` s y la fuente eléctrica (EmisorRayo3D) pasa por ella como si fuera agua: `Terreno3D.conductores`. El fuego la seca al
## momento; el tiempo, poco a poco. Señal `cambio(conduce)`.
## Por qué no es agua de la simulación: una casilla de suelo entre dos pozos recibiría el agua de los pozos y se llenaría sola; aquí
## el jugador tiene que PONER el agua, y se ve dónde (la pila) y cuánto le queda (el agua de la pila se encoge al secarse).

signal cambio(conduce: bool)

const T_MOJADO: float = 30.0
const RADIO: float = 0.55
const ALTO: float = 0.45
const COLOR_PIEDRA: Color = Color(0.5, 0.5, 0.52)
const COLOR_AGUA: Color = Color(0.3, 0.6, 1.0, 0.8)
const COLOR_RAYO: Color = Color(1.0, 0.92, 0.4)

var celda: Vector2i = Vector2i.ZERO
var mojado: float = 0.0                 ## s que le quedan de agua (0 = seca)
var conduce: bool = false
var _agua: MeshInstance3D = null
var _mat_agua: StandardMaterial3D = null
var _t_chispa: float = 0.0


func preparar(p_celda: Vector2i) -> void:
	celda = p_celda
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(RADIO * 2.2, ALTO + 0.4, RADIO * 2.2)
	forma.shape = caja
	forma.position = Vector3(0.0, (ALTO + 0.4) * 0.5, 0.0)
	add_child(forma)
	_dibujar()
	set_process(true)


func _dibujar() -> void:
	var mp := StandardMaterial3D.new()
	mp.albedo_color = COLOR_PIEDRA
	mp.roughness = 0.9
	var pila := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = RADIO
	cil.bottom_radius = RADIO * 0.85
	cil.height = ALTO
	pila.mesh = cil
	pila.position = Vector3(0.0, ALTO * 0.5, 0.0)
	pila.material_override = mp
	add_child(pila)
	# Dos bornes de cobre a los lados (de este a oeste: por donde pasa la corriente).
	for lado in [-1.0, 1.0]:
		var borne := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.25, 0.5, 0.12)
		borne.mesh = b
		borne.position = Vector3(lado * (RADIO + 0.1), 0.25, 0.0)
		var mb := StandardMaterial3D.new()
		mb.albedo_color = Color(0.75, 0.5, 0.25)
		mb.metallic = 0.6
		borne.material_override = mb
		add_child(borne)
	_mat_agua = StandardMaterial3D.new()
	_mat_agua.albedo_color = COLOR_AGUA
	_mat_agua.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_agua.roughness = 0.1
	_agua = MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = RADIO * 0.85
	disco.bottom_radius = RADIO * 0.85
	disco.height = 0.06
	_agua.mesh = disco
	_agua.position = Vector3(0.0, ALTO - 0.05, 0.0)
	_agua.material_override = _mat_agua
	_agua.visible = false
	add_child(_agua)


## --- Contrato con los hechizos ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
	if rune_data == null:
		return
	var m: Dictionary = Materia.de(hechizo if hechizo != null else rune_data)
	if Materia.riega(m):
		mojar()
	elif Materia.calienta(m):
		secar()


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> bool:
	if rune_data == null:
		return false
	var m: Dictionary = Materia.de(hechizo if hechizo != null else rune_data)
	return Materia.riega(m) or (Materia.calienta(m) and mojado > 0.0)


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


func punto_activacion() -> Vector3:
	return to_global(Vector3(0.0, ALTO, 0.0))


func mojar() -> void:
	mojado = T_MOJADO
	_poner(true)


func secar() -> void:
	mojado = 0.0
	_poner(false)


func _poner(si: bool) -> void:
	if _agua != null:
		_agua.visible = si
	if si == conduce:
		return
	conduce = si
	if si:
		Terreno3D.conductores[celda] = true
	else:
		Terreno3D.conductores.erase(celda)
	cambio.emit(si)


func _process(delta: float) -> void:
	if mojado <= 0.0:
		return
	mojado -= delta
	if mojado <= 0.0:
		_poner(false)
		return
	if _agua != null:
		var f: float = clampf(mojado / T_MOJADO, 0.15, 1.0)        # el agua de la pila se encoge al secarse
		_agua.scale = Vector3(f, 1.0, f)
	# Si la fuente está descargando por aquí, los bornes chispean (amarillo); si no, el agua azul de siempre.
	_t_chispa -= delta
	if _t_chispa <= 0.0:
		_t_chispa = 0.15
		var electrificada: bool = false
		for em in get_tree().get_nodes_in_group("emisor_rayo"):
			if (em.get("electrificada") as Array).has(celda):
				electrificada = true
		_mat_agua.albedo_color = COLOR_RAYO if electrificada else COLOR_AGUA
		_mat_agua.emission_enabled = electrificada
		_mat_agua.emission = COLOR_RAYO
