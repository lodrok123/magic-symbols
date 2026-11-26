extends SceneTree
## Crea albedos derivados del GLB original. Repetible: nunca procesa su propia salida.
const AJUSTE = preload("res://presentacion/ajuste_naturales_3d.gd")
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(AJUSTE.CARPETA_ROCAS))
	var fallos: int = 0
	for id in LechoRio3D.IDS_ROCAS:
		var escena: PackedScene = load(LechoRio3D.ruta_modelo(id))
		var n: Node = escena.instantiate()
		var tex: Texture2D
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var mat: BaseMaterial3D = mi.get_active_material(0) as BaseMaterial3D
			if mat != null and mat.albedo_texture != null:
				tex = mat.albedo_texture
				break
		if tex == null:
			push_error("Sin albedo original: " + id)
			fallos += 1
		else:
			var im: Image = AJUSTE.procesar(tex.get_image(), true)
			var err: int = im.save_png(AJUSTE.CARPETA_ROCAS+id+".png")
			if err != OK: fallos += 1
			var cfg := ConfigFile.new()
			var ruta_import: String = AJUSTE.CARPETA_ROCAS+id+".png.import"
			cfg.load(ruta_import)
			cfg.set_value("remap","importer","texture")
			cfg.set_value("remap","type","CompressedTexture2D")
			cfg.set_value("params","mipmaps/generate",true)
			cfg.set_value("params","detect_3d/compress_to",0)
			cfg.set_value("params","compress/mode",0)
			if cfg.save(ruta_import) != OK: fallos += 1
			print("PALETA ROCA ",id," ",im.get_size()," error=",err)
		n.free()
	print("TOTAL DE FALLOS: ",fallos)
	quit(1 if fallos else 0)
