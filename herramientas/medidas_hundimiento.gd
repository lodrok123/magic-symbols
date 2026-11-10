extends SceneTree
## ¿POR QUÉ se hunden bajo el suelo algunos clips traducidos, y qué parte del cuerpo es la que se mete?
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/medidas_hundimiento.gd -- <id> [clip...] [sin_tope]
## Por fotograma: la suela más baja (los huesos de pie, que es lo que miraba ClipsFamilia antes del tope) y el hueso MÁS BAJO de
## todos, sea cual sea. Si el que se mete bajo el suelo no es un pie, el criterio de «suela» no sirve para ese clip: en una muerte
## de espaldas lo que toca el suelo es la espalda, no la suela, y subir la figura por el pie la dejaría flotando.
## `sin_tope` apaga ClipsFamilia.tope_hundimiento_activo, para comparar el antes y el después.
## Todo en fracción del alto del personaje, y respecto a su suelo (p.global_position.y).

const ALTO: float = 0.85
const MUESTRAS: int = 24
const HUESOS_SUELA: PackedStringArray = ["Foot", "ToeBase", "Toe_End"]
const POR_DEFECTO: Array[String] = ["Dead", "RollDodge", "ChargedGroundSlam"]


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "santa_compana_vela"
	var clips: Array = []
	for i in range(1, args.size()):
		if String(args[i]) == "sin_tope":
			ClipsFamilia.tope_hundimiento_activo = false
			ClipsFamilia.vaciar_cache()
			continue
		clips.append(args[i])
	if clips.is_empty():
		clips.assign(POR_DEFECTO)
	print("tope de hundimiento: ", "puesto" if ClipsFamilia.tope_hundimiento_activo else "QUITADO")
	var mundo := Node3D.new()
	root.add_child(mundo)
	var p := Pj3D.new()
	mundo.add_child(p)
	if not p.cargar(id):
		push_error("no carga " + id)
		quit(1)
		return
	p.set_alto(ALTO)
	await process_frame
	var ap: AnimationPlayer = p._ap
	var sk: Skeleton3D = (p.find_children("*", "Skeleton3D", true, false)[0]) as Skeleton3D
	var alto: float = p.alto_modelo() * p.scale.y
	if p._arbol != null:
		p._arbol.active = false
	ap.active = true
	# Altura de referencia: lo que mide ClipsFamilia como «suela en reposo».
	sk.reset_bone_poses()
	sk.force_update_all_bone_transforms()
	var reposo_suela: float = float(_mas_bajo(sk, p, true)["y"]) / alto
	var reposo_todo: Dictionary = _mas_bajo(sk, p, false)
	print("%s · alto %.3f · en REPOSO: suela %+.3f · hueso más bajo %s %+.3f" % [
		id, alto, reposo_suela, reposo_todo["hueso"], float(reposo_todo["y"]) / alto])
	for clip in clips:
		if not ap.has_animation(String(clip)):
			print("  (no tiene %s)" % clip)
			continue
		var largo: float = ap.get_animation(String(clip)).length
		print("  %s (%.2f s)" % [clip, largo])
		print("    t       suela      hueso más bajo")
		# El tope sube la figura por fotograma: si ese movimiento diera saltos, se vería como un bote. Se mide la altura de la
		# cadera fotograma a fotograma y el mayor salto entre dos seguidos. Al PASO DE FOTOGRAMA de verdad (los clips van a
		# 30 fps): muestreando más grueso, el salto sale inflado y no dice si se vería un bote.
		var cadera_ant: float = NAN
		var salto: float = 0.0
		var i_cad: int = sk.find_bone("mixamorig_Hips")
		var muestras: int = maxi(MUESTRAS, int(largo * 30.0))
		for k in range(muestras + 1):
			ap.play(String(clip))
			ap.seek(largo * float(k) / float(muestras), true)
			sk.force_update_all_bone_transforms()
			var s: float = float(_mas_bajo(sk, p, true)["y"]) / alto
			var b: Dictionary = _mas_bajo(sk, p, false)
			if i_cad >= 0:
				var cy: float = ((sk.global_transform * sk.get_bone_global_pose(i_cad).origin).y - p.global_position.y) / alto
				if not is_nan(cadera_ant):
					salto = maxf(salto, absf(cy - cadera_ant))
				cadera_ant = cy
			# solo se imprimen los fotogramas que se hunden, y unos pocos del resto
			if s >= -0.005 and k % maxi(1, muestras / 6) != 0:
				continue
			print("    %.2f   %+.3f     %-28s %+.3f %s" % [
				largo * float(k) / float(muestras), s, b["hueso"], float(b["y"]) / alto,
				"<<< se hunde" if s < -0.005 else ""])
		print("    mayor salto de la cadera entre dos fotogramas seguidos: %.3f del alto" % salto)
	quit(0)


## El hueso más bajo (solo los de suela, o todos) en el espacio del personaje.
func _mas_bajo(sk: Skeleton3D, p: Pj3D, solo_suela: bool) -> Dictionary:
	var m: float = INF
	var cual: String = ""
	for i in range(sk.get_bone_count()):
		var n: String = sk.get_bone_name(i)
		if solo_suela:
			var vale: bool = false
			for fin in HUESOS_SUELA:
				if n.ends_with(fin):
					vale = true
					break
			if not vale:
				continue
		var y: float = (sk.global_transform * sk.get_bone_global_pose(i).origin).y - p.global_position.y
		if y < m:
			m = y
			cual = n
	return {"y": m, "hueso": cual}
