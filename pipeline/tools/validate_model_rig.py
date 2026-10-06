from __future__ import annotations

import argparse
import json
import math
import os
import sys
import traceback
from pathlib import Path
from typing import Any

import bpy
from mathutils import Vector


EXIT_VALID = 0
EXIT_INVALID_MODEL = 2
EXIT_IO_ERROR = 3
EXIT_IMPORT_ERROR = 4


def parse_blender_args() -> list[str]:
    argv = sys.argv
    if "--" not in argv:
        return []
    return argv[argv.index("--") + 1:]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate a Magic Symbols character GLB inside Blender."
    )
    parser.add_argument(
        "--character-json",
        required=True,
        type=Path,
        help="Path to pipeline/characters/<id>/character.json",
    )
    parser.add_argument(
        "--project-root",
        type=Path,
        default=None,
        help="Project root. Defaults to current working directory.",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=None,
        help="Optional explicit report JSON path.",
    )
    parser.add_argument(
        "--height-tolerance",
        type=float,
        default=0.25,
        help="Relative allowed height error. Default: 0.25 = ±25%%.",
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
    except OSError as exc:
        raise RuntimeError(f"No se pudo leer {path}: {exc}") from exc

    if not isinstance(data, dict):
        raise RuntimeError("character.json debe contener un objeto JSON raíz")

    return data


def print_pass(label: str, details: str = "") -> None:
    suffix = f" — {details}" if details else ""
    print(f"PASS {label}{suffix}")


def print_fail(label: str, details: str) -> None:
    print(f"FAIL {label} — {details}")


def print_warn(label: str, details: str) -> None:
    print(f"WARN {label} — {details}")


def clear_scene() -> None:
    if bpy.context.object is not None:
        try:
            bpy.ops.object.mode_set(mode="OBJECT")
        except RuntimeError:
            pass

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    for collection in (
        bpy.data.meshes,
        bpy.data.armatures,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for datablock in list(collection):
            if datablock.users == 0:
                collection.remove(datablock)


def import_glb(path: Path) -> None:
    result = bpy.ops.import_scene.gltf(filepath=str(path))
    if "FINISHED" not in result:
        raise RuntimeError(f"Blender devolvió: {result}")


def world_bbox_corners(obj: bpy.types.Object) -> list[Vector]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)

    if evaluated.type != "MESH":
        return []

    mesh = evaluated.to_mesh()
    try:
        return [evaluated.matrix_world @ vertex.co.copy() for vertex in mesh.vertices]
    finally:
        evaluated.to_mesh_clear()


def combined_mesh_height(meshes: list[bpy.types.Object]) -> tuple[float, float, float]:
    z_values: list[float] = []

    for obj in meshes:
        for point in world_bbox_corners(obj):
            z_values.append(float(point.z))

    if not z_values:
        raise RuntimeError("No se pudieron obtener vértices evaluados de las meshes")

    z_min = min(z_values)
    z_max = max(z_values)
    return z_min, z_max, z_max - z_min


def choose_armature() -> bpy.types.Object | None:
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]

    if not armatures:
        return None

    def score(obj: bpy.types.Object) -> tuple[int, int]:
        influenced_meshes = sum(
            1
            for mesh in bpy.context.scene.objects
            if mesh.type == "MESH"
            and any(
                modifier.type == "ARMATURE" and modifier.object == obj
                for modifier in mesh.modifiers
            )
        )
        bone_count = len(obj.data.bones)
        return influenced_meshes, bone_count

    return max(armatures, key=score)


def choose_character_meshes(
    config: dict[str, Any],
    armature: bpy.types.Object,
) -> list[bpy.types.Object]:
    mesh_config = config["model"]["mesh_selection"]
    mode = mesh_config["mode"]
    preferred_name = mesh_config.get("preferred_mesh_name", "").strip()

    all_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]

    if mode == "object_name":
        selected = [obj for obj in all_meshes if obj.name == preferred_name]
        return selected

    if mode == "armature_modifier":
        influenced = [
            obj
            for obj in all_meshes
            if any(
                modifier.type == "ARMATURE" and modifier.object == armature
                for modifier in obj.modifiers
            )
        ]

        if preferred_name:
            exact = [obj for obj in influenced if obj.name == preferred_name]
            if exact:
                return exact

        return influenced

    return []


def action_names() -> set[str]:
    return {action.name for action in bpy.data.actions}


def bone_world_position(
    armature_obj: bpy.types.Object,
    bone_name: str,
) -> Vector:
    pose_bone = armature_obj.pose.bones.get(bone_name)
    if pose_bone is None:
        raise RuntimeError(f"No existe pose bone: {bone_name}")
    return armature_obj.matrix_world @ pose_bone.head


def resolve_report_path(
    args: argparse.Namespace,
    config: dict[str, Any],
    project_root: Path,
) -> Path:
    if args.report is not None:
        report = args.report
        if not report.is_absolute():
            report = project_root / report
        return report.resolve()

    report_root = project_root / config["output"]["report_root"]
    return (report_root / "model_rig_validation.json").resolve()


def main() -> int:
    args = parse_args()

    character_json = args.character_json
    if not character_json.is_absolute():
        character_json = Path.cwd() / character_json
    character_json = character_json.resolve()

    project_root = (
        args.project_root.resolve()
        if args.project_root is not None
        else Path.cwd().resolve()
    )

    print("Magic Symbols Pipeline v1 — Model/Rig Validator")
    print(f"Blender:      {bpy.app.version_string}")
    print(f"Project root: {project_root}")
    print(f"Manifest:     {character_json}")
    print()

    try:
        config = load_json(character_json)
    except RuntimeError as exc:
        print_fail("manifest", str(exc))
        return EXIT_IO_ERROR

    source_model = Path(config["character"]["source_model"])
    if not source_model.is_absolute():
        source_model = project_root / source_model
    source_model = source_model.resolve()

    report_path = resolve_report_path(args, config, project_root)
    report_path.parent.mkdir(parents=True, exist_ok=True)

    report: dict[str, Any] = {
        "pipeline": "Magic Symbols Pipeline v1",
        "validator": "model_rig",
        "blender_version": bpy.app.version_string,
        "character_id": config["character"]["id"],
        "manifest": str(character_json),
        "source_model": str(source_model),
        "valid": False,
        "checks": [],
        "warnings": [],
        "measurements": {},
    }

    failures: list[str] = []

    def passed(name: str, details: str = "") -> None:
        print_pass(name, details)
        report["checks"].append({
            "name": name,
            "status": "PASS",
            "details": details,
        })

    def failed(name: str, details: str) -> None:
        print_fail(name, details)
        failures.append(f"{name}: {details}")
        report["checks"].append({
            "name": name,
            "status": "FAIL",
            "details": details,
        })

    def warned(name: str, details: str) -> None:
        print_warn(name, details)
        report["warnings"].append({
            "name": name,
            "details": details,
        })

    if not source_model.exists():
        failed("source model", f"No existe: {source_model}")
        report["failures"] = failures
        report_path.write_text(
            json.dumps(report, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        print()
        print(f"REPORT {report_path}")
        print("MODEL INVALID")
        return EXIT_IO_ERROR

    passed("source model", source_model.name)

    try:
        clear_scene()
        import_glb(source_model)
    except Exception as exc:
        failed("GLB import", str(exc))
        report["traceback"] = traceback.format_exc()
        report["failures"] = failures
        report_path.write_text(
            json.dumps(report, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        print()
        print(f"REPORT {report_path}")
        print("MODEL INVALID")
        return EXIT_IMPORT_ERROR

    passed("GLB import")

    scene_objects = list(bpy.context.scene.objects)
    report["measurements"]["scene_object_count"] = len(scene_objects)

    armatures = [obj for obj in scene_objects if obj.type == "ARMATURE"]
    report["measurements"]["armature_count"] = len(armatures)

    armature = choose_armature()

    if armature is None:
        failed("armature", "No se encontró ningún Armature")
    else:
        passed(
            "armature",
            f"{armature.name} ({len(armature.data.bones)} bones)",
        )
        report["measurements"]["armature_name"] = armature.name
        report["measurements"]["bone_count"] = len(armature.data.bones)

    meshes: list[bpy.types.Object] = []

    if armature is not None:
        meshes = choose_character_meshes(config, armature)

    if not meshes:
        failed(
            "character mesh",
            "No se encontró una mesh compatible con model.mesh_selection",
        )
    else:
        mesh_names = [obj.name for obj in meshes]
        passed("character mesh", ", ".join(mesh_names))
        report["measurements"]["mesh_names"] = mesh_names

    if armature is not None and meshes:
        bad_modifiers: list[str] = []

        for mesh in meshes:
            matching = [
                modifier
                for modifier in mesh.modifiers
                if modifier.type == "ARMATURE"
                and modifier.object == armature
            ]
            if not matching:
                bad_modifiers.append(mesh.name)

        if bad_modifiers:
            failed(
                "armature modifier",
                "Sin Armature Modifier válido: " + ", ".join(bad_modifiers),
            )
        else:
            passed("armature modifier")

    required_bones = config["model"]["rig"]["required_bones"]

    if armature is not None:
        bone_names = {bone.name for bone in armature.data.bones}
        missing_bones = [
            bone_name
            for bone_name in required_bones
            if bone_name not in bone_names
        ]

        if missing_bones:
            failed(
                "required bones",
                "Faltan: " + ", ".join(missing_bones),
            )
        else:
            passed(
                "required bones",
                ", ".join(required_bones),
            )

    ground_ref = config["model"]["rig"]["ground_reference"]

    if armature is not None:
        left_name = ground_ref["left_bone"]
        right_name = ground_ref["right_bone"]

        try:
            left_pos = bone_world_position(armature, left_name)
            right_pos = bone_world_position(armature, right_name)
            midpoint = (left_pos + right_pos) * 0.5

            report["measurements"]["ground_reference"] = {
                "left_bone": left_name,
                "right_bone": right_name,
                "left_world": list(left_pos),
                "right_world": list(right_pos),
                "midpoint_world": list(midpoint),
            }

            passed(
                "ground reference",
                f"{left_name} + {right_name}",
            )
        except RuntimeError as exc:
            failed("ground reference", str(exc))

    if meshes:
        try:
            z_min, z_max, height = combined_mesh_height(meshes)
            expected_height = float(config["model"]["expected_height_units"])
            tolerance = float(args.height_tolerance)
            lower = expected_height * (1.0 - tolerance)
            upper = expected_height * (1.0 + tolerance)

            report["measurements"]["geometry"] = {
                "z_min": z_min,
                "z_max": z_max,
                "height": height,
                "expected_height": expected_height,
                "allowed_range": [lower, upper],
                "relative_error": (
                    abs(height - expected_height) / expected_height
                    if expected_height > 0
                    else None
                ),
            }

            if lower <= height <= upper:
                passed(
                    "character height",
                    f"{height:.4f} units (expected ~{expected_height:.4f})",
                )
            else:
                failed(
                    "character height",
                    f"{height:.4f} units fuera de rango "
                    f"[{lower:.4f}, {upper:.4f}]",
                )
        except Exception as exc:
            failed("character height", str(exc))

    existing_actions = action_names()
    report["measurements"]["action_count"] = len(existing_actions)
    report["measurements"]["actions"] = sorted(existing_actions)

    enabled_animations = {
        animation_id: animation
        for animation_id, animation in config["animations"].items()
        if animation["enabled"]
    }

    missing_actions: list[str] = []

    for animation_id, animation in enabled_animations.items():
        source_action = animation["source_action"]

        if source_action not in existing_actions:
            missing_actions.append(
                f"{animation_id} -> {source_action}"
            )

    if missing_actions:
        failed(
            "animation actions",
            "Faltan: " + ", ".join(missing_actions),
        )
    else:
        passed(
            "animation actions",
            ", ".join(
                animation["source_action"]
                for animation in enabled_animations.values()
            ),
        )

    if armature is not None:
        scale = armature.scale
        report["measurements"]["armature_scale"] = list(scale)

        if all(math.isclose(float(component), 1.0, abs_tol=1e-5) for component in scale):
            passed("armature scale", "1,1,1")
        else:
            warned(
                "armature scale",
                f"{tuple(round(float(x), 6) for x in scale)}; "
                "no invalida v1, pero conviene normalizarlo en producción",
            )

    report["failures"] = failures
    report["valid"] = not failures

    report_path.write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print()
    print(f"REPORT {report_path}")

    if failures:
        print()
        print(f"MODEL INVALID ({len(failures)} failure(s))")
        return EXIT_INVALID_MODEL

    print()
    print("MODEL VALID")
    return EXIT_VALID


if __name__ == "__main__":
    sys.exit(main())
