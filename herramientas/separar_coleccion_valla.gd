extends SceneTree
## Separa la colección de Meshy de la valla modular (arte/meshy/piezas/coleccion_valla.glb: cuatro piezas de pie en 2 × 2) en
## arte/meshy/piezas/valla_<pieza>.res, cada una con el origen en el centro de su base (apoyada en y = 0).
##   godot --headless --path . --script res://herramientas/separar_coleccion_valla.gd
## Cada trozo conectado va a la casilla de su centro (2 columnas en X × 2 filas en Y).

const ORIGEN := "res://arte/meshy/piezas/coleccion_valla.glb"
## Fila de arriba y de abajo, de izquierda a derecha vistas de frente.
const NOMBRES := [["tramo_a", "tramo_b"], ["esquina", "cancela"]]


func _initialize() -> void:
	var raiz: Node3D = (load(ORIGEN) as PackedScene).instantiate()
	var mi: MeshInstance3D = raiz.find_children("*", "MeshInstance3D", true, false)[0]
	var mat: Material = mi.mesh.surface_get_material(0)
	var a: Array = mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var bb := mi.get_aabb()
	print("colección mide ", bb)
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
	var grupos := {}
	for k in range(0, idx.size(), 3):
		var r := _raiz(padre, idx[k])
		var g: Array = grupos.get(r, [PackedInt32Array(), AABB(v[idx[k]], Vector3.ZERO)])
		var li: PackedInt32Array = g[0]
		li.append_array([idx[k], idx[k + 1], idx[k + 2]])
		g[0] = li
		var cj: AABB = g[1]
		for j in range(3):
			cj = cj.expand(v[idx[k + j]])
		g[1] = cj
		grupos[r] = g
	var piezas := {}
	for r in grupos:
		var c: Vector3 = (grupos[r][1] as AABB).get_center()
		var clave := Vector2i(0 if c.x < bb.get_center().x else 1, 0 if c.y >= bb.get_center().y else 1)
		var li: PackedInt32Array = piezas.get(clave, PackedInt32Array())
		li.append_array(grupos[r][0])
		piezas[clave] = li
	for clave in piezas:
		var tri: PackedInt32Array = piezas[clave]
		var usados := {}
		for i in tri:
			usados[i] = true
		var caja := AABB(v[tri[0]], Vector3.ZERO)
		for i in usados:
			caja = caja.expand(v[i])
		var desplaza := Vector3(-caja.get_center().x, -caja.position.y, -caja.get_center().z)
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
		print("%s: %d triángulos, mide %s · guardar=%d" % [nombre, tri.size() / 3, caja.size, ResourceSaver.save(am, "res://arte/meshy/piezas/valla_%s.res" % nombre)])
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
