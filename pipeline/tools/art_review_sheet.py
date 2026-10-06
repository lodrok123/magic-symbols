from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont


DIRECTION_LABEL_HEIGHT = 28
SHEET_PADDING = 16
TILE_GAP = 12


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Magic Symbols art-review sheet generator. "
            "Builds silhouette, proportion-grid and scale-test sheets "
            "from an existing directional render."
        )
    )
    parser.add_argument(
        "--character-json",
        required=True,
        type=Path,
    )
    parser.add_argument(
        "--render-dir",
        required=True,
        type=Path,
    )
    parser.add_argument(
        "--output",
        required=True,
        type=Path,
    )
    parser.add_argument(
        "--frame-index",
        type=int,
        default=0,
        help="Frame index to inspect in every direction. Default: 0.",
    )
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(
        path.read_text(
            encoding="utf-8"
        )
    )


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    alpha = image.getchannel("A")
    return alpha.getbbox()


def find_direction_frame(
    render_dir: Path,
    direction: str,
    frame_index: int,
) -> Path:
    direction_dir = (
        render_dir
        / direction
    )

    if not direction_dir.is_dir():
        raise RuntimeError(
            f"No existe la dirección {direction}: {direction_dir}"
        )

    frames = sorted(
        direction_dir.glob("*.png")
    )

    if not frames:
        raise RuntimeError(
            f"No hay PNGs en {direction_dir}"
        )

    if frame_index < 0:
        index = len(frames) + frame_index
    else:
        index = frame_index

    if index < 0 or index >= len(frames):
        raise RuntimeError(
            f"frame-index {frame_index} fuera de rango para "
            f"{direction}; hay {len(frames)} frames."
        )

    return frames[index]


def make_silhouette(
    image: Image.Image,
) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")

    black = Image.new(
        "RGBA",
        rgba.size,
        (0, 0, 0, 0),
    )
    black.putalpha(alpha)

    return black


def checker_background(
    size: tuple[int, int],
    cell: int = 16,
) -> Image.Image:
    width, height = size
    image = Image.new(
        "RGBA",
        size,
        (244, 244, 244, 255),
    )
    draw = ImageDraw.Draw(image)

    for y in range(0, height, cell):
        for x in range(0, width, cell):
            if (
                (x // cell)
                + (y // cell)
            ) % 2:
                draw.rectangle(
                    [
                        x,
                        y,
                        min(x + cell - 1, width - 1),
                        min(y + cell - 1, height - 1),
                    ],
                    fill=(
                        224,
                        224,
                        224,
                        255,
                    ),
                )

    return image


def compose_on_background(
    image: Image.Image,
) -> Image.Image:
    background = checker_background(
        image.size
    )
    background.alpha_composite(
        image.convert("RGBA")
    )
    return background


def label_tile(
    image: Image.Image,
    label: str,
) -> Image.Image:
    width, height = image.size
    tile = Image.new(
        "RGBA",
        (
            width,
            height + DIRECTION_LABEL_HEIGHT,
        ),
        (255, 255, 255, 255),
    )
    tile.alpha_composite(
        image,
        (
            0,
            DIRECTION_LABEL_HEIGHT,
        ),
    )

    draw = ImageDraw.Draw(tile)
    draw.text(
        (
            width // 2,
            DIRECTION_LABEL_HEIGHT // 2,
        ),
        label,
        fill=(0, 0, 0, 255),
        anchor="mm",
    )

    return tile


def add_proportion_grid(
    image: Image.Image,
    bbox: tuple[int, int, int, int] | None,
) -> Image.Image:
    result = compose_on_background(
        image
    )
    draw = ImageDraw.Draw(
        result,
        "RGBA",
    )

    if bbox is None:
        return result

    left, top, right, bottom = bbox
    body_height = bottom - top

    draw.rectangle(
        [left, top, right - 1, bottom - 1],
        outline=(0, 0, 0, 180),
        width=1,
    )

    for i in range(1, 8):
        y = (
            top
            + body_height * i / 8.0
        )

        draw.line(
            [
                (left, y),
                (right, y),
            ],
            fill=(0, 0, 0, 90),
            width=1,
        )

    center_x = (
        left + right
    ) / 2.0

    draw.line(
        [
            (center_x, top),
            (center_x, bottom),
        ],
        fill=(0, 0, 0, 100),
        width=1,
    )

    return result


def make_sheet(
    tiles: list[tuple[str, Image.Image]],
    columns: int,
) -> Image.Image:
    if not tiles:
        raise RuntimeError(
            "No hay tiles para crear la hoja."
        )

    labeled = [
        label_tile(
            image,
            label,
        )
        for label, image in tiles
    ]

    tile_w, tile_h = (
        labeled[0].size
    )

    rows = math.ceil(
        len(labeled) / columns
    )

    sheet_w = (
        SHEET_PADDING * 2
        + columns * tile_w
        + (columns - 1) * TILE_GAP
    )

    sheet_h = (
        SHEET_PADDING * 2
        + rows * tile_h
        + (rows - 1) * TILE_GAP
    )

    sheet = Image.new(
        "RGBA",
        (
            sheet_w,
            sheet_h,
        ),
        (245, 245, 245, 255),
    )

    for index, tile in enumerate(
        labeled
    ):
        row = index // columns
        col = index % columns

        x = (
            SHEET_PADDING
            + col * (
                tile_w
                + TILE_GAP
            )
        )

        y = (
            SHEET_PADDING
            + row * (
                tile_h
                + TILE_GAP
            )
        )

        sheet.alpha_composite(
            tile,
            (
                x,
                y,
            ),
        )

    return sheet


def make_scale_sheet(
    direction_images: list[tuple[str, Image.Image]],
) -> Image.Image:
    scales = [
        ("100%", 1.0),
        ("75%", 0.75),
        ("50%", 0.5),
        ("35%", 0.35),
    ]

    rows: list[tuple[str, Image.Image]] = []

    for direction, image in direction_images:
        base = compose_on_background(
            image
        )

        for scale_name, scale in scales:
            width = max(
                1,
                int(
                    round(
                        base.width * scale
                    )
                ),
            )

            height = max(
                1,
                int(
                    round(
                        base.height * scale
                    )
                ),
            )

            scaled = base.resize(
                (
                    width,
                    height,
                ),
                Image.Resampling.LANCZOS,
            )

            canvas = Image.new(
                "RGBA",
                base.size,
                (245, 245, 245, 255),
            )

            x = (
                base.width - width
            ) // 2

            y = (
                base.height - height
            ) // 2

            canvas.alpha_composite(
                scaled,
                (
                    x,
                    y,
                ),
            )

            rows.append(
                (
                    f"{direction} · {scale_name}",
                    canvas,
                )
            )

    return make_sheet(
        rows,
        columns=4,
    )


def metrics_for(
    image: Image.Image,
) -> dict[str, Any]:
    rgba = image.convert(
        "RGBA"
    )

    bbox = alpha_bbox(
        rgba
    )

    width, height = (
        rgba.size
    )

    if bbox is None:
        return {
            "bbox": None,
            "canvas_px": [
                width,
                height,
            ],
            "occupancy": {
                "width_ratio": 0.0,
                "height_ratio": 0.0,
            },
        }

    left, top, right, bottom = (
        bbox
    )

    bbox_w = right - left
    bbox_h = bottom - top

    return {
        "bbox": [
            left,
            top,
            right,
            bottom,
        ],
        "bbox_px": [
            bbox_w,
            bbox_h,
        ],
        "canvas_px": [
            width,
            height,
        ],
        "occupancy": {
            "width_ratio": (
                bbox_w / width
            ),
            "height_ratio": (
                bbox_h / height
            ),
        },
        "margins_px": {
            "left": left,
            "top": top,
            "right": width - right,
            "bottom": height - bottom,
        },
        "center_px": [
            (
                left + right
            ) / 2.0,
            (
                top + bottom
            ) / 2.0,
        ],
    }


def main() -> int:
    args = parse_args()

    character_json = (
        args.character_json
        .resolve()
    )

    render_dir = (
        args.render_dir
        .resolve()
    )

    output_dir = (
        args.output
        .resolve()
    )

    config = load_json(
        character_json
    )

    directions = [
        item["id"]
        for item in config[
            "render"
        ][
            "directions"
        ]
    ]

    output_dir.mkdir(
        parents=True,
        exist_ok=True,
    )

    original_tiles: list[
        tuple[str, Image.Image]
    ] = []

    silhouette_tiles: list[
        tuple[str, Image.Image]
    ] = []

    grid_tiles: list[
        tuple[str, Image.Image]
    ] = []

    report: dict[
        str,
        Any,
    ] = {
        "character_id": config[
            "character"
        ][
            "id"
        ],
        "frame_index": args.frame_index,
        "render_dir": str(
            render_dir
        ),
        "directions": {},
    }

    for direction in directions:
        frame_path = (
            find_direction_frame(
                render_dir,
                direction,
                args.frame_index,
            )
        )

        image = Image.open(
            frame_path
        ).convert(
            "RGBA"
        )

        bbox = alpha_bbox(
            image
        )

        original_tiles.append(
            (
                direction,
                compose_on_background(
                    image
                ),
            )
        )

        silhouette = (
            make_silhouette(
                image
            )
        )

        silhouette_tiles.append(
            (
                direction,
                compose_on_background(
                    silhouette
                ),
            )
        )

        grid_tiles.append(
            (
                direction,
                add_proportion_grid(
                    silhouette,
                    bbox,
                ),
            )
        )

        report[
            "directions"
        ][direction] = {
            "file": str(
                frame_path
            ),
            **metrics_for(
                image
            ),
        }

    direction_count = len(
        directions
    )

    columns = (
        4
        if direction_count >= 4
        else max(
            1,
            direction_count,
        )
    )

    original_sheet = make_sheet(
        original_tiles,
        columns=columns,
    )

    silhouette_sheet = make_sheet(
        silhouette_tiles,
        columns=columns,
    )

    proportion_sheet = make_sheet(
        grid_tiles,
        columns=columns,
    )

    scale_sheet = make_scale_sheet(
        [
            (
                direction,
                Image.open(
                    find_direction_frame(
                        render_dir,
                        direction,
                        args.frame_index,
                    )
                ).convert("RGBA"),
            )
            for direction in directions
        ]
    )

    original_path = (
        output_dir
        / "sprite_8dir.png"
    )

    silhouette_path = (
        output_dir
        / "silhouette_8dir.png"
    )

    proportion_path = (
        output_dir
        / "proportion_grid_8dir.png"
    )

    scale_path = (
        output_dir
        / "scale_test_8dir.png"
    )

    report_path = (
        output_dir
        / "art_metrics.json"
    )

    original_sheet.save(
        original_path
    )

    silhouette_sheet.save(
        silhouette_path
    )

    proportion_sheet.save(
        proportion_path
    )

    scale_sheet.save(
        scale_path
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

    print(
        "Magic Symbols — Art Review"
    )

    print(
        f"Character: {report['character_id']}"
    )

    print(
        f"Frame:     {args.frame_index}"
    )

    print(
        f"Output:    {output_dir}"
    )

    print()
    print(
        "PASS sprite_8dir.png"
    )
    print(
        "PASS silhouette_8dir.png"
    )
    print(
        "PASS proportion_grid_8dir.png"
    )
    print(
        "PASS scale_test_8dir.png"
    )
    print(
        "PASS art_metrics.json"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(
        main()
    )
