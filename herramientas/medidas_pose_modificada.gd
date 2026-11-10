extends SceneTree
## ¿La pose que lee un script es la que se DIBUJA? Un SkeletonModifier3D (ProporcionChibi, la capa…) cambia la pose solo mientras se
## actualiza el esqueleto: fuera de ese momento, get_bone_global_pose devuelve la pose SIN modificar. Quien coloque o mida algo
## respecto a un hueso tiene que leerlo dentro de `skeleton_updated`, o medirá un esqueleto que no es el que se ve.
##   godot --headless --fixed-fps 60 --path . --script res://herramientas/medidas_pose_modificada.gd -- <id> [rol]
## Imprime los modificadores del personaje y, para la mano derecha y sus dedos, la posición leída dentro de `skeleton_updated` y la
## leída fuera, con la distancia entre las dos.

var _dentro: Dictionary = {}
var _sk: Skeleton3D = null
const HUESOS: Array[String] = ["RightArm", "RightForeArm", "RightHand", "RightHandMiddle1", "RightHandMiddle4"]


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var args: Array = Array(OS.get_cmdline_user_args())
	var id: String = String(args[0]) if args.size() > 0 else "santa_compana_cruz"
	var rol: String = String(args[1]) if args.size() > 1 else "idle"
	var p := Pj3D.new()
	root.add_child(p)
	p.cargar(id)
	p.set_alto(0.85)
	await process_frame
	_sk = (p.find_children("*", "Skeleton3D", true, false)[0]) as Skeleton3D
	print(id, " · modificadores del esqueleto:")
	for n in _sk.get_children():
		if n is SkeletonModifier3D:
			print("   ", n.name, " (", (n.get_script() as Script).resource_path.get_file() if n.get_script() != null else n.get_class(), ") activo=", (n as SkeletonModifier3D).active)
	print("   escala del nodo del esqueleto: ", _sk.global_transform.basis.get_scale())
	var ap: AnimationPlayer = p._ap
	if p._arbol != null:
		p._arbol.active = false
	ap.active = true
	ap.play(p.clip_de(rol))
	ap.seek(0.3, true)
	_sk.skeleton_updated.connect(_al_actualizar)
	for i in 20:
		await process_frame
	print("   hueso                dentro de skeleton_updated      fuera                      distancia")
	for h in HUESOS:
		var i_h: int = _sk.find_bone("mixamorig_" + h)
		var fuera: Vector3 = _sk.global_transform * _sk.get_bone_global_pose(i_h).origin
		var dentro: Vector3 = _dentro.get(h, Vector3.ZERO)
		print("   %-18s (%+.3f, %.3f, %+.3f)     (%+.3f, %.3f, %+.3f)     %.3f" % [h, dentro.x, dentro.y, dentro.z, fuera.x, fuera.y, fuera.z, dentro.distance_to(fuera)])
	quit(0)


func _al_actualizar() -> void:
	for h in HUESOS:
		_dentro[h] = _sk.global_transform * _sk.get_bone_global_pose(_sk.find_bone("mixamorig_" + h)).origin
