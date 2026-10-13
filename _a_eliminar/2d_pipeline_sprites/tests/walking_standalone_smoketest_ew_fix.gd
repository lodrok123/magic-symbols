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

@export var move_speed: float = 180.0

var sprite: AnimatedSprite2D
var state_label: Label
var velocity := Vector2.ZERO
var current_direction := "s"


func _ready() -> void:
    _build_background()
    _build_sprite()
    _build_ui()

    position = get_viewport_rect().size * 0.5

    _play_direction(current_direction)
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
        current_direction = _direction_from_vector(velocity)
        _play_direction(current_direction)
        position += velocity * delta

    _keep_inside_viewport()
    _update_ui()


func _build_background() -> void:
    var background_layer := CanvasLayer.new()
    background_layer.layer = -100
    add_child(background_layer)

    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color(0.12, 0.12, 0.15, 1.0)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background_layer.add_child(background)


func _build_sprite() -> void:
    var texture := load(WALK_TEXTURE_PATH) as Texture2D

    if texture == null:
        push_error("No se pudo cargar: " + WALK_TEXTURE_PATH)
        return

    print("Walking texture cargada: ", texture.get_size())

    var sprite_frames := SpriteFrames.new()

    if sprite_frames.has_animation("default"):
        sprite_frames.remove_animation("default")

    for row in range(DIRECTIONS.size()):
        var direction: String = DIRECTIONS[row]
        var animation_name := "walk_" + direction

        sprite_frames.add_animation(animation_name)
        sprite_frames.set_animation_speed(animation_name, WALK_FPS)
        sprite_frames.set_animation_loop(animation_name, true)

        for column in range(FRAMES_PER_DIRECTION):
            var atlas_texture := AtlasTexture.new()
            atlas_texture.atlas = texture
            atlas_texture.region = Rect2(
                column * FRAME_SIZE.x,
                row * FRAME_SIZE.y,
                FRAME_SIZE.x,
                FRAME_SIZE.y
            )

            sprite_frames.add_frame(
                animation_name,
                atlas_texture,
                1.0
            )

        print(
            animation_name,
            " frames=",
            sprite_frames.get_frame_count(animation_name)
        )

    sprite = AnimatedSprite2D.new()
    sprite.name = "WalkingSprite"
    sprite.sprite_frames = sprite_frames
    sprite.centered = true
    sprite.offset = VISUAL_OFFSET
    sprite.z_index = 10

    add_child(sprite)


func _build_ui() -> void:
    var marker := Polygon2D.new()
    marker.name = "GroundMarker"
    marker.polygon = PackedVector2Array([
        Vector2(-6, 0),
        Vector2(0, -6),
        Vector2(6, 0),
        Vector2(0, 6),
    ])
    marker.color = Color(1.0, 0.1, 0.1, 1.0)
    marker.z_index = 5
    add_child(marker)

    var ui_layer := CanvasLayer.new()
    ui_layer.layer = 100
    add_child(ui_layer)

    state_label = Label.new()
    state_label.position = Vector2(20, 20)
    state_label.size = Vector2(520, 160)
    ui_layer.add_child(state_label)


func _play_direction(direction: String) -> void:
    if sprite == null:
        return

    var animation_direction := direction

    if direction == "e":
        animation_direction = "w"
    elif direction == "w":
        animation_direction = "e"

    var animation_name := "walk_" + animation_direction

    if not sprite.sprite_frames.has_animation(animation_name):
        push_error("No existe animación: " + animation_name)
        return

    if sprite.animation != animation_name:
        sprite.play(animation_name)
    elif not sprite.is_playing():
        sprite.play()


func _direction_from_vector(value: Vector2) -> String:
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


func _keep_inside_viewport() -> void:
    var viewport_size := get_viewport_rect().size

    position.x = clamp(
        position.x,
        80.0,
        viewport_size.x - 80.0
    )

    position.y = clamp(
        position.y,
        140.0,
        viewport_size.y - 40.0
    )


func _update_ui() -> void:
    if state_label == null:
        return

    var moving := velocity.length_squared() > 0.0001

    state_label.text = (
        "WALKING STANDALONE SMOKETEST\n"
        + "Flechas = mover\n"
        + "Estado: "
        + ("WALK" if moving else "STOP")
        + "\nDirección: "
        + current_direction
        + "\nPosición: "
        + str(position.round())
    )
