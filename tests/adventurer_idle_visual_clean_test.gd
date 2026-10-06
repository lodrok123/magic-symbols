extends Node2D

@onready var visual = $AdventurerIdleVisual
@onready var state_label: Label = $UI/StateLabel


func _ready() -> void:
    var center := get_viewport_rect().size * 0.5

    visual.position = center
    $GroundMarker.position = center

    _update_ui()


func _process(_delta: float) -> void:
    var input_vector := Vector2.ZERO

    if Input.is_key_pressed(KEY_LEFT):
        input_vector.x -= 1.0
    if Input.is_key_pressed(KEY_RIGHT):
        input_vector.x += 1.0
    if Input.is_key_pressed(KEY_UP):
        input_vector.y -= 1.0
    if Input.is_key_pressed(KEY_DOWN):
        input_vector.y += 1.0

    if input_vector.length_squared() > 0.0001:
        visual.set_facing_from_vector(
            input_vector.normalized()
        )

    _update_ui()


func _update_ui() -> void:
    state_label.text = (
        "CLEAN AdventurerIdleVisual\n"
        + "Flechas = cambiar dirección\n"
        + "Dirección lógica: "
        + visual.get_current_direction()
        + "\nFPS: 8\n"
        + "Frames por dirección: 64"
    )
