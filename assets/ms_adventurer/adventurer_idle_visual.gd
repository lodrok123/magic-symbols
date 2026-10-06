extends AnimatedSprite2D
class_name MSAdventurerIdleVisual

var last_direction: StringName = &"s"


func _ready() -> void:
	if sprite_frames == null:
		push_error("MSAdventurerIdleVisual: SpriteFrames no asignado.")
		return

	if sprite_frames.has_animation(&"idle_s"):
		play(&"idle_s")
	else:
		push_error("MSAdventurerIdleVisual: falta idle_s.")


func play_idle_direction(direction_name: StringName) -> void:
	var direction_text := String(direction_name).to_lower()
	var animation_name := StringName("idle_" + direction_text)

	if sprite_frames == null:
		return

	if not sprite_frames.has_animation(animation_name):
		push_error(
			"MSAdventurerIdleVisual: animación inexistente: %s"
			% animation_name
		)
		return

	last_direction = StringName(direction_text)
	play(animation_name)


func set_screen_direction(direction: Vector2) -> void:
	if direction.length_squared() < 0.000001:
		play_idle_direction(last_direction)
		return

	play_idle_direction(_direction_name(direction))


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
