extends Node2D

const IDLE_TEXTURE_PATHS := [
    "res://assets/ms_adventurer/idle_8dir_part_1.png",
    "res://assets/ms_adventurer/idle_8dir_part_2.png",
    "res://assets/ms_adventurer/idle_8dir_part_3.png",
    "res://assets/ms_adventurer/idle_8dir_part_4.png",
]

const FRAME_SIZE := Vector2i(256, 320)
const FRAMES_PER_PART := 16
const PARTS := 4
const FRAMES_PER_DIRECTION := 64
const IDLE_FPS := 8.0
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
var state_label: Label
var current_direction := "s"


func _ready() -> void:
    _build_background()
    _build_sprite()
    _build_ui()

    position = get_viewport_rect().size * 0.5

    _play_direction(current_direction)
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
        current_direction = _direction_from_vector(
            input_vector.normalized()
        )
        _play_direction(current_direction)

    _update_ui()


func _build_background() -> void:
    var background_layer := CanvasLayer.new()
    background_layer.layer = -100
    add_child(background_layer)

    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(
        Control.PRESET_FULL_RECT
    )
    background.color = Color(
        0.12,
        0.12,
        0.15,
        1.0
    )
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE

    background_layer.add_child(background)


func _build_sprite() -> void:
    var textures: Array[Texture2D] = []

    for texture_path in IDLE_TEXTURE_PATHS:
        var texture := load(texture_path) as Texture2D

        if texture == null:
            push_error(
                "No se pudo cargar: "
                + texture_path
            )
            return

        var actual_size := Vector2i(
            texture.get_width(),
            texture.get_height()
        )

        var expected_size := Vector2i(
            FRAME_SIZE.x * FRAMES_PER_PART,
            FRAME_SIZE.y * DIRECTIONS.size()
        )

        if actual_size != expected_size:
            push_error(
                texture_path
                + " tiene tamaño "
                + str(actual_size)
                + ", esperado "
                + str(expected_size)
            )
            return

        print(
            "Idle texture cargada: ",
            texture_path,
            " size=",
            actual_size
        )

        textures.append(texture)

    var sprite_frames := SpriteFrames.new()

    if sprite_frames.has_animation("default"):
        sprite_frames.remove_animation("default")

    for row in range(DIRECTIONS.size()):
        var direction: String = DIRECTIONS[row]
        var animation_name := "idle_" + direction

        sprite_frames.add_animation(animation_name)
        sprite_frames.set_animation_speed(
            animation_name,
            IDLE_FPS
        )
        sprite_frames.set_animation_loop(
            animation_name,
            true
        )

        for global_frame in range(
            FRAMES_PER_DIRECTION
        ):
            var part_index := (
                global_frame / FRAMES_PER_PART
            )

            var local_column := (
                global_frame % FRAMES_PER_PART
            )

            var atlas_texture := AtlasTexture.new()

            atlas_texture.atlas = textures[
                part_index
            ]

            atlas_texture.region = Rect2(
                local_column * FRAME_SIZE.x,
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
            sprite_frames.get_frame_count(
                animation_name
            )
        )

    sprite = AnimatedSprite2D.new()
    sprite.name = "IdleSprite"
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

    marker.color = Color(
        1.0,
        0.1,
        0.1,
        1.0
    )

    marker.z_index = 5
    add_child(marker)

    var ui_layer := CanvasLayer.new()
    ui_layer.layer = 100
    add_child(ui_layer)

    state_label = Label.new()
    state_label.position = Vector2(20, 20)
    state_label.size = Vector2(560, 180)

    ui_layer.add_child(state_label)


func _play_direction(direction: String) -> void:
    if sprite == null:
        return

    var normalized := direction.to_lower()

    if not normalized in DIRECTIONS:
        normalized = "s"

    var animation_direction := normalized

    # Mantener el mismo swap E/O validado en Walking.
    if normalized == "e":
        animation_direction = "w"
    elif normalized == "w":
        animation_direction = "e"

    var animation_name := (
        "idle_"
        + animation_direction
    )

    if not sprite.sprite_frames.has_animation(
        animation_name
    ):
        push_error(
            "No existe animación: "
            + animation_name
        )
        return

    if sprite.animation != animation_name:
        sprite.play(animation_name)
    elif not sprite.is_playing():
        sprite.play()


func _direction_from_vector(
    value: Vector2
) -> String:
    var angle := rad_to_deg(
        atan2(
            value.y,
            value.x
        )
    )

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


func _update_ui() -> void:
    if state_label == null:
        return

    state_label.text = (
        "IDLE STANDALONE SMOKETEST\n"
        + "Flechas = cambiar dirección\n"
        + "Dirección lógica: "
        + current_direction
        + "\nFrames por dirección: "
        + str(FRAMES_PER_DIRECTION)
        + "\nFPS: "
        + str(IDLE_FPS)
    )
