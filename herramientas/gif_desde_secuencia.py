"""Junta los PNG que saca Godot con --write-movie en un GIF de 3 s (prueba 3 de VFX).
Uso:  py herramientas/gif_desde_secuencia.py <carpeta con f00000000.png ...> <salida.gif> [ancho=640] [fps=24] [saltar=10]
Salta los primeros `saltar` fotogramas (el efecto está naciendo) y coge fps * 3 fotogramas.
"""
import glob
import sys

from PIL import Image

carpeta, salida = sys.argv[1], sys.argv[2]
ancho = int(sys.argv[3]) if len(sys.argv) > 3 else 640
fps = int(sys.argv[4]) if len(sys.argv) > 4 else 24
saltar = int(sys.argv[5]) if len(sys.argv) > 5 else 10
fotos = sorted(glob.glob(carpeta.rstrip("/\\") + "/*.png"))[saltar:saltar + fps * 3]
if not fotos:
    raise SystemExit("no hay fotogramas en " + carpeta)
cuadros = []
for f in fotos:
    im = Image.open(f).convert("RGB")
    alto = round(im.height * ancho / im.width)
    cuadros.append(im.resize((ancho, alto), Image.LANCZOS))
paleta = cuadros[len(cuadros) // 2].quantize(colors=192, method=Image.Quantize.MEDIANCUT)
cuadros_p = [c.quantize(palette=paleta, dither=Image.Dither.NONE) for c in cuadros]
cuadros_p[0].save(salida, save_all=True, append_images=cuadros_p[1:], duration=round(1000 / fps), loop=0, optimize=False)
print("%s: %d fotogramas, %d ms cada uno" % (salida, len(cuadros_p), round(1000 / fps)))
