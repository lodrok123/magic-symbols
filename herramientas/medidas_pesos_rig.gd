extends SceneTree
## AUDITORÍA DE LOS PESOS DE PIEL de un rig (pensada para los que salen de tools/autorig_fantasma.py).
##   godot --headless --path . --script res://herramientas/medidas_pesos_rig.gd -- <id del GLB>
## No mira poses: mira los pesos, que es donde nace cada defecto que luego se ve al animar.
##   1) INFLUENCIAS   cuántos huesos mueven cada vértice. Un vértice de un solo hueso es rígido: no hay transición.
##   2) DESGARROS     aristas cuyos dos extremos casi no comparten huesos. Ahí la malla se rasga en cuanto esos huesos se separan.
##   3) LADO CRUZADO  vértices de un lado del cuerpo que cuelgan de huesos del otro lado.
##   4) LEJOS         vértices cuyo hueso dominante está lejos de ellos (un pie que cuelga de la columna, p. ej.).
##   5) PIES          de qué huesos cuelga todo lo que hay por debajo del tobillo. Debería ser Foot/ToeBase de SU pierna.
##   6) MANGAS        de qué huesos cuelga lo que rodea a cada antebrazo.
## Todas las distancias en fracción del alto del modelo.

const DESGARRO: float = 0.75      ## 1 − (peso compartido) por encima de esto = los extremos de la arista van cada uno por su lado
const CRUZ_PESO: float = 0.25     ## peso mínimo en huesos del otro lado para contarlo como cruzado
const CRUZ_MARGEN: float = 0.02   ## y a más de esto del plano medio (los vértices del centro pueden ser de los dos lados)
const LEJOS: float = 0.20
const RADIO_MANGA: float = 0.10


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "fantasma_elfo_rig"
	var modelo: Node3D = (load("res://arte/modelos/%s.glb" % id) as PackedScene).instantiate()
	root.add_child(modelo)
	await process_frame
	var sk: Skeleton3D = modelo.find_children("*", "Skeleton3D", true, false)[0]

	# Segmento de cada hueso en el mundo (de su articulación a la de su primer hijo).
	var cab: Array[Vector3] = []
	var cola: Array[Vector3] = []
	for i in sk.get_bone_count():
		var a: Vector3 = sk.global_transform * sk.get_bone_global_rest(i).origin
		var hijos: PackedInt32Array = sk.get_bone_children(i)
		var b: Vector3 = a
		if hijos.size() > 0:
			b = sk.global_transform * sk.get_bone_global_rest(hijos[0]).origin
		cab.append(a)
		cola.append(b)

	var pos: Array[Vector3] = []          # posición en el mundo de cada vértice
	var pesos: Array[Dictionary] = []     # hueso del esqueleto -> peso
	var aristas: Dictionary = {}
	for n in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var ar: Array = mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
			var bs: PackedInt32Array = ar[Mesh.ARRAY_BONES]
			var ws: PackedFloat32Array = ar[Mesh.ARRAY_WEIGHTS]
			var idx: PackedInt32Array = ar[Mesh.ARRAY_INDEX]
			if bs.is_empty() or ws.is_empty():
				continue
			var por_v: int = bs.size() / vs.size()
			var base: int = pos.size()
			for v in vs.size():
				pos.append(mi.global_transform * vs[v])
				var d: Dictionary = {}
				for k in por_v:
					var w: float = ws[v * por_v + k]
					if w <= 0.0001:
						continue
					# OJO: ARRAY_BONES son índices del SKIN, no del esqueleto.
					var b: int = bs[v * por_v + k]
					if mi.skin != null:
						var nb: String = mi.skin.get_bind_name(b)
						b = sk.find_bone(nb) if nb != "" else mi.skin.get_bind_bone(b)
					d[b] = float(d.get(b, 0.0)) + w
				pesos.append(d)
			for t in range(0, idx.size(), 3):
				for e in [[0, 1], [1, 2], [2, 0]]:
					var a2: int = base + idx[t + e[0]]
					var b2: int = base + idx[t + e[1]]
					aristas[Vector2i(mini(a2, b2), maxi(a2, b2))] = true

	var y0: float = INF
	var y1: float = -INF
	for p in pos:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var alto: float = y1 - y0
	print("=== %s · %d vértices · %d aristas · alto %.3f · %d huesos" % [id, pos.size(), aristas.size(), alto, sk.get_bone_count()])

	# 1) influencias
	var hist: Dictionary = {}
	for d in pesos:
		hist[d.size()] = int(hist.get(d.size(), 0)) + 1
	var txt: String = ""
	for k in [0, 1, 2, 3, 4]:
		txt += "  %d huesos: %.1f %%" % [k, 100.0 * float(hist.get(k, 0)) / float(pos.size())]
	print("1) INFLUENCIAS  ", txt)

	# 2) desgarros
	var rotas: int = 0
	var pares: Dictionary = {}
	for e in aristas:
		var da: Dictionary = pesos[e.x]
		var db: Dictionary = pesos[e.y]
		var comun: float = 0.0
		for b in da:
			if db.has(b):
				comun += minf(float(da[b]), float(db[b]))
		if 1.0 - comun >= DESGARRO:
			rotas += 1
			var na: String = _nombre(sk, _dominante(da))
			var nb2: String = _nombre(sk, _dominante(db))
			var clave: String = (na + " | " + nb2) if na < nb2 else (nb2 + " | " + na)
			pares[clave] = int(pares.get(clave, 0)) + 1
	print("2) DESGARROS    %d aristas (%.2f %%) cuyos extremos comparten menos del %d %% del peso" % [
		rotas, 100.0 * float(rotas) / float(maxi(aristas.size(), 1)), int((1.0 - DESGARRO) * 100.0)])
	_top(pares, 10)

	# 3) lado cruzado
	var cruz: Dictionary = {}
	var n_cruz: int = 0
	for v in pos.size():
		var x: float = pos[v].x
		if absf(x) < CRUZ_MARGEN * alto:
			continue
		# en este rig los huesos Left están en +X (medido en medidas_piernas_clip.gd)
		var otro: String = "Right" if x > 0.0 else "Left"
		var w_otro: float = 0.0
		var cual: String = ""
		for b in pesos[v]:
			var nb3: String = _nombre(sk, int(b))
			if nb3.begins_with(otro) and float(pesos[v][b]) > 0.0:
				w_otro += float(pesos[v][b])
				cual = nb3
		if w_otro >= CRUZ_PESO:
			n_cruz += 1
			cruz[cual] = int(cruz.get(cual, 0)) + 1
	print("3) LADO CRUZADO %d vértices (%.2f %%) con ≥ %d %% de peso en huesos del otro lado" % [
		n_cruz, 100.0 * float(n_cruz) / float(pos.size()), int(CRUZ_PESO * 100.0)])
	_top(cruz, 8)

	# 4) lejos
	var lejos: Dictionary = {}
	var n_lejos: int = 0
	var peor: float = 0.0
	for v in pos.size():
		var b4: int = _dominante(pesos[v])
		if b4 < 0:
			continue
		var d4: float = _dist_segmento(pos[v], cab[b4], cola[b4]) / alto
		if d4 >= LEJOS:
			n_lejos += 1
			peor = maxf(peor, d4)
			var nb4: String = _nombre(sk, b4)
			lejos[nb4] = int(lejos.get(nb4, 0)) + 1
	print("4) LEJOS        %d vértices (%.2f %%) a ≥ %.2f del alto de su hueso dominante (el peor, %.2f)" % [
		n_lejos, 100.0 * float(n_lejos) / float(pos.size()), LEJOS, peor])
	_top(lejos, 8)

	# 5) pies
	for lado in ["Left", "Right"]:
		var i_pie: int = sk.find_bone("mixamorig_%sFoot" % lado)
		if i_pie < 0:
			continue
		var tobillo: Vector3 = cab[i_pie]
		var reparto: Dictionary = {}
		var total: float = 0.0
		for v in pos.size():
			var p5: Vector3 = pos[v]
			# por debajo del tobillo y en la vertical de ese pie (media anchura de separación entre pies)
			if p5.y > tobillo.y or absf(p5.x - tobillo.x) > absf(tobillo.x) * 0.9 + 0.01:
				continue
			for b in pesos[v]:
				var nb5: String = _nombre(sk, int(b))
				reparto[nb5] = float(reparto.get(nb5, 0.0)) + float(pesos[v][b])
				total += float(pesos[v][b])
		print("5) PIE %-6s    peso de todo lo que hay bajo el tobillo (%.0f vértices):" % [lado, total])
		_top_f(reparto, total, 7)

	# 6) mangas
	for lado in ["Left", "Right"]:
		var i_ante: int = sk.find_bone("mixamorig_%sForeArm" % lado)
		if i_ante < 0:
			continue
		var rep: Dictionary = {}
		var tot: float = 0.0
		for v in pos.size():
			if _dist_segmento(pos[v], cab[i_ante], cola[i_ante]) / alto > RADIO_MANGA:
				continue
			for b in pesos[v]:
				var nb6: String = _nombre(sk, int(b))
				rep[nb6] = float(rep.get(nb6, 0.0)) + float(pesos[v][b])
				tot += float(pesos[v][b])
		print("6) ANTEBRAZO %-6s peso de lo que está a menos de %.2f del alto del hueso (%.0f vértices):" % [lado, RADIO_MANGA, tot])
		_top_f(rep, tot, 7)
	quit(0)


func _dominante(d: Dictionary) -> int:
	var mejor: int = -1
	var w: float = 0.0
	for b in d:
		if float(d[b]) > w:
			w = float(d[b])
			mejor = int(b)
	return mejor


func _nombre(sk: Skeleton3D, b: int) -> String:
	return String(sk.get_bone_name(b)).trim_prefix("mixamorig_") if b >= 0 else "?"


func _dist_segmento(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var l2: float = ab.length_squared()
	if l2 < 1e-10:
		return p.distance_to(a)
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / l2, 0.0, 1.0))


func _top(d: Dictionary, n: int) -> void:
	var ks: Array = d.keys()
	ks.sort_custom(func(a, b): return int(d[a]) > int(d[b]))
	for i in mini(n, ks.size()):
		print("       %6d  %s" % [int(d[ks[i]]), ks[i]])


func _top_f(d: Dictionary, total: float, n: int) -> void:
	var ks: Array = d.keys()
	ks.sort_custom(func(a, b): return float(d[a]) > float(d[b]))
	for i in mini(n, ks.size()):
		print("       %5.1f %%  %s" % [100.0 * float(d[ks[i]]) / maxf(total, 0.001), ks[i]])
