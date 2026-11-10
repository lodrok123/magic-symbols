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
## Hacia dónde mira la palma, en el espacio del PERSONAJE (+Z = su frente). ZERO = hacia donde ya miraba en el clip, aplastado a horizontal.
## 10/11 (Pablo sobre el primer plano: «la posición de la mano es correcta pero debería ser al revés»): la cruz lleva (0, 0, −1), la palma
## hacia ATRÁS. La mano agarra el palo por delante: se ve el dorso sobre el mango y los dedos lo rodean hacia atrás. Antes la palma miraba
## al frente y la mano quedaba escondida detrás del palo. Fijarlo al personaje, y no a cómo viene la mano, lo hace igual en todos los clips.
var palma_hacia: Vector3 = Vector3.ZERO
var _pulgar_signo: float = 1.0           ## de qué lado del eje (dedos × palma) cae el pulgar, medido en el reposo
var _dedos_local: Vector3 = Vector3.UP      ## hacia los dedos, en el espacio del hueso de la mano
var _palma_local: Vector3 = Vector3.LEFT    ## hacia donde mira la palma, en ese mismo espacio
var _listo: bool = false


## HACIA DÓNDE MIRA LA PALMA, sin suponerlo: +1 o −1 por el que hay que multiplicar (índice − muñeca) × (meñique − muñeca) para que salga
## de la PALMA y no del dorso. La palma es el lado hacia el que se CIERRAN los dedos, y eso sí se sabe: una falange se cierra girando sobre su
## +X local (Pj3D.EJE_CIERRE_DEDO, medido con cinemática directa), lo que lleva su punta hacia su +Z local. Así que la palma mira hacia el +Z
## del primer hueso del dedo corazón.
## 10/11: lo deduje de memoria («en la mano derecha ese producto sale de la palma») y estaba AL REVÉS en este esqueleto. Todo lo que colgaba de
## ahí salió invertido durante varias pasadas: el palo «delante de la palma» iba por el dorso, y los dedos, al cerrarse, se alejaban de él.
static func signo_palma(sk: Skeleton3D, hueso_mano: int) -> float:
	var base_n: String = String(sk.get_bone_name(hueso_mano))
	var i_m: int = sk.find_bone(base_n + "Middle1")
	var i_i: int = sk.find_bone(base_n + "Index1")
	var i_p: int = sk.find_bone(base_n + "Pinky1")
	if i_m < 0 or i_i < 0 or i_p < 0:
		return 1.0
	var hacia_palma: Vector3 = sk.get_bone_rest(i_m).basis.orthonormalized().z      # en el espacio del hueso de la mano
	var producto: Vector3 = sk.get_bone_rest(i_i).origin.cross(sk.get_bone_rest(i_p).origin)
	return 1.0 if producto.dot(hacia_palma) >= 0.0 else -1.0


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
	var n: Vector3 = a.cross(b) * signo_palma(p_esqueleto, hueso)      # ver signo_palma: hacia donde se cierran los dedos
	_palma_local = (n - _dedos_local * n.dot(_dedos_local)).normalized()      # perpendicular a los dedos
	var i_t: int = p_esqueleto.find_bone(base_n + "Thumb1")
	if i_t >= 0:
		_pulgar_signo = signf(p_esqueleto.get_bone_rest(i_t).origin.dot(_dedos_local.cross(_palma_local)))
		if _pulgar_signo == 0.0:
			_pulgar_signo = 1.0
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
	if palma_hacia != Vector3.ZERO and modelo != null:
		# dirección FIJA respecto al personaje: no depende de cómo traiga la mano el clip
		var zm: Vector3 = modelo.global_basis.z
		palma = Basis(Vector3.UP, atan2(zm.x, zm.z)) * palma_hacia
		palma.y = 0.0
		palma = palma.normalized()
	# los dedos: horizontales y perpendiculares a la palma. De los dos sentidos, el que CONTINÚA EL ANTEBRAZO (del codo a la muñeca):
	# así la mano nunca queda plegada hacia atrás sobre el brazo. Probado y descartado el 10/11: «el que más se parece a como venían»
	# daba la vuelta a la mano de un clip a otro y al cambiar la postura del hombro; y «el que deja el pulgar arriba», con la palma
	# hacia atrás y el brazo saliendo hacia fuera, doblaba la mano 180° sobre el antebrazo.
	var dedos: Vector3 = palma.cross(Vector3.UP).normalized()
	var padre: int = sk.get_bone_parent(hueso)
	var antebrazo: Vector3 = actual * _dedos_local
	if padre >= 0:
		antebrazo = giro_sk * (g.origin - sk.get_bone_global_pose(padre).origin)
	if dedos.dot(antebrazo) < 0.0:
		dedos = -dedos
	var marco_local := Basis(_dedos_local, _palma_local, _dedos_local.cross(_palma_local))
	var marco_mundo := Basis(dedos, palma, dedos.cross(palma))
	var destino: Basis = marco_mundo * marco_local.inverse()
	var q: Quaternion = actual.get_rotation_quaternion().slerp(destino.get_rotation_quaternion(), peso)
	var nueva: Basis = giro_sk.inverse() * Basis(q)
	sk.set_bone_global_pose(hueso, Transform3D(nueva.scaled_local(g.basis.get_scale()), g.origin))
