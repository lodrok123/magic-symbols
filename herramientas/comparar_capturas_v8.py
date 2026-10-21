"""Compara dos capturas del mismo encuadre píxel a píxel (V8, texturas a 1024). Uso:
    python herramientas/comparar_capturas_v8.py <antes.png> <despues.png> [diff_salida.png]
Dice: píxeles distintos (>0), distintos de verdad (>8/255 en algún canal), diferencia media y máxima, y lo mismo SOLO sobre los píxeles del personaje
(los que no son el fondo verde del suelo de la captura). Guarda una imagen de diferencias multiplicada por 8 si se pide.
"""
import sys
from PIL import Image, ImageChops

a = Image.open(sys.argv[1]).convert("RGB")
b = Image.open(sys.argv[2]).convert("RGB")
assert a.size == b.size, "tamaños distintos"
d = ImageChops.difference(a, b)
pa, pd = a.load(), d.load()
w, h = a.size
fondo = pa[5, 5]
n = n_pers = 0
dist0 = dist8 = dist0_p = dist8_p = 0
suma = suma_p = 0
mx = mx_p = 0
for y in range(h):
    for x in range(w):
        r, g, bl = pd[x, y]
        m = max(r, g, bl)
        es_pers = max(abs(pa[x, y][0] - fondo[0]), abs(pa[x, y][1] - fondo[1]), abs(pa[x, y][2] - fondo[2])) > 24
        n += 1
        suma += (r + g + bl) / 3.0
        mx = max(mx, m)
        if m > 0:
            dist0 += 1
        if m > 8:
            dist8 += 1
        if es_pers:
            n_pers += 1
            suma_p += (r + g + bl) / 3.0
            mx_p = max(mx_p, m)
            if m > 0:
                dist0_p += 1
            if m > 8:
                dist8_p += 1
print("imagen completa: %d px | distintos %.3f %% | distintos >8/255 %.3f %% | dif media %.4f/255 | máx %d" % (n, 100.0 * dist0 / n, 100.0 * dist8 / n, suma / n, mx))
if n_pers:
    print("solo personaje:  %d px | distintos %.2f %% | distintos >8/255 %.2f %% | dif media %.3f/255 | máx %d" % (n_pers, 100.0 * dist0_p / n_pers, 100.0 * dist8_p / n_pers, suma_p / n_pers, mx_p))
if len(sys.argv) > 3:
    d.point(lambda v: min(255, v * 8)).save(sys.argv[3])
