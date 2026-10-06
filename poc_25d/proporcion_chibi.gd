class_name ProporcionChibi
extends SkeletonModifier3D

## Cambia las PROPORCIONES de un personaje Mixamo sin tocar el modelo: cabeza más pequeña o más grande,
## piernas y torso más largos o más cortos. Se aplica DESPUÉS de la animación, en cada fotograma, así que
## vale para todos los clips (idle, walk, run...).
##
##   cabeza  escala de la cabeza (y de todo lo que cuelga de ella: pelo, orejas)
##   piernas alarga muslo y espinilla (la cadera sube lo mismo para que los pies sigan en el suelo)
##   torso   alarga la columna (de la cadera al cuello)
##
## Se crea desde Pj3D (Pj3D.PROPORCIONES) y se puede ajustar en vivo (catálogo: teclas 3-8).

@export var cabeza: float = 1.0
@export var piernas: float = 1.0
@export var torso: float = 1.0

## POSTURA, en grados, sumada a lo que trae cada clip (0 = como viene). Positivo = echa hacia atrás; si en un
## modelo va al revés (depende del eje local del hueso), basta con poner el valor negativo. Sirve para corregir
## clips de Meshy que dejan a la chibi cabizbaja o con los hombros encogidos sin volver a renderizar nada.
@export var cabeza_atras: float = 0.0
@export var cuello_atras: float = 0.0
@export var columna_atras: float = 0.0     ## Spine1 (pecho)
@export var brazos_abrir: float = 0.0      ## separa los codos del cuerpo (eje Z local de LeftArm/RightArm)
@export var rodillas_estirar: float = 0.0  ## estira las rodillas (el tobillo se contragira para que el pie siga plano)
@export var pies_abrir: float = 0.0        ## gira los muslos hacia fuera: quita las piernas "en X" y los pies hacia dentro
@export var pelvis_atras: float = 0.0      ## endereza la pelvis (quita el culo en pompa); las piernas se contragiran y no se mueven

var _cabeza: int = -1
var _caderas: int = -1
var _rodillas: PackedInt32Array = PackedInt32Array()   ## LeftLeg / RightLeg (cuelgan del muslo)
var _tobillos: PackedInt32Array = PackedInt32Array()   ## LeftFoot / RightFoot (cuelgan de la espinilla)
var _columna: PackedInt32Array = PackedInt32Array()    ## Spine1, Spine2, Neck
var _cuello: int = -1
var _pecho: int = -1                                    ## Spine1
var _brazos: PackedInt32Array = PackedInt32Array()     ## LeftArm / RightArm (hombro)
var _muslos: PackedInt32Array = PackedInt32Array()     ## LeftUpLeg / RightUpLeg
var _largo_pierna: float = 0.0                          ## de la cadera al tobillo, en espacio del esqueleto
var _largo_torso: float = 0.0


func _ready() -> void:
	preparar()


## Busca los huesos por el final del nombre (sirve con "mixamorig:Head", "mixamorig1:Head", "Head"...).
func preparar() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	_cabeza = _hueso(sk, "Head")
	_caderas = _hueso(sk, "Hips")
	_rodillas.clear()
	_tobillos.clear()
	_columna.clear()
	for lado in ["Left", "Right"]:
		var r: int = _hueso(sk, lado + "Leg")
		var t: int = _hueso(sk, lado + "Foot")
		if r >= 0:
			_rodillas.append(r)
		if t >= 0:
			_tobillos.append(t)
	for n in ["Spine1", "Spine2", "Neck"]:
		var b: int = _hueso(sk, n)
		if b >= 0:
			_columna.append(b)
	_cuello = _hueso(sk, "Neck")
	_pecho = _hueso(sk, "Spine1")
	_brazos.clear()
	for lado in ["Left", "Right"]:
		var h: int = _hueso(sk, lado + "Arm")
		if h >= 0:
			_brazos.append(h)
	_muslos.clear()
	for lado in ["Left", "Right"]:
		var m: int = _hueso(sk, lado + "UpLeg")
		if m >= 0:
			_muslos.append(m)
	_largo_pierna = 0.0
	if not _rodillas.is_empty() and not _tobillos.is_empty():
		var muslo: int = sk.get_bone_parent(_rodillas[0])
		if muslo >= 0:
			var y0: float = sk.get_bone_global_rest(muslo).origin.y
			var y1: float = sk.get_bone_global_rest(_tobillos[0]).origin.y
			_largo_pierna = absf(y0 - y1)
	_largo_torso = 0.0
	var cuello: int = _hueso(sk, "Neck")
	var col: int = _hueso(sk, "Spine")
	if cuello >= 0 and col >= 0:
		_largo_torso = absf(sk.get_bone_global_rest(cuello).origin.y - sk.get_bone_global_rest(col).origin.y)


func _hueso(sk: Skeleton3D, fin: String) -> int:
	for i in range(sk.get_bone_count()):
		var n: String = sk.get_bone_name(i)
		if n == fin or n.ends_with(":" + fin) or n.ends_with("_" + fin):
			return i
	return -1


## Cuánto cambia la altura del personaje (en espacio del esqueleto) con estas proporciones.
func cambio_de_altura(alto_cabeza: float) -> float:
	return _largo_pierna * (piernas - 1.0) + _largo_torso * (torso - 1.0) + alto_cabeza * (cabeza - 1.0)


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or _caderas < 0:
		return
	# Partimos siempre del reposo de cada hueso (no de la pose anterior) para que no se acumule.
	for b in _rodillas:
		sk.set_bone_pose_position(b, sk.get_bone_rest(b).origin * piernas)
	for b in _tobillos:
		sk.set_bone_pose_position(b, sk.get_bone_rest(b).origin * piernas)
	for b in _columna:
		sk.set_bone_pose_position(b, sk.get_bone_rest(b).origin * torso)
	if _cabeza >= 0:
		sk.set_bone_pose_scale(_cabeza, Vector3.ONE * cabeza)
	# Postura: un giro extra sobre la rotación que el clip ha puesto este fotograma. No se acumula porque
	# los clips de Meshy/Mixamo escriben todos los huesos en cada fotograma.
	_girar(sk, _cabeza, Vector3.RIGHT, cabeza_atras)
	_girar(sk, _cuello, Vector3.RIGHT, cuello_atras)
	_girar(sk, _pecho, Vector3.RIGHT, columna_atras)
	for i in range(_brazos.size()):
		# Los dos hombros giran en sentidos opuestos para abrirse los dos hacia fuera.
		_girar(sk, _brazos[i], Vector3.BACK, brazos_abrir * (1.0 if i == 0 else -1.0))
	# Pelvis: se gira la cadera y se deshace el mismo giro en los dos muslos (premultiplicando, en el espacio del
	# padre), así el torso entero se endereza con la pelvis y las piernas se quedan donde estaban.
	if _caderas >= 0 and not is_zero_approx(pelvis_atras):
		var qp := Quaternion(Vector3.RIGHT, deg_to_rad(pelvis_atras))
		sk.set_bone_pose_rotation(_caderas, sk.get_bone_pose_rotation(_caderas) * qp)
		for m in _muslos:
			sk.set_bone_pose_rotation(m, qp.inverse() * sk.get_bone_pose_rotation(m))
	# Piernas: la rodilla se extiende y el tobillo deshace ese giro para que el pie no se clave de punta.
	for b in _rodillas:
		_girar(sk, b, Vector3.RIGHT, -rodillas_estirar)
	for b in _tobillos:
		_girar(sk, b, Vector3.RIGHT, rodillas_estirar)
	for i in range(_muslos.size()):
		_girar(sk, _muslos[i], Vector3.UP, pies_abrir * (-1.0 if i == 0 else 1.0))
	# La cadera sube lo que crecen las piernas. Se expresa en el espacio del padre de la cadera.
	var subir: Vector3 = Vector3(0.0, _largo_pierna * (piernas - 1.0), 0.0)
	var padre: int = sk.get_bone_parent(_caderas)
	if padre >= 0:
		subir = sk.get_bone_global_pose(padre).basis.inverse() * subir
	sk.set_bone_pose_position(_caderas, sk.get_bone_pose_position(_caderas) + subir)


func _girar(sk: Skeleton3D, hueso: int, eje: Vector3, grados: float) -> void:
	if hueso < 0 or is_zero_approx(grados):
		return
	sk.set_bone_pose_rotation(hueso, sk.get_bone_pose_rotation(hueso) * Quaternion(eje, deg_to_rad(grados)))
