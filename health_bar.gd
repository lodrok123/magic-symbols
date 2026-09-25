extends ProgressBar

## Este script va en un ProgressBar dentro de un CanvasLayer, para que
## la barra se dibuje siempre en pantalla (UI) y no se mueva con la
## cámara ni con el mundo del juego.
##
## No busca al jugador por una ruta fija ($"../../Player"...), sino por
## el grupo "player" (ver player.gd _ready()). Así, si el jugador se
## mueve de sitio en el árbol de escena, esto no se rompe.
func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		print("HealthBar: no se encontró ningún nodo en el grupo 'player'.")
		return

	max_value = player.max_health
	value = player.health
	player.health_changed.connect(_on_health_changed)


func _on_health_changed(new_health: float, max_health: float) -> void:
	max_value = max_health
	value = new_health
