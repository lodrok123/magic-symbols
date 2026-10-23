extends SceneTree
## DIAGNÓSTICO del agua del cauce hondo lleno (23/10): lista las mallas visibles que atraviesan la columna de una casilla del cauce una vez llena.
##   godot --path . --script res://herramientas/diag_cauce_lleno.gd
const S: float = 2.3
const ESPERA_INICIAL_FRAMES: int = 150
const ESPERA_LLENADO_S: float = 8.0


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var m: Node3D = (load("res://escenas/PruebaBosque01.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for _i in ESPERA_INICIAL_FRAMES:
		await process_frame
	var lado: int = Terreno3D.lado_del_mapa()
	var cauce: Vector2i = Vector2i(-1, -1)
	for y in range(lado):
		for x in range(lado):
			if cauce.x < 0 and Terreno3D.letra_de(Vector2i(x, y)) == "c":
				cauce = Vector2i(x, y)
	m.call("llenar_cauce")
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) < ESPERA_LLENADO_S * 1000.0:
		await process_frame
	var cx: float = (float(cauce.x) + 0.5) * S
	var cz: float = (float(cauce.y) + 0.5) * S
	print("casilla ", cauce, " centro ", cx, ",", cz, " prof ", Terreno3D.agua_sim.profundidad_casilla(cauce))
	_listar(m, cx, cz)
	quit()


func _listar(n: Node, cx: float, cz: float) -> void:
	if n is GeometryInstance3D and (n as GeometryInstance3D).is_visible_in_tree():
		var g := n as GeometryInstance3D
		var bb: AABB = g.global_transform * g.get_aabb()
		if bb.position.x <= cx and bb.end.x >= cx and bb.position.z <= cz and bb.end.z >= cz and bb.size.x < 40.0:
			var mat: Material = g.material_override
			if mat == null and g is MeshInstance3D and (g as MeshInstance3D).mesh != null and (g as MeshInstance3D).mesh.get_surface_count() > 0:
				mat = (g as MeshInstance3D).mesh.surface_get_material(0)
			var nm: String = "-"
			if mat != null:
				nm = mat.get_class()
				if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null:
					nm += " " + (mat as ShaderMaterial).shader.resource_path
				nm += " pri=%d" % mat.render_priority
			print(n.get_path(), " ", n.get_class(), " y[%.2f..%.2f] " % [bb.position.y, bb.end.y], nm)
	for h in n.get_children():
		_listar(h, cx, cz)
