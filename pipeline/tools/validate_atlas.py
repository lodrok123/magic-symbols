from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops


EXIT_VALID = 0
EXIT_INVALID = 2
EXIT_INPUT_ERROR = 3


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Validate Magic Symbols sprite atlases against "
            "character.json, renderer metadata, and source PNG frames."
        )
    )

    parser.add_argument(
        "--character-json",
        required=True,
        type=Path,
        help="Path to character.json",
    )

    parser.add_argument(
        "--animation",
        required=True,
        help="Animation ID in character.json, e.g. walk or idle",
    )

    parser.add_argument(
        "--render-dir",
        required=True,
        type=Path,
        help="Generic renderer output directory for this animation",
    )

    parser.add_argument(
        "--atlas-dir",
        required=True,
        type=Path,
        help="Atlas output directory produced by build_atlas.py",
    )

    parser.add_argument(
        "--report",
        type=Path,
        default=None,
        help="Optional validation report path",
    )

    return parser.parse_args()


def resolve_project_path(path: Path) -> Path:
    if path.is_absolute():
        return path.resolve()
    return (Path.cwd() / path).resolve()


def load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as file:
            data = json.load(file)
    except FileNotFoundError as exc:
        raise RuntimeError(f"No existe: {path}") from exc
    except json.JSONDecodeError as exc:
        raise RuntimeError(
            f"JSON inválido en {path}, línea {exc.lineno}, "
            f"columna {exc.colno}: {exc.msg}"
        ) from exc

    if not isinstance(data, dict):
        raise RuntimeError(
            f"El JSON raíz debe ser un objeto: {path}"
        )

    return data


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as file:
        for chunk in iter(
            lambda: file.read(1024 * 1024),
            b"",
        ):
            digest.update(chunk)

    return digest.hexdigest()


def render_metadata_path(
    render_dir: Path,
    animation_id: str,
) -> Path:
    exact = (
        render_dir
        / f"{animation_id}_render_metadata.json"
    )

    if exact.exists():
        return exact

    candidates = sorted(
        render_dir.glob("*_render_metadata.json")
    )

    if len(candidates) == 1:
        return candidates[0]

    if not candidates:
        raise RuntimeError(
            f"No se encontró render metadata en {render_dir}"
        )

    raise RuntimeError(
        "Hay varios *_render_metadata.json: "
        + ", ".join(path.name for path in candidates)
    )


def atlas_metadata_path(
    atlas_dir: Path,
    basename: str,
) -> Path:
    exact = (
        atlas_dir
        / f"{basename}_metadata.json"
    )

    if exact.exists():
        return exact

    candidates = sorted(
        atlas_dir.glob("*_metadata.json")
    )

    if len(candidates) == 1:
        return candidates[0]

    if not candidates:
        raise RuntimeError(
            f"No se encontró atlas metadata en {atlas_dir}"
        )

    raise RuntimeError(
        "Hay varios *_metadata.json: "
        + ", ".join(path.name for path in candidates)
    )


def images_equal(
    first: Image.Image,
    second: Image.Image,
) -> bool:
    if first.size != second.size:
        return False

    a = first.convert("RGBA")
    b = second.convert("RGBA")

    return ImageChops.difference(
        a,
        b,
    ).getbbox() is None


def calculate_expected_layout(
    frame_size: tuple[int, int],
    direction_count: int,
    frame_count: int,
    max_texture_size: int,
) -> dict[str, int]:
    frame_w, frame_h = frame_size

    atlas_height = (
        frame_h * direction_count
    )

    if atlas_height > max_texture_size:
        raise RuntimeError(
            "Las filas no caben en max_texture_size"
        )

    columns_per_part = (
        max_texture_size // frame_w
    )

    if columns_per_part < 1:
        raise RuntimeError(
            "Un frame no cabe horizontalmente"
        )

    part_count = math.ceil(
        frame_count / columns_per_part
    )

    return {
        "atlas_height": atlas_height,
        "columns_per_part": columns_per_part,
        "part_count": part_count,
    }


def validate_atlas(
    config: dict[str, Any],
    animation_id: str,
    render_dir: Path,
    atlas_dir: Path,
    render_metadata: dict[str, Any],
    atlas_metadata: dict[str, Any],
) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []

    animation_cfg = config["animations"][animation_id]
    render_cfg = config["render"]
    atlas_cfg = config["atlas"]

    character_id = str(
        config["character"]["id"]
    )

    directions = list(
        atlas_cfg["layout"]["direction_order"]
    )

    frame_w, frame_h = map(
        int,
        render_cfg["frame_size_px"],
    )

    frame_count = int(
        render_metadata.get(
            "frame_count_per_direction",
            0,
        )
    )

    if frame_count < 1:
        errors.append(
            "render metadata tiene frame_count_per_direction inválido"
        )

    expected_layout = calculate_expected_layout(
        frame_size=(frame_w, frame_h),
        direction_count=len(directions),
        frame_count=frame_count,
        max_texture_size=int(
            atlas_cfg["max_texture_size_px"]
        ),
    )

    if (
        atlas_metadata.get("character_id")
        != character_id
    ):
        errors.append(
            "character_id del atlas metadata no coincide"
        )

    if (
        atlas_metadata.get("animation_id")
        != animation_id
    ):
        errors.append(
            "animation_id del atlas metadata no coincide"
        )

    if (
        atlas_metadata.get("source_action")
        != animation_cfg["source_action"]
    ):
        errors.append(
            "source_action del atlas metadata no coincide"
        )

    if (
        atlas_metadata.get("frame_size_px")
        != [frame_w, frame_h]
    ):
        errors.append(
            "frame_size_px del atlas metadata no coincide"
        )

    if (
        int(
            atlas_metadata.get(
                "frames_per_direction",
                -1,
            )
        )
        != frame_count
    ):
        errors.append(
            "frames_per_direction del atlas metadata no coincide"
        )

    if (
        atlas_metadata.get("direction_order")
        != directions
    ):
        errors.append(
            "direction_order del atlas metadata no coincide exactamente"
        )

    if (
        atlas_metadata.get("ground_anchor_px")
        != render_cfg["ground_anchor_px"]
    ):
        errors.append(
            "ground_anchor_px del atlas metadata no coincide"
        )

    atlas_layout = atlas_metadata.get(
        "layout",
        {},
    )

    expected_part_count = int(
        expected_layout["part_count"]
    )

    expected_columns_per_part = int(
        expected_layout["columns_per_part"]
    )

    if (
        int(
            atlas_layout.get(
                "part_count",
                -1,
            )
        )
        != expected_part_count
    ):
        errors.append(
            "part_count del atlas metadata no coincide con el cálculo esperado"
        )

    if (
        int(
            atlas_layout.get(
                "max_columns_per_part",
                -1,
            )
        )
        != expected_columns_per_part
    ):
        errors.append(
            "max_columns_per_part del atlas metadata no coincide"
        )

    if (
        int(
            atlas_layout.get(
                "rows_count",
                -1,
            )
        )
        != len(directions)
    ):
        errors.append(
            "rows_count del atlas metadata no coincide"
        )

    render_directions = (
        render_metadata.get(
            "directions",
            {},
        )
    )

    parts = atlas_metadata.get(
        "parts",
        [],
    )

    if len(parts) != expected_part_count:
        errors.append(
            f"metadata contiene {len(parts)} partes; "
            f"esperadas {expected_part_count}"
        )

    region_count = 0
    pixel_match_count = 0
    seen_pairs: set[tuple[str, int]] = set()

    part_reports: list[dict[str, Any]] = []

    for expected_part_index in range(
        expected_part_count
    ):
        part_number = (
            expected_part_index + 1
        )

        if expected_part_index >= len(parts):
            part_reports.append({
                "part": part_number,
                "valid": False,
                "errors": [
                    "Falta parte en metadata"
                ],
            })
            continue

        part = parts[
            expected_part_index
        ]

        part_errors: list[str] = []

        if int(
            part.get("part", -1)
        ) != part_number:
            part_errors.append(
                "Número de parte incorrecto"
            )

        start_frame = (
            expected_part_index
            * expected_columns_per_part
        )

        end_frame_exclusive = min(
            frame_count,
            start_frame
            + expected_columns_per_part,
        )

        end_frame = (
            end_frame_exclusive - 1
        )

        columns_this_part = (
            end_frame_exclusive
            - start_frame
        )

        expected_width = (
            columns_this_part
            * frame_w
        )

        expected_height = int(
            expected_layout[
                "atlas_height"
            ]
        )

        if part.get(
            "global_frame_range"
        ) != [
            start_frame,
            end_frame,
        ]:
            part_errors.append(
                "global_frame_range incorrecto"
            )

        if int(
            part.get(
                "columns",
                -1,
            )
        ) != columns_this_part:
            part_errors.append(
                "columns incorrecto"
            )

        if part.get(
            "atlas_size_px"
        ) != [
            expected_width,
            expected_height,
        ]:
            part_errors.append(
                "atlas_size_px incorrecto"
            )

        filename = str(
            part.get(
                "file",
                "",
            )
        )

        atlas_path = (
            atlas_dir / filename
        )

        atlas_image: Image.Image | None = None
        actual_hash: str | None = None

        if not atlas_path.exists():
            part_errors.append(
                f"Falta PNG: {filename}"
            )
        else:
            actual_hash = sha256_file(
                atlas_path
            )

            expected_hash = str(
                part.get(
                    "sha256",
                    "",
                )
            )

            if actual_hash != expected_hash:
                part_errors.append(
                    "SHA-256 no coincide"
                )

            try:
                with Image.open(
                    atlas_path
                ) as source:
                    source.load()

                    if source.mode != "RGBA":
                        part_errors.append(
                            f"Modo {source.mode}; esperado RGBA"
                        )

                    if source.size != (
                        expected_width,
                        expected_height,
                    ):
                        part_errors.append(
                            f"Tamaño real {source.size}; "
                            f"esperado {(expected_width, expected_height)}"
                        )

                    atlas_image = (
                        source.convert("RGBA")
                    )
            except Exception as exc:
                part_errors.append(
                    f"No se pudo abrir PNG: {exc}"
                )

        part_directions = (
            part.get(
                "directions",
                {},
            )
        )

        for row_index, direction in enumerate(
            directions
        ):
            direction_data = (
                part_directions.get(
                    direction
                )
            )

            if direction_data is None:
                part_errors.append(
                    f"Falta dirección {direction}"
                )
                continue

            if int(
                direction_data.get(
                    "row_index",
                    -1,
                )
            ) != row_index:
                part_errors.append(
                    f"{direction}: row_index incorrecto"
                )

            entries = direction_data.get(
                "frames",
                [],
            )

            if len(
                entries
            ) != columns_this_part:
                part_errors.append(
                    f"{direction}: {len(entries)} regiones; "
                    f"esperadas {columns_this_part}"
                )

            render_direction = (
                render_directions.get(
                    direction,
                    {},
                )
            )

            render_frames = (
                render_direction.get(
                    "frames",
                    [],
                )
            )

            for local_column, global_index in enumerate(
                range(
                    start_frame,
                    end_frame_exclusive,
                )
            ):
                if local_column >= len(
                    entries
                ):
                    continue

                entry = entries[
                    local_column
                ]

                region_count += 1

                pair = (
                    direction,
                    global_index,
                )

                if pair in seen_pairs:
                    part_errors.append(
                        f"{direction} frame {global_index}: duplicado"
                    )
                else:
                    seen_pairs.add(
                        pair
                    )

                if int(
                    entry.get(
                        "global_frame_index",
                        -1,
                    )
                ) != global_index:
                    part_errors.append(
                        f"{direction} frame {global_index}: "
                        "global_frame_index incorrecto"
                    )

                if int(
                    entry.get(
                        "local_column",
                        -1,
                    )
                ) != local_column:
                    part_errors.append(
                        f"{direction} frame {global_index}: "
                        "local_column incorrecto"
                    )

                expected_region = {
                    "x": (
                        local_column
                        * frame_w
                    ),
                    "y": (
                        row_index
                        * frame_h
                    ),
                    "w": frame_w,
                    "h": frame_h,
                }

                if (
                    entry.get(
                        "region_px"
                    )
                    != expected_region
                ):
                    part_errors.append(
                        f"{direction} frame {global_index}: "
                        "region_px incorrecto"
                    )

                if (
                    global_index
                    >= len(render_frames)
                ):
                    part_errors.append(
                        f"{direction} frame {global_index}: "
                        "no existe en render metadata"
                    )
                    continue

                render_entry = (
                    render_frames[
                        global_index
                    ]
                )

                source_filename = str(
                    render_entry.get(
                        "file",
                        "",
                    )
                )

                if (
                    entry.get(
                        "source_file"
                    )
                    != source_filename
                ):
                    part_errors.append(
                        f"{direction} frame {global_index}: "
                        "source_file no coincide"
                    )

                source_path = (
                    render_dir
                    / direction
                    / source_filename
                )

                if not source_path.exists():
                    part_errors.append(
                        f"{direction} frame {global_index}: "
                        f"falta source PNG {source_filename}"
                    )
                    continue

                if atlas_image is None:
                    continue

                x = expected_region["x"]
                y = expected_region["y"]

                crop = atlas_image.crop(
                    (
                        x,
                        y,
                        x + frame_w,
                        y + frame_h,
                    )
                )

                try:
                    with Image.open(
                        source_path
                    ) as source:
                        source.load()
                        source_rgba = (
                            source.convert(
                                "RGBA"
                            )
                        )

                        if source_rgba.size != (
                            frame_w,
                            frame_h,
                        ):
                            part_errors.append(
                                f"{direction} frame {global_index}: "
                                f"source size {source_rgba.size}"
                            )
                            continue

                        if not images_equal(
                            crop,
                            source_rgba,
                        ):
                            part_errors.append(
                                f"{direction} frame {global_index}: "
                                "pixels del atlas != source PNG"
                            )
                        else:
                            pixel_match_count += 1
                except Exception as exc:
                    part_errors.append(
                        f"{direction} frame {global_index}: "
                        f"error leyendo source PNG: {exc}"
                    )

        if part_errors:
            errors.extend(
                f"part {part_number}: {message}"
                for message in part_errors
            )

        part_reports.append({
            "part": part_number,
            "file": filename,
            "valid": not part_errors,
            "sha256": actual_hash,
            "expected_size_px": [
                expected_width,
                expected_height,
            ],
            "global_frame_range": [
                start_frame,
                end_frame,
            ],
            "columns": columns_this_part,
            "errors": part_errors,
        })

    expected_pairs = {
        (
            direction,
            frame_index,
        )
        for direction in directions
        for frame_index in range(
            frame_count
        )
    }

    missing_pairs = (
        expected_pairs - seen_pairs
    )

    extra_pairs = (
        seen_pairs - expected_pairs
    )

    if missing_pairs:
        errors.append(
            f"Faltan {len(missing_pairs)} regiones globales"
        )

    if extra_pairs:
        errors.append(
            f"Hay {len(extra_pairs)} regiones globales inesperadas"
        )

    expected_region_count = (
        len(directions)
        * frame_count
    )

    if region_count != expected_region_count:
        errors.append(
            f"Regiones procesadas={region_count}; "
            f"esperadas={expected_region_count}"
        )

    if (
        pixel_match_count
        != expected_region_count
    ):
        errors.append(
            f"Regiones pixel-perfect={pixel_match_count}; "
            f"esperadas={expected_region_count}"
        )

    return {
        "pipeline": (
            "Magic Symbols Pipeline v1"
        ),
        "validator": (
            "validate_atlas.py"
        ),
        "character_id": character_id,
        "animation_id": animation_id,
        "source_action": (
            animation_cfg[
                "source_action"
            ]
        ),
        "valid": not errors,
        "errors": errors,
        "warnings": warnings,
        "frame_size_px": [
            frame_w,
            frame_h,
        ],
        "frames_per_direction": (
            frame_count
        ),
        "direction_order": (
            directions
        ),
        "expected_region_count": (
            expected_region_count
        ),
        "validated_region_count": (
            region_count
        ),
        "pixel_perfect_region_count": (
            pixel_match_count
        ),
        "layout": {
            "max_texture_size_px": int(
                atlas_cfg[
                    "max_texture_size_px"
                ]
            ),
            "max_columns_per_part": (
                expected_columns_per_part
            ),
            "part_count": (
                expected_part_count
            ),
        },
        "parts": part_reports,
    }


def main() -> int:
    args = parse_args()

    try:
        manifest_path = (
            resolve_project_path(
                args.character_json
            )
        )

        render_dir = (
            resolve_project_path(
                args.render_dir
            )
        )

        atlas_dir = (
            resolve_project_path(
                args.atlas_dir
            )
        )

        config = load_json(
            manifest_path
        )

        animation_id = (
            args.animation
        )

        if (
            animation_id
            not in config["animations"]
        ):
            raise RuntimeError(
                f'Animación "{animation_id}" '
                "no existe en character.json"
            )

        if not render_dir.exists():
            raise RuntimeError(
                f"No existe render-dir: {render_dir}"
            )

        if not atlas_dir.exists():
            raise RuntimeError(
                f"No existe atlas-dir: {atlas_dir}"
            )

        render_meta_path = (
            render_metadata_path(
                render_dir,
                animation_id,
            )
        )

        basename = (
            config["animations"]
            [animation_id]
            ["atlas_basename"]
        )

        atlas_meta_path = (
            atlas_metadata_path(
                atlas_dir,
                basename,
            )
        )

        render_metadata = load_json(
            render_meta_path
        )

        atlas_metadata = load_json(
            atlas_meta_path
        )

        report = validate_atlas(
            config=config,
            animation_id=animation_id,
            render_dir=render_dir,
            atlas_dir=atlas_dir,
            render_metadata=render_metadata,
            atlas_metadata=atlas_metadata,
        )

        if args.report is not None:
            report_path = (
                resolve_project_path(
                    args.report
                )
            )
        else:
            report_root = (
                resolve_project_path(
                    Path(
                        config["output"]
                        ["report_root"]
                    )
                )
            )

            report_path = (
                report_root
                / (
                    f"{animation_id}"
                    "_atlas_validation.json"
                )
            )

        report_path.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        report_path.write_text(
            json.dumps(
                report,
                indent=2,
                ensure_ascii=False,
            )
            + "\n",
            encoding="utf-8",
        )

    except Exception as exc:
        print(
            "[Atlas Validator] INPUT FAIL:",
            exc,
        )
        return EXIT_INPUT_ERROR

    print(
        "Magic Symbols Pipeline v1 "
        "— Atlas Validator"
    )
    print(
        "Animation:",
        report["animation_id"],
    )
    print()

    for part in report["parts"]:
        status = (
            "PASS"
            if part["valid"]
            else "FAIL"
        )

        print(
            f"{status} part {part['part']} | "
            f"{part['file']} | "
            f"{part['expected_size_px'][0]}"
            f"x"
            f"{part['expected_size_px'][1]} | "
            f"frames "
            f"{part['global_frame_range'][0]}"
            f"-"
            f"{part['global_frame_range'][1]}"
        )

        if not part["valid"]:
            for error in part["errors"]:
                print(
                    f"  - {error}"
                )

    print()
    print(
        "Regions:",
        f"{report['validated_region_count']}"
        f"/"
        f"{report['expected_region_count']}",
    )

    print(
        "Pixel-perfect:",
        f"{report['pixel_perfect_region_count']}"
        f"/"
        f"{report['expected_region_count']}",
    )

    print(
        "REPORT",
        report_path,
    )

    if report["valid"]:
        print()
        print("ATLAS VALID")
        return EXIT_VALID

    print()
    print(
        f"ATLAS INVALID "
        f"({len(report['errors'])} failure(s))"
    )

    for error in report["errors"]:
        print(
            f"  - {error}"
        )

    return EXIT_INVALID


if __name__ == "__main__":
    sys.exit(main())
