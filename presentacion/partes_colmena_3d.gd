extends RefCounted
## Rama y cera son islas desconectadas dentro de la misma malla. Identificarlas
## por continuidad evita dejar cuello de cera o amputar la punta de la rama.
## La soldadura solo clasifica; se conservan normales y UV de cada vértice.
static func _raiz(padres: Array[int], i: int) -> int:
	while padres[i] != i:
		padres[i] = padres[padres[i]]
		i = padres[i]
	return i

static func crear(original: Node3D) -> Node3D:
	var triangulos: Array = []
	var padres: Array[int] = []
	var posiciones: Dictionary = {}
	for mi in original.find_children("*","MeshInstance3D",true,false):
		if mi.mesh == null: continue
		var tf: Transform3D = original.global_transform.affine_inverse()*mi.global_transform
		var normal_tf: Basis = tf.basis.inverse().transposed()
		for s in mi.mesh.get_surface_count():
			var a: Array = mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for i in vs.size(): indices.append(i)
			for i in range(0,indices.size(),3):
				var id: int = padres.size()
				padres.append(id)
				var vertices: Array = []
				for j in 3:
					var k: int = indices[i+j]
					var v: Vector3 = tf*vs[k]
					vertices.append([v,(normal_tf*ns[k]).normalized(),uv[k]])
					var clave := Vector3i((v*10000.0).round())
					if posiciones.has(clave): padres[_raiz(padres,id)] = _raiz(padres,posiciones[clave])
					else: posiciones[clave] = id
				triangulos.append([vertices,mi.get_active_material(s)])
	var grupos: Dictionary = {}
	for i in triangulos.size():
		var id: int = _raiz(padres,i)
		if not grupos.has(id): grupos[id] = AABB(triangulos[i][0][0][0],Vector3.ZERO)
		for v in triangulos[i][0]: grupos[id] = grupos[id].expand(v[0])
	# La rama es la isla más alta del asset; los insectos y la cera quedan debajo.
	var rama: int = -1
	var alto: float = -INF
	for id in grupos:
		if grupos[id].end.y > alto:
			alto = grupos[id].end.y
			rama = id
	var resultado := Node3D.new()
	for superior in [true,false]:
		var parte := Node3D.new()
		parte.name = "soporte" if superior else "panal"
		resultado.add_child(parte)
		var superficies: Dictionary = {}
		for i in triangulos.size():
			if (_raiz(padres,i) == rama) != superior: continue
			var mat: Material = triangulos[i][1]
			if not superficies.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				superficies[mat] = st
			var st: SurfaceTool = superficies[mat]
			for v in triangulos[i][0]:
				st.set_normal(v[1])
				st.set_uv(v[2])
				st.add_vertex(v[0])
		for mat in superficies:
			var st: SurfaceTool = superficies[mat]
			st.generate_tangents()
			var malla := MeshInstance3D.new()
			malla.mesh = st.commit()
			var copia: Material = mat.duplicate()
			if superior and copia is StandardMaterial3D:
				# Madera más sobria, con la veta y los anillos originales.
				copia.albedo_color *= Color(0.78,0.88,1.0)
			malla.material_override = copia
			parte.add_child(malla)
	return resultado
