from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any

try:
    import jsonschema
except ImportError:
    jsonschema = None


EXIT_VALID = 0
EXIT_INVALID_CONFIG = 2
EXIT_IO_ERROR = 3
EXIT_DEPENDENCY_ERROR = 4


def load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        raise RuntimeError(f"No existe el archivo: {path}")
    except json.JSONDecodeError as exc:
        raise RuntimeError(
            f"JSON inválido en {path}: línea {exc.lineno}, columna {exc.colno}: {exc.msg}"
        )
    except OSError as exc:
        raise RuntimeError(f"No se pudo leer {path}: {exc}")

    if not isinstance(data, dict):
        raise RuntimeError(f"El JSON raíz debe ser un objeto: {path}")

    return data


def print_pass(label: str) -> None:
    print(f"PASS {label}")


def print_fail(label: str, details: str) -> None:
    print(f"FAIL {label}: {details}")


def validate_schema(
    config: dict[str, Any],
    schema: dict[str, Any],
) -> list[str]:
    if jsonschema is None:
        return [
            "Falta la dependencia 'jsonschema'. Instala con: py -m pip install jsonschema"
        ]

    errors: list[str] = []
    validator_cls = jsonschema.validators.validator_for(schema)
    validator_cls.check_schema(schema)
    validator = validator_cls(schema)

    sorted_errors = sorted(
        validator.iter_errors(config),
        key=lambda e: list(e.absolute_path),
    )

    for error in sorted_errors:
        path = ".".join(str(x) for x in error.absolute_path)
        location = path if path else "<root>"
        errors.append(f"{location}: {error.message}")

    return errors


def validate_semantics(config: dict[str, Any]) -> list[str]:
    errors: list[str] = []

    render = config["render"]
    atlas = config["atlas"]
    godot = config["godot"]
    validation = config["validation"]
    animations = config["animations"]
    model = config["model"]
    output = config["output"]

    frame_w, frame_h = render["frame_size_px"]
    anchor_x, anchor_y = render["ground_anchor_px"]

    if not (0 <= anchor_x < frame_w):
        errors.append(
            f"render.ground_anchor_px[0]={anchor_x} queda fuera del frame width={frame_w}"
        )

    if not (0 <= anchor_y < frame_h):
        errors.append(
            f"render.ground_anchor_px[1]={anchor_y} queda fuera del frame height={frame_h}"
        )

    offset_x, offset_y = godot["visual_offset_px"]
    expected_offset_x = frame_w // 2 - anchor_x
    expected_offset_y = frame_h // 2 - anchor_y

    if (offset_x, offset_y) != (expected_offset_x, expected_offset_y):
        errors.append(
            "godot.visual_offset_px no coincide con el anchor. "
            f"Esperado [{expected_offset_x}, {expected_offset_y}], "
            f"recibido [{offset_x}, {offset_y}]"
        )

    directions = render["directions"]
    direction_ids = [entry["id"] for entry in directions]

    if len(direction_ids) != len(set(direction_ids)):
        errors.append("render.directions contiene IDs duplicados")

    rotations = [float(entry["rotation_deg"]) % 360.0 for entry in directions]
    rounded_rotations = [round(value, 6) for value in rotations]

    if len(rounded_rotations) != len(set(rounded_rotations)):
        errors.append("render.directions contiene rotaciones duplicadas")

    required_dirs = validation["required_directions"]

    if set(direction_ids) != set(required_dirs):
        errors.append(
            "validation.required_directions no coincide con render.directions"
        )

    atlas_order = atlas["layout"]["direction_order"]

    if set(atlas_order) != set(direction_ids):
        errors.append(
            "atlas.layout.direction_order no contiene exactamente las mismas direcciones "
            "que render.directions"
        )

    if len(atlas_order) != len(set(atlas_order)):
        errors.append("atlas.layout.direction_order contiene direcciones duplicadas")

    mapping = godot["direction_mapping"]

    if set(mapping.keys()) != set(direction_ids):
        errors.append(
            "godot.direction_mapping debe definir exactamente una entrada por dirección lógica"
        )

    invalid_mapping_values = [
        value
        for value in mapping.values()
        if value not in direction_ids
    ]

    if invalid_mapping_values:
        errors.append(
            "godot.direction_mapping contiene destinos inválidos: "
            + ", ".join(sorted(set(invalid_mapping_values)))
        )

    max_texture_size = atlas["max_texture_size_px"]

    if frame_w > max_texture_size:
        errors.append(
            f"frame width {frame_w} supera atlas.max_texture_size_px={max_texture_size}"
        )

    total_rows_height = frame_h * len(atlas_order)

    if total_rows_height > max_texture_size:
        errors.append(
            "La altura completa del atlas supera el máximo configurado: "
            f"{frame_h} × {len(atlas_order)} = {total_rows_height} > {max_texture_size}"
        )

    max_columns = max_texture_size // frame_w

    if max_columns < 1:
        errors.append(
            "atlas.max_texture_size_px no permite ni una columna de frames"
        )

    for animation_id, animation in animations.items():
        fps = float(animation["output_fps"])
        frame_count = int(animation["frame_count"])
        source_action = str(animation["source_action"]).strip()
        atlas_basename = str(animation["atlas_basename"]).strip()

        if not math.isfinite(fps) or fps <= 0:
            errors.append(
                f"animations.{animation_id}.output_fps debe ser > 0"
            )

        if frame_count <= 0:
            errors.append(
                f"animations.{animation_id}.frame_count debe ser > 0"
            )

        if not source_action:
            errors.append(
                f"animations.{animation_id}.source_action está vacío"
            )

        if not atlas_basename:
            errors.append(
                f"animations.{animation_id}.atlas_basename está vacío"
            )

        timing = animation["timing"]
        timing_mode = timing["mode"]

        if timing_mode == "custom":
            timing_fps = float(timing["playback_fps"])
            timing_frames = int(timing["frame_count"])

            if not math.isclose(
                timing_fps,
                fps,
                rel_tol=0.0,
                abs_tol=1e-9,
            ):
                errors.append(
                    f"animations.{animation_id}.timing.playback_fps "
                    f"({timing_fps}) no coincide con output_fps ({fps})"
                )

            if timing_frames != frame_count:
                errors.append(
                    f"animations.{animation_id}.timing.frame_count "
                    f"({timing_frames}) no coincide con frame_count ({frame_count})"
                )

        if (
            animation["expect_in_place"]
            and float(animation["root_motion_tolerance"]) <= 0.0
        ):
            errors.append(
                f"animations.{animation_id}.root_motion_tolerance "
                "debe ser > 0 cuando expect_in_place=true"
            )

        if animation["enabled"] and max_columns > 0:
            required_parts = math.ceil(frame_count / max_columns)

            if required_parts < 1:
                errors.append(
                    f"animations.{animation_id}: cálculo inválido de partes de atlas"
                )

    required_bones = model["rig"]["required_bones"]
    if len(required_bones) != len(set(required_bones)):
        errors.append("model.rig.required_bones contiene huesos duplicados")

    left_bone = model["rig"]["ground_reference"]["left_bone"]
    right_bone = model["rig"]["ground_reference"]["right_bone"]

    if left_bone == right_bone:
        errors.append(
            "model.rig.ground_reference debe usar dos huesos distintos"
        )

    for bone_name in (left_bone, right_bone):
        if bone_name not in required_bones:
            errors.append(
                f"El hueso de ground_reference '{bone_name}' "
                "también debe aparecer en model.rig.required_bones"
            )

    output_values = list(output.values())
    if len(output_values) != len(set(output_values)):
        errors.append("output contiene rutas duplicadas")

    for key, value in output.items():
        if Path(value).is_absolute():
            errors.append(
                f"output.{key} debe ser una ruta relativa y portable, no absoluta: {value}"
            )

    source_model = config["character"]["source_model"]
    if Path(source_model).is_absolute():
        errors.append(
            "character.source_model debe ser una ruta relativa para mantener el manifest portable"
        )

    return errors


def summarize_config(config: dict[str, Any]) -> None:
    render = config["render"]
    atlas = config["atlas"]
    animations = config["animations"]

    frame_w, frame_h = render["frame_size_px"]
    max_texture = atlas["max_texture_size_px"]
    max_columns = max_texture // frame_w

    print()
    print("SUMMARY")
    print(f"  character: {config['character']['id']}")
    print(f"  frame: {frame_w}x{frame_h}")
    print(f"  directions: {len(render['directions'])}")
    print(f"  ortho_scale: {render['ortho_scale']}")
    print(f"  ground_anchor: {render['ground_anchor_px']}")
    print(f"  atlas_max: {max_texture}px")
    print(f"  max_columns_per_atlas: {max_columns}")

    for animation_id, animation in animations.items():
        if not animation["enabled"]:
            state = "disabled"
            parts = 0
        else:
            state = "enabled"
            parts = math.ceil(animation["frame_count"] / max_columns)

        timing = animation["timing"]
        timing_desc = timing["mode"]

        if timing["mode"] == "custom":
            timing_desc += (
                f" {timing['frame_count']} frames "
                f"@ {timing['playback_fps']} FPS"
            )

        print(
            f"  animation {animation_id}: "
            f"{animation['frame_count']} frames @ {animation['output_fps']} FPS "
            f"({state}, timing={timing_desc}, "
            f"in_place={animation['expect_in_place']}, "
            f"estimated atlas parts={parts})"
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate a Magic Symbols character pipeline manifest."
    )

    parser.add_argument(
        "character_json",
        type=Path,
        help="Path to character.json",
    )

    parser.add_argument(
        "--schema",
        type=Path,
        default=None,
        help=(
            "Path to character.schema.json. "
            "Defaults to a file with that name next to character.json."
        ),
    )

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    character_path = args.character_json.resolve()
    schema_path = (
        args.schema.resolve()
        if args.schema is not None
        else character_path.with_name("character.schema.json")
    )

    print("Magic Symbols Pipeline v1 — Config Validator")
    print(f"Character: {character_path}")
    print(f"Schema:    {schema_path}")
    print()

    try:
        config = load_json(character_path)
        schema = load_json(schema_path)
    except RuntimeError as exc:
        print_fail("IO", str(exc))
        return EXIT_IO_ERROR

    if jsonschema is None:
        print_fail(
            "dependency",
            "Falta 'jsonschema'. Ejecuta: py -m pip install jsonschema",
        )
        return EXIT_DEPENDENCY_ERROR

    try:
        schema_errors = validate_schema(config, schema)
    except Exception as exc:
        print_fail("schema engine", str(exc))
        return EXIT_INVALID_CONFIG

    if schema_errors:
        print_fail("schema", f"{len(schema_errors)} error(es)")
        for item in schema_errors:
            print(f"  - {item}")
        return EXIT_INVALID_CONFIG

    print_pass("schema")

    semantic_errors = validate_semantics(config)

    if semantic_errors:
        print_fail("semantic validation", f"{len(semantic_errors)} error(es)")
        for item in semantic_errors:
            print(f"  - {item}")
        return EXIT_INVALID_CONFIG

    print_pass("render config")
    print_pass("directions")
    print_pass("animations")
    print_pass("atlas")
    print_pass("godot mapping")
    print_pass("validation rules")

    summarize_config(config)

    print()
    print("CONFIG VALID")
    return EXIT_VALID


if __name__ == "__main__":
    sys.exit(main())
