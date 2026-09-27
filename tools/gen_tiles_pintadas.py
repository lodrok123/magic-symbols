"""Mete las losas pintadas en la rejilla del juego.

Tres cosas que hay que hacer y ninguna se ve a ojo:

  1. APLASTARLAS. Lo generado viene en isometrico VERDADERO (30 grados,
     razon 1.732 = raiz de 3) y el juego usa 2.109. Medido sobre la
     pendiente del borde inferior de cinco cubos: 0.577, 0.576, 0.576,
     0.572, 0.578 — clavado en 0.577, que es 30 grados exactos. Es un 18%
     de diferencia: en una pieza suelta no se nota, pero al enlosar las
     juntas no cierran.

     Se corrige con una escala vertical, y es EXACTA: 1.732/2.109.

  2. RECORTAR EL FONDO. Viene negro opaco, no en alfa.

  3. COLOCARLAS EN EL LIENZO. El juego centra el sprite en la casilla, asi
     que el centro de la cara superior tiene que caer en el mismo sitio
     que en las losas actuales (y=183 de 352). Los adornos no tienen cara
     superior: se alinean por la BASE, donde se apoyan.

Uso:  python gen_tiles_pintadas.py <hoja.png> <destino>
"""
from PIL import Image
import numpy as np
from scipy import ndimage
import os
import sys

W, H = 256, 352

## 256x352 -> 128x176. El mismo de gen_iso_tiles.py y gen_props.py, y por
## el mismo motivo: se compone en el lienzo del pack, donde el anclaje
## sale solo, y se reduce al final de una vez.
ESCALA = 0.5

## Medido en las losas que ya usa el juego (dirt_center): el centro de su
## cara superior cae aqui. Todo lo demas se alinea a esto.
CENTRO_CARA = 183

## Donde apoyan los adornos. Sale de tree_single del pack, que se
## compone correctamente sobre estas mismas losas.
BASE_ADORNO = 307

## 1.732 / 2.109. No es un ajuste a ojo: es la razon entre el isometrico
## de 30 grados y el de la rejilla.
APLASTADO = 1.732 / 2.109

TOLERANCIA = 26


## El tocon del juego NO es un tocon cualquiera: es lo que queda de un
## arbol despues de arder. El dibujado esta recien cortado, con setas y
## madera clara, y puesto donde ardio un arbol se lee como otra cosa.
TIZNAR = {"prop_stump.png"}
CARBON = (0.50, 0.41, 0.36)


def tiznar(im):
    """Desatura y tiñe en pardo oscuro: madera quemada.

    Se desatura antes de teñir porque multiplicar a secas conserva el
    tono, y una madera clara multiplicada por marron sigue siendo madera
    clara. Hay que perder el color y volver a ponerlo.
    """
    a = np.asarray(im).astype(float).copy()
    lum = a[..., :3] @ np.array([0.299, 0.587, 0.114])
    for i, f in enumerate(CARBON):
        a[..., i] = np.clip(lum * f, 0, 255)
    return Image.fromarray(a.astype("uint8"), "RGBA")


def piezas(a):
    """Separa los objetos sueltos de la hoja."""
    fondo = np.median(np.concatenate([
        a[:12, :12].reshape(-1, 3), a[-12:, -12:].reshape(-1, 3)]), axis=0)
    occ = np.abs(a - fondo).max(axis=2) > TOLERANCIA
    lab, n = ndimage.label(ndimage.binary_closing(occ, np.ones((5, 5))))
    tam = ndimage.sum(occ, lab, range(1, n + 1))
    cajas = ndimage.find_objects(lab)
    vivos = [(i + 1, cajas[i]) for i in range(n) if tam[i] > 4000]
    # De arriba abajo y de izquierda a derecha, que es como se leen.
    vivos.sort(key=lambda t: (cajas[t[0] - 1][0].start // 200,
                              cajas[t[0] - 1][1].start))
    return [(lab == i, c) for i, c in vivos], occ


def recortar(a, mascara, caja):
    sy, sx = caja
    m = mascara[sy, sx]
    img = a[sy, sx]
    return Image.fromarray(
        np.dstack([img, np.where(m, 255, 0)]).astype("uint8"), "RGBA")


def colocar(fig, es_losa):
    """Aplasta y planta la pieza en el lienzo de 256x352."""
    ancho = max(1, round(fig.width * W / 256.0))
    fig = fig.resize((fig.width, max(1, round(fig.height * APLASTADO))),
                     Image.LANCZOS)

    # Que quepa de ancho sin deformar mas.
    if fig.width > W:
        k = W / fig.width
        fig = fig.resize((W, max(1, round(fig.height * k))), Image.LANCZOS)

    lienzo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    x = (W - fig.width) // 2

    if es_losa:
        # La cara superior de un cubo es su fila mas ancha. Ahi va el
        # centro, y por eso una losa alta y una baja acaban alineadas
        # aunque midan distinto.
        al = np.asarray(fig)[..., 3] > 20
        filas = al.sum(axis=1)
        y_esquinas = int(np.argmax(filas))
        y = CENTRO_CARA - y_esquinas
    else:
        # Un adorno no tiene cara superior: se apoya por abajo.
        y = BASE_ADORNO - fig.height

    lienzo.alpha_composite(fig, (x, y))

    # Y AQUI EL PASO QUE FALTABA. El lienzo del pack es de 256x352 y el
    # juego usa 128x176: gen_iso_tiles.py y gen_props.py terminan los dos
    # con este mismo 0.5, y esta version no. Sin el, las losas salen al
    # doble y todo lo demas —personajes, flechas, la pira— parece de
    # juguete al lado. Se reduce el LIENZO ENTERO, nunca el recorte, que
    # es lo que hace que el anclaje siga valiendo sin recalcular nada.
    return lienzo.resize((round(W * ESCALA), round(H * ESCALA)),
                         Image.LANCZOS)


## Que es cada pieza de la hoja y como se llama en el juego. El orden es
## el de lectura: arriba-izquierda a abajo-derecha.
PLAN = [
    ("floor.png",       True),   # tierra 1  -> la N del mapa, la que mas se ve
    ("earth.png",       True),   # tierra 2  -> la que se apila
    ("floor_b.png",     True),   # tierra 3  -> VARIANTE de la N
    ("grass.png",       True),   # hierba 1  -> la fina, se cruza
    ("grass_b.png",     True),   # hierba 2  -> VARIANTE de la hierba
    # La TUPIDA es la tercera, no la segunda: en el juego la hierba
    # crecida BLOQUEA EL PASO, y la de flores no lo dice. La tercera trae
    # matas y helechos, que si se leen como "por aqui no se pasa".
    ("grass_grown.png", True),   # hierba 3  -> tupida, corta el paso
    ("water.png",       True),   # agua 1
    ("water_b.png",     True),   # agua 2 (nenufares) -> VARIANTE
    (None,              True),   # agua 3 (cascada)
    ("prop_tree.png",   False),  # arbol frondoso
    ("prop_pine.png",   False),  # pino
    ("prop_grove.png",  False),  # arbol 2
    ("prop_rocks.png",  False),  # rocas 1
    (None,              False),  # rocas 2
    ("prop_boulder.png", False), # rocas 3 -> el canto que empuja el viento
    ("prop_cabin.png",  False),  # cabaña 1
    (None,              False),  # cabaña 2
    (None,              False),  # cabaña 3
    ("prop_stump.png",  False),  # tocon 1 -> el arbol QUEMADO (se tizna)
    (None,              False),  # tocon 2
]


def main(origen, destino):
    os.makedirs(destino, exist_ok=True)
    a = np.asarray(Image.open(origen).convert("RGB")).astype(int)
    trozos, _ = piezas(a)
    print(f"  {len(trozos)} piezas en la hoja, {len(PLAN)} en el plan")

    for k, (mascara, caja) in enumerate(trozos):
        if k >= len(PLAN) or PLAN[k][0] is None:
            continue
        nombre, es_losa = PLAN[k]
        fig = recortar(a, mascara, caja)
        if nombre in TIZNAR:
            fig = tiznar(fig)
        out = colocar(fig, es_losa)
        out.save(os.path.join(destino, nombre))
        print(f"    {nombre:18} {'losa ' if es_losa else 'adorno'}"
              f"  de {fig.width}x{fig.height}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
