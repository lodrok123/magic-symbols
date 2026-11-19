extends SceneTree
## Mide el fotograma de manos más bajas para calibrar el contacto; no cambia el clip.
func _initialize() -> void:
	await process_frame
	var pj := Pj3D.new()
	root.add_child(pj)
	pj.cargar("jugadora_base")
	pj.set_alto(1.0)
	if pj._arbol != null:
		pj._arbol.active = false
	pj._ap.active = true
	var clip: String = pj.clip_de("Mixamo_AbrirTapa")
	var sk: Skeleton3D = pj.find_children("*", "Skeleton3D", true, false)[0]
	var izq: int = sk.find_bone("mixamorig_LeftHand")
	var der: int = sk.find_bone("mixamorig_RightHand")
	var dur: float = pj._ap.get_animation(clip).length
	var bajo := INF
	var contacto := 0.0
	for paso in range(int(dur * 30) + 1):
		var t: float = paso / 30.0
		pj._ap.play(clip)
		pj._ap.seek(t, true)
		pj._ap.pause()
		sk.force_update_all_bone_transforms()
		var manos: float = ((sk.global_transform * sk.get_bone_global_pose(izq)).origin.y + (sk.global_transform * sk.get_bone_global_pose(der)).origin.y) * 0.5
		if manos < bajo:
			bajo = manos
			contacto = t
	print("CALIBRACION clip=%s duracion=%.3f contacto_min_manos=%.3f altura=%.3f" % [clip, dur, contacto, bajo])
	quit()
