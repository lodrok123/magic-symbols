extends SceneTree
## Separa la «colección» de Meshy del hogar rústico (arte/meshy/piezas/coleccion_hogar_rustico.glb: seis piezas en una sola malla, en dos filas
## de tres) en seis mallas sueltas arte/meshy/piezas/hogar_<pieza>.res, cada una con el origen en el centro de su base (apoyada en y = 0).
##   godot --headless --path . --script res://herramientas/separar_coleccion_hogar.gd
## Cada triángulo va a la pieza de su casilla (3 columnas por X × 2 filas por Z). Las piezas no se tocan entre sí, así que el corte es limpio.

const ORIGEN := "res://arte/meshy/piezas/coleccion_hogar_rustico.glb"
## Fila de arriba y fila de abajo (la colección está de pie), de izquierda a derecha vistas de frente.
const NOMBRES := [["horno_pan", "varas_ahumado", "arca_grano"], ["yugo_aperos", "cesto", "telar"]]


func _initialize() -> void:
	var raiz: Node3D = (load(ORIGEN) as PackedScene).instantiate()
	var mi: MeshInstance3D = raiz.find_children("*", "MeshInstance3D", true, false)[0]
	var mat: Material = mi.mesh.surface_get_material(0)
	var a: Array = mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var bb := mi.get_aabb()
	# 1. Trozos conectados: dos triángulos van juntos si comparten un vértice (por posición: Meshy duplica vértices en las costuras de UV).
	var padre := PackedInt32Array()
	padre.resize(v.size())
	for i in range(v.size()):
		padre[i] = i
	var por_pos := {}
	for i in range(v.size()):
		var clave_p := Vector3i(roundi(v[i].x * 20000.0), roundi(v[i].y * 20000.0), roundi(v[i].z * 20000.0))
		if por_pos.has(clave_p):
			padre = _unir(padre, i, por_pos[clave_p])
		else:
			por_pos[clave_p] = i
	for k in range(0, idx.size(), 3):
		padre = _unir(padre, idx[k], idx[k + 1])
		padre = _unir(padre, idx[k], idx[k + 2])
	var trozos := {}          # raíz -> {tri: PackedInt32Array, caja: AABB}
	for k in range(0, idx.size(), 3):
		var r := _raiz(padre, idx[k])
		var t: Dictionary = trozos.get(r, {"tri": PackedInt32Array(), "caja": AABB(v[idx[k]], Vector3.ZERO)})
		var lista: PackedInt32Array = t["tri"]
		lista.append_array([idx[k], idx[k + 1], idx[k + 2]])
		t["tri"] = lista
		var cj: AABB = t["caja"]
		for j in range(3):
			cj = cj.expand(v[idx[k + j]])
		t["caja"] = cj
		trozos[r] = t
	# 2. Los trozos cuyas cajas se tocan (con un margen pequeño) son la misma pieza.
	var piezas: Array = []
	for r in trozos:
		piezas.append({"tri": trozos[r]["tri"], "caja": trozos[r]["caja"]})
	var cambio := true
	while cambio:
		cambio = false
		for i in range(piezas.size()):
			for j in range(i + 1, piezas.size()):
				if (piezas[i]["caja"] as AABB).intersects(piezas[j]["caja"]):
					var li: PackedInt32Array = piezas[i]["tri"]
					li.append_array(piezas[j]["tri"])
					piezas[i]["tri"] = li
					piezas[i]["caja"] = (piezas[i]["caja"] as AABB).merge(piezas[j]["caja"])
					piezas.remove_at(j)
					cambio = true
					break
			if cambio:
				break
	print("piezas encontradas: %d" % piezas.size())
	for p in piezas:
		print("  pieza centro %s tamaño %s triángulos %d" % [(p["caja"] as AABB).get_center(), (p["caja"] as AABB).size, (p["tri"] as PackedInt32Array).size() / 3])
	# 3. La colección está DE PIE, como un escaparate: tres columnas en X y dos filas en ALTURA (Y). Cada trozo conectado va a la casilla de su centro
	#    (juntar por cajas que se tocan mezclaba el horno de arriba con los aperos de abajo).
	var grupos := {}
	var izquierda := bb.position.x + bb.size.x / 3.0
	for r in trozos.keys():
		# La base del horno y la barra de los aperos vienen soldadas en un mismo trozo: en la columna izquierda se reparte triángulo a triángulo por su
		# profundidad (el horno atrás, z < 0,07; los aperos delante).
		if (trozos[r]["caja"] as AABB).get_center().x < izquierda:
			var tri: PackedInt32Array = trozos[r]["tri"]
			for k in range(0, tri.size(), 3):
				var ct := (v[tri[k]] + v[tri[k + 1]] + v[tri[k + 2]]) / 3.0
				# aperos: delante y de la barra hacia abajo; todo lo demás es el horno (que es hondo y su frente llega hasta z ≈ 0,2)
				var es_apero := (ct.z > 0.09 and ct.y < 0.0) or ct.y < -0.07      # …y lo que cuelga por debajo de la base del horno (y ≈ −0,076; su cara de abajo no se ve)
				var clave_i := Vector2i(0, 1 if es_apero else 0)
				var li: PackedInt32Array = grupos.get(clave_i, PackedInt32Array())
				li.append_array([tri[k], tri[k + 1], tri[k + 2]])
				grupos[clave_i] = li
			trozos.erase(r)
	for r in trozos:
		var c: Vector3 = (trozos[r]["caja"] as AABB).get_center()
		var col := clampi(int((c.x - bb.position.x) / bb.size.x * 3.0), 0, 2)
		var fila := 0 if c.y >= bb.get_center().y else 1
		# En la columna izquierda el horno (base y cúpula, atrás: z ≈ 0,0) y los aperos (delante: z > 0,08) se solapan en altura: se separan por profundidad.
		if col == 0:
			fila = 0 if c.z < 0.06 else 1
		var clave := Vector2i(col, fila)
		var lista: PackedInt32Array = grupos.get(clave, PackedInt32Array())
		lista.append_array(trozos[r]["tri"])
		grupos[clave] = lista
	for clave in grupos:
		var tri: PackedInt32Array = grupos[clave]
		# Vértices usados y su caja.
		var usados := {}
		for i in tri:
			usados[i] = true
		var caja := AABB(v[tri[0]], Vector3.ZERO)
		for i in usados:
			caja = caja.expand(v[i])
		var desplaza := Vector3(-caja.get_center().x, -caja.position.y, -caja.get_center().z)
		# Arrays compactos solo con esos vértices.
		var mapa := {}
		var nuevo: Array = []
		nuevo.resize(Mesh.ARRAY_MAX)
		for tipo in range(Mesh.ARRAY_MAX):
			if tipo == Mesh.ARRAY_INDEX or a[tipo] == null:
				continue
			nuevo[tipo] = a[tipo].duplicate()
			nuevo[tipo].resize(0)
		var orden: Array = usados.keys()
		orden.sort()
		for i in orden:
			mapa[i] = mapa.size()
			for tipo in range(Mesh.ARRAY_MAX):
				if tipo == Mesh.ARRAY_INDEX or a[tipo] == null:
					continue
				var por := 4 if tipo == Mesh.ARRAY_TANGENT else 1
				for p in range(por):
					nuevo[tipo].append(a[tipo][i * por + p])
		var vv: PackedVector3Array = nuevo[Mesh.ARRAY_VERTEX]
		for j in range(vv.size()):
			vv[j] += desplaza
		nuevo[Mesh.ARRAY_VERTEX] = vv
		var ni := PackedInt32Array()
		for i in tri:
			ni.append(mapa[i])
		nuevo[Mesh.ARRAY_INDEX] = ni
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, nuevo)
		am.surface_set_material(0, mat)
		var nombre: String = NOMBRES[clave.y][clave.x]
		var destino := "res://arte/meshy/piezas/hogar_%s.res" % nombre
		print("%s: %d triángulos, mide %s · guardar=%d" % [nombre, tri.size() / 3, caja.size, ResourceSaver.save(am, destino)])
	raiz.free()
	quit()


func _raiz(p: PackedInt32Array, i: int) -> int:
	while p[i] != i:
		i = p[i]
	return i


func _unir(p: PackedInt32Array, a: int, b: int) -> PackedInt32Array:
	var ra := _raiz(p, a)
	var rb := _raiz(p, b)
	if ra != rb:
		p[maxi(ra, rb)] = mini(ra, rb)
	return p
