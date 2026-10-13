"""Monta las hojas de animacion del personaje pintado.

Coge la hoja tal y como la escupe el generador y la deja en la rejilla
que espera actor_animator.gd. Hay tres cosas que traducir, y las tres
darian un fallo distinto si se hicieran a ojo:

  1. ESTA TRASPUESTA. El generador saca columnas = direcciones y filas =
     fotogramas; el animador quiere lo contrario.

  2. EL ORDEN DE LAS DIRECCIONES NO COINCIDE. El generador las saca en
     S SE E NE N NO O SO, que es como las lista cualquiera. El animador
     las numera con posmod(round(angulo/45), 8) sobre el angulo
     desaplastado, con 0 grados = derecha de pantalla, o sea
     E SE S SO O NO N NE. Ponerlas en el orden "natural" hace que la
     maga ande mirando hacia donde no es, y parece un fallo de fisica.

  3. EL FONDO ES NEGRO OPACO, no transparente.

Uso:  python gen_hero_sheets.py <hoja.png> <destino> [clip] [columnas] [filas]
"""
from PIL import Image
import numpy as np
from scipy import ndimage
import os
import sys

## Celda de 96 y no de 64. Medido componiendo la figura sobre las losas:
## a 60 px parece un muñeco, a 96 se come el bloque de detras, y a 78
## ocupa el ancho de la cara superior del rombo y se lee como alguien de
## pie SOBRE la casilla. 78 de figura + aire = celda de 96.
## CELDA DE 128 y no de 96, aunque la figura de pie siga midiendo 78.
##
## El sobrante no es capricho: en la animacion de muerte el personaje
## acaba TUMBADO, y un cuerpo tendido mide poco de alto pero mucho de
## ancho. Medido en la hoja: de pie 213 px, tumbada 138 de alto y mucho
## mas ancha. En una celda de 96 se salia por los lados.
CELL, ALTO, PIES = 128, 78, 118

## Como llegan y como se quieren.
ENTRADA = ["S", "SE", "E", "NE", "N", "NO", "O", "SO"]
ANIMADOR = ["E", "SE", "S", "SO", "O", "NO", "N", "NE"]

## Cuanto puede alejarse un pixel del color del fondo y seguir siendo
## fondo. Se compara canal a canal contra el color medido en las
## esquinas, no contra un umbral fijo.
##
## EL UMBRAL FIJO NO VALE, y costo un susto: las hojas han llegado con
## tres fondos distintos —alfa de verdad, negro puro y gris (31,30,30)—
## y el gris suma 91, justo por encima del corte de 90 que habia. El
## detector lo tomo por figura entera: decia que solo el 9% era fondo
## cuando era el 61%, y las medidas del ciclo salian todas falsas.
TOLERANCIA = 26

## Las direcciones que se sacan espejando su pareja.
ESPEJO = {"SO": "SE", "O": "E", "NO": "NE"}

## Manchas de borde. El generador deja pixeles rojos y amarillos sueltos
## pegados al contorno (medido: el 0.8% de lo opaco en la hoja de idle).
## Son restos del recorte del alfa, no dibujo, y a 78 px se ven como
## purpurina. Se les quita el alfa en vez de repintarlos: borrar un
## pixel de contorno no se nota, inventarle un color si.
def limpiar_bordes(im):
    a = np.asarray(im).astype(int).copy()
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    rojo = (r > 110) & (g < 70) & (b < 70)
    amarillo = (r > 120) & (g > 105) & (b < 80)
    a[..., 3] = np.where((rojo | amarillo) & (al > 0), 0, al)
    return Image.fromarray(a.astype("uint8"), "RGBA")


def fondo_fuera(rgba):
    """Marca que pixeles son figura, sea cual sea el fondo que traiga.

    Si la hoja tiene alfa de verdad, manda el alfa. Si no, el color del
    fondo se MIDE en las esquinas y se descarta lo que se le parezca.
    Deducirlo en vez de suponerlo es lo unico que funciona cuando cada
    tanda llega de una manera.
    """
    if (rgba[..., 3] < 250).any():
        return rgba[..., 3] > 40

    a = rgba[..., :3]
    h, w, _ = a.shape
    k = max(4, min(h, w) // 60)
    esquinas = np.concatenate([
        a[:k, :k].reshape(-1, 3), a[:k, -k:].reshape(-1, 3),
        a[-k:, :k].reshape(-1, 3), a[-k:, -k:].reshape(-1, 3)])
    color = np.median(esquinas, axis=0)
    return np.abs(a - color).max(axis=2) > TOLERANCIA


def bandas(perfil, cuantas):
    """Reparte un eje en tramos. Rejilla regular primero, valles despues.

    Las dos mitades de esto son cicatrices de sendos fallos.

    NO SE DIVIDE EL LIENZO EN PARTES IGUALES, sino el TROZO QUE TIENE
    CONTENIDO. Las hojas llegan con margenes desiguales —una traia 58 px
    de aire a la izquierda y 67 a la derecha— asi que repartir el ancho
    total desplaza todos los cortes.

    Y LOS VALLES SOLO AJUSTAN, no deciden. Buscarlos en una ventana
    amplia fue el segundo fallo: en la hoja de trenzas los huecos reales
    estaban en 212-279 y 431-504, pero la busqueda se iba a los multiplos
    de 229, que caen DENTRO de las figuras. Salian columnas de 204 y de
    287 para figuras iguales. Con una ventana estrecha (8% del paso) el
    valle solo corrige el pequeño desfase y no puede escaparse a otra
    figura.
    """
    n = len(perfil)
    lleno = [i for i in range(n) if perfil[i] > 0]
    ini, fin = (lleno[0], lleno[-1] + 1) if lleno else (0, n)
    paso = (fin - ini) / cuantas

    cortes = [ini]
    for k in range(1, cuantas):
        centro = int(ini + k * paso)
        margen = max(2, int(paso * 0.08))
        ventana = range(max(1, centro - margen), min(n - 1, centro + margen))
        cortes.append(min(ventana, key=lambda y: perfil[y]))
    cortes.append(fin)
    return list(zip(cortes[:-1], cortes[1:]))


## Cuanto se asoma cada celda a la de al lado antes de recortar.
##
## Hace falta porque EN ALGUNAS HOJAS LAS FIGURAS SE TOCAN: en la de las
## trenzas no hay hueco entre tres de las filas, y el corte le rebanaba
## 3, 16 y 20 px a la punta del pelo o a las botas. Con margen se recoge
## lo que sobresale, y la componente conexa del centro se encarga de
## tirar el trozo de la vecina que entra de rebote.
MARGEN = 26


def celda(a, occ, y0, y1, x0, x1):
    # Se mira una ventana MAS GRANDE que la celda...
    ya, yb = max(0, y0 - MARGEN), min(occ.shape[0], y1 + MARGEN)
    xa, xb = max(0, x0 - MARGEN), min(occ.shape[1], x1 + MARGEN)
    m = occ[ya:yb, xa:xb].copy()
    if not m.any():
        return None

    # ...y se conserva SOLO la mancha que pasa por el centro de la celda
    # de verdad. Asi la figura entra entera aunque se salga de su casilla,
    # y la vecina que asoma se queda fuera aunque este pegada.
    etq, n = ndimage.label(ndimage.binary_closing(m, np.ones((3, 3))))
    cy, cx = (y0 + y1) // 2 - ya, (x0 + x1) // 2 - xa
    quien = etq[cy, cx]
    if quien == 0:
        # El centro puede caer en un hueco del dibujo (entre las piernas,
        # por ejemplo). Se coge entonces la mancha mas grande de la celda.
        dentro = etq[y0 - ya:y1 - ya, x0 - xa:x1 - xa]
        vals, cuenta = np.unique(dentro[dentro > 0], return_counts=True)
        if len(vals) == 0:
            return None
        quien = vals[int(np.argmax(cuenta))]
    m = etq == quien

    ys, xs = np.where(m)
    img = a[ya:yb, xa:xb][ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    mk = m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return limpiar_bordes(Image.fromarray(
        np.dstack([img, np.where(mk, 255, 0)]).astype("uint8"), "RGBA"))


def encajar(fig, esc):
    """Coloca la figura ya escalada, centrada y apoyada en PIES.

    LA ESCALA VIENE DE FUERA, UNA SOLA PARA TODA LA HOJA, y es lo que
    salva la animacion de muerte. Escalando cada fotograma a 78 px de
    alto —que es lo que hacia antes— el cuerpo tumbado, que mide 138 en
    vez de 213, se inflaba un 54% y la maga crecia al morirse.
    """
    w = max(1, round(fig.width * esc))
    h = max(1, round(fig.height * esc))
    fig = fig.resize((w, h), Image.LANCZOS)
    c = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    c.alpha_composite(fig, ((CELL - w) // 2, PIES - h))
    return c


## Ida y vuelta: 0,1,..,n-1,n-2,..,1. Cierra cualquier secuencia sin
## salto, porque el ultimo fotograma es vecino del primero por
## construccion.
##
## Es un apaño y conviene saber de que: un andar de verdad ALTERNA las
## piernas, y medido sobre la hoja de trenzas el mismo pie iba delante en
## los siete fotogramas (la zancada solo se abria, de 105 a 136 px). Eso
## es medio paso. De ida y vuelta se lee como andar —el cuerpo sube y
## baja, las piernas se abren y se cierran, y no hay tiron al repetir—
## pero es un vaiven, no una marcha. Se arregla dibujando.
def vaiven(n):
    return list(range(n)) + list(range(n - 2, 0, -1))


def main(origen, destino, clip="walk", ncols=8, nfilas=7, ida_y_vuelta=False):
    os.makedirs(destino, exist_ok=True)
    src = Image.open(origen).convert("RGBA")
    rgba = np.asarray(src).astype(int)
    a = rgba[..., :3]
    occ = fondo_fuera(rgba)

    filas = bandas(occ.sum(axis=1), nfilas)
    cols = bandas(occ.sum(axis=0), ncols)

    # PRIMERA PASADA: la figura mas alta y la mas ancha de toda la hoja.
    # La escala sale de ahi y vale para todos los fotogramas, que es lo
    # que mantiene las proporciones entre unos y otros.
    alto_max = ancho_max = 1
    for _, (y0, y1) in enumerate(filas):
        for x0, x1 in cols:
            f = celda(a, occ, y0, y1, x0, x1)
            if f:
                alto_max = max(alto_max, f.height)
                ancho_max = max(ancho_max, f.width)
    esc = min(ALTO / alto_max, (CELL - 6) / ancho_max)

    orden = vaiven(nfilas) if ida_y_vuelta else list(range(nfilas))
    hoja = Image.new("RGBA", (len(orden) * CELL, 8 * CELL), (0, 0, 0, 0))
    faltan = espejadas = 0
    for destino_fila, d in enumerate(ANIMADOR):
        # CINCO DIBUJOS, OCHO DIRECCIONES. Si la hoja solo trae S SE E NE
        # N, las otras tres salen espejando su pareja. No es solo ahorrar
        # trabajo: GARANTIZA que la pareja sea coherente, que es justo
        # donde falla la generacion. Lo que se paga es que los detalles
        # asimetricos —la bolsa, la trenza— cambian de lado; a 78 px se
        # nota poco y es lo que hacen casi todos los juegos clasicos.
        espejo = d not in ENTRADA[:ncols]
        origen_d = ESPEJO[d] if espejo else d
        ci = ENTRADA.index(origen_d)
        if ci >= len(cols):
            faltan += nfilas
            continue
        x0, x1 = cols[ci]
        espejadas += 1 if espejo else 0
        for f, cual in enumerate(orden):
            y0, y1 = filas[cual]
            fig = celda(a, occ, y0, y1, x0, x1)
            if fig is None:
                faltan += 1
                continue
            if espejo:
                fig = fig.transpose(Image.FLIP_LEFT_RIGHT)
            hoja.alpha_composite(encajar(fig, esc), (f * CELL, destino_fila * CELL))

    ruta = os.path.join(destino, f"rita_{clip}.png")
    hoja.save(ruta)
    print(f"  rita_{clip}.png   {hoja.width}x{hoja.height}"
          f"   {len(orden)} col x 8 filas"
          + (f"   {espejadas} filas espejadas" if espejadas else "")
          + (f"   ({faltan} celdas vacias)" if faltan else ""))
    print(f"  celda {CELL} · figura {ALTO} · pies y={PIES}"
          f" · foot_offset = {CELL // 2 - (CELL - PIES)}")
    return hoja


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2],
         sys.argv[3] if len(sys.argv) > 3 else "walk",
         int(sys.argv[4]) if len(sys.argv) > 4 else 8,
         int(sys.argv[5]) if len(sys.argv) > 5 else 7,
         len(sys.argv) > 6 and sys.argv[6] == "vaiven")
