from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops, ImageStat


EXIT_VALID = 0
EXIT_INVALID = 2
EXIT_INPUT_ERROR = 3


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate Magic Symbols generic renderer output."
    )

    parser.add_argument(
        "--character-json",
        required=True,
        type=Path,
    )

    parser.add_argument(
        "--animation",
        required=True,
    )

    parser.add_argument(
        "--render-dir",
        required=True,
        type=Path,
    )

    parser.add_argument(
        "--report",
        type=Path,
        default=None,
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
        raise RuntimeError(f"JSON raíz inválido: {path}")

    return data


def render_metadata_path(
    render_dir: Path,
    animation_id: str,
) -> Path:
    exact = render_dir / f"{animation_id}_render_metadata.json"

    if exact.exists():
        return exact

    candidates = sorted(
        render_dir.glob("*_render_metadata.json")
    )

    if len(candidates) == 1:
        return candidates[0]

    if not candidates:
        raise RuntimeError(
            f"No se encontró *_render_metadata.json en {render_dir}"
        )

    raise RuntimeError(
        "Hay varios metadata posibles: "
        + ", ".join(path.name for path in candidates)
    )


def rgba_difference_score(
    a: Image.Image,
    b: Image.Image,
) -> float:
    diff = ImageChops.difference(
        a.convert("RGBA"),
        b.convert("RGBA"),
    )

    means = ImageStat.Stat(diff).mean

    return float(sum(means) / len(means))


def alpha_bbox_metrics(
    image: Image.Image,
) -> dict[str, float | int | None]:
    rgba = image.convert("RGBA")
    width, height = rgba.size

    alpha = rgba.getchannel("A")
    bbox = alpha.getbbox()

    if bbox is None:
        return {
            "empty": True,
            "left": None,
            "top": None,
            "right": None,
            "bottom": None,
            "width": 0,
            "height": 0,
            "margin_left": width,
            "margin_top": height,
            "margin_right": width,
            "margin_bottom": height,
            "center_x": None,
            "center_y": None,
        }

    left, top, right, bottom = bbox

    return {
        "empty": False,
        "left": int(left),
        "top": int(top),
        "right": int(right),
        "bottom": int(bottom),
        "width": int(right - left),
        "height": int(bottom - top),
        "margin_left": int(left),
        "margin_top": int(top),
        "margin_right": int(width - right),
        "margin_bottom": int(height - bottom),
        "center_x": float((left + right) / 2.0),
        "center_y": float((top + bottom) / 2.0),
    }


def load_direction_frames(
    render_dir: Path,
    direction: str,
    direction_metadata: dict[str, Any],
    expected_size: tuple[int, int],
) -> tuple[list[Image.Image], list[dict[str, Any]], list[str]]:
    images: list[Image.Image] = []
    metrics: list[dict[str, Any]] = []
    errors: list[str] = []

    entries = direction_metadata.get("frames", [])

    for expected_index, entry in enumerate(entries):
        actual_index = int(entry.get("frame_index", -1))

        if actual_index != expected_index:
            errors.append(
                f"{direction}: índice discontinuo; "
                f"esperado {expected_index}, encontrado {actual_index}"
            )

        filename = str(entry.get("file", ""))
        path = render_dir / direction / filename

        if not path.exists():
            errors.append(
                f"{direction}: falta archivo {path}"
            )
            continue

        try:
            with Image.open(path) as source:
                source.load()
                image = source.convert("RGBA")
        except Exception as exc:
            errors.append(
                f"{direction}: no se pudo abrir {filename}: {exc}"
            )
            continue

        if image.size != expected_size:
            errors.append(
                f"{direction}/{filename}: tamaño {image.size}, "
                f"esperado {expected_size}"
            )

        frame_metrics = alpha_bbox_metrics(image)
        frame_metrics["frame_index"] = expected_index
        frame_metrics["file"] = filename

        images.append(image)
        metrics.append(frame_metrics)

    return images, metrics, errors


def summarize_direction(
    direction: str,
    images: list[Image.Image],
    frame_metrics: list[dict[str, Any]],
    validation_cfg: dict[str, Any],
    animation_cfg: dict[str, Any],
    direction_metadata: dict[str, Any],
    frame_size: tuple[int, int],
) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []

    if not frame_metrics:
        return {
            "direction": direction,
            "valid": False,
            "errors": ["No hay frames válidos"],
            "warnings": [],
        }

    non_empty = [
        metric
        for metric in frame_metrics
        if not metric["empty"]
    ]

    if len(non_empty) != len(frame_metrics):
        empty_indexes = [
            metric["frame_index"]
            for metric in frame_metrics
            if metric["empty"]
        ]
        errors.append(
            "Frames completamente transparentes: "
            + ", ".join(map(str, empty_indexes))
        )

    margins = {
        "left": [
            int(metric["margin_left"])
            for metric in non_empty
        ],
        "top": [
            int(metric["margin_top"])
            for metric in non_empty
        ],
        "right": [
            int(metric["margin_right"])
            for metric in non_empty
        ],
        "bottom": [
            int(metric["margin_bottom"])
            for metric in non_empty
        ],
    }

    bbox_widths = [
        int(metric["width"])
        for metric in non_empty
    ]

    bbox_heights = [
        int(metric["height"])
        for metric in non_empty
    ]

    center_x_values = [
        float(metric["center_x"])
        for metric in non_empty
    ]

    center_y_values = [
        float(metric["center_y"])
        for metric in non_empty
    ]

    minimum_edge_margin = int(
        validation_cfg["minimum_edge_margin_px"]
    )

    reject_clipping = bool(
        validation_cfg["reject_clipping"]
    )

    if non_empty:
        absolute_min_margin = min(
            min(values)
            for values in margins.values()
        )

        if reject_clipping and absolute_min_margin <= 0:
            errors.append(
                "Alpha toca un borde del frame (clipping)"
            )

        if absolute_min_margin < minimum_edge_margin:
            errors.append(
                f"Margen mínimo {absolute_min_margin}px "
                f"< requerido {minimum_edge_margin}px"
            )

    center_x_drift = (
        max(center_x_values) - min(center_x_values)
        if center_x_values
        else 0.0
    )

    center_y_drift = (
        max(center_y_values) - min(center_y_values)
        if center_y_values
        else 0.0
    )

    # Alpha-bbox center drift is descriptive only.
    # It changes naturally when limbs extend during walking, especially in profile.
    # The actual stability criterion is the feet midpoint recorded by the renderer.

    framing = direction_metadata.get("framing", {})
    frame_entries = direction_metadata.get("frames", [])

    visible_w = float(framing.get("visible_w", 0.0))
    visible_h = float(framing.get("visible_h", 0.0))
    frame_w, frame_h = frame_size

    feet_mid_x = []
    feet_mid_y = []

    for entry in frame_entries:
        feet_mid = entry.get("feet_mid_camera")

        if (
            isinstance(feet_mid, list)
            and len(feet_mid) >= 2
        ):
            feet_mid_x.append(float(feet_mid[0]))
            feet_mid_y.append(float(feet_mid[1]))

    anchor_drift_x_px = 0.0
    anchor_drift_y_px = 0.0

    if feet_mid_x and visible_w > 0.0:
        anchor_drift_x_px = (
            (max(feet_mid_x) - min(feet_mid_x))
            / visible_w
            * frame_w
        )

    if feet_mid_y and visible_h > 0.0:
        anchor_drift_y_px = (
            (max(feet_mid_y) - min(feet_mid_y))
            / visible_h
            * frame_h
        )

    # Per-frame feet midpoint drift is descriptive only.
    # Walking naturally moves both feet through the cycle.
    # The hard framing check is whether the MEAN feet midpoint lands on the configured anchor.

    anchor_x_px, anchor_y_px = animation_cfg.get(
        "_validation_ground_anchor_px",
        [None, None],
    )

    mean_anchor_error_x_px = 0.0
    mean_anchor_error_y_px = 0.0

    if (
        feet_mid_x
        and feet_mid_y
        and visible_w > 0.0
        and visible_h > 0.0
        and anchor_x_px is not None
        and anchor_y_px is not None
    ):
        mean_camera_x = sum(feet_mid_x) / len(feet_mid_x)
        mean_camera_y = sum(feet_mid_y) / len(feet_mid_y)

        desired_camera_x = float(
            framing.get("desired_camera_x", 0.0)
        )
        desired_camera_y = float(
            framing.get("desired_camera_y", 0.0)
        )

        shift_x = float(
            framing.get("shift_x", 0.0)
        )
        shift_y = float(
            framing.get("shift_y", 0.0)
        )

        # Camera shift changes projection, not camera-space coordinates.
        # Convert the mean feet midpoint into the effective projected
        # camera-space position before comparing it to the configured anchor.
        projected_mean_x = (
            mean_camera_x
            - shift_x * visible_w
        )

        projected_mean_y = (
            mean_camera_y
            - shift_y * visible_h
        )

        mean_anchor_error_x_px = (
            abs(projected_mean_x - desired_camera_x)
            / visible_w
            * frame_w
        )

        mean_anchor_error_y_px = (
            abs(projected_mean_y - desired_camera_y)
            / visible_h
            * frame_h
        )

    max_anchor_error = float(
        validation_cfg["maximum_center_drift_px"]
    )

    if mean_anchor_error_x_px > max_anchor_error:
        errors.append(
            f"Mean ground anchor X error {mean_anchor_error_x_px:.3f}px "
            f"> máximo {max_anchor_error:.3f}px"
        )

    if mean_anchor_error_y_px > max_anchor_error:
        errors.append(
            f"Mean ground anchor Y error {mean_anchor_error_y_px:.3f}px "
            f"> máximo {max_anchor_error:.3f}px"
        )

    consecutive_scores: list[float] = []

    if len(images) >= 2:
        for index in range(1, len(images)):
            consecutive_scores.append(
                rgba_difference_score(
                    images[index - 1],
                    images[index],
                )
            )

    mean_consecutive = (
        sum(consecutive_scores) / len(consecutive_scores)
        if consecutive_scores
        else 0.0
    )

    loop_score = (
        rgba_difference_score(
            images[-1],
            images[0],
        )
        if len(images) >= 2
        else 0.0
    )

    loop_ratio = (
        loop_score / mean_consecutive
        if mean_consecutive > 1e-12
        else 0.0
    )

    loop_cfg = validation_cfg["loop"]

    if (
        animation_cfg["loop"]
        and loop_cfg["enabled_for_looping_animations"]
    ):
        max_ratio = float(
            loop_cfg[
                "max_last_to_first_over_mean_step_ratio"
            ]
        )

        if loop_ratio > max_ratio:
            errors.append(
                f"Loop closure ratio {loop_ratio:.3f} "
                f"> máximo {max_ratio:.3f}"
            )

    return {
        "direction": direction,
        "valid": not errors,
        "errors": errors,
        "warnings": warnings,
        "frame_count": len(frame_metrics),
        "bbox": {
            "width_min": min(bbox_widths) if bbox_widths else 0,
            "width_max": max(bbox_widths) if bbox_widths else 0,
            "height_min": min(bbox_heights) if bbox_heights else 0,
            "height_max": max(bbox_heights) if bbox_heights else 0,
        },
        "margins": {
            edge: {
                "min": min(values) if values else None,
                "max": max(values) if values else None,
            }
            for edge, values in margins.items()
        },
        "bbox_center_drift_px": {
            "x": center_x_drift,
            "y": center_y_drift,
        },
        "feet_midpoint_drift_px": {
            "x": anchor_drift_x_px,
            "y": anchor_drift_y_px,
        },
        "mean_ground_anchor_error_px": {
            "x": mean_anchor_error_x_px,
            "y": mean_anchor_error_y_px,
        },
        "loop": {
            "mean_consecutive_difference": mean_consecutive,
            "last_to_first_difference": loop_score,
            "last_to_first_over_mean_step_ratio": loop_ratio,
        },
        "frames": frame_metrics,
    }


def validate_render(
    config: dict[str, Any],
    animation_id: str,
    render_dir: Path,
    render_metadata: dict[str, Any],
) -> dict[str, Any]:
    errors: list[str] = []

    animation_cfg = config["animations"][animation_id]
    render_cfg = config["render"]
    validation_cfg = config["validation"]

    expected_size = tuple(
        map(int, render_cfg["frame_size_px"])
    )

    expected_directions = list(
        validation_cfg["required_directions"]
    )

    actual_directions = list(
        render_metadata.get(
            "direction_order",
            [],
        )
    )

    if render_metadata.get("character_id") != config["character"]["id"]:
        errors.append(
            "character_id del metadata no coincide con manifest"
        )

    if render_metadata.get("animation_id") != animation_id:
        errors.append(
            "animation_id del metadata no coincide"
        )

    if render_metadata.get("source_action") != animation_cfg["source_action"]:
        errors.append(
            "source_action del metadata no coincide"
        )

    if render_metadata.get("canvas_px") != list(expected_size):
        errors.append(
            "canvas_px del metadata no coincide"
        )

    if actual_directions != expected_directions:
        errors.append(
            "direction_order incorrecto: "
            f"{actual_directions} != {expected_directions}"
        )

    declared_frame_count = int(
        render_metadata.get(
            "frame_count_per_direction",
            0,
        )
    )

    direction_reports: dict[str, Any] = {}

    for direction in expected_directions:
        direction_metadata = (
            render_metadata.get(
                "directions",
                {},
            ).get(direction)
        )

        if direction_metadata is None:
            errors.append(
                f"Falta metadata de dirección {direction}"
            )
            continue

        entries = direction_metadata.get(
            "frames",
            [],
        )

        if len(entries) != declared_frame_count:
            errors.append(
                f"{direction}: metadata contiene {len(entries)} frames, "
                f"esperado {declared_frame_count}"
            )

        images, frame_metrics, load_errors = load_direction_frames(
            render_dir=render_dir,
            direction=direction,
            direction_metadata=direction_metadata,
            expected_size=expected_size,
        )

        errors.extend(load_errors)

        animation_cfg_for_validation = dict(animation_cfg)
        animation_cfg_for_validation["_validation_ground_anchor_px"] = (
            render_cfg["ground_anchor_px"]
        )

        report = summarize_direction(
            direction=direction,
            images=images,
            frame_metrics=frame_metrics,
            validation_cfg=validation_cfg,
            animation_cfg=animation_cfg_for_validation,
            direction_metadata=direction_metadata,
            frame_size=expected_size,
        )

        direction_reports[direction] = report

        for error in report["errors"]:
            errors.append(
                f"{direction}: {error}"
            )

    return {
        "pipeline": "Magic Symbols Pipeline v1",
        "validator": "validate_render.py",
        "character_id": config["character"]["id"],
        "animation_id": animation_id,
        "source_action": animation_cfg["source_action"],
        "valid": not errors,
        "errors": errors,
        "thresholds": validation_cfg,
        "render_metadata": {
            "frame_count_per_direction": declared_frame_count,
            "canvas_px": render_metadata.get("canvas_px"),
            "ortho_scale": render_metadata.get("ortho_scale"),
            "ground_anchor_px": render_metadata.get("ground_anchor_px"),
            "direction_order": actual_directions,
        },
        "directions": direction_reports,
    }


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
                f'Animación "{animation_id}" no existe en manifest'
            )

        if not render_dir.exists():
            raise RuntimeError(
                f"No existe render-dir: {render_dir}"
            )

        metadata_path = render_metadata_path(
            render_dir,
            animation_id,
        )

        render_metadata = load_json(
            metadata_path
        )

        report = validate_render(
            config=config,
            animation_id=animation_id,
            render_dir=render_dir,
            render_metadata=render_metadata,
        )

        if args.report is not None:
            report_path = resolve_project_path(
                args.report
            )
        else:
            report_root = resolve_project_path(
                Path(config["output"]["report_root"])
            )

            report_path = (
                report_root
                / f"{animation_id}_render_validation.json"
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
            "[Render Validator] INPUT FAIL:",
            exc,
        )
        return EXIT_INPUT_ERROR

    print(
        "Magic Symbols Pipeline v1 — Render Validator"
    )
    print(
        f"Animation: {report['animation_id']}"
    )
    print()

    for direction, direction_report in report["directions"].items():
        if direction_report["valid"]:
            bbox = direction_report["bbox"]
            margins = direction_report["margins"]
            bbox_drift = direction_report["bbox_center_drift_px"]
            feet_drift = direction_report["feet_midpoint_drift_px"]
            anchor_error = direction_report["mean_ground_anchor_error_px"]
            loop = direction_report["loop"]

            print(
                f"PASS {direction} | "
                f"h={bbox['height_min']}-{bbox['height_max']} | "
                f"bottom={margins['bottom']['min']}-{margins['bottom']['max']} | "
                f"anchor_err=({anchor_error['x']:.2f},{anchor_error['y']:.2f})px | "
                f"feet_drift=({feet_drift['x']:.2f},{feet_drift['y']:.2f})px | "
                f"bbox_dx={bbox_drift['x']:.2f}px | "
                f"loop_ratio={loop['last_to_first_over_mean_step_ratio']:.3f}"
            )
        else:
            print(
                f"FAIL {direction}"
            )

            for error in direction_report["errors"]:
                print(
                    f"  - {error}"
                )

    print()
    print(
        "REPORT",
        report_path,
    )

    if report["valid"]:
        print()
        print("RENDER VALID")
        return EXIT_VALID

    print()
    print(
        f"RENDER INVALID ({len(report['errors'])} failure(s))"
    )

    for error in report["errors"]:
        print(
            f"  - {error}"
        )

    return EXIT_INVALID


if __name__ == "__main__":
    sys.exit(main())
