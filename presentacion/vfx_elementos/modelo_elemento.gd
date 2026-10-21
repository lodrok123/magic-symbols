class_name ModeloElemento
extends RefCounted

## MODELOS DE MESHY PARA LOS VFX DE ELEMENTOS (tierra, hielo): lee un GLB suelto de `arte/meshy/piezas/` y lo HORNEA (una vez) a unidades de juego, con el origen
## donde lo piden `VfxTierra` / `VfxHielo`, para que `pieza(id)` devuelva una malla lista (escala 1, posición 0), igual que la primitiva con el mismo id.
## «El cambio es solo de malla» (PROMPTS_ELEMENTOS.md): las llamadas del juego no saben si dibujan un GLB o la primitiva.
##
## Los GLB vienen a la escala de la lámina (no a la del juego), con el centro de la base en el origen (x, z) y la base en y = 0. Se ajustan a la medida
## de cada pieza (casilla = 2,3 u; la jugadora ≈ 1 u) con uno de tres ajustes:
##   "mayor"  escala uniforme: el lado mayor mide lo que dice la medida (terrones, cascotes, esquirla)
##   "alto"   escala uniforme por el ALTO, con el ancho limitado a 1,6 veces lo que daría la medida (racimos, pinchos: no salen más gordos de lo pedido)
##   "caja"   escala por eje hasta la caja de la medida (el bloque pisable, la placa de hielo): estira un poco, pero la altura y la planta son las del juego

const RUTA: String = "res://arte/meshy/piezas/"
const ANCHO_MAX_K: float = 1.6


## La malla del GLB `RUTA + id + ".glb"` (la primera malla del árbol) o null si no existe. El árbol instanciado se libera en el acto.
static func malla_glb(id: String) -> Mesh:
	var ruta: String = "%s%s.glb" % [RUTA, id]
	if not ResourceLoader.exists(ruta):
		return null
	var ps: PackedScene = load(ruta) as PackedScene
	if ps == null:
		return null
	var raiz: Node = ps.instantiate()
	var m: Mesh = null
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		m = (n as MeshInstance3D).mesh
		break
	raiz.free()
	return m


## Límites exactos (en vértices) de la malla `m` después de girarla con `rot`.
static func limites(m: Mesh, rot: Basis = Basis.IDENTITY) -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for s in range(m.get_surface_count()):
		var v: PackedVector3Array = m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for p in v:
			var q: Vector3 = rot * p
			lo = lo.min(q)
			hi = hi.max(q)
	if lo.x == INF:
		return AABB()
	return AABB(lo, hi - lo)


## Vector de escala para llevar una pieza de tamaño `caja` (ya girada) a la medida `med`, según el ajuste.
static func escala_de(caja: Vector3, med: Vector3, ajuste: String) -> Vector3:
	var c := Vector3(maxf(caja.x, 0.0001), maxf(caja.y, 0.0001), maxf(caja.z, 0.0001))
	match ajuste:
		"caja":
			return Vector3(med.x / c.x, med.y / c.y, med.z / c.z)
		"alto":
			var kh: float = med.y / c.y
			var kxz: float = minf(kh, minf(med.x / c.x, med.z / c.z) * ANCHO_MAX_K)
			return Vector3(kxz, kh, kxz)
		_:
			var k: float = maxf(med.x, maxf(med.y, med.z)) / maxf(c.x, maxf(c.y, c.z))
			return Vector3(k, k, k)


## Hornea `m` a unidades de juego: gira con `rot`, centra en x/z (y apoyada en 0 si `base`, centrada si no), escala con `ajuste` a `med` y suma `desplaza`
## (en unidades de LÁMINA, antes de escalar: los trozos de una pieza rota conservan su sitio). `ref` = tamaño de lámina (girada) que manda la escala; si es
## ZERO manda la propia malla (los trozos de la placa usan el de la entera). Conserva UVs y materiales. Las normales se corrigen para escalas no uniformes.
static func hornear(m: Mesh, med: Vector3, ajuste: String, base: bool, rot: Basis = Basis.IDENTITY, ref: Vector3 = Vector3.ZERO, desplaza: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var caja: AABB = limites(m, rot)
	var s: Vector3 = escala_de(ref if ref != Vector3.ZERO else caja.size, med, ajuste)
	var c := Vector3(caja.position.x + caja.size.x * 0.5, caja.position.y if base else caja.position.y + caja.size.y * 0.5, caja.position.z + caja.size.z * 0.5)
	var res := ArrayMesh.new()
	for i in range(m.get_surface_count()):
		var arr: Array = m.surface_get_arrays(i)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nv := PackedVector3Array()
		nv.resize(v.size())
		for k in range(v.size()):
			nv[k] = (rot * v[k] - c + desplaza) * s
		arr[Mesh.ARRAY_VERTEX] = nv
		var nn: Variant = arr[Mesh.ARRAY_NORMAL]
		if nn is PackedVector3Array:
			var n_in: PackedVector3Array = nn
			var n_out := PackedVector3Array()
			n_out.resize(n_in.size())
			for k in range(n_in.size()):
				n_out[k] = ((rot * n_in[k]) / s).normalized()
			arr[Mesh.ARRAY_NORMAL] = n_out
		var tg: Variant = arr[Mesh.ARRAY_TANGENT]
		if tg is PackedFloat32Array:
			var t_in: PackedFloat32Array = tg
			var t_out := PackedFloat32Array()
			t_out.resize(t_in.size())
			for k in range(int(t_in.size() / 4)):
				var t: Vector3 = (rot * Vector3(t_in[k * 4], t_in[k * 4 + 1], t_in[k * 4 + 2]) * s).normalized()
				t_out[k * 4] = t.x
				t_out[k * 4 + 1] = t.y
				t_out[k * 4 + 2] = t.z
				t_out[k * 4 + 3] = t_in[k * 4 + 3]
			arr[Mesh.ARRAY_TANGENT] = t_out
		res.add_surface_from_arrays(m.surface_get_primitive_type(i), arr)
		res.surface_set_material(res.get_surface_count() - 1, m.surface_get_material(i))
	return res
