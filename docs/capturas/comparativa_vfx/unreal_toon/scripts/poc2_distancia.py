# Prueba 2 (fuego toon): distancia objetiva entre la franja de fuego de la referencia (ref_muro.jpg, Zelda BotW) y la
# de una captura propia. Python del sistema (PIL + numpy), fuera del editor.
#   py -3 poc2_distancia.py <ref_muro.jpg> <captura.png> [x0 y0 x1 y1 del muro en la captura]
# Método (criterio de Pablo): recorte de la franja del fuego en las dos imágenes (en la referencia, filas 270-380 de 668),
# histograma de tono x valor cuantizado a 8x8 sobre los píxeles con saturación > 0,4, normalizado, y distancia L1 entre
# los dos histogramas (0 = iguales, 2 = nada en común). También se imprime el reparto por tonos (amarillo / naranja /
# rojo) para saber qué sobra o falta.
import sys, numpy as np
from PIL import Image

ref = sys.argv[1] if len(sys.argv) > 1 else r"E:\tmp\wt_prueba2_unreal\docs\capturas\comparativa_vfx\referencia\ref_muro.jpg"
mia = sys.argv[2] if len(sys.argv) > 2 else r"E:\UnrealProjects\MS_POC_VFX\Saved\Screenshots\WindowsEditor\muro_cerca.png"
caja = tuple(int(v) for v in sys.argv[3:7]) if len(sys.argv) >= 7 else None
SAT_MIN, N = 0.4, 8


def franja_ref(im):
    h = im.size[1]
    return im.crop((0, int(h * 270 / 668), im.size[0], int(h * 380 / 668)))


def franja_mia(im, caja):
    if caja: return im.crop(caja)
    # sin caja: el rectángulo que envuelve a los píxeles cálidos y saturados (la llama), con un margen
    a = np.asarray(im.convert("HSV")).astype(np.float32) / 255.0
    cal = (a[..., 1] > SAT_MIN) & (a[..., 2] > 0.5) & ((a[..., 0] < 0.17) | (a[..., 0] > 0.95))
    ys, xs = np.nonzero(cal)
    if len(xs) == 0: return im
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    m = int(0.03 * im.size[1])
    return im.crop((max(0, x0 - m), max(0, y0 - m), min(im.size[0], x1 + m), min(im.size[1], y1 + m)))


def histograma(im):
    a = np.asarray(im.convert("HSV")).astype(np.float32) / 255.0
    h, s, v = a[..., 0], a[..., 1], a[..., 2]
    sel = s > SAT_MIN
    hq = np.minimum((h[sel] * N).astype(int), N - 1); vq = np.minimum((v[sel] * N).astype(int), N - 1)
    H = np.zeros((N, N)); np.add.at(H, (hq, vq), 1)
    return H / max(1, H.sum()), int(sel.sum())


def reparto(H):
    """Fracción por tono (índices 0..7 = 0-45º rojo-naranja, 45-90º amarillo, ... en tono PIL 0-255)."""
    por_tono = H.sum(axis=1)
    rojo = por_tono[7] + por_tono[0] * 0  # tono 0.875-1 (magenta-rojo)
    return {"rojo-naranja (0-45º)": round(float(por_tono[0]), 3), "amarillo (45-90º)": round(float(por_tono[1]), 3),
            "verde-cian": round(float(por_tono[2:5].sum()), 3), "azul-magenta": round(float(por_tono[5:].sum()), 3)}


r = franja_ref(Image.open(ref).convert("RGB")); m = franja_mia(Image.open(mia).convert("RGB"), caja)
Hr, nr = histograma(r); Hm, nm = histograma(m)
d = float(np.abs(Hr - Hm).sum())
print("referencia: franja %dx%d, %d píxeles saturados; reparto %s" % (r.size[0], r.size[1], nr, reparto(Hr)))
print("mía:        franja %dx%d, %d píxeles saturados; reparto %s" % (m.size[0], m.size[1], nm, reparto(Hm)))
# valor medio de los píxeles saturados por tono cálido: dice si el naranja/rojo es más claro u oscuro que en la referencia
for nombre, H in (("referencia", Hr), ("mía", Hm)):
    vals = np.arange(N) + 0.5
    for t in (0, 1):
        fila = H[t]
        if fila.sum() > 0: print("  %s tono %d: valor medio %.2f, reparto por valor %s" % (nombre, t, (fila * vals).sum() / fila.sum() / N, np.round(fila / fila.sum(), 2).tolist()))
print("DISTANCIA L1 (tono x valor 8x8, s > %.1f): %.3f" % (SAT_MIN, d))
