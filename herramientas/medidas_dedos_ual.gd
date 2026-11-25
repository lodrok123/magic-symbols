extends SceneTree
## MEDIDAS del cierre de los dedos de la mano derecha en los clips UAL (25/11): para cada clip, a la mitad de su duración, el ángulo de cada falange (1→2, 2→3, 3→4)
## respecto a la anterior (la 1 respecto al tramo muñeca → nudillo del corazón), en el MANIQUÍ con el clip original y en la jugadora con y sin alinear los dedos
## (LabJugadora3D.alinear_dedos_ual). Un puño cerrado da ~70–90° por falange; la mano plana, ~0–10°. Sin ventana:
##   godot --headless --path . --script res://herramientas/medidas_dedos_ual.gd

const ESCENA: String = "res://laboratorios/LabJugadora3D.tscn"
const SCRIPT_LAB: String = "res://laboratorios/lab_jugadora_3d.gd"
const CLIPS: Array = ["UAL_Reposo", "UAL_PunoDirecto", "UAL_Conjuro2Mantener", "UAL_Conjuro3Soltar", "UAL_Interactuar", "UAL_EspadaQuieta"]
const DEDOS: Array = ["Index", "Middle", "Pinky", "Thumb"]
const FRACCION: float = 0.5


func _initialize() -> void:
	_correr()


func _correr() -> void:
	Estado.nuevo()
	await process_frame
	var res: Dictionary = {}       # clip -> {"fuente": str, true: str, false: str}
	for alinear in [true, false]:
		(load(SCRIPT_LAB) as GDScript).set("alinear_dedos_ual", alinear)
		var lab: Node = (load(ESCENA) as PackedScene).instantiate()
		root.add_child(lab)
		for _i in 3:
			await process_frame
		var pj: Pj3D = lab.call("jugadora")
		var sk: Skeleton3D = pj.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var fuentes: Array = lab.get("_fuentes")
		var sk_f: Skeleton3D = (fuentes[fuentes.size() - 1] as Dictionary)["sk"]
		for clip in CLIPS:
			lab.call("elegir_clip_por_nombre", clip)
			lab.call("poner_pausa", true)
			lab.call("poner_fraccion", FRACCION)
			await process_frame
			if not res.has(clip):
				res[clip] = {}
			res[clip][alinear] = _cierre(sk)
			if alinear:
				res[clip]["fuente"] = _cierre(sk_f)
		lab.queue_free()
		await process_frame
	for clip in CLIPS:
		print(clip)
		print("   maniquí       ", res[clip]["fuente"])
		print("   alineados     ", res[clip][true])
		print("   sin alinear   ", res[clip][false])
	quit()


## «Index 12/35/20 · Middle …»: grados de cada falange respecto a la anterior.
func _cierre(sk: Skeleton3D) -> String:
	var p := func(n: String) -> Vector3: return sk.get_bone_global_pose(sk.find_bone("mixamorig_Right" + n)).origin
	var trozos: PackedStringArray = []
	for dedo in DEDOS:
		var puntos: Array = [p.call("Hand"), p.call("HandMiddle1") if dedo != "Thumb" else p.call("HandThumb1")]
		for f in [1, 2, 3, 4]:
			puntos.append(p.call("Hand%s%d" % [dedo, f]))
		if dedo != "Thumb":
			puntos.remove_at(1)        # muñeca → nudillo propio ya hace de tramo de la mano
		var angs: PackedStringArray = []
		for k in range(1, puntos.size() - 1):
			var a: Vector3 = (puntos[k] as Vector3) - (puntos[k - 1] as Vector3)
			var b: Vector3 = (puntos[k + 1] as Vector3) - (puntos[k] as Vector3)
			angs.append("%d" % roundi(rad_to_deg(a.angle_to(b))) if a.length() > 1e-6 and b.length() > 1e-6 else "-")
		trozos.append("%s %s" % [dedo, "/".join(angs)])
	return " · ".join(trozos)
