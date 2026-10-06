extends Node2D

const WALK_TEXTURE_PATH := "res://assets/ms_adventurer/walking_8dir.png"

const FRAME_SIZE := Vector2i(256, 320)
const FRAMES_PER_DIRECTION := 8
const WALK_FPS := 10.0
const VISUAL_OFFSET := Vector2(0.0, -101.0)

const DIRECTIONS := [
    "s",
    "sw",
    "w",
    "nw",
    "n",
    "ne",
    "e",
    "se",
]

var sprite: AnimatedSprite2D
var current_direction: String = "s"


func _ready() -> void:
    _build_sprite_frames()
    play_direction(current_direction)


func set_motion(screen_velocity: Vector2) -> void:
    if screen_velocity.length_squared() <= 0.0001:
        return

    current_direction = direction_from_vector(screen_velocity)
    play_direction(current_direction)


func play_direction(direction: String) -> void:
    if sprite == null:
        return

    var normalized := _normalize_direction(direction)
    current_direction = normalized

    var animation_direction := normalized

    if normalized == "e":
        animation_direction = "w"
    elif normalized == "w":
        animation_direction = "e"

    var animation_name := "walk_" + animation_direction

    if not sprite.sprite_frames.has_animation(animation_name):
        push_error("No existe animación: " + animation_name)
        return

    if sprite.animation != animation_name:
        sprite.play(animation_name)
    elif not sprite.is_playing():
        sprite.play()


func direction_from_vector(value: Vector2) -> String:
    if value.length_squared() <= 0.0001:
        return current_direction

    var angle := rad_to_deg(atan2(value.y, value.x))

    if angle < 0.0:
        angle += 360.0

    if angle >= 337.5 or angle < 22.5:
        return "e"
    elif angle < 67.5:
        return "se"
    elif angle < 112.5:
        return "s"
    elif angle < 157.5:
        return "sw"
    elif angle < 202.5:
        return "w"
    elif angle < 247.5:
        return "nw"
    elif angle < 292.5:
        return "n"
    else:
        return "ne"


func get_current_direction() -> String:
    return current_direction


func get_sprite() -> AnimatedSprite2D:
    return sprite


func _build_sprite_frames() -> void:
    var texture := load(WALK_TEXTURE_PATH) as Texture2D

    if texture == null:
        push_error("No se pudo cargar: " + WALK_TEXTURE_PATH)
        return

    var expected_size := Vector2i(
        FRAME_SIZE.x * FRAMES_PER_DIRECTION,
        FRAME_SIZE.y * DIRECTIONS.size()
    )

    var actual_size := Vector2i(texture.get_width(), texture.get_height())

    if actual_size != expected_size:
        push_error(
            "walking_8dir.png tiene tamaño "
            + str(actual_size)
            + ", esperado "
            + str(expected_size)
        )
        return

    var frames := SpriteFrames.new()

    if frames.has_animation("default"):
        frames.remove_animation("default")

    for row in range(DIRECTIONS.size()):
        var direction: String = DIRECTIONS[row]
        var animation_name := "walk_" + direction

        frames.add_animation(animation_name)
        frames.set_animation_speed(animation_name, WALK_FPS)
        frames.set_animation_loop(animation_name, true)

        for column in range(FRAMES_PER_DIRECTION):
            var atlas_texture := AtlasTexture.new()
            atlas_texture.atlas = texture
            atlas_texture.region = Rect2(
                column * FRAME_SIZE.x,
                row * FRAME_SIZE.y,
                FRAME_SIZE.x,
                FRAME_SIZE.y
            )

            frames.add_frame(
                animation_name,
                atlas_texture,
                1.0
            )

    sprite = AnimatedSprite2D.new()
    sprite.name = "WalkingSprite"
    sprite.sprite_frames = frames
    sprite.centered = true
    sprite.offset = VISUAL_OFFSET

    add_child(sprite)


func _normalize_direction(direction: String) -> String:
    var normalized := direction.to_lower()

    if normalized in DIRECTIONS:
        return normalized

    return "s"
