extends SceneTree
## Medidas del modelo del chamán goblin (sin rig) y comparación con goblin_asesino y goblin_warrior_chibi.
##   Godot --headless --path . --script res://herramientas/medidas_goblin_chaman.gd

const MODELOS: Array = ["goblin_chaman", "goblin_asesino", "goblin_warrior_chibi"]


func _initialize() -> void:
	for m in MODELOS:
		_medir(m, m == "goblin_chaman")
	quit(0)


func _recoger(n: Node, out: Dictionary) -> void:
	out["nodos"] += 1
	if n is Skeleton3D:
		out["esqueletos"] += 1
	if n is AnimationPlayer:
		out["anims"] += (n as AnimationPlayer).get_animation_list().size()
	if n is MeshInstance3D:
		out["mallas"].append(n)
	for c in n.get_children():
		_recoger(c, out)


func _medir(nombre: String, detalle: bool) -> void:
	var ps: PackedScene = load("res://arte/modelos/%s.glb" % nombre)
	var raiz: Node3D = ps.instantiate()
	get_root().add_child(raiz)
	var out: Dictionary = {"nodos": 0, "esqueletos": 0, "anims": 0, "mallas": []}
	_recoger(raiz, out)
	print("=== ", nombre, " ===")
	print("nodos ", out["nodos"], "  mallas ", out["mallas"].size(), "  Skeleton3D ", out["esqueletos"], "  animaciones ", out["anims"])
	var verts: PackedVector3Array = PackedVector3Array()
	var tris: int = 0
	var mats: Dictionary = {}
	var comps: Array = []
	for mi in out["mallas"]:
		var mesh: Mesh = mi.mesh
		var xf: Transform3D = _rel(raiz, mi)
		for s in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var base: int = verts.size()
			for p in v:
				verts.append(xf * p)
			tris += (idx.size() if idx.size() > 0 else v.size()) / 3
			var mat: Material = mi.get_active_material(s)
			if mat is BaseMaterial3D:
				for t in [mat.albedo_texture, mat.normal_texture, mat.orm_texture, mat.metallic_texture, mat.roughness_texture]:
					if t != null:
						mats[t.get_width()] = str(t.get_width()) + "x" + str(t.get_height())
			mats[str(mat)] = 1
			if detalle:
				comps.append([base, v, idx])
	print("vertices ", verts.size(), "  triangulos ", tris, "  materiales/texturas: ", mats.values())
	var mn: Vector3 = verts[0]
	var mx: Vector3 = verts[0]
	for p in verts:
		mn = mn.min(p)
		mx = mx.max(p)
	var sz: Vector3 = mx - mn
	print("caja min ", mn, " max ", mx, "\n  ALTO(y) %.3f  ANCHO(x) %.3f  FONDO(z) %.3f  ancho/alto %.2f" % [sz.y, sz.x, sz.z, sz.x / sz.y])
	print("  pies en y=", snappedf(mn.y, 0.001), "  centro xz ", snapped(Vector2((mn.x + mx.x) / 2, (mn.z + mx.z) / 2), Vector2(0.001, 0.001)))
	# Centroide de vértices por bandas de altura y extremos en z (cara hacia +z o -z)
	var bandas: int = 10
	for b in bandas:
		var y0: float = mn.y + sz.y * b / bandas
		var y1: float = mn.y + sz.y * (b + 1) / bandas
		var bmn := Vector3(1e9, 1e9, 1e9)
		var bmx := Vector3(-1e9, -1e9, -1e9)
		var n: int = 0
		for p in verts:
			if p.y >= y0 and p.y < y1 + (0.0001 if b == bandas - 1 else 0.0):
				bmn = bmn.min(p)
				bmx = bmx.max(p)
				n += 1
		if n > 0:
			print("  banda %d (y %.2f-%.2f) n=%d  x[%.2f,%.2f] z[%.2f,%.2f]" % [b, y0, y1, n, bmn.x, bmx.x, bmn.z, bmx.z])
	if detalle:
		_detalle(verts, mn, mx, comps)
	raiz.queue_free()


func _detalle(verts: PackedVector3Array, mn: Vector3, mx: Vector3, comps: Array) -> void:
	var sz: Vector3 = mx - mn
	# Componentes conexas por posición soldada (¿hay piezas sueltas?).
	var padre: Dictionary = {}
	var clave := func(p: Vector3) -> Vector3i: return Vector3i(roundi(p.x * 2000.0), roundi(p.y * 2000.0), roundi(p.z * 2000.0))
	var raiz_de: Callable
	raiz_de = func(k: Vector3i) -> Vector3i:
		while padre[k] != k:
			padre[k] = padre[padre[k]]
			k = padre[k]
		return k
	for c in comps:
		var base: int = c[0]
		var v: PackedVector3Array = c[1]
		for p in v:
			var k: Vector3i = clave.call(p)
			if not padre.has(k):
				padre[k] = k
		var idx: PackedInt32Array = c[2]
		for i in range(0, idx.size(), 3):
			var k0: Vector3i = raiz_de.call(clave.call(v[idx[i]]))
			for j in 2:
				var k1: Vector3i = raiz_de.call(clave.call(v[idx[i + 1 + j]]))
				if k1 != k0:
					padre[k1] = k0
	var grupos: Dictionary = {}
	for k in padre.keys():
		var r: Vector3i = raiz_de.call(k)
		var p := Vector3(k) / 2000.0
		if not grupos.has(r):
			grupos[r] = [p, p, 0]
		grupos[r][0] = grupos[r][0].min(p)
		grupos[r][1] = grupos[r][1].max(p)
		grupos[r][2] += 1
	print("  componentes conexas (vertices soldados): ", grupos.size())
	var lista: Array = grupos.values()
	lista.sort_custom(func(a, b): return a[2] > b[2])
	for i in mini(6, lista.size()):
		print("    n=%d  min %s max %s" % [lista[i][2], lista[i][0], lista[i][1]])
	# Cara: el sombrero/cuerpo; la nariz es el vértice más adelantado de la cabeza (banda superior 80-95 %).
	var cy0: float = mn.y + sz.y * 0.55
	var cy1: float = mn.y + sz.y * 0.80
	var zmax := -1e9
	var zmin := 1e9
	var pzmax := Vector3.ZERO
	var pzmin := Vector3.ZERO
	for p in verts:
		if p.y > cy0 and p.y < cy1:
			if p.z > zmax:
				zmax = p.z
				pzmax = p
			if p.z < zmin:
				zmin = p.z
				pzmin = p
	print("  cabeza (y 55-80%%): z mas +: %s   z mas -: %s   (si el mas + sobresale mas del centro, mira a +z)" % [pzmax, pzmin])
	# Brazos: vértices a la altura de los hombros/manos por lados.
	var xs_der := -1e9
	var xs_izq := 1e9
	var p_der := Vector3.ZERO
	var p_izq := Vector3.ZERO
	for p in verts:
		if p.y < mn.y + sz.y * 0.85:
			if p.x > xs_der:
				xs_der = p.x
				p_der = p
			if p.x < xs_izq:
				xs_izq = p.x
				p_izq = p
	print("  extremo +x (bajo 85%% alto): ", p_der, "  extremo -x: ", p_izq)
	# Perfil de torso: ancho de x a media altura de pecho (60-70 %) y de cadera
	for fr in [[0.0, 0.08], [0.08, 0.2], [0.2, 0.35], [0.35, 0.5], [0.5, 0.65]]:
		var a := Vector3(1e9, 1e9, 1e9)
		var bb := Vector3(-1e9, -1e9, -1e9)
		for p in verts:
			var f: float = (p.y - mn.y) / sz.y
			if f >= fr[0] and f < fr[1]:
				a = a.min(p)
				bb = bb.max(p)
		print("  franja %d-%d%%: x[%.3f,%.3f] z[%.3f,%.3f]" % [fr[0] * 100, fr[1] * 100, a.x, bb.x, a.z, bb.z])
	# Huecos entre piernas: para cada altura 2..40 %, número de grupos en x (separados > 0,02)
	for f in [0.04, 0.10, 0.16, 0.22, 0.28, 0.34, 0.40]:
		var xsl: Array = []
		for p in verts:
			if absf((p.y - mn.y) / sz.y - f) < 0.006:
				xsl.append(p.x)
		xsl.sort()
		var cortes: Array = []
		for i in range(1, xsl.size()):
			if xsl[i] - xsl[i - 1] > 0.03:
				cortes.append("%.2f..%.2f" % [xsl[i - 1], xsl[i]])
		print("  y=%d%% alto: huecos en x: %s" % [f * 100, cortes])


## Transformación de `n` respecto a `raiz` (sin depender de estar en el árbol).
func _rel(raiz: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != raiz:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t
