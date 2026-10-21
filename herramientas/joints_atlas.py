#!/usr/bin/env python3
"""Corta la lámina pintada de joints en un atlas de tiras SEAMLESS en horizontal.

  python herramientas/joints_atlas.py [lamina.webp] [atlas.png]

Entrada : arte/meshy/entrada/joints_lamina.webp (1500x750, RGBA, fondo transparente, 5 tiras horizontales).
Salida  : arte/suelo_meshy/joints_atlas.png (1024 x 640 = 5 filas de 128 px), docs/capturas/joints/atlas_repeticion.png (control: 3 copias seguidas).

ORDEN DE LAS FILAS (de arriba abajo; fila 0 = y 0..127):
  0  camino -> tierra    1  camino -> piedra    2  tierra -> piedra    3  hierba -> camino    4  hierba -> piedra
ORIENTACION: v = 0 (borde de arriba de la fila) es el lado DENSO = el suelo de ORIGEN (el primero del nombre); hacia abajo la tira se deshace en
migas / piedrecitas sueltas, que caen sobre el suelo VECINO. u (horizontal) se repite: la costura esta fundida.

COSTURA: la tira empieza en un color y acaba en otro. Se recorta un solape B del final y se funde con el principio mediante una rampa cuyo
umbral lo desplaza un ruido suave (no una linea recta): out[x] = mezcla(tira[L + x], tira[x], t(x, y)) para x < B, con L = ancho - B; el resto es la
tira tal cual. Asi out[L - 1] -> out[0] es continuo (out[0] = tira[L], justo lo que sigue a tira[L - 1]). Se hace en alfa premultiplicado.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAMINA = os.path.join(RAIZ, "arte", "meshy", "entrada", "joints_lamina.webp")
ATLAS = os.path.join(RAIZ, "arte", "suelo_meshy", "joints_atlas.png")
CONTROL = os.path.join(RAIZ, "docs", "capturas", "joints", "atlas_repeticion.png")
NOMBRES = ["camino_tierra", "camino_piedra", "tierra_piedra", "hierba_camino", "hierba_piedra"]
ANCHO = 1024
ALTO_FILA = 128
MARGEN_SUP = 6          # px de aire sobre el lado denso dentro de cada fila
SOLAPE = 220            # px (de la lámina) que se funden en la costura
UMBRAL_ALFA = 20


def franjas(a):
    """Rangos de filas (y0, y1) con algo de alfa, separados por filas vacías."""
    lleno = (a > UMBRAL_ALFA).sum(1) > 0
    res, ini = [], None
    for y, v in enumerate(lleno):
        if v and ini is None:
            ini = y
        if not v and ini is not None:
            res.append((ini, y))
            ini = None
    if ini is not None:
        res.append((ini, len(lleno)))
    return res


def ruido_suave(forma, sigma, rng):
    r = gaussian_filter(rng.random(forma), sigma, mode="wrap")
    return (r - r.min()) / (r.max() - r.min() + 1e-9)


def seamless(tira, rng):
    """tira: float (h, w, 4) premultiplicada. Devuelve (h, w - SOLAPE, 4) periódica."""
    h, w, _ = tira.shape
    L = w - SOLAPE
    n = ruido_suave((h, SOLAPE), (6, 14), rng)
    n = gaussian_filter(n, 3)
    x = np.linspace(0, 1, SOLAPE)[None, :]
    t = np.clip((x - 0.5) * 2.2 + 0.5 + (n - 0.5) * 1.3, 0, 1)
    t = t * t * (3 - 2 * t)
    t = t[:, :, None]
    sal = tira[:, :L].copy()
    sal[:, :SOLAPE] = tira[:, L:] * (1 - t) + tira[:, :SOLAPE] * t
    return sal


def a_straight(p):
    """Premultiplicado -> RGBA recto, con el color de los píxeles transparentes rellenado desde el vecino (no hay halo negro al filtrar)."""
    a = p[..., 3]
    rgb_b = np.stack([gaussian_filter(p[..., i], 2.5) for i in range(3)], -1)
    a_b = gaussian_filter(a, 2.5)[..., None]
    rel = rgb_b / np.maximum(a_b, 1e-4)
    prop = p[..., :3] / np.maximum(a[..., None], 1e-4)
    k = np.clip(a[..., None] * 6, 0, 1)
    rgb = prop * k + rel * (1 - k)
    return np.clip(np.concatenate([rgb, a[..., None]], -1), 0, 1)


def main():
    lamina = sys.argv[1] if len(sys.argv) > 1 else LAMINA
    salida = sys.argv[2] if len(sys.argv) > 2 else ATLAS
    im = np.array(Image.open(lamina).convert("RGBA")).astype(np.float64) / 255.0
    a = im[..., 3]
    fr = franjas((a * 255).astype(np.uint8))
    if len(fr) != 5:
        raise SystemExit("se esperaban 5 franjas y hay %d: %s" % (len(fr), fr))
    rng = np.random.default_rng(7)
    atlas = np.zeros((ALTO_FILA * 5, ANCHO, 4))
    for i, (y0, y1) in enumerate(fr):
        sub = im[y0:y1]
        cols = np.where((sub[..., 3] * 255 > UMBRAL_ALFA).any(0))[0]
        sub = sub[:, cols[0]:cols[-1] + 1]
        p = sub.copy()
        p[..., :3] *= p[..., 3:4]
        p = seamless(p, rng)
        h, w, _ = p.shape
        escala = ANCHO / w
        nh = int(round(h * escala))
        if nh + MARGEN_SUP > ALTO_FILA:
            raise SystemExit("la fila %d no cabe: %d px" % (i, nh))
        # Reescalado en premultiplicado (PIL, por canal en float).
        red = np.stack([np.array(Image.fromarray(p[..., c].astype(np.float32), "F").resize((ANCHO, nh), Image.LANCZOS)) for c in range(4)], -1)
        red = np.clip(red, 0, 1)
        red[..., :3] = np.minimum(red[..., :3], red[..., 3:4])
        atlas[i * ALTO_FILA + MARGEN_SUP:i * ALTO_FILA + MARGEN_SUP + nh] = red
        print("fila %d %-14s franja y %d..%d -> %d x %d px (escala %.3f)" % (i, NOMBRES[i], y0, y1, ANCHO, nh, escala))
    out = (a_straight(atlas) * 255 + 0.5).astype(np.uint8)
    os.makedirs(os.path.dirname(salida), exist_ok=True)
    Image.fromarray(out, "RGBA").save(salida)
    print("atlas:", salida, out.shape[1], "x", out.shape[0])
    # Control: 3 copias seguidas sobre un fondo neutro, con una marca roja bajo cada costura.
    tri = np.concatenate([out] * 3, 1)
    fondo = Image.new("RGBA", (tri.shape[1], tri.shape[0]), (92, 84, 70, 255))
    fondo.alpha_composite(Image.fromarray(tri, "RGBA"))
    fondo = fondo.convert("RGB")
    px = fondo.load()
    for k in (1, 2):
        for y in range(0, tri.shape[0], 128):
            for dx in range(-1, 1):
                px[k * ANCHO + dx, y + 1] = (255, 0, 0)
                px[k * ANCHO + dx, y + 2] = (255, 0, 0)
    os.makedirs(os.path.dirname(CONTROL), exist_ok=True)
    fondo.save(CONTROL)
    print("control:", CONTROL)


if __name__ == "__main__":
    main()
