class_name PiezaVertical3D
extends Node3D
## Una pieza de equipo que se lleva SIEMPRE VERTICAL, aunque la mano gire: la cruz de campanillas de la Santa Compaña.
##
## Por qué hace falta: una pieza colgada de un BoneAttachment3D hereda la rotación entera de la mano, así que basta cambiar de clip
## para que se tuerza. Con el andar de la elfa la cruz salía vertical, pero el andar que cierra la mano sobre un mango (`Spear_Walk`
## de Mixamo) lleva la mano como quien porta una lanza, y la cruz salía horizontal atravesando el cuerpo.
##
## Qué hace: cada fotograma deja la pieza de pie (su +Y hacia arriba del mundo), girada solo en el eje vertical para acompañar al
## personaje, y la coloca de modo que su punto de agarre (`agarre_y`, en unidades de la pieza) caiga en el PUÑO. Así la mano sigue
## llevándola de un lado a otro con la animación, pero la cruz nunca se tumba.
##
## Es pariente de PiezaApoyada3D, pero más simple: aquella planta el bastón en el suelo y esta solo mantiene la pieza derecha.

const K_AGARRE_Y: String = "agarre_y"      ## altura del punto de agarre dentro de la pieza, en unidades de la pieza (0 = su base)
const K_INCLINACION: String = "inclinacion"  ## grados que se inclina hacia delante (0 = recta); la cruz procesional va recta
## Separación respecto al puño, en el espacio del PERSONAJE (x = su izquierda, z = su frente). Al dejar la pieza en la vertical
## exacta del puño se mete dentro de la ropa, porque la mano va pegada al cuerpo: esto la saca.
const K_DESPLAZ: String = "desplaz"

var pieza: Node3D = null
var modelo: Node3D = null
var esqueleto: Skeleton3D = null
var hueso: int = -1
var agarre_y: float = 0.0
var inclinacion: float = 0.0
var desplaz: Vector3 = Vector3.ZERO
## La posición y la escala LOCALES que Equipo3D le dio a la pieza. Hay que guardarlas porque cada fotograma se sobrescribe su
## transformación global, así que después ya no se pueden leer de la propia pieza.
var _pos_local: Vector3 = Vector3.ZERO
var _escala_local: Vector3 = Vector3.ONE


func preparar(p_pieza: Node3D, p_modelo: Node3D, p_sk: Skeleton3D, p_hueso: int, datos: Dictionary) -> void:
	pieza = p_pieza
	modelo = p_modelo
	esqueleto = p_sk
	hueso = p_hueso
	agarre_y = float(datos.get(K_AGARRE_Y, 0.0))
	inclinacion = float(datos.get(K_INCLINACION, 0.0))
	desplaz = datos.get(K_DESPLAZ, Vector3.ZERO) as Vector3
	_pos_local = p_pieza.position
	_escala_local = p_pieza.scale
	set_process(true)


func _process(_delta: float) -> void:
	actualizar()


## Pública para que las pruebas puedan llamarla sin esperar un fotograma.
func actualizar() -> void:
	if pieza == null or not is_instance_valid(pieza):
		return
	var anclaje: Node3D = pieza.get_parent() as Node3D       # el BoneAttachment3D, que ya sigue al hueso de la mano
	if anclaje == null:
		return
	# Dónde estaría la pieza colgada de la mano: ese punto es el agarre.
	var punto: Vector3 = anclaje.global_transform * _pos_local
	var escala: Vector3 = anclaje.global_basis.get_scale() * _escala_local
	# De pie, girada solo en el eje vertical con el personaje, y con la inclinación fija que se le pida.
	var yaw: float = modelo.global_rotation.y if modelo != null else 0.0
	var base := Basis(Vector3.UP, yaw)
	if not is_zero_approx(inclinacion):
		base = base * Basis(Vector3.RIGHT, deg_to_rad(inclinacion))
	if desplaz != Vector3.ZERO:
		punto += base * (desplaz * escala)
	# El punto de agarre de la pieza debe caer en el puño: se retrocede por su propio eje.
	var origen: Vector3 = punto - base.y * (agarre_y * escala.y)
	pieza.global_transform = Transform3D(base.scaled(escala), origen)
