"""Genera art/floor_tile.png: la capa neutra de relleno.

Tiene que cumplir tres cosas, y las tres importan:

1. SIN COSTURAS. Se repite por toda la pantalla, asi que el ruido se
   genera con envoltura (el borde derecho continua en el izquierdo).
   Sin esto se ve una rejilla y queda peor que el fondo liso.

2. NEUTRA DE VERDAD. Se saca del color de la losa de tierra (#8E4704)
   pero DESATURADA y a medio camino de valor. Si tuviera tanto color
   como las losas competiria con ellas; si fuera tan oscura como el
   fondo actual no arreglaria nada. Su trabajo es no llamar la atencion.

3. CON PINTA DE PIXEL ART. El ruido se cuantiza a 5 tonos. Un degradado
   continuo al lado de losas de pixel art canta muchisimo."""
from PIL import Image
import random

SIZE = 128
OCTAVAS = (4, 8, 16, 32, 64)   # celdas por lado de cada capa de ruido
TONOS = 5


def ruido_envolvente(celdas, seed):
    """Ruido de valor que se repite sin costura.

    El truco es el modulo en los indices: al interpolar, la celda de la
    derecha del ultimo punto es OTRA VEZ la primera. Asi el pixel 63
    enlaza con el 0 y el mosaico no tiene junta."""
    rnd = random.Random(seed)
    rejilla = [[rnd.random() for _ in range(celdas)] for _ in range(celdas)]
    paso = SIZE / celdas
    salida = [[0.0] * SIZE for _ in range(SIZE)]

    for y in range(SIZE):
        gy = y / paso
        y0 = int(gy) % celdas
        y1 = (y0 + 1) % celdas
        ty = gy - int(gy)
        ty = ty * ty * (3 - 2 * ty)          # suavizado
        for x in range(SIZE):
            gx = x / paso
            x0 = int(gx) % celdas
            x1 = (x0 + 1) % celdas
            tx = gx - int(gx)
            tx = tx * tx * (3 - 2 * tx)
            arriba = rejilla[y0][x0] * (1 - tx) + rejilla[y0][x1] * tx
            abajo = rejilla[y1][x0] * (1 - tx) + rejilla[y1][x1] * tx
            salida[y][x] = arriba * (1 - ty) + abajo * ty
    return salida


# --- La rampa de color -------------------------------------------------
# Del mismo tronco que la losa de tierra (142,71,4) pero llevada hacia
# el morado de sombra (71,32,67) que comparten todas las losas: asi la
# capa neutra pertenece a la misma familia aunque no compita.
BASE = (92, 68, 60)
RANGO = 19


def rampa(i):
    f = (i / (TONOS - 1) - 0.5) * 2.0        # -1 .. 1
    return tuple(max(0, min(255, int(c + f * RANGO + (6 if i == TONOS - 1 else 0))))
                 for c in BASE)


campo = [[0.0] * SIZE for _ in range(SIZE)]
for k, celdas in enumerate(OCTAVAS):
    peso = 1.0 / (2 ** k)
    capa = ruido_envolvente(celdas, 100 + k)
    for y in range(SIZE):
        for x in range(SIZE):
            campo[y][x] += capa[y][x] * peso

lo = min(min(f) for f in campo)
hi = max(max(f) for f in campo)

img = Image.new("RGBA", (SIZE, SIZE))
for y in range(SIZE):
    for x in range(SIZE):
        n = (campo[y][x] - lo) / (hi - lo)
        img.putpixel((x, y), rampa(int(n * TONOS * 0.999)) + (255,))

img.save("floor_tile.png")
print("floor_tile.png", img.size)

# Comprobacion de costura: la primera y la ultima columna deben poder
# ir pegadas sin salto brusco. Se mide y se dice, no se supone.
px = img.load()
peor = 0
for y in range(SIZE):
    for a, b in ((px[SIZE - 1, y], px[0, y]), (px[y, SIZE - 1], px[y, 0])):
        peor = max(peor, max(abs(a[i] - b[i]) for i in range(3)))
print(f"salto maximo en la junta: {peor} niveles (de 255)")

# Vista previa: 4x4 repeticiones, para ver si aparece rejilla
prev = Image.new("RGBA", (SIZE * 4, SIZE * 3))
for j in range(3):
    for i in range(4):
        prev.paste(img, (i * SIZE, j * SIZE))
prev.save("preview_tiled.png")
