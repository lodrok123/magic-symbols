extends SceneTree
## MallaReducida3D (bloque 4 de la revisión EoW, 23/10), sin ventana: reduce las piezas grandes del decorado y dice cuántos triángulos quedan.
##   godot --headless --path . --script res://herramientas/prueba_malla_reducida.gd

const PIEZAS: Array = ["arbol_redondo", "pino", "brasero"]

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	for id in PIEZAS:
		var escena: PackedScene = load("res://arte/piezas/%s.tscn" % id) as PackedScene
		if escena == null:
			_ok("%s carga" % id, false)
			continue
		var n: Node = escena.instantiate()
		var mallas: Array = n.find_children("*", "MeshInstance3D", true, false)
		var malla: Mesh = (mallas[0] as MeshInstance3D).mesh if not mallas.is_empty() else null
		var t0: int = MallaReducida3D.triangulos(malla)
		var t0_ms: int = Time.get_ticks_msec()
		var r: Mesh = MallaReducida3D.reducir(malla, 0.125)
		var ms: int = Time.get_ticks_msec() - t0_ms
		var t1: int = MallaReducida3D.triangulos(r)
		_ok("%s se reduce (≈ 1/8)" % id, t1 > 0 and t1 < t0 / 3, "%d → %d triángulos en %d ms" % [t0, t1, ms])
		_ok("%s conserva superficies y materiales" % id, r.get_surface_count() == malla.get_surface_count() and r.surface_get_material(0) == malla.surface_get_material(0))
		var r2: Mesh = MallaReducida3D.reducir(malla, 0.125)
		_ok("%s: la segunda vez sale de la caché" % id, r2 == r)
		n.free()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
