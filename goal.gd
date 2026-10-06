extends Area2D

## Condición de victoria: en cuanto el jugador toca esta área, se acabó
## el nivel. Usamos el grupo "player" (el mismo que ya usa health_bar.gd
## para encontrar al jugador) en vez de comprobar un tipo de nodo
## concreto, así Goal no necesita saber nada de CharacterBody2D ni de
## ningún script del jugador — solo "¿eres del grupo player?".
var already_won: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if already_won:
		return

	if not body.is_in_group("player"):
		return

	_win()


func _win() -> void:
	already_won = true
	print("¡Has ganado! Llegaste a la meta.")
	PlayLog.event("victoria")
	PlayLog.volcar()

	# Igual que health_bar.gd busca al jugador por grupo, aquí buscamos
	# la etiqueta de victoria por grupo ("victory_ui"), para no depender
	# de una ruta fija dentro del árbol de escena.
	var victory_label = get_tree().get_first_node_in_group("victory_ui")
	if victory_label:
		victory_label.visible = true

	# Pausa el árbol de escena entero: se detienen enemigos, timers,
	# el input de movimiento... una forma sencilla de "congelar" el
	# final de nivel sin tener que apagar cada sistema a mano.
	get_tree().paused = true
