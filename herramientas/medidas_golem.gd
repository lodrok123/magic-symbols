extends SceneTree
## Medidas del gólem de piedra (sin rig) frente al chamán y al guerrero, y búsqueda del hueco del pecho. Headless:
##   Godot --headless --path . --script res://herramientas/medidas_golem.gd

func _initialize() -> void:
	for m in ["golem_piedra", "goblin_chaman", "goblin_warrior_chibi"]:
		_medir(m, m == "golem_piedra")
	quit(0)


func _rel(raiz: Node, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != raiz:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


func _medir(nombre: String, detalle: bool) -> void:
	var raiz: Node3D = (load("res://arte/modelos/%s.glb" % nombre) as PackedScene).instantiate()
	var mallas: Array = raiz.find_children("*", "MeshInstance3D", true, false)
	var esq: int = raiz.find_children("*", "Skeleton3D", true, false).size()
	var anims: int = 0
	for ap in raiz.find_children("*", "AnimationPlayer", true, false):
		anims += (ap as AnimationPlayer).get_animation_list().size()
	var verts := PackedVector3Array()
	var tris := 0
	var tex: Array = []
	var mats := 0
	for mi in mallas:
		var xf: Transform3D = _rel(raiz, mi)
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var a: Array = mesh.surface_get_arrays(s)
			var idx = a[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else a[Mesh.ARRAY_VERTEX].size()) / 3
			for p in a[Mesh.ARRAY_VERTEX]:
				verts.append(xf * p)
			var m: Material = mi.get_active_material(s)
			mats += 1
			if m is BaseMaterial3D and m.albedo_texture != null:
				tex.append("%dx%d" % [m.albedo_texture.get_width(), m.albedo_texture.get_height()])
	var mn: Vector3 = verts[0]
	var mx: Vector3 = verts[0]
	for p in verts:
		mn = mn.min(p)
		mx = mx.max(p)
	var sz: Vector3 = mx - mn
	print("=== %s ===  mallas %d  materiales %d  texturas %s  Skeleton3D %d  animaciones %d" % [nombre, mallas.size(), mats, tex, esq, anims])
	print("  vertices %d  triangulos %d" % [verts.size(), tris])
	print("  caja min %s max %s" % [mn, mx])
	print("  ALTO %.3f  ANCHO %.3f  FONDO %.3f  ancho/alto %.2f  pies y=%.3f  centro xz (%.3f, %.3f)" % [sz.y, sz.x, sz.z, sz.x / sz.y, mn.y, (mn.x + mx.x) / 2, (mn.z + mx.z) / 2])
	for b in 10:
		var y0: float = mn.y + sz.y * b / 10.0
		var y1: float = y0 + sz.y / 10.0
		var a := Vector3(1e9, 1e9, 1e9)
		var z := Vector3(-1e9, -1e9, -1e9)
		for p in verts:
			if p.y >= y0 and p.y <= y1:
				a = a.min(p)
				z = z.max(p)
		print("  banda %d (%.0f-%.0f%%) x[%.2f,%.2f] z[%.2f,%.2f]" % [b, b * 10, b * 10 + 10, a.x, z.x, a.z, z.z])
	if detalle:
		_pecho(verts, mn, mx)
		_piernas_brazos(verts, mn, mx)
	raiz.queue_free()


func _piernas_brazos(verts: PackedVector3Array, mn: Vector3, mx: Vector3) -> void:
	var sz: Vector3 = mx - mn
	for f in [0.03, 0.08, 0.14, 0.20, 0.26, 0.32]:
		var xs: Array = []
		for p in verts:
			if absf((p.y - mn.y) / sz.y - f) < 0.008:
				xs.append(p.x)
		xs.sort()
		var cortes: Array = []
		for i in range(1, xs.size()):
			if xs[i] - xs[i - 1] > 0.03:
				cortes.append("%.2f..%.2f" % [xs[i - 1], xs[i]])
		print("  y=%d%%: huecos en x %s" % [f * 100, cortes])
	# extremo de las manos: vértice más bajo con |x| grande
	var pb := Vector3(0, 1e9, 0)
	var pe := Vector3.ZERO
	for p in verts:
		if absf(p.x) > sz.x * 0.38 and p.y < pb.y:
			pb = p
		if absf(p.x) > absf(pe.x):
			pe = p
	print("  mano mas baja (|x|>38%% ancho): %s   punto mas lejano en x: %s" % [pb, pe])


## Mapa de profundidad frontal (z máximo por celda x,y) del pecho: un hueco para el núcleo sale como una depresión.
func _pecho(verts: PackedVector3Array, mn: Vector3, mx: Vector3) -> void:
	var sz: Vector3 = mx - mn
	var paso: float = sz.y / 60.0
	var x0: float = -sz.x * 0.25
	var x1: float = sz.x * 0.25
	var y0: float = mn.y + sz.y * 0.45
	var y1: float = mn.y + sz.y * 0.85
	var nx: int = int((x1 - x0) / paso)
	var ny: int = int((y1 - y0) / paso)
	var h: Array = []
	for j in ny:
		var fila: Array = []
		for i in nx:
			fila.append(-1e9)
		h.append(fila)
	for p in verts:
		if p.x >= x0 and p.x < x1 and p.y >= y0 and p.y < y1 and p.z > 0.0:
			var i: int = mini(int((p.x - x0) / paso), nx - 1)
			var j: int = mini(int((p.y - y0) / paso), ny - 1)
			h[j][i] = maxf(h[j][i], p.z)
	var zmax: float = -1e9
	for fila in h:
		for v in fila:
			zmax = maxf(zmax, v)
	print("  mapa frontal del pecho (x %.2f..%.2f, y %.2f..%.2f, celda %.3f); z max %.3f; '#'=superficie adelantada, '.'=hundida, ' '=sin vertices" % [x0, x1, y0, y1, paso, zmax])
	for j in range(ny - 1, -1, -1):
		var s: String = "%5.2f " % (y0 + (j + 0.5) * paso)
		for i in nx:
			var v: float = h[j][i]
			if v < -1e8:
				s += " "
			else:
				var d: float = zmax - v
				s += "#" if d < 0.04 else ("+" if d < 0.08 else ("-" if d < 0.13 else "."))
		print(s)
