from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path
from typing import Any

from PIL import Image


DEFAULT_ALPHA_THRESHOLD = 16


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Magic Symbols alpha auditor. Scans raw directional PNG renders "
            "for partial alpha and enclosed transparent holes."
        )
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
        "--alpha-threshold",
        type=int,
        default=DEFAULT_ALPHA_THRESHOLD,
    )
    parser.add_argument(
        "--frame-index",
        type=int,
        default=0,
        help="Frame index to inspect in each direction. Default: 0.",
    )
    parser.add_argument(
        "--directions",
        default="S,SW,W,NW,N,NE,E,SE",
        help=(
            "Comma-separated directions to audit. "
            "Example: S or S,E,N,W."
        ),
    )
    return parser.parse_args()


def frame_for_direction(
    render_dir: Path,
    direction: str,
    frame_index: int,
) -> Path:
    folder = render_dir / direction

    if not folder.is_dir():
        raise RuntimeError(
            f"No existe la carpeta de dirección: {folder}"
        )

    frames = sorted(
        folder.glob("*.png")
    )

    if not frames:
        raise RuntimeError(
            f"No hay PNGs en: {folder}"
        )

    index = (
        frame_index
        if frame_index >= 0
        else len(frames) + frame_index
    )

    if index < 0 or index >= len(frames):
        raise RuntimeError(
            f"frame-index {frame_index} fuera de rango para {direction}; "
            f"hay {len(frames)} frames."
        )

    return frames[index]


def alpha_bbox(
    alpha: Image.Image,
    threshold: int,
) -> tuple[int, int, int, int] | None:
    mask = alpha.point(
        lambda value: 255
        if value >= threshold
        else 0
    )

    return mask.getbbox()


def enclosed_holes(
    alpha: Image.Image,
    bbox: tuple[int, int, int, int],
    threshold: int,
) -> dict[str, Any]:
    left, top, right, bottom = bbox
    width = right - left
    height = bottom - top

    alpha_pixels = alpha.load()

    solid = [
        [
            alpha_pixels[
                left + x,
                top + y,
            ] >= threshold
            for x in range(width)
        ]
        for y in range(height)
    ]

    visited = [
        [False] * width
        for _ in range(height)
    ]

    queue: deque[tuple[int, int]] = deque()

    def push_if_background(
        x: int,
        y: int,
    ) -> None:
        if (
            0 <= x < width
            and 0 <= y < height
            and not visited[y][x]
            and not solid[y][x]
        ):
            visited[y][x] = True
            queue.append((x, y))

    for x in range(width):
        push_if_background(x, 0)
        push_if_background(x, height - 1)

    for y in range(height):
        push_if_background(0, y)
        push_if_background(width - 1, y)

    while queue:
        x, y = queue.popleft()

        push_if_background(x + 1, y)
        push_if_background(x - 1, y)
        push_if_background(x, y + 1)
        push_if_background(x, y - 1)

    holes_mask = [
        [
            (
                not solid[y][x]
                and not visited[y][x]
            )
            for x in range(width)
        ]
        for y in range(height)
    ]

    seen = [
        [False] * width
        for _ in range(height)
    ]

    hole_areas: list[int] = []

    for y in range(height):
        for x in range(width):
            if (
                not holes_mask[y][x]
                or seen[y][x]
            ):
                continue

            area = 0
            component: deque[tuple[int, int]] = deque(
                [(x, y)]
            )
            seen[y][x] = True

            while component:
                cx, cy = component.popleft()
                area += 1

                for nx, ny in (
                    (cx + 1, cy),
                    (cx - 1, cy),
                    (cx, cy + 1),
                    (cx, cy - 1),
                ):
                    if (
                        0 <= nx < width
                        and 0 <= ny < height
                        and holes_mask[ny][nx]
                        and not seen[ny][nx]
                    ):
                        seen[ny][nx] = True
                        component.append((nx, ny))

            hole_areas.append(area)

    hole_areas.sort(
        reverse=True
    )

    return {
        "count": len(hole_areas),
        "areas_px": hole_areas,
        "total_area_px": sum(hole_areas),
        "largest_area_px": (
            hole_areas[0]
            if hole_areas
            else 0
        ),
    }


def flattened_alpha_values(
    alpha: Image.Image,
) -> list[int]:
    getter = getattr(
        alpha,
        "get_flattened_data",
        None,
    )

    if getter is not None:
        return list(
            getter()
        )

    return list(
        alpha.getdata()
    )


def analyze_png(
    path: Path,
    threshold: int,
) -> dict[str, Any]:
    image = Image.open(
        path
    ).convert("RGBA")

    alpha = image.getchannel("A")

    values = flattened_alpha_values(
        alpha
    )

    total = len(values)

    transparent = sum(
        1
        for value in values
        if value == 0
    )

    partial = sum(
        1
        for value in values
        if 0 < value < 255
    )

    opaque = sum(
        1
        for value in values
        if value == 255
    )

    bbox = alpha_bbox(
        alpha,
        threshold,
    )

    holes = {
        "count": 0,
        "areas_px": [],
        "total_area_px": 0,
        "largest_area_px": 0,
    }

    if bbox is not None:
        holes = enclosed_holes(
            alpha,
            bbox,
            threshold,
        )

    return {
        "file": str(path),
        "size_px": list(
            image.size
        ),
        "alpha_min": min(values),
        "alpha_max": max(values),
        "transparent_px": transparent,
        "partial_alpha_px": partial,
        "opaque_px": opaque,
        "partial_alpha_ratio": (
            partial / total
            if total
            else 0.0
        ),
        "bbox": (
            list(bbox)
            if bbox is not None
            else None
        ),
        "holes": holes,
    }


def main() -> int:
    args = parse_args()

    render_dir = (
        args.render_dir
        .resolve()
    )

    output_path = (
        args.output
        .resolve()
    )

    directions = [
        item.strip()
        for item in args.directions.split(",")
        if item.strip()
    ]

    valid_directions = {
        "S",
        "SW",
        "W",
        "NW",
        "N",
        "NE",
        "E",
        "SE",
    }

    if not directions:
        raise RuntimeError(
            "--directions no contiene ninguna dirección."
        )

    unknown = [
        direction
        for direction in directions
        if direction not in valid_directions
    ]

    if unknown:
        raise RuntimeError(
            "Direcciones desconocidas: "
            + ", ".join(unknown)
        )

    report: dict[str, Any] = {
        "render_dir": str(
            render_dir
        ),
        "frame_index": args.frame_index,
        "alpha_threshold": args.alpha_threshold,
        "directions": {},
    }

    print(
        "Magic Symbols — Alpha Audit"
    )
    print(
        f"Render dir: {render_dir}"
    )
    print()

    for direction in directions:
        frame = frame_for_direction(
            render_dir,
            direction,
            args.frame_index,
        )

        result = analyze_png(
            frame,
            args.alpha_threshold,
        )

        report[
            "directions"
        ][direction] = result

        holes = result["holes"]

        print(
            f"{direction:>2} "
            f"partial={result['partial_alpha_px']:>5} "
            f"({result['partial_alpha_ratio']:.4%}) "
            f"holes={holes['count']:>3} "
            f"largest={holes['largest_area_px']:>4}px"
        )

    output_path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    output_path.write_text(
        json.dumps(
            report,
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )

    print()
    print(
        f"REPORT {output_path}"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(
        main()
    )
