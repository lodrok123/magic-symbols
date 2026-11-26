extends SceneTree
## Genera la opción A aprobada. Solo datos visuales, sin cuerpos; los originales
## siguen disponibles. Los GLB de Cosmos se guardan dentro de su carpeta excluida.
const P = preload("res://herramientas/propuesta_sustituciones_assets.gd")
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var fallos: int = 0
	if "hornear" in args:
		for id in ["setas_amarillas","caja","caja_pequena","barril"]:
			if not GeneradorPiezas.generar(id): fallos += 1
			print("HORNEADA ",id)
	else:
		for id in P.OPCIONES:
			var n: Node3D = P.crear(id,1)
			var doc := GLTFDocument.new()
			var estado := GLTFState.new()
			var ruta: String = Pieza3D.VISUALES_APROBADOS[id]
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ruta.get_base_dir()))
			var err: int = doc.append_from_scene(n,estado)
			if err == OK: err = doc.write_to_filesystem(estado,ProjectSettings.globalize_path(ruta))
			if err != OK: fallos += 1
			print("VISUAL A ",id," error=",err)
			n.free()
	print("TOTAL DE FALLOS: ",fallos)
	quit(1 if fallos else 0)
