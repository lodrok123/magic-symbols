from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any

import bpy
from mathutils import Vector


EXIT_VALID = 0
EXIT_AUDIT_FAILED = 2
EXIT_IO_ERROR = 3
EXIT_IMPORT_ERROR = 4


def parse_blender_args() -> list[str]:
    argv = sys.argv
    if "--" not in argv:
        return []
    return argv[argv.index("--") + 1:]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Audit animations declared in a Magic Symbols character manifest."
    )
    parser.add_argument(
        "--character-json",
        required=True,
        type=Path,
    )
    parser.add_argument(
        "--project-root",
        type=Path,
        default=None,
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=None,
    )
    parser.add_argument(
        "--sample-count",
        type=int,
        default=33,
        help="Samples used for motion/bounds analysis. Default: 33.",
    )
    return parser.parse_args(parse_blender_args())


def load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError as exc:
        raise RuntimeError(f"No existe: {path}") from exc
    except json.JSONDecodeError as exc:
        raise RuntimeError(
            f"JSON inválido en {path}, línea {exc.lineno}, columna {exc.colno}: {exc.msg}"
        ) from exc

    if not isinstance(data, dict):
        raise RuntimeError("character.json debe contener un objeto JSON raíz")

    return data


def print_pass(label: str, details: str = "") -> None:
    suffix = f" — {details}" if details else ""
    print(f"PASS {label}{suffix}")


def print_fail(label: str, details: str) -> None:
    print(f"FAIL {label} — {details}")


def print_info(label: str, details: str) -> None:
    print(f"INFO {label} — {details}")


def clear_scene() -> None:
    if bpy.context.object is not None:
        try:
            bpy.ops.object.mode_set(mode="OBJECT")
        except RuntimeError:
            pass

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def choose_armature() -> bpy.types.Object | None:
    armatures = [
        obj
        for obj in bpy.context.scene.objects
        if obj.type == "ARMATURE"
    ]

    if not armatures:
        return None

    return max(
        armatures,
        key=lambda obj: len(obj.data.bones),
    )


def choose_character_meshes(
    config: dict[str, Any],
    armature: bpy.types.Object,
) -> list[bpy.types.Object]:
    mesh_config = config["model"]["mesh_selection"]
    preferred_name = mesh_config.get("preferred_mesh_name", "").strip()

    meshes = [
        obj
        for obj in bpy.context.scene.objects
        if obj.type == "MESH"
        and any(
            modifier.type == "ARMATURE"
            and modifier.object == armature
            for modifier in obj.modifiers
        )
    ]

    if preferred_name:
        exact = [obj for obj in meshes if obj.name == preferred_name]
        if exact:
            return exact

    return meshes


def get_action(name: str) -> bpy.types.Action | None:
    return bpy.data.actions.get(name)


def set_action(
    armature: bpy.types.Object,
    action: bpy.types.Action,
) -> None:
    if armature.animation_data is None:
        armature.animation_data_create()

    armature.animation_data.action = action


def pose_bone_world(
    armature: bpy.types.Object,
    bone_name: str,
) -> Vector:
    bone = armature.pose.bones.get(bone_name)
    if bone is None:
        raise RuntimeError(f"No existe pose bone: {bone_name}")

    return armature.matrix_world @ bone.head


def evaluated_bounds(
    meshes: list[bpy.types.Object],
) -> tuple[Vector, Vector]:
    depsgraph = bpy.context.evaluated_depsgraph_get()

    mins = Vector((math.inf, math.inf, math.inf))
    maxs = Vector((-math.inf, -math.inf, -math.inf))

    found = False

    for obj in meshes:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()

        try:
            for vertex in mesh.vertices:
                p = evaluated.matrix_world @ vertex.co
                mins.x = min(mins.x, p.x)
                mins.y = min(mins.y, p.y)
                mins.z = min(mins.z, p.z)
                maxs.x = max(maxs.x, p.x)
                maxs.y = max(maxs.y, p.y)
                maxs.z = max(maxs.z, p.z)
                found = True
        finally:
            evaluated.to_mesh_clear()

    if not found:
        raise RuntimeError("No se pudo obtener bounding box evaluado")

    return mins, maxs


def vec_to_list(v: Vector) -> list[float]:
    return [float(v.x), float(v.y), float(v.z)]


def vector_distance(a: Vector, b: Vector) -> float:
    return float((a - b).length)


def sample_frames(
    frame_start: float,
    frame_end: float,
    sample_count: int,
) -> list[float]:
    if sample_count <= 1 or math.isclose(frame_start, frame_end):
        return [frame_start]

    return [
        frame_start + (frame_end - frame_start) * i / (sample_count - 1)
        for i in range(sample_count)
    ]


def set_scene_frame(frame: float) -> None:
    whole = int(math.floor(frame))
    subframe = float(frame - whole)
    bpy.context.scene.frame_set(whole, subframe=subframe)


def audit_action(
    config: dict[str, Any],
    armature: bpy.types.Object,
    meshes: list[bpy.types.Object],
    animation_id: str,
    animation_cfg: dict[str, Any],
    sample_count: int,
) -> dict[str, Any]:
    action_name = animation_cfg["source_action"]
    action = get_action(action_name)

    if action is None:
        return {
            "animation_id": animation_id,
            "source_action": action_name,
            "valid": False,
            "errors": [f"Action no encontrada: {action_name}"],
        }

    set_action(armature, action)

    frame_start, frame_end = [float(x) for x in action.frame_range]
    duration_frames = max(0.0, frame_end - frame_start)

    scene_fps = (
        bpy.context.scene.render.fps
        / bpy.context.scene.render.fps_base
    )

    duration_seconds = (
        duration_frames / scene_fps
        if scene_fps > 0
        else 0.0
    )

    output_fps = float(animation_cfg["output_fps"])
    expected_output_frames = int(animation_cfg["frame_count"])

    hips_name = config["model"]["rig"]["required_bones"][0]
    left_foot_name = config["model"]["rig"]["ground_reference"]["left_bone"]
    right_foot_name = config["model"]["rig"]["ground_reference"]["right_bone"]

    samples = sample_frames(
        frame_start,
        frame_end,
        max(2, sample_count),
    )

    hips_positions: list[Vector] = []
    left_positions: list[Vector] = []
    right_positions: list[Vector] = []
    bbox_sizes: list[Vector] = []
    bbox_centers: list[Vector] = []

    for frame in samples:
        set_scene_frame(frame)

        hips_positions.append(
            pose_bone_world(armature, hips_name)
        )
        left_positions.append(
            pose_bone_world(armature, left_foot_name)
        )
        right_positions.append(
            pose_bone_world(armature, right_foot_name)
        )

        bbox_min, bbox_max = evaluated_bounds(meshes)
        bbox_sizes.append(bbox_max - bbox_min)
        bbox_centers.append((bbox_min + bbox_max) * 0.5)

    hips_total = vector_distance(
        hips_positions[0],
        hips_positions[-1],
    )

    left_total = vector_distance(
        left_positions[0],
        left_positions[-1],
    )

    right_total = vector_distance(
        right_positions[0],
        right_positions[-1],
    )

    root_motion_horizontal = math.sqrt(
        (hips_positions[-1].x - hips_positions[0].x) ** 2
        + (hips_positions[-1].y - hips_positions[0].y) ** 2
    )

    hips_step_distances = [
        vector_distance(hips_positions[i - 1], hips_positions[i])
        for i in range(1, len(hips_positions))
    ]

    left_step_distances = [
        vector_distance(left_positions[i - 1], left_positions[i])
        for i in range(1, len(left_positions))
    ]

    right_step_distances = [
        vector_distance(right_positions[i - 1], right_positions[i])
        for i in range(1, len(right_positions))
    ]

    bbox_height_values = [float(v.z) for v in bbox_sizes]
    bbox_width_values = [float(v.x) for v in bbox_sizes]
    bbox_depth_values = [float(v.y) for v in bbox_sizes]

    center_x_values = [float(v.x) for v in bbox_centers]
    center_y_values = [float(v.y) for v in bbox_centers]
    center_z_values = [float(v.z) for v in bbox_centers]

    first_last_pose_delta = {
        "hips": hips_total,
        "left_foot": left_total,
        "right_foot": right_total,
        "bbox_center": vector_distance(
            bbox_centers[0],
            bbox_centers[-1],
        ),
        "bbox_size": vector_distance(
            bbox_sizes[0],
            bbox_sizes[-1],
        ),
    }

    timing = animation_cfg["timing"]
    timing_mode = timing["mode"]

    if timing_mode == "custom":
        playback_fps = float(timing["playback_fps"])
        playback_frame_count = int(timing["frame_count"])
        configured_duration_seconds = (
            playback_frame_count / playback_fps
            if playback_fps > 0
            else 0.0
        )
        recommended_preserve_frame_count = None
    else:
        playback_fps = float(
            timing.get(
                "playback_fps",
                animation_cfg["output_fps"],
            )
        )
        playback_frame_count = int(
            round(duration_seconds * playback_fps)
        )
        playback_frame_count = max(1, playback_frame_count)
        configured_duration_seconds = duration_seconds
        recommended_preserve_frame_count = playback_frame_count

    duration_scale = (
        configured_duration_seconds / duration_seconds
        if duration_seconds > 0
        else 1.0
    )

    expect_in_place = bool(
        animation_cfg["expect_in_place"]
    )

    root_motion_tolerance = float(
        animation_cfg["root_motion_tolerance"]
    )

    errors: list[str] = []

    if (
        expect_in_place
        and root_motion_horizontal > root_motion_tolerance
    ):
        errors.append(
            "root motion horizontal "
            f"{root_motion_horizontal:.6f} excede tolerancia "
            f"{root_motion_tolerance:.6f}"
        )

    result = {
        "animation_id": animation_id,
        "source_action": action_name,
        "valid": not errors,
        "errors": errors,
        "loop_declared": bool(animation_cfg["loop"]),
        "scene_fps": scene_fps,
        "source_frame_range": [frame_start, frame_end],
        "source_duration_frames": duration_frames,
        "source_duration_seconds": duration_seconds,
        "output_fps": output_fps,
        "configured_output_frame_count": expected_output_frames,
        "timing": {
            "mode": timing_mode,
            "playback_fps": playback_fps,
            "playback_frame_count": playback_frame_count,
            "configured_duration_seconds": configured_duration_seconds,
            "source_duration_seconds": duration_seconds,
            "duration_scale_vs_source": duration_scale,
            "recommended_preserve_frame_count": recommended_preserve_frame_count,
        },
        "expect_in_place": expect_in_place,
        "root_motion_tolerance": root_motion_tolerance,
        "samples_used": len(samples),
        "motion": {
            "hips_start_world": vec_to_list(hips_positions[0]),
            "hips_end_world": vec_to_list(hips_positions[-1]),
            "hips_start_to_end_distance": hips_total,
            "hips_horizontal_root_motion": root_motion_horizontal,
            "hips_mean_step_distance": (
                sum(hips_step_distances) / len(hips_step_distances)
                if hips_step_distances
                else 0.0
            ),
            "left_foot_start_to_end_distance": left_total,
            "right_foot_start_to_end_distance": right_total,
            "left_foot_mean_step_distance": (
                sum(left_step_distances) / len(left_step_distances)
                if left_step_distances
                else 0.0
            ),
            "right_foot_mean_step_distance": (
                sum(right_step_distances) / len(right_step_distances)
                if right_step_distances
                else 0.0
            ),
        },
        "bounds": {
            "width_min": min(bbox_width_values),
            "width_max": max(bbox_width_values),
            "depth_min": min(bbox_depth_values),
            "depth_max": max(bbox_depth_values),
            "height_min": min(bbox_height_values),
            "height_max": max(bbox_height_values),
            "center_x_range": max(center_x_values) - min(center_x_values),
            "center_y_range": max(center_y_values) - min(center_y_values),
            "center_z_range": max(center_z_values) - min(center_z_values),
        },
        "loop_closure": first_last_pose_delta,
    }

    return result


def main() -> int:
    args = parse_args()

    project_root = (
        args.project_root.resolve()
        if args.project_root is not None
        else Path.cwd().resolve()
    )

    manifest = args.character_json
    if not manifest.is_absolute():
        manifest = project_root / manifest
    manifest = manifest.resolve()

    print("Magic Symbols Pipeline v1 — Animation Audit")
    print(f"Blender:      {bpy.app.version_string}")
    print(f"Project root: {project_root}")
    print(f"Manifest:     {manifest}")
    print()

    try:
        config = load_json(manifest)
    except RuntimeError as exc:
        print_fail("manifest", str(exc))
        return EXIT_IO_ERROR

    source_model = Path(config["character"]["source_model"])
    if not source_model.is_absolute():
        source_model = project_root / source_model
    source_model = source_model.resolve()

    if not source_model.exists():
        print_fail("source model", f"No existe: {source_model}")
        return EXIT_IO_ERROR

    clear_scene()

    try:
        result = bpy.ops.import_scene.gltf(filepath=str(source_model))
    except Exception as exc:
        print_fail("GLB import", str(exc))
        return EXIT_IMPORT_ERROR

    if "FINISHED" not in result:
        print_fail("GLB import", str(result))
        return EXIT_IMPORT_ERROR

    print_pass("GLB import")

    armature = choose_armature()
    if armature is None:
        print_fail("armature", "No se encontró")
        return EXIT_AUDIT_FAILED

    print_pass("armature", armature.name)

    meshes = choose_character_meshes(config, armature)
    if not meshes:
        print_fail("character mesh", "No se encontró")
        return EXIT_AUDIT_FAILED

    print_pass(
        "character mesh",
        ", ".join(obj.name for obj in meshes),
    )

    report = {
        "pipeline": "Magic Symbols Pipeline v1",
        "audit": "animations",
        "character_id": config["character"]["id"],
        "blender_version": bpy.app.version_string,
        "source_model": str(source_model),
        "valid": True,
        "animations": {},
    }

    failures: list[str] = []

    enabled_animations = {
        animation_id: animation
        for animation_id, animation in config["animations"].items()
        if animation["enabled"]
    }

    print()
    print("ANIMATION AUDIT")
    print("---------------")

    for animation_id, animation_cfg in enabled_animations.items():
        result = audit_action(
            config=config,
            armature=armature,
            meshes=meshes,
            animation_id=animation_id,
            animation_cfg=animation_cfg,
            sample_count=args.sample_count,
        )

        report["animations"][animation_id] = result

        if not result["valid"]:
            failures.extend(result["errors"])
            print_fail(
                animation_id,
                "; ".join(result["errors"]),
            )
            continue

        motion = result["motion"]
        bounds = result["bounds"]
        loop = result["loop_closure"]

        timing = result["timing"]

        if result["valid"]:
            print_pass(
                animation_id,
                (
                    f"{result['source_action']} | "
                    f"{result['source_duration_seconds']:.3f}s source | "
                    f"{timing['configured_duration_seconds']:.3f}s configured | "
                    f"timing={timing['mode']}"
                ),
            )
        else:
            failures.extend(
                f"{animation_id}: {error}"
                for error in result["errors"]
            )
            print_fail(
                animation_id,
                "; ".join(result["errors"]),
            )

        print_info(
            f"{animation_id}.timing",
            (
                f"{timing['playback_frame_count']} frames "
                f"@ {timing['playback_fps']:.3f} FPS | "
                f"duration scale={timing['duration_scale_vs_source']:.4f}x"
            ),
        )

        print_info(
            f"{animation_id}.root_motion",
            (
                f"{motion['hips_horizontal_root_motion']:.6f} units | "
                f"expect_in_place={result['expect_in_place']} | "
                f"tolerance={result['root_motion_tolerance']:.6f}"
            ),
        )

        print_info(
            f"{animation_id}.height",
            f"{bounds['height_min']:.4f}–{bounds['height_max']:.4f} units",
        )

        if result["loop_declared"]:
            print_info(
                f"{animation_id}.loop_closure",
                (
                    f"hips={loop['hips']:.6f}, "
                    f"LFoot={loop['left_foot']:.6f}, "
                    f"RFoot={loop['right_foot']:.6f}"
                ),
            )

    report["valid"] = not failures
    report["failures"] = failures

    if args.report is not None:
        report_path = args.report
        if not report_path.is_absolute():
            report_path = project_root / report_path
        report_path = report_path.resolve()
    else:
        report_root = project_root / config["output"]["report_root"]
        report_path = (
            report_root / "animation_audit.json"
        ).resolve()

    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print()
    print(f"REPORT {report_path}")

    if failures:
        print()
        print(f"ANIMATION AUDIT FAILED ({len(failures)} failure(s))")
        return EXIT_AUDIT_FAILED

    print()
    print("ANIMATION AUDIT VALID")
    return EXIT_VALID


if __name__ == "__main__":
    raise SystemExit(main())
