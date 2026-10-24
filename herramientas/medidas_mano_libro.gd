extends SceneTree
## MEDIDAS de la mano izquierda para colgar el libro (Pj3D.libro_mano): ejes del hueso de la mano en el clip CastOneHandFront (¿hacia dónde mira la palma?) y caja de los vértices
## de la malla que pesan en esa mano, en el espacio del hueso y en unidades del modelo. Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/medidas_mano_libro.gd

const IDS: Array = ["woodland_wanderer", "jugadora_base"]
const PESO_MIN: float = 0.5
const MUESTRAS: int = 4


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var mundo := Node3D.new()
	root.add_child(mundo)
	for id in IDS:
		var p := Pj3D.new()
		mundo.add_child(p)
		p.cargar(String(id))
		p.set_alto(1.0)
		await process_frame
		var sk: Skeleton3D = p._esqueleto()
		var esc: float = 1.0
		var n: Node = sk
		while n != null and n != p._modelo:
			if n is Node3D:
				esc *= (n as Node3D).scale.y
			n = n.get_parent()
		var h: int = Equipo3D._hueso(sk, "LeftHand")
		print("== %s: escala del esqueleto %.2f" % [id, esc])
		var dedo: int = Equipo3D._hueso(sk, "LeftHandMiddle1")
		if dedo >= 0:
			print("   MiddleFinger1 en el espacio de la mano (u modelo): %s" % _v(sk.get_bone_rest(dedo).origin * esc))
		# Caja de los vértices de la mano.
		var mn := Vector3(1e9, 1e9, 1e9)
		var mx := Vector3(-1e9, -1e9, -1e9)
		var cuantos: int = 0
		for nodo in sk.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = nodo as MeshInstance3D
			if mi.skin == null or mi.mesh == null:
				continue
			var enlace: int = -1
			for b in mi.skin.get_bind_count():
				var nom: String = mi.skin.get_bind_name(b)
				if (nom != "" and sk.find_bone(nom) == h) or (nom == "" and mi.skin.get_bind_bone(b) == h):
					enlace = b
			if enlace < 0:
				continue
			for s in mi.mesh.get_surface_count():
				var arr: Array = mi.mesh.surface_get_arrays(s)
				if arr[Mesh.ARRAY_BONES] == null or arr[Mesh.ARRAY_WEIGHTS] == null:
					continue
				var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
				var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var por: int = bones.size() / maxi(verts.size(), 1)
				for v in verts.size():
					var w: float = 0.0
					for k in por:
						if bones[v * por + k] == enlace:
							w += pesos[v * por + k]
					if w >= PESO_MIN:
						var q: Vector3 = (mi.skin.get_bind_pose(enlace) * verts[v]) * esc
						mn = mn.min(q)
						mx = mx.max(q)
						cuantos += 1
		print("   vértices de la mano: %d  caja X %.3f..%.3f  Y %.3f..%.3f  Z %.3f..%.3f" % [cuantos, mn.x, mx.x, mn.y, mx.y, mn.z, mx.z])
		# Ejes de la mano en el clip a una mano.
		var clip: String = p.clip_de("cast_mano_frente")
		if clip == "":
			print("   sin clip a una mano")
		else:
			var ap: AnimationPlayer = p._ap
			if p._arbol != null:
				p._arbol.active = false
			ap.active = true
			ap.play(clip)
			var largo: float = ap.get_animation(clip).length
			for k in MUESTRAS + 1:
				ap.seek(largo * float(k) / float(MUESTRAS), true)
				sk.force_update_all_bone_transforms()
				var g: Transform3D = sk.global_transform * sk.get_bone_global_pose(h)
				print("   %s t=%.2f  ejes X %s  Y %s  Z %s" % [clip, largo * float(k) / float(MUESTRAS), _v(g.basis.x.normalized()), _v(g.basis.y.normalized()), _v(g.basis.z.normalized())])
		p.queue_free()
		await process_frame
	quit(0)


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
