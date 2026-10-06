extends CharacterBody2D

@export var move_speed: float = 180.0

@onready var visual = $AdventurerVisualController


func _physics_process(_delta: float) -> void:
    var input_vector := _get_movement_input()

    velocity = input_vector * move_speed

    move_and_slide()

    visual.set_motion(velocity)


func _get_movement_input() -> Vector2:
    var input_vector := Vector2.ZERO

    if Input.is_key_pressed(KEY_LEFT):
        input_vector.x -= 1.0

    if Input.is_key_pressed(KEY_RIGHT):
        input_vector.x += 1.0

    if Input.is_key_pressed(KEY_UP):
        input_vector.y -= 1.0

    if Input.is_key_pressed(KEY_DOWN):
        input_vector.y += 1.0

    if input_vector.length_squared() > 1.0:
        input_vector = input_vector.normalized()

    return input_vector


func get_visual_controller() -> Node:
    return visual
