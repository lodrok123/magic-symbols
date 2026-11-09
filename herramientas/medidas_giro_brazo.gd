extends SceneTree
## Qué eje y qué signo hay que girar para SEPARAR el brazo del cuerpo o para subirlo, en el esqueleto de un modelo concreto.
##   godot --path . --headless --script res://herramientas/medidas_giro_brazo.gd -- <id_modelo> [hueso]
## Prueba giros de ±25° en cada eje del hueso y dice cuánto se mueve la mano: hacia fuera (x), hacia arriba (y) y hacia delante (z),
## en el espacio del personaje. Con eso se rellena Pj3D.CORRECCION_POSTURA sin ir probando a ojo.

const PRUEBA: float = 25.0


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "santa_compana_cruz"
	var hueso_corto: String = args[1] if args.size() > 1 else "RightArm"
	var glb: String = String(Pj3D.MODELO_DE.get(id, id))
	var modelo: Node3D = (load("res://arte/modelos/%s.glb" % glb) as PackedScene).instantiate()
	root.add_child(modelo)
	var sk: Skeleton3D = modelo.find_children("*", "Skeleton3D", true, false)[0]
	await process_frame

	var i_h: int = _hueso(sk, hueso_corto)
	var i_mano: int = _hueso(sk, "RightHand" if hueso_corto.begins_with("Right") else "LeftHand")
	if i_h < 0 or i_mano < 0:
		push_error("no están los huesos")
		quit(1)
		return
	# La referencia tiene que medirse en la MISMA pose que las pruebas (el reposo del esqueleto), o el cambio sale falseado.
	sk.reset_bone_poses()
	await process_frame
	var base: Vector3 = sk.get_bone_global_pose(i_mano).origin
	print("modelo %s, hueso %s. Mano en reposo: %s" % [glb, hueso_corto, _v(base)])
	print("  giro                 mano (x,y,z)            cambio: fuera / arriba / delante")
	for eje in 3:
		for signo in [1.0, -1.0]:
			var e := Vector3.ZERO
			e[eje] = PRUEBA * signo
			sk.reset_bone_poses()
			sk.set_bone_pose_rotation(i_h, Quaternion.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z))))
			await process_frame
			var p: Vector3 = sk.get_bone_global_pose(i_mano).origin
			var d: Vector3 = p - base
			# «fuera» es alejarse del eje del cuerpo: el signo de x de la mano manda
			var fuera: float = d.x * signf(base.x)
			print("  %-18s  %s   fuera %+.3f  arriba %+.3f  delante %+.3f" % [_v(e), _v(p), fuera, d.y, d.z])
	sk.reset_bone_poses()
	quit(0)


func _hueso(sk: Skeleton3D, fin: String) -> int:
	for b in sk.get_bone_count():
		var n := String(sk.get_bone_name(b))
		if n == fin or n.ends_with("_" + fin) or n.ends_with(":" + fin):
			return b
	return -1


func _v(v: Vector3) -> String:
	return "(%+.2f,%+.2f,%+.2f)" % [v.x, v.y, v.z]
