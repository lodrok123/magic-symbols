extends SceneTree
## Parte arte/modelos/golem_piedra.glb (cuerpo + núcleo en la MISMA malla) en dos GLB, sin tocar el original:
##   arte/modelos/golem_piedra_cuerpo.glb  cuerpo centrado en X/Z (caja), pies en y=0, mirando a +Z
##   arte/modelos/nucleo_golem.glb         núcleo centrado en su centro (0,0,0)
## Criterio: las posiciones NO están soldadas (cada costura de UV duplica vértices), así que se sueldan por posición y se agrupan los triángulos en piezas conexas (276 en este modelo: cada
## roca, los dedos de la jaula, la esfera...). Una pieza es del núcleo si el centro de su caja tiene x >= CORTE_X (medido en el modelo tal como viene); el resto es cuerpo. Un corte plano por vértice
## (x >= 0,27) partía 57 triángulos, porque una garra de la jaula empieza en x=0,235. Conserva posiciones, normales, tangentes, UV y el MISMO material (y textura) en los dos.
##   Godot --headless --path . --script res://herramientas/separar_golem.gd
## Con --copia1024 también deja las texturas a 1024 (golem_piedra_cuerpo_1k.glb y nucleo_golem_1k.glb).

const ORIGEN: String = "res://arte/modelos/golem_piedra.glb"
const SALIDA_CUERPO: String = "res://arte/modelos/golem_piedra_cuerpo.glb"
const SALIDA_NUCLEO: String = "res://arte/modelos/nucleo_golem.glb"
const CORTE_X: float = 0.27


func _initialize() -> void:
	var n: Node3D = (load(ORIGEN) as PackedScene).instantiate()
	var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: ArrayMesh = mi.mesh
	var mat: Material = mi.get_active_material(0)
	var xf := Transform3D.IDENTITY
	var c: Node = mi
	while c != null and c != n:
		if c is Node3D:
			xf = (c as Node3D).transform * xf
		c = c.get_parent()
	var a: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var par := PackedInt32Array()
	par.resize(v.size())
	for i in v.size():
		par[i] = i
	var raiz_de := func(x: int) -> int:
		while par[x] != x:
			par[x] = par[par[x]]
			x = par[x]
		return x
	var pos := {}
	for i in v.size():
		var k := Vector3i(roundi(v[i].x * 2000.0), roundi(v[i].y * 2000.0), roundi(v[i].z * 2000.0))
		if pos.has(k):
			par[raiz_de.call(i)] = raiz_de.call(pos[k])
		else:
			pos[k] = i
	for i in range(0, idx.size(), 3):
		for j in 2:
			var r0: int = raiz_de.call(idx[i])
			var r1: int = raiz_de.call(idx[i + 1 + j])
			if r0 != r1:
				par[r1] = r0
	var cajas := {}
	for i in range(0, idx.size(), 3):
		var r: int = raiz_de.call(idx[i])
		if not cajas.has(r):
			cajas[r] = [1e9, -1e9]
		for j in 3:
			var x: float = (xf * v[idx[i + j]]).x
			cajas[r][0] = minf(cajas[r][0], x)
			cajas[r][1] = maxf(cajas[r][1], x)
	var tri_nucleo := PackedInt32Array()
	var tri_cuerpo := PackedInt32Array()
	for i in range(0, idx.size(), 3):
		var cx: Array = cajas[raiz_de.call(idx[i])]
		if (cx[0] + cx[1]) / 2.0 >= CORTE_X:
			tri_nucleo.append_array(idx.slice(i, i + 3))
		else:
			tri_cuerpo.append_array(idx.slice(i, i + 3))
	print("piezas conexas ", cajas.size())
	print("triangulos total %d  nucleo %d  cuerpo %d " % [idx.size() / 3, tri_nucleo.size() / 3, tri_cuerpo.size() / 3])
	var mc: ArrayMesh = _sub(a, tri_cuerpo, xf, true)
	var mn: ArrayMesh = _sub(a, tri_nucleo, xf, false)
	mc.surface_set_material(0, mat)
	mn.surface_set_material(0, mat)
	_exportar(mc, SALIDA_CUERPO, "golem_piedra_cuerpo")
	_exportar(mn, SALIDA_NUCLEO, "nucleo_golem")
	quit(0)


## Sub-malla con solo los triángulos `tris`: vértices reindexados, trasladados (cuerpo: centro X/Z en 0 y pies en y=0; núcleo: su centro en el origen).
func _sub(a: Array, tris: PackedInt32Array, xf: Transform3D, cuerpo: bool) -> ArrayMesh:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var remap := {}
	var usados := PackedInt32Array()
	var idx := PackedInt32Array()
	for k in tris:
		if not remap.has(k):
			remap[k] = usados.size()
			usados.append(k)
		idx.append(remap[k])
	var mn := Vector3(1e9, 1e9, 1e9)
	var mx := Vector3(-1e9, -1e9, -1e9)
	for k in usados:
		var p: Vector3 = xf * v[k]
		mn = mn.min(p)
		mx = mx.max(p)
	var d: Vector3 = Vector3((mn.x + mx.x) / 2.0, mn.y, (mn.z + mx.z) / 2.0) if cuerpo else (mn + mx) / 2.0
	print("%s: caja min %s max %s  desplazamiento %s" % ["cuerpo" if cuerpo else "nucleo", mn, mx, d])
	var r: Array = []
	r.resize(Mesh.ARRAY_MAX)
	var nv := PackedVector3Array()
	for k in usados:
		nv.append(xf * v[k] - d)
	r[Mesh.ARRAY_VERTEX] = nv
	for canal in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		if a[canal] != null:
			var src: Variant = a[canal]
			var dst: Variant = src.duplicate()
			dst.resize(usados.size())
			for i in usados.size():
				dst[i] = src[usados[i]]
			r[canal] = dst
	if a[Mesh.ARRAY_TANGENT] != null:
		var st: PackedFloat32Array = a[Mesh.ARRAY_TANGENT]
		var dt := PackedFloat32Array()
		dt.resize(usados.size() * 4)
		for i in usados.size():
			for q in 4:
				dt[i * 4 + q] = st[usados[i] * 4 + q]
		r[Mesh.ARRAY_TANGENT] = dt
	r[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, r)
	return m


func _exportar(m: ArrayMesh, ruta: String, nombre: String) -> void:
	var raiz := Node3D.new()
	raiz.name = nombre
	var mi := MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = m
	raiz.add_child(mi)
	mi.owner = raiz
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var e: int = doc.append_from_scene(raiz, st)
	var e2: int = doc.write_to_filesystem(st, ProjectSettings.globalize_path(ruta))
	print("exportado %s  (append %d, write %d)" % [ruta, e, e2])
