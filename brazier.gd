extends Area2D

## LA PIRA — el objetivo del nivel.
##
## Su única regla: se enciende con `calor`. No sabe qué es el fuego, ni
## el viento, ni que hay un canal de agua por medio. Exactamente el mismo
## contrato que la hierba.
##
## Y ahí está la gracia del nivel: el jugador no puede llevar fuego hasta
## aquí porque el agua corta el paso, pero **el viento que cruza fuego se
## lleva el fuego consigo**. Esa regla ya existía y no se escribió
## pensando en este puzle. El nivel no añade una mecánica: descubre una.
##
## El agua lo apaga, así que no es un interruptor de un solo uso: es un
## estado del mundo que se puede perder.

signal lit

const FIRE_RUNE: RuneData = preload("res://fire_rune.tres")

var is_lit: bool = false

@onready var visual: Sprite2D = $Visual

var flame_fx: GPUParticles2D = null

## La pira es la fuente de luz mas grande del juego a proposito: es el
## objetivo del nivel, y a oscuras encenderla CAMBIA el mapa. Se guarda
## la referencia porque el agua puede apagarla.
var fuego_luz: PointLight2D = null


func _ready() -> void:
	add_to_group("ground")
	_apply()


func on_spell_hit(rune_data: RuneData, _direction: Vector2 = Vector2.ZERO) -> void:
	if rune_data == null:
		return

	if rune_data.tags.has("calor") and not is_lit:
		_light()
	elif (rune_data.tags.has("agua") or rune_data.tags.has("frio")) and is_lit:
		_extinguish()


## Lo que puede arrastrar el viento de aquí: si arde, fuego. Así una pira
## encendida sirve de **mechero** para encender la siguiente, y un nivel
## futuro puede pedir una cadena de piras sin una línea nueva.
func carried_element() -> RuneData:
	return FIRE_RUNE if is_lit else null


func _light() -> void:
	is_lit = true
	_apply()
	BlockFx.burst(self, "chispas")
	flame_fx = BlockFx.flames(self)
	fuego_luz = Glow.attach(self, Glow.LUZ_FUEGO, 260.0, 1.5, true)
	Sfx.play(self, "pira")
	print("¡La pira arde!")
	lit.emit()

	# La victoria se busca por grupo, igual que hace la meta: este script
	# no necesita conocer la estructura de la interfaz.
	var cartel: Node = get_tree().get_first_node_in_group("victory_ui")
	if cartel:
		cartel.visible = true
	get_tree().paused = true


func _extinguish() -> void:
	is_lit = false
	_apply()
	if flame_fx:
		flame_fx.queue_free()
		flame_fx = null
	if fuego_luz:
		fuego_luz.queue_free()
		fuego_luz = null
	BlockFx.burst(self, "ceniza")
	print("La pira se apaga.")


func _apply() -> void:
	# Apagada se ve fría y apagada; encendida, cálida. Es `modulate`, que
	# multiplica: no hace falta una textura por estado.
	visual.modulate = Color(1.35, 1.1, 0.8) if is_lit else Color(0.72, 0.7, 0.72)
