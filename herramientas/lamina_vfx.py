"""Monta la LAMINA de ejes y propiedades del fuego parametrico (FuegoToy) con PIL.

Uso:
    python herramientas/lamina_vfx.py <carpeta con celda_*.png y celdas.json> <lamina.png> [ancho_reducido=2400]

Las capturas las saca herramientas/captura_fuego_parametrico.gd (modo celdas).
Modo "en el juego" (A1, 2/11/2026): python herramientas/lamina_vfx.py --en-juego <carpeta con <elemento>_<hechizo>_<actual|procedural>_<t>.png y celdas.json> <lamina.png>
    (las saca herramientas/captura_vfx_en_juego.gd con la camara del juego): una fila por hechizo, y por elemento dos columnas lado a lado, el dibujo ACTUAL y el PROCEDURAL (FuegoToy / AguaToy). Cada celda lleva su rotulo (titulo, figura y ejes x·y·z en metros, propiedades);
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


# ---------------------------------------------------------------- modo "en el juego" (A1, 2/11/2026) ----------------------------------------------------------------
# Fotogramas completos de 1280x720 con la camara del juego (ortogonal): se recorta un area alrededor de la jugadora (centro de pantalla), a escala 1:1 de pixeles
# del juego (sin reescalar, para que el tamano de los dos dibujos se pueda comparar a ojo), y se ponen lado a lado.
EJ_RECORTE = (480, 160, 1280, 640)    # x0, y0, x1, y1 del recorte (800x480): la jugadora (centro de pantalla, ~645, 380) y lo que sale por delante (un muro a 2 casillas queda a ~550 px; la jugadora, a la izquierda)
EJ_CELDA = (640, 384)                 # tamano de la celda en la lamina: 0,8 de los pixeles del juego, igual en todas las celdas
EJ_HECHIZOS = [("bola_quieta", "BOLA QUIETA"), ("proyectil", "PROYECTIL"), ("muro", "MURO"), ("pilar", "PILAR"), ("barrera", "BARRERA"), ("haz", "HAZ"), ("carga", "CARGA EN LA MANO")]
EJ_ELEMENTOS = ["fuego", "agua"]


def lamina_en_juego(carpeta, salida, ancho_red=2400):
    celdas = json.load(open(os.path.join(carpeta, "celdas.json"), encoding="utf-8"))
    tiempos = sorted({c["t"] for c in celdas})
    t_sel = tiempos[0] if tiempos else 0.45
    # un solo fotograma por celda: el primero (formado) y, si hay, el segundo (asentado / en pleno vuelo) como segunda fila de la misma figura
    col_w, col_h = EJ_CELDA
    cols = len(EJ_ELEMENTOS) * 2
    ancho = BANDA_W + MARGEN + cols * (col_w + MARGEN)
    cab = 150
    fila_h = col_h + MARGEN
    filas = [(h, n, t) for (h, n) in EJ_HECHIZOS for t in tiempos]
    alto = cab + len(filas) * fila_h + MARGEN
    im = Image.new("RGB", (ancho, alto), FONDO)
    d = ImageDraw.Draw(im)
    f_t, f_s, f_c, f_p = fuente(40, True), fuente(22), fuente(23, True), fuente(20)
    d.text((MARGEN * 2, 14), "Fuego y agua en el juego: lo de antes (ACTUAL) frente a FuegoToy / AguaToy (PROCEDURAL)", font=f_t, fill=TEXTO)
    d.text((MARGEN * 2, 66), "Camara del juego (ortogonal a 60 grados, zoom de la maqueta), misma luz y mismo sitio en todas las celdas; recorte 1:1 de pixeles alrededor de la jugadora. Bosque 01 v01.", font=f_s, fill=SUAVE)
    d.text((MARGEN * 2, 92), "Cada hechizo, en dos instantes (%s s y %s s tras lanzar). Lado a lado: actual | procedural, para fuego y luego para agua." % (num(tiempos[0]), num(tiempos[-1]) if len(tiempos) > 1 else "-"), font=f_s, fill=SUAVE)
    x_col = lambda c: BANDA_W + MARGEN + c * (col_w + MARGEN)
    for ie, el in enumerate(EJ_ELEMENTOS):
        for im_, modo in enumerate(["actual", "procedural"]):
            c = ie * 2 + im_
            d.text((x_col(c) + 8, cab - 36), "%s · %s" % (el.upper(), modo.upper()), font=f_c, fill=ACENTO if modo == "procedural" else TEXTO)
    for r, (h, nombre, t) in enumerate(filas):
        y0 = cab + r * fila_h
        banda = Image.new("RGB", (col_h, BANDA_W), PAPEL)
        bd = ImageDraw.Draw(banda)
        bd.text((12, 8), nombre, font=f_c, fill=ACENTO)
        bd.text((12, 40), "%s s" % num(t), font=f_p, fill=SUAVE)
        im.paste(banda.rotate(90, expand=True), (0, y0))
        for ie, el in enumerate(EJ_ELEMENTOS):
            for im_, modo in enumerate(["actual", "procedural"]):
                ruta = os.path.join(carpeta, "%s_%s_%s_%03d.png" % (el, h, modo, int(round(t * 100))))
                x0 = x_col(ie * 2 + im_)
                if os.path.exists(ruta):
                    img = Image.open(ruta).convert("RGB").crop(EJ_RECORTE).resize(EJ_CELDA, Image.LANCZOS)
                    im.paste(img, (x0, y0))
                else:
                    d.rectangle([x0, y0, x0 + col_w, y0 + col_h], outline=(200, 60, 60))
                    d.text((x0 + 20, y0 + 20), "FALTA la captura", font=f_c, fill=(220, 90, 90))
    im.save(salida)
    print("lamina", salida, im.size)
    if im.size[0] > ancho_red:
        red = im.resize((ancho_red, int(im.size[1] * ancho_red / im.size[0])), Image.LANCZOS)
        ruta_red = os.path.splitext(salida)[0] + "_reducida.png"
        red.save(ruta_red)
        print("reducida", ruta_red, red.size)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--en-juego":
        lamina_en_juego(sys.argv[2], sys.argv[3], int(sys.argv[4]) if len(sys.argv) > 4 else 2400)
    else:
        main()
