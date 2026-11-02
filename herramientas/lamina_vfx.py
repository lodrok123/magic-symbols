"""Monta la LAMINA de ejes y propiedades del fuego parametrico (FuegoToy) con PIL.

Uso:
    python herramientas/lamina_vfx.py <carpeta con celda_*.png y celdas.json> <lamina.png> [ancho_reducido=2400]

Las capturas las saca herramientas/captura_fuego_parametrico.gd (modo celdas). Cada celda lleva su rotulo (titulo, figura y ejes x·y·z en metros, propiedades);
la lamina cabe en menos de 4000 px de ancho y se guarda tambien una copia reducida (<salida>_reducida.png).
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

CELDA_W, CELDA_H = 540, 405
RUBRO_H = 84            # cabecera de cada celda (rotulo)
MARGEN = 10
BANDA_W = 74            # rotulo de la fila (girado)
FILAS = ["BOLA", "MURO", "PILAR", "BARRERA", "HAZ", "PROPIEDADES\nmuro 3,45·1,5·0,3", "PROPIEDADES\nbola r 0,4"]
FIGURAS = ["bola", "muro", "pilar", "barrera", "haz"]
FONDO = (22, 22, 26)
PAPEL = (34, 34, 40)
TEXTO = (240, 236, 228)
SUAVE = (170, 166, 158)
ACENTO = (255, 150, 60)


def fuente(tam, negrita=False):
    for ruta in (
        "C:/Windows/Fonts/segoeuib.ttf" if negrita else "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arialbd.ttf" if negrita else "C:/Windows/Fonts/arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if negrita else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        if os.path.exists(ruta):
            return ImageFont.truetype(ruta, tam)
    return ImageFont.load_default()


def num(v):
    s = ("%.2f" % v).rstrip("0").rstrip(".")
    return s.replace(".", ",")


def main():
    carpeta, salida = sys.argv[1], sys.argv[2]
    ancho_red = int(sys.argv[3]) if len(sys.argv) > 3 else 2400
    celdas = json.load(open(os.path.join(carpeta, "celdas.json"), encoding="utf-8"))
    cols = max(c["col"] for c in celdas) + 1
    filas = max(c["fila"] for c in celdas) + 1
    ancho = BANDA_W + MARGEN + cols * (CELDA_W + MARGEN)
    cab = 120
    nfig = 1 + max(c["fila"] for c in celdas if not c.get("prop"))
    sep = 46                 # franja entre figuras y propiedades
    alto_celda = RUBRO_H + CELDA_H
    alto = cab + nfig * (alto_celda + MARGEN) + sep + 2 * (alto_celda + MARGEN) + MARGEN
    im = Image.new("RGB", (ancho, alto), FONDO)
    d = ImageDraw.Draw(im)
    f_t, f_s, f_c, f_p, f_b = fuente(40, True), fuente(22), fuente(23, True), fuente(20), fuente(30, True)
    d.text((MARGEN * 2, 14), "FuegoToy: los ejes (x, y, z) y las propiedades, una sola escena paramétrica", font=f_t, fill=TEXTO)
    d.text((MARGEN * 2, 66), "Misma dirección de cámara y mismo FOV en todas las celdas; la distancia se ajusta para que quepan el efecto y el cubo gris de 1 m de referencia (a su izquierda). "
           "Semiejes en metros.", font=f_s, fill=SUAVE)
    d.text((MARGEN * 2, 92), "Columnas de las filas de figuras: pequeño · tamaño de la prueba 3 · grande · anisótropo A · anisótropo B · escena validada (no hay del haz: es nuevo) de la prueba 3 (para comparar) · bola en vuelo.",
           font=f_s, fill=SUAVE)

    def y_fila(f):
        if f < nfig:
            return cab + f * (alto_celda + MARGEN)
        return cab + nfig * (alto_celda + MARGEN) + sep + (f - nfig) * (alto_celda + MARGEN)

    d.text((MARGEN * 2, y_fila(nfig) - sep + 6), "PROPIEDADES (mandos de EfectoToy) sobre el muro 3,45·1,5·0,3 y la bola de radio 0,4", font=f_b, fill=ACENTO)
    for f in range(filas):
        y0 = y_fila(f)
        banda = Image.new("RGB", (alto_celda, BANDA_W), PAPEL)
        bd = ImageDraw.Draw(banda)
        lineas = FILAS[f].split("\n")
        for i, ln in enumerate(lineas):
            bd.text((16, 6 + i * 30 if len(lineas) > 1 else 20), ln, font=f_c if i == 0 else f_p, fill=ACENTO if i == 0 else SUAVE)
        im.paste(banda.rotate(90, expand=True), (0, y0))
    for c in celdas:
        x0 = BANDA_W + MARGEN + c["col"] * (CELDA_W + MARGEN)
        y0 = y_fila(c["fila"])
        ruta = os.path.join(carpeta, "celda_%s.png" % c["id"])
        d.rectangle([x0, y0, x0 + CELDA_W, y0 + RUBRO_H], fill=PAPEL)
        figura = FIGURAS[c["figura"]]
        d.text((x0 + 10, y0 + 5), c["titulo"], font=f_c, fill=TEXTO)
        if c["validada"]:
            linea2 = "%s validada (escena de la prueba 3)" % figura
        else:
            linea2 = "%s · x·y·z = %s·%s·%s m" % (figura, num(c["x"]), num(c["y"]), num(c["z"]))
        d.text((x0 + 10, y0 + 36), linea2, font=f_p, fill=SUAVE)
        if c["viaja"]:
            d.text((x0 + 10, y0 + 60), "viaja = sí (cola, jirones y estelas)", font=fuente(16), fill=SUAVE)
        elif c["props"]:
            d.text((x0 + 10, y0 + 60), ", ".join("%s = %s" % (k, num(v)) for k, v in c["props"].items()), font=fuente(16), fill=ACENTO)
        if os.path.exists(ruta):
            img = Image.open(ruta).convert("RGB").resize((CELDA_W, CELDA_H), Image.LANCZOS)
            im.paste(img, (x0, y0 + RUBRO_H))
        else:
            d.rectangle([x0, y0 + RUBRO_H, x0 + CELDA_W, y0 + RUBRO_H + CELDA_H], outline=(200, 60, 60))
            d.text((x0 + 20, y0 + RUBRO_H + 20), "FALTA la captura", font=f_c, fill=(220, 90, 90))
    im.save(salida)
    print("lamina", salida, im.size)
    if im.size[0] > ancho_red:
        red = im.resize((ancho_red, int(im.size[1] * ancho_red / im.size[0])), Image.LANCZOS)
        ruta_red = os.path.splitext(salida)[0] + "_reducida.png"
        red.save(ruta_red)
        print("reducida", ruta_red, red.size)


if __name__ == "__main__":
    main()
