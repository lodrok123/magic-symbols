extends SceneTree
## Repaso de TODOS los clips de un portador de la Santa Compaña: ¿pisa el suelo y la pieza que lleva se queda donde debe?
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/medidas_clips_portador.gd -- <id>
## Por clip y a lo largo de todo el ciclo, en fracción del alto del personaje:
##   suelo   la suela más baja. Negativo = atraviesa el suelo; muy positivo = flota.
##   pieza   lo más cerca que la pieza de equipo (la vela, la cruz) llega de la CABEZA: si baja de cero, se mete en la capucha.
##   mano    lo que se separa la pieza de la mano que la sostiene (debería ser casi constante).
## Se mide sobre un Pj3D de verdad, montado como en el juego, no sobre la captura.

const ALTO: float = 0.85
const MUESTRAS: int = 24
const HUESOS_SUELA: PackedStringArray = ["Foot", "ToeBase", "Toe_End"]


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "santa_compana_vela"
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
	var pieza: Node3D = null
	for n in p.find_children("*", "Node3D", true, false):
		if (n as Node3D).has_meta("equipo_id"):
			pieza = n as Node3D
	var alto: float = p.alto_modelo() * p.scale.y
	print("%s · alto %.3f u · pieza %s" % [id, alto, pieza.get_meta("equipo_id") if pieza != null else "(ninguna)"])
	print("  clip                     suelo (mín)   pieza-cabeza (mín)   mano (mín/máx)")
	if p._arbol != null:
		p._arbol.active = false
	ap.active = true
	var i_cab: int = sk.find_bone("mixamorig_Head")
	var i_mano: int = sk.find_bone("mixamorig_RightHand")
	for clip in ap.get_animation_list():
		var largo: float = ap.get_animation(clip).length
		var suelo: float = INF
		var cerca: float = INF
		var mano_min: float = INF
		var mano_max: float = -INF
		for k in range(MUESTRAS + 1):
			ap.play(clip)
			ap.seek(largo * float(k) / float(MUESTRAS), true)
			# OJO: NO vale forzar la pose con force_update_all_bone_transforms y medir. Las piezas de equipo
			# (PiezaVertical3D, PiezaApoyada3D) se recolocan con la señal `skeleton_updated`, es decir, DESPUÉS de
			# la pose del fotograma: midiendo a mano se mide una pieza que todavía no ha seguido a la mano, y
			# parece que se le escapa de las manos en casi todos los clips. Se deja correr el fotograma entero.
			await process_frame
			await process_frame
			for i in range(sk.get_bone_count()):
				for fin in HUESOS_SUELA:
					if sk.get_bone_name(i).ends_with(fin):
						suelo = minf(suelo, (sk.global_transform * sk.get_bone_global_pose(i).origin).y - p.global_position.y)
						break
			if pieza != null and i_cab >= 0:
				var cabeza: Vector3 = sk.global_transform * sk.get_bone_global_pose(i_cab).origin
				cerca = minf(cerca, pieza.global_position.distance_to(cabeza))
			if pieza != null and i_mano >= 0:
				var m: Vector3 = sk.global_transform * sk.get_bone_global_pose(i_mano).origin
				var d: float = pieza.global_position.distance_to(m)
				mano_min = minf(mano_min, d)
				mano_max = maxf(mano_max, d)
		print("  %-22s  %+.3f        %.3f                %.3f / %.3f" % [
			clip, suelo / alto, cerca / alto, mano_min / alto, mano_max / alto])
	quit(0)
