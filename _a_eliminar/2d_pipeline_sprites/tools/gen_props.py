"""Saca de kenney_sketch-town.zip los ADORNOS del mundo.

Un adorno no es un bloque: no tiene losa propia, se pinta ENCIMA de la
casilla que ya haya. En el pack se distinguen solos por la caja de
recorte — grass_center ocupa 11..244 (la losa entera) y tree_single solo
63..193 (el arbol suelto, sin suelo debajo). Por eso se pueden poner
sobre hierba, sobre tierra o sobre lo que sea sin recortar nada.

El lienzo NO se recorta a proposito: se conserva el 256x352 original y
se reduce entero. Asi la alineacion sale sola, igual que en
gen_iso_tiles.py, y no hay ni un desplazamiento calculado a mano.

Uso:  python gen_props.py <carpeta_Tiles> <carpeta_destino>
"""
from PIL import Image
import sys, os

ESCALA = 0.5   # 256x352 -> 128x176

ADORNOS = {
    "tree_single":   "prop_tree.png",      # arbol: arde
    "tree_multiple": "prop_grove.png",     # arboleda: arde, mas grande
    "rocks_dirt":    "prop_rocks.png",     # rocas: se rompen
}

# El canto se PINTA DE GRIS a partir del mismo monton de rocas.
#
# Probe antes con rocks_grass para diferenciarlos, y en el nivel se veia
# mal: ese sprite trae su pizca de hierba y el suelo del nivel es tierra,
# asi que quedaban dos manchas verdes sueltas sobre naranja. El problema
# no era la forma, era el color del suelo que lleva pegado.
#
# Gris ademas DICE algo: la piedra suelta se distingue del monton de
# rocas de un vistazo, y el jugador necesita saber cual puede empujar
# antes de gastar un hechizo en averiguarlo.
#
# Y hay que DESATURAR, no multiplicar. Multiplicar por un gris conserva
# el tono: las rocas del pack son verdosas y por mucho que se oscurezcan
# siguen siendo verdes. Se pasa por luminancia y se vuelve a teñir.
PIEDRA = (0.86, 0.89, 0.98)

# El tocon se FABRICA, no se extrae: el pack no trae arbol quemado.
# Quedarse con la parte de abajo del cono y ennegrecerla da justo lo que
# hace falta — algo bajo, oscuro y con la misma silueta, para que se lea
# como "ese arbol de ahi, ya quemado" y no como un objeto nuevo.
## 248 y no 270: con el corte mas alto quedaba una raja negra de 37
## filas que no se leia como un tocon, se leia como un agujero. Hay que
## conservar suficiente cono para que se reconozca la silueta del arbol
## que habia ahi.
CORTE_TOCON = 248          # a partir de esta fila se conserva (de 352)

## Carbon: se desatura igual que la piedra y se tiñe en pardo oscuro.
## Multiplicando a secas quedaba verde oliva —el arbol es verde y el tono
## sobrevive a la multiplicacion—, y un tocon verde no se lee como
## quemado. Los valores son bajos pero no negros: asi conserva la luz y
## la sombra del dibujo, y tiene volumen en vez de ser una mancha.
CARBON = (0.52, 0.42, 0.36)


def apedrar(im, tinte):
    """Desatura y vuelve a teñir, conservando la transparencia.

    Multiplicar por un gris no habria valido: el tono sobrevive a la
    multiplicacion, asi que unas rocas verdes se quedan verdes por muy
    oscuras que se pongan. Hay que perder el color y volver a ponerlo.
    Vale igual para la piedra gris y para el carbon del tocon; lo unico
    que cambia entre los dos es el tinte.
    """
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

    def cargar(nombre):
        return Image.open(os.path.join(tiles, nombre + "_N.png")).convert("RGBA")

    def guardar(im, nombre):
        tam = (round(im.width * ESCALA), round(im.height * ESCALA))
        # LANCZOS: esto es arte vectorial plano, no pixel art.
        im.resize(tam, Image.LANCZOS).save(os.path.join(destino, nombre))
        print(f"  {nombre:20s} {tam[0]}x{tam[1]}")

    for origen, nombre in ADORNOS.items():
        guardar(cargar(origen), nombre)

    guardar(apedrar(cargar("rocks_dirt"), PIEDRA), "prop_boulder.png")

    arbol = cargar("tree_single")
    tocon = Image.new("RGBA", arbol.size, (0, 0, 0, 0))
    tocon.paste(arbol.crop((0, CORTE_TOCON, arbol.width, arbol.height)),
                (0, CORTE_TOCON))
    guardar(apedrar(tocon, CARBON), "prop_stump.png")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
