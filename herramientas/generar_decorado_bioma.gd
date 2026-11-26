extends SceneTree

## GENERAR EL DECORADO DE LA TABLA POR BIOMA (26/11/2026). Para cada pieza del pack Pure Nature que aparece en
## `presentacion/tabla_decorado_bioma.gd` (con cualquier peso: también las vetadas) crea su versión «juego»:
##
##   arte/pure_nature/juego/<pn_…>.tscn      el modelo del pack con el MATERIAL DEL JUEGO (MaterialesUE.material_juego → StandardMaterial3D), que es el
##                                           que se quema, se moja, se hiela y reacciona; igual que las 27+8 de `aplicar_candidatos_vegetacion.gd`.
##   arte/pure_nature/juego/materiales/…     los materiales traducidos (se comparten con las demás).
##
##   tools\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://herramientas/generar_decorado_bioma.gd
##
## Reejecutable (sobrescribe). Necesita el pack generado (arte/pure_nature/LEEME.md); sin él, el generador de mapas sigue con las piezas del juego.
## Se corre una vez al añadir una fila «pn_…» a la tabla. Acaba con `fallos=0`.

const TABLA = preload("res://presentacion/tabla_decorado_bioma.gd")
const PN: String = "res://arte/pure_nature/"
const JUEGO: String = "res://arte/pure_nature/juego/"


func _initialize() -> void:
	var informe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PN + "informe.json"))
	var traductor := MaterialesUE.new(informe, PN + "texturas/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(JUEGO + "materiales"))
	var fallos: int = 0
	var hechas: int = 0
	for id in TABLA.ids_pack():
		if not _variante_juego(traductor, String(id)):
			fallos += 1
		else:
			hechas += 1
	print("RESULTADO piezas=%d fallos=%d" % [hechas, fallos])
	quit(0 if fallos == 0 else 1)


## arte/pure_nature/juego/<pn>.tscn: el «modelo» de la pieza del pack con los materiales del juego (misma receta que aplicar_candidatos_vegetacion.gd).
func _variante_juego(traductor: MaterialesUE, pn: String) -> bool:
	var ps: PackedScene = load(PN + "piezas/" + pn + ".tscn") as PackedScene
	if ps == null:
		print("FALLO  no existe la pieza del pack ", pn)
		return false
	var pieza: Node3D = ps.instantiate() as Node3D
	var pack: String = String(pieza.get_meta("pack", ""))
	var modelo: Node3D = pieza.get_node("modelo") as Node3D
	pieza.remove_child(modelo)
	pieza.free()
	var raiz := Node3D.new()
	raiz.name = pn
	raiz.set_meta("pieza_pack", pn)
	raiz.add_child(modelo)
	for n in modelo.find_children("*", "", true, false):
		n.owner = raiz
	modelo.owner = raiz
	var sin_material: int = 0
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for s in range(m.mesh.get_surface_count()):
			var orig: Material = m.mesh.surface_get_material(s)
			var clave: String = pack + "__" + (orig.resource_name if orig != null else "")
			var mat: Material = traductor.material_juego(clave)
			if mat == null:
				sin_material += 1
				continue
			if mat is StandardMaterial3D:
				var ruta_mat: String = JUEGO + "materiales/" + clave + ".tres"
				if not ResourceLoader.exists(ruta_mat):
					ResourceSaver.save(mat, ruta_mat)
				mat = load(ruta_mat)
			m.set_surface_override_material(s, mat)
	var emp := PackedScene.new()
	emp.pack(raiz)
	var err: int = ResourceSaver.save(emp, JUEGO + pn + ".tscn")
	raiz.free()
	print("%s    %s%s" % ["OK " if err == OK else "FALLO", pn, ("   (%d superficies sin material del juego: se quedan con el del pack)" % sin_material) if sin_material > 0 else ""])
	return err == OK
