"""Extrae de kenney_sketch-town.zip las piezas que usa el juego.

Se guarda en el repo para que el paso sea REPETIBLE: si manana se
cambia la escala o se elige otro cubo, se toca aqui y se relanza, en vez
de acordarse de que un dia alguien recorto unos PNG a mano.

Uso:  python gen_iso_tiles.py <carpeta_Tiles> <carpeta_destino>
"""
from PIL import Image
import sys, os

ESCALA = 0.5   # 256x352 -> 128x176

# A que bloque del juego corresponde cada pieza del pack. El mapeo sale
# redondo porque el pack son cubos de material y el juego ya estaba
# modelado como bloques de material.
SENCILLAS = {
    "grass_center":   "grass.png",   # GrassBlock fina: se cruza
    "water_center":   "water.png",   # WaterBlock
    "dirt_center":    "earth.png",   # EarthBlock: cubo entero, da altura
    "dirt_low":       "floor.png",   # NeutralBlock: losa baja, se pisa
    "structure_arch": "goal.png",    # la meta
}

# Compuestas: se montan DOS piezas sobre el mismo lienzo de 256x352.
# Al no mover ninguna, la alineacion sale sola y no hay que calcular
# ningun desplazamiento a mano.
COMPUESTAS = {
    "grass_grown.png": ["grass_center", "tree_single"],  # tupida: corta el paso
}

# La puerta trae sus DOS estados dibujados en el pack, y eso decide como
# se implementa: se cambia de textura, no se tiñe ni se esconde nada. Un
# arco abierto y un porton cerrado se leen al instante incluso de reojo,
# que es justo lo que hace falta cuando corres hacia ella antes de que se
# vuelva a cerrar.
PUERTAS = {
    "castle_gate":     "door_closed.png",
    "castle_gateOpen": "door_open.png",
}

# El conductor es la losa baja de siempre, pintada de metal.
#
# MISMA SILUETA QUE EL SUELO A PROPOSITO: no es un obstaculo ni un
# adorno, es una placa metida en el suelo por la que pasa la corriente.
# Si tuviera volumen propio se leeria como algo que estorba, y lo unico
# que hace es conducir.
#
# Se desatura y se vuelve a teñir; multiplicar por un gris no valdria,
# porque el naranja de la tierra sobrevive a la multiplicacion.
CONDUCTOR = ("dirt_low", "conductor.png", (0.80, 0.84, 0.94))


def apedrar(im, tinte):
    """Desatura y vuelve a teñir, conservando la transparencia."""
    salida = im.copy()
    px = salida.load()
    for y in range(salida.height):
        for x in range(salida.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            px[x, y] = (min(255, int(lum * tinte[0])),
                        min(255, int(lum * tinte[1])),
                        min(255, int(lum * tinte[2])), a)
    return salida


def main(tiles: str, destino: str) -> None:
    os.makedirs(destino, exist_ok=True)

    def cargar(nombre: str) -> Image.Image:
        return Image.open(os.path.join(tiles, nombre + "_N.png")).convert("RGBA")

    def guardar(im: Image.Image, nombre: str) -> None:
        tam = (round(im.width * ESCALA), round(im.height * ESCALA))
        # LANCZOS y no NEAREST: esto es arte vectorial plano, no pixel
        # art. Reducir con suavizado es lo correcto aqui; con NEAREST
        # los contornos saldrian dentados.
        im.resize(tam, Image.LANCZOS).save(os.path.join(destino, nombre))
        print(f"  {nombre:18s} {tam[0]}x{tam[1]}")

    for origen, nombre in SENCILLAS.items():
        guardar(cargar(origen), nombre)

    for nombre, capas in COMPUESTAS.items():
        out = cargar(capas[0])
        for capa in capas[1:]:
            out.alpha_composite(cargar(capa))
        guardar(out, nombre)

    for origen, nombre in PUERTAS.items():
        guardar(cargar(origen), nombre)

    guardar(apedrar(cargar(CONDUCTOR[0]), CONDUCTOR[2]), CONDUCTOR[1])


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
