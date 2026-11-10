extends SceneTree
## ¿El esqueleto del brazo ENCAJA en la malla? Compara dónde acaba la mano de la MALLA con dónde tiene el esqueleto la muñeca y la yema.
##   godot --headless --path . --script res://herramientas/medidas_mano_malla.gd -- <id del GLB> [id...]
## La punta de la mano de la malla es su vértice más alejado del eje del cuerpo, a cada lado, entre el 25 % y el 70 % del alto (ahí no
## llegan ni los picos de la capa ni la capucha). Si el brazo encaja, esa punta coincide con la yema del dedo corazón del esqueleto.
## `sobra` = cuánto se pasa el esqueleto de la malla, medido a lo largo del brazo (hombro → yema): positivo = el hueso de la mano queda
## más allá de la mano de verdad, y entonces los huesos de los dedos mueven aire y la mano visible cuelga rígida del antebrazo.

func _initialize() -> void:
	await process_frame
	var ids: Array = Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		ids = ["santa_compana_rig", "fantasma_elfo_rig"]
	for id in ids:
		var modelo: Node3D = (load("res://arte/modelos/%s.glb" % id) as PackedScene).instantiate()
		root.add_child(modelo)
		await process_frame
		var sk: Skeleton3D = modelo.find_children("*", "Skeleton3D", true, false)[0]
		var pts: Array[Vector3] = []
		for n in modelo.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				for v in (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					pts.append(mi.global_transform * v)
		var alto: float = 0.0
		for p in pts:
			alto = maxf(alto, p.y)
		print("=== %s · alto %.3f" % [id, alto])
		for lado in ["Left", "Right"]:
			var signo: float = 1.0 if lado == "Left" else -1.0
			# los 25 vértices más alejados del eje, a ese lado y a la altura de los brazos
			var cand: Array[Vector3] = []
			for p in pts:
				if p.x * signo > 0.0 and p.y > alto * 0.25 and p.y < alto * 0.70:
					cand.append(p)
			cand.sort_custom(func(a, b): return a.x * signo > b.x * signo)
			var punta := Vector3.ZERO
			var n_p: int = mini(25, cand.size())
			for i in n_p:
				punta += cand[i]
			punta /= float(maxi(n_p, 1))
			var hombro: Vector3 = _h(sk, lado + "Arm")
			var muneca: Vector3 = _h(sk, lado + "Hand")
			var yema: Vector3 = _h(sk, lado + "HandMiddle4")
			var eje: Vector3 = (yema - hombro).normalized()
			var largo_malla: float = (punta - hombro).dot(eje)
			var largo_hueso: float = (yema - hombro).length()
			print("  %-5s  punta de la malla (%+.3f, %.3f, %+.3f) · muñeca del esqueleto (%+.3f, %.3f, %+.3f) · yema (%+.3f, %.3f, %+.3f)" % [
				lado, punta.x, punta.y, punta.z, muneca.x, muneca.y, muneca.z, yema.x, yema.y, yema.z])
			print("         brazo de la malla %.3f · brazo del esqueleto %.3f · sobra %+.3f (%.0f %% del brazo) · la muñeca del esqueleto está a %.3f de la punta de la malla" % [
				largo_malla, largo_hueso, largo_hueso - largo_malla, 100.0 * (largo_hueso - largo_malla) / largo_hueso, muneca.distance_to(punta)])
		# ¿DE QUÉ HUESOS CUELGA LA MANO DE LA MALLA? Reparto del peso de los vértices a menos de 0,05 de su punta derecha. Si manda el
		# antebrazo, la mano visible es rígida: girar la muñeca o los dedos del esqueleto no la mueve.
		var cand_d: Array[Vector3] = []
		for p in pts:
			if p.x < 0.0 and p.y > alto * 0.25 and p.y < alto * 0.70:
				cand_d.append(p)
		cand_d.sort_custom(func(a, b): return a.x < b.x)
		var punta_d := Vector3.ZERO
		for i in mini(25, cand_d.size()):
			punta_d += cand_d[i]
		punta_d /= float(maxi(mini(25, cand_d.size()), 1))
		var reparto: Dictionary = {}
		var total: float = 0.0
		for n in modelo.find_children("*", "MeshInstance3D", true, false):
			var mi2: MeshInstance3D = n as MeshInstance3D
			if mi2.mesh == null:
				continue
			for s in mi2.mesh.get_surface_count():
				var ar: Array = mi2.mesh.surface_get_arrays(s)
				var vs: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
				var bs: PackedInt32Array = ar[Mesh.ARRAY_BONES]
				var ws: PackedFloat32Array = ar[Mesh.ARRAY_WEIGHTS]
				var por_v: int = bs.size() / vs.size()
				for v in vs.size():
					if (mi2.global_transform * vs[v]).distance_to(punta_d) > 0.05:
						continue
					for k in por_v:
						var w: float = ws[v * por_v + k]
						if w <= 0.0001:
							continue
						var b: int = bs[v * por_v + k]
						var nb: String = mi2.skin.get_bind_name(b) if mi2.skin != null else String(sk.get_bone_name(b))
						nb = nb.trim_prefix("mixamorig_")
						# los dedos, juntos
						for d in ["Thumb", "Index", "Middle", "Ring", "Pinky"]:
							if nb.contains(d):
								nb = "RightHand (dedos)" if nb.begins_with("Right") else nb
						reparto[nb] = float(reparto.get(nb, 0.0)) + w
						total += w
		var ks: Array = reparto.keys()
		ks.sort_custom(func(a, b): return float(reparto[a]) > float(reparto[b]))
		var txt: String = "  la mano derecha de la malla cuelga de:"
		for i in mini(5, ks.size()):
			txt += "  %s %.0f %%" % [ks[i], 100.0 * float(reparto[ks[i]]) / maxf(total, 0.001)]
		print(txt)
		modelo.queue_free()
	quit(0)


func _h(sk: Skeleton3D, n: String) -> Vector3:
	return sk.global_transform * sk.get_bone_global_rest(sk.find_bone("mixamorig_" + n)).origin
