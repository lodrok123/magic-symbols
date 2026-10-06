from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path
from typing import Any

import bpy


EXIT_OK = 0
EXIT_CONFIG_ERROR = 2
EXIT_SCENE_ERROR = 3
EXIT_RENDER_ERROR = 4

POSE_CHANGE_EPSILON = 1e-5


def blender_args() -> list[str]:
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1:]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generic Magic Symbols 3D-to-sprite renderer."
    )

    parser.add_argument(
        "--character-json",
        required=True,
        type=Path,
    )

    parser.add_argument(
        "--animation",
        required=True,
        help="Animation ID from character.json, e.g. walk or idle.",
    )

    parser.add_argument(
        "--output",
        required=True,
        type=Path,
    )

    parser.add_argument(
        "--directions",
        default=None,
        help=(
            "Optional comma-separated direction IDs. "
            "Example: E or S,SW,W. Defaults to every configured direction."
        ),
    )

    return parser.parse_args(blender_args())


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    if not isinstance(data, dict):
        raise RuntimeError("character.json debe contener un objeto JSON raíz.")

    return data


def resolve_project_path(path: Path) -> Path:
    if path.is_absolute():
        return path.resolve()

    return (Path.cwd() / path).resolve()


def set_frame(frame: float) -> None:
    whole = math.floor(frame)

    bpy.context.scene.frame_set(
        int(whole),
        subframe=float(frame - whole),
    )

    bpy.context.view_layer.update()


def import_character_source(
    config: dict[str, Any],
) -> tuple[
    Path,
    list[bpy.types.Object],
    bpy.types.Object,
    list[bpy.types.Action],
]:
    source_model_raw = config["character"].get("source_model", "").strip()

    if not source_model_raw:
        raise RuntimeError(
            'character.source_model está vacío en character.json.'
        )

    source_model = resolve_project_path(
        Path(source_model_raw)
    )

    if not source_model.is_file():
        raise RuntimeError(
            f"No existe el source model: {source_model}"
        )

    before_objects = {
        obj.as_pointer()
        for obj in bpy.data.objects
    }

    before_actions = {
        action.as_pointer()
        for action in bpy.data.actions
    }

    result = bpy.ops.import_scene.gltf(
        filepath=str(source_model)
    )

    if "FINISHED" not in result:
        raise RuntimeError(
            f"No se pudo importar el source model: {source_model}"
        )

    imported_objects = [
        obj
        for obj in bpy.data.objects
        if obj.as_pointer() not in before_objects
    ]

    imported_actions = [
        action
        for action in bpy.data.actions
        if action.as_pointer() not in before_actions
    ]

    armatures = [
        obj
        for obj in imported_objects
        if obj.type == "ARMATURE"
    ]

    if len(armatures) != 1:
        raise RuntimeError(
            "El source model debe importar exactamente 1 Armature. "
            f"Encontrados: {[obj.name for obj in armatures]}"
        )

    armature = armatures[0]

    print(
        "[Magic Symbols] Source model:",
        source_model,
    )
    print(
        "[Magic Symbols] Imported armature:",
        armature.name,
    )
    print(
        "[Magic Symbols] Imported Actions:",
        ", ".join(
            sorted(action.name for action in imported_actions)
        ) or "(none)",
    )

    return (
        source_model,
        imported_objects,
        armature,
        imported_actions,
    )


def find_character_root(
    armature: bpy.types.Object,
) -> bpy.types.Object:
    obj = armature

    while obj.parent is not None:
        obj = obj.parent

    return obj


def create_direction_turntable(
    root: bpy.types.Object,
    character_id: str,
) -> bpy.types.Object:
    """
    Creates a non-animated parent used exclusively for directional yaw.

    Important: never rotate the animated armature/root directly. A source
    Action may contain object-level transform channels and frame_set() can
    overwrite those rotations, producing identical directional renders.
    """
    turntable = bpy.data.objects.new(
        f"MS_Turntable_{character_id}",
        None,
    )

    turntable.empty_display_type = "PLAIN_AXES"
    turntable.rotation_mode = "XYZ"

    root_world = root.matrix_world.copy()

    turntable.location = (
        root_world.translation.copy()
    )

    bpy.context.scene.collection.objects.link(
        turntable
    )

    root.parent = turntable
    root.matrix_world = root_world

    bpy.context.view_layer.update()

    return turntable


def character_meshes(
    config: dict[str, Any],
    armature: bpy.types.Object,
    imported_objects: list[bpy.types.Object],
) -> list[bpy.types.Object]:
    mesh_cfg = config["model"]["mesh_selection"]
    preferred = mesh_cfg.get("preferred_mesh_name", "").strip()

    meshes = [
        obj
        for obj in imported_objects
        if obj.type == "MESH"
        and any(
            modifier.type == "ARMATURE"
            and modifier.object == armature
            for modifier in obj.modifiers
        )
    ]

    if preferred:
        exact = [
            obj
            for obj in meshes
            if obj.name == preferred
        ]

        if exact:
            return exact

        # Blender may append .001 if the Render Studio already contains
        # a datablock with the same object name.
        suffixed = [
            obj
            for obj in meshes
            if obj.name == preferred
            or re.fullmatch(
                re.escape(preferred) + r"\.\d{3}",
                obj.name,
            )
        ]

        if suffixed:
            return suffixed

    if not meshes:
        raise RuntimeError(
            "No se encontró ninguna mesh importada deformada "
            "por el Armature del personaje."
        )

    return meshes


def collect_armature_actions(
    armature: bpy.types.Object,
) -> list[bpy.types.Action]:
    animation_data = armature.animation_data

    if animation_data is None:
        return []

    actions: list[bpy.types.Action] = []
    seen: set[int] = set()

    if animation_data.action is not None:
        action = animation_data.action
        actions.append(action)
        seen.add(action.as_pointer())

    for track in animation_data.nla_tracks:
        for strip in track.strips:
            action = strip.action

            if action is None:
                continue

            pointer = action.as_pointer()

            if pointer in seen:
                continue

            seen.add(pointer)
            actions.append(action)

    return actions


def action_name_matches(
    actual_name: str,
    requested_name: str,
) -> bool:
    if actual_name == requested_name:
        return True

    return re.fullmatch(
        re.escape(requested_name) + r"\.\d{3}",
        actual_name,
    ) is not None


def find_imported_action(
    armature: bpy.types.Object,
    imported_actions: list[bpy.types.Action],
    requested_name: str,
) -> bpy.types.Action:
    armature_actions = collect_armature_actions(
        armature
    )

    imported_pointers = {
        action.as_pointer()
        for action in imported_actions
    }

    candidates = [
        action
        for action in armature_actions
        if action.as_pointer() in imported_pointers
    ]

    if not candidates:
        candidates = imported_actions

    matches = [
        action
        for action in candidates
        if action_name_matches(
            action.name,
            requested_name,
        )
    ]

    if len(matches) == 1:
        action = matches[0]

        print(
            "[Magic Symbols] Action mapping:",
            f"{requested_name} -> {action.name}",
        )

        return action

    available = ", ".join(
        sorted(action.name for action in candidates)
    )

    if not matches:
        raise RuntimeError(
            f'No existe la Action importada "{requested_name}". '
            f"Disponibles en el source model: {available or '(none)'}"
        )

    raise RuntimeError(
        f'La Action "{requested_name}" es ambigua en el source model. '
        f"Coincidencias: {', '.join(action.name for action in matches)}"
    )


def attach_action(
    armature: bpy.types.Object,
    action: bpy.types.Action,
) -> None:
    if armature.animation_data is None:
        armature.animation_data_create()

    animation_data = armature.animation_data

    for track in animation_data.nla_tracks:
        track.mute = True

    animation_data.action = action

    slots = getattr(action, "slots", None)

    if slots and hasattr(animation_data, "action_slot"):
        slot = next(
            (
                candidate
                for candidate in slots
                if getattr(candidate, "target_id_type", "") == "OBJECT"
            ),
            slots[0],
        )

        try:
            animation_data.action_slot = slot
        except Exception as exc:
            print(
                "[Magic Symbols] WARN ActionSlot:",
                exc,
            )

    bpy.context.view_layer.update()


def pose_signature(
    armature: bpy.types.Object,
) -> list[float]:
    values: list[float] = []

    for bone in armature.pose.bones:
        for row in bone.matrix:
            values.extend(float(value) for value in row)

    return values


def validate_pose_changes(
    armature: bpy.types.Object,
    frames: list[float],
) -> None:
    indices = sorted(
        {
            0,
            len(frames) // 4,
            len(frames) // 2,
            3 * len(frames) // 4,
        }
    )

    signatures: list[list[float]] = []

    for index in indices:
        set_frame(frames[index])
        signatures.append(pose_signature(armature))

    max_delta = 0.0

    for signature in signatures[1:]:
        max_delta = max(
            max_delta,
            max(
                abs(a - b)
                for a, b in zip(
                    signatures[0],
                    signature,
                )
            ),
        )

    print(
        "[Magic Symbols] Pose max delta:",
        f"{max_delta:.8f}",
    )

    if max_delta <= POSE_CHANGE_EPSILON:
        raise RuntimeError(
            "La Action no produce cambios de pose detectables."
        )


def sample_frames(
    action: bpy.types.Action,
    animation_cfg: dict[str, Any],
    source_fps: float,
) -> list[float]:
    start, end = map(float, action.frame_range)

    timing = animation_cfg["timing"]
    mode = timing["mode"]

    if mode == "custom":
        count = int(timing["frame_count"])
    elif mode == "preserve_source_duration":
        if source_fps <= 0:
            raise RuntimeError("FPS fuente inválido.")

        source_duration = max(0.0, (end - start) / source_fps)

        playback_fps = float(
            timing.get(
                "playback_fps",
                animation_cfg["output_fps"],
            )
        )

        count = max(
            1,
            int(round(source_duration * playback_fps)),
        )
    else:
        raise RuntimeError(
            f"timing.mode no soportado: {mode}"
        )

    count = max(1, count)

    if count == 1:
        return [start]

    # For looping clips do not sample the exact end pose as an extra duplicate.
    if animation_cfg["loop"]:
        return [
            start + (end - start) * i / count
            for i in range(count)
        ]

    return [
        start + (end - start) * i / (count - 1)
        for i in range(count)
    ]


def find_pose_bone_exact(
    armature: bpy.types.Object,
    bone_name: str,
) -> bpy.types.PoseBone:
    bone = armature.pose.bones.get(bone_name)

    if bone is None:
        raise RuntimeError(
            f'No existe el hueso requerido "{bone_name}".'
        )

    return bone


def isolate_character_render(
    meshes: list[bpy.types.Object],
) -> dict[str, bool]:
    saved: dict[str, bool] = {}

    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue

        saved[obj.name] = bool(obj.hide_render)
        obj.hide_render = obj not in meshes

    bpy.context.view_layer.update()
    return saved


def restore_visibility(
    saved: dict[str, bool],
) -> None:
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH" and obj.name in saved:
            obj.hide_render = saved[obj.name]

    bpy.context.view_layer.update()


def bone_world_position(
    armature: bpy.types.Object,
    bone: bpy.types.PoseBone,
):
    return armature.matrix_world @ bone.matrix.translation


def camera_space(
    camera: bpy.types.Object,
    world_position,
):
    return camera.matrix_world.inverted() @ world_position


def midpoint(a, b):
    return (a + b) * 0.5


def vec_list(vector) -> list[float]:
    return [
        float(vector.x),
        float(vector.y),
        float(vector.z),
    ]


def configure_render(
    scene: bpy.types.Scene,
    config: dict[str, Any],
    playback_fps: float,
) -> None:
    render_cfg = config["render"]
    width, height = render_cfg["frame_size_px"]

    scene.render.engine = render_cfg["engine"]
    scene.render.resolution_x = int(width)
    scene.render.resolution_y = int(height)
    scene.render.resolution_percentage = 100

    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"

    scene.render.film_transparent = bool(
        render_cfg["transparent_background"]
    )

    fps_int = max(1, int(round(playback_fps)))
    scene.render.fps = fps_int
    scene.render.fps_base = fps_int / playback_fps


def desired_camera_coordinates(
    config: dict[str, Any],
) -> tuple[float, float, float, float]:
    render_cfg = config["render"]

    width, height = render_cfg["frame_size_px"]
    anchor_x, anchor_y = render_cfg["ground_anchor_px"]
    ortho_scale = float(render_cfg["ortho_scale"])

    aspect = width / height
    visible_w = ortho_scale * aspect
    visible_h = ortho_scale

    desired_x = (
        (anchor_x / width) - 0.5
    ) * visible_w

    desired_y = (
        0.5 - (anchor_y / height)
    ) * visible_h

    return (
        desired_x,
        desired_y,
        visible_w,
        visible_h,
    )


def feet_mid_reference(
    camera: bpy.types.Object,
    armature: bpy.types.Object,
    left_foot: bpy.types.PoseBone,
    right_foot: bpy.types.PoseBone,
    frames: list[float],
) -> dict[str, float]:
    xs: list[float] = []
    ys: list[float] = []

    for frame in frames:
        set_frame(frame)

        feet_mid_world = midpoint(
            bone_world_position(
                armature,
                left_foot,
            ),
            bone_world_position(
                armature,
                right_foot,
            ),
        )

        feet_mid_camera = camera_space(
            camera,
            feet_mid_world,
        )

        xs.append(float(feet_mid_camera.x))
        ys.append(float(feet_mid_camera.y))

    return {
        "mean_x": float(sum(xs) / len(xs)),
        "mean_y": float(sum(ys) / len(ys)),
        "min_x": float(min(xs)),
        "max_x": float(max(xs)),
        "range_x": float(max(xs) - min(xs)),
        "min_y": float(min(ys)),
        "max_y": float(max(ys)),
        "range_y": float(max(ys) - min(ys)),
    }


def apply_framing(
    camera: bpy.types.Object,
    config: dict[str, Any],
    reference: dict[str, float],
) -> dict[str, float]:
    ortho_scale = float(
        config["render"]["ortho_scale"]
    )

    camera.data.type = "ORTHO"
    camera.data.ortho_scale = ortho_scale

    (
        desired_x,
        desired_y,
        visible_w,
        visible_h,
    ) = desired_camera_coordinates(config)

    camera.data.shift_x = (
        reference["mean_x"] - desired_x
    ) / visible_w

    camera.data.shift_y = (
        reference["mean_y"] - desired_y
    ) / visible_h

    bpy.context.view_layer.update()

    return {
        "desired_camera_x": float(desired_x),
        "desired_camera_y": float(desired_y),
        "visible_w": float(visible_w),
        "visible_h": float(visible_h),
        "shift_x": float(camera.data.shift_x),
        "shift_y": float(camera.data.shift_y),
    }


def select_directions(
    config: dict[str, Any],
    requested: str | None,
) -> list[dict[str, Any]]:
    configured = config["render"]["directions"]

    if requested is None:
        return configured

    wanted = [
        item.strip()
        for item in requested.split(",")
        if item.strip()
    ]

    by_id = {
        item["id"]: item
        for item in configured
    }

    unknown = [
        direction
        for direction in wanted
        if direction not in by_id
    ]

    if unknown:
        raise RuntimeError(
            "Direcciones desconocidas: "
            + ", ".join(unknown)
        )

    return [by_id[direction] for direction in wanted]


def load_character_style(manifest_path: Path, config: dict[str, Any]):
    """Estilo toon/contorno para los atlas. Prioridad: env MS_CHAR_STYLE >
    character.json render.style > pipeline/config/ms.json character_style.
    'base' o vacio = sin estilo (aspecto original)."""
    import os

    spec = os.environ.get("MS_CHAR_STYLE") or config["render"].get("style")
    if not spec:   # estilo propio del personaje: pipeline/characters/<id>/estilo.txt (una linea con el nombre)
        try:
            ef = Path(manifest_path).parent / "estilo.txt"
            if ef.is_file():
                spec = ef.read_text(encoding="utf-8").strip().splitlines()[0].strip()
        except Exception:
            spec = None
    tools_dir = Path(__file__).resolve().parent
    if not spec:
        try:
            ms = json.loads(
                (tools_dir.parent / "config" / "ms.json").read_text(encoding="utf-8")
            )
            spec = ms.get("character_style")
        except Exception:
            spec = None
    if not spec or spec == "base":
        return None, "base"

    if str(tools_dir) not in sys.path:
        sys.path.insert(0, str(tools_dir))
    import ms_style

    dirs = [
        tools_dir.parent / "profiles" / "styles",
        tools_dir / "estilos",
        tools_dir / "terreno" / "styles",
    ]
    for d in dirs:
        if (d / f"{spec}.json").is_file() or Path(spec).is_file():
            return ms_style.load_style(spec, d), spec
    raise FileNotFoundError(f"Estilo '{spec}' no encontrado en {[str(d) for d in dirs]}")


def safe_animation_filename(animation_id: str) -> str:
    cleaned = "".join(
        ch.lower()
        if ch.isalnum()
        else "_"
        for ch in animation_id
    )

    return cleaned.strip("_") or "animation"


def main() -> int:
    args = parse_args()

    manifest_path = resolve_project_path(
        args.character_json
    )

    output_dir = resolve_project_path(
        args.output
    )

    try:
        config = load_json(manifest_path)
    except Exception as exc:
        print("[Magic Symbols] FAIL manifest:", exc)
        return EXIT_CONFIG_ERROR

    animation_id = args.animation

    if animation_id not in config["animations"]:
        print(
            "[Magic Symbols] FAIL animation:",
            f'"{animation_id}" no existe en character.json',
        )
        return EXIT_CONFIG_ERROR

    animation_cfg = config["animations"][animation_id]

    if not animation_cfg["enabled"]:
        print(
            "[Magic Symbols] FAIL animation:",
            f'"{animation_id}" está deshabilitada.',
        )
        return EXIT_CONFIG_ERROR

    try:
        directions = select_directions(
            config,
            args.directions,
        )

        scene = bpy.context.scene
        camera = scene.camera

        if camera is None:
            raise RuntimeError(
                "El Render Studio no tiene cámara activa."
            )

        (
            source_model,
            imported_objects,
            armature,
            imported_actions,
        ) = import_character_source(
            config
        )

        root = find_character_root(
            armature
        )

        turntable = create_direction_turntable(
            root,
            str(config["character"]["id"]),
        )

        meshes = character_meshes(
            config,
            armature,
            imported_objects,
        )

        action = find_imported_action(
            armature,
            imported_actions,
            animation_cfg["source_action"],
        )

        attach_action(
            armature,
            action,
        )

        armature.data.pose_position = "POSE"

        ground_cfg = config["model"]["rig"]["ground_reference"]

        left_foot = find_pose_bone_exact(
            armature,
            ground_cfg["left_bone"],
        )

        right_foot = find_pose_bone_exact(
            armature,
            ground_cfg["right_bone"],
        )

        source_fps = (
            scene.render.fps
            / scene.render.fps_base
        )

        frames = sample_frames(
            action,
            animation_cfg,
            source_fps,
        )

        timing = animation_cfg["timing"]

        if timing["mode"] == "custom":
            playback_fps = float(
                timing["playback_fps"]
            )
        else:
            playback_fps = float(
                timing.get(
                    "playback_fps",
                    animation_cfg["output_fps"],
                )
            )

        configure_render(
            scene,
            config,
            playback_fps,
        )

        validate_pose_changes(
            armature,
            frames,
        )

        # Modo pruebas de arte: un solo frame (fraccion 0..1 de la animacion).
        import os

        only = os.environ.get("MS_ONLY_FRAME")
        if only:
            pos = min(max(float(only), 0.0), 0.999)
            frames = [frames[int(len(frames) * pos)]]

        # Estilo toon + contorno (si falla, se renderiza con el aspecto base).
        style_report = {"name": "base", "applied": [], "errors": []}
        try:
            style, style_name = load_character_style(
                manifest_path, config
            )
            if style is not None:
                camera.data.type = "ORTHO"
                camera.data.ortho_scale = float(
                    config["render"]["ortho_scale"]
                )
                bpy.context.view_layer.update()
                import ms_style

                style_report = ms_style.apply_style(
                    style,
                    scene,
                    meshes,
                    camera,
                    armature.matrix_world.translation.copy(),
                )
        except Exception as style_exc:
            print("[Magic Symbols] WARN style:", style_exc)
            style_report = {
                "name": "error",
                "applied": [],
                "errors": [f"{type(style_exc).__name__}: {style_exc}"],
            }

    except Exception as exc:
        print("[Magic Symbols] FAIL setup:", exc)
        return EXIT_SCENE_ERROR

    output_dir.mkdir(
        parents=True,
        exist_ok=True,
    )

    original_turntable_rotation = (
        turntable.rotation_euler.copy()
    )

    original_shift_x = float(
        camera.data.shift_x
    )

    original_shift_y = float(
        camera.data.shift_y
    )

    original_ortho = float(
        camera.data.ortho_scale
    )

    original_filepath = str(
        scene.render.filepath
    )

    saved_visibility = isolate_character_render(
        meshes
    )

    filename_prefix = safe_animation_filename(
        animation_id
    )

    metadata: dict[str, Any] = {
        "pipeline": "Magic Symbols Pipeline v1",
        "renderer": "render_character.py",
        "character_id": config["character"]["id"],
        "animation_id": animation_id,
        "source_model": str(source_model),
        "source_action": animation_cfg["source_action"],
        "resolved_action": action.name,
        "imported_armature": armature.name,
        "direction_rotation_object": turntable.name,
        "blender_version": bpy.app.version_string,
        "timing": animation_cfg["timing"],
        "output_fps": playback_fps,
        "frame_count_per_direction": len(frames),
        "canvas_px": config["render"]["frame_size_px"],
        "ortho_scale": config["render"]["ortho_scale"],
        "ground_anchor_px": config["render"]["ground_anchor_px"],
        "stabilization": config["render"]["stabilization"],
        "style": style_report,
        "character_meshes": [
            obj.name
            for obj in meshes
        ],
        "direction_order": [
            item["id"]
            for item in directions
        ],
        "directions": {},
    }

    try:
        for direction in directions:
            direction_name = direction["id"]
            direction_degrees = float(
                direction["rotation_deg"]
            )

            print()
            print(
                "[Magic Symbols] Render:",
                animation_id,
                direction_name,
                f"{direction_degrees:.1f}°",
            )

            turntable.rotation_euler = (
                original_turntable_rotation.copy()
            )

            turntable.rotation_euler[2] = math.radians(
                direction_degrees
            )

            bpy.context.view_layer.update()

            print(
                "[Magic Symbols] Direction turntable:",
                turntable.name,
                "yaw=",
                f"{math.degrees(turntable.rotation_euler[2]):.1f}°",
            )

            camera.data.shift_x = 0.0
            camera.data.shift_y = 0.0
            camera.data.ortho_scale = float(
                config["render"]["ortho_scale"]
            )

            bpy.context.view_layer.update()

            reference = feet_mid_reference(
                camera,
                armature,
                left_foot,
                right_foot,
                frames,
            )

            framing = apply_framing(
                camera,
                config,
                reference,
            )

            direction_dir = (
                output_dir
                / direction_name
            )

            direction_dir.mkdir(
                parents=True,
                exist_ok=True,
            )

            frame_metadata: list[dict[str, Any]] = []

            for index, source_frame in enumerate(
                frames
            ):
                set_frame(source_frame)

                feet_mid_world = midpoint(
                    bone_world_position(
                        armature,
                        left_foot,
                    ),
                    bone_world_position(
                        armature,
                        right_foot,
                    ),
                )

                feet_mid_camera = camera_space(
                    camera,
                    feet_mid_world,
                )

                frame_path = (
                    direction_dir
                    / (
                        f"{filename_prefix}_"
                        f"{direction_name}_"
                        f"{index:03d}.png"
                    )
                )

                scene.render.filepath = str(
                    frame_path
                )

                bpy.ops.render.render(
                    write_still=True
                )

                frame_metadata.append({
                    "frame_index": index,
                    "source_frame": float(
                        source_frame
                    ),
                    "file": frame_path.name,
                    "feet_mid_camera": vec_list(
                        feet_mid_camera
                    ),
                })

            metadata["directions"][direction_name] = {
                "degrees": direction_degrees,
                "feet_mid_reference": reference,
                "framing": framing,
                "frames": frame_metadata,
            }

            print(
                "[Magic Symbols] PASS",
                direction_name,
                f"frames={len(frames)}",
                "shift=",
                f"{framing['shift_x']:.6f},",
                f"{framing['shift_y']:.6f}",
            )

        metadata_path = (
            output_dir
            / f"{filename_prefix}_render_metadata.json"
        )

        metadata_path.write_text(
            json.dumps(
                metadata,
                indent=2,
                ensure_ascii=False,
            )
            + "\n",
            encoding="utf-8",
        )

        print()
        print(
            "[Magic Symbols] RENDER VALID OUTPUT"
        )
        print(
            "[Magic Symbols] Metadata:",
            metadata_path,
        )

    except Exception as exc:
        print(
            "[Magic Symbols] FAIL render:",
            exc,
        )
        return EXIT_RENDER_ERROR

    finally:
        restore_visibility(
            saved_visibility
        )

        turntable.rotation_euler = (
            original_turntable_rotation
        )

        camera.data.shift_x = (
            original_shift_x
        )

        camera.data.shift_y = (
            original_shift_y
        )

        camera.data.ortho_scale = (
            original_ortho
        )

        scene.render.filepath = (
            original_filepath
        )

        if frames:
            set_frame(frames[0])

    return EXIT_OK


if __name__ == "__main__":
    raise SystemExit(main())
