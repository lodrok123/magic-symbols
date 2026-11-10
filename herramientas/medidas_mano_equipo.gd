extends SceneTree
## Medidas para colocar una pieza de Equipo3D en la mano de un modelo:
##   godot --path . --headless --script res://herramientas/medidas_mano_equipo.gd -- <id_modelo>
## Por cada mano imprime la base del hueso en el mundo, el giro que deja el +Y de la pieza VERTICAL con el modelo en reposo, y el
## CENTRO DEL PUÑO medido sobre la malla skinneada (vértices con al menos la mitad del peso en la mano y sus dedos), pasado al
## espacio del hueso: eso es lo que va en el campo de posición de Equipo3D.EQUIPO, sin tener que probar números a ojo.

func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "santa_compana_rig"
	var ruta: String = "res://arte/modelos/%s.glb" % id
	if not ResourceLoader.exists(ruta):
		push_error("no existe " + ruta)
		quit(1)
		return
	var modelo: Node3D = (load(ruta) as PackedScene).instantiate()
	root.add_child(modelo)
	var sk: Skeleton3D = modelo.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = null
	for n in modelo.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).skin != null:
			mi = n as MeshInstance3D
			break
	await process_frame
	print("modelo: ", ruta)
	for mano in ["RightHand", "LeftHand"]:
		var i: int = _hueso(sk, mano)
		if i < 0:
			print(mano, ": no está")
			continue
		var tb: Transform3D = sk.global_transform * sk.get_bone_global_pose(i)
		var base: Basis = tb.basis.orthonormalized()
		print("%s: +X %s  +Y %s  +Z %s" % [mano, _v(base.x), _v(base.y), _v(base.z)])
		var objetivo: Vector3 = (base.inverse() * Vector3.UP).normalized()
		var e: Vector3 = Basis(Quaternion(Vector3.UP, objetivo)).get_euler()
		print("   giro para dejar el +Y de la pieza VERTICAL: (%.1f, %.1f, %.1f)" % [rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)])
		var centro: Vector3 = _centro_puno(sk, mi, mano) if mi != null else Vector3(INF, INF, INF)
		if centro.x == INF:
			centro = _centro_por_huesos(sk, mano)
			print("   (puño por HUESOS: la malla no se pudo leer)")
		if centro.x == INF:
			print("   (no se pudo medir el puño)")
			continue
		var local: Vector3 = tb.affine_inverse() * centro
		print("   centro del puño: mundo %s  ->  posición en el espacio del hueso %s" % [_v(centro), _v(local)])
	quit(0)


func _hueso(sk: Skeleton3D, fin: String) -> int:
	for b in sk.get_bone_count():
		var n := String(sk.get_bone_name(b))
		if n == fin or n.ends_with("_" + fin) or n.ends_with(":" + fin):
			return b
	return -1


## Centro de los vértices con ≥ 50 % de peso en la mano o en sus dedos. La malla manda: el hueso solo dice dónde empieza la muñeca.
func _centro_puno(sk: Skeleton3D, mi: MeshInstance3D, mano: String) -> Vector3:
	var lado: String = "Right" if mano.begins_with("Right") else "Left"
	var quiero: Dictionary = {}
	for b in sk.get_bone_count():
		var n := String(sk.get_bone_name(b))
		if n.contains(lado + "Hand"):
			quiero[b] = true
	var malla: Mesh = mi.mesh
	var skin: Skin = mi.skin
	var mapa: Dictionary = {}
	for k in skin.get_bind_count():
		mapa[k] = skin.get_bind_bone(k)
	var suma := Vector3.ZERO
	var n_v: int = 0
	for s in malla.get_surface_count():
		var arr: Array = malla.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var hs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		if hs.is_empty() or vs.is_empty():
			continue
		var por_v: int = hs.size() / vs.size()
		for v in vs.size():
			var peso: float = 0.0
			for k in por_v:
				var bruto: int = hs[v * por_v + k]
				var bi: int = int(mapa.get(bruto, bruto))
				if quiero.has(bi):
					peso += ws[v * por_v + k]
			if peso >= 0.5:
				suma += mi.global_transform * vs[v]
				n_v += 1
	if n_v == 0:
		return Vector3(INF, INF, INF)
	print("   (vértices del puño: %d)" % n_v)
	return suma / float(n_v)


## Alternativa sin malla: el centro del puño es la media de la primera falange de los cuatro dedos (los nudillos), que es donde
## se cierra la mano sobre un mango.
func _centro_por_huesos(sk: Skeleton3D, mano: String) -> Vector3:
	var lado: String = "Right" if mano.begins_with("Right") else "Left"
	var suma := Vector3.ZERO
	var n: int = 0
	for dedo in ["Index1", "Middle1", "Ring1", "Pinky1"]:
		var b: int = _hueso(sk, lado + "Hand" + dedo)
		if b < 0:
			continue
		suma += (sk.global_transform * sk.get_bone_global_pose(b)).origin
		n += 1
	if n == 0:
		return Vector3(INF, INF, INF)
	print("   (puño por %d nudillos)" % n)
	return suma / float(n)


func _v(v: Vector3) -> String:
	return "(%+.3f,%+.3f,%+.3f)" % [v.x, v.y, v.z]
