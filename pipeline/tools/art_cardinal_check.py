from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageStat


CARDINALS = ("S", "E", "N", "W")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Magic Symbols cardinal-direction art checker. "
            "Creates a large S/E/N/W comparison sheet and measures "
            "pixel differences between directional renders."
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
        "--frame-index",
        type=int,
        default=0,
    )
    parser.add_argument(
        "--scale",
        type=int,
        default=3,
        help="Nearest-neighbor enlargement factor. Default: 3.",
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
            f"frame-index {frame_index} fuera de rango para {direction}"
        )

    return frames[index]


def alpha_bbox(image: Image.Image):
    return image.getchannel("A").getbbox()


def normalize_rgba(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")

    # Transparent RGB values can vary even when invisible.
    blank = Image.new(
        "RGBA",
        rgba.size,
        (0, 0, 0, 0),
    )

    blank.alpha_composite(rgba)
    return blank


def pair_difference(
    a: Image.Image,
    b: Image.Image,
) -> dict[str, float]:
    a = normalize_rgba(a)
    b = normalize_rgba(b)

    if a.size != b.size:
        raise RuntimeError(
            f"Tamaños distintos: {a.size} vs {b.size}"
        )

    diff = ImageChops.difference(
        a,
        b,
    )

    stat = ImageStat.Stat(
        diff
    )

    mean_rgba = [
        float(value)
        for value in stat.mean
    ]

    extrema = diff.getbbox()

    width, height = a.size
    total_pixels = width * height

    if extrema is None:
        changed_bbox_area = 0
    else:
        left, top, right, bottom = extrema
        changed_bbox_area = (
            (right - left)
            * (bottom - top)
        )

    alpha_a = a.getchannel("A")
    alpha_b = b.getchannel("A")

    alpha_diff = ImageChops.difference(
        alpha_a,
        alpha_b,
    )

    alpha_stat = ImageStat.Stat(
        alpha_diff
    )

    return {
        "mean_abs_r": mean_rgba[0],
        "mean_abs_g": mean_rgba[1],
        "mean_abs_b": mean_rgba[2],
        "mean_abs_a": mean_rgba[3],
        "mean_abs_rgba": sum(mean_rgba) / 4.0,
        "alpha_mean_abs": float(
            alpha_stat.mean[0]
        ),
        "changed_bbox_area_ratio": (
            changed_bbox_area / total_pixels
            if total_pixels
            else 0.0
        ),
    }


def checker(
    size: tuple[int, int],
    cell: int = 16,
) -> Image.Image:
    w, h = size

    out = Image.new(
        "RGBA",
        size,
        (246, 246, 246, 255),
    )

    pixels = out.load()

    light = (
        246,
        246,
        246,
        255,
    )

    dark = (
        224,
        224,
        224,
        255,
    )

    for y in range(h):
        for x in range(w):
            pixels[x, y] = (
                dark
                if (
                    (x // cell)
                    + (y // cell)
                ) % 2
                else light
            )

    return out


def build_sheet(
    images: dict[str, Image.Image],
    scale: int,
) -> Image.Image:
    first = images[
        CARDINALS[0]
    ]

    width, height = first.size

    scaled_w = width * scale
    scaled_h = height * scale

    label_h = 42
    gap = 16
    margin = 20

    sheet = Image.new(
        "RGBA",
        (
            margin * 2
            + 4 * scaled_w
            + 3 * gap,
            margin * 2
            + label_h
            + scaled_h,
        ),
        (245, 245, 245, 255),
    )

    from PIL import ImageDraw

    draw = ImageDraw.Draw(
        sheet
    )

    for index, direction in enumerate(
        CARDINALS
    ):
        x = (
            margin
            + index * (
                scaled_w + gap
            )
        )

        y = (
            margin + label_h
        )

        bg = checker(
            (
                width,
                height,
            )
        )

        bg.alpha_composite(
            images[direction]
        )

        enlarged = bg.resize(
            (
                scaled_w,
                scaled_h,
            ),
            Image.Resampling.NEAREST,
        )

        sheet.alpha_composite(
            enlarged,
            (
                x,
                y,
            ),
        )

        draw.text(
            (
                x + scaled_w // 2,
                margin + label_h // 2,
            ),
            direction,
            fill=(
                0,
                0,
                0,
                255,
            ),
            anchor="mm",
        )

    return sheet


def main() -> int:
    args = parse_args()

    render_dir = args.render_dir.resolve()
    output_dir = args.output.resolve()

    output_dir.mkdir(
        parents=True,
        exist_ok=True,
    )

    images: dict[
        str,
        Image.Image,
    ] = {}

    files: dict[
        str,
        str,
    ] = {}

    for direction in CARDINALS:
        frame_path = find_frame(
            render_dir,
            direction,
            args.frame_index,
        )

        image = Image.open(
            frame_path
        ).convert(
            "RGBA"
        )

        images[direction] = image
        files[direction] = str(
            frame_path
        )

    sheet = build_sheet(
        images,
        max(
            1,
            args.scale,
        ),
    )

    sheet_path = (
        output_dir
        / "cardinal_SENW.png"
    )

    sheet.save(
        sheet_path
    )

    pairs = [
        ("S", "E"),
        ("S", "N"),
        ("S", "W"),
        ("E", "N"),
        ("E", "W"),
        ("N", "W"),
    ]

    differences = {}

    for a, b in pairs:
        key = f"{a}_vs_{b}"

        differences[key] = (
            pair_difference(
                images[a],
                images[b],
            )
        )

    report = {
        "render_dir": str(
            render_dir
        ),
        "frame_index": args.frame_index,
        "files": files,
        "bbox": {
            direction: (
                list(
                    alpha_bbox(
                        image
                    )
                )
                if alpha_bbox(
                    image
                )
                is not None
                else None
            )
            for direction, image
            in images.items()
        },
        "differences": differences,
    }

    report_path = (
        output_dir
        / "cardinal_direction_metrics.json"
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
        "Magic Symbols — Cardinal Direction Check"
    )
    print(
        f"Sheet:  {sheet_path}"
    )
    print(
        f"Report: {report_path}"
    )
    print()

    for key, values in differences.items():
        print(
            f"{key:8s} "
            f"RGBA={values['mean_abs_rgba']:.4f} "
            f"alpha={values['alpha_mean_abs']:.4f} "
            f"area={values['changed_bbox_area_ratio']:.4f}"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(
        main()
    )
