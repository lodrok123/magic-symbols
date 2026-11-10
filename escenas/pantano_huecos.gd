extends Node
## HUECOS de las piezas nuevas del Pantano (escenas/PruebaPantano.tscn): un POSTE con rotulo en cada casilla `; hueco <id> <x> <y> [giro=<grados>]` de mundo/datos_nivel/mapas/Pantano.txt,
## para ver donde va cada pieza que aun no ha llegado de Meshy (arbol_manglar, cipres_calvo, pasarelas...). Solo marcadores: no bloquean ni tocan nada mas.
##
## CUANDO LLEGA LA PIEZA: en el mapa, quitar el `# ` de la linea `; # pieza h_<id>_<n> decorado ...` de ese id y borrar su linea `; hueco` (pasos completos en la cabecera del mapa).
## Si la pieza ya existe como modelo (arte/piezas/<id>.tscn) el poste no se pone: ya la dibuja Puzle3D. `huecos = false` los quita todos (capturas limpias).

const MAPA: String = "res://mundo/datos_nivel/mapas/Pantano.txt"
const COLOR_POSTE: Color = Color(0.85, 0.62, 0.25)

@export var huecos: bool = true


func _ready() -> void:
	if huecos:
		_poner.call_deferred()


func _poner() -> void:
	for _i in range(20):                       # a que el terreno y Puzle3D hayan montado el mapa
		await get_tree().process_frame
	if not FileAccess.file_exists(MAPA):
		return
	var n: int = 0
	for l in FileAccess.get_file_as_string(MAPA).split("\n"):
		if not l.begins_with("; hueco "):
			continue
		var p: PackedStringArray = l.strip_edges().split(" ", false)
		if p.size() < 5 or not p[3].is_valid_int() or not p[4].is_valid_int():
			continue
		if ResourceLoader.exists("res://arte/piezas/%s.tscn" % p[2]):
			continue
		var giro: float = 0.0
		for i in range(5, p.size()):
			if p[i].begins_with("giro="):
				giro = float(p[i].substr(5))
		var c := Vector2i(int(p[3]), int(p[4]))
		_poste(p[2], c, giro, n)
		n += 1


func _poste(id: String, c: Vector2i, giro: float, k: int) -> void:
	var raiz := Node3D.new()
	raiz.name = "hueco_%s_%d" % [id, k]
	add_child(raiz)
	raiz.global_position = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	raiz.rotation_degrees.y = giro
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_POSTE
	mat.roughness = 0.9
	var cil := CylinderMesh.new()
	cil.top_radius = 0.07
	cil.bottom_radius = 0.09
	cil.height = 0.9
	var poste := MeshInstance3D.new()
	poste.mesh = cil
	poste.material_override = mat
	poste.position = Vector3(0.0, 0.45, 0.0)
	raiz.add_child(poste)
	var base := MeshInstance3D.new()                # una tablilla plana orientada con el giro: se ve hacia donde mira la pieza
	var caja := BoxMesh.new()
	caja.size = Vector3(0.9, 0.04, 0.5)
	base.mesh = caja
	base.material_override = mat
	base.position = Vector3(0.0, 0.02, 0.0)
	raiz.add_child(base)
	var l := Label3D.new()
	l.text = id.replace("_", " ")
	l.font_size = 40
	l.pixel_size = 0.0055
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(1.0, 0.92, 0.5)
	l.outline_size = 12
	l.outline_modulate = Color(0.08, 0.08, 0.12)
	l.shaded = false
	l.no_depth_test = true
	l.position = Vector3(0.0, 1.15, 0.0)
	raiz.add_child(l)
