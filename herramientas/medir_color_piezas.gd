extends SceneTree
## Color medio (ponderado por área) de cada pieza de Meshy, para compararlo con la paleta (Paleta3D). Herramienta de medida.
func _recoger(n: Node, t: Transform3D, fuera: Array) -> void:
	var tt: Transform3D = t
	if n is Node3D:
		tt = t * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		fuera.append([n, tt])
	for h in n.get_children():
		_recoger(h, tt, fuera)
func _medio(v: Node3D) -> Array:
	var lista: Array = []
	_recoger(v, Transform3D.IDENTITY, lista)
	var suma := Vector3.ZERO
	var peso: float = 0.0
	var imgs: Dictionary = {}
	for it in lista:
		var mi: MeshInstance3D = it[0]
		var tt: Transform3D = it[1]
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				for i in vs.size():
					idx.append(i)
			var img: Image = null
			var tint := Color.WHITE
			if m is StandardMaterial3D:
				var sm: StandardMaterial3D = m
				tint = sm.albedo_color
				if sm.albedo_texture != null:
					if not imgs.has(sm.albedo_texture):
						var im: Image = sm.albedo_texture.get_image()
						if im != null and im.is_compressed():
							im.decompress()
						imgs[sm.albedo_texture] = im
					img = imgs[sm.albedo_texture]
			for q in range(0, idx.size(), 3):
				var a: Vector3 = tt * vs[idx[q]]
				var b: Vector3 = tt * vs[idx[q + 1]]
				var c: Vector3 = tt * vs[idx[q + 2]]
				var area: float = (b - a).cross(c - a).length() * 0.5
				if area <= 0.0:
					continue
				var col := tint
				if img != null and uv.size() > 0:
					var u: Vector2 = (uv[idx[q]] + uv[idx[q + 1]] + uv[idx[q + 2]]) / 3.0
					var px: Color = img.get_pixel(clampi(int(u.x * img.get_width()), 0, img.get_width() - 1), clampi(int(u.y * img.get_height()), 0, img.get_height() - 1))
					col = Color(px.r * tint.r, px.g * tint.g, px.b * tint.b)
				suma += Vector3(col.r, col.g, col.b) * area
				peso += area
	if peso <= 0.0:
		return []
	var med: Vector3 = suma / peso
	return [Color(med.x, med.y, med.z), peso]
func _initialize() -> void:
	var ids := ["helecho","hierba_alta","canas","flores_blancas","roca_musgosa","rocas_pequenas","tronco_musgoso","troncos_apilados","hojas_caidas","paja","seta_quemada","tronco_resina","tronco_sin_resina","raiz_mundo","cristal_elemental","tinaja_ruina","campamento_cazo","campamento_cofre","campamento_rocas","campamento_tienda","cofre","losa_runas_llana","losa_runas_ovalo","losa_runas_remaches","canal_recto","canal_codo"]
	for id in ids:
		var v: Node3D = Pieza3D.crear_visual(id)
		if v == null:
			print("%-20s (sin modelo)" % id)
			continue
		var r: Array = _medio(v)
		if r.is_empty():
			print("%-20s (sin color)" % id)
		else:
			var c: Color = r[0]
			print("%-20s #%s  h%3d s%.2f v%.2f" % [id, c.to_html(false).to_upper(), int(c.h * 360.0), c.s, c.v])
		v.free()
	quit()
