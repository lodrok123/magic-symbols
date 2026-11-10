class_name ManoEmpuna3D
extends SkeletonModifier3D

## LA MANO QUE EMPUÑA UN PALO VERTICAL (10/11, cruz de la Santa Compaña; Pablo: «sí, ciérralos»).
## Cerrar los dedos no basta para que una mano empuñe: tiene que estar ATRAVESADA al palo. Con el brazo colgando, los dedos apuntan hacia
## abajo, casi paralelos a un bastón plantado en el suelo, y al cerrarlos se clavan en él en vez de rodearlo (medido: las yemas quedaban a
## 0,003-0,03 del eje de un mango de 0,029 de radio, o sea, dentro). Este modificador gira SOLO la muñeca, en cada fotograma y después de la
## animación, hasta dejarla así:
##   · los dedos HORIZONTALES (perpendiculares al palo, que es vertical);
##   · la palma mirando en horizontal hacia donde ya miraba (se conserva hacia qué lado da; solo se le quita la componente vertical).
## PiezaApoyada3D, con la clave `palma`, pone el palo delante de esa palma ya girada; y los dedos, cerrados con Pj3D.MANO_RELAJADA, lo rodean.
## No toca el brazo: la postura del hombro y el codo sigue siendo la del clip y la de Pj3D.CORRECCION_POSTURA.
## Mientras la pieza está SUELTA (la mano lejos: un golpe, la muerte) deja la muñeca como la trae el clip, con una transición suave.
## Los ejes de la mano no se suponen: la dirección de los dedos y hacia dónde mira la palma se sacan del REPOSO del propio esqueleto.

const PASO: float = 0.12              ## cuánto se acerca el peso a su objetivo en cada actualización (transición al agarrar y al soltar)
const HORIZONTAL_MIN: float = 0.25    ## si la palma mira casi en vertical, su proyección horizontal no dice nada: se usa el frente del personaje

var hueso: int = -1
var lado: float = -1.0                ## -1 = mano derecha de un modelo que mira a +Z
var apoyo: PiezaApoyada3D = null      ## la pieza que sostiene (para saber si está suelta); null = empuña siempre
var modelo: Node3D = null
var peso: float = 1.0
var _dedos_local: Vector3 = Vector3.UP      ## hacia los dedos, en el espacio del hueso de la mano
var _palma_local: Vector3 = Vector3.LEFT    ## hacia donde mira la palma, en ese mismo espacio
var _listo: bool = false


func preparar(p_esqueleto: Skeleton3D, p_hueso: int, p_lado: float, p_apoyo: PiezaApoyada3D, p_modelo: Node3D) -> void:
	hueso = p_hueso
	lado = p_lado
	apoyo = p_apoyo
	modelo = p_modelo
	var base_n: String = String(p_esqueleto.get_bone_name(hueso))
	var i_m: int = p_esqueleto.find_bone(base_n + "Middle1")
	var i_i: int = p_esqueleto.find_bone(base_n + "Index1")
	var i_p: int = p_esqueleto.find_bone(base_n + "Pinky1")
	if i_m < 0 or i_i < 0 or i_p < 0:
		push_warning("ManoEmpuna3D: %s no tiene dedos (Middle1/Index1/Pinky1); no se orienta la muñeca" % base_n)
		return
	# En reposo, los nudillos en el espacio del hueso de la mano (son hijos directos: su reposo local ya está en ese espacio).
	var m: Vector3 = p_esqueleto.get_bone_rest(i_m).origin
	var a: Vector3 = p_esqueleto.get_bone_rest(i_i).origin
	var b: Vector3 = p_esqueleto.get_bone_rest(i_p).origin
	_dedos_local = m.normalized()
	# (índice − muñeca) × (meñique − muñeca) sale de la palma en la mano DERECHA; en la izquierda, al revés
	var n: Vector3 = a.cross(b) * (1.0 if lado < 0.0 else -1.0)
	_palma_local = (n - _dedos_local * n.dot(_dedos_local)).normalized()      # perpendicular a los dedos
	_listo = true


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if not _listo or sk == null or hueso < 0:
		return
	var objetivo: float = 0.0 if (apoyo != null and is_instance_valid(apoyo) and apoyo.suelta) else 1.0
	peso = move_toward(peso, objetivo, PASO)
	if peso <= 0.001:
		return
	var g: Transform3D = sk.get_bone_global_pose(hueso)
	var giro_sk: Basis = sk.global_transform.basis.orthonormalized()
	var actual: Basis = giro_sk * g.basis.orthonormalized()               # la mano en el mundo, sin escala
	# hacia dónde mira la palma, aplastado a horizontal
	var palma: Vector3 = actual * _palma_local
	palma.y = 0.0
	if palma.length() < HORIZONTAL_MIN:
		palma = (modelo.global_basis.z if modelo != null else Vector3.BACK)
		palma.y = 0.0
	palma = palma.normalized()
	# los dedos: horizontales y perpendiculares a la palma; de los dos sentidos, el que más se parece a como venían
	var dedos: Vector3 = palma.cross(Vector3.UP).normalized()
	var venian: Vector3 = actual * _dedos_local
	if dedos.dot(venian) < 0.0:
		dedos = -dedos
	var marco_local := Basis(_dedos_local, _palma_local, _dedos_local.cross(_palma_local))
	var marco_mundo := Basis(dedos, palma, dedos.cross(palma))
	var destino: Basis = marco_mundo * marco_local.inverse()
	var q: Quaternion = actual.get_rotation_quaternion().slerp(destino.get_rotation_quaternion(), peso)
	var nueva: Basis = giro_sk.inverse() * Basis(q)
	sk.set_bone_global_pose(hueso, Transform3D(nueva.scaled_local(g.basis.get_scale()), g.origin))
