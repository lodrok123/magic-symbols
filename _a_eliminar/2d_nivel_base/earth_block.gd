extends Area2D

## Bloque que el jugador CREA con la runa de tierra (sobre suelo
## neutro). Bloquea el paso, así que sirve para taponar un hueco, hacer
## de escalón o cortar el avance de un enemigo.

## --- Tope de bloques simultáneos ---
## Sin límite, cada bloque creado es un nodo más con su física activa
## para siempre: 200 bloques son 200 áreas y 200 cuerpos estáticos que
## el motor tiene que consultar en cada ciclo. 20 es un número cómodo:
## suficiente para construir un camino o una pared larga en un puzzle,
## y bajo para que el rendimiento no se note. Si un día los puzzles
## piden más, se sube esta constante y ya está.
const MAX_EARTH_BLOCKS: int = 20
const GROUP_NAME: String = "earth_blocks"

## El grupo que marca "sobre esto se puede subir". El jugador no
## pregunta "¿eres un bloque de tierra?", pregunta "¿perteneces al grupo
## de lo escalable?" — igual que los hechizos preguntan por on_spell_hit
## en vez de por el tipo de nodo. Cualquier cosa futura (una caja, una
## plataforma) se vuelve trepable con solo entrar en este grupo.
const CLIMBABLE_GROUP: String = "climbable"

const GRASS_BLOCK_SCENE: PackedScene = preload("res://GrassBlock.tscn")


func _ready() -> void:
	add_to_group(GROUP_NAME)
	add_to_group(CLIMBABLE_GROUP)
	add_to_group("ground")
	_enforce_block_limit()


## Política FIFO ("first in, first out"): al pasarse del tope, el que
## desaparece es el MÁS ANTIGUO, no el recién creado. Así el jugador
## nunca ve que su última acción "no ha hecho nada" — siempre aparece
## el bloque nuevo, y se desvanece el primero que puso. Los nodos de un
## grupo vienen en el orden en que entraron en la escena, así que el
## más antiguo es sencillamente el primero de la lista.
func _enforce_block_limit() -> void:
	var blocks: Array = get_tree().get_nodes_in_group(GROUP_NAME)

	while blocks.size() > MAX_EARTH_BLOCKS:
		var oldest: Node = blocks.pop_front()
		if is_instance_valid(oldest):
			print("Límite de ", MAX_EARTH_BLOCKS, " bloques de tierra: se desmorona el más antiguo.")
			BlockFx.burst(oldest, "tierra")
			oldest.queue_free()


## Tierra + agua = vegetación. En vez de añadirle a este bloque un
## estado "con hierba" (y duplicar toda la lógica de incendios que ya
## vive en GrassBlock), el bloque se sustituye a sí mismo por una
## GrassBlock. Cada script sigue haciendo una sola cosa.
func on_spell_hit(rune_data: RuneData, _direction: Vector2 = Vector2.ZERO) -> void:
	if rune_data == null:
		return

	if rune_data.tags.has("agua"):
		_sprout()
	elif rune_data.tags.has("disipar"):
		# Desmoronar lo que has levantado no es solo "deshacer": con un
		# tope de MAX_EARTH_BLOCKS, es la forma de RECUPERAR presupuesto.
		# Sin esto, construir mal te cuesta un bloque hasta que el FIFO
		# lo empuje solo; con esto, rectificar es una jugada.
		print("El tiempo desmorona el bloque de tierra.")
		BlockFx.burst(self, "magia")
		queue_free()


func _sprout() -> void:
	var grass: Node = GRASS_BLOCK_SCENE.instantiate()
	get_tree().current_scene.add_child(grass)
	grass.global_position = global_position
	print("La tierra regada brota: ahora es vegetación.")
	BlockFx.burst(self, "tierra")
	queue_free()
