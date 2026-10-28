extends SceneTree
## Comprueba arte/modelos/golem_piedra_rig.glb (salida de tools/autorig_golem.py). Headless:
##   Godot --headless --path . --script res://herramientas/prueba_rig_golem.gd
## Mira: Skeleton3D con huesos Mixamo; todos los vertices con peso; ninguna roca repartida entre huesos lejanos; y una pose de prueba (brazos arriba 120 grados,
## rodilla derecha 60 grados, cabeza 30 grados) midiendo cuanto se alargan las aristas respecto al reposo.

const RUTA: String = "res://arte/modelos/golem_piedra_rig.glb"
const ESPERADOS: Array = ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "RightShoulder", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm",
	"LeftHand", "RightHand", "LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]


func _initialize() -> void:
	var modelo: Node3D = (load(RUTA) as PackedScene).instantiate()
	root.add_child(modelo)
	await process_frame
	var sk: Skeleton3D = modelo.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = modelo.find_children("*", "MeshInstance3D", true, false)[0]
	print("Skeleton3D con %d huesos; animaciones: %d" % [sk.get_bone_count(), modelo.find_children("*", "AnimationPlayer", true, false).size()])
	var faltan: Array = []
	for e in ESPERADOS:
		if sk.find_bone("mixamorig_" + e) < 0:
			faltan.append(e)
	print("huesos Mixamo que faltan: ", faltan)
	var a: Array = mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var hu: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var pe: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var sin_peso: int = 0
	var max_inf: int = 0
	for i in v.size():
		var s: float = 0.0
		var n: int = 0
		for k in 4:
			s += pe[i * 4 + k]
			if pe[i * 4 + k] > 0.001:
				n += 1
		max_inf = maxi(max_inf, n)
		if s < 0.99:
			sin_peso += 1
	print("vertices %d  sin peso (suma<0,99): %d  influencias max por vertice: %d  tris %d" % [v.size(), sin_peso, max_inf, idx.size() / 3])
	# Rocas: componentes por posicion soldada; para cada una, huesos dominantes distintos y distancia maxima entre ellos en reposo.
	var par := PackedInt32Array()
	par.resize(v.size())
	for i in v.size():
		par[i] = i
	var f := func(x: int) -> int:
		while par[x] != x:
			par[x] = par[par[x]]
			x = par[x]
		return x
	var pos := {}
	for i in v.size():
		var k := Vector3i(roundi(v[i].x * 2000), roundi(v[i].y * 2000), roundi(v[i].z * 2000))
		if pos.has(k):
			par[f.call(i)] = f.call(pos[k])
		else:
			pos[k] = i
	for i in range(0, idx.size(), 3):
		for j in 2:
			var r0: int = f.call(idx[i])
			var r1: int = f.call(idx[i + 1 + j])
			if r0 != r1:
				par[r1] = r0
	var rocas := {}
	for i in v.size():
		var r: int = f.call(i)
		if not rocas.has(r):
			rocas[r] = {}
		var dom: int = hu[i * 4]
		var wd: float = pe[i * 4]
		for k in 4:
			if pe[i * 4 + k] > wd:
				wd = pe[i * 4 + k]
				dom = hu[i * 4 + k]
		rocas[r][dom] = rocas[r].get(dom, 0) + 1
	var rigidas: int = 0
	var mezcladas: int = 0
	var lejanas: int = 0
	var rest_pos: Array = []
	for b in sk.get_bone_count():
		rest_pos.append(sk.get_bone_global_rest(b).origin)
	var skin: Skin = mi.skin
	var mapa: Dictionary = {}
	for k in skin.get_bind_count():
		mapa[k] = sk.find_bone(skin.get_bind_name(k))
	for r in rocas:
		var d: Dictionary = rocas[r]
		if d.size() == 1:
			rigidas += 1
		else:
			mezcladas += 1
			var mx: float = 0.0
			for h1 in d:
				for h2 in d:
					mx = maxf(mx, (rest_pos[mapa[h1]] - rest_pos[mapa[h2]]).length())
			if mx > 0.2:
				lejanas += 1
				print("  roca repartida entre huesos lejanos (%.2f): %s" % [mx, d.keys().map(func(q): return sk.get_bone_name(mapa[q]))])
	print("rocas %d  rigidas (1 hueso) %d  con mezcla %d  mezcladas con huesos a >0,2: %d" % [rocas.size(), rigidas, mezcladas, lejanas])
	# Pose de prueba
	var reposo: PackedVector3Array = _piel(sk, skin, mapa, v, hu, pe)
	_giro(sk, "mixamorig_RightArm", Basis(Vector3.RIGHT, deg_to_rad(-120.0)))
	_giro(sk, "mixamorig_LeftArm", Basis(Vector3.RIGHT, deg_to_rad(-120.0)))
	_giro(sk, "mixamorig_RightLeg", Basis(Vector3.RIGHT, deg_to_rad(60.0)))
	_giro(sk, "mixamorig_Head", Basis(Vector3.UP, deg_to_rad(30.0)))
	sk.force_update_all_bone_transforms()
	var pose: PackedVector3Array = _piel(sk, skin, mapa, v, hu, pe)
	var peores: Array = []
	var n_mal: int = 0
	var n_ar: int = 0
	var suma: float = 0.0
	var emax: float = 0.0
	for i in range(0, idx.size(), 3):
		for j in 3:
			var p: int = idx[i + j]
			var q: int = idx[i + (j + 1) % 3]
			var l0: float = (v[p] - v[q]).length()
			if l0 < 0.004:
				continue
			var l1: float = (pose[p] - pose[q]).length()
			var rr: float = l1 / l0
			n_ar += 1
			suma += absf(rr - 1.0)
			if rr > 1.5 or rr < 0.6:
				n_mal += 1
			emax = maxf(emax, rr)
	print("pose (brazos 120, rodilla der 60, cabeza 30): aristas medidas %d  cambio medio %.3f%%  max estiramiento x%.2f  aristas con >50%% de cambio: %d (%.2f%%)" % [n_ar, 100.0 * suma / n_ar, emax, n_mal, 100.0 * n_mal / n_ar])
	quit(0)


## Gira el hueso `nombre` en el espacio del modelo (rotacion R sobre su reposo global) y deja la pose de los hijos relativa.
func _giro(sk: Skeleton3D, nombre: String, r: Basis) -> void:
	var b: int = sk.find_bone(nombre)
	var p: int = sk.get_bone_parent(b)
	var pg: Basis = sk.get_bone_global_pose(p).basis if p >= 0 else Basis.IDENTITY
	var deseada: Basis = r * sk.get_bone_global_rest(b).basis
	sk.set_bone_pose_rotation(b, (pg.inverse() * deseada).get_rotation_quaternion())


func _piel(sk: Skeleton3D, skin: Skin, mapa: Dictionary, v: PackedVector3Array, hu: PackedInt32Array, pe: PackedFloat32Array) -> PackedVector3Array:
	var m: Array = []
	for k in skin.get_bind_count():
		m.append(sk.get_bone_global_pose(mapa[k]) * skin.get_bind_pose(k))
	var o := PackedVector3Array()
	o.resize(v.size())
	for i in v.size():
		var p := Vector3.ZERO
		for k in 4:
			var w: float = pe[i * 4 + k]
			if w > 0.0:
				p += (m[hu[i * 4 + k]] * v[i]) * w
		o[i] = p
	return o
