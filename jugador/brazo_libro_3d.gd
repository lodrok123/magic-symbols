class_name BrazoLibro3D
extends SkeletonModifier3D

## BRAZO DEL LIBRO (T-CP1, 18/10, Juego; docs/LAB_CASTPOINT.md §2.3.3). Los clips de lanzar son a DOS manos (salvo MageSoellCast003 y los CastOneHand*):
## si una mano sostiene el libro, la animación se lo llevaría por el aire y lo atravesaría con el hechizo. Este modificador va DESPUÉS de la animación y mezcla
## los huesos del brazo que lleva el libro (hombro, brazo, antebrazo, mano) hacia una pose FIJA («libro recogido»), sacada de un fotograma de `CastOneHandFront`
## (el brazo que ya sostiene el libro con la palma arriba; `Readandwrite` si el GLB no lo trae), con el peso `influence` (0 = no hace nada, 1 = el brazo clavado en la pose; LAB_CASTPOINT pide 0,8–1).
##
## Un solo lado a la vez (`lado`); la pose del otro lado es la ESPEJADA: si el rig es simétrico (Mixamo lo es), la rotación local del hueso derecho es la
## de su gemelo izquierdo conjugada con la reflexión del plano YZ del modelo: (x, y, z, w) → (x, −y, −z, w). `prueba_cast_points` mide que la mano derecha
## queda en el espejo de la izquierda (error en unidades de modelo).
## Es un SkeletonModifier3D (Godot 4.3+): hijo del Skeleton3D, se ejecuta tras el AnimationPlayer en el mismo fotograma, sin tocar el clip.

const CADENA: PackedStringArray = ["Shoulder", "Arm", "ForeArm", "Hand"]
## Segundo de Readandwrite del que se saca la pose. Se eligió el instante en que la mano izquierda está más cerca de su posición media durante el clip
## (la pose «típica» de llevar el libro, no el arranque ni el punto más alto); `prueba_cast_points` imprime la desviación.
const T_REF_POR_DEFECTO: float = 1.25
## Segundo de CastOneHandFront (1,10 s) del que se saca la pose cuando el GLB lo trae: la mano izquierda ya sostiene el libro con la palma hacia arriba
## y entre 0,8 y 1,0 s el brazo está quieto (medido: la normal de la palma varía < 3°).
const T_REF_UNA_MANO: float = 0.9

var lado: String = "izquierda"                  ## el brazo que sujeta el libro
var _huesos: Dictionary = {}                    ## "izquierda" | "derecha" -> PackedInt32Array (índices de la cadena, de hombro a mano)
var _pose: Dictionary = {}                      ## "izquierda" | "derecha" -> Array[Quaternion] (rotación local de cada hueso de la cadena)
var preparado: bool = false
var t_ref: float = T_REF_POR_DEFECTO


## Busca los huesos de las dos cadenas y saca la pose de `clip` en el segundo `t`. Devuelve false si falta algo (sin esqueleto, sin clip o sin huesos).
func preparar(clip: Animation, t: float = T_REF_POR_DEFECTO) -> bool:
	var sk: Skeleton3D = _sk()
	preparado = false
	if sk == null or clip == null:
		return false
	t_ref = t
	for l in ["izquierda", "derecha"]:
		var lado_hueso: String = "Left" if l == "izquierda" else "Right"
		var idx := PackedInt32Array()
		for parte in CADENA:
			var h: int = _hueso(sk, lado_hueso + parte)
			if h < 0:
				return false
			idx.append(h)
		_huesos[l] = idx
	# La pose de la izquierda sale del clip; la de la derecha, espejada de ella.
	var izq: Array = []
	for h in (_huesos["izquierda"] as PackedInt32Array):
		var q: Variant = _rotacion_en(sk, clip, sk.get_bone_name(h), t)
		if q == null:
			return false
		izq.append(q)
	var der: Array = []
	for q in izq:
		var qq: Quaternion = q
		der.append(Quaternion(qq.x, -qq.y, -qq.z, qq.w))
	_pose["izquierda"] = izq
	_pose["derecha"] = der
	preparado = true
	return true


## El esqueleto es el padre (`get_skeleton()` solo vale cuando el árbol ya ha procesado un fotograma).
func _sk() -> Skeleton3D:
	return get_parent() as Skeleton3D


static func _hueso(sk: Skeleton3D, fin: String) -> int:
	for i in range(sk.get_bone_count()):
		var n: String = sk.get_bone_name(i)
		if n == fin or n.ends_with("_" + fin) or n.ends_with(":" + fin):
			return i
	return -1


## Rotación local del hueso `nombre` en el segundo `t` del clip (null si el clip no la anima).
static func _rotacion_en(sk: Skeleton3D, clip: Animation, nombre: String, t: float) -> Variant:
	for i in range(clip.get_track_count()):
		if clip.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		if clip.track_get_path(i).get_concatenated_subnames() == nombre:
			return clip.rotation_track_interpolate(i, t)
	return null


## Rotación local del hueso `nombre` ahora mismo (para las pruebas).
func pose_de(l: String, i: int) -> Quaternion:
	return (_pose[l] as Array)[i]


## Godot 4.4+ llama a esta; la antigua `_process_modification()` ya no se invoca.
func _process_modification_with_delta(_delta: float) -> void:
	_aplicar()


var llamadas: int = 0


func _aplicar() -> void:
	llamadas += 1
	if not preparado:
		return
	var sk: Skeleton3D = _sk()
	if sk == null or not _huesos.has(lado):
		return
	var idx: PackedInt32Array = _huesos[lado]
	var pose: Array = _pose[lado]
	for k in range(idx.size()):
		sk.set_bone_pose_rotation(idx[k], pose[k] as Quaternion)
