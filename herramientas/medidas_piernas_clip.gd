extends SceneTree
## ¿Las piernas se CRUZAN al andar, y de quién es la culpa: del rig o del clip?
##   godot --path . --headless --script res://herramientas/medidas_piernas_clip.gd -- <id> [clip]
## Dos medidas independientes:
##   1) PESOS: para cada hueso de pierna, el centroide (en X, el eje lateral) de los vértices que ese hueso domina.
##      Si el centroide de LeftUpLeg cae al lado contrario que el hueso LeftUpLeg, la malla está cosida en espejo y el
##      problema es del GLB, no de la animación.
##   2) CLIP: a lo largo del ciclo, la X y la Z de cada pie en el espacio del personaje, y si en algún instante el pie
##      izquierdo pasa al lado derecho del eje del cuerpo (o al revés), que es lo que se ve como piernas cruzadas.

const PASOS: int = 12


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "santa_compana_vela"
	var clip: String = args[1] if args.size() > 1 else "Walking"
	var glb: String = String(Pj3D.MODELO_DE.get(id, id))
	var modelo: Node3D = (load("res://arte/modelos/%s.glb" % glb) as PackedScene).instantiate()
	root.add_child(modelo)
	var sk: Skeleton3D = modelo.find_children("*", "Skeleton3D", true, false)[0]
	await process_frame
	print("id %s, modelo %s, clip %s" % [id, glb, clip])

	_pesos(modelo, sk)

	# Clips como en el juego: por id si la variante tiene fuente propia, si no por GLB.
	var clave: String = id if ClipsFamilia.tiene_fuente(id) else glb
	var todos: Dictionary = ClipsFamilia.clips_para(clave, modelo, sk)
	if not todos.has(clip):
		print("el clip no está. Hay: ", todos.keys())
		quit(1)
		return
	_clip(sk, todos[clip] as Animation)
	quit(0)


## Centroide lateral de los vértices que domina cada hueso de pierna, frente a la X del propio hueso en reposo.
func _pesos(modelo: Node3D, sk: Skeleton3D) -> void:
	var huesos: Array[String] = ["LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot"]
	var suma: Dictionary = {}
	var cuenta: Dictionary = {}
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		var malla: Mesh = (mi as MeshInstance3D).mesh
		if malla == null:
			continue
		for s in malla.get_surface_count():
			var ar: Array = malla.surface_get_arrays(s)
			var vs: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
			var bs: PackedInt32Array = ar[Mesh.ARRAY_BONES]
			var ws: PackedFloat32Array = ar[Mesh.ARRAY_WEIGHTS]
			if bs.is_empty() or ws.is_empty():
				continue
			var por_v: int = bs.size() / vs.size()
			for v in vs.size():
				# el hueso con más peso de este vértice
				var mejor: int = -1
				var w_mejor: float = 0.0
				for k in por_v:
					if ws[v * por_v + k] > w_mejor:
						w_mejor = ws[v * por_v + k]
						mejor = bs[v * por_v + k]
				if mejor < 0:
					continue
				var n: String = String(sk.get_bone_name(mejor))
				for h in huesos:
					if n.ends_with(h):
						suma[h] = float(suma.get(h, 0.0)) + vs[v].x
						cuenta[h] = int(cuenta.get(h, 0)) + 1
						break
	print("  PESOS (eje lateral X; el signo tiene que coincidir)")
	for h in huesos:
		var i: int = _hueso(sk, h)
		if i < 0 or int(cuenta.get(h, 0)) == 0:
			print("    %-11s sin datos" % h)
			continue
		var cx: float = float(suma[h]) / float(cuenta[h])
		var hx: float = sk.get_bone_global_rest(i).origin.x
		var ok: String = "ok" if signf(cx) == signf(hx) else "<<< CRUZADO"
		print("    %-11s hueso x %+.3f   malla x %+.3f  (%d vértices)  %s" % [h, hx, cx, int(cuenta[h]), ok])


## X (lateral) y Z (adelante) de cada pie a lo largo del clip, y si cambian de lado.
func _clip(sk: Skeleton3D, an: Animation) -> void:
	var i_izq: int = _hueso(sk, "LeftFoot")
	var i_der: int = _hueso(sk, "RightFoot")
	var i_rizq: int = _hueso(sk, "LeftLeg")
	var i_rder: int = _hueso(sk, "RightLeg")
	var i_cad: int = _hueso(sk, "Hips")
	if i_izq < 0 or i_der < 0:
		return
	var s_izq: float = signf(sk.get_bone_global_rest(i_izq).origin.x)
	var sep_reposo: float = absf(sk.get_bone_global_rest(i_izq).origin.x - sk.get_bone_global_rest(i_der).origin.x)
	var sep_rod_reposo: float = absf(sk.get_bone_global_rest(i_rizq).origin.x - sk.get_bone_global_rest(i_rder).origin.x)
	print("  CLIP (%.2f s; en REPOSO los pies están a %+.3f y las rodillas a %+.3f)" % [an.length, sep_reposo, sep_rod_reposo])
	print("    t      pies: izq (x,z)        der (x,z)      separación    rodillas: sep.    lado")
	var cruces: int = 0
	for k in range(PASOS + 1):
		var t: float = an.length * float(k) / float(PASOS)
		var pos: Dictionary = _pose(sk, an, t)
		var pi: Vector3 = pos[i_izq]
		var pd: Vector3 = pos[i_der]
		var sep_rod: float = (pos[i_rizq] as Vector3).x - (pos[i_rder] as Vector3).x
		var cx: float = (pos[i_cad] as Vector3).x if i_cad >= 0 else 0.0
		# «cruzado» = el pie (o la rodilla) izquierdo al lado derecho del eje del cuerpo, y viceversa
		var cruzado: bool = (pi.x - cx) * s_izq < 0.0 or (pd.x - cx) * s_izq > 0.0 or sep_rod * s_izq < 0.0
		if cruzado:
			cruces += 1
		print("    %.2f  (%+.3f,%+.3f)  (%+.3f,%+.3f)   %+.3f        %+.3f    %s" % [
			t, pi.x, pi.z, pd.x, pd.z, pi.x - pd.x, sep_rod, "CRUZADO" if cruzado else ""])
	print("    fotogramas con las piernas cruzadas: %d de %d" % [cruces, PASOS + 1])


## Posición (espacio del esqueleto) de todos los huesos con el clip `an` en el instante `t`.
func _pose(sk: Skeleton3D, an: Animation, t: float) -> Dictionary:
	var rot: Dictionary = {}
	var cadera: int = sk.find_bone("mixamorig_Hips")
	var p_cad: Vector3 = sk.get_bone_rest(cadera).origin if cadera >= 0 else Vector3.ZERO
	for p in range(an.get_track_count()):
		var b: int = sk.find_bone(String(an.track_get_path(p)).get_slice(":", 1))
		if b < 0 or an.track_get_key_count(p) == 0:
			continue
		if an.track_get_type(p) == Animation.TYPE_ROTATION_3D:
			rot[b] = an.rotation_track_interpolate(p, t)
		elif an.track_get_type(p) == Animation.TYPE_POSITION_3D and b == cadera:
			p_cad = an.position_track_interpolate(p, t)
	var g: Dictionary = {}
	var res: Dictionary = {}
	for i in _orden(sk):
		var q: Quaternion = rot.get(i, sk.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion())
		var loc := Transform3D(Basis(q), p_cad if i == cadera else sk.get_bone_rest(i).origin)
		var p: int = sk.get_bone_parent(i)
		g[i] = loc if p < 0 else (g[p] as Transform3D) * loc
		res[i] = (g[i] as Transform3D).origin
	return res


func _orden(sk: Skeleton3D) -> Array:
	var res: Array = []
	var visto: Dictionary = {}
	for i in range(sk.get_bone_count()):
		var cadena: Array = []
		var b: int = i
		while b >= 0 and not visto.has(b):
			cadena.push_front(b)
			visto[b] = true
			b = sk.get_bone_parent(b)
		res.append_array(cadena)
	return res


func _hueso(sk: Skeleton3D, fin: String) -> int:
	for b in sk.get_bone_count():
		var n := String(sk.get_bone_name(b))
		if n == fin or n.ends_with("_" + fin) or n.ends_with(":" + fin):
			return b
	return -1
