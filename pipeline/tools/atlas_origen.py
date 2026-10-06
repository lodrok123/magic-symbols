"""De que modelo salen los ATLAS de un personaje (solo stdlib; lo usan build_character.py y art_stage.py).

  "master" (por defecto)  pipeline/characters/<id>/<id>_master.glb: el modelo de Meshy tal cual (look del master).
  "arte"                  pipeline_output/<id>/art/model/npc_processed.glb: el que deja la FASE DE ARTE (bake de
                          color, materiales limpios: el look pastel de las hojas de revision).

build_character.py se lo pasa a render_character.py (copia character.arte.json); con "master" no cambia nada
y los renders ya validados siguen al dia. Se elige, de mas a menos prioridad, con: la variable de entorno MS_ATLAS_DESDE, character.json render.modelo,
pipeline/config/ms.json "atlas_desde". Si se pide "arte" y no hay GLB de arte, se usa el master y se avisa.
Mientras no se decida el canon de la maga (master dorado/verde o arte pastel; docs/PLAN_ACCION_TEST2.md §2.1),
se queda en "master".
"""
from __future__ import annotations

import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def eleccion(config: dict) -> str:
    v = os.environ.get("MS_ATLAS_DESDE") or (config.get("render") or {}).get("modelo")
    if not v:
        try:
            v = json.loads((ROOT / "pipeline" / "config" / "ms.json").read_text(encoding="utf-8")).get("atlas_desde")
        except Exception:  # noqa: BLE001
            v = None
    return "arte" if str(v or "").lower() == "arte" else "master"


def modelo_arte(config: dict) -> Path:
    cid = str(config["character"]["id"])
    return ROOT / "pipeline_output" / cid / "art" / "model" / "npc_processed.glb"


def modelo_atlas(config: dict, master: Path) -> tuple[Path, str]:
    """(modelo con el que renderizar, nota para el log)."""
    if eleccion(config) != "arte":
        return master, "atlas desde el master"
    arte = modelo_arte(config)
    if arte.is_file():
        return arte, "atlas desde el GLB de la fase de arte"
    return master, f"AVISO: se pidio atlas desde el arte pero no existe {arte}; se usa el master"
