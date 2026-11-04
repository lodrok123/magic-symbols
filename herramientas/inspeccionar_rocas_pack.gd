extends SceneTree

## Inspecciona un GLB de rocas (por defecto el pack original) y lista nodos, mallas, caja en metros, triángulos y materiales/texturas. Sin ventana:
##   godot --headless --path . --script res://herramientas/inspeccionar_rocas_pack.gd -- res://arte/meshy/aprobacion3d/rocas_estilizadas/sm_rocks_objects.glb

func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var ruta: String = a[0] if a.size() > 0 else "res://arte/meshy/aprobacion3d/rocas_estilizadas/sm_rocks_objects.glb"
	var st := GLTFState.new()
	var doc := GLTFDocument.new()
	var err: int = doc.append_from_file(ProjectSettings.globalize_path(ruta), st)
	print("append_from_file: ", err)
	var n: Node = doc.generate_scene(st)
	var total: int = 0
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		var ab: AABB = mi.mesh.get_aabb()
		var tris: int = 0
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		total += tris
		var mat: Material = mi.mesh.surface_get_material(0)
		var tx: String = ""
		if mat is BaseMaterial3D:
			var b: BaseMaterial3D = mat
			tx = "albedo=%s normal=%s rough=%s emis=%s" % [_t(b.albedo_texture), _t(b.normal_texture), _t(b.roughness_texture), _t(b.emission_texture)]
		print("%-14s pos=%s tam=%s tris=%d mat=%s %s" % [mi.name, mi.position, ab.size, tris, mat.resource_name if mat else "-", tx])
	print("TOTAL tris ", total)
	quit()


func _t(t: Texture2D) -> String:
	return "-" if t == null else "%dx%d" % [t.get_width(), t.get_height()]
