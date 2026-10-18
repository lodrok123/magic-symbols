#!/usr/bin/env python3
"""Bosque 01 AMPLIADO (Juego, 16/10): mapas/Bosque_01.txt + Nivel_Bosque_01.tscn horneado, a partir del mapa que ya existe.

Por qué existe: la hoja `Nivel_Bosque_01.xlsx` dio el primer Bosque 01 (28 × 28; tools/hoja_a_nivel.py). Pablo pidió ampliarlo con ramas
secundarias, puzles del laboratorio de fuego, más encuentros y más decorado, y que el verde oscuro de la hoja NO sean árboles-pared
sino relleno donde se generan assets y hierba. Este script parte del `.txt` del nivel vigente (el 28 × 28 queda EXACTAMENTE en las mismas
casillas: las reglas, las pruebas y las notas de Pablo siguen valiendo), le añade las zonas nuevas y vuelve a hornear el .tscn.

Uso (desde la raíz del repo):
    python tools/ampliar_bosque_01.py [--base mundo/datos_nivel/mapas/Bosque_01.txt] [--salida mundo/datos_nivel]
Si el .tscn o el .txt de salida ya existen NO los pisa: los aparta como *_copia_<fecha> (el .tscn lleva las ediciones de Pablo).
Necesita las piezas de `arte/piezas/*.tscn` y la plantilla `Nivel_Bosque.tscn` (para los uid). Repetible: misma semilla, mismo resultado.

TODO lo que hay que saber del diseño está en las tablas de abajo (CARVADO, MARCADORES, PUZLES). Si algo no te gusta, se cambia ahí.
"""
import math
import os
import random
import re
import sys
import time
from collections import deque

S = 2.3            # lado de casilla (HorneadorNivel.S)
ALTO = 1.035       # alto de casilla (HorneadorNivel.ALTO)
Y_PIEZA = 1.005
SEMILLA = 10
LADO = 52          # cuadrado de trabajo (lo pintado ocupa 52 × 44)

# ---------------------------------------------------------------------------------------------------------------------
# LO QUE YA EXISTÍA (no se toca salvo F17 y los pasos nuevos)
# ---------------------------------------------------------------------------------------------------------------------
# Marcadores de datos del primer Bosque 01 (hoja_a_nivel.DATOS_MARCAS, ya en coordenadas del mapa): (x, y, grupo, giro)
DATOS_ANTIGUOS = [(7, 5, "tronco_puente", 180), (16, 14, "tronco_estanque", 0), (9, 14, "loberno", 0), (9, 18, "loberno", 0)]
GIRO_PUERTA = {(21, 15): 90}
TIENDAS = [(10, 1), (10, 2)]             # campamento goblin (decorado)
F17 = (2, 12)                            # antes brasero T, ahora telaraña (Pablo, 16/10: «al principio usa telaraña, no antorcha»)

# ---------------------------------------------------------------------------------------------------------------------
# LO NUEVO. Coordenadas del mapa (columna, fila); el 28 × 28 viejo ocupa (0..27, 0..27).
# ---------------------------------------------------------------------------------------------------------------------
# Rectángulos de suelo que se abren (x0, y0, x1, y1, letra). `.` = suelo base (el azar lo reparte en hierba/tierra), `g` tierra, `v` hierba alta.
CARVADO = [
    # Paso del campamento al claro del NE (rama 1) y el propio claro
    (11, 3, 12, 3, "."), (13, 1, 26, 5, "."),
    # Salida del claro hacia el este y bajada por el sendero oriental (2 de ancho)
    (27, 3, 31, 4, "."), (30, 5, 31, 28, "."),
    # El sendero se ensancha en el claro de los lobernos
    (28, 13, 33, 21, "."),
    # Bajada del prado al sur (rama 2) y la explanada
    (10, 21, 11, 28, "."), (4, 29, 46, 31, "."),
    # Cámara A (cuatro antorchas): entrada, sala, puerta, trastienda del cofre
    (8, 32, 9, 32, "."), (4, 33, 12, 38, "."), (8, 39, 8, 39, "."), (7, 40, 9, 41, "."),
    # Cámara B (contrafuego): entrada, sala, puerta, trastienda
    (15, 32, 16, 32, "."), (14, 33, 28, 38, "."), (27, 39, 27, 39, "."), (26, 40, 28, 41, "."),
    # Cámara C (relé de braseros): entrada, sala, puerta, trastienda
    (35, 32, 36, 32, "."), (31, 33, 39, 38, "."), (35, 39, 35, 39, "."), (34, 40, 36, 41, "."),
    # Cámara D (cuerda): entrada, sala (el arroyo la parte en dos por la columna 47), puerta, trastienda
    (43, 32, 44, 32, "."), (42, 33, 50, 39, "."), (44, 40, 44, 40, "."), (43, 41, 45, 42, "."),
]
# Hierba alta nueva (arde: es opcional y está lejos de los puzles)
HIERBA_ALTA = [(29, 16, 32, 18)]

# Marcadores por casilla: (x, y) -> (letra, nombre). Los viejos conservan su casilla y ganan nombre `tipo_NN`.
# Los nombres de los que usan las reglas (escenas/bosque_01_3d.gd) son el CONTRATO: `antorcha_01..04` = la secuencia en orden,
# `brasero_01/02` = el par del tótem 2, `totem_fuego_01/02/03` = propagación / antorchas / secuencia, `guerrero_01/02` = los del cofre 1.
NOMBRES_VIEJOS = {
    (2, 21): "inicio_01",
    (2, 5): "guerrero_01", (3, 5): "guerrero_02",
    (9, 3): "telarana_01", (F17[0], F17[1]): "telarana_02",
    (10, 4): "cofre_01", (26, 15): "cofre_02",
    (25, 15): "elemental_01", (21, 15): "puerta_01", (13, 19): "alquimista_01",
    (10, 14): "seta_01", (10, 18): "seta_02", (6, 21): "raiz_01",
    (18, 25): "totem_fuego_01", (19, 8): "totem_fuego_02", (17, 19): "totem_fuego_03",
    (18, 9): "brasero_01", (19, 9): "brasero_02",
    (19, 13): "antorcha_01", (17, 16): "antorcha_02", (17, 11): "antorcha_03", (19, 17): "antorcha_04",
}
# (x, y, letra, nombre)
MARCADORES_NUEVOS = [
    # Rama 1 · claro del NE: una patrulla goblin (guerrero + dos arqueros) guarda el cofre 3
    (19, 3, "W", "guerrero_03"), (23, 2, "A", "arquero_01"), (23, 4, "A", "arquero_02"), (25, 1, "Z", "cofre_03"),
    # Sendero oriental: dos telarañas que cortan el paso (se queman con la flecha de fuego)
    (30, 8, "r", "telarana_03"), (31, 8, "r", "telarana_04"),
    # Rama 2 · explanada del sur: un guerrero que patrulla
    (22, 30, "W", "guerrero_04"),
    # Cámara A (F1, cuatro antorchas): cuatro braseros y el cofre 4 tras la puerta
    (5, 34, "T", "brasero_03"), (11, 34, "T", "brasero_04"), (5, 37, "T", "brasero_05"), (11, 37, "T", "brasero_06"), (8, 41, "Z", "cofre_04"),
    # Cámara B (F4, contrafuego): cuatro setos secos en fila; el barril y la puerta los pone el .txt; el cofre 5 tras la puerta
    (19, 36, "z", "seto_01"), (20, 36, "z", "seto_02"), (21, 36, "z", "seto_03"), (22, 36, "z", "seto_04"), (27, 41, "Z", "cofre_05"),
    # Cámara C (F2, relé de braseros): cuatro braseros en fila; el cofre 6 tras la puerta
    (32, 35, "T", "brasero_07"), (34, 35, "T", "brasero_08"), (36, 35, "T", "brasero_09"), (38, 35, "T", "brasero_10"), (35, 41, "Z", "cofre_06"),
    # Cámara D (F3, quema la cuerda): el arroyo (siete casillas de canal, giradas 90°) y el cofre 7 tras la puerta
    (47, 33, "-", "canal_01"), (47, 34, "-", "canal_02"), (47, 35, "-", "canal_03"), (47, 36, "-", "canal_04"), (47, 37, "-", "canal_05"),
    (47, 38, "-", "canal_06"), (47, 39, "-", "canal_07"), (44, 42, "Z", "cofre_07"),
]
GIRO_CANAL = 90      # el canal recto corre a lo largo de X con giro 0; con 90 corre a lo largo de Z (de norte a sur)
# Marcadores de DATOS nuevos (grupo, sin letra): lobernos del claro oriental
DATOS_NUEVOS = [(30, 15, "loberno", 0), (31, 19, "loberno", 0)]

# Puzles del laboratorio de fuego que solo piden flecha de fuego (laboratorios/… PuzlesFuego.txt, diario 100): F1, F4 y F2. Se escriben como
# líneas `; pieza` / `; puzle` del .txt (las lee escenas/puzle.gd). Las puertas NO se vuelven a cerrar (no hay regla `cierra`): así nadie
# queda encerrado en una trastienda ni la pierde por una llama que se apague.
PUZLES = """\
; --- CÁMARA A · F1 «cuatro antorchas»: los cuatro braseros (T) se encienden con la flecha de fuego; con 4/4 se abre la puerta de la trastienda (cofre_04).
; pieza a_b1 brasero 5 34
; pieza a_b2 brasero 11 34
; pieza a_b3 brasero 5 37
; pieza a_b4 brasero 11 37
; pieza a_cont contador 8 35 de=5,34+11,34+5,37+11,37
; pieza a_puerta puerta 8 39
; puzle a_abre cuando=a_cont.todos hace=a_puerta.abrir
; --- CÁMARA B · F4 «contrafuego»: cuatro setos secos (z) en fila y un barril al final. Una flecha de fuego al primer seto y el fuego corre por la fila,
; ---   enciende el barril y su explosión abre la puerta de la trastienda (cofre_05). El jugador dispara desde la entrada, a más de 8 u del barril.
; pieza b_barril barril 23 36
; pieza b_puerta puerta 27 39
; puzle b_abre cuando=b_barril.explota hace=b_puerta.abrir
; --- CÁMARA C · F2 «relé de braseros»: encender el primero (A) enciende el siguiente 1,5 s después, y cada uno se apaga a los 6 s. La puerta de la trastienda
; ---   (cofre_06) se abre cuando A y D arden A LA VEZ (de +4,5 s a +6 s de lanzar la flecha a A) y se queda abierta.
; pieza c_a brasero 32 35 rele=c_b
; pieza c_b brasero 34 35 rele=c_c
; pieza c_c brasero 36 35 rele=c_d
; pieza c_d brasero 38 35 dura=6
; pieza c_cont contador 35 36 de=32,35+38,35
; pieza c_puerta puerta 35 39
; puzle c_abre cuando=c_cont.todos hace=c_puerta.abrir
; --- CÁMARA D · F3 «quema la cuerda»: un arroyo de canal (47,33..39) parte la sala; una compuerta LEVANTADA (abierta) lo deja correr y la cuerda de al lado la
; ---   sostiene. Una flecha de fuego a la cuerda (arde 1 s y se rompe) hace caer la compuerta: se corta el agua y el vado (47,36) baja de 0,25 -> se abre la
; ---   puerta de la trastienda (cofre_07). El arroyo está en la mitad este: el jugador no lo cruza, dispara por encima.
; pieza d_arroyo manantial 47 33 celdas=47,33..47,39 caudal=1.5 volumen=0
; pieza d_desague cuenca 47 39 fijo=0.02
; pieza d_compuerta compuerta 47 34 abierta=si vertical=no estrecha=no
; pieza d_cuerda cuerda 46 34 sostiene=d_compuerta
; pieza d_nivel nivel 47 36 objetivo=0.25 invertido=si
; pieza d_puerta puerta 44 40
; puzle d_abre cuando=d_nivel.alcanzado hace=d_puerta.abrir
; puzle d_cierra cuando=d_nivel.perdido hace=d_puerta.cerrar
; --- (d_cierra existe solo por el arranque: el manantial tarda ~18 s en llegar y hasta entonces el vado está a 0 («bajo») y la puerta abierta. Tras romper la cuerda el agua no vuelve nunca: la puerta ya no se cierra)
"""

# ---------------------------------------------------------------------------------------------------------------------
# Tipos de marcador (copia mínima de marcador_3d.gd): letra -> (grupo, tipo)
# ---------------------------------------------------------------------------------------------------------------------
LETRAS = {
    "S": ("inicio_jugador", ""), "W": ("goblin", "guerrero"), "A": ("goblin", "arquero"), "G": ("goblin", "elemental"), "X": ("puerta", ""),
    "Q": ("npc", "alquimista"), "j": ("reactivo", "totem_fuego"), "T": ("reactivo", "brasero"), "s": ("reactivo", "seta"),
    "q": ("reactivo", "raiz"), "r": ("reactivo", "telarana"), "z": ("reactivo", "seto"), "Z": ("cofre", "cofre"), "-": ("canal", "recto"),
}
LETRA_ITEM = {".": 0, "~": 1, "b": 2, "g": 3, "v": 4, ",": 5, "c": 6, "R": 7, "#": 5}
MARCAS_SIN_TIPO = ("Q", "Z", "W", "G")

# Piezas de decorado. (id, bloquea). Las que bloquean solo van donde hay sitio de sobra (3 × 3 libres); las demás, en cualquier sitio.
SOLIDAS = {"roca_musgosa", "roca_grande", "tronco_musgoso", "troncos_apilados", "arbusto", "arbusto_otono", "tocon", "campamento_rocas",
           "campamento_cazo", "cartel", "valla"}
PIEZAS_USADAS = ["arbol_redondo", "arbol_redondo_2", "pino", "pino_2", "arbusto", "arbusto_otono", "arbusto_flores", "tocon", "piedras", "setas",
                 "roca_musgosa", "roca_grande", "rocas_pequenas", "tronco_musgoso", "troncos_apilados", "hojas_caidas", "helecho", "matas",
                 "juncos", "canas", "flores_blancas", "paja", "campamento_cazo", "campamento_rocas", "campamento_tienda", "tienda_goblin", "cartel"]

# Qué decorado va en cada zona (id, peso). Es el «criterio»: lo que tiene sentido ahí, no un reparto uniforme.
ZONAS = {
    "agua":     [("juncos", 5), ("canas", 4), ("rocas_pequenas", 2), ("piedras", 2)],
    "campamento": [("campamento_cazo", 2), ("campamento_rocas", 2), ("troncos_apilados", 2), ("paja", 3), ("tocon", 2), ("matas", 1)],
    "camino":   [("arbusto_flores", 3), ("flores_blancas", 3), ("piedras", 3), ("matas", 3), ("hojas_caidas", 2), ("setas", 1)],
    "claro":    [("roca_musgosa", 2), ("tronco_musgoso", 2), ("hojas_caidas", 3), ("flores_blancas", 3), ("helecho", 3), ("tocon", 2),
                 ("arbusto_flores", 2), ("rocas_pequenas", 2), ("setas", 2), ("arbusto_otono", 1)],
    "explanada": [("piedras", 3), ("matas", 3), ("rocas_pequenas", 3), ("hojas_caidas", 2), ("arbusto_flores", 2), ("troncos_apilados", 1)],
    "camara":   [("piedras", 3), ("rocas_pequenas", 3), ("hojas_caidas", 2), ("matas", 1)],
    "prado":    [("flores_blancas", 4), ("arbusto_flores", 3), ("matas", 3), ("piedras", 2), ("roca_musgosa", 1), ("hojas_caidas", 2), ("setas", 2)],
    "monte":    [("helecho", 3), ("hojas_caidas", 3), ("roca_musgosa", 2), ("tronco_musgoso", 2), ("tocon", 2), ("arbusto_otono", 2), ("setas", 2)],
}
# Relleno del verde oscuro (lo que se genera donde la hoja pintó verde oscuro): árboles, pero también matorral, rocas y troncos.
RELLENO = [("arbol_redondo", 24), ("arbol_redondo_2", 10), ("pino", 16), ("pino_2", 8), ("arbusto_otono", 7), ("arbusto", 6),
           ("roca_musgosa", 6), ("roca_grande", 3), ("tronco_musgoso", 4), ("helecho", 5), ("matas", 4), ("troncos_apilados", 2), ("tocon", 3)]


# Huella física (semiancho en X y en Z, en unidades de mundo, a escala 1) del `cuerpo` de cada pieza que bloquea. MEDIDA en Godot con las CollisionShape3D
# de arte/piezas/*.tscn. Importa porque Terreno3D bloquea por colisión real (FuenteNodos): una roca grande en una casilla «#» pegada al camino se
# desborda a la casilla vecina y la cierra (así se cortó un pasillo de 1 de ancho en la primera versión). Casilla = S = 2,3.
HUELLA = {"arbol_redondo": (0.448, 0.427), "arbol_redondo_2": (0.448, 0.427), "pino": (0.424, 0.447), "pino_2": (0.424, 0.447),
          "arbusto": (0.604, 0.563), "arbusto_otono": (0.911, 0.934), "arbusto_flores": (0.632, 0.651), "roca_musgosa": (0.385, 0.43),
          "roca_grande": (1.139, 1.236), "tronco_musgoso": (0.42, 0.423), "troncos_apilados": (0.373, 0.32), "tocon": (0.743, 0.684),
          "campamento_cazo": (0.745, 0.683), "campamento_rocas": (0.773, 0.881), "cartel": (0.36, 0.298)}
MARGEN = 0.15        # holgura sumada a la huella: el jugador tiene radio y el cuerpo no es exactamente una caja


def celdas_huella(pid, px, pz, esc):
    """Casillas que toca el cuerpo de `pid` puesto en (px, pz) del mundo a escala `esc` (rectángulo alineado: cota alta, a favor de la seguridad)."""
    hx, hz = HUELLA[pid]
    x0, x1 = px - hx * esc - MARGEN, px + hx * esc + MARGEN
    z0, z1 = pz - hz * esc - MARGEN, pz + hz * esc + MARGEN
    return {(cx, cz) for cx in range(int(math.floor(x0 / S)), int(math.floor(x1 / S)) + 1) for cz in range(int(math.floor(z0 / S)), int(math.floor(z1 / S)) + 1)}


def vecinos4(x, y):
    return ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))


def elegir(rng, tabla):
    total = sum(p for _, p in tabla)
    r = rng.uniform(0, total)
    for pid, p in tabla:
        r -= p
        if r <= 0:
            return pid
    return tabla[-1][0]


# ---------------------------------------------------------------------------------------------------------------------
# LECTURA DEL MAPA VIGENTE
# ---------------------------------------------------------------------------------------------------------------------
def leer_base(ruta):
    cab, filas = [], []
    for l in open(ruta, encoding="utf-8").read().split("\n"):
        if l.startswith(";"):
            cab.append(l)
        elif l.strip() != "" or filas:
            filas.append(l)
    while filas and filas[-1].strip() == "":
        filas.pop()
    return cab, filas


def construir(filas):
    """Devuelve suelo {(x,y): letra de suelo}, marcas {(x,y): letra}, tiendas."""
    suelo, marcas = {}, {}
    for y, fila in enumerate(filas):
        for x, ch in enumerate(fila):
            if ch == " ":
                continue
            if ch in "#.,gv~c":
                suelo[(x, y)] = ch
            elif ch == "t":
                suelo[(x, y)] = "?"
            else:
                marcas[(x, y)] = ch
                suelo[(x, y)] = "?"
    # El suelo bajo un marcador es el que dominan sus vecinas (igual que hoja_a_nivel.py).
    for xy in [k for k, v in suelo.items() if v == "?"]:
        votos = {}
        for q in vecinos4(*xy):
            v = suelo.get(q)
            if v in (".", "g", "v"):
                votos[v] = votos.get(v, 0) + 1
        suelo[xy] = max(votos, key=votos.get) if votos else "."
    return suelo, marcas


def aplicar_nuevo(suelo, marcas):
    # F17: de brasero a telaraña
    marcas[F17] = "r"
    for x0, y0, x1, y1, ch in CARVADO:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                suelo[(x, y)] = ch
    for x0, y0, x1, y1 in HIERBA_ALTA:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                suelo[(x, y)] = "v"
    for x, y, letra, _ in MARCADORES_NUEVOS:
        marcas[(x, y)] = letra
        if suelo.get((x, y)) in (None, "#"):
            raise SystemExit("marcador fuera del suelo: %s en %s" % (letra, (x, y)))


def rodear_de_relleno(suelo):
    """Vacío pegado (8 vecinas) a suelo jugable -> `#` (relleno de decorado). Es el borde natural del nivel."""
    nuevos = {}
    for y in range(-1, LADO + 1):
        for x in range(-1, LADO + 1):
            if (x, y) in suelo:
                continue
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    v = suelo.get((x + dx, y + dy))
                    if v is not None and v != "#":
                        nuevos[(x, y)] = "#"
    nuevos = {k: v for k, v in nuevos.items() if k[0] >= 0 and k[1] >= 0}      # nada en negativo: el origen del nivel tiene que seguir en (0, 0)
    suelo.update(nuevos)


def pasable(suelo, xy, extra_ok=()):
    v = suelo.get(xy)
    return v is not None and v not in ("#", "~") and (v != "c" or True)


def alcanzables(suelo, ini, abrir=()):
    """BFS sobre casillas andables. `abrir`: casillas que cuentan como paso aunque sean agua (el puente caído)."""
    visto = {ini}
    cola = deque([ini])
    while cola:
        c = cola.popleft()
        for q in vecinos4(*c):
            if q in visto:
                continue
            v = suelo.get(q)
            if v is None or v == "#" or (v == "~" and q not in abrir):
                continue
            visto.add(q)
            cola.append(q)
    return visto


# ---------------------------------------------------------------------------------------------------------------------
# SUELO
# ---------------------------------------------------------------------------------------------------------------------
def azar_suelo(suelo, marcas, rng):
    """Reparte el `.` en hierba corta `,`, tierra `g` y suelo base `.` con manchas (ruido de valor), como HorneadorNivel._azar_suelo."""
    rej = {}
    paso = 4

    def nodo(i, j):
        if (i, j) not in rej:
            rej[(i, j)] = rng.random()
        return rej[(i, j)]

    def ruido(x, y):
        fx, fy = x / paso, y / paso
        i, j = int(math.floor(fx)), int(math.floor(fy))
        tx, ty = fx - i, fy - j
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = nodo(i, j) * (1 - tx) + nodo(i + 1, j) * tx
        b = nodo(i, j + 1) * (1 - tx) + nodo(i + 1, j + 1) * tx
        return a * (1 - ty) + b * ty

    res = dict(suelo)
    for (x, y), ch in suelo.items():
        if ch == ".":
            n = ruido(x, y)
            res[(x, y)] = "g" if n > 0.76 else "," if n > 0.45 else "."
    return res


def senderos(suelo, caminos):
    """Pinta de tierra `g` la ruta más corta entre cada par de puntos (los caminos que se ven en el suelo). Solo cambia `.` y `,`."""
    for a, b in caminos:
        prev = {a: None}
        cola = deque([a])
        while cola:
            c = cola.popleft()
            if c == b:
                break
            for q in vecinos4(*c):
                v = suelo.get(q)
                if q not in prev and v is not None and v not in ("#", "~", "c"):
                    prev[q] = c
                    cola.append(q)
        c = b
        while c is not None and c in prev:
            if suelo.get(c) in (".", ","):
                suelo[c] = "g"
            c = prev[c]


# ---------------------------------------------------------------------------------------------------------------------
# DECORADO
# ---------------------------------------------------------------------------------------------------------------------
def zona_de(x, y, suelo):
    for dx in range(-2, 3):
        for dy in range(-2, 3):
            if suelo.get((x + dx, y + dy)) in ("~", "c"):
                return "agua"
    if 7 <= x <= 11 and 0 <= y <= 9:
        return "campamento"
    if 13 <= x <= 26 and 1 <= y <= 5:
        return "claro"
    if x >= 28 and y <= 28:
        return "claro" if 13 <= y <= 21 else "camino"
    if y >= 32:
        return "camara"
    if y >= 29:
        return "explanada"
    if 9 <= x <= 15 and 11 <= y <= 20:
        return "prado"
    if suelo.get((x, y)) == "g":
        return "camino"
    return "monte"


def decorado(suelo, marcas, puzles_celdas, rng):
    """Piezas sueltas cada ~5 casillas (con varianza, tipo Poisson) y el relleno del verde oscuro. Devuelve (piezas, relleno)."""
    prohibidas = set(marcas) | set(puzles_celdas) | set(TIENDAS)
    for (x, y) in list(prohibidas):
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                prohibidas.add((x + dx, y + dy))
    # Casillas de «paso» que nunca se tocan: las de 1 de ancho (cuellos) y sus vecinas, para no estrechar ni cerrar nada.
    def libre(xy):
        v = suelo.get(xy)
        return v is not None and v not in ("#", "~", "c")
    cuello = set()
    for (x, y), v in suelo.items():
        if v in ("#",) or not libre((x, y)):
            continue
        h = libre((x - 1, y)) and libre((x + 1, y))
        w = libre((x, y - 1)) and libre((x, y + 1))
        if not (h and w):
            cuello.add((x, y))
    amplio = set()
    for (x, y) in suelo:
        if libre((x, y)) and all(libre((x + dx, y + dy)) for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
            amplio.add((x, y))
    # Poisson: cada candidato lleva su propia distancia mínima (3,4 a 5,4 casillas)
    cand = [xy for xy in suelo if libre(xy) and suelo[xy] != "v" and xy not in prohibidas and xy not in cuello]
    rng.shuffle(cand)
    puestas = []
    piezas = []
    for xy in cand:
        r = rng.uniform(3.4, 5.4)
        if any((xy[0] - q[0]) ** 2 + (xy[1] - q[1]) ** 2 < r * r for q in puestas):
            continue
        z = zona_de(xy[0], xy[1], suelo)
        tabla = [(p, w) for p, w in ZONAS[z] if (p not in SOLIDAS or xy in amplio)]
        pid = elegir(rng, tabla)
        puestas.append(xy)
        piezas.append((pid, xy, pid not in SOLIDAS))
    # Señales a la entrada de las cámaras y al pie de la bajada (decorado con intención; no estorban: la explanada tiene 3 de alto)
    for xy in [(7, 31), (13, 31), (34, 31), (42, 31), (12, 30)]:
        if libre(xy) and xy not in prohibidas:
            piezas.append(("cartel", xy, False))
    # Relleno del verde oscuro
    relleno = []
    for xy, v in suelo.items():
        if v == "#":
            relleno.append((elegir(rng, RELLENO), xy))
    return piezas, relleno


# ---------------------------------------------------------------------------------------------------------------------
# SALIDAS
# ---------------------------------------------------------------------------------------------------------------------
def apartar(ruta):
    if os.path.exists(ruta):
        base, ext = os.path.splitext(ruta)
        copia = "%s_copia_%s%s" % (base, time.strftime("%Y%m%d_%H%M%S"), ext)
        os.rename(ruta, copia)
        print("aviso: ya existía %s; apartado como %s" % (ruta, copia))


def vista(suelo, marcas):
    ancho = max(x for x, _ in suelo) + 1
    alto = max(y for _, y in suelo) + 1
    filas = []
    for y in range(alto):
        f = ""
        for x in range(ancho):
            if (x, y) in marcas:
                f += marcas[(x, y)]
            elif (x, y) in TIENDAS:
                f += "t"
            else:
                f += suelo.get((x, y), " ")
        filas.append(f)
    return filas


def escribir_txt(ruta, cab_vieja, suelo, marcas, puzles_txt):
    filas = vista(suelo, marcas)
    # El mapa de letras no distingue hierba corta de suelo (lo hace el azar de suelo del tscn): se vuelve a `.`
    filas = [f.replace(",", ".") for f in filas]
    cab = [
        "; Bosque_01 AMPLIADO (Fase 16, 16/10): %d × %d casillas pintadas. El 28 × 28 de antes está en las mismas casillas; las ramas nuevas salen de tools/ampliar_bosque_01.py." % (len(filas[0]), len(filas)),
        "; Letras: marcador_3d.gd y hornear_nivel.gd. `t` tienda goblin (decorado). `#` ya NO es «pared de árboles»: es relleno de decorado (árboles, matorral, rocas) que no se pisa.",
        "; El TRONCO-PUENTE (cae sobre la casilla (6, 5)) y el TRONCO DEL ESTANQUE son marcadores de datos del Nivel_Bosque_01.tscn horneado; los lobernos también.",
        "; Reglas: escenas/bosque_01_3d.gd (nodo «Reglas» de escenas/PruebaBosque01.tscn): lee los marcadores POR NOMBRE (cofre_01, antorcha_03…). Los puzles: las líneas `pieza` y `puzle` de abajo.",
        "; azar_suelo 1 %d %d" % (LADO - 2, SEMILLA),
        "; giro 21 15 90",
    ]
    # Se conservan tal cual las líneas del estanque (la losa y el manantial)
    for l in cab_vieja:
        if l.startswith("; --- ESTANQUE") or l.startswith("; --- El manantial") or l.startswith("; pieza losa_estanque") \
                or l.startswith("; pieza estanque ") or l.startswith("; puzle losa_sube_agua"):
            cab.append(l)
    cab += puzles_txt.rstrip("\n").split("\n")
    apartar(ruta)
    open(ruta, "w", encoding="utf-8", newline="\n").write("\n".join(cab + filas) + "\n")
    return filas


def uid_de(ruta_pieza):
    try:
        t = open(ruta_pieza, encoding="utf-8").readline()
        m = re.search(r'uid="([^"]+)"', t)
        return m.group(1) if m else ""
    except OSError:
        return ""


def transform(yaw, esc, x, y, z):
    c, s = math.cos(yaw) * esc, math.sin(yaw) * esc
    f = lambda v: ("%.7g" % v)
    return "Transform3D(%s, 0, %s, 0, %s, 0, %s, 0, %s, %s, %s, %s)" % (f(c), f(s), f(esc), f(-s), f(c), f(x), f(y), f(z))


def recurso_plantilla(plantilla, ruta_res):
    for l in open(plantilla, encoding="utf-8"):
        m = re.match(r'\[ext_resource type="(\w+)" uid="([^"]+)" path="([^"]+)" id="([^"]+)"\]', l)
        if m and m.group(3) == ruta_res:
            return m.group(2)
    return ""


def escribir_tscn(ruta, suelo, marcas, nombres, datos, piezas, relleno, plantilla, carpeta_piezas, rng):
    P = "res://arte/piezas/"
    cab = ["[gd_scene format=3]", ""]
    ids = {}
    n = 1
    lib_path = "res://mundo/datos_nivel/suelo_tipos.tres"
    cab.append('[ext_resource type="MeshLibrary" uid="%s" path="%s" id="1_lib"]' % (recurso_plantilla(plantilla, lib_path), lib_path))
    usadas = sorted(set(PIEZAS_USADAS) | {p for p, _, _ in piezas} | {p for p, _ in relleno})
    for p in usadas:
        n += 1
        ids[p] = "%d_%s" % (n, p)
        uid = uid_de(os.path.join(carpeta_piezas, p + ".tscn"))
        cab.append('[ext_resource type="PackedScene"%s path="%s%s.tscn" id="%s"]' % ((' uid="%s"' % uid) if uid else "", P, p, ids[p]))
    sc = recurso_plantilla(plantilla, "res://mundo/marcador_3d.gd")
    cab.append('[ext_resource type="Script"%s path="res://mundo/marcador_3d.gd" id="99_mk"]' % ((' uid="%s"' % sc) if sc else ""))
    cab.append("")
    lado = max(max(x for x, _ in suelo), max(y for _, y in suelo)) + 1
    out = cab + [
        '[node name="Nivel_Bosque_01" type="Node3D"]',
        "metadata/lado = %d" % lado,
        'metadata/nombre = "Bosque_01"',
        'metadata/origen = "ampliar_bosque_01"',
        'metadata/horneado = "%s"' % time.strftime("%Y-%m-%dT%H:%M:%S"),
        "",
    ]
    celdas = []
    for y in range(lado):
        for x in range(lado):
            ch = suelo.get((x, y))
            if ch is not None:
                celdas += [x, y, LETRA_ITEM[ch]]
    out += ['[node name="Suelo" type="GridMap" parent="."]', 'mesh_library = ExtResource("1_lib")',
            "cell_size = Vector3(%s, %s, %s)" % (S, ALTO, S), "cell_center_y = false", "data = {",
            '"cells": PackedInt32Array(%s)' % ", ".join(map(str, celdas)), "}", ""]
    nombres_usados = {}

    def caminable(xy):
        v = suelo.get(xy)
        return v is not None and v not in ("#", " ", "~", "c")

    amplias = {xy for xy in suelo if caminable(xy) and all(caminable((xy[0] + dx, xy[1] + dy)) for dx in (-1, 0, 1) for dy in (-1, 0, 1))}
    sustituidas = [0]

    def pieza(pid, c, sin_bloqueo, esc, padre, yaw=None):
        x, y = c
        yw = rng.uniform(0, 2 * math.pi) if yaw is None else yaw
        jx, jz = rng.uniform(-0.45, 0.45), rng.uniform(-0.45, 0.45)
        if not sin_bloqueo and pid in HUELLA:
            # Una pieza que bloquea no puede rozar ninguna casilla que se pueda pisar (en el relleno «#») ni salirse de las amplias (suelta).
            def vale(jx_, jz_, e_):
                cs = celdas_huella(pid, (x + 0.5) * S + jx_, (y + 0.5) * S + jz_, e_)
                if padre == "Borde":
                    return not any(caminable(q) for q in cs)
                return all(q in amplias or q == (x, y) for q in cs)
            if not vale(jx, jz, esc):
                for jx2, jz2, e2 in [(0.0, 0.0, esc), (0.0, 0.0, 0.92), (0.0, 0.0, 0.8)]:
                    if vale(jx2, jz2, e2):
                        jx, jz, esc = jx2, jz2, e2
                        break
                else:
                    sustituidas[0] += 1
                    pid, sin_bloqueo = ("helecho", False) if padre == "Borde" else ("matas", False)    # no bloquean: no estorban
        base = "%s_%d_%d" % (pid, x, y)
        k = nombres_usados.get(base, 0)
        nombres_usados[base] = k + 1
        nm = base if k == 0 else "%s_%d" % (base, k)
        lin = ['[node name="%s" parent="%s" instance=ExtResource("%s")]' % (nm, padre, ids[pid]),
               "transform = " + transform(yw, esc, (x + 0.5) * S + jx, Y_PIEZA, (y + 0.5) * S + jz)]
        if sin_bloqueo:
            lin.append("metadata/bloquea = false")
        lin.append("")
        return lin

    out += ['[node name="Piezas" type="Node3D" parent="."]', ""]
    for t in TIENDAS:
        out += pieza("tienda_goblin", t, False, 1.05, "Piezas")
    for pid, c, sin in piezas:
        out += pieza(pid, c, sin, rng.uniform(0.92, 1.1), "Piezas")
    out += ['[node name="Borde" type="Node3D" parent="."]', ""]
    for pid, c in relleno:
        out += pieza(pid, c, False, rng.uniform(1.0, 1.14), "Borde")
    print("piezas sólidas sustituidas por no sólidas (su huella rozaba el camino): %d" % sustituidas[0])
    out += ['[node name="Marcadores" type="Node3D" parent="."]', ""]
    f = lambda v: "%.7g" % v
    todos = [(xy, marcas[xy], None) for xy in sorted(marcas, key=lambda k: (k[1], k[0]))] + [((x, y), "", (g, gi)) for x, y, g, gi in datos]
    for (x, y), letra, dato in todos:
        g, t = LETRAS[letra] if letra else (dato[0], "")
        nm = nombres[(x, y, letra or dato[0])]
        giro = math.radians(dato[1]) if dato else math.radians(GIRO_CANAL if letra == "-" else GIRO_PUERTA.get((x, y), 0))
        c, s = math.cos(giro), math.sin(giro)
        if abs(c) < 1e-9:
            c = 0.0
        out.append('[node name="%s" type="Node3D" parent="Marcadores" groups=[%s]]' % (nm, ", ".join('"%s"' % q for q in sorted(["marcador", g]))))
        out.append("transform = Transform3D(%s, 0, %s, 0, 1, 0, %s, 0, %s, %s, %s, %s)" % (f(c), f(s), f(-s), f(c), f((x + 0.5) * S), ALTO, f((y + 0.5) * S)))
        out.append('script = ExtResource("99_mk")')
        if dato:
            out.append('grupo = "%s"' % g)
        else:
            out.append('letra = "%s"' % letra)
            if t and letra not in MARCAS_SIN_TIPO:
                out.append('tipo = "%s"' % t)
        out.append("")
    apartar(ruta)
    open(ruta, "w", encoding="utf-8", newline="\n").write("\n".join(out))


def main():
    base = "mundo/datos_nivel/mapas/Bosque_01.txt"
    salida = "mundo/datos_nivel"
    if "--base" in sys.argv:
        base = sys.argv[sys.argv.index("--base") + 1]
    if "--salida" in sys.argv:
        salida = sys.argv[sys.argv.index("--salida") + 1]
    plantilla = os.path.join(salida, "Nivel_Bosque.tscn")
    carpeta_piezas = "arte/piezas"
    cab_vieja, filas = leer_base(base)
    suelo, marcas = construir(filas)
    # Los marcadores de datos viejos no están en el .txt (van en el .tscn): se añaden aquí con su casilla de siempre.
    aplicar_nuevo(suelo, marcas)
    rodear_de_relleno(suelo)
    rng = random.Random(SEMILLA)
    # Comprobación previa: todo lo que hay en el mapa se alcanza desde el inicio (el puente caído cuenta como paso)
    ini = [xy for xy, v in marcas.items() if v == "S"][0]
    vis = alcanzables(suelo, ini, abrir=[(6, 5)])
    sin_llegar = sorted(xy for xy in marcas if xy not in vis and marcas[xy] != "G")
    print("marcadores que NO se alcanzan desde el inicio (con el puente caído):", sin_llegar)
    # Nombres de marcador: los viejos del contrato; el resto, `tipo_NN`
    nombres = {}
    cuenta = {}
    nuevos = {(x, y): n for x, y, _, n in MARCADORES_NUEVOS}
    TIPO = {"S": "inicio", "W": "guerrero", "A": "arquero", "G": "elemental", "X": "puerta", "Q": "alquimista", "j": "totem_fuego", "T": "brasero",
            "s": "seta", "q": "raiz", "r": "telarana", "z": "seto", "Z": "cofre", "-": "canal"}
    for xy in sorted(marcas, key=lambda k: (k[1], k[0])):
        nm = NOMBRES_VIEJOS.get(xy) or nuevos.get(xy)
        if nm is None:
            k = cuenta.get(TIPO[marcas[xy]], 0) + 1
            cuenta[TIPO[marcas[xy]]] = k
            nm = "%s_%02d" % (TIPO[marcas[xy]], k)
        nombres[(xy[0], xy[1], marcas[xy])] = nm
    datos = list(DATOS_ANTIGUOS) + list(DATOS_NUEVOS)
    cuenta_d = {}
    for x, y, g, _ in datos:
        cuenta_d[g] = cuenta_d.get(g, 0) + 1
        nombres[(x, y, g)] = "%s_%02d" % (g, cuenta_d[g])
    # Suelo: azar por manchas y caminos de tierra en lo nuevo
    suelo2 = azar_suelo(suelo, marcas, rng)
    senderos(suelo2, [((11, 20), (11, 29)), ((4, 30), (38, 30)), ((8, 31), (8, 38)), ((15, 31), (16, 36)), ((35, 31), (35, 38)), ((43, 31), (44, 39)),
                      ((12, 3), (26, 3)), ((26, 3), (30, 4)), ((30, 5), (30, 29))])
    # Casillas que el decorado no toca: las de los puzles (contadores, puertas, barril)
    puz_celdas = [(8, 35), (8, 39), (23, 36), (27, 39), (35, 36), (35, 39), (32, 35), (34, 35), (36, 35), (38, 35), (46, 34), (47, 34), (47, 36), (44, 40)]
    piezas, relleno = decorado(suelo2, marcas, puz_celdas, rng)
    filas_txt = escribir_txt("%s/mapas/Bosque_01.txt" % salida, cab_vieja, suelo2, marcas, PUZLES)
    print("\n".join("%2d %s" % (i, f) for i, f in enumerate(filas_txt)))
    escribir_tscn("%s/Nivel_Bosque_01.tscn" % salida, suelo2, marcas, nombres, datos, piezas, relleno, plantilla, carpeta_piezas, rng)
    print("pintadas %d casillas · relleno %d · decorado suelto %d" % (len(suelo2), len(relleno), len(piezas)))


if __name__ == "__main__":
    main()
