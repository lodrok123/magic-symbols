#!/usr/bin/env python3
"""Cierra un build hecho A MANO (build_character.py <id>, PROCESAR.cmd rapido <id>...) igual que lo cierra
PROCESAR_PERSONAJES.cmd: fase de arte si hace falta y REPORTE.md nuevo con el veredicto de ESTE build.

Antes, solo procesar_inbox.py reescribia REPORTE.md: tras un build a mano se quedaba la cabecera vieja
(p. ej. "# RECHAZADO") y exportar_godot.py se negaba aunque el build hubiera ido bien. Y la fase de arte no
se ejecutaba, asi que el exportador lo decia al final, con los renders ya hechos.

    python pipeline/tools/cerrar_build.py <id> [--sin-arte] [--codigo N]

build_character.py lo llama solo al terminar (salvo --sin-reporte, que usa procesar_inbox.py).
La fase de arte solo se repite si el master es mas nuevo que el arte que hay (tarda unos minutos).
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import procesar_inbox as pi  # noqa: E402

ROOT = pi.ROOT
PIPE = pi.PIPE
OUT = pi.OUT


def _arte_guardado(cid: str) -> dict | None:
    """El resultado de la ultima fase de arte: art/art_result.json o, si no esta, la seccion del REPORTE viejo."""
    j = OUT / cid / "art" / "art_result.json"
    if j.is_file():
        try:
            art = json.loads(j.read_text(encoding="utf-8"))
            art.setdefault("notes", []).insert(0, "(fase de arte de una ejecucion anterior: el master no ha cambiado)")
            return art
        except Exception:  # noqa: BLE001
            pass
    rep = OUT / cid / "REPORTE.md"
    if not rep.is_file():
        return None
    m = re.search(r"^## Arte: (APROBADO|RECHAZADO)\n(.*?)(?=\nSalida:|\Z)", rep.read_text(encoding="utf-8"), re.S | re.M)
    if not m:
        return None
    lineas = [x[2:] if x.startswith("- ") else x for x in m.group(2).strip().splitlines() if x.strip()]
    return {"ran": False, "verdict": m.group(1), "checks": [], "sheets": [], "artifacts": [],
            "notes": ["(fase de arte de una ejecucion anterior, copiada del REPORTE previo: el master no ha cambiado)"] + lineas}


def _clasificacion(cid: str) -> dict:
    """Lo que write_report espera de procesar_inbox.classify(), sacado de character.json (no hay carpeta de inbox)."""
    cfg = json.loads((PIPE / "characters" / cid / "character.json").read_text(encoding="utf-8-sig"))
    files = []
    for aid, a in cfg.get("animations", {}).items():
        estado = "" if a.get("enabled", True) else "  [desactivada" + (f": {a['_desactivada']}" if a.get("_desactivada") else "") + "]"
        files.append({"name": f"{aid} (accion {a.get('source_action', '?')})", "role": aid, "why": "character.json" + estado,
                      "info": None})
    return {"files": files, "warnings": [], "display": cfg.get("character", {}).get("display_name", cid)}


def _estilo(cid: str) -> str:
    """Que estilo se aplico de verdad en los atlas (lo dice el metadata del render)."""
    for meta in sorted((OUT / cid / "renders").glob("*/*_render_metadata.json")):
        try:
            st = json.loads(meta.read_text(encoding="utf-8")).get("style") or {}
        except Exception:  # noqa: BLE001
            continue
        aplicado = ", ".join(st.get("applied", [])) or "nada"
        errores = "; ".join(st.get("errors", []))
        modelo = json.loads(meta.read_text(encoding="utf-8")).get("source_model", "")
        return (f"Estilo de los atlas: {st.get('name', 'base')} (aplicado: {aplicado})"
                + (f" ERRORES: {errores}" if errores else "") + f" | modelo: {Path(modelo).name}")
    return "Estilo de los atlas: (sin renders)"


def cerrar(cid: str, codigo: int, con_arte: bool = True, origen: str = "build a mano") -> str:
    master = PIPE / "characters" / cid / f"{cid}_master.glb"
    arte_glb = OUT / cid / "art" / "model" / "npc_processed.glb"
    _, malos, n = pi.collect_reports(cid)
    tecnico_ok = codigo == 0 and n > 0 and not malos
    art = None
    nota_arte = ""
    if con_arte and tecnico_ok:
        viejo = (not arte_glb.is_file()) or (master.is_file() and master.stat().st_mtime > arte_glb.stat().st_mtime)
        if viejo:
            print("\n  Fase de arte: el master es mas nuevo que el arte (o no hay arte). Se ejecuta ahora (unos minutos)...")
            import art_stage
            art = art_stage.run_art_stage(cid, OUT / cid / "art_stage.log")
            nota_arte = "fase de arte ejecutada en este cierre"
        else:
            art = _arte_guardado(cid)
            nota_arte = "fase de arte reutilizada (master sin cambios)"
    elif not con_arte:
        nota_arte = "sin fase de arte (--sin-arte)"
    cls = _clasificacion(cid)
    cls["warnings"].append(f"REPORTE escrito por cerrar_build.py tras un {origen} (codigo {codigo}); {nota_arte}.")
    cls["warnings"].append(_estilo(cid))
    veredicto = pi.write_report(cid, cls["display"], cls, codigo, cid, None, "", art)
    print(f"\n  >>> {veredicto}: pipeline_output/{cid}/REPORTE.md")
    return veredicto


def main() -> int:
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    if not a:
        print(__doc__)
        return 2
    codigo = 0
    if "--codigo" in sys.argv:
        codigo = int(sys.argv[sys.argv.index("--codigo") + 1])
        a = [x for x in a if x != str(codigo)]
    v = cerrar(a[0], codigo, "--sin-arte" not in sys.argv, "cierre manual")
    return 0 if v == "APROBADO" else 1


if __name__ == "__main__":
    sys.exit(main())
