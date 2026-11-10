extends SceneTree

## VER ROCAS DE LELU (7/11/2026). Lista cada malla del GLB del pack «Stylized Rocks - Stones» con su nombre, vertices y caja (ancho, alto, fondo) y la proporcion alto/ancho.
## Sirve para elegir cuales valen como PUA (las mas alargadas hacia arriba) sin abrir el editor. Sin ventana (antes, `--headless --import`):
##   godot --headless --path . --script res://herramientas/ver_rocas_lelu.gd

const RUTA := "res://arte/rocas_lelu/sm_rocks_objects.glb"

func _initialize() -> void:
	var escena: PackedScene = load(RUTA)
	if escena == null:
		print("FALLO: no carga ", RUTA)
		quit(1)
		return
	var raiz: Node = escena.instantiate()
	var filas: Array = []
	_recorrer(raiz, filas)
	filas.sort_custom(func(a, b): return a["prop"] > b["prop"])
	print("MALLAS: ", filas.size(), "  (ordenadas por alto/ancho, de mayor a menor)")
	print("%-34s %8s %8s %8s %8s %8s" % ["nombre", "vertices", "ancho", "alto", "fondo", "alto/anc"])
	for f in filas:
		print("%-34s %8d %8.3f %8.3f %8.3f %8.2f" % [f["nombre"], f["verts"], f["ancho"], f["alto"], f["fondo"], f["prop"]])
	raiz.free()
	quit(0)

func _recorrer(n: Node, filas: Array) -> void:
	if n is MeshInstance3D and n.mesh != null:
		var mi: MeshInstance3D = n
		var verts := 0
		for s in range(mi.mesh.get_surface_count()):
			var arr: Array = mi.mesh.surface_get_arrays(s)
			verts += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var caja: AABB = mi.mesh.get_aabb()
		# con la escala del nodo (el GLB puede traerla en el transform), sin rotaciones
		var e: Vector3 = mi.scale
		var w: float = caja.size.x * absf(e.x)
		var h: float = caja.size.y * absf(e.y)
		var d: float = caja.size.z * absf(e.z)
		filas.append({"nombre": String(n.name), "verts": verts, "ancho": w, "alto": h, "fondo": d, "prop": h / maxf(w, 0.0001)})
	for c in n.get_children():
		_recorrer(c, filas)
