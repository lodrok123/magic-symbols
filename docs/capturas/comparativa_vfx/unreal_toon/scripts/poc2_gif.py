# Prueba 2 (fuego toon): monta el GIF de 3 s a 12 fps con las capturas seq_*.png de PIE (Python del sistema con PIL,
# fuera del editor) y mide cuántos pares consecutivos son idénticos (comprobación de la cuantización a 12 fps).
#   py -3 poc2_gif.py <carpeta_capturas> <salida.gif>
import sys, glob, os
from PIL import Image, ImageChops

carpeta = sys.argv[1] if len(sys.argv) > 1 else r"E:\UnrealProjects\MS_POC_VFX\Saved\Screenshots\WindowsEditor"
salida = sys.argv[2] if len(sys.argv) > 2 else os.path.join(carpeta, "muro_2m_12fps.gif")
UMBRAL_PIXEL, UMBRAL_IGUAL = 40, 0.0005   # un par es "igual" si menos del 0,05 % de los píxeles cambia más de 40 (ruido del TAA)

def distintos(a, b):
    d = ImageChops.difference(a, b).convert("L").point(lambda v: 255 if v > UMBRAL_PIXEL else 0)
    return d.histogram()[255] / float(a.size[0] * a.size[1])

def informe(patron, etiqueta):
    fs = sorted(glob.glob(os.path.join(carpeta, patron)))
    ims = [Image.open(f).convert("RGB") for f in fs]
    pares = [distintos(ims[i], ims[i + 1]) for i in range(len(ims) - 1)]
    iguales = sum(1 for p in pares if p < UMBRAL_IGUAL)
    print("%s: %d capturas, %d pares consecutivos iguales de %d; fracción de píxeles cambiados por par: %s" % (
        etiqueta, len(ims), iguales, len(pares), ["%.4f" % p for p in pares]))
    return fs, ims, pares

informe("muro_q*.png", "muro_q0..q3 (1/24 s de juego entre capturas)")
fs, ims, pares = informe("seq_*.png", "secuencia (1/12 s de juego entre capturas)")
if ims:
    # recorte a la zona del muro y reducción a 720 px de ancho para que el GIF no pase de unos pocos MB
    w, h = ims[0].size
    caja = (0, int(h * 0.05), w, int(h * 0.80))
    cuadros = [im.crop(caja).resize((720, int(720 * (caja[3] - caja[1]) / w)), Image.LANCZOS).quantize(colors=64, method=Image.MEDIANCUT) for im in ims]
    cuadros[0].save(salida, save_all=True, append_images=cuadros[1:], duration=int(1000 / 12), loop=0, optimize=True)
    print("GIF:", salida, "%d cuadros, %.2f s, %.1f MB" % (len(cuadros), len(cuadros) / 12.0, os.path.getsize(salida) / 1e6))
