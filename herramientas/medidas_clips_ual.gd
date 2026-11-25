extends SceneTree
## MEDIDAS de las manos en clips UAL (25/11): para cada clip pedido, la altura media de las dos manos (y la de cada una) sobre la suela, a 15 fps, en el esqueleto del
## propio maniquí (sin retarget: los instantes no cambian al traducir). Sirve para sacar el instante de un gesto (manos abajo, en la tapa del cofre…). Sin ventana:
##   godot --headless --path . --script res://herramientas/medidas_clips_ual.gd -- <ruta GLB> <clip>[,<clip>...]

func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var ruta: String = a[0] if a.size() > 0 else "res://arte/ual/ual2_standard_mixamo.glb"
	var clips: PackedStringArray = (a[1] if a.size() > 1 else "Chest_Open,Consume").split(",")
	var m: Node3D = (load(ruta) as PackedScene).instantiate() as Node3D
	root.add_child(m)
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mi: int = sk.find_bone("mixamorig_LeftHand")
	var md: int = sk.find_bone("mixamorig_RightHand")
	var pie: int = sk.find_bone("mixamorig_LeftToeBase")
	var cad: int = sk.find_bone("mixamorig_Hips")
	for c in clips:
		if not ap.has_animation(c):
			print("FALTA ", c)
			continue
		var largo: float = ap.get_animation(c).length
		ap.play(c)
		print("%s (%.2f s): t · manos (media / izq / dcha) · adelante de la mano dcha respecto a la cadera" % [c, largo])
		var t: float = 0.0
		while t <= largo + 0.001:
			ap.seek(t, true)
			await process_frame
			var yp: float = sk.get_bone_global_pose(pie).origin.y
			var yi: float = sk.get_bone_global_pose(mi).origin.y - yp
			var yd: float = sk.get_bone_global_pose(md).origin.y - yp
			var fd: float = (sk.get_bone_global_pose(md).origin - sk.get_bone_global_pose(cad).origin).z
			print("  %.2f · %.2f / %.2f / %.2f · %.2f" % [t, (yi + yd) * 0.5, yi, yd, fd])
			t += 1.0 / 15.0
	quit()
