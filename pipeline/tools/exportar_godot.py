#!/usr/bin/env python3
"""Exporta un personaje APROBADO a export_godot/characters/<id>/ (solo stdlib).

Uso: python exportar_godot.py <id> [--tipo characters|enemies] [--forzar]
Copia atlas + metadata, escribe meta.json y REPORTE.md. Si el REPORTE no
empieza por '# APROBADO' se niega (salvo --forzar).
"""
import json, shutil, sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PIPE, OUT, EXP = ROOT / "pipeline", ROOT / "pipeline_output", ROOT / "export_godot"


def main() -> int:
    args = sys.argv[1:]
    if "--tipo" in args:
        i = args.index("--tipo"); del args[i:i + 2]
    a = [x for x in args if not x.startswith("--")]
    if not a:
        print(__doc__); return 2
    cid = a[0]
    tipo = sys.argv[sys.argv.index("--tipo") + 1] if "--tipo" in sys.argv else "characters"
    if tipo not in ("characters", "enemies"):
        print("ERROR: --tipo debe ser characters o enemies"); return 2
    src = OUT / cid
    rep = src / "REPORTE.md"
    if not rep.exists():
        print(f"ERROR: no existe {rep}. Procesa antes el personaje."); return 1
    first = rep.read_text(encoding="utf-8").splitlines()[0]
    if not first.startswith("# APROBADO") and "--forzar" not in sys.argv:
        print(f"NO EXPORTADO: el reporte dice '{first}'. Corrige y vuelve a procesar."); return 1
    if not (src / "art" / "model").is_dir():
        print("NO EXPORTADO: falta la fase de arte (art\\model). Ejecuta PROCESAR_ARTE.cmd."); return 1
    cj = PIPE / "characters" / cid / "character.json"
    cfg = json.loads(cj.read_text(encoding="utf-8"))
    dest = EXP / tipo / cid
    if dest.exists():
        shutil.rmtree(dest)
    (dest / "atlases").mkdir(parents=True)

    anims, problems = {}, []
    for name, an in cfg["animations"].items():
        if not an.get("enabled", True):
            continue
        sd = src / "atlases" / name
        pngs = sorted(sd.glob("*.png")) if sd.is_dir() else []
        metas = sorted(sd.glob("*_metadata.json")) if sd.is_dir() else []
        if not pngs or not metas:
            problems.append(f"{name}: sin atlas o metadata en {sd}")
            continue
        (dest / "atlases" / name).mkdir()
        for f in pngs + metas:
            shutil.copy2(f, dest / "atlases" / name / f.name)
        anims[name] = {"frames": an["frame_count"], "fps": an["output_fps"], "loop": an["loop"],
                       "atlas_png": [f"atlases/{name}/{p.name}" for p in pngs],
                       "metadata": [f"atlases/{name}/{m.name}" for m in metas]}
    if problems:
        shutil.rmtree(dest)
        print("NO EXPORTADO:\n  " + "\n  ".join(problems)); return 1

    r = cfg["render"]
    meta = {
        "id": cid,
        "nombre": cfg["character"]["display_name"],
        "tipo": "character" if tipo == "characters" else "enemy",
        "direcciones": cfg["atlas"]["layout"]["direction_order"],
        "mapeo_direcciones_godot": cfg["godot"]["direction_mapping"],
        "frame_px": r["frame_size_px"],
        "ancla_suelo_px": r["ground_anchor_px"],
        "offset_visual_px": cfg["godot"]["visual_offset_px"],
        "asset_root_godot": cfg["godot"]["asset_root"],
        "layout_atlas": {"columnas": "frames", "filas": "direcciones"},
        "animaciones": anims,
        "origen_glb": f"pipeline_output/{cid}/art/model/npc_processed.glb",
        "altura_unidades": cfg["model"].get("expected_height_units", 1.7),
        "escala_relativa": float(cfg["model"].get("world_scale", 1.0)),   # ajustable por personaje en character.json (model.world_scale)
        "aprobado": date.today().isoformat(),
    }
    (dest / "meta.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
    shutil.copy2(rep, dest / "REPORTE.md")
    rv = src / "art" / "review"
    if rv.is_dir():
        shutil.copytree(rv, dest / "review", dirs_exist_ok=True)
    n = sum(1 for _ in dest.rglob("*") if _.is_file())
    print(f"EXPORTADO: {dest}  ({n} archivos)")
    demo = Path(__file__).resolve().parent / "godot_demo"
    if demo.is_dir():
        (EXP / "demo").mkdir(parents=True, exist_ok=True)
        for f in demo.glob("*"):
            shutil.copy2(f, EXP / "demo" / f.name)
        print("Demo: abre res://export_godot/demo/demo.tscn (WASD mover, Shift correr, Tab cambiar)")
    print(f"En Godot: copia la carpeta a {meta['asset_root_godot']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
