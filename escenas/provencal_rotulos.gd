extends Node
## Rotulos del mapa de muestreo del pack Fantasy Provencal (escenas/PruebaProvencal.tscn): un nombre flotando sobre cada pieza colocada (los nodos `d_<id>` que pone Puzle3D con las lineas
## `; pieza d_<id> decorado ...` de mundo/datos_nivel/mapas/Provencal.txt) y el titulo de cada zona (lineas `; rotulo x y TITULO` de ese mismo mapa). Solo etiquetas: no toca nada mas.
## `rotulos = false` los quita (para capturas limpias).

const MAPA: String = "res://mundo/datos_nivel/mapas/Provencal.txt"

@export var rotulos: bool = true


func _ready() -> void:
	_poner.call_deferred()


func _poner() -> void:
	for _i in range(20):                       # a que Puzle3D haya montado sus piezas
		await get_tree().process_frame
	if not rotulos:
		return
	for n in get_tree().root.find_children("d_*", "Node3D", true, false):
		var nodo: Node3D = n as Node3D
		if nodo is Label3D:
			continue
		var alto: float = _alto_de(nodo)
		_etiqueta(nodo, String(nodo.name).trim_prefix("d_"), Vector3(0.0, alto + 0.45, 0.0), 0.0055, Color(1, 1, 1))
	if FileAccess.file_exists(MAPA):
		for l in FileAccess.get_file_as_string(MAPA).split("\n"):
			if l.begins_with("; rotulo "):
				var p: PackedStringArray = l.split(" ")
				if p.size() >= 5:
					var c := Vector2i(int(p[2]), int(p[3]))
					var tit := Node3D.new()
					tit.name = "titulo_" + p[4]
					add_child(tit)
					tit.global_position = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
					_etiqueta(tit, p[4].replace("_", " "), Vector3(0.0, 1.6, 0.0), 0.016, Color(1.0, 0.92, 0.5))


func _etiqueta(padre: Node3D, texto: String, pos: Vector3, tam: float, color: Color) -> void:
	var l := Label3D.new()
	l.text = texto
	l.font_size = 48
	l.pixel_size = tam
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = color
	l.outline_size = 12
	l.outline_modulate = Color(0.08, 0.08, 0.12)
	l.position = pos
	l.shaded = false
	padre.add_child(l)


## Altura (m) de la pieza: el techo de la union de sus mallas.
func _alto_de(n: Node3D) -> float:
	var y: float = 0.0
	for h in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = h as MeshInstance3D
		if mi.mesh != null:
			y = maxf(y, (mi.global_transform * mi.mesh.get_aabb()).end.y - n.global_position.y)
	return clampf(y, 0.3, 8.0)
