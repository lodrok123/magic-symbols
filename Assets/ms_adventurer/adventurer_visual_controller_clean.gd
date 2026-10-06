extends Node2D

@onready var idle_visual = $IdleVisual
@onready var walk_visual = $WalkVisual

var current_direction: String = "s"
var current_state: String = "idle"


func _ready() -> void:
    _set_state_idle()
    _apply_direction(current_direction)


func set_motion(screen_velocity: Vector2) -> void:
    if screen_velocity.length_squared() <= 0.0001:
        _set_state_idle()
        _apply_direction(current_direction)
        return

    current_direction = walk_visual.direction_from_vector(screen_velocity)

    _set_state_walk()
    _apply_direction(current_direction)


func set_direction(direction: String) -> void:
    current_direction = _normalize_direction(direction)
    _apply_direction(current_direction)


func get_current_direction() -> String:
    return current_direction


func get_current_state() -> String:
    return current_state


func _set_state_idle() -> void:
    current_state = "idle"

    idle_visual.visible = true
    walk_visual.visible = false


func _set_state_walk() -> void:
    current_state = "walk"

    idle_visual.visible = false
    walk_visual.visible = true


func _apply_direction(direction: String) -> void:
    idle_visual.play_direction(direction)
    walk_visual.play_direction(direction)


func _normalize_direction(direction: String) -> String:
    var normalized := direction.to_lower()

    match normalized:
        "s", "sw", "w", "nw", "n", "ne", "e", "se":
            return normalized
        _:
            return "s"
