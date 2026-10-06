from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Sequence


EXIT_OK = 0
EXIT_BUILD_FAILED = 2
EXIT_INPUT_ERROR = 3

PROJECT_ROOT = Path(__file__).resolve().parents[2]

DEFAULT_BLENDER_WINDOWS = Path(
    r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
)


@dataclass(frozen=True)
class Step:
    name: str
    command: list[str]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Magic Symbols Pipeline v2 character orchestrator. "
            "Optionally assembles source GLBs, then runs the validated "
            "preflight, render and atlas pipeline."
        )
    )

    parser.add_argument(
        "character",
        nargs="?",
        default=None,
        help=(
            "Character ID, e.g. bookseller_test. "
            "Uses pipeline/characters/<id>/character.json."
        ),
    )

    parser.add_argument(
        "--character-json",
        type=Path,
        default=None,
        help=(
            "Explicit path to character.json. "
            "Overrides positional character ID."
        ),
    )

    parser.add_argument(
        "--blender",
        type=Path,
        default=None,
        help="Path to Blender executable.",
    )

    parser.add_argument(
        "--phase",
        choices=[
            "assemble",
            "preflight",
            "render",
            "atlas",
            "all",
        ],
        default="all",
        help=(
            "assemble=source GLBs -> master GLB; "
            "preflight=config+rig+animation audit; "
            "render=render+render validation; "
            "atlas=atlas build+atlas validation; "
            "all=everything."
        ),
    )

    parser.add_argument(
        "--assemble",
        choices=[
            "auto",
            "always",
            "never",
        ],
        default="auto",
        help=(
            "auto=rebuild master only when source/*.glb or the assembler "
            "is newer; always=force assembly; never=skip assembly."
        ),
    )

    parser.add_argument(
        "--bootstrap",
        choices=[
            "auto",
            "always",
            "never",
        ],
        default="auto",
        help=(
            "auto=prepare a new character folder when character.json or "
            "canonical source GLBs are missing; always=refresh bootstrap "
            "inputs; never=disable automatic bootstrap."
        ),
    )

    parser.add_argument(
        "--bootstrap-template",
        type=Path,
        default=None,
        help=(
            "Optional character.json used as bootstrap template. "
            "If omitted, a project template/reference character is selected."
        ),
    )

    parser.add_argument(
        "--assemble-sources",
        default=None,
        help=(
            'Optional comma-separated source IDs passed to the assembler, '
            'e.g. "idle,walk,run". If omitted, assembler discovery is used.'
        ),
    )

    parser.add_argument(
        "--animations",
        default="all",
        help=(
            'Comma-separated enabled animation IDs, e.g. "walk,idle", '
            'or "all". "all" means every enabled animation in character.json.'
        ),
    )

    parser.add_argument(
        "--skip-existing-renders",
        action="store_true",
        help=(
            "Backward-compatible flag. Smart incremental render skipping "
            "is now the default."
        ),
    )

    parser.add_argument(
        "--skip-existing-atlases",
        action="store_true",
        help=(
            "Backward-compatible flag. Smart incremental atlas skipping "
            "is now the default."
        ),
    )

    parser.add_argument(
        "--force-renders",
        action="store_true",
        help=(
            "Force regeneration of selected renders even when dependency "
            "timestamps indicate they are current."
        ),
    )

    parser.add_argument(
        "--force-atlases",
        action="store_true",
        help=(
            "Force regeneration of selected atlases even when dependency "
            "timestamps indicate they are current."
        ),
    )

    parser.add_argument(
        "--keep-derived-on-assemble",
        action="store_true",
        help=(
            "Do not invalidate existing render/atlas outputs when the master "
            "GLB is rebuilt. Normally those derived outputs are removed."
        ),
    )

    parser.add_argument(
        "--no-schema-bootstrap",
        action="store_true",
        help=(
            "Do not copy an existing identical character.schema.json into a "
            "new character folder when its local schema is missing."
        ),
    )

    parser.add_argument(
        "--sin-arte",
        action="store_true",
        help=(
            "Al terminar, no ejecutar la fase de arte (si no, se ejecuta cuando el master es "
            "mas nuevo que el arte que haya)."
        ),
    )

    parser.add_argument(
        "--sin-reporte",
        action="store_true",
        help=(
            "No escribir REPORTE.md al terminar (lo usa procesar_inbox.py, que lo escribe el)."
        ),
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print actions and commands without executing them.",
    )

    return parser.parse_args()


def resolve_project_path(path: Path) -> Path:
    if path.is_absolute():
        return path.resolve()

    return (PROJECT_ROOT / path).resolve()


def load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as file:
            data = json.load(file)

    except FileNotFoundError as exc:
        raise RuntimeError(
            f"No existe: {path}"
        ) from exc

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


def quote_command(command: Sequence[str]) -> str:
    if os.name == "nt":
        return subprocess.list2cmdline(
            list(command)
        )

    return shlex.join(command)


def ensure_file(path: Path, label: str) -> None:
    if not path.is_file():
        raise RuntimeError(
            f"{label} no existe: {path}"
        )


def find_blender(
    explicit: Path | None,
) -> Path:
    if explicit is not None:
        blender = resolve_project_path(
            explicit
        )
        ensure_file(
            blender,
            "Blender",
        )
        return blender

    env_value = os.environ.get(
        "BLENDER_EXE",
        "",
    ).strip()

    if env_value:
        blender = (
            Path(env_value)
            .expanduser()
            .resolve()
        )
        ensure_file(
            blender,
            "BLENDER_EXE",
        )
        return blender

    if DEFAULT_BLENDER_WINDOWS.is_file():
        return DEFAULT_BLENDER_WINDOWS

    discovered = shutil.which(
        "blender"
    )

    if discovered:
        return Path(
            discovered
        ).resolve()

    raise RuntimeError(
        "No se encontró Blender. Usa --blender "
        r'"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" '
        "o define BLENDER_EXE."
    )


def normalize_character_id(value: str) -> str:
    character_id = value.strip()

    if not character_id:
        raise RuntimeError(
            "El character ID está vacío."
        )

    if Path(character_id).name != character_id:
        raise RuntimeError(
            "El character ID debe ser únicamente el nombre de la carpeta."
        )

    if not re.fullmatch(
        r"[A-Za-z0-9][A-Za-z0-9_-]*",
        character_id,
    ):
        raise RuntimeError(
            "El character ID solo puede contener letras, números, "
            "guiones y guiones bajos."
        )

    return character_id


def character_display_name(character_id: str) -> str:
    words = re.split(
        r"[_-]+",
        character_id,
    )

    return " ".join(
        word[:1].upper() + word[1:]
        for word in words
        if word
    )


def character_dir_from_args(
    args: argparse.Namespace,
) -> Path:
    if args.character_json is not None:
        return resolve_project_path(
            args.character_json
        ).parent

    if not args.character:
        raise RuntimeError(
            "Indica un character ID o usa --character-json."
        )

    character_id = normalize_character_id(
        args.character
    )

    return resolve_project_path(
        Path("pipeline")
        / "characters"
        / character_id
    )


def source_role_from_filename(path: Path) -> str | None:
    stem = re.sub(
        r"[^a-z0-9]+",
        "_",
        path.stem.lower(),
    )

    tokens = {
        token
        for token in stem.split("_")
        if token
    }

    aliases = {
        "idle": {
            "idle",
            "idling",
        },
        "walk": {
            "walk",
            "walking",
        },
        "run": {
            "run",
            "running",
        },
    }

    matched = [
        role
        for role, names in aliases.items()
        if tokens & names
    ]

    if len(matched) == 1:
        return matched[0]

    exact = {
        "idle": "idle",
        "idling": "idle",
        "walk": "walk",
        "walking": "walk",
        "run": "run",
        "running": "run",
    }.get(
        path.stem.lower()
    )

    return exact


def discover_loose_glbs(
    character_dir: Path,
) -> list[Path]:
    candidates: list[Path] = []

    for folder in (
        character_dir,
        character_dir / "incoming",
    ):
        if not folder.is_dir():
            continue

        for path in sorted(
            folder.glob("*.glb")
        ):
            if path.name.endswith(
                "_master.glb"
            ):
                continue

            candidates.append(
                path.resolve()
            )

    return candidates


def canonicalize_source_glbs(
    character_dir: Path,
    force: bool,
    dry_run: bool,
) -> list[str]:
    source_dir = (
        character_dir
        / "source"
    )

    loose = discover_loose_glbs(
        character_dir
    )

    by_role: dict[
        str,
        list[Path],
    ] = {
        "idle": [],
        "walk": [],
        "run": [],
    }

    for path in loose:
        role = source_role_from_filename(
            path
        )

        if role is not None:
            by_role[role].append(
                path
            )

    for role, matches in by_role.items():
        if len(matches) > 1:
            raise RuntimeError(
                f'Bootstrap ambiguo para "{role}". '
                "Hay varios GLB candidatos: "
                + ", ".join(
                    str(path)
                    for path in matches
                )
            )

    changed: list[str] = []

    for role in (
        "idle",
        "walk",
        "run",
    ):
        destination = (
            source_dir
            / f"{role}.glb"
        )

        candidates = by_role[
            role
        ]

        if not candidates:
            continue

        source = candidates[0]

        should_copy = (
            force
            or not destination.is_file()
            or source.stat().st_mtime
            > destination.stat().st_mtime
            or source.stat().st_size
            != destination.stat().st_size
        )

        if not should_copy:
            continue

        print(
            "[BOOTSTRAP] Source:",
            f"{source.name} -> source/{role}.glb",
        )

        if not dry_run:
            source_dir.mkdir(
                parents=True,
                exist_ok=True,
            )

            shutil.copy2(
                source,
                destination,
            )

        changed.append(
            role
        )

    return changed


def template_character_candidates(
    character_dir: Path,
) -> list[Path]:
    preferred = [
        resolve_project_path(
            Path("pipeline")
            / "templates"
            / "character.template.json"
        ),
        resolve_project_path(
            Path("pipeline")
            / "templates"
            / "character.json"
        ),
        resolve_project_path(
            Path("pipeline")
            / "characters"
            / "bookseller_test"
            / "character.json"
        ),
        resolve_project_path(
            Path("pipeline")
            / "characters"
            / "adventurer"
            / "character.json"
        ),
    ]

    character_root = resolve_project_path(
        Path("pipeline")
        / "characters"
    )

    if character_root.is_dir():
        preferred.extend(
            sorted(
                character_root.glob(
                    "*/character.json"
                )
            )
        )

    result: list[Path] = []
    seen: set[Path] = set()

    for candidate in preferred:
        candidate = (
            candidate.resolve()
        )

        if candidate.parent == character_dir.resolve():
            continue

        if candidate in seen:
            continue

        seen.add(
            candidate
        )

        if candidate.is_file():
            result.append(
                candidate
            )

    return result


def select_bootstrap_template(
    explicit: Path | None,
    character_dir: Path,
) -> Path:
    if explicit is not None:
        template = resolve_project_path(
            explicit
        )

        ensure_file(
            template,
            "Bootstrap template",
        )

        return template

    candidates = template_character_candidates(
        character_dir
    )

    if not candidates:
        raise RuntimeError(
            "No existe ningún character.json que pueda usarse como "
            "plantilla de bootstrap. Crea pipeline/templates/"
            "character.template.json o usa --bootstrap-template."
        )

    return candidates[0]


def build_bootstrap_manifest(
    template: dict[str, Any],
    character_id: str,
) -> dict[str, Any]:
    manifest = json.loads(
        json.dumps(
            template
        )
    )

    character = manifest.setdefault(
        "character",
        {},
    )

    character[
        "id"
    ] = character_id

    character[
        "display_name"
    ] = character_display_name(
        character_id
    )

    character[
        "status"
    ] = "prototype"

    character[
        "source_model"
    ] = (
        Path("pipeline")
        / "characters"
        / character_id
        / f"{character_id}_master.glb"
    ).as_posix()

    model = manifest.setdefault(
        "model",
        {},
    )

    mesh_selection = model.setdefault(
        "mesh_selection",
        {},
    )

    mesh_selection[
        "preferred_mesh_name"
    ] = (
        f"{character_id}_Mesh"
    )

    godot = manifest.setdefault(
        "godot",
        {},
    )

    godot[
        "asset_root"
    ] = (
        f"res://assets/ms_{character_id}"
    )

    output = manifest.setdefault(
        "output",
        {},
    )

    output[
        "render_root"
    ] = (
        f"pipeline_output/{character_id}/renders"
    )

    output[
        "atlas_root"
    ] = (
        f"pipeline_output/{character_id}/atlases"
    )

    output[
        "report_root"
    ] = (
        f"pipeline_output/{character_id}/reports"
    )

    output[
        "godot_export_root"
    ] = (
        f"pipeline_output/{character_id}/godot"
    )

    return manifest


def write_bootstrap_manifest(
    character_dir: Path,
    character_id: str,
    template_path: Path,
    dry_run: bool,
) -> Path:
    target = (
        character_dir
        / "character.json"
    )

    template = load_json(
        template_path
    )

    manifest = build_bootstrap_manifest(
        template,
        character_id,
    )

    print(
        "[BOOTSTRAP] Manifest template:",
        template_path,
    )
    print(
        "[BOOTSTRAP] Manifest create:",
        target,
    )

    if not dry_run:
        character_dir.mkdir(
            parents=True,
            exist_ok=True,
        )

        target.write_text(
            json.dumps(
                manifest,
                indent=2,
                ensure_ascii=False,
            )
            + "\n",
            encoding="utf-8",
        )

    return target


def bootstrap_character(
    args: argparse.Namespace,
) -> Path:
    character_dir = character_dir_from_args(
        args
    )

    if not character_dir.is_dir():
        raise RuntimeError(
            "No existe la carpeta del personaje: "
            f"{character_dir}\n"
            "Créala y copia dentro los GLB de idle/walk/run."
        )

    if args.character_json is not None:
        character_json = resolve_project_path(
            args.character_json
        )

        inferred_id = character_dir.name
    else:
        inferred_id = normalize_character_id(
            args.character
        )

        character_json = (
            character_dir
            / "character.json"
        )

    bootstrap_enabled = (
        args.bootstrap != "never"
    )

    if bootstrap_enabled:
        canonicalize_source_glbs(
            character_dir=character_dir,
            force=(
                args.bootstrap
                == "always"
            ),
            dry_run=args.dry_run,
        )

    if character_json.is_file():
        return character_json

    if not bootstrap_enabled:
        raise RuntimeError(
            f"character.json no existe: {character_json}"
        )

    template_path = select_bootstrap_template(
        explicit=args.bootstrap_template,
        character_dir=character_dir,
    )

    return write_bootstrap_manifest(
        character_dir=character_dir,
        character_id=inferred_id,
        template_path=template_path,
        dry_run=args.dry_run,
    )


def resolve_character_json(
    args: argparse.Namespace,
) -> Path:
    return bootstrap_character(
        args
    )


def select_animations(
    config: dict[str, Any],
    value: str,
) -> list[str]:
    animations_cfg = config.get(
        "animations",
        {},
    )

    if not animations_cfg:
        raise RuntimeError(
            "character.json no contiene animaciones."
        )

    enabled = [
        animation_id
        for animation_id, animation_cfg
        in animations_cfg.items()
        if bool(
            animation_cfg.get(
                "enabled",
                True,
            )
        )
    ]

    if not enabled:
        raise RuntimeError(
            "character.json no contiene animaciones habilitadas."
        )

    if value.strip().lower() == "all":
        return enabled

    selected = [
        item.strip()
        for item in value.split(",")
        if item.strip()
    ]

    if not selected:
        raise RuntimeError(
            "--animations no contiene IDs válidos."
        )

    unknown = [
        animation_id
        for animation_id in selected
        if animation_id not in animations_cfg
    ]

    if unknown:
        raise RuntimeError(
            "Animaciones desconocidas: "
            + ", ".join(unknown)
        )

    disabled = [
        animation_id
        for animation_id in selected
        if not bool(
            animations_cfg[
                animation_id
            ].get(
                "enabled",
                True,
            )
        )
    ]

    if disabled:
        raise RuntimeError(
            "Animaciones seleccionadas pero deshabilitadas: "
            + ", ".join(disabled)
        )

    deduplicated: list[str] = []

    for animation_id in selected:
        if animation_id not in deduplicated:
            deduplicated.append(
                animation_id
            )

    return deduplicated


def project_relative_or_absolute(
    path_value: str | Path,
) -> Path:
    path = Path(
        path_value
    )

    if path.is_absolute():
        return path.resolve()

    return resolve_project_path(
        path
    )


def render_output_dir(
    config: dict[str, Any],
    animation_id: str,
) -> Path:
    character_id = str(
        config["character"]["id"]
    )

    output_cfg = config.get(
        "output",
        {},
    )

    render_root = output_cfg.get(
        "render_root"
    )

    if render_root:
        base = project_relative_or_absolute(
            render_root
        )
    else:
        base = resolve_project_path(
            Path("pipeline_output")
            / character_id
            / "renders"
        )

    return (
        base
        / f"{animation_id}_generic_8dir"
    )


def atlas_output_dir(
    config: dict[str, Any],
    animation_id: str,
) -> Path:
    character_id = str(
        config["character"]["id"]
    )

    output_cfg = config.get(
        "output",
        {},
    )

    atlas_root = output_cfg.get(
        "atlas_root"
    )

    if atlas_root:
        base = project_relative_or_absolute(
            atlas_root
        )
    else:
        base = resolve_project_path(
            Path("pipeline_output")
            / character_id
            / "atlases"
        )

    return (
        base
        / animation_id
    )


def render_root_dir(
    config: dict[str, Any],
) -> Path:
    output_cfg = config.get(
        "output",
        {},
    )

    value = output_cfg.get(
        "render_root"
    )

    if value:
        return project_relative_or_absolute(
            value
        )

    return resolve_project_path(
        Path("pipeline_output")
        / str(
            config["character"]["id"]
        )
        / "renders"
    )


def atlas_root_dir(
    config: dict[str, Any],
) -> Path:
    output_cfg = config.get(
        "output",
        {},
    )

    value = output_cfg.get(
        "atlas_root"
    )

    if value:
        return project_relative_or_absolute(
            value
        )

    return resolve_project_path(
        Path("pipeline_output")
        / str(
            config["character"]["id"]
        )
        / "atlases"
    )


def expected_render_metadata(
    render_dir: Path,
    animation_id: str,
) -> Path:
    exact = (
        render_dir
        / f"{animation_id}_render_metadata.json"
    )

    if exact.is_file():
        return exact

    candidates = sorted(
        render_dir.glob(
            "*_render_metadata.json"
        )
    )

    if len(candidates) == 1:
        return candidates[0]

    return exact


def expected_atlas_metadata(
    config: dict[str, Any],
    atlas_dir: Path,
    animation_id: str,
) -> Path:
    animation_cfg = (
        config[
            "animations"
        ][animation_id]
    )

    basename = animation_cfg.get(
        "atlas_basename",
        f"{animation_id}_8dir",
    )

    return (
        atlas_dir
        / f"{basename}_metadata.json"
    )


def remove_generated_dir(
    path: Path,
    dry_run: bool,
    label: str,
) -> None:
    if not path.exists():
        return

    print(
        f"[BUILD] CLEAN {label}: {path}"
    )

    if dry_run:
        return

    shutil.rmtree(
        path
    )


def run_step(
    step: Step,
    dry_run: bool,
) -> None:
    print()
    print("=" * 78)
    print(
        f"[BUILD] {step.name}"
    )
    print("=" * 78)
    print(
        quote_command(
            step.command
        )
    )
    print()

    if dry_run:
        print(
            "[BUILD] DRY RUN — skipped"
        )
        return

    started = (
        time.perf_counter()
    )

    completed = subprocess.run(
        step.command,
        cwd=PROJECT_ROOT,
        check=False,
    )

    elapsed = (
        time.perf_counter()
        - started
    )

    if completed.returncode != 0:
        raise RuntimeError(
            f'{step.name} falló con exit code '
            f"{completed.returncode} "
            f"tras {elapsed:.1f}s"
        )

    print(
        f"[BUILD] PASS {step.name} "
        f"({elapsed:.1f}s)"
    )


def python_step(
    name: str,
    script: Path,
    arguments: Sequence[str],
) -> Step:
    ensure_file(
        script,
        name,
    )

    return Step(
        name=name,
        command=[
            sys.executable,
            str(script),
            *arguments,
        ],
    )


def blender_step(
    name: str,
    blender: Path,
    script: Path,
    arguments: Sequence[str],
    blend_file: Path | None = None,
) -> Step:
    ensure_file(
        script,
        name,
    )

    command = [
        str(blender),
    ]

    if blend_file is not None:
        ensure_file(
            blend_file,
            "Render Studio .blend",
        )

        command.append(
            str(blend_file)
        )

    command.extend([
        "--background",
        "--python",
        str(script),
        "--",
        *arguments,
    ])

    return Step(
        name=name,
        command=command,
    )


def render_studio_blend(
    config: dict[str, Any],
) -> Path:
    render_cfg = config.get(
        "render",
        {},
    )

    configured = (
        render_cfg.get(
            "studio_blend"
        )
        or render_cfg.get(
            "blend_file"
        )
    )

    if configured:
        return project_relative_or_absolute(
            configured
        )

    return resolve_project_path(
        Path("Render Studio")
        / "MS_CHARACTER_RENDER_STUDIO.blend"
    )


def schema_candidates(
    target: Path,
) -> list[Path]:
    candidates = [
        resolve_project_path(
            Path("pipeline")
            / "schemas"
            / "character.schema.json"
        ),
        resolve_project_path(
            Path("pipeline")
            / "character.schema.json"
        ),
        resolve_project_path(
            Path("character.schema.json")
        ),
    ]

    character_root = resolve_project_path(
        Path("pipeline")
        / "characters"
    )

    if character_root.is_dir():
        candidates.extend(
            sorted(
                character_root.glob(
                    "*/character.schema.json"
                )
            )
        )

    unique: list[Path] = []
    seen: set[Path] = set()

    for candidate in candidates:
        resolved = candidate.resolve()

        if resolved == target.resolve():
            continue

        if resolved in seen:
            continue

        seen.add(
            resolved
        )

        if resolved.is_file():
            unique.append(
                resolved
            )

    return unique


def ensure_character_schema(
    character_json: Path,
    dry_run: bool,
    disabled: bool,
) -> None:
    target = (
        character_json.parent
        / "character.schema.json"
    )

    if target.is_file():
        return

    if disabled:
        raise RuntimeError(
            f"Falta character.schema.json junto al manifest: {target}"
        )

    candidates = schema_candidates(
        target
    )

    if not candidates:
        raise RuntimeError(
            "Falta character.schema.json y no existe ningún schema "
            "canónico/copíable dentro del proyecto."
        )

    content_groups: dict[
        bytes,
        list[Path],
    ] = {}

    for candidate in candidates:
        content = candidate.read_bytes()

        content_groups.setdefault(
            content,
            [],
        ).append(
            candidate
        )

    if len(content_groups) != 1:
        descriptions = []

        for paths in content_groups.values():
            descriptions.append(
                ", ".join(
                    str(path)
                    for path in paths
                )
            )

        raise RuntimeError(
            "Hay varias versiones diferentes de character.schema.json. "
            "No se copiará ninguna automáticamente. Versiones: "
            + " | ".join(descriptions)
        )

    source = candidates[0]

    print(
        "[BUILD] SCHEMA bootstrap:"
    )
    print(
        f"        from: {source}"
    )
    print(
        f"        to:   {target}"
    )

    if dry_run:
        return

    target.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    shutil.copy2(
        source,
        target,
    )


def parse_source_ids(
    value: str | None,
) -> list[str] | None:
    if value is None:
        return None

    result = [
        item.strip().lower()
        for item in value.split(",")
        if item.strip()
    ]

    if not result:
        raise RuntimeError(
            "--assemble-sources no contiene IDs válidos."
        )

    deduplicated: list[str] = []

    for item in result:
        if item not in deduplicated:
            deduplicated.append(
                item
            )

    return deduplicated


def assembly_inputs(
    character_dir: Path,
    selected_sources: list[str] | None,
) -> list[Path]:
    source_dir = (
        character_dir
        / "source"
    )

    if not source_dir.is_dir():
        return []

    if selected_sources is None:
        return sorted(
            source_dir.glob(
                "*.glb"
            )
        )

    result = []

    for source_id in selected_sources:
        path = (
            source_dir
            / f"{source_id}.glb"
        )

        if not path.is_file():
            raise RuntimeError(
                f"Falta source GLB solicitado: {path}"
            )

        result.append(
            path
        )

    return result


def master_model_path(
    character_dir: Path,
    character_id: str,
) -> Path:
    return (
        character_dir
        / f"{character_id}_master.glb"
    ).resolve()


def configured_source_model_path(
    config: dict[str, Any],
) -> Path:
    value = (
        config["character"]
        .get(
            "source_model",
            "",
        )
    )

    if not isinstance(
        value,
        str,
    ) or not value.strip():
        raise RuntimeError(
            "character.source_model está vacío."
        )

    return project_relative_or_absolute(
        value
    )


def assembly_is_stale(
    master_path: Path,
    source_glbs: Sequence[Path],
    assembler_script: Path,
) -> bool:
    if not master_path.is_file():
        return True

    master_mtime = (
        master_path.stat().st_mtime
    )

    inputs = [
        *source_glbs,
        assembler_script,
    ]

    return any(
        path.is_file()
        and path.stat().st_mtime
        > master_mtime
        for path in inputs
    )


def should_consider_assembly(
    phase: str,
) -> bool:
    return phase in (
        "assemble",
        "preflight",
        "render",
        "all",
    )


def run_assembly_pipeline(
    args: argparse.Namespace,
    config: dict[str, Any],
    character_json: Path,
    blender: Path,
    tools_dir: Path,
) -> bool:
    if args.assemble == "never":
        print(
            "[BUILD] ASSEMBLE disabled (--assemble never)"
        )
        return False

    if not should_consider_assembly(
        args.phase
    ):
        return False

    character_id = str(
        config["character"]["id"]
    )

    character_dir = (
        character_json.parent.resolve()
    )

    expected_character_dir = resolve_project_path(
        Path("pipeline")
        / "characters"
        / character_id
    )

    source_ids = parse_source_ids(
        args.assemble_sources
    )

    source_glbs = assembly_inputs(
        character_dir,
        source_ids,
    )

    if not source_glbs:
        if args.assemble == "always":
            raise RuntimeError(
                f"No hay source/*.glb en {character_dir}"
            )

        print(
            "[BUILD] ASSEMBLE skip: no source/*.glb"
        )
        return False

    if (
        character_dir
        != expected_character_dir
    ):
        raise RuntimeError(
            "El auto-assembler requiere que el manifest viva en "
            f"{expected_character_dir}. Actual: {character_dir}"
        )

    assembler_script = (
        tools_dir
        / "assemble_character_glb.py"
    )

    ensure_file(
        assembler_script,
        "Character assembler",
    )

    master_path = master_model_path(
        character_dir,
        character_id,
    )

    configured_model = (
        configured_source_model_path(
            config
        )
    )

    if (
        configured_model
        != master_path
    ):
        expected_relative = (
            Path("pipeline")
            / "characters"
            / character_id
            / f"{character_id}_master.glb"
        )

        raise RuntimeError(
            "Hay source/*.glb para auto-assembly, pero "
            "character.source_model no apunta al master generado.\n"
            f"Actual:   {configured_model}\n"
            f"Esperado: {master_path}\n"
            "Usa en character.json:\n"
            f'"source_model": "{expected_relative.as_posix()}"'
        )

    stale = assembly_is_stale(
        master_path,
        source_glbs,
        assembler_script,
    )

    force = (
        args.assemble == "always"
    )

    if not force and not stale:
        print(
            "[BUILD] ASSEMBLE up-to-date:",
            master_path,
        )
        return False

    assembler_args = [
        character_id,
        "--project-root",
        str(PROJECT_ROOT),
        "--blender",
        str(blender),
    ]

    if source_ids:
        assembler_args.extend(
            [
                "--sources",
                *source_ids,
            ]
        )

    run_step(
        python_step(
            "Assemble master GLB",
            assembler_script,
            assembler_args,
        ),
        args.dry_run,
    )

    if not args.dry_run:
        ensure_file(
            master_path,
            "Master GLB generado",
        )

    return True


def invalidate_derived_outputs(
    config: dict[str, Any],
    dry_run: bool,
) -> None:
    remove_generated_dir(
        render_root_dir(
            config
        ),
        dry_run,
        "render root after master rebuild",
    )

    remove_generated_dir(
        atlas_root_dir(
            config
        ),
        dry_run,
        "atlas root after master rebuild",
    )


def newest_mtime(paths: Sequence[Path]) -> float:
    existing = [
        path
        for path in paths
        if path.is_file()
    ]

    if not existing:
        return 0.0

    return max(
        path.stat().st_mtime
        for path in existing
    )


def output_is_current(
    output: Path,
    dependencies: Sequence[Path],
) -> bool:
    if not output.is_file():
        return False

    for dependency in dependencies:
        if not dependency.is_file():
            return False

    return (
        output.stat().st_mtime
        >= newest_mtime(
            dependencies
        )
    )


def render_dependencies(
    config: dict[str, Any],
    character_json: Path,
    tools_dir: Path,
    studio_blend: Path,
) -> list[Path]:
    # El modelo del que salen de verdad los atlas (master o GLB de arte, ver atlas_origen.py):
    # si cambia, hay que volver a renderizar. Con el master (por defecto) la lista es la de siempre,
    # asi que los renders ya validados siguen al dia.
    sys.path.insert(0, str(tools_dir))
    import atlas_origen

    modelo, _ = atlas_origen.modelo_atlas(
        config,
        configured_source_model_path(
            config
        ),
    )
    return [
        modelo,
        character_json,
        tools_dir
        / "render_character.py",
        studio_blend,
    ]


def atlas_dependencies(
    character_json: Path,
    tools_dir: Path,
    render_metadata: Path,
) -> list[Path]:
    return [
        character_json,
        tools_dir
        / "build_atlas.py",
        render_metadata,
    ]


def run_preflight(
    character_json: Path,
    blender: Path,
    tools_dir: Path,
    dry_run: bool,
) -> None:
    blender_common = [
        "--character-json",
        str(character_json),
    ]

    run_step(
        python_step(
            "Config validation",
            tools_dir
            / "validate_character_config.py",
            [
                str(character_json),
            ],
        ),
        dry_run,
    )

    run_step(
        blender_step(
            "Model / rig validation",
            blender,
            tools_dir
            / "validate_model_rig.py",
            blender_common,
        ),
        dry_run,
    )

    run_step(
        blender_step(
            "Animation audit",
            blender,
            tools_dir
            / "audit_animations.py",
            blender_common,
        ),
        dry_run,
    )


def run_render_pipeline(
    config: dict[str, Any],
    character_json: Path,
    animations: Sequence[str],
    blender: Path,
    tools_dir: Path,
    dry_run: bool,
    force: bool,
) -> None:
    studio_blend = render_studio_blend(
        config
    )

    for animation_id in animations:
        render_dir = render_output_dir(
            config,
            animation_id,
        )

        metadata_path = (
            expected_render_metadata(
                render_dir,
                animation_id,
            )
        )

        dependencies = render_dependencies(
            config=config,
            character_json=character_json,
            tools_dir=tools_dir,
            studio_blend=studio_blend,
        )

        current = output_is_current(
            metadata_path,
            dependencies,
        )

        should_render = (
            force
            or not current
        )

        if should_render:
            remove_generated_dir(
                render_dir,
                dry_run,
                f"render {animation_id}",
            )

            remove_generated_dir(
                atlas_output_dir(
                    config,
                    animation_id,
                ),
                dry_run,
                (
                    "downstream atlas "
                    f"{animation_id}"
                ),
            )

            run_step(
                blender_step(
                    (
                        "Render "
                        f"{animation_id}"
                    ),
                    blender,
                    tools_dir
                    / "render_character.py",
                    [
                        "--character-json",
                        str(json_para_render(config, character_json)),
                        "--animation",
                        animation_id,
                        "--output",
                        str(render_dir),
                    ],
                    blend_file=studio_blend,
                ),
                dry_run,
            )
        else:
            print()
            print(
                "[BUILD] SKIP render "
                f"{animation_id}: current"
            )
            print(
                f"        metadata: {metadata_path}"
            )

        run_step(
            python_step(
                (
                    "Render validation "
                    f"{animation_id}"
                ),
                tools_dir
                / "validate_render.py",
                [
                    "--character-json",
                    str(character_json),
                    "--animation",
                    animation_id,
                    "--render-dir",
                    str(render_dir),
                ],
            ),
            dry_run,
        )


def run_atlas_pipeline(
    config: dict[str, Any],
    character_json: Path,
    animations: Sequence[str],
    tools_dir: Path,
    dry_run: bool,
    force: bool,
) -> None:
    for animation_id in animations:
        render_dir = render_output_dir(
            config,
            animation_id,
        )

        atlas_dir = atlas_output_dir(
            config,
            animation_id,
        )

        metadata_path = (
            expected_atlas_metadata(
                config,
                atlas_dir,
                animation_id,
            )
        )

        render_metadata = (
            expected_render_metadata(
                render_dir,
                animation_id,
            )
        )

        dependencies = atlas_dependencies(
            character_json=character_json,
            tools_dir=tools_dir,
            render_metadata=render_metadata,
        )

        current = output_is_current(
            metadata_path,
            dependencies,
        )

        should_build = (
            force
            or not current
        )

        if should_build:
            remove_generated_dir(
                atlas_dir,
                dry_run,
                f"atlas {animation_id}",
            )

            run_step(
                python_step(
                    (
                        "Atlas build "
                        f"{animation_id}"
                    ),
                    tools_dir
                    / "build_atlas.py",
                    [
                        "--character-json",
                        str(character_json),
                        "--animation",
                        animation_id,
                        "--render-dir",
                        str(render_dir),
                        "--output",
                        str(atlas_dir),
                    ],
                ),
                dry_run,
            )
        else:
            print()
            print(
                "[BUILD] SKIP atlas "
                f"{animation_id}: current"
            )
            print(
                f"        metadata: {metadata_path}"
            )

        run_step(
            python_step(
                (
                    "Atlas validation "
                    f"{animation_id}"
                ),
                tools_dir
                / "validate_atlas.py",
                [
                    "--character-json",
                    str(character_json),
                    "--animation",
                    animation_id,
                    "--render-dir",
                    str(render_dir),
                    "--atlas-dir",
                    str(atlas_dir),
                ],
            ),
            dry_run,
        )


def json_para_render(config: dict[str, Any], character_json: Path) -> Path:
    """character.json para render_character.py. Si los atlas salen del GLB de la fase de arte
    (atlas_origen.py), una copia al lado (character.arte.json) con source_model apuntando a ese GLB."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import atlas_origen

    modelo, nota = atlas_origen.modelo_atlas(config, configured_source_model_path(config))
    print(f"[BUILD] {nota}")
    if atlas_origen.eleccion(config) != "arte" or modelo == configured_source_model_path(config):
        return character_json
    copia = json.loads(json.dumps(config))
    copia["character"]["source_model"] = str(modelo)
    destino = character_json.with_name("character.arte.json")
    destino.write_text(json.dumps(copia, indent=2, ensure_ascii=False), encoding="utf-8")
    return destino


def asegurar_requisitos() -> None:
    """jsonschema y Pillow: si faltan (build lanzado a mano, sin los .cmd), se instalan con este mismo Python."""
    try:
        import jsonschema  # noqa: F401
        import PIL  # noqa: F401
        return
    except ImportError:
        pass
    req = PROJECT_ROOT / "pipeline" / "tools" / "requirements.txt"
    print(f"Instalando requisitos de Python ({req.name}) para {sys.executable} ...")
    subprocess.call([sys.executable, "-m", "pip", "install", "--user", "-q", "-r", str(req)])


def main() -> int:
    """Build + cierre: fase de arte si hace falta y REPORTE.md al dia (cerrar_build.py), como el inbox."""
    asegurar_requisitos()
    codigo = construir()
    try:
        args = parse_args()
    except SystemExit:
        return codigo
    if args.sin_reporte or args.dry_run or args.phase != "all" or codigo == 130:
        return codigo
    cid = args.character
    if cid is None and args.character_json is not None:
        try:
            cid = load_json(resolve_project_path(args.character_json))["character"]["id"]
        except Exception:  # noqa: BLE001
            cid = None
    if not cid:
        return codigo
    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import cerrar_build

        cerrar_build.cerrar(str(cid), codigo, not args.sin_arte, "build_character.py")
    except Exception as exc:  # noqa: BLE001
        print(f"[BUILD] AVISO: no se pudo cerrar el reporte: {exc}")
    return codigo


def construir() -> int:
    try:
        args = parse_args()

        character_json = (
            resolve_character_json(
                args
            )
        )

        if (
            args.dry_run
            and not character_json.is_file()
        ):
            print()
            print("=" * 78)
            print("BOOTSTRAP DRY RUN VALID")
            print(
                "character.json se generaría en:"
            )
            print(
                character_json
            )
            print(
                "Ejecuta el mismo comando sin --dry-run "
                "para materializar el personaje."
            )
            print("=" * 78)
            return EXIT_OK

        ensure_file(
            character_json,
            "character.json",
        )

        ensure_character_schema(
            character_json=character_json,
            dry_run=args.dry_run,
            disabled=(
                args.no_schema_bootstrap
            ),
        )

        config = load_json(
            character_json
        )

        character_id = str(
            config["character"]["id"]
        )

        if (
            args.character is not None
            and args.character_json is None
            and args.character
            != character_id
        ):
            raise RuntimeError(
                "El ID solicitado no coincide con character.id: "
                f"{args.character} != {character_id}"
            )

        animations = (
            select_animations(
                config,
                args.animations,
            )
        )

        tools_dir = resolve_project_path(
            Path("pipeline")
            / "tools"
        )

        blender = find_blender(
            args.blender
        )

        print(
            "Magic Symbols Pipeline v2.1 "
            "— Character Builder"
        )
        print(
            f"Project:    {PROJECT_ROOT}"
        )
        print(
            f"Character:  {character_id}"
        )
        print(
            "Animations: "
            + ", ".join(
                animations
            )
        )
        print(
            f"Phase:      {args.phase}"
        )
        print(
            f"Assembly:   {args.assemble}"
        )
        print(
            f"Bootstrap:  {args.bootstrap}"
        )
        print(
            f"Blender:    {blender}"
        )
        print(
            f"Python:     {sys.executable}"
        )

        started = (
            time.perf_counter()
        )

        master_rebuilt = (
            run_assembly_pipeline(
                args=args,
                config=config,
                character_json=character_json,
                blender=blender,
                tools_dir=tools_dir,
            )
        )

        if (
            master_rebuilt
            and not args.keep_derived_on_assemble
        ):
            invalidate_derived_outputs(
                config=config,
                dry_run=args.dry_run,
            )

        if args.phase in (
            "preflight",
            "all",
        ):
            run_preflight(
                character_json=character_json,
                blender=blender,
                tools_dir=tools_dir,
                dry_run=args.dry_run,
            )

        if args.phase in (
            "render",
            "all",
        ):
            run_render_pipeline(
                config=config,
                character_json=character_json,
                animations=animations,
                blender=blender,
                tools_dir=tools_dir,
                dry_run=args.dry_run,
                force=(
                    args.force_renders
                ),
            )

        if args.phase in (
            "atlas",
            "all",
        ):
            run_atlas_pipeline(
                config=config,
                character_json=character_json,
                animations=animations,
                tools_dir=tools_dir,
                dry_run=args.dry_run,
                force=(
                    args.force_atlases
                ),
            )

        elapsed = (
            time.perf_counter()
            - started
        )

        print()
        print("=" * 78)
        print("BUILD VALID")
        print(
            f"Character: {character_id}"
        )
        print(
            "Animations: "
            + ", ".join(
                animations
            )
        )
        print(
            f"Phase: {args.phase}"
        )
        print(
            "Master: "
            + (
                "rebuilt"
                if master_rebuilt
                else "unchanged/skipped"
            )
        )
        print(
            f"Elapsed: {elapsed:.1f}s"
        )
        print("=" * 78)

        return EXIT_OK

    except KeyboardInterrupt:
        print()
        print(
            "[BUILD] CANCELLED BY USER"
        )
        return 130

    except Exception as exc:
        print()
        print("=" * 78)
        print("BUILD INVALID")
        print(
            str(exc)
        )
        print("=" * 78)
        return EXIT_BUILD_FAILED


if __name__ == "__main__":
    sys.exit(
        main()
    )
