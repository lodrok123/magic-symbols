extends SceneTree
## Baja el aldabón de la puerta de la Torre Verde (puerta_torre_sumicio.glb, Meshy) a la mitad del lado recto, bajo el arco (14/11, Pablo).
## Guarda la malla en arte/meshy/piezas/puerta_torre_sumicio_pomo.res; la visita la pone en la hoja.
##   godot --headless --path . --script res://herramientas/hornear_puerta_torre_pomo.gd
##
## 1. Se eligen los TRIÁNGULOS del aldabón: los de hierro (gris, poco saturado) con el centro en CAJA, y los conectados a ellos dentro de CAJA
##    (los brillos del hierro, más claros). La madera roja es muy saturada y no entra.
## 2. Si la madera comparte algún vértice con el hierro, la madera recibe una COPIA de ese vértice que se queda en su sitio: así al bajar el
##    hierro no se arrastra la tabla (antes salía un agujero) ni se estira nada.
## 3. Se bajan los vértices del aldabón BAJAR.

const ORIGEN := "res://arte/meshy/piezas/puerta_torre_sumicio.glb"
const DESTINO := "res://arte/meshy/piezas/puerta_torre_sumicio_pomo.res"
const CAJA := AABB(Vector3(0.07, -0.10, -0.09), Vector3(0.21, 0.52, 0.18))   ## placa, argolla (cuelga hasta y ≈ −0,05), clavos y barra (local del modelo, 0,61 × 1,0 centrado)
const TEXTURA := "res://arte/meshy/piezas/puerta_torre_sumicio_pomo.png"   ## la textura sin la sombra pintada del aldabón (la visita la pone en el material)
const BAJAR := -0.24          ## de y ≈ 0,09 a y ≈ −0,15: la mitad del tramo recto del lado (de −0,5 a ~0,2, donde empieza el arco)


func _initialize() -> void:
	var raiz: Node3D = (load(ORIGEN) as PackedScene).instantiate()
	var mi: MeshInstance3D = raiz.find_children("*", "MeshInstance3D", true, false)[0]
	var mat: Material = mi.mesh.surface_get_material(0)
	var a: Array = mi.mesh.surface_get_arrays(0)
	var img: Image = (mat as BaseMaterial3D).albedo_texture.get_image()
	if img.is_compressed():
		img.decompress()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var n_tri := idx.size() / 3
	# 1. Triángulos del aldabón.
	var tri := {}
	var verts := {}
	for t in range(n_tri):
		var k := t * 3
		var c := (v[idx[k]] + v[idx[k + 1]] + v[idx[k + 2]]) / 3.0
		if not CAJA.has_point(c):
			continue
		var u := (uv[idx[k]] + uv[idx[k + 1]] + uv[idx[k + 2]]) / 3.0
		var col := img.get_pixel(clampi(int(u.x * img.get_width()), 0, img.get_width() - 1), clampi(int(u.y * img.get_height()), 0, img.get_height() - 1))
		# Solo por color: el hierro es gris (saturación < 0,42), también en sus brillos; la madera, aun en sombra, es rojiza y muy saturada.
		# (Crecer «por conexión» metía trocitos de tabla pegados a la argolla y al bajarlos dejaban un agujero en forma de media luna.)
		# …o lo que SOBRESALE de la tabla (la cara de las tablas está en |z| ≈ 0,015): la argolla tiene zonas pardas que no pasan por color.
		if col.s < 0.42 or absf(c.z) > 0.024:
			tri[t] = true
			for j in range(3):
				verts[idx[k + j]] = true
	# 2. La madera que comparte vértices con el aldabón se queda con copias propias.
	var copia := {}          # vértice original -> su copia para la madera
	var copiados := 0
	for t in range(n_tri):
		if tri.has(t):
			continue
		for j in range(3):
			var k := t * 3 + j
			var o: int = idx[k]
			if not verts.has(o):
				continue
			if not copia.has(o):
				copia[o] = _duplicar_vertice(a, o)
				copiados += 1
			idx[k] = copia[o]
	a[Mesh.ARRAY_INDEX] = idx
	# 3. Bajar el aldabón.
	v = a[Mesh.ARRAY_VERTEX]
	for i in verts:
		v[i] = v[i] + Vector3(0, BAJAR, 0)
	a[Mesh.ARRAY_VERTEX] = v
	# 3b. El HUECO de la tabla: Meshy no puso madera detrás de la placa del aldabón; al bajarlo queda un agujero (se veía una media luna oscura).
	#     Se tapa con un parche de tabla delante y detrás, con la madera de la misma tabla PARCHE_BAJA más abajo (las tablas son verticales).
	# (Probado el 14/11: un parche con la UV de la tabla de abajo sale a rayas; no hace falta: lo que se veía era geometría que sobresale.)
	# 4. La SOMBRA del aldabón pintada en la textura de la tabla (no es geometría): las tablas son triángulos grandes, así que se recorre la
	#    zona donde estaba, punto a punto, se busca la cara de madera que lo cubre y se repinta ese píxel con la madera de su fila.
	var tex := img.duplicate() as Image
	var w := tex.get_width()
	var h := tex.get_height()
	var zona := Rect2(0.08, -0.08, 0.2, 0.5)
	var caras: Array = []
	for t in range(n_tri):
		if tri.has(t):
			continue
		var k := t * 3
		var p0 := v[idx[k]]
		var p1 := v[idx[k + 1]]
		var p2 := v[idx[k + 2]]
		var r2 := Rect2(Vector2(p0.x, p0.y), Vector2.ZERO).expand(Vector2(p1.x, p1.y)).expand(Vector2(p2.x, p2.y))
		var nz := (p1 - p0).cross(p2 - p0).normalized().z
		if r2.intersects(zona) and absf(nz) > 0.7:
			caras.append(k)
	var repintados := 0
	var y0 := zona.position.y
	while y0 < zona.end.y:
		var x0 := zona.position.x
		while x0 < zona.end.x:
			for k in caras:
				var a2 := Vector2(v[idx[k]].x, v[idx[k]].y)
				var b2 := Vector2(v[idx[k + 1]].x, v[idx[k + 1]].y)
				var c2 := Vector2(v[idx[k + 2]].x, v[idx[k + 2]].y)
				var den := (b2.y - c2.y) * (a2.x - c2.x) + (c2.x - b2.x) * (a2.y - c2.y)
				if absf(den) < 1e-10:
					continue
				var l1 := ((b2.y - c2.y) * (x0 - c2.x) + (c2.x - b2.x) * (y0 - c2.y)) / den
				var l2 := ((c2.y - a2.y) * (x0 - c2.x) + (a2.x - c2.x) * (y0 - c2.y)) / den
				var l3 := 1.0 - l1 - l2
				if l1 < 0.0 or l2 < 0.0 or l3 < 0.0:
					continue
				var t2 := uv[idx[k]] * l1 + uv[idx[k + 1]] * l2 + uv[idx[k + 2]] * l3
				var px := Vector2i(clampi(int(t2.x * w), 0, w - 1), clampi(int(t2.y * h), 0, h - 1))
				for oy in range(-3, 4):
					for ox in range(-3, 4):
						if _repintar(tex, Vector2i(clampi(px.x + ox, 0, w - 1), clampi(px.y + oy, 0, h - 1))):
							repintados += 1
			x0 += 0.002
		y0 += 0.002
	tex.save_png(TEXTURA)
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	am.surface_set_material(0, mat)
	print("aldabón: %d triángulos, %d vértices bajados; %d vértices de madera copiados; %d caras de tabla, %d píxeles de sombra repintados · guardar=%d" % [tri.size(), verts.size(), copiados, caras.size(), repintados, ResourceSaver.save(am, DESTINO)])
	raiz.free()
	quit()


const PARCHE := Rect2(0.10, 0.02, 0.14, 0.30)      ## donde estaba la placa (x, y, ancho, alto en local del modelo)
const PARCHE_BAJA := 0.32                         ## de dónde se copia la madera: la misma tabla, más abajo


## Añade dos quads (delante y detrás) en el plano de la tabla sobre `r`, con la UV de la tabla PARCHE_BAJA más abajo. Devuelve cuántos puso.
func _parchear(a: Array, r: Rect2, excluir: Dictionary) -> int:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var puestos := 0
	for lado in [1.0, -1.0]:
		# El plano de la tabla de ese lado: la z más repetida de las caras grandes de madera alrededor.
		var z_cara := 0.0
		var mejor := 0
		var cuentas := {}
		for k in range(0, idx.size(), 3):
			if excluir.has(k / 3):
				continue
			var c := (v[idx[k]] + v[idx[k + 1]] + v[idx[k + 2]]) / 3.0
			if signf(c.z) != lado or absf(c.x - r.get_center().x) > 0.2:
				continue
			var clave := snappedf(c.z, 0.002)
			cuentas[clave] = int(cuentas.get(clave, 0)) + 1
			if cuentas[clave] > mejor:
				mejor = cuentas[clave]
				z_cara = clave
		var esquinas := [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]
		var nuevos: Array = []
		for e in esquinas:
			var uv_e = _uv_en(v, uv, idx, Vector2(e.x, e.y - PARCHE_BAJA), lado, excluir)
			if uv_e == null:
				break
			var i := _duplicar_vertice(a, idx[0])
			v = a[Mesh.ARRAY_VERTEX]
			uv = a[Mesh.ARRAY_TEX_UV]
			v[i] = Vector3(e.x, e.y, z_cara + 0.001 * lado)
			uv[i] = uv_e
			a[Mesh.ARRAY_VERTEX] = v
			a[Mesh.ARRAY_TEX_UV] = uv
			if a[Mesh.ARRAY_NORMAL] != null:
				var nr: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
				nr[i] = Vector3(0, 0, lado)
				a[Mesh.ARRAY_NORMAL] = nr
			nuevos.append(i)
		if nuevos.size() < 4:
			continue
		idx = a[Mesh.ARRAY_INDEX]
		if lado > 0.0:
			idx.append_array([nuevos[0], nuevos[2], nuevos[1], nuevos[0], nuevos[3], nuevos[2]])
		else:
			idx.append_array([nuevos[0], nuevos[1], nuevos[2], nuevos[0], nuevos[2], nuevos[3]])
		a[Mesh.ARRAY_INDEX] = idx
		puestos += 1
	return puestos


## La UV de la tabla en el punto `q` (x, y) de la cara `lado`, o null si no hay madera ahí.
func _uv_en(v: PackedVector3Array, uv: PackedVector2Array, idx: PackedInt32Array, q: Vector2, lado: float, excluir: Dictionary):
	for k in range(0, idx.size(), 3):
		if excluir.has(k / 3):
			continue
		var p0 := v[idx[k]]
		var p1 := v[idx[k + 1]]
		var p2 := v[idx[k + 2]]
		if signf((p0.z + p1.z + p2.z) / 3.0) != lado:
			continue
		var a2 := Vector2(p0.x, p0.y)
		var b2 := Vector2(p1.x, p1.y)
		var c2 := Vector2(p2.x, p2.y)
		var den := (b2.y - c2.y) * (a2.x - c2.x) + (c2.x - b2.x) * (a2.y - c2.y)
		if absf(den) < 1e-10:
			continue
		var l1 := ((b2.y - c2.y) * (q.x - c2.x) + (c2.x - b2.x) * (q.y - c2.y)) / den
		var l2 := ((c2.y - a2.y) * (q.x - c2.x) + (a2.x - c2.x) * (q.y - c2.y)) / den
		var l3 := 1.0 - l1 - l2
		if l1 >= 0.0 and l2 >= 0.0 and l3 >= 0.0:
			return uv[idx[k]] * l1 + uv[idx[k + 1]] * l2 + uv[idx[k + 2]] * l3
	return null


## Si el píxel es sombra (gris u oscuro frente a la madera roja), toma el color de la madera más cercana de su fila. Devuelve si lo cambió.
func _repintar(tex: Image, p: Vector2i) -> bool:
	var col := tex.get_pixelv(p)
	# La madera limpia anda por v ≈ 0,6; la mancha de la placa es la misma madera más oscura (v < 0,5) y la sombra del hierro, gris.
	if col.s >= 0.55 and col.v >= 0.5:
		return false
	var w := tex.get_width()
	for d in range(4, 120):
		for lado in [-1, 1]:
			var cand := tex.get_pixel(clampi(p.x + d * lado, 0, w - 1), p.y)
			if cand.s >= 0.6 and cand.v >= 0.5:
				tex.set_pixelv(p, cand)
				return true
	return false


## Añade al final de cada array por vértice una copia del vértice `o` y devuelve su índice.
func _duplicar_vertice(a: Array, o: int) -> int:
	var nuevo := -1
	for tipo in range(Mesh.ARRAY_MAX):
		if tipo == Mesh.ARRAY_INDEX or a[tipo] == null:
			continue
		var arr = a[tipo]
		var por_vertice := 1
		match tipo:
			Mesh.ARRAY_TANGENT:
				por_vertice = 4
			Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS:
				por_vertice = arr.size() / (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		for p in range(por_vertice):
			arr.append(arr[o * por_vertice + p])
		a[tipo] = arr
		if tipo == Mesh.ARRAY_VERTEX:
			nuevo = (arr as PackedVector3Array).size() - 1
	return nuevo
