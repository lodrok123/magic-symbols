"""Estadistica de luminancia de una captura (docs/capturas/albedos/*.png) por familia de color aproximada (clasificada por tono HSV).
Uso: python -I medir_captura_albedos.py <png> [<png> ...]   -> una tabla en Markdown por captura.
Familias (heuristicas; el pixel final mezcla luz, sombra y albedo): hierba (verde), copas (verde amarillento), pinos (verde azulado), tierra (marron saturado oscuro),
arena (claro poco saturado calido), todo (el fotograma entero sin el borde azul del vacio)."""
import sys
import numpy as np
from PIL import Image
import colorsys


def hsv(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx = a.max(-1)
    mn = a.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rc = np.where(m & (mx == r), ((g - b) / np.where(m, d, 1)) % 6, 0)
    gc = np.where(m & (mx == g) & (mx != r), (b - r) / np.where(m, d, 1) + 2, 0)
    bc = np.where(m & (mx == b) & (mx != r) & (mx != g), (r - g) / np.where(m, d, 1) + 4, 0)
    h = (rc + gc + bc) * 60.0
    s = np.where(mx > 0, d / np.where(mx > 0, mx, 1), 0)
    return h, s, mx


def estad(l):
    if l.size < 50:
        return None
    return l.size, l.mean(), l.std(), np.percentile(l, 5), np.percentile(l, 95)


def main(rutas):
    for ruta in rutas:
        im = np.asarray(Image.open(ruta).convert("RGB"), dtype=np.float32) / 255.0
        lum = (0.2126 * im[..., 0] + 0.7152 * im[..., 1] + 0.0722 * im[..., 2]) * 255.0
        h, s, v = hsv(im)
        vacio = (h > 195) & (h < 250) & (s < 0.25) & (v > 0.8)     # el borde claro azulado fuera del mapa
        fam = {
            "todo": ~vacio,
            "hierba": (h >= 85) & (h < 150) & (s >= 0.3) & ~vacio,
            "copas": (h >= 55) & (h < 85) & (s >= 0.25) & ~vacio,
            "pinos/azul": (h >= 150) & (h < 215) & (s >= 0.25) & ~vacio,
            "tierra": (h >= 8) & (h < 40) & (s >= 0.45) & (v < 0.85) & ~vacio,
            "arena": (h >= 25) & (h < 55) & (s < 0.45) & (s >= 0.1) & (v >= 0.8) & ~vacio,
        }
        print("### %s" % ruta)
        print("| familia | pixeles | media | desv | p5 | p95 | rango |")
        print("|---|---|---|---|---|---|---|")
        for k, m in fam.items():
            e = estad(lum[m])
            if e:
                print("| %s | %d | %.1f | %.1f | %.1f | %.1f | %.1f |" % (k, e[0], e[1], e[2], e[3], e[4], e[4] - e[3]))
        print()


if __name__ == "__main__":
    main(sys.argv[1:])
