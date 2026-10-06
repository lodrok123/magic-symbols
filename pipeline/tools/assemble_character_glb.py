#!/usr/bin/env python3
"""
Magic Symbols - assemble_character_glb.py

Combina varios GLB del mismo personaje, cada uno con una animación,
en un único GLB maestro compatible con la pipeline v1.

Estructura esperada:

pipeline/
  characters/
    <character_id>/
      source/
        idle.glb
        walk.glb
        run.glb
      work/
      reports/

Salida:

pipeline/characters/<character_id>/<character_id>_master.glb
pipeline/characters/<character_id>/work/<character_id>_master.blend
pipeline/characters/<character_id>/reports/assemble_character_glb.json

Uso:

python pipeline/tools/assemble_character_glb.py bookseller_test --sources idle walk run

Blender esperado por defecto:
C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe
"""

from __future__ import annotations

import re
import argparse
import json
import math
import os
import subprocess
import sys
from pathlib import Path


CANONICAL_ACTIONS = {
    "idle": "Idle",
    "walk": "Walking",
    "run": "Running",
    "talk": "Talk",
    "interact_collect": "Interact_Collect",
    "interact_open_door": "Interact_Open_Door",
    "sit": "Sit",
    "crouch": "Crouch",
    "hit": "Hit",
    "death": "Death",
}

SOURCE_ORDER = tuple(CANONICAL_ACTIONS)

REQUIRED_BONES = (
    "mixamorig:Hips",
    "mixamorig:LeftFoot",
    "mixamorig:RightFoot",
)


def get_project_root() -> Path:
    return Path(__file__).resolve().parents[2]


def get_default_blender() -> Path:
    env = os.environ.get("BLENDER_EXE")
    if env:
        return Path(env)

    known = Path(
        r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
    )
    if known.exists():
        return known

    return Path("blender")


def discover_sources(
    character_dir: Path,
    requested_sources: list[str] | None,
) -> list[dict]:
    source_dir = character_dir / "source"

    if not source_dir.is_dir():
        raise FileNotFoundError(f"No existe la carpeta source: {source_dir}")

    if requested_sources:
        keys = [key.strip().lower() for key in requested_sources]
    else:
        present = {path.stem.lower() for path in source_dir.glob("*.glb")}
        keys = [key for key in SOURCE_ORDER if key in present]
        # animaciones extra (Animation_<Nombre>.glb): todas las demas de source/ entran tambien
        keys += sorted(key for key in present if key not in SOURCE_ORDER and not key.startswith("_"))

    if "idle" not in keys:
        raise RuntimeError("Se necesita source/idle.glb como modelo maestro.")

    keys = ["idle"] + [key for key in keys if key != "idle"]

    result = []
    seen = set()

    for key in keys:
        if key in seen:
            continue

        seen.add(key)
        path = source_dir / f"{key}.glb"

        if not path.is_file():
            raise FileNotFoundError(f"Falta el archivo: {path}")

        canonical_action = CANONICAL_ACTIONS.get(
            key,
            "".join(part.capitalize() for part in key.split("_")),
        )

        result.append(
            {
                "key": key,
                "path": str(path.resolve()),
                "canonical_action": canonical_action,
            }
        )

    return result


def run_controller(args: argparse.Namespace) -> int:
    root = (
        Path(args.project_root).resolve()
        if args.project_root
        else get_project_root()
    )

    character_dir = root / "pipeline" / "characters" / args.character

    if not character_dir.is_dir():
        raise FileNotFoundError(
            f"No existe la carpeta del personaje: {character_dir}"
        )

    sources = discover_sources(character_dir, args.sources)

    work_dir = character_dir / "work"
    report_dir = character_dir / "reports"

    work_dir.mkdir(parents=True, exist_ok=True)
    report_dir.mkdir(parents=True, exist_ok=True)

    output_glb = character_dir / f"{args.character}_master.glb"
    output_blend = work_dir / f"{args.character}_master.blend"
    output_report = report_dir / "assemble_character_glb.json"

    blender = Path(args.blender) if args.blender else get_default_blender()
    script_path = Path(__file__).resolve()

    command = [
        str(blender),
        "--background",
        "--factory-startup",
        "--python",
        str(script_path),
        "--",
        "--worker",
        "--character",
        args.character,
        "--sources-json",
        json.dumps(sources),
        "--output",
        str(output_glb),
        "--blend-output",
        str(output_blend),
        "--report",
        str(output_report),
        "--rest-tolerance",
        str(args.rest_tolerance),
    ]

    if args.skip_verify:
        command.append("--skip-verify")

    print()
    print("=== MAGIC SYMBOLS CHARACTER ASSEMBLER ===")
    print(f"Character : {args.character}")
    print(f"Blender   : {blender}")
    print("Sources:")

    for source in sources:
        print(
            f"  {source['key']}.glb -> {source['canonical_action']}"
        )

    print(f"Output    : {output_glb}")
    print()

    result = subprocess.run(command, check=False)

    if result.returncode != 0:
        print(
            f"ASSEMBLE FAIL (Blender exit code {result.returncode})",
            file=sys.stderr,
        )
        return result.returncode

    print()
    print("ASSEMBLE PASS")
    print(f"GLB    : {output_glb}")
    print(f"Blend  : {output_blend}")
    print(f"Report : {output_report}")

    return 0


def clear_scene(bpy) -> None:
    if bpy.context.mode != "OBJECT":
        try:
            bpy.ops.object.mode_set(mode="OBJECT")
        except RuntimeError:
            pass

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)


def import_glb(bpy, path: Path) -> list:
    before = {obj.as_pointer() for obj in bpy.data.objects}

    result = bpy.ops.import_scene.gltf(filepath=str(path))

    if "FINISHED" not in result:
        raise RuntimeError(f"No se pudo importar {path}")

    imported = [
        obj
        for obj in bpy.data.objects
        if obj.as_pointer() not in before
    ]

    if not imported:
        raise RuntimeError(f"{path} no importó objetos.")

    return imported


def get_single_armature(objects: list, label: str):
    armatures = [obj for obj in objects if obj.type == "ARMATURE"]

    if len(armatures) != 1:
        raise RuntimeError(
            f"{label}: esperaba 1 Armature y encontré "
            f"{len(armatures)}: {[obj.name for obj in armatures]}"
        )

    return armatures[0]


def get_bound_meshes(objects: list, armature) -> list:
    meshes = []

    for obj in objects:
        if obj.type != "MESH":
            continue

        linked = obj.parent == armature

        if not linked:
            linked = any(
                modifier.type == "ARMATURE"
                and modifier.object == armature
                for modifier in obj.modifiers
            )

        if linked:
            meshes.append(obj)

    return meshes


def collect_armature_actions(armature) -> list:
    data = armature.animation_data

    if data is None:
        return []

    result = []
    seen = set()

    if data.action is not None:
        result.append(data.action)
        seen.add(data.action.as_pointer())

    for track in data.nla_tracks:
        for strip in track.strips:
            action = strip.action

            if action is None:
                continue

            pointer = action.as_pointer()

            if pointer not in seen:
                seen.add(pointer)
                result.append(action)

    return result


def choose_source_action(armature, source_key: str):
    actions = collect_armature_actions(armature)

    if len(actions) == 1:
        return actions[0]

    matching = [
        action
        for action in actions
        if source_key.lower() in action.name.lower()
    ]

    if len(matching) == 1:
        return matching[0]

    # Varias Actions (p. ej. 'X' y 'X.001'): se elige la de mayor rango de frames
    # (empate: la de nombre sin sufijo .NNN) en lugar de fallar.
    def _span(a):
        fr = getattr(a, "frame_range", None)
        return (float(fr[1]) - float(fr[0])) if fr else 0.0

    best = sorted(
        actions,
        key=lambda a: (-_span(a), bool(re.search(r"\.\d+$", a.name)), a.name),
    )
    if best:
        print(
            f"[assemble] AVISO {source_key}: varias Actions "
            f"{[a.name for a in actions]}; se usa '{best[0].name}'"
        )
        return best[0]

    raise RuntimeError(
        f"{source_key}: esperaba una única Action. "
        f"Encontradas: {[action.name for action in actions]}"
    )


def skeleton_signature(armature) -> dict:
    result = {}

    for bone in armature.data.bones:
        result[bone.name] = {
            "parent": bone.parent.name if bone.parent else None,
            "matrix": tuple(
                float(value)
                for row in bone.matrix_local
                for value in row
            ),
        }

    return result


def validate_required_bones(signature: dict, source_key: str) -> None:
    missing = [
        bone_name
        for bone_name in REQUIRED_BONES
        if bone_name not in signature
    ]

    if missing:
        raise RuntimeError(
            f"{source_key}: faltan huesos requeridos: {missing}"
        )


def compare_skeletons(
    master: dict,
    candidate: dict,
    source_key: str,
    tolerance: float,
) -> list[str]:
    master_names = set(master)
    candidate_names = set(candidate)

    if master_names != candidate_names:
        missing = sorted(master_names - candidate_names)
        extra = sorted(candidate_names - master_names)

        raise RuntimeError(
            f"{source_key}: skeleton incompatible. "
            f"Missing={missing}, Extra={extra}"
        )

    warnings = []

    for bone_name in sorted(master_names):
        if master[bone_name]["parent"] != candidate[bone_name]["parent"]:
            raise RuntimeError(
                f"{source_key}: parent distinto en {bone_name}: "
                f"{master[bone_name]['parent']} != "
                f"{candidate[bone_name]['parent']}"
            )

        delta = max(
            abs(a - b)
            for a, b in zip(
                master[bone_name]["matrix"],
                candidate[bone_name]["matrix"],
            )
        )

        if delta > tolerance:
            warnings.append(
                f"{bone_name}: rest matrix delta={delta:.6g}"
            )

    return warnings


def assign_action_compat(armature, action) -> None:
    data = armature.animation_data

    if data is None:
        data = armature.animation_data_create()

    data.action = action

    slots = getattr(action, "slots", None)

    if slots and hasattr(data, "action_slot"):
        slot = next(
            (
                candidate
                for candidate in slots
                if getattr(candidate, "target_id_type", "") == "OBJECT"
            ),
            slots[0],
        )

        try:
            data.action_slot = slot
        except Exception as exc:
            print(
                "[assemble] WARN ActionSlot:",
                armature.name,
                action.name,
                exc,
            )


def configure_source_action(armature, action) -> None:
    data = armature.animation_data

    if data is None:
        data = armature.animation_data_create()

    for track in data.nla_tracks:
        track.mute = True

    assign_action_compat(
        armature,
        action,
    )


def clear_master_animation(armature) -> None:
    data = armature.animation_data

    if data is None:
        data = armature.animation_data_create()

    data.action = None

    for track in list(data.nla_tracks):
        data.nla_tracks.remove(track)


def duplicate_base_armature(bpy, armature, action):
    duplicate = armature.copy()
    duplicate.data = armature.data.copy()
    duplicate.name = "__BASE_ANIMATION_SOURCE__"

    bpy.context.collection.objects.link(duplicate)

    duplicate.animation_data_clear()
    duplicate.animation_data_create()

    assign_action_compat(
        duplicate,
        action,
    )

    bpy.context.view_layer.update()

    return duplicate


def pose_signature(armature) -> tuple[float, ...]:
    values = []

    for bone in armature.pose.bones:
        for row in bone.matrix:
            values.extend(float(value) for value in row)

    return tuple(values)


def pose_variation_for_action(
    bpy,
    armature,
    action,
) -> float:
    configure_source_action(
        armature,
        action,
    )

    start = float(action.frame_range[0])
    end = float(action.frame_range[1])

    frames = [
        start,
        start + (end - start) * 0.25,
        start + (end - start) * 0.50,
        start + (end - start) * 0.75,
    ]

    signatures = []

    for frame in frames:
        whole = math.floor(frame)

        bpy.context.scene.frame_set(
            int(whole),
            subframe=float(frame - whole),
        )

        bpy.context.view_layer.update()

        signatures.append(
            pose_signature(armature)
        )

    baseline = signatures[0]
    max_delta = 0.0

    for signature in signatures[1:]:
        max_delta = max(
            max_delta,
            max(
                abs(a - b)
                for a, b in zip(
                    baseline,
                    signature,
                )
            ),
        )

    return max_delta


def bake_action(
    bpy,
    source_armature,
    master_armature,
    source_action,
    canonical_name: str,
):
    configure_source_action(source_armature, source_action)

    new_action = bpy.data.actions.new(name=canonical_name)
    new_action.use_fake_user = True

    master_data = master_armature.animation_data

    if master_data is None:
        master_data = master_armature.animation_data_create()

    master_data.action = new_action

    start_frame = int(math.floor(source_action.frame_range[0]))
    end_frame = int(math.ceil(source_action.frame_range[1]))

    scene = bpy.context.scene

    for frame in range(start_frame, end_frame + 1):
        scene.frame_set(frame)
        bpy.context.view_layer.update()

        for source_bone in source_armature.pose.bones:
            target_bone = master_armature.pose.bones.get(source_bone.name)

            if target_bone is None:
                continue

            target_bone.rotation_mode = source_bone.rotation_mode
            target_bone.matrix_basis = source_bone.matrix_basis.copy()

            target_bone.keyframe_insert(
                data_path="location",
                frame=frame,
                group=source_bone.name,
            )

            if target_bone.rotation_mode == "QUATERNION":
                target_bone.keyframe_insert(
                    data_path="rotation_quaternion",
                    frame=frame,
                    group=source_bone.name,
                )
            elif target_bone.rotation_mode == "AXIS_ANGLE":
                target_bone.keyframe_insert(
                    data_path="rotation_axis_angle",
                    frame=frame,
                    group=source_bone.name,
                )
            else:
                target_bone.keyframe_insert(
                    data_path="rotation_euler",
                    frame=frame,
                    group=source_bone.name,
                )

            target_bone.keyframe_insert(
                data_path="scale",
                frame=frame,
                group=source_bone.name,
            )

    master_data.action = None

    return new_action


def delete_objects(bpy, objects: list) -> None:
    bpy.ops.object.select_all(action="DESELECT")

    for obj in objects:
        if obj.name in bpy.data.objects:
            obj.select_set(True)

    bpy.ops.object.delete(use_global=False)


def remove_action_data(bpy, action) -> None:
    if action is None:
        return

    if action.name in bpy.data.actions:
        bpy.data.actions.remove(
            action,
            do_unlink=True,
        )


def purge_non_master_actions(bpy, keep_actions: list) -> None:
    keep_pointers = {
        action.as_pointer()
        for action in keep_actions
    }

    for action in list(bpy.data.actions):
        if action.as_pointer() not in keep_pointers:
            bpy.data.actions.remove(
                action,
                do_unlink=True,
            )


def get_export_properties(bpy) -> set[str]:
    return {
        prop.identifier
        for prop in bpy.ops.export_scene.gltf.get_rna_type().properties
    }


def exporter_supports_enum(
    bpy,
    property_name: str,
    enum_name: str,
) -> bool:
    try:
        prop = (
            bpy.ops.export_scene.gltf
            .get_rna_type()
            .properties[property_name]
        )

        return enum_name in {
            item.identifier for item in prop.enum_items
        }
    except Exception:
        return False


def export_master_glb(
    bpy,
    output: Path,
    armature,
    meshes: list,
) -> None:
    bpy.ops.object.select_all(action="DESELECT")

    armature.select_set(True)

    for mesh in meshes:
        mesh.select_set(True)

    bpy.context.view_layer.objects.active = armature

    kwargs = {
        "filepath": str(output),
        "export_format": "GLB",
        "use_selection": True,
        "check_existing": False,
        "export_cameras": False,
        "export_lights": False,
        "export_materials": "EXPORT",
        "export_yup": True,
        "export_animations": True,
        "export_force_sampling": True,
        "export_frame_range": False,
        "export_anim_slide_to_zero": True,
        "export_skins": True,
        "export_current_frame": False,
        "export_apply": False,
    }

    if exporter_supports_enum(
        bpy,
        "export_animation_mode",
        "ACTIONS",
    ):
        kwargs["export_animation_mode"] = "ACTIONS"

    valid_properties = get_export_properties(bpy)

    kwargs = {
        key: value
        for key, value in kwargs.items()
        if key in valid_properties
    }

    result = bpy.ops.export_scene.gltf(**kwargs)

    if "FINISHED" not in result:
        raise RuntimeError("Falló la exportación GLB.")


def verify_export(
    bpy,
    output: Path,
    expected_actions: list[str],
) -> dict:
    clear_scene(bpy)

    objects = import_glb(bpy, output)
    armature = get_single_armature(objects, "verification")

    actions = collect_armature_actions(armature)

    action_names = sorted(
        {action.name for action in actions}
    )

    missing = [
        action_name
        for action_name in expected_actions
        if action_name not in action_names
    ]

    if missing:
        raise RuntimeError(
            "El GLB final no contiene todas las animaciones. "
            f"Missing={missing}. Found={action_names}"
        )

    return {
        "armature": armature.name,
        "bone_count": len(armature.data.bones),
        "mesh_count": len(get_bound_meshes(objects, armature)),
        "actions": action_names,
    }


def run_worker(args: argparse.Namespace) -> int:
    import bpy

    sources = json.loads(args.sources_json)
    output = Path(args.output).resolve()
    blend_output = Path(args.blend_output).resolve()
    report_path = Path(args.report).resolve()

    report = {
        "schema_version": "1.0",
        "character": args.character,
        "status": "running",
        "sources": [],
        "warnings": [],
        "output": str(output),
    }

    try:
        clear_scene(bpy)

        base = sources[0]

        base_objects = import_glb(
            bpy,
            Path(base["path"]),
        )

        master_armature = get_single_armature(
            base_objects,
            base["key"],
        )

        master_meshes = get_bound_meshes(
            base_objects,
            master_armature,
        )

        if not master_meshes:
            raise RuntimeError(
                "idle.glb no tiene Mesh ligada al Armature."
            )

        master_signature = skeleton_signature(master_armature)

        validate_required_bones(
            master_signature,
            base["key"],
        )

        base_source_action = choose_source_action(
            master_armature,
            base["key"],
        )

        base_original_name = base_source_action.name

        base_source_armature = duplicate_base_armature(
            bpy,
            master_armature,
            base_source_action,
        )

        clear_master_animation(master_armature)

        base_source_action.name = f"__SOURCE__{base_original_name}"

        baked_actions = []

        source_idle_delta = pose_variation_for_action(
            bpy,
            base_source_armature,
            base_source_action,
        )

        print(
            "[assemble] Source pose delta:",
            base["key"],
            f"{source_idle_delta:.8f}",
        )

        if source_idle_delta <= 1e-5:
            raise RuntimeError(
                "La animación source/idle.glb no produce cambios de pose detectables."
            )

        idle_action = bake_action(
            bpy,
            base_source_armature,
            master_armature,
            base_source_action,
            base["canonical_action"],
        )

        baked_idle_delta = pose_variation_for_action(
            bpy,
            master_armature,
            idle_action,
        )

        print(
            "[assemble] Baked pose delta:",
            base["canonical_action"],
            f"{baked_idle_delta:.8f}",
        )

        if baked_idle_delta <= 1e-5:
            raise RuntimeError(
                "El bake de Idle quedó estático; se aborta el master GLB."
            )

        baked_actions.append(idle_action)

        delete_objects(
            bpy,
            [base_source_armature],
        )

        remove_action_data(
            bpy,
            base_source_action,
        )

        report["sources"].append(
            {
                "key": base["key"],
                "file": base["path"],
                "source_action": base_original_name,
                "canonical_action": idle_action.name,
                "bone_count": len(master_signature),
            }
        )

        for source in sources[1:]:
            imported_objects = import_glb(
                bpy,
                Path(source["path"]),
            )

            source_armature = get_single_armature(
                imported_objects,
                source["key"],
            )

            source_signature = skeleton_signature(source_armature)

            validate_required_bones(
                source_signature,
                source["key"],
            )

            warnings = compare_skeletons(
                master_signature,
                source_signature,
                source["key"],
                args.rest_tolerance,
            )

            report["warnings"].extend(
                f"{source['key']}: {warning}"
                for warning in warnings
            )

            source_action = choose_source_action(
                source_armature,
                source["key"],
            )

            original_name = source_action.name

            source_action.name = (
                f"__SOURCE__{source['key']}__{original_name}"
            )

            source_pose_delta = pose_variation_for_action(
                bpy,
                source_armature,
                source_action,
            )

            print(
                "[assemble] Source pose delta:",
                source["key"],
                f"{source_pose_delta:.8f}",
            )

            if source_pose_delta <= 1e-5:
                raise RuntimeError(
                    f"La animación source/{source['key']}.glb "
                    "no produce cambios de pose detectables."
                )

            baked_action = bake_action(
                bpy,
                source_armature,
                master_armature,
                source_action,
                source["canonical_action"],
            )

            baked_pose_delta = pose_variation_for_action(
                bpy,
                master_armature,
                baked_action,
            )

            print(
                "[assemble] Baked pose delta:",
                source["canonical_action"],
                f"{baked_pose_delta:.8f}",
            )

            if baked_pose_delta <= 1e-5:
                raise RuntimeError(
                    f"El bake de {source['canonical_action']} quedó estático; "
                    "se aborta el master GLB."
                )

            baked_actions.append(baked_action)

            report["sources"].append(
                {
                    "key": source["key"],
                    "file": source["path"],
                    "source_action": original_name,
                    "canonical_action": baked_action.name,
                    "bone_count": len(source_signature),
                    "rest_matrix_warnings": warnings,
                }
            )

            delete_objects(
                bpy,
                imported_objects,
            )

            remove_action_data(
                bpy,
                source_action,
            )

        master_armature.name = f"{args.character}_Armature"
        master_armature.data.name = f"{args.character}_ArmatureData"

        for index, mesh in enumerate(master_meshes):
            mesh.name = (
                f"{args.character}_Mesh"
                if len(master_meshes) == 1
                else f"{args.character}_Mesh_{index:02d}"
            )

        purge_non_master_actions(
            bpy,
            baked_actions,
        )

        master_animation = master_armature.animation_data

        if master_animation is None:
            master_animation = master_armature.animation_data_create()

        master_animation.action = baked_actions[0]

        blend_output.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        bpy.ops.wm.save_as_mainfile(
            filepath=str(blend_output)
        )

        output.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        export_master_glb(
            bpy,
            output,
            master_armature,
            master_meshes,
        )

        expected_actions = [
            action.name
            for action in baked_actions
        ]

        report["master"] = {
            "armature": master_armature.name,
            "bone_count": len(master_signature),
            "mesh_count": len(master_meshes),
            "actions": expected_actions,
        }

        if not args.skip_verify:
            report["verification"] = verify_export(
                bpy,
                output,
                expected_actions,
            )

        report["status"] = "pass"

    except Exception as exc:
        report["status"] = "fail"
        report["error"] = f"{type(exc).__name__}: {exc}"

        report_path.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        report_path.write_text(
            json.dumps(
                report,
                indent=2,
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )

        raise

    report_path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    report_path.write_text(
        json.dumps(
            report,
            indent=2,
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )

    print(
        "[worker] PASS: "
        + ", ".join(report["master"]["actions"])
    )

    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Magic Symbols - Assemble character GLBs."
        )
    )

    parser.add_argument(
        "character",
        nargs="?",
    )

    parser.add_argument(
        "--character",
        dest="worker_character",
        help=argparse.SUPPRESS,
    )

    parser.add_argument(
        "--project-root",
    )

    parser.add_argument(
        "--blender",
    )

    parser.add_argument(
        "--sources",
        nargs="+",
        help="Ejemplo: --sources idle walk run",
    )

    parser.add_argument(
        "--rest-tolerance",
        type=float,
        default=1e-4,
    )

    parser.add_argument(
        "--skip-verify",
        action="store_true",
    )

    parser.add_argument(
        "--worker",
        action="store_true",
        help=argparse.SUPPRESS,
    )

    parser.add_argument(
        "--sources-json",
        help=argparse.SUPPRESS,
    )

    parser.add_argument(
        "--output",
        help=argparse.SUPPRESS,
    )

    parser.add_argument(
        "--blend-output",
        help=argparse.SUPPRESS,
    )

    parser.add_argument(
        "--report",
        help=argparse.SUPPRESS,
    )

    return parser


def main() -> int:
    argv = sys.argv[1:]

    if "--" in argv:
        argv = argv[argv.index("--") + 1:]

    args = build_parser().parse_args(argv)

    if args.worker and args.worker_character:
        args.character = args.worker_character

    if not args.character:
        raise RuntimeError("Falta character id.")

    if args.worker:
        required = (
            "sources_json",
            "output",
            "blend_output",
            "report",
        )

        missing = [
            field
            for field in required
            if not getattr(args, field)
        ]

        if missing:
            raise RuntimeError(
                f"Worker args incompletos: {missing}"
            )

        return run_worker(args)

    return run_controller(args)


if __name__ == "__main__":
    try:
        raise SystemExit(main())

    except KeyboardInterrupt:
        raise SystemExit(130)

    except Exception as exc:
        print(
            f"[assemble] ERROR: "
            f"{type(exc).__name__}: {exc}",
            file=sys.stderr,
        )

        raise SystemExit(1)
