extends Node2D

@export var move_speed: float = 180.0

@onready var visual = $AdventurerWalkVisual
@onready var state_label: Label = $UI/StateLabel

var velocity := Vector2.ZERO


func _ready() -> void:
    var center := get_viewport_rect().size * 0.5

    visual.position = center
    $StartMarker.position = center

    _update_ui()


func _process(delta: float) -> void:
    var input_vector := Vector2.ZERO

    if Input.is_key_pressed(KEY_LEFT):
        input_vector.x -= 1.0
    if Input.is_key_pressed(KEY_RIGHT):
        input_vector.x += 1.0
    if Input.is_key_pressed(KEY_UP):
        input_vector.y -= 1.0
    if Input.is_key_pressed(KEY_DOWN):
        input_vector.y += 1.0

    input_vector = input_vector.normalized()
    velocity = input_vector * move_speed

    if velocity.length_squared() > 0.0001:
        visual.set_motion(velocity)
        visual.position += velocity * delta

    _keep_inside_viewport()
    _update_ui()


func _keep_inside_viewport() -> void:
    var viewport_size := get_viewport_rect().size

    visual.position.x = clamp(
        visual.position.x,
        80.0,
        viewport_size.x - 80.0
    )

    visual.position.y = clamp(
        visual.position.y,
        140.0,
        viewport_size.y - 40.0
    )


func _update_ui() -> void:
    state_label.text = (
        "CLEAN AdventurerWalkVisual\n"
        + "Flechas = mover\n"
        + "Dirección lógica: "
        + visual.get_current_direction()
        + "\nPosición: "
        + str(visual.position.round())
    )
