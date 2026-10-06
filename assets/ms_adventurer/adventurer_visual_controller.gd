extends Node2D
class_name MSAdventurerVisualController

@onready var idle_visual: AnimatedSprite2D = $IdleVisual
@onready var walk_visual: AnimatedSprite2D = $WalkVisual

@export var movement_threshold: float = 0.01

var last_direction: StringName = &"s"
var moving := false


func _ready() -> void:
	_play_idle(last_direction)


func set_motion(screen_velocity: Vector2) -> void:
	var should_move := screen_velocity.length() > movement_threshold

	if should_move:
		last_direction = _direction_name(screen_velocity)

	if should_move != moving:
		moving = should_move

	if moving:
		_play_walk(last_direction)
	else:
		_play_idle(last_direction)


func set_direction(direction_name: StringName) -> void:
	var normalized := StringName(String(direction_name).to_lower())

	if not _is_valid_direction(normalized):
		push_error(
			"MSAdventurerVisualController: dirección inválida: %s"
			% direction_name
		)
		return

	last_direction = normalized

	if moving:
		_play_walk(last_direction)
	else:
		_play_idle(last_direction)


func set_moving(value: bool) -> void:
	moving = value

	if moving:
		_play_walk(last_direction)
	else:
		_play_idle(last_direction)


func get_last_direction() -> StringName:
	return last_direction


func is_moving() -> bool:
	return moving


func _play_idle(direction_name: StringName) -> void:
	var animation_name := StringName("idle_" + String(direction_name))

	idle_visual.visible = true
	walk_visual.visible = false

	if idle_visual.sprite_frames == null:
		return

	if not idle_visual.sprite_frames.has_animation(animation_name):
		push_error(
			"MSAdventurerVisualController: falta animación %s"
			% animation_name
		)
		return

	if idle_visual.animation != animation_name or not idle_visual.is_playing():
		idle_visual.play(animation_name)


func _play_walk(direction_name: StringName) -> void:
	var animation_name := StringName("walk_" + String(direction_name))

	idle_visual.visible = false
	walk_visual.visible = true

	if walk_visual.sprite_frames == null:
		return

	if not walk_visual.sprite_frames.has_animation(animation_name):
		push_error(
			"MSAdventurerVisualController: falta animación %s"
			% animation_name
		)
		return

	if walk_visual.animation != animation_name or not walk_visual.is_playing():
		walk_visual.play(animation_name)


func _direction_name(direction: Vector2) -> StringName:
	var angle := atan2(direction.y, direction.x)
	var octant := int(round(angle / (PI / 4.0)))

	match octant:
		0:
			return &"e"
		1:
			return &"se"
		2:
			return &"s"
		3:
			return &"sw"
		4, -4:
			return &"w"
		-3:
			return &"nw"
		-2:
			return &"n"
		-1:
			return &"ne"

	return &"s"


func _is_valid_direction(direction_name: StringName) -> bool:
	return direction_name in [
		&"s",
		&"sw",
		&"w",
		&"nw",
		&"n",
		&"ne",
		&"e",
		&"se",
	]
