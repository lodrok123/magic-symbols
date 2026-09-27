"""Poda la biblioteca de gestos: quita muestras dispersas y nombres muertos.

MAS MUESTRAS NO ES MEJOR, y esto es lo que costo aprenderlo.

El $P no decide por parecido sino por CUANTO LE SACA EL PRIMERO AL
SEGUNDO. Un gesto con muchas muestras y poco consistentes se convierte
por eso en el rival de todos los demas: siempre hay alguna suya cerca de
lo que dibujes, asi que el margen de todo el mundo se hunde.

Paso exactamente eso con 'rombo': 33 muestras, un tercio de la
biblioteca, y era el vecino mas cercano de pilar (14 veces), de barrera
(9) y de levitacion (3). En partida barrera acertaba 2 de 10 y rombo 1
de 7. Con las 12 muestras mas coherentes, medido en validacion cruzada:

    sello         antes   despues
    pilar          324%      485%
    barrera        106%      193%
    rombo          275%      384%
    (los demas, igual: nadie empeora)

Que hace:
  1. Se queda con las TOPE muestras mas coherentes de cada gesto: las
     que menos se alejan de sus propias hermanas. No es quitar las
     "malas" a ojo, es quitar las que discrepan del resto.
  2. Borra los nombres que ya no usa nadie (circulo, triangulo,
     semicirculo, levitar: nombres viejos de antes del renombrado). No
     estorbaban al reconocer —templates_for() solo mira las familias
     buenas— pero eran la mitad del peso del archivo.

Uso:  python podar_gestos.py <gesture_library.tres> [tope]
El original se guarda al lado con extension .bak.
"""
import re
import shutil
import statistics
import sys
from math import hypot, sqrt

# Las dos familias vivas. Lo que no este aqui, fuera.
ELEMENTS = ["fuego", "agua", "tierra", "rayo", "hielo", "tiempo", "viento"]
SIGILS = ["flecha", "pilar", "barrera", "levitacion", "repeticion", "rombo"]

TOPE_POR_DEFECTO = 12


# --- El $P, lo justo para medir distancias entre nubes ---

def _greedy(a, b, start):
    n = len(a)
    usados = [False] * n
    total = peso_total = 0.0
    idx = start
    for paso in range(n):
        mejor, mejor_j = 1e18, -1
        ax, ay = a[idx]
        for j in range(n):
            if usados[j]:
                continue
            d = hypot(ax - b[j][0], ay - b[j][1])
            if d < mejor:
                mejor, mejor_j = d, j
        if mejor_j < 0:
            break
        usados[mejor_j] = True
        # Los primeros emparejamientos pesan mas: se hacen con toda la
        # nube libre, asi que son los de fiar.
        peso = (n - paso) / n
        total += peso * mejor
        peso_total += peso
        idx = (idx + 1) % n
    return total / peso_total if peso_total else 1e18


def distancia(a, b):
    paso = max(1, round(sqrt(len(a))))
    return min(min(_greedy(a, b, i), _greedy(b, a, i))
               for i in range(0, len(a), paso))


# --- Leer y escribir el .tres ---

def leer(ruta):
    texto = open(ruta, encoding="utf8").read()
    biblioteca = {}
    for m in re.finditer(r'"([a-zA-Z_]+)":\s*\[', texto):
        nombre = m.group(1)
        i, prof, j = m.end(), 1, m.end()
        while prof and j < len(texto):
            prof += 1 if texto[j] == "[" else -1 if texto[j] == "]" else 0
            j += 1
        nubes = []
        for pv in re.finditer(r"PackedVector2Array\(([^)]*)\)", texto[i:j]):
            v = [float(x) for x in pv.group(1).split(",") if x.strip()]
            nubes.append([(v[k], v[k + 1]) for k in range(0, len(v), 2)])
        biblioteca[nombre] = nubes
    return texto, biblioteca


def escribir(ruta, texto, biblioteca):
    partes = []
    for nombre, nubes in biblioteca.items():
        cuerpo = ", ".join(
            "PackedVector2Array(" +
            ", ".join(f"{c:.8g}" for p in nube for c in p) + ")"
            for nube in nubes)
        partes.append(f'"{nombre}": [{cuerpo}]')
    bloque = "templates = {\n" + ",\n".join(partes) + "\n}\n"

    inicio = texto.index("templates = {")
    # El cierre del diccionario es la primera llave a principio de linea
    fin = texto.index("\n}\n", inicio) + 3
    open(ruta, "w", encoding="utf8").write(texto[:inicio] + bloque + texto[fin:])


# --- La poda ---

def coherencia(nubes):
    """Distancia media de cada muestra a sus hermanas. Mas bajo, mas tipica."""
    return [statistics.mean([distancia(a, b) for j, b in enumerate(nubes)
                             if j != i and len(b) == len(a)] or [0.0])
            for i, a in enumerate(nubes)]


def main(ruta, tope):
    shutil.copy(ruta, ruta + ".bak")
    texto, biblioteca = leer(ruta)

    vivos = {}
    for nombre in ELEMENTS + SIGILS:
        nubes = biblioteca.get(nombre, [])
        if not nubes:
            continue
        if len(nubes) > tope:
            orden = sorted(range(len(nubes)), key=lambda i: coherencia(nubes)[i])
            elegidas = [nubes[i] for i in orden[:tope]]
            print(f"  {nombre:12} {len(nubes):3d} -> {tope:3d}")
        else:
            elegidas = nubes
            print(f"  {nombre:12} {len(nubes):3d}    (se queda igual)")
        vivos[nombre] = elegidas

    muertos = [n for n in biblioteca if n not in vivos]
    if muertos:
        print("  nombres muertos borrados: " + ", ".join(muertos))

    escribir(ruta, texto, vivos)
    print(f"\nHecho. El original esta en {ruta}.bak")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1],
         int(sys.argv[2]) if len(sys.argv) > 2 else TOPE_POR_DEFECTO)
