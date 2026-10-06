"""PROCESAR.cmd arte <id> [opciones]  -  banco de pruebas de direccion artistica.

Renderiza UN frame (idle por defecto) de un personaje en pocas direcciones con
varios estilos (toon / textura simplificada / contorno), y compone una hoja
comparativa sobre un bloque del terreno. NO ensambla, NO valida, NO hace atlas
y NO toca la exportacion ni el catalogo: solo escribe en
pipeline_output/arte_QA/<id>/.

Opciones:
  --estilos a,b,c     nombres de estilo (def.: base + m0..m6, cada uno anade una cosa al anterior; 'todos' = todos los de pipeline/tools/estilos/arte)
  --anim idle         animacion a usar
  --dirs SW,SE,NE     direcciones (def. SW,SE,NE)
  --frame 0.0..1.0    posicion en la animacion (def. 0.0)
  --escala 0.45       tamano del sprite en la hoja respecto al frame (0.45 = tamano de juego aprox.)
  --zoom 2            ampliacion de la hoja para verla mejor
  --solo-hoja         no renderiza: recompone la hoja con lo ya renderizado

Fondo: si existe pipeline_output/arte_QA/_fondo/*.png (mapa real de la escena) se usa como fondo.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PIPE = ROOT / "pipeline"
WORK = ROOT / "pipeline_output"
STYLES = HERE / "estilos" / "arte"


def _jload(p: Path, default=None):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:  # noqa: BLE001
        return default


def _opts(rest: list[str]) -> tuple[list[str], dict]:
    o = {"estilos": None, "anim": "idle", "dirs": "SW,SE,NE", "frame": "0.0", "solo_hoja": False, "escala": "0.45", "zoom": "2"}
    pos, i = [], 0
    while i < len(rest):
        a = rest[i]
        if a == "--solo-hoja":
            o["solo_hoja"] = True
        elif a.startswith("--") and i + 1 < len(rest):
            o[a[2:].replace("-", "_")] = rest[i + 1]
            i += 1
        else:
            pos.append(a)
        i += 1
    return pos, o


def _blender() -> str:
    ms = _jload(PIPE / "config" / "ms.json", {}) or {}
    return os.environ.get("BLENDER_EXE") or ms.get(
        "blender", r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe")


def _studio(cfg: dict) -> Path:
    r = cfg.get("render", {})
    c = r.get("studio_blend") or r.get("blend_file")
    if c:
        p = Path(c)
        return p if p.is_absolute() else ROOT / p
    return ROOT / "Render Studio" / "MS_CHARACTER_RENDER_STUDIO.blend"


def _style_list(sel: str | None) -> list[tuple[str, str]]:
    """[(nombre, spec)] ; spec 'base' = sin estilo, si no ruta absoluta al json."""
    out = [("a_base", "base")]
    files = sorted(STYLES.glob("*.json"))
    if not sel:
        default = ("n1_dos_bandas", "n2_sombra_tono", "n3_tres_bandas", "n4_textura", "n5_lineas", "n6_vivo")
        return out + [(p.stem, str(p)) for p in files if p.stem in default]
    if sel == "todos":
        return out + [(p.stem, str(p)) for p in files]
    if sel:
        want = [x.strip() for x in sel.split(",") if x.strip()]
        out = []
        for w in want:
            if w in ("base", "a_base"):
                out.append(("a_base", "base"))
                continue
            f = next((p for p in files if p.stem == w), None) or (Path(w) if Path(w).is_file() else None)
            if f is None:
                print(f"  ! estilo desconocido: {w}")
                continue
            out.append((f.stem, str(f)))
        return out
    return out + [(p.stem, str(p)) for p in files]


def _render_style(name: str, spec: str, cid: str, cjson: Path, cfg: dict, o: dict, outdir: Path) -> str:
    env = dict(os.environ)
    env["MS_CHAR_STYLE"] = spec  # 'base' desactiva el estilo
    env["MS_ONLY_FRAME"] = o["frame"]
    dst = outdir / name
    cmd = [_blender(), str(_studio(cfg)), "--background", "--python", str(HERE / "render_character.py"),
           "--", "--character-json", str(cjson), "--animation", o["anim"], "--output", str(dst),
           "--directions", o["dirs"]]
    r = subprocess.run(cmd, cwd=str(ROOT), env=env, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    (outdir / f"{name}.log").write_text((r.stdout or "") + "\n" + (r.stderr or ""), encoding="utf-8")
    return "OK" if r.returncode == 0 else f"ERROR({r.returncode})"


# --------------------------------------------------------------- composicion
def _terrain_tile():
    try:
        return _terrain_tile_inner()
    except Exception:  # noqa: BLE001  (sin numpy/scipy: se usa un rombo plano)
        return None


def _terrain_tile_inner():
    from PIL import Image
    import numpy as np
    from scipy import ndimage as ndi
    for sheet in sorted((PIPE / "scenes").glob("*/Terrain/Terreno.png")):
        a = np.asarray(Image.open(sheet).convert("RGB")).astype(int)
        nonwhite = a.min(axis=2) < 235
        lab, _ = ndi.label(ndi.binary_closing(nonwhite, iterations=3))
        found = []
        for i, sl in enumerate(ndi.find_objects(lab)):
            h = sl[0].stop - sl[0].start
            w = sl[1].stop - sl[1].start
            if w < 150 or h < 100:
                continue
            m = ndi.binary_fill_holes(lab[sl] == i + 1)
            rgba = np.dstack([a[sl].astype(np.uint8), (m * 255).astype(np.uint8)])
            found.append((round(sl[0].start / 200), sl[1].start, Image.fromarray(rgba, "RGBA")))
        found.sort(key=lambda t: (t[0], t[1]))
        if found:
            return found[0][2]
    return None


def _fondo():
    """Mapa real de la escena (pipeline_output/arte_QA/_fondo/*.png) para comparar en contexto."""
    from PIL import Image
    d = WORK / "arte_QA" / "_fondo"
    for p in sorted(d.glob("*.png")) if d.is_dir() else []:
        return Image.open(p).convert("RGBA")
    return None


# zona del mapa (campamento y camino) usada como fondo y punto de los pies, en pixeles del mapa
FONDO_BOX = (760, 520, 1060, 780)
FONDO_PIES = (150, 190)


def _compose(outdir: Path, styles: list[tuple[str, str]], dirs: list[str], anim: str, stamp: str,
             cfg: dict, escala: float = 0.45, zoom: int = 2) -> Path | None:
    from PIL import Image, ImageDraw, ImageFilter
    fondo = _fondo()
    rows = [(n, s) for n, s in styles if (outdir / n).is_dir()]
    if not rows:
        return None
    anchor = cfg.get("render", {}).get("ground_anchor_px", [128, 209])
    fsz = cfg.get("render", {}).get("frame_size_px", [256, 320])
    FW, FH = int(fsz[0] * escala), int(fsz[1] * escala)
    ax, ay = int(anchor[0] * escala), int(anchor[1] * escala)
    if fondo is not None:
        cw, ch = FONDO_BOX[2] - FONDO_BOX[0], FONDO_BOX[3] - FONDO_BOX[1]
    else:
        cw, ch = 300, 260
    LABEL = 150
    sheet = Image.new("RGBA", (LABEL + cw * len(dirs), ch * len(rows)), (30, 30, 36, 255))
    d = ImageDraw.Draw(sheet)
    for ri, (name, _s) in enumerate(rows):
        y0 = ri * ch
        d.text((6, y0 + 6), name, fill=(235, 235, 235))
        for ci, dr in enumerate(dirs):
            x0 = LABEL + ci * cw
            cell = fondo.crop(FONDO_BOX) if fondo is not None else Image.new("RGBA", (cw, ch), (124, 200, 60, 255))
            pngs = sorted((outdir / name / dr).glob("*.png"))
            if not pngs:
                ImageDraw.Draw(cell).text((10, 10), "sin render", fill=(255, 80, 80))
            else:
                px, py = FONDO_PIES
                sh = Image.new("RGBA", cell.size, (0, 0, 0, 0))
                ImageDraw.Draw(sh).ellipse((px - 24, py - 7, px + 24, py + 7), fill=(20, 30, 10, 90))
                cell.alpha_composite(sh.filter(ImageFilter.GaussianBlur(2)))
                im = Image.open(pngs[0]).convert("RGBA").resize((FW, FH), Image.LANCZOS)
                cell.alpha_composite(im, (px - ax, py - ay))
            sheet.alpha_composite(cell, (x0, y0))
            ImageDraw.Draw(sheet).text((x0 + 6, y0 + 6), dr, fill=(255, 255, 255))
    if zoom > 1:
        sheet = sheet.resize((sheet.width * zoom, sheet.height * zoom), Image.LANCZOS)
    dst = outdir / f"hoja_{anim}_{stamp}.png"
    sheet.convert("RGB").save(dst)
    return dst


def run(rest: list[str]) -> int:
    pos, o = _opts(rest)
    if not pos:
        print(__doc__)
        return 2
    cid = pos[0]
    cjson = PIPE / "characters" / cid / "character.json"
    cfg = _jload(cjson)
    if cfg is None:
        print(f"No existe {cjson}. Procesa antes el personaje (PROCESAR.cmd).")
        return 2
    if o["anim"] not in cfg.get("animations", {}):
        print(f"La animacion '{o['anim']}' no existe en {cid}. Disponibles:",
              ", ".join(cfg.get("animations", {})))
        return 2
    outdir = WORK / "arte_QA" / cid
    outdir.mkdir(parents=True, exist_ok=True)
    styles = _style_list(o["estilos"])
    dirs = [x.strip() for x in o["dirs"].split(",") if x.strip()]
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    lines = [f"# Prueba de arte: {cid}", "", f"Fecha: {stamp}  |  anim: {o['anim']}  |  dirs: {o['dirs']}  |  frame: {o['frame']}", ""]
    if not o["solo_hoja"]:
        if not Path(_blender()).exists():
            print(f"No se encuentra Blender: {_blender()}")
            return 2
        for name, spec in styles:
            print(f"  render {name} ...", flush=True)
            res = _render_style(name, spec, cid, cjson, cfg, o, outdir)
            print(f"    {res}")
            lines.append(f"- {name}: {res}")
            for md in (outdir / name).glob("*_render_metadata.json"):
                st = (_jload(md, {}) or {}).get("style", {})
                if st.get("errors"):
                    lines.append(f"    - errores de estilo: {st['errors']}")
                    print(f"    ! errores de estilo: {st['errors']}")
    try:
        sheet = _compose(outdir, styles, dirs, o["anim"], stamp, cfg, float(o["escala"]), int(o["zoom"]))
    except Exception as e:  # noqa: BLE001
        print(f"No se pudo componer la hoja ({type(e).__name__}: {e}). Los PNG sueltos estan en {outdir}")
        sheet = None
    (outdir / "REPORTE_ARTE.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print()
    print(f"Hoja comparativa: {sheet}" if sheet else f"Sin hoja. Revisa {outdir}")
    print(f"Estilos probados desde: {STYLES}")
    return 0 if sheet else 1
