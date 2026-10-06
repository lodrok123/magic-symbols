"""Magic Symbols - composicion del terreno del bosque a partir de imagenes 2D (solo Python + Pillow).

Uso:
  python ms_terrain_compose.py [--root RUTA] [--config ms_terrain_config.json] [--seed N] [--fire on|off|both]

Raiz de trabajo (en este orden): --root > variable MS_TERRAIN_ROOT > "root" del config > carpeta de este script.
Dentro de la raiz espera:  Assets/ (hojas 2D)  Materials/ (GLB del arbol)  Terrain/ (hoja de bloques)  y escribe en Output/.

Genera en Output/:
  map.png, map_sano.png (segun --fire), sprites/<tipo>/*.png (recortes listos para Godot), report.json, REPORTE.md
"""
from __future__ import annotations

import argparse
import json
import math
import os
import random
import sys
import traceback
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import ms_terrain_layout as L  # noqa: E402
import ms_blocks  # noqa: E402

MARK = (255, 0, 255)
IMG_EXT = {".png", ".jpg", ".jpeg", ".webp"}


# ---------------------------------------------------------------- utilidades de imagen
def cutout(im: Image.Image, thr: int = 40) -> Image.Image:
    """Quita el fondo claro conectado con el borde (flood fill). Solo Pillow."""
    rgb = im.convert("RGB")
    W, H = rgb.size
    near_white = lambda p: (765 - sum(p)) <= thr  # noqa: E731
    px = rgb.load()
    seeds = []
    step = 6
    for x in range(0, W, step):
        seeds += [(x, 0), (x, H - 1)]
    for y in range(0, H, step):
        seeds += [(0, y), (W - 1, y)]
    for s in seeds:
        if px[s] != MARK and near_white(px[s]):
            ImageDraw.floodfill(rgb, s, MARK, thresh=thr)
    alpha = Image.new("L", (W, H), 255)
    ap, rp = alpha.load(), rgb.load()
    for y in range(H):
        for x in range(W):
            if rp[x, y] == MARK:
                ap[x, y] = 0
    out = im.convert("RGBA")
    out.putalpha(alpha)
    return out


def crop_alpha(im: Image.Image) -> Image.Image:
    bb = im.getchannel("A").getbbox()
    return im.crop(bb) if bb else im


def slice_grid(sheet: Image.Image, cols: int, rows: int):
    W, H = sheet.size
    out = []
    for r in range(rows):
        row = []
        for c in range(cols):
            cell = sheet.crop((int(c * W / cols), int(r * H / rows), int((c + 1) * W / cols), int((r + 1) * H / rows)))
            row.append(crop_alpha(cell))
        out.append(row)
    return out


def sized_h(im: Image.Image, h: int) -> Image.Image:
    s = h / im.height
    return im.resize((max(1, round(im.width * s)), h), Image.LANCZOS)


def sized_w(im: Image.Image, w: int) -> Image.Image:
    s = w / im.width
    return im.resize((w, max(1, round(im.height * s))), Image.LANCZOS)


def tint(im: Image.Image, mul) -> Image.Image:
    r, g, b, a = im.split()
    f = lambda m: (lambda v: min(255, int(v * m)))  # noqa: E731
    return Image.merge("RGBA", (r.point(f(mul[0])), g.point(f(mul[1])), b.point(f(mul[2])), a))


def recolor(im: Image.Image, hue: float = 0.0, sat: float = 1.0, val: float = 1.0, greens_only: bool = True) -> Image.Image:
    """Cambia tono (grados), saturacion y valor conservando el alfa."""
    if abs(hue) < 0.01 and abs(sat - 1) < 0.001 and abs(val - 1) < 0.001:
        return im
    a = im.getchannel("A")
    h, sv, v = im.convert("RGB").convert("HSV").split()
    sh = int(round(hue * 255.0 / 360.0))
    lo, hi = int(70 * 255 / 360), int(210 * 255 / 360)      # verdes/azulados
    mask = h.point(lambda x: 255 if lo <= x <= hi else 0) if greens_only else None
    h2 = h.point(lambda x: (x + sh) % 256)
    sv2 = sv.point(lambda x: max(0, min(255, int(x * sat))))
    v2 = v.point(lambda x: max(0, min(255, int(x * val))))
    full = Image.merge("HSV", (h2, sv2, v2)).convert("RGB")
    if mask is not None:
        full = Image.composite(full, im.convert("RGB"), mask)     # troncos y marrones intactos
    out = full.convert("RGBA")
    out.putalpha(a)
    return out


def _dseg(x, y, p, q):
    px, py = p
    qx, qy = q
    dx, dy = qx - px, qy - py
    ln = math.hypot(dx, dy)
    t = ((x - px) * dx + (y - py) * dy) / (ln * ln)
    return abs((x - px) * dy - (y - py) * dx) / ln, t


def strip_diamond_outline(t: Image.Image) -> Image.Image:
    """Quita el contorno oscuro de las dos aristas frontales del rombo (evita costuras entre tiles)."""
    t = t.copy()
    w, h = t.size
    P = [(0, h - 32), (64, h - 1), (127, h - 32)]
    px = t.load()
    for y in range(max(0, h - 40), h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0 or (r + g + b) / 3 >= 95:
                continue
            for p, q in zip(P[:-1], P[1:]):
                d, tt = _dseg(x, y, p, q)
                if d <= 3.2 and y >= min(p[1], q[1]) - 3:
                    px[x, y] = (r, g, b, 0)
                    break
    return t


def outline_sprite(im: Image.Image, px: float = 1.6, dark: float = 0.3) -> Image.Image:
    """Contorno de color de material: extiende los colores del borde hacia fuera, los oscurece y los pone detras."""
    im = im.convert("RGBA")
    pad = int(math.ceil(px)) + 2
    big = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0))
    big.paste(im, (pad, pad))
    a = big.getchannel("A")
    k = max(3, int(2 * math.ceil(px) + 1))
    k += 1 - k % 2
    grow = a.filter(ImageFilter.MaxFilter(k))
    if px < math.ceil(px):                        # radio fraccionario: mezcla con el anterior
        k2 = max(1, k - 2)
        g2 = a.filter(ImageFilter.MaxFilter(k2)) if k2 > 1 else a
        t = (px - (math.ceil(px) - 1))
        grow = Image.blend(g2, grow, max(0.0, min(1.0, t)))
    try:
        import numpy as np
    except ImportError:                           # sin numpy: contorno de un solo color oscuro
        flat = Image.new("RGBA", big.size, (30, 36, 22, 255))
        flat.putalpha(grow)
        flat.alpha_composite(big)
        bb = flat.getchannel("A").getbbox()
        return flat.crop(bb) if bb else flat
    pm = Image.merge("RGBA", (ImageChops.multiply(big.getchannel("R"), a), ImageChops.multiply(big.getchannel("G"), a),
                             ImageChops.multiply(big.getchannel("B"), a), a))
    bl = pm.filter(ImageFilter.GaussianBlur(px * 2 + 1))
    arr = np.asarray(bl).astype(float)
    alpha = np.maximum(arr[..., 3:4], 1.0)
    col = np.clip(arr[..., :3] / alpha * 255.0, 0, 255) * dark
    ring = np.zeros(big.size[::-1] + (4,), dtype=np.uint8)
    ring[..., :3] = col.astype(np.uint8)
    ring[..., 3] = np.asarray(grow)
    out = Image.fromarray(ring, "RGBA")
    out.alpha_composite(big)
    bb = out.getchannel("A").getbbox()
    return out.crop(bb) if bb else out


def clean_edges(b: Image.Image, ul: bool, ur: bool, cy: int = 34) -> Image.Image:
    """Rellena (con el color de la cara superior) el contorno de las aristas traseras compartidas con otro bloque igual."""
    out = b.copy()
    src = b.load()
    dst = out.load()
    w, h = b.size
    edges = []
    if ul:
        edges.append(((0, cy), (64, cy - 32)))
    if ur:
        edges.append(((64, cy - 32), (128, cy)))
    kill = set()
    for y in range(0, cy + 6):
        for x in range(w):
            if src[x, y][3] == 0:
                continue
            for p, q in edges:
                d, t = _dseg(x, y, p, q)
                if d <= 5.4 and -0.03 <= t <= 1.03:
                    kill.add((x, y))
                    break
    for (x, y) in kill:
        vx, vy = 64 - x, cy - y
        n = math.hypot(vx, vy) or 1.0
        acc = []
        for r in (7, 9, 11):
            sx, sy = int(round(x + vx / n * r)), int(round(y + vy / n * r))
            if 0 <= sx < w and 0 <= sy < h and (sx, sy) not in kill and src[sx, sy][3] > 0:
                acc.append(src[sx, sy])
        if acc:
            m = len(acc)
            dst[x, y] = tuple(int(sum(p[i] for p in acc) / m) for i in range(3)) + (255,)
    return out


def make_flowers(rnd: random.Random, colors) -> Image.Image:
    S = 4
    W, H = 26 * S, 22 * S
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    n = rnd.randint(3, 5)
    for _ in range(n):
        x = rnd.randint(4 * S, W - 4 * S)
        y = rnd.randint(8 * S, H - 3 * S)
        top = y - rnd.randint(4 * S, 7 * S)
        d.line([(x, y), (x, top)], fill=(40, 110, 40, 255), width=S)
        col = tuple(rnd.choice(colors)) + (255,)
        r = rnd.randint(2 * S, 3 * S)
        for k in range(5):
            ang = k * 72 + rnd.randint(0, 20)
            px, py = x + math.cos(math.radians(ang)) * r, top + math.sin(math.radians(ang)) * r
            d.ellipse([px - r * .8, py - r * .8, px + r * .8, py + r * .8], fill=col, outline=(70, 40, 25, 255))
        d.ellipse([x - r * .55, top - r * .55, x + r * .55, top + r * .55], fill=(255, 214, 80, 255), outline=(70, 40, 25, 255))
    return im.resize((W // S, H // S), Image.LANCZOS)


def make_leaves(rnd: random.Random, colors) -> Image.Image:
    S = 4
    W, H = 30 * S, 14 * S
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for _ in range(rnd.randint(4, 8)):
        x, y = rnd.randint(3 * S, W - 3 * S), rnd.randint(3 * S, H - 3 * S)
        a, b = rnd.randint(2 * S, 3 * S), rnd.randint(1 * S, 2 * S)
        d.ellipse([x - a, y - b, x + a, y + b], fill=tuple(rnd.choice(colors)) + (255,), outline=(80, 45, 25, 255))
    return im.resize((W // S, H // S), Image.LANCZOS)


# ---------------------------------------------------------------- arte 3D (terreno3d.py --sprites)
ART3D = HERE.parents[1] / "assets3d" / "terreno"


def apply_art3d(cfg, lib, out):
    """Si hay sprites renderizados en 3D (pipeline/assets3d/terreno/{blocks,props}/*.png) sustituyen a los pintados."""
    if not cfg.get("art3d", True) or not ART3D.exists():
        return
    nb = npp = 0
    for f in sorted((ART3D / "blocks").glob("*.png")) if (ART3D / "blocks").exists() else []:
        img = Image.open(f).convert("RGBA")
        if img.size != (128, 102):
            lib.warn.append(f"art3d: {f.name} mide {img.size}, se esperaba (128, 102); se ignora")
            continue
        n = f.stem
        lib.blocks[n] = img
        if n in lib.block_vars:
            lib.block_vars[n] = [img]
            lib.b3d[n] = img
        dump(img, out, "blocks", n)
        nb += 1
    for f in sorted((ART3D / "props").glob("*.png")) if (ART3D / "props").exists() else []:
        img = Image.open(f).convert("RGBA")
        if img.getchannel("A").getbbox() is None:
            lib.warn.append(f"art3d: {f.name} vacio, se ignora")
            continue
        lib.props[f.stem] = crop_alpha(img)
        dump(lib.props[f.stem], out, "props", f.stem)
        npp += 1
    lib.info.append(f"art3d: {nb} bloques y {npp} props renderizados en 3D")


# ---------------------------------------------------------------- carga
class Lib:
    def __init__(self):
        self.blocks = {}      # nombre -> imagen 128 de ancho
        self.block_vars = {}  # nombre -> [variantes] (bloques procedurales)
        self.proc = None
        self.b3d = {}         # bloques renderizados en 3D (sustituyen a los pintados)
        self.props = {}       # nombre -> imagen
        self.grass = {}       # (estado, k) -> imagen
        self.clumps = {}      # (estado, nombre) -> imagen
        self.trees = {}       # nombre -> imagen
        self.warn = []
        self.info = []


def first_image(folder: Path):
    if not folder.exists():
        return None
    files = sorted(p for p in folder.iterdir() if p.suffix.lower() in IMG_EXT)
    return files[0] if files else None


def dump(img, root_out: Path, kind: str, name: str):
    d = root_out / "sprites" / kind
    d.mkdir(parents=True, exist_ok=True)
    img.save(d / f"{name}.png")


def load_library(cfg, root: Path, out: Path) -> Lib:
    lib = Lib()
    fol = cfg["folders"]
    assets = root / fol["assets"]
    # terreno
    ts = cfg["terrain_sheet"]
    tf = (root / fol["terrain"] / ts["file"]) if ts.get("file") else first_image(root / fol["terrain"])
    if not tf or not tf.exists():
        lib.warn.append(f"No hay hoja de terreno en {root / fol['terrain']}")
    else:
        cols, rows = ts["grid"]
        cells = slice_grid(cutout(Image.open(tf)), cols, rows)
        for r in range(rows):
            for c in range(cols):
                img = sized_w(cells[r][c], int(ts.get("block_width_px", 128)))
                name = ts["names"][r][c]
                lib.blocks[name] = img
                dump(img, out, "blocks", name)
        lib.info.append(f"terreno: {tf.name} -> {len(lib.blocks)} bloques")
    pb = cfg.get("procedural_blocks", {})
    if pb.get("enabled", True):
        kinds = tuple(pb.get("kinds", ["dirt", "path", "water"]))
        nvar = int(pb.get("variants", 3))
        lib.proc = {"kinds": kinds, "n": nvar, "over": pb.get("overrides") or {}}
        gen = ms_blocks.make_all(kinds, nvar, pb.get("overrides"))
        for k, lst in gen.items():
            lib.block_vars[k] = lst
            lib.blocks[k] = lst[0]
            for i, b in enumerate(lst):
                dump(b, out, "blocks", f"{k}_proc{i}")
        lib.info.append(f"bloques procedurales: {', '.join(kinds)} x {nvar} variantes")
    # hojas 2D
    for sh in cfg["sheets"]:
        f = assets / sh["file"]
        if not f.exists():
            lib.warn.append(f"Falta {f}")
            continue
        cols, rows = sh["grid"]
        cells = slice_grid(cutout(Image.open(f)), cols, rows)
        typ = sh["type"]
        if typ == "props":
            for r in range(rows):
                for c in range(cols):
                    n = sh["names"][r][c]
                    img = sized_h(cells[r][c], int(sh["heights"][n]))
                    lib.props[n] = img
                    dump(img, out, "props", n)
        elif typ == "grass_states":
            for si, st in enumerate(sh["states"]):
                for k in range(cols):
                    img = sized_w(cells[si][k], 128)
                    if sh.get("strip_diamond_outline", True):
                        img = strip_diamond_outline(img)
                    lib.grass[(st, k)] = img
                    dump(img, out, "grass", f"hierba_{st}_{k}")
        elif typ == "clump_states":
            for si, st in enumerate(sh["states"]):
                for ci, n in enumerate(sh["names"]):
                    img = sized_h(cells[si][ci], int(sh.get("height", 46)))
                    lib.clumps[(st, n)] = img
                    dump(img, out, "clumps", f"mata_{n}_{st}")
        lib.info.append(f"{f.name}: {typ} ok")
    # arbol (render de Blender): uno o varios angulos
    tr = cfg["tree"]
    tdir = out / "trees"
    files = sorted(tdir.glob("tree_a*.png")) if tdir.exists() else []
    legacy = out / tr.get("render_png", "trees/tree_base.png")
    if not files and legacy.exists():
        files = [legacy]
    bases = []
    for f in files:
        im = Image.open(f).convert("RGBA")
        if im.getchannel("A").getbbox() is None:
            lib.warn.append(f"El render del arbol esta VACIO (todo transparente): {f}. Mira render_tree.log")
        else:
            bases.append(crop_alpha(im))
    if not bases:
        lib.warn.append(f"Sin arbol: no hay renders validos en {tdir}. Ejecuta el paso Blender o pon los PNG ahi.")
    else:
        for name, v in tr["variants"].items():
            lst = []
            for base in bases:
                img = sized_h(tint(recolor(base, v.get("hue", 0), v.get("sat", 1), v.get("val", 1)), v.get("tint", [1, 1, 1])), int(v["h"]))
                if abs(v.get("w_scale", 1.0) - 1.0) > 0.01:
                    img = img.resize((max(1, int(img.width * v["w_scale"])), img.height), Image.LANCZOS)
                oc = tr.get("outline")      # contorno Pillow (desactivado: el contorno va en el render 3D, outline_3d)
                if oc and oc.get("enabled", True):
                    img = outline_sprite(img, float(oc.get("px", 1.6)), float(oc.get("dark", 0.3)))
                lst.append(img)
            lib.trees[name] = lst
            for i, im in enumerate(lst):
                dump(im, out, "trees", f"{name}_{i}")
        lib.info.append(f"arbol: {len(bases)} angulos x {len(tr['variants'])} variantes = {len(bases) * len(tr['variants'])} sprites")
    apply_art3d(cfg, lib, out)
    return lib


# ---------------------------------------------------------------- composicion
def compose(cfg, lib: Lib, root: Path, out: Path, seed: int, fire_on: bool, dest: Path):
    mp = L.load_json(root / cfg["map"] if (root / cfg["map"]).exists() else HERE / cfg["map"])
    w, h, tiles = L.parse_map(mp["rows"], mp["legend"])
    placed = L.place_props(w, h, tiles, mp["rules"], seed, mp.get("fixed"))
    props = dict(lib.props)
    placed = [p for p in placed if p["prop"] in props or p["prop"] in lib.trees or p["prop"] in ("bush", "bush_berry")]

    fc = cfg["fire"]
    nr = random.Random(int(fc.get("seed", 11)))
    noise = {k: nr.random() for k in tiles}
    org = fc.get("origin", "auto")
    FIRE = (w - 4, 3) if org == "auto" else tuple(org)

    def bstate(ix, iy):
        if not fire_on:
            return 0
        d = math.hypot(ix - FIRE[0], iy - FIRE[1]) + noise[(ix, iy)] * float(fc.get("noise", 2.2))
        return 2 if d < fc["burnt_radius"] else (1 if d < fc["scorched_radius"] else 0)

    KB = {"grass": "grass", "forest_grass": "forest_grass", "moss": "moss", "dirt": "dirt", "path": "path",
          "stone": "stone", "water": "water", "mud": "mud"}
    VEG = ("grass", "forest_grass", "moss")

    def eff(ix, iy):
        k = tiles[(ix, iy)]
        st = bstate(ix, iy) if k in VEG else 0
        return KB[k] if st < 2 else "dirt"

    def sc0(x, y):
        return ((x + y) * 64, (x - y) * 32)

    pos = {}
    for (ix, iy) in tiles:
        x, y = L.tile_xy(ix, iy, w, h)
        pos[sc0(x, y)] = (ix, iy)
    cache = {}

    GRASSY = ("grass", "forest_grass", "moss")
    LAND = ("grass", "forest_grass", "moss", "dirt", "path", "stone", "mud")

    def block_for(ix, iy):
        x, y = L.tile_xy(ix, iy, w, h)
        px, py = sc0(x, y)
        me = eff(ix, iy)
        pbc = cfg.get("procedural_blocks", {})
        trans = pbc.get("transitions", True)
        offs = ((-64, -32), (64, -32), (64, 32), (-64, 32))        # UL UR DR DL
        nb = []
        for dx, dy in offs:
            n = pos.get((px + dx, py + dy))
            nb.append(eff(*n) if n is not None else None)
        f = [nb[0] == me, nb[1] == me]
        fr = [False] * 4
        frkind = None
        if trans and me in ("path", "dirt"):
            fr = [n in GRASSY for n in nb]
            frkind = "grass_on_dirt"
        elif trans and me == "water":
            fr = [n in LAND for n in nb]
            frkind = "sand_on_water"
        # contorno trasero a quitar: bloques iguales o pares con transicion (tierra/hierba, agua/tierra)
        def pair(n):
            if n is None:
                return False
            return ((me in ("path", "dirt") and n in GRASSY) or (me in GRASSY and n in ("path", "dirt"))
                    or (me == "water" and n in LAND) or (me in LAND and n == "water"))
        cl = [f[0] or (trans and pair(nb[0])), f[1] or (trans and pair(nb[1]))]
        vl = lib.block_vars.get(me)
        vi = (ix * 7 + iy * 13) % len(vl) if vl else 0
        shore = None
        if me == "water" and pbc.get("water_rim", True):
            shore = tuple(n is None or n != "water" for n in nb)
        is_proc = me in lib.block_vars
        if is_proc:
            def keep(n, i):          # contorno de la arista solo si el vecino falta o es de otro tipo sin transicion
                return n is None or (n != me and not (trans and pair(n)))
            edges = tuple(keep(nb[i], i) for i in range(4))
            key = (me, vi, edges, shore, tuple(fr), (px, py) if any(fr) else None)
        else:
            key = (me, vi, tuple(cl), shore, tuple(fr), None)
        if key not in cache:
            if is_proc and me in lib.b3d:
                b = lib.b3d[me].copy()
                if any(cl):
                    b = clean_edges(b, cl[0], cl[1], int(cfg["terrain_sheet"].get("top_center_y", 34)))
            elif is_proc:
                b = ms_blocks.make_block(me, vi, lib.proc["over"].get(me), edges)
            else:
                b = vl[vi] if vl else lib.blocks[me]
            if shore and any(shore):
                b = ms_blocks.water_rim(b, shore, pbc.get("overrides", {}).get("water"))
            if any(fr) and frkind and is_proc:
                b = ms_blocks.fringe(b, fr, frkind, (px, py))
            if not is_proc and any(cl):
                b = clean_edges(b, cl[0], cl[1], int(cfg["terrain_sheet"].get("top_center_y", 34)))
            cache[key] = b
        return cache[key]

    xs = [L.tile_xy(ix, iy, w, h) for (ix, iy) in tiles]
    syv = [(x - y) * 32 for x, y in xs]
    sxv = [(x + y) * 64 for x, y in xs]
    OY = int(-min(syv)) + 210
    MX = int(-min(sxv)) + 90
    CW = int(max(sxv) - min(sxv)) + 260
    CH = int(max(syv) - min(syv)) + 210 + 170
    canvas = Image.new("RGBA", (CW, CH), tuple(cfg.get("bg_color", [34, 34, 40])) + (255,))
    items = [(ix + iy, 0, ("tile", ix, iy, k)) for (ix, iy), k in tiles.items()]
    items += [(p["tile"][0] + p["tile"][1], 1, ("prop", p)) for p in placed]
    dc = cfg.get("decor", {})
    drnd = random.Random(seed * 7 + 3)
    for (ix, iy), k in tiles.items():
        st0 = bstate(ix, iy) if k in VEG else 0
        if st0 > 0:
            continue
        cx, cy = L.tile_xy(ix, iy, w, h)
        for kind, kinds, key in (("flowers", ("grass", "forest_grass", "moss"), "flowers"), ("leaves", ("grass", "forest_grass", "dirt", "path"), "leaves")):
            c = dc.get(key)
            if not c or k not in kinds:
                continue
            pr = float(c.get("p_forest" if k == "forest_grass" else "p", 0.1))
            if drnd.random() < pr:
                spr = (make_flowers if kind == "flowers" else make_leaves)(drnd, c["colors"])
                items.append((ix + iy, 1, ("decor", spr, cx + drnd.uniform(-.34, .34), cy + drnd.uniform(-.34, .34))))
    items.sort(key=lambda t: (t[0], t[1]))

    def sc(x, y):
        return ((x + y) * 64 + MX, (x - y) * 32 + OY)

    n_state = [0, 0, 0]
    for _, _, it in items:
        if it[0] == "tile":
            _, ix, iy, k = it
            x, y = L.tile_xy(ix, iy, w, h)
            sx, sy = sc(x, y)
            st = bstate(ix, iy) if k in VEG else 0
            if k in VEG:
                n_state[st] += 1
            if eff(ix, iy) in lib.blocks:
                canvas.alpha_composite(block_for(ix, iy), (int(sx - 64), int(sy - 34)))
            if lib.grass and (k in ("grass", "forest_grass") or (k == "moss" and st > 0)):
                rr = random.Random(ix * 97 + iy * 31)
                names = ("sano", "chamuscado", "quemado")
                gc = cfg.get("grass", {})
                cover = float(gc.get("coverage_forest" if k == "forest_grass" else "coverage_grass", 1.0))
                if any(tiles.get((ix + a_, iy + b_)) in ("path", "dirt") for a_, b_ in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    cover *= float(gc.get("path_edge_factor", 0.4))
                if st == 0 and rr.random() > cover:
                    continue          # sin overlay: se ve el bloque (suelo mas plano y claro)
                vi = rr.randrange(4)
                t = lib.grass[(names[st], vi)]
                if rr.random() < .5:
                    t = t.transpose(Image.FLIP_LEFT_RIGHT)
                near_dirt = any(tiles.get((ix + a_, iy + b_)) == "dirt" for a_ in (-1, 0, 1) for b_ in (-1, 0, 1))
                if st == 0 and near_dirt and gc.get("dry_variants") and rr.random() < float(gc.get("dry_prob", 0.85)):
                    hv, sv_, vv = gc["dry_variants"][rr.randrange(len(gc["dry_variants"]))]
                    t = recolor(t, hv, sv_, vv)
                elif st == 0:
                    vars_ = gc.get("forest_variants" if k == "forest_grass" else "variants", [[0, 1, 1]])
                    hv, sv_, vv = vars_[rr.randrange(len(vars_))]
                    t = recolor(t, hv, sv_, vv)
                canvas.alpha_composite(t, (int(sx - 64), int(sy + 32 - t.height)))
        elif it[0] == "decor":
            _, spr, dx_, dy_ = it
            sx, sy = sc(dx_, dy_)
            canvas.alpha_composite(spr, (int(sx - spr.width / 2), int(sy - spr.height + 4)))
        else:
            p = it[1]
            sx, sy = sc(p["x"], p["y"])
            tk = tuple(p["tile"])
            k = tiles[tk]
            st = bstate(*tk) if k in VEG else 0
            nm = p["prop"]
            if st > 0 and nm in ("grass_clump", "flowers", "groundcover", "mushrooms", "lavender", "fern"):
                continue
            if k in ("grass", "forest_grass") and nm == "grass_clump" and lib.grass:
                continue
            names = ("sano", "chamuscado", "quemado")
            rp = random.Random(int(p["x"] * 1000) * 31 + int(p["y"] * 1000))
            if nm in ("bush", "bush_berry"):
                img = lib.clumps.get((names[st], nm)) or props.get(nm)
            elif nm in lib.trees:
                if st == 2 and "tree_dead" in lib.trees:
                    lst = lib.trees["tree_dead"]
                else:
                    lst = lib.trees[nm]
                img = lst[rp.randrange(len(lst))]
                if rp.random() < .5:
                    img = img.transpose(Image.FLIP_LEFT_RIGHT)
                if st == 1:
                    img = tint(img, (.8, .7, .55))
            else:
                img = props.get(nm)
            if img is None:
                continue
            s = p["scale"]
            im2 = img.resize((max(1, int(img.width * s)), max(1, int(img.height * s))), Image.LANCZOS) if abs(s - 1) > .02 else img
            canvas.alpha_composite(im2, (int(sx - im2.width / 2), int(sy - im2.height + 4)))
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(dest)
    return {"file": str(dest), "tiles": [w, h], "props": len(placed), "fire": fire_on,
            "veg_tiles_by_state": {"sano": n_state[0], "chamuscado": n_state[1], "quemado": n_state[2]},
            "size": [CW, CH]}


# ---------------------------------------------------------------- principal
def resolve_root(args, cfg) -> Path:
    if args.root:
        return Path(args.root)
    if os.environ.get("MS_TERRAIN_ROOT"):
        return Path(os.environ["MS_TERRAIN_ROOT"])
    if cfg.get("root"):
        return Path(cfg["root"])
    return HERE


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root")
    ap.add_argument("--config", default=str(HERE / "ms_terrain_config.json"))
    ap.add_argument("--seed", type=int)
    ap.add_argument("--fire", default=None, choices=["on", "off", "both"])
    args = ap.parse_args()
    cfg = json.loads(Path(args.config).read_text(encoding="utf-8"))
    root = resolve_root(args, cfg).resolve()
    out = root / cfg["folders"]["output"]
    out.mkdir(parents=True, exist_ok=True)
    seed = args.seed if args.seed is not None else int(cfg.get("seed", 7))
    print(f"[ROOT] {root}")
    lib = load_library(cfg, root, out)
    rep = {"root": str(root), "seed": seed, "info": lib.info, "warnings": lib.warn, "maps": []}
    if not lib.blocks:
        print("ERROR: sin bloques de terreno; no se puede componer el mapa.")
        for wmsg in lib.warn:
            print(" -", wmsg)
        sys.exit(2)
    mode = args.fire or ("on" if cfg["fire"].get("enabled", True) else "off")
    runs = {"on": [("map.png", True)], "off": [("map.png", False)],
            "both": [("map.png", True), ("map_sano.png", False)]}[mode]
    for fname, fire in runs:
        r = compose(cfg, lib, root, out, seed, fire, out / fname)
        rep["maps"].append(r)
        print(f"[MAP] {r['file']} fuego={fire} props={r['props']} {r['veg_tiles_by_state']}")
    (out / "report.json").write_text(json.dumps(rep, indent=2, ensure_ascii=False), encoding="utf-8")
    lines = ["# Terreno bosque - informe", "", f"Raiz: `{root}`  |  semilla {seed}", ""]
    lines += ["## Cargado"] + [f"- {i}" for i in lib.info]
    lines += ["", "## Avisos"] + ([f"- {x}" for x in lib.warn] or ["- ninguno"])
    lines += ["", "## Mapas"] + [f"- {m['file']} (props {m['props']}, estados {m['veg_tiles_by_state']})" for m in rep["maps"]]
    (out / "REPORTE.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    for x in lib.warn:
        print("[AVISO]", x)


if __name__ == "__main__":
    try:
        main()
    except Exception:  # noqa: BLE001
        traceback.print_exc()
        sys.exit(1)
