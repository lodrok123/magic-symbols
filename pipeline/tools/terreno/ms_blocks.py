"""Magic Symbols - bloques de terreno procedurales (solo Pillow): tierra, camino y agua uniformes.

Geometria identica a los bloques de la hoja (128 px de ancho, cara superior con vertices
(0,34) (64,2) (128,34) (64,66), canto de 36 px -> alto 102). Los estratos de los costados son
periodicos cada 64 px y arrancan siempre a la misma distancia del borde superior, asi que
casan sin desnivel con los bloques vecinos. Las variantes solo cambian detalles de la cara superior.
"""
from __future__ import annotations

import math
import random

from PIL import Image, ImageDraw

W, H = 128, 102
S = 4                      # supersampling
T = (64, 2)
Lf = (0, 34)
Rt = (128, 34)
Bt = (64, 66)
SH = 36
OUTLINE = (71, 33, 23, 255)

DEFAULTS = {
    "dirt": {"top": [178, 120, 73], "strata": [[150, 96, 60], [133, 82, 50], [118, 70, 43]], "pebbles": [[140, 92, 58]], "n_pebbles": 6},
    "path": {"top": [172, 134, 84], "strata": [[150, 96, 60], [133, 82, 50], [118, 70, 43]], "pebbles": [[166, 166, 160], [150, 150, 146]], "n_pebbles": 7},
    "water": {"top": [84, 152, 142], "water_side": [92, 160, 148], "rim": [128, 208, 196], "rim_width": 14,
              "strata": [[150, 96, 60], [118, 70, 43]], "water_depth": 24},
}


def _col(c, k=1.0, a=255):
    return (int(min(255, c[0] * k)), int(min(255, c[1] * k)), int(min(255, c[2] * k)), a)


def _band_depths(x):
    """Profundidades (px, bajo el borde superior de la cara) de los limites de estrato; periodicas cada 64 px."""
    u = 2 * math.pi * x / 64.0
    return (11 + 2.0 * math.sin(u + 0.6), 23 + 2.4 * math.sin(2 * u + 1.9))


def _edge_y(face, x):
    return 34 + (x / 64.0) * 32 if face == "L" else 66 - ((x - 64) / 64.0) * 32


def _draw_sides(d, spec, kind):
    strata = spec["strata"]
    for face, x0, x1, k in (("L", 0, 64, 1.0), ("R", 64, 128, 0.86)):
        for xi in range(int(x0 * S), int(x1 * S)):
            x = xi / S
            ye = _edge_y(face, x)
            d1, d2 = _band_depths(x)
            top, bot = ye * S, (ye + SH) * S
            if kind == "water":
                wd = spec["water_depth"] + 1.2 * math.sin(2 * math.pi * x / 64.0 + 0.3)
                ws = _col(spec["water_side"], k)
                d.line([(xi, top), (xi, (ye + wd) * S)], fill=ws, width=1)
                d.line([(xi, (ye + wd) * S), (xi, (ye + wd + (SH - wd) * 0.45) * S)], fill=_col(strata[0], k), width=1)
                d.line([(xi, (ye + wd + (SH - wd) * 0.45) * S), (xi, bot)], fill=_col(strata[1], k), width=1)
            else:
                d.line([(xi, top), (xi, (ye + d1) * S)], fill=_col(strata[0], k), width=1)
                d.line([(xi, (ye + d1) * S), (xi, (ye + d2) * S)], fill=_col(strata[1], k), width=1)
                d.line([(xi, (ye + d2) * S), (xi, bot)], fill=_col(strata[2], k), width=1)


def _pt(p):
    return (p[0] * S, p[1] * S)


def _inside_diamond(x, y, shrink=0.72):
    cx, cy = 64, 34
    return abs(x - cx) / (64 * shrink) + abs(y - cy) / (32 * shrink) <= 1.0


def make_block(kind: str, variant: int, spec: dict | None = None, edges=(True, True, True, True)) -> Image.Image:
    """edges = (UL, UR, DR, DL): True dibuja el contorno de esa arista de la cara superior; False la deja sin linea
    (junto a un bloque igual o con transicion)."""
    spec = dict(DEFAULTS[kind], **(spec or {}))
    rnd = random.Random(f"{kind}-{variant}")
    im = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    _draw_sides(d, spec, kind)
    top = _col(spec["top"])
    d.polygon([_pt(Lf), _pt(T), _pt(Rt), _pt(Bt)], fill=top)
    if kind in ("dirt", "path"):
        # manchas suaves y piedrecitas dentro del rombo (sin degradado hacia el centro)
        for _ in range(3):
            x, y = rnd.uniform(24, 104), rnd.uniform(22, 46)
            if _inside_diamond(x, y):
                rx, ry = rnd.uniform(6, 11), rnd.uniform(3, 5)
                d.ellipse([(x - rx) * S, (y - ry) * S, (x + rx) * S, (y + ry) * S], fill=_col(spec["top"], 0.94))
        n = 0
        tries = 0
        while n < spec["n_pebbles"] and tries < 100:
            tries += 1
            x, y = rnd.uniform(14, 114), rnd.uniform(14, 54)
            if not _inside_diamond(x, y, 0.8):
                continue
            rx, ry = rnd.uniform(1.4, 3.0), rnd.uniform(0.9, 1.8)
            c = rnd.choice(spec["pebbles"])
            d.ellipse([(x - rx) * S, (y - ry) * S, (x + rx) * S, (y + ry) * S], fill=_col(c), outline=_col(c, 0.55), width=max(1, S // 3))
            n += 1
    else:
        # agua plana y uniforme + unas ondas cortas
        for _ in range(rnd.randint(2, 4)):
            for _t in range(50):
                x, y = rnd.uniform(28, 100), rnd.uniform(24, 44)
                if _inside_diamond(x, y, 0.62):
                    break
            rx, ry = rnd.uniform(5, 9), rnd.uniform(2.5, 4.5)
            a0 = rnd.uniform(0, 360)
            d.arc([(x - rx) * S, (y - ry) * S, (x + rx) * S, (y + ry) * S], a0, a0 + rnd.uniform(70, 130),
                  fill=(228, 247, 242, 235), width=max(1, int(S * 0.8)))
    # contorno: solo en las aristas marcadas; en las demas se extiende el color de la tapa para que no haya rendija
    ow = max(1, int(S * 1.5))
    tops = ((Lf, T), (T, Rt), (Rt, Bt), (Bt, Lf))
    for on, (a, b) in zip(edges, tops):
        if on:
            d.line([_pt(a), _pt(b)], fill=OUTLINE, width=ow)
        else:
            d.line([_pt(a), _pt(b)], fill=top, width=int(S * 2.6))
    for p in (Lf, Rt, Bt):
        d.line([_pt(p), (p[0] * S, (p[1] + SH) * S)], fill=OUTLINE, width=ow)
    for a, b in (((Lf[0], Lf[1] + SH), (Bt[0], Bt[1] + SH)), ((Bt[0], Bt[1] + SH), (Rt[0], Rt[1] + SH))):
        d.line([_pt(a), _pt(b)], fill=OUTLINE, width=ow)
    if kind == "water":
        for on, (a, b) in ((edges[3], (Lf, Bt)), (edges[2], (Bt, Rt))):
            if on:
                d.line([_pt(a), _pt(b)], fill=_col(spec["rim"]), width=max(1, S // 2))   # borde de la superficie
                d.line([_pt(a), _pt(b)], fill=OUTLINE, width=ow)
    return im.resize((W, H), Image.LANCZOS)


def _dist_to_line(x, y, p, q):
    dx, dy = q[0] - p[0], q[1] - p[1]
    return abs((x - p[0]) * dy - (y - p[1]) * dx) / math.hypot(dx, dy)


def water_rim(b: Image.Image, edges, spec: dict | None = None) -> Image.Image:
    """Degradado turquesa en las aristas de la cara superior que NO tienen agua al lado (orilla): da profundidad
    a la charca: turquesa claro junto a la orilla y mas oscuro hacia el centro. edges = (ul, ur, dr, dl)."""
    sp = dict(DEFAULTS["water"], **(spec or {}))
    rim = sp["rim"]
    wd = float(sp.get("rim_width", 14))
    lines = [(Lf, T), (T, Rt), (Rt, Bt), (Bt, Lf)]
    act = [ln for ln, on in zip(lines, edges) if on]
    if not act:
        return b
    out = b.copy()
    px = out.load()
    for y in range(0, 70):
        for x in range(W):
            r, g, bl, a = px[x, y]
            if a < 200 or (r + g + bl) / 3 < 105:       # fuera del agua o contorno oscuro
                continue
            if abs(x + 0.5 - 64) / 64.0 + abs(y - 34) / 32.0 > 1.0:
                continue
            k = 0.0
            for p, q in act:
                dd = _dist_to_line(x + 0.5, y + 0.5, p, q)
                k = max(k, max(0.0, 1.0 - dd / wd))
            if k > 0:
                k = k * k * (3 - 2 * k)                  # suavizado
                px[x, y] = (int(r + (rim[0] - r) * k), int(g + (rim[1] - g) * k), int(bl + (rim[2] - bl) * k), a)
    return out



# ---------------------------------------------------------------- transiciones irregulares (orillas)
FRINGE = {
    # hierba que invade el borde de tierra/camino
    "grass_on_dirt": {"fill": (118, 188, 62), "fill2": (92, 160, 50), "line": (52, 100, 40), "base": 6.0, "amp": 3.2, "tufts": True},
    # franja de arena mojada en la orilla del agua
    "sand_on_water": {"fill": (212, 190, 136), "fill2": (176, 150, 100), "line": (140, 108, 70), "base": 5.0, "amp": 2.6, "tufts": False},
}
_EDGES = (("UL", Lf, T), ("UR", T, Rt), ("DR", Rt, Bt), ("DL", Bt, Lf))


def _hash01(a: int, b: int = 0) -> float:
    n = (a * 374761393 + b * 668265263) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def fringe(b: Image.Image, edges, kind: str, world=(0, 0)) -> Image.Image:
    """Franja irregular en las aristas indicadas (UL UR DR DL) de la cara superior. Su profundidad depende de la
    posicion en el mundo a lo largo de la arista, asi continua sin saltos entre bloques vecinos de una misma linea."""
    sp = FRINGE[kind]
    act = [(n, p, q) for (n, p, q), on in zip(_EDGES, edges) if on]
    if not act:
        return b
    ov = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    px = ov.load()
    mask = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(mask).polygon([_pt(Lf), _pt(T), _pt(Rt), _pt(Bt)], fill=255)
    from PIL import ImageFilter
    mask = mask.filter(ImageFilter.MaxFilter(2 * int(S * 1.0) + 1))      # cubre tambien la mitad exterior del trazo del contorno
    for name, p, q in act:
        dx, dy = q[0] - p[0], q[1] - p[1]
        ln = math.hypot(dx, dy)
        ex, ey = dx / ln, dy / ln
        ecx, ecy = (64 / 71.55, -32 / 71.55) if name in ("UL", "DR") else (64 / 71.55, 32 / 71.55)   # direccion canonica
        sgn = ex * ecx + ey * ecy                          # +1 / -1 segun el sentido de la arista
        ph = 0.9 if name in ("UL", "DR") else 2.3
        wx, wy = world

        def depth(g):
            return (sp["base"] + sp["amp"] * math.sin(g * 0.21 + ph) + 0.55 * sp["amp"] * math.sin(g * 0.53 + 2 * ph)
                    + 0.18 * sp["amp"] * math.sin(g * 0.83 + 3 * ph))
        mx = max(1, int(math.ceil(sp["base"] + 2 * sp["amp"] + 2)))
        # recorrido por pixeles del 4x en una banda alrededor de la arista
        x0 = int(min(p[0], q[0]) * S) - mx * S
        x1 = int(max(p[0], q[0]) * S) + mx * S
        y0 = int(min(p[1], q[1]) * S) - mx * S
        y1 = int(max(p[1], q[1]) * S) + mx * S
        for yy in range(max(0, y0), min(H * S, y1)):
            for xx in range(max(0, x0), min(W * S, x1)):
                x, y = (xx + 0.5) / S, (yy + 0.5) / S
                dd = abs((x - p[0]) * dy - (y - p[1]) * dx) / ln
                t = ((x - p[0]) * dx + (y - p[1]) * dy) / (ln * ln)
                if t < -0.02 or t > 1.02:
                    continue
                g = (x + wx) * ecx + (y + wy) * ecy
                dep = depth(g)
                if dd > dep + 0.4:
                    continue
                if dd > dep - 0.9:
                    col = sp["line"]
                elif dd > dep - 2.6:
                    col = sp["fill2"]
                else:
                    col = sp["fill"]
                px[xx, yy] = col + (255,)
        if sp.get("tufts"):
            d = ImageDraw.Draw(ov)
            step = 13.0
            g0 = (p[0] + wx) * ecx + (p[1] + wy) * ecy
            k0 = int(math.floor(g0 / step)) - 1
            for k in range(k0 - 1, k0 + int(ln / step) + 4):
                gk = (k + 0.5 + (_hash01(k, 7) - 0.5) * 0.8) * step
                tt = (gk - g0) * sgn / ln
                if tt < 0.05 or tt > 0.95 or _hash01(k, 3) < 0.35:
                    continue
                bx, by = p[0] + dx * tt, p[1] + dy * tt
                nx, ny = -ey, ex                            # normal hacia el interior de la cara (aprox.)
                if (nx * (64 - bx) + ny * (34 - by)) < 0:
                    nx, ny = -nx, -ny
                dep = depth(gk)
                for j in range(3):
                    ox = (j - 1) * 2.2
                    sx_, sy_ = bx + ex * ox + nx * dep, by + ey * ox + ny * dep
                    ang = (j - 1) * 0.35
                    hx = nx * math.cos(ang) - ny * math.sin(ang)
                    hy = nx * math.sin(ang) + ny * math.cos(ang)
                    ln2 = 4.0 + 3.0 * _hash01(k, j + 11)
                    d.line([(sx_ * S, sy_ * S), ((sx_ + hx * ln2) * S, (sy_ + hy * ln2) * S)], fill=sp["line"] + (255,), width=int(S * 2.4))
                    d.line([(sx_ * S, sy_ * S), ((sx_ + hx * ln2) * S, (sy_ + hy * ln2) * S)], fill=sp["fill"] + (255,), width=int(S * 1.2))
    a = ov.getchannel("A")
    from PIL import ImageChops
    ov.putalpha(ImageChops.multiply(a, mask))
    ov = ov.resize((W, H), Image.LANCZOS)
    out = b.copy()
    out.alpha_composite(ov)
    return out


def make_all(kinds=("dirt", "path", "water"), variants: int = 3, overrides: dict | None = None):
    out = {}
    for k in kinds:
        out[k] = [make_block(k, v, (overrides or {}).get(k)) for v in range(variants)]
    return out


if __name__ == "__main__":
    import sys
    blocks = make_all()
    sheet = Image.new("RGBA", (128 * 3 * 2 + 40, 102 * 3 * 2 + 40), (255, 255, 255, 255))
    for r, k in enumerate(("dirt", "path", "water")):
        for c, b in enumerate(blocks[k]):
            sheet.alpha_composite(b.resize((256, 204), Image.NEAREST), (c * 266, r * 214))
    sheet.convert("RGB").save(sys.argv[1] if len(sys.argv) > 1 else "ms_blocks_preview.png")
