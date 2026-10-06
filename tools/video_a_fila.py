"""De un video de personaje a una fila de la hoja de animacion.

    python tools/video_a_fila.py Hero_walking_N.mp4 --salida fila_N.png

Sirve para los videos generados con IA, que traen cuatro problemas que
un video de animacion de verdad no tiene. Cada uno tiene su apartado
mas abajo:

  1. FONDO     la figura viene sobre un color plano, no con alfa
  2. ZOOM      el personaje se acerca o se aleja mientras anda
  3. DERIVA    no anda en el sitio: se va moviendo por el encuadre
  4. BUCLE     el ciclo no cierra: el ultimo fotograma no enlaza con el primero

Lo que sale cumple docs/ANIMACION.md: una tira de CELDA x CELDA con la
figura al alto que toca, centrada, y pisando en PIES_Y. Esa tira se pega
luego en la fila que corresponda a su direccion (fila 6 = N).

Necesita ffmpeg en el PATH, y pillow + numpy + scipy.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image
from scipy import ndimage

# --- El contrato de la hoja (docs/ANIMACION.md) ---
CELDA = 128
FILAS = 8
ALTO_FIGURA = 75.0     # alto de la figura de pie, medido en la hoja actual
PIES_Y = 117           # donde pisa, dentro de la celda
CENTRO_X = 63.5

FILA_POR_DIRECCION = {
    "E": 0, "SE": 1, "S": 2, "SO": 3, "O": 4, "NO": 5, "N": 6, "NE": 7,
}


def sacar_fotogramas(video, destino):
    subprocess.run(
        ["ffmpeg", "-v", "error", "-i", video, "-vsync", "0",
         os.path.join(destino, "f%04d.png")],
        check=True)
    return sorted(os.listdir(destino))


def color_de_fondo(img):
    """El color plano del fondo: la mediana del marco de la imagen."""
    a = np.array(img.convert("RGB"))
    borde = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    return np.median(borde, axis=0).astype(int)


def silueta(img, fondo, marca, umbral):
    """Mascara de la figura, sin fondo y sin agujeros.

    Se queda con el TROZO CONECTADO MAS GRANDE y luego rellena sus
    huecos. Las dos cosas hacen falta: la firma de la IA es otro trozo
    suelto, y las partes oscuras del personaje (botas, pelo) se parecen
    al fondo y se abririan como agujeros dentro de la figura.
    """
    a = np.array(img.convert("RGB")).astype(int)
    if marca:
        x0, y0, x1, y1 = marca
        a[y0:y1, x0:x1] = fondo

    bruto = np.abs(a - fondo).sum(axis=2) > umbral
    etiq, cuantos = ndimage.label(bruto)
    if cuantos == 0:
        return bruto
    tam = ndimage.sum(bruto, etiq, range(1, cuantos + 1))
    return ndimage.binary_fill_holes(etiq == (np.argmax(tam) + 1))


def con_alfa(img, mascara, suavizado=1.2):
    """RGBA con el borde suavizado.

    Un alfa duro deja dientes de sierra en cuanto se reduce de 1400 px a
    75, y en un sprite pequeno eso se ve como suciedad alrededor.
    """
    suave = ndimage.gaussian_filter(mascara.astype(float), suavizado)
    alfa = np.clip((suave - 0.35) / 0.35, 0.0, 1.0)
    return np.dstack([np.array(img.convert("RGB")), (alfa * 255).astype(np.uint8)])


def normalizada(mascara, ancho=64, alto=128):
    """La silueta llevada siempre al mismo tamano, para poder comparar
    FORMAS sin que el zoom del video cuente como diferencia."""
    ys, xs = np.where(mascara)
    rec = mascara[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return np.array(Image.fromarray((rec * 255).astype(np.uint8))
                    .resize((ancho, alto))) / 255.0


def buscar_ciclo(normas, minimo=12, maximo=40):
    """El tramo que mejor cierra el bucle.

    Se prueba cada comienzo con cada duracion y se mide el SALTO entre el
    ultimo fotograma y el primero. Gana el que menos salta — pero
    restando el movimiento medio del tramo, porque si no gana siempre un
    trozo en el que el personaje esta casi quieto: cierra perfecto y no
    es un andar.
    """
    n = len(normas)

    def dist(i, j):
        return float(np.abs(normas[i] - normas[j]).mean())

    mejor = None
    for p in range(minimo, min(maximo, n - 1) + 1):
        for s in range(0, n - p):
            salto = dist(s, s + p)
            movimiento = np.mean([dist(s + k, s + k + 1) for k in range(p)])
            puntua = salto - movimiento * 1.4
            if mejor is None or puntua < mejor[0]:
                mejor = (puntua, s, p, salto, movimiento)
    return mejor[1], mejor[2], mejor[3], mejor[4]


def celda_de(rgba, mascara, alto_figura):
    """Un fotograma escalado y colocado dentro de su celda.

    CADA FOTOGRAMA SE ESCALA POR SU PROPIO ALTO, no todos por el mismo
    factor: eso es lo que anula el zoom del video. Con una escala comun,
    el personaje encogeria dentro de la celda segun se aleja de la camara.

    Y SE ANCLA POR LOS PIES, no por el centro de la caja. En isometrico
    todo se ordena por donde se pisa; anclando por la caja, el personaje
    daria saltitos verticales cada vez que levanta un brazo.
    """
    ys, xs = np.where(mascara)
    k = alto_figura / float(ys.max() - ys.min() + 1)

    img = Image.fromarray(rgba, "RGBA")
    img = img.resize((max(1, int(round(img.width * k))),
                      max(1, int(round(img.height * k)))), Image.LANCZOS)

    pie_y = ys.max() * k
    cen_x = (xs.min() + xs.max()) / 2.0 * k

    celda = Image.new("RGBA", (CELDA, CELDA), (0, 0, 0, 0))
    celda.alpha_composite(img, (int(round(CENTRO_X - cen_x)),
                                int(round(PIES_Y - pie_y))))
    return celda


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("video")
    p.add_argument("--salida", default=None, help="PNG de la tira (por defecto, junto al video)")
    p.add_argument("--gif", default=None, help="ademas, un GIF del ciclo para mirarlo")
    p.add_argument("--columnas", type=int, default=12,
                   help="fotogramas de la fila; TIENE que ser el mismo numero "
                        "que ya tienen las demas filas de la hoja (por defecto 12)")
    p.add_argument("--umbral", type=int, default=38,
                   help="cuanto se tiene que diferenciar del fondo para contar como figura")
    p.add_argument("--marca", default=None,
                   help="x0,y0,x1,y1 de la firma de la IA, para taparla antes de recortar")
    p.add_argument("--alto", type=float, default=ALTO_FIGURA)
    args = p.parse_args()

    if shutil.which("ffmpeg") is None:
        sys.exit("Hace falta ffmpeg en el PATH.")

    marca = tuple(int(v) for v in args.marca.split(",")) if args.marca else None
    salida = args.salida or os.path.splitext(args.video)[0] + "_fila.png"

    tmp = tempfile.mkdtemp(prefix="video_a_fila_")
    try:
        nombres = sacar_fotogramas(args.video, tmp)
        print("%d fotogramas" % len(nombres))

        imgs = [Image.open(os.path.join(tmp, n)) for n in nombres]
        fondo = color_de_fondo(imgs[0])
        print("fondo detectado: rgb%s" % (tuple(fondo),))

        mascaras = [silueta(im, fondo, marca, args.umbral) for im in imgs]
        rgbas = [con_alfa(im, m) for im, m in zip(imgs, mascaras)]

        altos = [np.ptp(np.where(m)[0]) + 1 for m in mascaras]
        print("alto de la figura: de %d a %d px (zoom del %.0f%%; se normaliza)"
              % (min(altos), max(altos),
                 100.0 * (max(altos) - min(altos)) / np.mean(altos)))

        normas = [normalizada(m) for m in mascaras]
        inicio, periodo, salto, mov = buscar_ciclo(normas)
        print("ciclo: fotogramas %d..%d (%d de largo)" % (inicio + 1, inicio + periodo, periodo))
        print("  salto al cerrar el bucle %.4f  /  salto normal entre fotogramas %.4f"
              % (salto, mov))
        if salto > mov * 1.6:
            print("  OJO: cierra peor que un paso normal. Se va a notar un tiron.")

        indices = [inicio + int(round(k * periodo / args.columnas))
                   for k in range(args.columnas)]

        tira = Image.new("RGBA", (CELDA * args.columnas, CELDA), (0, 0, 0, 0))
        for k, i in enumerate(indices):
            tira.alpha_composite(celda_de(rgbas[i], mascaras[i], args.alto), (k * CELDA, 0))
        tira.save(salida)
        print("tira -> %s  (%dx%d)" % (salida, tira.width, tira.height))

        if args.gif:
            cuadros = []
            for i in range(inicio, inicio + periodo):
                ys, xs = np.where(mascaras[i])
                k = 360.0 / (ys.max() - ys.min() + 1)
                im = Image.fromarray(rgbas[i], "RGBA")
                im = im.resize((int(im.width * k), int(im.height * k)), Image.LANCZOS)
                lienzo = Image.new("RGBA", (300, 420), (250, 248, 245, 255))
                lienzo.alpha_composite(im, (int(150 - (xs.min() + xs.max()) / 2 * k),
                                            int(400 - ys.max() * k)))
                cuadros.append(lienzo.convert("P", palette=Image.ADAPTIVE))
            cuadros[0].save(args.gif, save_all=True, append_images=cuadros[1:],
                            duration=42, loop=0, disposal=2)
            print("gif  -> %s" % args.gif)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
