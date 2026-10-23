class_name MallaReducida3D
extends RefCounted
## UNA MALLA CON MENOS TRIÁNGULOS, hecha en el juego (bloque 4 de la revisión EoW, 23/10), sin exportar nada de nuevo: los mismos vértices y
## los índices de un nivel de detalle que calcula Godot (`ImporterMesh.generate_lods`, el simplificador de meshoptimizer que usa al importar).
##
## PARA QUÉ. Medido en el Bosque (herramientas/medir_rendimiento.gd, Intel UHD 620): la pasada de SOMBRA del sol dibuja todos los árboles del
## mapa (≈ 3,8 M de triángulos de 4,35 M por fotograma), mientras la cámara solo dibuja lo que ve (≈ 0,55 M). Una sombra no necesita las hojas
## una a una: con una copia reducida que solo PROYECTA sombra (y el árbol de verdad que no la proyecta) la silueta es casi la misma.
## EoW hace algo parecido por otro camino: árboles de ~850 triángulos (docs/estudios/eow/EOW_4_ASSETS.md §6.6).
##
## `reducir(malla, fraccion)` devuelve una ArrayMesh con las mismas superficies y materiales y, en cada una, el nivel de detalle cuyo número de
## triángulos se acerca más a `fraccion` del original (sin bajar de él). Si no se puede (malla sin índices, sin niveles), devuelve la original.
## Se guarda en caché por malla: cada id del decorado se reduce una vez.
##
## OJO: las mallas de Meshy llegan como TRIÁNGULOS SUELTOS (36 000 vértices para 36 000 índices en el árbol: ningún vértice compartido, por las
## costuras de UV y las normales por cara). Así el simplificador no encuentra nada que unir y no genera ningún nivel. Por eso, ANTES, se
## SUELDAN los vértices por posición (se pierden UV y normales: esta malla es para SOMBRA, que no las usa) y se recalculan normales suaves.

static var _cache: Dictionary = {}      ## "<id de instancia>|<fracción>" -> ArrayMesh


static func reducir(malla: Mesh, fraccion: float = 0.125) -> Mesh:
	if malla == null or not (malla is ArrayMesh):
		return malla
	var clave: String = "%d|%.3f" % [malla.get_instance_id(), fraccion]
	if _cache.has(clave):
		return _cache[clave]
	var am: ArrayMesh = malla as ArrayMesh
	var soldadas: Array = []
	var im := ImporterMesh.new()
	for s in range(am.get_surface_count()):
		var sol: Array = _soldar(am.surface_get_arrays(s))
		soldadas.append(sol)
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, sol, [], {}, am.surface_get_material(s), am.surface_get_name(s))
	# 60° para fundir normales (como el importador de Godot) y 25° para partir; sin huesos.
	im.generate_lods(60.0, 25.0, [])
	var res := ArrayMesh.new()
	var reducida: bool = false
	for s in range(am.get_surface_count()):
		var arrays: Array = soldadas[s]
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		var total: int = (idx as PackedInt32Array).size() if idx is PackedInt32Array else 0
		var mejor: PackedInt32Array = PackedInt32Array()
		if total > 0:
			for l in range(im.get_surface_lod_count(s)):
				var li: PackedInt32Array = im.get_surface_lod_indices(s, l)
				if li.size() >= int(float(total) * fraccion) and (mejor.is_empty() or li.size() < mejor.size()):
					mejor = li
		if not mejor.is_empty() and mejor.size() < total:
			arrays[Mesh.ARRAY_INDEX] = mejor
			reducida = true
		res.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		res.surface_set_material(s, am.surface_get_material(s))
	var salida: Mesh = res if reducida else malla
	_cache[clave] = salida
	return salida


## Une los vértices que están en la misma posición (a 0,1 mm) y devuelve arrays con solo posición, normales suaves e índices.
static func _soldar(arrays: Array) -> Array:
	var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx_orig: Variant = arrays[Mesh.ARRAY_INDEX]
	var orden: PackedInt32Array = idx_orig if idx_orig is PackedInt32Array and (idx_orig as PackedInt32Array).size() > 0 else PackedInt32Array(range(vs.size()))
	var mapa: Dictionary = {}
	var nuevos: PackedVector3Array = PackedVector3Array()
	var idx: PackedInt32Array = PackedInt32Array()
	idx.resize(orden.size())
	for i in range(orden.size()):
		var p: Vector3 = vs[orden[i]]
		var k: Vector3i = Vector3i(roundi(p.x * 10000.0), roundi(p.y * 10000.0), roundi(p.z * 10000.0))
		var j: int = mapa.get(k, -1)
		if j < 0:
			j = nuevos.size()
			mapa[k] = j
			nuevos.append(p)
		idx[i] = j
	# Normales suaves: suma de las normales de cara de cada vértice.
	var ns: PackedVector3Array = PackedVector3Array()
	ns.resize(nuevos.size())
	for t in range(0, idx.size() - 2, 3):
		var a: Vector3 = nuevos[idx[t]]
		var n: Vector3 = (nuevos[idx[t + 1]] - a).cross(nuevos[idx[t + 2]] - a)
		for e in range(3):
			ns[idx[t + e]] += n
	for v in range(ns.size()):
		ns[v] = ns[v].normalized() if ns[v].length_squared() > 0.0 else Vector3.UP
	var res: Array = []
	res.resize(Mesh.ARRAY_MAX)
	res[Mesh.ARRAY_VERTEX] = nuevos
	res[Mesh.ARRAY_NORMAL] = ns
	res[Mesh.ARRAY_INDEX] = idx
	return res


## Triángulos de una malla (para medir lo que se ahorra).
static func triangulos(malla: Mesh) -> int:
	var t: int = 0
	if malla == null:
		return 0
	for s in range(malla.get_surface_count()):
		var arrays: Array = malla.surface_get_arrays(s)
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
			t += (idx as PackedInt32Array).size() / 3
		elif arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			t += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t
