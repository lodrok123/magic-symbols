extends SceneTree
## ¿Un clip traducido ALARGA el brazo? Mide hombro→codo→muñeca en el reposo y a lo largo del clip, y avisa si crece.
##   godot --path . --headless --script res://herramientas/medidas_brazo_clip.gd -- <id_modelo> [clip]
## Un hueso no cambia de longitud al girar, así que si la distancia crece es que el clip trae pistas de POSICIÓN de la fuente
## (otro esqueleto, con otras proporciones) y se están copiando tal cual.

const FUENTE: String = "res://arte/modelos/chibi_elf.glb"


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "santa_compana_rig"
	var clip: String = args[1] if args.size() > 1 else "Walking"
	var glb: String = String(Pj3D.MODELO_DE.get(id, id))
	var modelo: Node3D = (load("res://arte/modelos/%s.glb" % glb) as PackedScene).instantiate()
	root.add_child(modelo)
	var sk: Skeleton3D = modelo.find_children("*", "Skeleton3D", true, false)[0]
	await process_frame

	var i_arm: int = _hueso(sk, "LeftArm")
	var i_fore: int = _hueso(sk, "LeftForeArm")
	var i_hand: int = _hueso(sk, "LeftHand")
	if i_arm < 0 or i_fore < 0 or i_hand < 0:
		push_error("faltan huesos del brazo")
		quit(1)
		return

	var reposo_sup: float = (sk.get_bone_global_rest(i_fore).origin - sk.get_bone_global_rest(i_arm).origin).length()
	var reposo_inf: float = (sk.get_bone_global_rest(i_hand).origin - sk.get_bone_global_rest(i_fore).origin).length()
	print("modelo %s, clip %s" % [glb, clip])
	print("  REPOSO: brazo %.4f   antebrazo %.4f   total %.4f" % [reposo_sup, reposo_inf, reposo_sup + reposo_inf])

	var an: Animation = ClipsFamilia.traducir_clip(glb, FUENTE, clip, modelo, sk)
	if an == null:
		push_error("no se pudo traducir " + clip)
		quit(1)
		return
	var ap := AnimationPlayer.new()
	modelo.add_child(ap)
	var lib := AnimationLibrary.new()
	lib.add_animation(clip, an)
	ap.add_animation_library("", lib)

	var peor: float = 1.0
	print("  por el clip (fracción, brazo, antebrazo, total, crecimiento):")
	for k in 9:
		var f: float = k / 8.0
		ap.play(clip)
		ap.seek(an.length * f, true)
		ap.pause()
		await process_frame
		var sup: float = (sk.get_bone_global_pose(i_fore).origin - sk.get_bone_global_pose(i_arm).origin).length()
		var inf: float = (sk.get_bone_global_pose(i_hand).origin - sk.get_bone_global_pose(i_fore).origin).length()
		var rel: float = (sup + inf) / maxf(reposo_sup + reposo_inf, 1e-6)
		peor = maxf(peor, rel)
		print("    %.2f  %.4f  %.4f  %.4f   x%.3f" % [f, sup, inf, sup + inf, rel])
	print("  CRECIMIENTO MÁXIMO: x%.3f  %s" % [peor, "(el clip alarga el brazo)" if peor > 1.02 else "(correcto, no alarga)"])
	quit(0)


func _hueso(sk: Skeleton3D, fin: String) -> int:
	for b in sk.get_bone_count():
		var n := String(sk.get_bone_name(b))
		if n == fin or n.ends_with("_" + fin) or n.ends_with(":" + fin):
			return b
	return -1
