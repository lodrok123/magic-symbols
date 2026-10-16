class_name Molino3D
extends Area3D

## MOLINO DE AGUA (15/10, Juego; referencia de Pablo: la rueda de TotK que gira con el agua y «al impactar en el molino este gira
## habilitando un mecanismo»). Una rueda de palas sobre una casilla de agua (canal, cauce o río). GIRA cuando:
##   · la CORRIENTE de la simulación en su casilla pasa de `umbral` u/s (AguaSim3D.corriente_en): un arroyo que corre por debajo;
##   · o la golpea un hechizo de AGUA: el chorro la empuja `T_IMPULSO` s (así se activa sin arroyo, de un golpe, y luego se para).
## Emite `girando(si)` al arrancar y al pararse: es el DISPARADOR del mecanismo (una puerta, un ascensor…). `velocidad` es la
## velocidad angular actual (rad/s), por si el mecanismo quiere ir a su ritmo.
## Se dibuja solo (eje + rueda de palas que gira de verdad): el modelo bueno lo pondrá el Pipeline encima con `visual`.

signal girando(si: bool)

const T_IMPULSO: float = 6.0            ## s que gira tras un hechizo de agua
const VEL_MAX: float = 3.0              ## rad/s a corriente plena (o por hechizo)
const ACELERA: float = 2.0              ## rad/s² al arrancar y al frenar (la rueda tiene inercia: no arranca de golpe)
const RADIO: float = 0.75
const PALAS: int = 8

var celda: Vector2i = Vector2i.ZERO
var umbral: float = 0.3                 ## u/s de corriente a partir de la cual gira
var vertical: bool = true               ## el eje cruza la casilla de este a oeste (la rueda mira al norte-sur: agua que corre N-S)
var velocidad: float = 0.0
var activo: bool = false
var _t_impulso: float = 0.0
var _rueda: Node3D = null


func preparar(p_celda: Vector2i, p_umbral: float = 0.3, p_vertical: bool = true) -> void:
	celda = p_celda
	umbral = p_umbral
	vertical = p_vertical
	position = Terreno3D.centro_de(celda, Terreno3D.alto_suelo)


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(RADIO * 2.2, RADIO * 2.4, RADIO * 2.2)
	forma.shape = caja
	forma.position = Vector3(0.0, RADIO * 1.2, 0.0)
	add_child(forma)
	_dibujar()
	set_physics_process(true)


func _dibujar() -> void:
	_rueda = Node3D.new()
	_rueda.position = Vector3(0.0, RADIO * 1.1, 0.0)
	if not vertical:
		_rueda.rotation.y = PI * 0.5
	add_child(_rueda)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.36, 0.2)
	var eje := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.08
	cil.bottom_radius = 0.08
	cil.height = Terreno3D.casilla * 0.9
	eje.mesh = cil
	eje.rotation.z = PI * 0.5               # el eje tumbado, de este a oeste
	eje.material_override = mat
	_rueda.add_child(eje)
	for k in range(PALAS):
		var pala := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.06, RADIO, 0.6)
		pala.mesh = b
		var brazo := Node3D.new()
		brazo.rotation.x = float(k) * TAU / float(PALAS)
		pala.position = Vector3(0.0, RADIO * 0.5, 0.0)
		pala.material_override = mat
		brazo.add_child(pala)
		_rueda.add_child(brazo)
	# Dos postes que sostienen el eje.
	for lado in [-1.0, 1.0]:
		var poste := MeshInstance3D.new()
		var p := BoxMesh.new()
		p.size = Vector3(0.12, RADIO * 1.1, 0.12)
		poste.mesh = p
		poste.position = Vector3(lado * Terreno3D.casilla * 0.42, RADIO * 0.55, 0.0) if vertical else Vector3(0.0, RADIO * 0.55, lado * Terreno3D.casilla * 0.42)
		poste.material_override = mat
		add_child(poste)


## --- Contrato con los hechizos: solo el agua la empuja ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> void:
	if rune_data != null and rune_data.tags.has("agua"):
		_t_impulso = T_IMPULSO


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	return rune_data != null and rune_data.tags.has("agua")


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


func punto_activacion() -> Vector3:
	return to_global(Vector3(0.0, RADIO * 1.1, 0.0))


## Corriente bajo la rueda (u/s), 0 sin simulación.
func corriente() -> float:
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim == null:
		return 0.0
	return sim.corriente_en(Terreno3D.centro_de(celda, 0.0)).length()


func _physics_process(delta: float) -> void:
	_t_impulso = maxf(_t_impulso - delta, 0.0)
	var objetivo: float = VEL_MAX if (_t_impulso > 0.0 or corriente() >= umbral) else 0.0
	velocidad = move_toward(velocidad, objetivo, ACELERA * delta)
	if _rueda != null:
		_rueda.rotate_x(velocidad * delta)          # eje X local: la rueda ya va girada 90° en Y si no es vertical
	var ahora: bool = velocidad > VEL_MAX * 0.5
	if ahora != activo:
		activo = ahora
		girando.emit(activo)
