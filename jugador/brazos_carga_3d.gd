class_name BrazosCarga3D
extends SkeletonModifier3D

## BRAZOS DE LA CARGA (4/11, docs/RECOGER_LANZAR_2026-11-04.md). La jugadora no tiene clips de «andar cargando» ni de «lanzar» (hay `agacharse` y `walk`, nada con las dos manos en alto):
## esta capa va DESPUÉS de la animación y apunta los dos brazos a unas direcciones fijas (como `BrazoLibro3D`, pero por DIRECCIÓN y no por giros a mano, así no depende de cómo esté el
## reposo del esqueleto). Mientras `influence` valga 0 no hace nada; 1 = los brazos clavados en la pose. La pose sale de mezclar dos de `POSES` (`pose_a` → `pose_b`, `mezcla` 0..1) y la
## columna se echa hacia atrás `inclinacion` (0..1 de `INCLINACION_MAX`) para que el peso se lea sobre la cabeza.
## Direcciones en el espacio del esqueleto (el del modelo: +X la izquierda de ella, +Y arriba, +Z delante) del brazo y del antebrazo del lado IZQUIERDO; el derecho es el espejo en X.
## Es un SkeletonModifier3D: hijo del Skeleton3D, se ejecuta tras el AnimationPlayer en el mismo fotograma, sin tocar el clip.

const POSES: Dictionary = {
	# manos a la altura del pecho/cintura, delante: levantando el objeto del suelo, o dejándolo
	"bajo": [Vector3(0.18, -0.55, 0.70), Vector3(-0.30, -0.35, 0.85)],
	# las dos manos por encima de la cabeza, casi juntas: el objeto encima (la pose de andar cargando)
	"alzado": [Vector3(0.05, 0.93, 0.30), Vector3(-0.35, 0.90, 0.20)],
	# armar el lanzamiento: el objeto va hacia atrás y un poco abajo de la cabeza
	"atras": [Vector3(0.10, 0.60, -0.70), Vector3(-0.30, 0.55, -0.75)],
	# remate: los brazos estirados al frente, algo por encima del pecho
	"adelante": [Vector3(0.12, 0.30, 0.94), Vector3(-0.02, 0.30, 0.95)],
}
const INCLINACION_MAX: float = 12.0          ## grados de columna hacia atrás con inclinacion = 1
const HUESOS_COLUMNA: PackedStringArray = ["Spine", "Spine1", "Spine2"]

var pose_a: String = "alzado"
var pose_b: String = "alzado"
var mezcla: float = 0.0
var inclinacion: float = 0.0
var llamadas: int = 0

var _huesos: Array = []            ## [izquierda, derecha]: cada una [brazo, antebrazo, mano] (índices)
var _columna: PackedInt32Array = PackedInt32Array()
var preparado: bool = false


## Busca los huesos de los dos brazos y la columna. false si falta algo (sin esqueleto o sin huesos).
func preparar() -> bool:
	var sk: Skeleton3D = get_parent() as Skeleton3D
	preparado = false
	if sk == null:
		return false
	_huesos = []
	for lado in ["Left", "Right"]:
		var idx := PackedInt32Array()
		for parte in ["Arm", "ForeArm", "Hand"]:
			var h: int = Equipo3D._hueso(sk, lado + parte)
			if h < 0:
				return false
			idx.append(h)
		_huesos.append(idx)
	_columna = PackedInt32Array()
	for n in HUESOS_COLUMNA:
		var c: int = Equipo3D._hueso(sk, n)
		if c >= 0:
			_columna.append(c)
	preparado = true
	return true


## Pone la pose de este fotograma (la llama CargarObjeto3D) y el peso total.
func poner(a: String, b: String, k: float, peso: float, inclina: float = 0.0) -> void:
	pose_a = a
	pose_b = b
	mezcla = clampf(k, 0.0, 1.0)
	inclinacion = clampf(inclina, 0.0, 1.0)
	influence = clampf(peso, 0.0, 1.0)


## La dirección del brazo (`i` = 0) o del antebrazo (`i` = 1) del lado `lado` (0 izquierda, 1 derecha) con la pose mezclada.
func direccion(i: int, lado: int) -> Vector3:
	var da: Vector3 = (POSES[pose_a] as Array)[i]
	var db: Vector3 = (POSES[pose_b] as Array)[i]
	var d: Vector3 = da.lerp(db, mezcla).normalized()
	if lado == 1:
		d.x = -d.x
	return d


func _process_modification_with_delta(_delta: float) -> void:
	_aplicar()


func _aplicar() -> void:
	llamadas += 1
	if not preparado or influence <= 0.0:
		return
	var sk: Skeleton3D = get_parent() as Skeleton3D
	if sk == null:
		return
	# Columna: cada hueso se echa atrás una parte del total, girando sobre el eje X del esqueleto (en global, así no depende de cómo esté orientado cada hueso).
	if inclinacion > 0.0 and not _columna.is_empty():
		var ang: float = -deg_to_rad(INCLINACION_MAX) * inclinacion / float(_columna.size())
		for c in _columna:
			var p: int = sk.get_bone_parent(c)
			var P: Basis = sk.get_bone_global_pose(p).basis.orthonormalized() if p >= 0 else Basis.IDENTITY
			var loc: Basis = sk.get_bone_pose(c).basis.orthonormalized()
			var G: Basis = P * loc
			var G2: Basis = Basis(Vector3.RIGHT, ang) * G
			sk.set_bone_pose_rotation(c, (P.inverse() * G2).get_rotation_quaternion())
	for lado in range(2):
		var idx: PackedInt32Array = _huesos[lado]
		var P2: Basis = sk.get_bone_global_pose(sk.get_bone_parent(idx[0])).basis.orthonormalized()
		for k in range(2):
			var hueso: int = idx[k]
			var hijo: int = idx[k + 1]
			var reposo: Basis = sk.get_bone_rest(hueso).basis.orthonormalized()
			var hacia_hijo: Vector3 = sk.get_bone_rest(hijo).origin.normalized()
			var G3: Basis = P2 * reposo
			var ahora: Vector3 = (G3 * hacia_hijo).normalized()
			var R: Basis = Basis(_arco(ahora, direccion(k, lado)))
			var G4: Basis = R * G3
			sk.set_bone_pose_rotation(hueso, (P2.inverse() * G4).get_rotation_quaternion())
			P2 = G4
		# La mano sigue al antebrazo con su reposo.
		var rm: Basis = sk.get_bone_rest(idx[2]).basis.orthonormalized()
		sk.set_bone_pose_rotation(idx[2], rm.get_rotation_quaternion())


## Rotación de arco mínimo que lleva `a` a `b` (vectores unitarios).
static func _arco(a: Vector3, b: Vector3) -> Quaternion:
	var d: float = clampf(a.dot(b), -1.0, 1.0)
	if d > 0.99999:
		return Quaternion.IDENTITY
	if d < -0.99999:
		var eje: Vector3 = a.cross(Vector3.RIGHT)
		if eje.length() < 0.01:
			eje = a.cross(Vector3.UP)
		return Quaternion(eje.normalized(), PI)
	return Quaternion(a.cross(b).normalized(), acos(d))
