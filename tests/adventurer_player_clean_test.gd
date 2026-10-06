extends Node2D

@onready var player = $AdventurerPlayer
@onready var state_label: Label = $UI/Panel/StateLabel


func _ready() -> void:
	player.position = get_viewport_rect().size * 0.5
	_update_ui()


func _process(_delta: float) -> void:
	_keep_player_inside_viewport()
	_update_ui()


func _keep_player_inside_viewport() -> void:
	var viewport_size := get_viewport_rect().size

	player.position.x = clamp(
		player.position.x,
		80.0,
		viewport_size.x - 80.0
	)

	player.position.y = clamp(
		player.position.y,
		140.0,
		viewport_size.y - 40.0
	)


func _update_ui() -> void:
	var visual = player.get_visual_controller()

	state_label.text = (
        "CharacterBody2D CLEAN\n"
		+ "Flechas = mover\n"
		+ "Estado: "
		+ visual.get_current_state().to_upper()
		+ "\nDirección: "
		+ visual.get_current_direction()
		+ "\nVelocity: "
		+ str(player.velocity.round())
		+ "\nPosition: "
		+ str(player.position.round())
	)
