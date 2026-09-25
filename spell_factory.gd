class_name SpellFactory
extends RefCounted

## Punto único para crear hechizos en el mundo.
##
## Antes, cada objeto que quería lanzar un hechizo (el Spellcaster, la
## hierba ardiendo empujada por el viento, el agua hirviendo...) repetía
## las mismas 5 líneas. Repetir código no es solo feo: si el orden de
## esas líneas importa (y aquí importa mucho, ver abajo), tarde o
## temprano una de las copias se queda desactualizada y falla solo en
## un sitio, que es el peor tipo de bug.

const SPELL_SCENE: PackedScene = preload("res://spell.tscn")

## IMPORTANTE — el orden de estas líneas no es cosmético:
## add_child() ejecuta el _ready() del hechizo INMEDIATAMENTE. Todo lo
## que _ready() necesite leer (aquí: direction, para saber si es una
## flecha que vuela o un pilar quieto) tiene que estar puesto ANTES de
## meterlo en el árbol. Lo que necesite que el nodo ya esté en escena
## (global_position, acceder a $ColorRect) va DESPUÉS.
static func cast(
		world: Node,
		spawn_position: Vector2,
		direction: Vector2,
		rune_data: RuneData,
		stationary_lifetime: float = 0.6
) -> Area2D:
	var spell = SPELL_SCENE.instantiate()

	# --- Antes de entrar en el árbol (lo lee _ready) ---
	spell.direction = direction
	spell.stationary_lifetime = stationary_lifetime

	world.get_tree().current_scene.add_child(spell)

	# --- Ya dentro del árbol ---
	spell.global_position = spawn_position
	spell.set_rune_data(rune_data)

	return spell
