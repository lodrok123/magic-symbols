"""Textura del lecho del río: lecho_rio_original.png (Meshy, no seamless) -> arte/suelo_meshy/lecho_rio.png, 512x512 seamless en X e Y.
Uso: python herramientas/lecho_rio_textura.py   (desde la raíz del proyecto). Reproducible (semilla fija).
Método: se pasa a 512x512; la versión DESPLAZADA medio tamaño (np.roll) es continua en sus bordes pero tiene la costura en la cruz central; ahí se mete el
centro de la ORIGINAL (limpio) con una máscara cuyo contorno se rompe con ruido de baja frecuencia, de modo que el corte sigue irregular y no deja un borroso en línea recta."""
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, zoom

N = 512
ENTRADA = "arte/meshy/entrada/lecho_rio_original.png"
SALIDA = "arte/suelo_meshy/lecho_rio.png"
REPETICION = "docs/capturas/agua_filtro/lecho_repeticion.png"
SEMILLA = 7
SEMIANCHO = 105     # px desde la cruz central donde manda la original
SUAVE = 4           # ancho del fundido (px)
AMPL_RUIDO = 55     # cuánto se desvía el contorno del corte (px)

im = Image.open(ENTRADA).convert("RGB").resize((N, N), Image.LANCZOS)
orig = np.asarray(im).astype(np.float32)
rod = np.roll(orig, (N // 2, N // 2), axis=(0, 1))
rng = np.random.default_rng(SEMILLA)
yy, xx = np.mgrid[0:N, 0:N]


def un_eje(a, eje):
    """Hace `a` seamless en un eje. Se busca el corte k (entre 160 y 352) donde la imagen ya es lo más continua posible (la original trae una junta en el centro en algunas filas);
    la versión rodada hasta ese corte es continua en sus bordes y tiene la costura (los bordes de la original) en la línea c = N - k; ahí entra la original, que es limpia lejos de sus bordes,
    con una máscara de contorno irregular (ruido de baja frecuencia)."""
    b = np.moveaxis(a, eje, 0)
    costes = [np.abs(b[k] - b[k - 1]).mean() for k in range(160, 353)]
    k = 160 + int(np.argmin(costes))
    c = N - k
    ruido = zoom(gaussian_filter(rng.standard_normal((32, 32)), 2.0, mode="wrap"), N / 32, order=3)
    ruido = (ruido - ruido.mean()) / (ruido.std() + 1e-6)
    pos = xx if eje == 1 else yy
    d = np.abs(pos - c).astype(np.float32) + ruido * (AMPL_RUIDO * 0.5)
    w = 1.0 - np.clip((d - (SEMIANCHO - SUAVE)) / (2 * SUAVE), 0, 1)
    w = w * w * (3 - 2 * w)
    rod = np.roll(a, -k, axis=eje)
    print("eje %d: corte k=%d (coste %.1f), costura en %d" % (eje, k, min(costes), c))
    return rod * (1 - w[..., None]) + a * w[..., None]

res = un_eje(un_eje(orig, 1), 0)
out = Image.fromarray(np.clip(res + 0.5, 0, 255).astype(np.uint8))
out.save(SALIDA)

def costura(a):
    a = a.astype(np.float32)
    h = np.abs(a[:, 0] - a[:, -1]).mean()
    v = np.abs(a[0] - a[-1]).mean()
    dentro = np.abs(a[:, 1:] - a[:, :-1]).mean()
    return h, v, dentro

print("original  costura H %.1f V %.1f, dentro %.1f" % costura(np.asarray(im)))
print("resultado costura H %.1f V %.1f, dentro %.1f" % costura(np.asarray(out)))
a = np.asarray(out)
mos = np.concatenate([np.concatenate([a, a], 1), np.concatenate([a, a], 1)], 0)
Image.fromarray(mos).save(REPETICION)




