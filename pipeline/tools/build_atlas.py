from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
from typing import Any

from PIL import Image


EXIT_OK = 0
EXIT_CONFIG_ERROR = 2
EXIT_INPUT_ERROR = 3
EXIT_BUILD_ERROR = 4


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build Magic Symbols directional sprite atlases from generic renderer output."
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
        help="Generic renderer output directory",
    )

    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help=(
            "Output directory. If omitted, uses "
            "<atlas_root>/<animation_id> from character.json."
        ),
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
            f"JSON inválido en {path}, línea {exc.lineno}, columna {exc.colno}: {exc.msg}"
        ) from exc

    if not isinstance(data, dict):
        raise RuntimeError(f"El JSON raíz debe ser un objeto: {path}")

    return data


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)

    return digest.hexdigest()


def animation_render_metadata_path(
    render_dir: Path,
    animation_id: str,
) -> Path:
    exact = render_dir / f"{animation_id}_render_metadata.json"

    if exact.exists():
        return exact

    candidates = sorted(render_dir.glob("*_render_metadata.json"))

    if len(candidates) == 1:
        return candidates[0]

    if not candidates:
        raise RuntimeError(
            f"No se encontró metadata de render dentro de: {render_dir}"
        )

    raise RuntimeError(
        "Hay varios archivos *_render_metadata.json y no se puede elegir uno: "
        + ", ".join(path.name for path in candidates)
    )


def direction_ids(config: dict[str, Any]) -> list[str]:
    return list(config["atlas"]["layout"]["direction_order"])


def source_frame_files(
    render_dir: Path,
    render_metadata: dict[str, Any],
    direction: str,
) -> list[Path]:
    direction_data = render_metadata["directions"].get(direction)

    if direction_data is None:
        raise RuntimeError(
            f"El render metadata no contiene la dirección: {direction}"
        )

    frame_entries = direction_data.get("frames", [])

    if not frame_entries:
        raise RuntimeError(
            f"No hay frames declarados para dirección: {direction}"
        )

    paths: list[Path] = []

    for expected_index, frame_entry in enumerate(frame_entries):
        actual_index = int(frame_entry["frame_index"])

        if actual_index != expected_index:
            raise RuntimeError(
                f"{direction}: frame_index discontinuo. "
                f"Esperado {expected_index}, encontrado {actual_index}"
            )

        filename = str(frame_entry["file"])
        frame_path = render_dir / direction / filename

        if not frame_path.exists():
            raise RuntimeError(
                f"{direction}: falta frame declarado en metadata: {frame_path}"
            )

        paths.append(frame_path)

    return paths


def validate_source_image(
    path: Path,
    expected_size: tuple[int, int],
) -> None:
    try:
        with Image.open(path) as image:
            image.load()

            if image.size != expected_size:
                raise RuntimeError(
                    f"{path}: tamaño {image.size}, esperado {expected_size}"
                )

            if image.mode != "RGBA":
                raise RuntimeError(
                    f"{path}: modo {image.mode}, esperado RGBA"
                )
    except RuntimeError:
        raise
    except Exception as exc:
        raise RuntimeError(
            f"No se pudo leer imagen {path}: {exc}"
        ) from exc


def validate_render_metadata(
    config: dict[str, Any],
    animation_id: str,
    render_metadata: dict[str, Any],
) -> None:
    animation_cfg = config["animations"][animation_id]
    render_cfg = config["render"]

    if render_metadata.get("character_id") != config["character"]["id"]:
        raise RuntimeError(
            "character_id del render metadata no coincide con character.json"
        )

    if render_metadata.get("animation_id") != animation_id:
        raise RuntimeError(
            "animation_id del render metadata no coincide con --animation"
        )

    if render_metadata.get("source_action") != animation_cfg["source_action"]:
        raise RuntimeError(
            "source_action del render metadata no coincide con character.json"
        )

    if render_metadata.get("canvas_px") != render_cfg["frame_size_px"]:
        raise RuntimeError(
            "canvas_px del render metadata no coincide con character.json"
        )

    configured_directions = direction_ids(config)
    rendered_directions = render_metadata.get("direction_order", [])

    if rendered_directions != configured_directions:
        raise RuntimeError(
            "direction_order del render no coincide exactamente con atlas.layout.direction_order. "
            f"Render={rendered_directions}, Config={configured_directions}"
        )

    expected_frames = int(render_metadata["frame_count_per_direction"])

    if expected_frames < 1:
        raise RuntimeError(
            "frame_count_per_direction debe ser >= 1"
        )


def calculate_layout(
    frame_size: tuple[int, int],
    direction_count: int,
    frame_count: int,
    max_texture_size: int,
) -> dict[str, int]:
    frame_w, frame_h = frame_size

    required_height = frame_h * direction_count

    if required_height > max_texture_size:
        raise RuntimeError(
            "Las filas de direcciones no caben en el límite de textura: "
            f"{frame_h} × {direction_count} = {required_height} > {max_texture_size}"
        )

    columns_per_part = max_texture_size // frame_w

    if columns_per_part < 1:
        raise RuntimeError(
            f"Un frame de ancho {frame_w}px no cabe en max_texture_size={max_texture_size}px"
        )

    part_count = math.ceil(frame_count / columns_per_part)

    return {
        "columns_per_part": columns_per_part,
        "part_count": part_count,
        "atlas_height": required_height,
    }


def clean_output_dir(output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    for path in output_dir.glob("*.png"):
        path.unlink()

    for path in output_dir.glob("*_metadata.json"):
        path.unlink()


def build_atlases(
    config: dict[str, Any],
    render_dir: Path,
    render_metadata: dict[str, Any],
    animation_id: str,
    output_dir: Path,
) -> dict[str, Any]:
    animation_cfg = config["animations"][animation_id]
    atlas_cfg = config["atlas"]

    frame_w, frame_h = map(
        int,
        config["render"]["frame_size_px"],
    )

    directions = direction_ids(config)

    source_frames: dict[str, list[Path]] = {}

    for direction in directions:
        source_frames[direction] = source_frame_files(
            render_dir,
            render_metadata,
            direction,
        )

    frame_counts = {
        direction: len(paths)
        for direction, paths in source_frames.items()
    }

    unique_counts = set(frame_counts.values())

    if len(unique_counts) != 1:
        raise RuntimeError(
            f"Las direcciones no tienen el mismo número de frames: {frame_counts}"
        )

    frame_count = unique_counts.pop()

    declared_count = int(
        render_metadata["frame_count_per_direction"]
    )

    if frame_count != declared_count:
        raise RuntimeError(
            f"Frames reales={frame_count}, metadata={declared_count}"
        )

    expected_size = (frame_w, frame_h)

    print("[Atlas] Validating source PNGs...")

    for direction in directions:
        for frame_path in source_frames[direction]:
            validate_source_image(
                frame_path,
                expected_size,
            )

    layout = calculate_layout(
        frame_size=expected_size,
        direction_count=len(directions),
        frame_count=frame_count,
        max_texture_size=int(
            atlas_cfg["max_texture_size_px"]
        ),
    )

    columns_per_part = layout["columns_per_part"]
    part_count = layout["part_count"]
    atlas_height = layout["atlas_height"]

    basename = animation_cfg["atlas_basename"]

    parts_metadata: list[dict[str, Any]] = []

    for part_index in range(part_count):
        start_frame = part_index * columns_per_part
        end_frame_exclusive = min(
            frame_count,
            start_frame + columns_per_part,
        )

        columns_this_part = (
            end_frame_exclusive - start_frame
        )

        atlas_width = columns_this_part * frame_w

        atlas = Image.new(
            "RGBA",
            (atlas_width, atlas_height),
            (0, 0, 0, 0),
        )

        part_directions: dict[str, Any] = {}

        for row_index, direction in enumerate(directions):
            frame_entries: list[dict[str, Any]] = []

            for local_column, global_frame_index in enumerate(
                range(start_frame, end_frame_exclusive)
            ):
                source_path = source_frames[direction][
                    global_frame_index
                ]

                with Image.open(source_path) as source_image:
                    rgba = source_image.convert("RGBA")

                    x = local_column * frame_w
                    y = row_index * frame_h

                    atlas.alpha_composite(
                        rgba,
                        (x, y),
                    )

                frame_entries.append({
                    "global_frame_index": global_frame_index,
                    "local_column": local_column,
                    "source_file": source_path.name,
                    "region_px": {
                        "x": x,
                        "y": y,
                        "w": frame_w,
                        "h": frame_h,
                    },
                })

            part_directions[direction] = {
                "row_index": row_index,
                "frames": frame_entries,
            }

        part_number = part_index + 1

        atlas_name = (
            f"{basename}_part_{part_number}.png"
            if part_count > 1
            else f"{basename}.png"
        )

        atlas_path = output_dir / atlas_name

        atlas.save(
            atlas_path,
            format="PNG",
        )

        file_hash = sha256_file(atlas_path)

        parts_metadata.append({
            "part": part_number,
            "file": atlas_name,
            "sha256": file_hash,
            "global_frame_range": [
                start_frame,
                end_frame_exclusive - 1,
            ],
            "columns": columns_this_part,
            "atlas_size_px": [
                atlas_width,
                atlas_height,
            ],
            "directions": part_directions,
        })

        print(
            f"[Atlas] PASS part {part_number}/{part_count}: "
            f"{atlas_name} "
            f"{atlas_width}x{atlas_height} "
            f"frames {start_frame}-{end_frame_exclusive - 1}"
        )

    playback_fps = float(
        animation_cfg["timing"].get(
            "playback_fps",
            animation_cfg["output_fps"],
        )
    )

    atlas_metadata: dict[str, Any] = {
        "pipeline": "Magic Symbols Pipeline v1",
        "builder": "build_atlas.py",
        "character_id": config["character"]["id"],
        "animation_id": animation_id,
        "source_action": animation_cfg["source_action"],
        "loop": bool(animation_cfg["loop"]),
        "fps": playback_fps,
        "frame_size_px": [
            frame_w,
            frame_h,
        ],
        "frames_per_direction": frame_count,
        "direction_order": directions,
        "ground_anchor_px": config["render"]["ground_anchor_px"],
        "ortho_scale": config["render"]["ortho_scale"],
        "layout": {
            "columns": "frames",
            "rows": "directions",
            "rows_count": len(directions),
            "max_texture_size_px": int(
                atlas_cfg["max_texture_size_px"]
            ),
            "max_columns_per_part": columns_per_part,
            "part_count": part_count,
        },
        "godot": {
            "visual_offset_px": config["godot"]["visual_offset_px"],
            "direction_mapping": config["godot"]["direction_mapping"],
            "runtime_spriteframes": config["godot"]["runtime_spriteframes"],
        },
        "render_metadata_file": str(
            render_dir.name
            + "/"
            + f"{animation_id}_render_metadata.json"
        ),
        "parts": parts_metadata,
    }

    metadata_name = f"{basename}_metadata.json"
    metadata_path = output_dir / metadata_name

    metadata_path.write_text(
        json.dumps(
            atlas_metadata,
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )

    print(
        "[Atlas] Metadata:",
        metadata_path,
    )

    return atlas_metadata


def main() -> int:
    args = parse_args()

    try:
        manifest_path = resolve_project_path(
            args.character_json
        )

        render_dir = resolve_project_path(
            args.render_dir
        )

        config = load_json(
            manifest_path
        )

        animation_id = args.animation

        if animation_id not in config["animations"]:
            raise RuntimeError(
                f'Animación "{animation_id}" no existe en character.json'
            )

        if not config["animations"][animation_id]["enabled"]:
            raise RuntimeError(
                f'Animación "{animation_id}" está deshabilitada'
            )

        if args.output is None:
            output_dir = resolve_project_path(
                Path(config["output"]["atlas_root"])
                / animation_id
            )
        else:
            output_dir = resolve_project_path(
                args.output
            )

        if not render_dir.exists():
            raise RuntimeError(
                f"No existe render-dir: {render_dir}"
            )

        render_metadata_path = animation_render_metadata_path(
            render_dir,
            animation_id,
        )

        render_metadata = load_json(
            render_metadata_path
        )

        validate_render_metadata(
            config,
            animation_id,
            render_metadata,
        )

    except Exception as exc:
        print(
            "[Atlas] CONFIG/INPUT FAIL:",
            exc,
        )
        return EXIT_CONFIG_ERROR

    try:
        clean_output_dir(
            output_dir
        )

        metadata = build_atlases(
            config=config,
            render_dir=render_dir,
            render_metadata=render_metadata,
            animation_id=animation_id,
            output_dir=output_dir,
        )

    except Exception as exc:
        print(
            "[Atlas] BUILD FAIL:",
            exc,
        )
        return EXIT_BUILD_ERROR

    print()
    print("[Atlas] BUILD VALID")
    print(
        "[Atlas] Animation:",
        metadata["animation_id"],
    )
    print(
        "[Atlas] Frames/direction:",
        metadata["frames_per_direction"],
    )
    print(
        "[Atlas] Parts:",
        metadata["layout"]["part_count"],
    )
    print(
        "[Atlas] Output:",
        output_dir,
    )

    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
