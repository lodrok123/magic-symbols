"""Mide los TONOS de HieloToy y RayoToy en las fotos de captura_fuego_parametrico.gd (modo hielo_rayo). Adaptado de medir_tonos_fuego.py (B1, 2/11/2026).

Uso:
    python herramientas/medir_tonos_hielo_rayo.py <carpeta con hr_<elemento>_<figura>.png y hr_<elemento>_<figura>_base.png>

Cada figura se fotografia dos veces con la misma camara: con el efecto y sin el (_base). Los pixeles del efecto son los que cambian (diferencia > UMBRAL en algun canal); sobre ellos se mide:
  · hielo: el color medio y el reparto entre los tres tonos de hielo_paleta.gd (hondo / claro / escarcha: el mas cercano por distancia de color, en sRGB) y cuanto del efecto es azul (b > g > r)
  · rayo: el reparto entre BLANCO (saturacion < 0,25 y claro), AMARILLO (matiz 35-70 grados, saturacion >= 0,2) y AZUL (matiz 190-250 grados, saturacion >= 0,25), que es lo que pide la regla de Pablo («amarillo-blanco con halo azul»)
Los pixeles son lo que se ve en pantalla (el efecto mezclado con el suelo), no los uniforms: por eso se compara con la paleta por cercania, no por igualdad.
"""
import colorsys
import os
import sys

from PIL import Image

UMBRAL = 28
HIELO = {"hondo": (0.46, 0.66, 0.88), "claro": (0.72, 0.86, 0.97), "escarcha": (0.86, 0.93, 0.99)}
FIGURAS = ["bola", "muro", "pilar", "barrera", "haz"]


def pixeles_efecto(ruta, base):
    a = Image.open(ruta).convert("RGB")
    b = Image.open(base).convert("RGB")
    pa, pb = a.load(), b.load()
    w, h = a.size
    res = []
    for j in range(0, h, 2):
        for i in range(0, w, 2):
            r, g, bl = pa[i, j]
            r2, g2, b2 = pb[i, j]
            if max(abs(r - r2), abs(g - g2), abs(bl - b2)) > UMBRAL:
                res.append((r / 255.0, g / 255.0, bl / 255.0))
    return res


def medir_hielo(px):
    n = len(px)
    if n == 0:
        return "sin efecto"
    cuenta = {k: 0 for k in HIELO}
    azul = 0
    sr = sg = sb = 0.0
    for (r, g, b) in px:
        sr, sg, sb = sr + r, sg + g, sb + b
        if b > g > r:
            azul += 1
        mejor = min(HIELO, key=lambda k: (r - HIELO[k][0]) ** 2 + (g - HIELO[k][1]) ** 2 + (b - HIELO[k][2]) ** 2)
        cuenta[mejor] += 1
    return "%d px, medio (%.2f %.2f %.2f), azul (b>g>r) %.0f%%, mas cercano a hondo %.0f%% · claro %.0f%% · escarcha %.0f%%" % (
        n, sr / n, sg / n, sb / n, 100.0 * azul / n, 100.0 * cuenta["hondo"] / n, 100.0 * cuenta["claro"] / n, 100.0 * cuenta["escarcha"] / n)


def medir_rayo(px):
    n = len(px)
    if n == 0:
        return "sin efecto"
    blanco = amarillo = azul = otro = 0
    c_amar = c_azul = c_otro = 0
    for (r, g, b) in px:
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        d = h * 360.0
        if s >= 0.2 and v >= 0.7:                       # solo los pixeles de color y brillantes: el trazo (no el suelo iluminado por su luz ni el halo muy diluido)
            if 35 <= d <= 70:
                c_amar += 1
            elif 190 <= d <= 250:
                c_azul += 1
            else:
                c_otro += 1
        if s < 0.25 and v > 0.85:
            blanco += 1
        elif 35 <= d <= 70 and s >= 0.2:
            amarillo += 1
        elif 190 <= d <= 250 and s >= 0.25:
            azul += 1
        else:
            otro += 1
    nc = max(c_amar + c_azul + c_otro, 1)
    return "%d px: blanco %.0f%% · amarillo %.0f%% · azul %.0f%% · otro %.0f%% (el resto es el suelo iluminado por la luz del rayo y los halos diluidos) | de los %d px de color y brillantes: amarillo %.0f%% · azul %.0f%% · otro %.0f%%" % (
        n, 100.0 * blanco / n, 100.0 * amarillo / n, 100.0 * azul / n, 100.0 * otro / n, c_amar + c_azul + c_otro, 100.0 * c_amar / nc, 100.0 * c_azul / nc, 100.0 * c_otro / nc)


def main():
    carpeta = sys.argv[1]
    for elem, medir in (("hielo", medir_hielo), ("rayo", medir_rayo)):
        print("== " + elem)
        for fig in FIGURAS:
            ruta = os.path.join(carpeta, "hr_%s_%s.png" % (elem, fig))
            base = os.path.join(carpeta, "hr_%s_%s_base.png" % (elem, fig))
            if not (os.path.exists(ruta) and os.path.exists(base)):
                print("%-8s falta la foto o su base" % fig)
                continue
            print("%-8s %s" % (fig, medir(pixeles_efecto(ruta, base))))


if __name__ == "__main__":
    main()
