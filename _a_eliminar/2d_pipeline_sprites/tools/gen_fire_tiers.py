"""Las tres intensidades del fuego, en el formato de siempre.

art/fx/fire.png ya salia de la carpeta 'weak' del Spellbook. Aqui se
recogen las otras dos que llevaban meses sin usarse:

    art/fx/fire.png       weak     potencia normal
    art/fx/fire_mid.png   medium   una amplificacion
    art/fx/fire_high.png  strong   dos o mas

Mismo contrato que gen_fx.py: 18 fotogramas de 128x128 en rejilla de 6
columnas (768x384). En REJILLA y no en tira por el limite de tamano de
textura; la tira original de strongFire.png mide 35623 px de ancho y
tumbaba el juego al arrancar.

TODAS LAS INTENSIDADES SE ENCUADRAN IGUAL, y eso es deliberado. Podria
parecer que el fuego fuerte tiene que ocupar mas pixeles en la hoja,
pero el tamano ya lo pone el hechizo: spell.gd escala el nodo con la
raiz de la potencia. Si ademas la hoja fuera mas grande, el aumento se
aplicaria dos veces y una amplificacion doble llenaria la pantalla. La
hoja aporta la FORMA —el fuego fuerte es una columna rugiente, el debil
unas lenguas sueltas— y la potencia aporta el tamano.

Uso:  python gen_fire_tiers.py <carpeta_Spellbook/fire> <carpeta_destino>
"""
from PIL import Image
import os
import sys

CELL, COLS, FRAMES = 128, 6, 18

## Cuanto del ancho de la celda ocupa el fotograma mas grande de la
## intensidad. No el 100%: al animarse, una llama que roza el borde se
## ve recortada en los fotogramas altos.
OCUPACION = 0.88

## Que archivos forman cada intensidad. Los de 'strong' vienen partidos
## en tres actos y se montan en ese orden —nace, arde, se apaga—, que es
## la misma estructura de tres actos que ya tienen las demas hojas.
TANDAS = {
    # SOLO LA LLAMA, del 2 al 23. La tanda 'medium' del pack sigue
    # despues con un impacto y una nube de humo: es un efecto distinto
    # —un meteorito que cae y revienta—, no un fuego mas fuerte. Meterlo
    # aqui costaba dos cosas: la lectura, porque el fuego amplificado
    # acabaria en humo negro, y el encuadre, porque la explosion es
    # cuatro veces mas ancha que la llama y al compartir escala dejaba
    # los diecisiete fotogramas anteriores hechos una miniatura.
    #
    # Las frames 26-41 son buenas y estan ahi cuando hagan falta, pero
    # para otra cosa: un impacto, o el final de una bola de fuego.
    "fire_mid.png": [
        ("mediumFire%04d.png", [2, 3, 4, 5, 6, 7, 9, 10, 11, 12,
                                13, 15, 16, 17, 19, 20, 22, 23]),
    ],
    "fire_high.png": [
        ("fireStrongBeginning%04d.png", [25, 27, 38, 40]),
        ("fireStrongRepeat%04d.png", [1, 2, 3, 4, 5, 7, 8, 9, 10, 11]),
        ("fireStrongEnd%04d.png", [1, 4, 7, 10]),
    ],
}

SUBCARPETA = {"fire_mid.png": "medium", "fire_high.png": "strong"}

## Donde se planta cada fotograma dentro de su celda.
##
## La ESCALA siempre se comparte: si cada fotograma se estirase hasta
## llenar su celda, la llama respiraria de tamano en vez de arder.
##
## El CENTRO depende de la tanda, y cuesta un rato darse cuenta:
##   - 'strong' es un remolino plantado en el sitio. Su centro comun es
##     el centro real del efecto, y respetarlo conserva el bamboleo.
##   - 'medium' es una bola de fuego que CAE: recorre media imagen de
##     arriba abajo. Con centro comun, los ultimos fotogramas se salian
##     de la celda por abajo y aparecian cortados. Se centra cada uno
##     por su cuenta, que aqui equivale a quitarle el viaje y quedarse
##     con la llama, que es lo unico que se queria de esa tanda.
CENTRADO_PROPIO = {"fire_mid.png"}


def main(origen: str, destino: str) -> None:
    os.makedirs(destino, exist_ok=True)

    for salida, tandas in TANDAS.items():
        carpeta = os.path.join(origen, SUBCARPETA[salida])
        cuadros = []
        for patron, numeros in tandas:
            for n in numeros:
                cuadros.append(Image.open(
                    os.path.join(carpeta, patron % n)).convert("RGBA"))

        # UNA SOLA ESCALA PARA TODA LA TANDA, calculada con el fotograma
        # mas grande. Encuadrar cada fotograma por separado seria el
        # error clasico: la llama "respiraria" de tamano en vez de
        # crecer, porque cada cuadro se estiraria hasta llenar la celda.
        caja = [0, 0]
        for im in cuadros:
            b = im.getbbox()
            if b:
                caja[0] = max(caja[0], b[2] - b[0])
                caja[1] = max(caja[1], b[3] - b[1])
        escala = CELL * OCUPACION / max(caja)

        propio = salida in CENTRADO_PROPIO
        comun = None if propio else _centro_comun(cuadros)

        filas = -(-FRAMES // COLS)
        hoja = Image.new("RGBA", (COLS * CELL, filas * CELL), (0, 0, 0, 0))

        for i, im in enumerate(cuadros[:FRAMES]):
            pequeno = im.resize(
                (max(1, round(im.width * escala)), max(1, round(im.height * escala))),
                Image.LANCZOS)

            centro = _centro_de(im) if propio else comun
            cx = round(centro[0] * escala)
            cy = round(centro[1] * escala)
            destino_x = (i % COLS) * CELL + CELL // 2 - cx
            destino_y = (i // COLS) * CELL + CELL // 2 - cy
            hoja.alpha_composite(pequeno, (destino_x, destino_y))

        hoja.save(os.path.join(destino, salida))
        print(f"  {salida:16s} {hoja.size[0]}x{hoja.size[1]}  "
              f"{len(cuadros)} fotogramas, escala {escala:.3f}")


def _centro_de(im):
    b = im.getbbox()
    return ((b[0] + b[2]) / 2.0, (b[1] + b[3]) / 2.0) if b else (0.0, 0.0)


## El centro de la tanda: el medio de la caja que encierra a TODOS los
## fotogramas. Se usa el mismo para los dieciocho.
def _centro_comun(cuadros):
    izq = arr = 10 ** 9
    der = aba = 0
    for im in cuadros:
        b = im.getbbox()
        if not b:
            continue
        izq, arr = min(izq, b[0]), min(arr, b[1])
        der, aba = max(der, b[2]), max(aba, b[3])
    return ((izq + der) / 2.0, (arr + aba) / 2.0)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
