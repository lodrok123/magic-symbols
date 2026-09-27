"""Corta la lamina de maleza y la deja lista para la rejilla.

Mismo contrato que el resto de adornos del juego, y por eso no hay ni un
desplazamiento a ojo:

  - Lienzo de 128 de ancho (el rombo mide 116) y alto variable por
    familia, siempre PAR: el Sprite2D va centrado, asi que el centro del
    lienzo es el nodo.
  - EL PIE DE LA PIEZA CAE EN +2 del centro, que es donde esta la
    cintura del rombo de la losa. Es el mismo anclaje que ya usan
    prop_tree y compania desde que se arreglo el hundimiento.

Uso:  python gen_props_bosque.py <lamina.png> <carpeta_destino>
"""
from PIL import Image
import numpy as np
from scipy import ndimage
import os, sys, json

## El ancho del rombo. Todo se mide contra esto.
ROMBO = 116

## Donde cae el pie, contando desde el centro del lienzo.
CARA = 2

ANCHO = 128

## Cuanto se reduce cada familia. UNA POR FAMILIA Y NO UNA SOLA, que fue
## el primer intento y salio mal: en la lamina todas las piezas estan
## dibujadas al mismo tamano de dibujo, no al mismo tamano de mundo, asi
## que un corro de setas ocupa lo mismo que un arbusto entero. Con un
## factor unico las setas salian tan altas como la maga.
##
## Los numeros salen de contra que se mide cada cosa: el rombo son 116 px
## y la maga 78 de alto.
##   setas      un corro de setas le llega por la rodilla -> ~20 px
##   mata       un helecho por la cintura                 -> ~40 px
##   arbusto    por el pecho                              -> ~55 px
##   arbolillo  le saca la cabeza, sin llegar al arbol    -> ~65 px
ESCALAS = {
    "arbusto": 0.40,
    "mata": 0.34,
    "setas": 0.24,
    "tronco": 0.38,
    "cepa": 0.34,
    "arbolillo": 0.48,
    "roca": 0.38,
    "enredadera": 0.44,
}
ESCALA = 0.40      # para lo que no tenga familia propia

## Que es cada fila y como se llaman sus piezas. El orden es el de
## lectura; si la hoja cambia, esto es lo unico que se toca.
FILAS = [
    "arbusto", "mata", "setas", "tronco",
    "cepa", "arbolillo", "roca", "enredadera",
]

UMBRAL = 28          # el fondo es negro puro (1,1,1), no hace falta mas
MINIMO = 900         # por debajo es basura de compresion


def piezas(a):
    occ = a.max(axis=2) > UMBRAL
    lab, n = ndimage.label(occ)
    tam = ndimage.sum(occ, lab, range(1, n + 1))
    cajas = ndimage.find_objects(lab)
    vivos = [(i + 1, cajas[i]) for i in range(n) if tam[i] > MINIMO]

    # Agrupar en filas por el centro vertical, no por una rejilla: las
    # piezas no estan alineadas y una rejilla regular partiria las altas.
    centros = sorted(((c[0].start + c[0].stop) // 2, (c[1].start + c[1].stop) // 2, i, c)
                     for i, c in vivos)
    filas, actual = [], [centros[0]]
    for p in centros[1:]:
        if p[0] - actual[-1][0] > 70:
            filas.append(actual); actual = [p]
        else:
            actual.append(p)
    filas.append(actual)
    for f in filas:
        f.sort(key=lambda t: t[1])
    return lab, filas


def recortar(a, lab, idx, caja):
    sy, sx = caja
    m = lab[sy, sx] == idx
    # Un poco de dilatacion para no comerse el antialias del borde.
    m = ndimage.binary_dilation(m, np.ones((3, 3)))
    img = a[sy, sx]
    return Image.fromarray(np.dstack([img, np.where(m, 255, 0)]).astype("uint8"), "RGBA")


def colocar(fig, escala):
    w = max(1, round(fig.width * escala))
    h = max(1, round(fig.height * escala))
    fig = fig.resize((w, h), Image.LANCZOS)

    # El lienzo crece con la pieza en vez de ser fijo: una enredadera
    # colgante mide el triple que una seta, y un lienzo unico obligaria
    # a que todos midieran lo de la mas grande.
    alto = max(64, 2 * (h + 8 + CARA))
    if alto % 2:
        alto += 1

    lz = Image.new("RGBA", (ANCHO, alto), (0, 0, 0, 0))
    lz.alpha_composite(fig, ((ANCHO - w) // 2, alto // 2 + CARA - h))
    return lz


def main(origen, destino):
    os.makedirs(destino, exist_ok=True)
    a = np.asarray(Image.open(origen).convert("RGB")).astype(int)
    lab, filas = piezas(a)

    catalogo = {}
    for nf, fila in enumerate(filas):
        familia = FILAS[nf] if nf < len(FILAS) else f"fila{nf}"
        for k, (_, _, idx, caja) in enumerate(fila, start=1):
            nombre = f"{familia}_{k}"
            out = colocar(recortar(a, lab, idx, caja),
                          ESCALAS.get(familia, ESCALA))
            out.save(os.path.join(destino, nombre + ".png"))
            catalogo[nombre] = out.size
        print(f"  {familia:12} {len(fila)} piezas")

    json.dump(catalogo, open(os.path.join(destino, "_indice.json"), "w"), indent=1)
    print(f"  total {len(catalogo)}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__); sys.exit(1)
    main(sys.argv[1], sys.argv[2])
