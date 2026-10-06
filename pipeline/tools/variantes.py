#!/usr/bin/env python3
"""Renderiza un personaje con varios estilos y genera una hoja de comparacion.

Uso:  python variantes.py <id> [estilo1,estilo2,...] [--solo-hoja]
Por defecto: base,anime_a,anime_b  (JSON en pipeline/profiles/styles/)
Salida: pipeline_output/<id>/estilos/<estilo>/renders/idle/<DIR>.png
        pipeline_output/<id>/estilos/comparacion.png
Necesita que el personaje haya pasado antes por la fase de arte (PROCESAR_ARTE).
"""
import json, re, subprocess, sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
PIPE, OUT = ROOT / "pipeline", ROOT / "pipeline_output"
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
STUDIO = ROOT / "Render Studio" / "MS_CHARACTER_RENDER_STUDIO.blend"
DIRS8 = "S,SW,W,NW,N,NE,E,SE"
SHOW = ["S", "SW", "E", "N"]


def work_dir(cid: str) -> Path | None:
    base = OUT / "npc_e2e"
    cands = []
    for p in base.glob(f"{cid}_art*"):
        m = re.fullmatch(rf"{re.escape(cid)}_art(\d*)", p.name)
        if m and (p / "character_art.json").exists():
            cands.append((int(m.group(1) or 1), p))
    return max(cands)[1] if cands else None


def render_style(work: Path, cid: str, style: str) -> bool:
    dest = OUT / cid / "estilos" / style
    (dest / "reports").mkdir(parents=True, exist_ok=True)
    cmd = [BLENDER, str(STUDIO), "--background", "--python", str(PIPE / "tools" / "render_npc_v2_5.py"),
           "--", "--character-json", str(work / "character_art.json"), "--directions", DIRS8,
           "--output", str(dest / "renders" / "idle"), "--report", str(dest / "reports" / "render.json"),
           "--style", style]
    print(f"\n=== Estilo {style} ===", flush=True)
    log = dest / "render.log"
    with open(log, "w", encoding="utf-8", errors="replace") as f:
        code = subprocess.call(cmd, stdout=f, stderr=subprocess.STDOUT)
    rep = dest / "reports" / "render.json"
    if code != 0 or not rep.exists():
        print(f"  FALLO (codigo {code}). Mira {log}")
        return False
    info = json.loads(rep.read_text(encoding="utf-8")).get("style", {})
    for e in info.get("errors", []):
        print(f"  AVISO estilo: {e}")
    print(f"  OK aplicado: {', '.join(info.get('applied', [])) or 'nada (base)'}")
    return True


def sheet(cid: str, styles: list[str]) -> Path | None:
    rows = []
    for st in styles:
        d = OUT / cid / "estilos" / st / "renders" / "idle"
        imgs = [d / f"{x}.png" for x in SHOW]
        if all(p.exists() for p in imgs):
            rows.append((st, [Image.open(p).convert("RGBA") for p in imgs]))
    if not rows:
        return None
    w, h = rows[0][1][0].size
    pad, lab = 8, 22
    # por fila: 4 vistas al 100% sobre verde + 4 al 50% sobre oscuro
    cw = len(SHOW) * (w + pad) + len(SHOW) * (w // 2 + pad) + pad
    rh = h + lab + pad
    img = Image.new("RGB", (cw, rh * len(rows) + pad), (30, 30, 34))
    dr = ImageDraw.Draw(img)
    for r, (name, ims) in enumerate(rows):
        y = pad + r * rh
        dr.text((pad, y + 4), name, fill=(235, 235, 235))
        x = pad
        for im in ims:
            bg = Image.new("RGBA", im.size, (92, 143, 60, 255))
            bg.alpha_composite(im)
            img.paste(bg.convert("RGB"), (x, y + lab))
            x += w + pad
        for im in ims:
            sm = im.resize((w // 2, h // 2), Image.LANCZOS)
            bg = Image.new("RGBA", sm.size, (35, 35, 43, 255))
            bg.alpha_composite(sm)
            img.paste(bg.convert("RGB"), (x, y + lab))
            x += w // 2 + pad
    out = OUT / cid / "estilos" / "comparacion.png"
    img.save(out)
    return out


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print(__doc__); return 2
    cid = args[0]
    styles = (args[1] if len(args) > 1 else "base,anime_a,anime_b").split(",")
    if "--solo-hoja" not in sys.argv:
        work = work_dir(cid)
        if not work:
            print(f"ERROR: no hay trabajo de arte para '{cid}' (npc_e2e\\{cid}_art*). Ejecuta PROCESAR_ARTE.cmd {cid}.")
            return 1
        print(f"Trabajo de arte: {work}")
        if not STUDIO.exists() or not Path(BLENDER).exists():
            print("ERROR: no se encuentra Blender o el Render Studio."); return 1
        for st in styles:
            render_style(work, cid, st)
    out = sheet(cid, styles)
    if out:
        print(f"\nHOJA DE COMPARACION: {out}")
        return 0
    print("\nNo se pudo generar la hoja (faltan renders).")
    return 1


if __name__ == "__main__":
    sys.exit(main())
