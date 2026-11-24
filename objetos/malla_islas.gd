class_name MallaIslas
extends RefCounted

## ISLAS DE UNA MALLA (24/11/2026). Los modelos del pack Lost Cave vienen en UNA malla, pero sus piezas móviles (las ruedas de la vagoneta, el asa del
## detonador) son ISLAS sueltas de triángulos dentro de ella. Esto las encuentra y hace mallas nuevas con un trozo, para moverlas aparte.
## Una isla = triángulos unidos por vértices en la misma posición (las costuras de UV duplican vértices, así que se unen por posición, no por índice).

## Las islas de la superficie 0: [{idx: PackedInt32Array (sus triángulos), caja: AABB}] .
static func islas(m: Mesh) -> Array:
	var arr: Array = m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var padre: Dictionary = {}
	var clave: Array = []
	for p in v:
		var k: Vector3i = Vector3i(roundi(p.x * 2000.0), roundi(p.y * 2000.0), roundi(p.z * 2000.0))
		clave.append(k)
		if not padre.has(k):
			padre[k] = k
	var raiz: Callable = func(k) -> Variant:
		while padre[k] != k:
			padre[k] = padre[padre[k]]
			k = padre[k]
		return k
	for i in range(0, idx.size(), 3):
		var a = raiz.call(clave[idx[i]])
		for j in [1, 2]:
			var b = raiz.call(clave[idx[i + j]])
			if a != b:
				padre[b] = a
	var tris: Dictionary = {}
	var cajas: Dictionary = {}
	for i in range(0, idx.size(), 3):
		var r = raiz.call(clave[idx[i]])
		var lista: PackedInt32Array = tris.get(r, PackedInt32Array())     # un Packed*Array se copia al sacarlo: se añade y se vuelve a guardar
		lista.append_array([idx[i], idx[i + 1], idx[i + 2]])
		tris[r] = lista
		for j in 3:
			cajas[r] = (cajas[r] as AABB).expand(v[idx[i + j]]) if cajas.has(r) else AABB(v[idx[i + j]], Vector3.ZERO)
	var res: Array = []
	for r in tris:
		res.append({"idx": tris[r], "caja": cajas[r]})
	return res


## Una malla con solo los triángulos `idx` de la superficie 0 de `m`, corrida `-centro` (para girarla sobre `centro`). Mismo material.
static func malla_de(m: Mesh, idx: PackedInt32Array, centro: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var arr: Array = m.surface_get_arrays(0).duplicate()
	if centro != Vector3.ZERO:
		var va: PackedVector3Array = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
		for k in va.size():
			va[k] -= centro
		arr[Mesh.ARRAY_VERTEX] = va
	arr[Mesh.ARRAY_INDEX] = idx
	var res := ArrayMesh.new()
	res.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	res.surface_set_material(0, m.surface_get_material(0))
	return res
