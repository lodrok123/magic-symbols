extends Node2D

## El reinicio con R ya no vive aquí: se movió al nodo LevelController,
## que tiene process_mode = ALWAYS para poder seguir leyendo teclas
## mientras el nivel está en pausa (victoria o muerte). Ver
## level_controller.gd para el porqué del cambio.


## --- LA CAPA NEUTRA DE FONDO ---
##
## El problema que resuelve: las losas son pixel art muy saturado
## (#8E4704 la tierra, #488E04 la hierba) y el fondo era un borrón casi
## negro. Pixel art brillante sobre negro es el contraste máximo que
## existe, y en los huecos entre losas se veía directamente ese vacío.
##
## La solución no es oscurecer las losas ni aclarar el fondo entero,
## sino meter un SUELO entre los dos: un tono medio, desaturado, que
## llena toda la pantalla. Las losas pasan de flotar en el vacío a estar
## apoyadas en algo.
##
## La textura se genera con tools/gen_floor.py y se repite sin costura.
## Si quieres otro tono, ahí está el color base; el "neutro claro" que
## comparamos era (112, 86, 76).
const FLOOR_TILE: Texture2D = preload("res://art/floor_tile.png")

## Qué queda de la textura de fondo antigua. No se tira: bajada a un
## tercio deja de ser el suelo y pasa a ser lo que siempre debió ser —
## una mancha grande que rompe la uniformidad del enlosado. Sube esto
## hacia 1.0 y vuelves a tener el fondo oscuro de antes.
const GROUND_OPACITY: float = 0.33


func _ready() -> void:
	_build_backdrop()

	# El fondo viejo sigue en la escena, encima de la capa neutra, pero
	# casi transparente. Se busca con get_node_or_null por si algún día
	# se quita de la escena: un fondo que falta no debería tirar el juego.
	var ground: Node = get_node_or_null("Background")
	if ground:
		ground.modulate.a = GROUND_OPACITY


## Va en una CanvasLayer con número NEGATIVO, y eso es lo que hace que
## funcione: una CanvasLayer no se mueve con el mundo ni con la cámara,
## así que el suelo cubre SIEMPRE la pantalla entera por muy lejos que
## llegue el jugador. Un Sprite2D gigante, en cambio, siempre acaba
## teniendo un borde donde se le acaba la tela.
##
## Se monta desde código y no desde la escena a propósito: es decorado
## puro, no tiene nada que el editor necesite tocar, y así el .tscn no
## engorda con nodos que nadie va a mover nunca.
func _build_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Backdrop"
	layer.layer = -100
	add_child(layer)

	var floor_rect := TextureRect.new()
	floor_rect.texture = FLOOR_TILE
	floor_rect.stretch_mode = TextureRect.STRETCH_TILE

	# Sin esta línea el mosaico NO se repite: el TextureRect sabe que
	# quieres repetir, pero quien lo permite de verdad es el modo de
	# repetición de la textura, que viene heredado y suele estar en "no
	# repetir". El resultado sería un único cuadro arriba a la izquierda.
	floor_rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	floor_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Es decorado: no debe comerse ni un clic destinado al grimorio.
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	layer.add_child(floor_rect)
