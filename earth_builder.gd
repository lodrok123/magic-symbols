class_name EarthBuilder
extends RefCounted

## Construir tierra encima de algo lo necesitan ya dos sitios distintos
## (el suelo neutro y el agua), y mañana probablemente más. En vez de
## copiar las mismas líneas en cada uno —y arriesgarse a que una copia
## se quede desactualizada— la receta vive aquí una sola vez.

const EARTH_BLOCK_SCENE: PackedScene = preload("res://EarthBlock.tscn")


## Devuelve el bloque que ocupa la casilla después de la llamada, sea el
## que ya había o el recién creado. Quien la llama guarda ese valor:
##
##     occupant = EarthBuilder.build_on(self, occupant)
##
## `is_instance_valid()` es la forma de preguntar "¿ese nodo que guardé
## sigue existiendo?" sin que nadie tenga que avisarnos al destruirlo.
## Importa aquí porque el bloque puede desaparecer por su cuenta: al
## convertirse en vegetación, o al desmoronarse el más antiguo cuando se
## alcanza el tope de 20.
static func build_on(host: Node2D, current_occupant: Node) -> Node:
	if is_instance_valid(current_occupant):
		print("Aquí ya hay algo construido.")
		return current_occupant

	var earth: Node2D = EARTH_BLOCK_SCENE.instantiate()
	host.get_tree().current_scene.add_child(earth)
	earth.global_position = host.global_position
	return earth
