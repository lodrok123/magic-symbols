from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Visualize enclosed transparent holes and partial-alpha pixels "
            "in a single Magic Symbols render frame."
        )
    )
    parser.add_argument(
        "--render-dir",
        required=True,
        type=Path,
    )
    parser.add_argument(
        "--direction",
        default="S",
    )
    parser.add_argument(
        "--frame-index",
        type=int,
        default=0,
    )
    parser.add_argument(
        "--output",
        required=True,
        type=Path,
    )
    parser.add_argument(
        "--alpha-threshold",
        type=int,
        default=16,
    )
    parser.add_argument(
        "--scale",
        type=int,
        default=4,
    )
    return parser.parse_args()


def find_frame(
    render_dir: Path,
    direction: str,
    frame_index: int,
) -> Path:
    folder = render_dir / direction

    if not folder.is_dir():
        raise RuntimeError(
            f"No existe la dirección {direction}: {folder}"
        )

    frames = sorted(
        folder.glob("*.png")
    )

    if not frames:
        raise RuntimeError(
            f"No hay PNGs en {folder}"
        )

    index = (
        frame_index
        if frame_index >= 0
        else len(frames) + frame_index
    )

    if index < 0 or index >= len(frames):
        raise RuntimeError(
            f"frame-index {frame_index} fuera de rango; "
            f"hay {len(frames)} frames."
        )

    return frames[index]


def alpha_bbox(
    alpha: Image.Image,
    threshold: int,
):
    mask = alpha.point(
        lambda value: 255
        if value >= threshold
        else 0
    )

    return mask.getbbox()


def find_hole_components(
    alpha: Image.Image,
    bbox: tuple[int, int, int, int],
    threshold: int,
) -> list[dict[str, object]]:
    left, top, right, bottom = bbox
    width = right - left
    height = bottom - top

    pixels = alpha.load()

    solid = [
        [
            pixels[
                left + x,
                top + y,
            ] >= threshold
            for x in range(width)
        ]
        for y in range(height)
    ]

    exterior = [
        [False] * width
        for _ in range(height)
    ]

    queue: deque[
        tuple[int, int]
    ] = deque()

    def visit_background(
        x: int,
        y: int,
    ) -> None:
        if (
            0 <= x < width
            and 0 <= y < height
            and not exterior[y][x]
            and not solid[y][x]
        ):
            exterior[y][x] = True
            queue.append((x, y))

    for x in range(width):
        visit_background(x, 0)
        visit_background(
            x,
            height - 1,
        )

    for y in range(height):
        visit_background(0, y)
        visit_background(
            width - 1,
            y,
        )

    while queue:
        x, y = queue.popleft()

        for nx, ny in (
            (x + 1, y),
            (x - 1, y),
            (x, y + 1),
            (x, y - 1),
        ):
            visit_background(
                nx,
                ny,
            )

    hole = [
        [
            (
                not solid[y][x]
                and not exterior[y][x]
            )
            for x in range(width)
        ]
        for y in range(height)
    ]

    seen = [
        [False] * width
        for _ in range(height)
    ]

    components: list[
        dict[str, object]
    ] = []

    for y in range(height):
        for x in range(width):
            if (
                not hole[y][x]
                or seen[y][x]
            ):
                continue

            component_queue: deque[
                tuple[int, int]
            ] = deque(
                [(x, y)]
            )

            seen[y][x] = True
            points: list[
                tuple[int, int]
            ] = []

            while component_queue:
                cx, cy = (
                    component_queue.popleft()
                )

                points.append(
                    (
                        left + cx,
                        top + cy,
                    )
                )

                for nx, ny in (
                    (cx + 1, cy),
                    (cx - 1, cy),
                    (cx, cy + 1),
                    (cx, cy - 1),
                ):
                    if (
                        0 <= nx < width
                        and 0 <= ny < height
                        and hole[ny][nx]
                        and not seen[ny][nx]
                    ):
                        seen[ny][nx] = True
                        component_queue.append(
                            (nx, ny)
                        )

            xs = [
                point[0]
                for point in points
            ]

            ys = [
                point[1]
                for point in points
            ]

            components.append({
                "area": len(points),
                "points": points,
                "bbox": (
                    min(xs),
                    min(ys),
                    max(xs) + 1,
                    max(ys) + 1,
                ),
            })

    components.sort(
        key=lambda item: int(
            item["area"]
        ),
        reverse=True,
    )

    return components


def checkerboard(
    size: tuple[int, int],
    cell: int = 16,
) -> Image.Image:
    width, height = size

    out = Image.new(
        "RGBA",
        size,
        (
            245,
            245,
            245,
            255,
        ),
    )

    draw = ImageDraw.Draw(
        out
    )

    for y in range(
        0,
        height,
        cell,
    ):
        for x in range(
            0,
            width,
            cell,
        ):
            if (
                (x // cell)
                + (y // cell)
            ) % 2:
                draw.rectangle(
                    (
                        x,
                        y,
                        min(
                            width - 1,
                            x + cell - 1,
                        ),
                        min(
                            height - 1,
                            y + cell - 1,
                        ),
                    ),
                    fill=(
                        224,
                        224,
                        224,
                        255,
                    ),
                )

    return out


def main() -> int:
    args = parse_args()

    render_dir = (
        args.render_dir
        .resolve()
    )

    frame = find_frame(
        render_dir,
        args.direction,
        args.frame_index,
    )

    image = Image.open(
        frame
    ).convert(
        "RGBA"
    )

    alpha = image.getchannel(
        "A"
    )

    bbox = alpha_bbox(
        alpha,
        args.alpha_threshold,
    )

    if bbox is None:
        raise RuntimeError(
            "El frame no contiene píxeles visibles."
        )

    holes = find_hole_components(
        alpha,
        bbox,
        args.alpha_threshold,
    )

    base = checkerboard(
        image.size
    )

    base.alpha_composite(
        image
    )

    overlay = Image.new(
        "RGBA",
        image.size,
        (
            0,
            0,
            0,
            0,
        ),
    )

    overlay_pixels = (
        overlay.load()
    )

    # Yellow = partial-alpha pixels.
    alpha_pixels = (
        alpha.load()
    )

    for y in range(
        image.height
    ):
        for x in range(
            image.width
        ):
            value = alpha_pixels[
                x,
                y,
            ]

            if 0 < value < 255:
                overlay_pixels[
                    x,
                    y,
                ] = (
                    255,
                    215,
                    0,
                    150,
                )

    # Red = enclosed transparent holes.
    for component in holes:
        for x, y in component[
            "points"
        ]:
            overlay_pixels[
                x,
                y,
            ] = (
                255,
                0,
                0,
                220,
            )

    combined = Image.alpha_composite(
        base,
        overlay,
    )

    draw = ImageDraw.Draw(
        combined
    )

    for index, component in enumerate(
        holes,
        start=1,
    ):
        left, top, right, bottom = (
            component["bbox"]
        )

        draw.rectangle(
            (
                left - 1,
                top - 1,
                right,
                bottom,
            ),
            outline=(
                255,
                0,
                0,
                255,
            ),
            width=1,
        )

        label = (
            f"#{index} "
            f"{component['area']}px"
        )

        draw.text(
            (
                left,
                max(
                    0,
                    top - 12,
                ),
            ),
            label,
            fill=(
                255,
                0,
                0,
                255,
            ),
        )

    scale = max(
        1,
        args.scale,
    )

    enlarged = combined.resize(
        (
            combined.width * scale,
            combined.height * scale,
        ),
        Image.Resampling.NEAREST,
    )

    output_path = (
        args.output
        .resolve()
    )

    output_path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    enlarged.save(
        output_path
    )

    print(
        "Magic Symbols — Alpha Hole Visualizer"
    )
    print(
        f"Frame: {frame}"
    )
    print(
        f"Holes: {len(holes)}"
    )

    for index, component in enumerate(
        holes,
        start=1,
    ):
        print(
            f"  #{index}: "
            f"{component['area']} px "
            f"bbox={component['bbox']}"
        )

    print(
        f"OUTPUT {output_path}"
    )
    print(
        "Legend: RED=hole, YELLOW=partial alpha"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(
        main()
    )
