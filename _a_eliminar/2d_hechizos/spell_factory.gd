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

## DÓNDE golpeó el último hechizo, en coordenadas de mundo. on_spell_hit no
## lleva posición (y no merece la pena cambiarle la firma a todo lo que
## reacciona), así que el hechizo la deja aquí justo antes de avisar; quien la
## necesite (la hierba, para prender DESDE el punto de contacto) la lee, y
## quien no, la ignora. Vector2.INF = no hay ninguna.
static var ultimo_impacto: Vector2 = Vector2.INF

## ¿El agua apaga entera una barrera de fuego que se desplaza (barrera + flecha)?
## En el Blockout sí (impide cruzar el canal con un muro de llamas). Un nivel que
## quiera dejarlas pasar lo pone a false mientras dure, y lo devuelve a true al salir.
static var agua_apaga_muros: bool = true

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

	# El chispazo de SALIR, del color del propio elemento. Va aquí y no
	# dentro de spell.gd porque es del INSTANTE DE NACER, no de la vida
	# del hechizo: pasa una vez, en la fábrica, igual que el resto de lo
	# que se hace "antes de soltarlo al mundo".
	#
	# Solo si SALE volando. Una barrera son seis manifestaciones quietas y
	# seis chispazos de lanzar a la vez serían ruido: lo que dice "esto se
	# queda aquí" no es una salida, es el campo de la barrera (ver SpellForm).
	if direction != Vector2.ZERO and not SpellForm.silhouette:
		BlockFx.spell_cast(spell, rune_data.color)

	return spell
