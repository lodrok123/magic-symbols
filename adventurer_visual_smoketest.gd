extends Node2D

const SPEED := 180.0

@onready var visual = $AdventurerVisualController
@onready var state_label: Label = $UI/State
@onready var direction_label: Label = $UI/Direction


func _process(_delta: float) -> void:
	var input_vector := Vector2.ZERO

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vector.x += 1.0

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vector.x -= 1.0

	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vector.y += 1.0

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vector.y -= 1.0

	if input_vector.length_squared() > 1.0:
		input_vector = input_vector.normalized()

	visual.set_motion(input_vector * SPEED)

	state_label.text = "Estado: " + ("WALK" if visual.is_moving() else "IDLE")
	direction_label.text = "Direccion: " + String(visual.get_last_direction())
