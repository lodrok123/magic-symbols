extends SceneTree
const DIR = "res://output/blender_interacciones_2026-11-25/"
func _initialize() -> void: call_deferred("correr")
func correr() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR+"fuentes"))
	var ids := {"caja":"caja","jarron":"jarron","jarron_alto":"jarron_alto","roca":"roca_est_1","bayas":"arbusto_bayas","tocon":"tocon","cristal":"cristal_resonante","barril":"barril"}
	var fuentes: Dictionary = {}
	var fallos: int = 0
	Pieza3D._cargar_bibliotecas()
	for nombre in ids:
		var n: Node3D = Pieza3D.crear_visual(ids[nombre])
		if n==null:
			push_error("Sin fuente "+nombre)
			fallos += 1
			continue
		var ruta: String = ProjectSettings.globalize_path(DIR+"fuentes/"+nombre+".glb")
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err: int = doc.append_from_scene(n,state)
		if err==OK: err=doc.write_to_filesystem(state,ruta)
		if err!=OK: fallos += 1
		fuentes[nombre] = ruta
		print("FUENTE ",nombre," ",err)
		n.free()
	var caldera: Node3D = PiezaFuego3D.crear("caldera_cuerpo")
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err: int = doc.append_from_scene(caldera,state)
	var ruta: String = ProjectSettings.globalize_path(DIR+"fuentes/caldera.glb")
	if err==OK: err=doc.write_to_filesystem(state,ruta)
	fuentes["caldera"] = ruta
	caldera.free()
	var f := FileAccess.open(DIR+"fuentes.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(fuentes,"  "))
	print("TOTAL DE FALLOS: ",fallos)
	quit(1 if fallos else 0)
