"""Logica pura (sin Blender) del flujo de terreno: mapa, colocacion de props, encuadre.

Se puede probar con Python normal:  python ms_terrain_layout.py <forest_map.json>
"""
from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

TILE = 1.0                      # lado de una casilla en unidades de Blender
DIAG = math.sqrt(2.0) * TILE    # ancho en pantalla de un rombo (az 45) en unidades
TILE_PX = 128                   # ancho en pixeles del rombo (contrato con Godot)
PPU = TILE_PX / DIAG            # pixeles por unidad de Blender


def load_json(p) -> dict:
    return json.loads(Path(p).read_text(encoding="utf-8"))


def iso_basis(az_deg: float = 45.0, el_deg: float = 30.0):
    """Ejes de pantalla (derecha R, arriba U) para una camara ortografica isometrica."""
    az, el = math.radians(az_deg), math.radians(el_deg)
    f = (-math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), -math.sin(el))
    r = (f[1], -f[0], 0.0)
    n = math.hypot(r[0], r[1])
    r = (r[0] / n, r[1] / n, 0.0)
    u = (r[1] * f[2] - r[2] * f[1], r[2] * f[0] - r[0] * f[2], r[0] * f[1] - r[1] * f[0])
    return r, u, f


def project_px(p, az=45.0, el=30.0):
    r, u, _ = iso_basis(az, el)
    return (sum(p[i] * r[i] for i in range(3)) * PPU, sum(p[i] * u[i] for i in range(3)) * PPU)


def parse_map(rows: list[str], legend: dict):
    """Devuelve (ancho, alto, {(ix,iy): material}). Fila 0 = fondo del mapa (y mayor)."""
    h = len(rows)
    w = max(len(r) for r in rows)
    tiles = {}
    for iy, row in enumerate(rows):
        for ix, ch in enumerate(row):
            if ch == " " or ch == ".":
                continue
            if ch not in legend:
                raise ValueError(f"Simbolo '{ch}' del mapa no esta en la leyenda")
            tiles[(ix, iy)] = legend[ch]
    return w, h, tiles


def tile_xy(ix: int, iy: int, w: int, h: int):
    return (ix - (w - 1) / 2.0) * TILE, ((h - 1) / 2.0 - iy) * TILE


def place_props(w, h, tiles, rules: dict, seed: int, fixed: list | None = None):
    """Coloca props segun reglas por material. Determinista por semilla."""
    rnd = random.Random(seed)
    placed, big_tiles = [], set()
    for iy in range(h):
        for ix in range(w):
            kind = tiles.get((ix, iy))
            if not kind:
                continue
            cx, cy = tile_xy(ix, iy, w, h)
            local = []
            has_big = False
            smalls = 0
            for rule in rules.get(kind, []):
                if rnd.random() > float(rule.get("p", 0.0)):
                    continue
                big = bool(rule.get("big"))
                if big:
                    if has_big:
                        continue
                    gap = int(rule.get("min_gap", 1))
                    if any((ix + dx, iy + dy) in big_tiles
                           for dx in range(-gap, gap + 1) for dy in range(-gap, gap + 1)):
                        continue
                    ox, oy = rnd.uniform(-0.12, 0.12), rnd.uniform(-0.12, 0.12)
                else:
                    if smalls >= int(rule.get("max_small", 3)):
                        continue
                    ox, oy = rnd.uniform(-0.36, 0.36), rnd.uniform(-0.36, 0.36)
                    if any(math.hypot(ox - a, oy - b) < 0.26 for a, b, _ in local):
                        continue
                lo, hi = rule.get("size", [1.0, 1.0])
                local.append((ox, oy, big))
                if big:
                    has_big = True
                    big_tiles.add((ix, iy))
                else:
                    smalls += 1
                placed.append({"prop": rule["prop"], "x": cx + ox, "y": cy + oy,
                               "rot": rnd.uniform(0, 360), "scale": rnd.uniform(lo, hi),
                               "tile": [ix, iy]})
    for f in fixed or []:
        if tuple(f["tile"]) in tiles:
            cx, cy = tile_xy(f["tile"][0], f["tile"][1], w, h)
            ox, oy = f.get("offset", [0, 0])
            placed.append({"prop": f["prop"], "x": cx + ox, "y": cy + oy, "rot": f.get("rot", 0.0),
                           "scale": f.get("scale", 1.0), "tile": list(f["tile"]), "fixed": True})
    return placed


def map_frame(w, h, tile_h, max_prop_h, margin=24, az=45.0, el=30.0):
    """Tamano de imagen y pixel donde cae el origen (0,0,0) para encuadrar todo el mapa."""
    hx, hy = w * TILE / 2.0, h * TILE / 2.0
    pts = []
    for sx in (-hx, hx):
        for sy in (-hy, hy):
            for z in (-tile_h, 0.0, max_prop_h):
                pts.append(project_px((sx, sy, z), az, el))
    minx = min(p[0] for p in pts); maxx = max(p[0] for p in pts)
    miny = min(p[1] for p in pts); maxy = max(p[1] for p in pts)
    W = int(math.ceil(maxx - minx)) + 2 * margin
    H = int(math.ceil(maxy - miny)) + 2 * margin
    return W, H, (margin - minx, margin + maxy)


def ascii_preview(w, h, tiles, placed, legend_rev):
    grid = [[" "] * w for _ in range(h)]
    for (ix, iy), k in tiles.items():
        grid[iy][ix] = legend_rev.get(k, "?")
    for p in placed:
        ix, iy = p["tile"]
        if p["prop"].startswith("tree"):
            grid[iy][ix] = "T"
    return "\n".join("".join(r) for r in grid)


if __name__ == "__main__":
    cfg = load_json(sys.argv[1])
    legend = cfg["legend"]
    w, h, tiles = parse_map(cfg["rows"], legend)
    placed = place_props(w, h, tiles, cfg["rules"], int(cfg.get("seed", 1)), cfg.get("fixed"))
    rev = {v: k for k, v in legend.items()}
    print(ascii_preview(w, h, tiles, placed, rev))
    from collections import Counter
    print(Counter(p["prop"] for p in placed))
    print("frame", map_frame(w, h, 0.45, 3.0))
