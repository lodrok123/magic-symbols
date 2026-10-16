#!/usr/bin/env python3
"""Hoja de cálculo del nivel (xlsx) -> mapas/<Nivel>.txt + Nivel_<Nivel>.tscn horneado (Bosque 01).

Por qué existe: el horneado de verdad lo hace F9 en Godot (HorneadorNivel), pero necesita el árbol `arte/` completo. Este script
escribe el MISMO formato (GridMap Suelo + Piezas + Borde + Marcadores) a partir de la hoja, para que Pablo lo abra y lo edite
en Godot como cualquier otro nivel. Es repetible: misma hoja y misma semilla -> mismo resultado.

Uso (desde la raíz del repo):
    python tools/hoja_a_nivel.py Nivel_Bosque_01.xlsx mundo/datos_nivel Bosque_01 --plantilla mundo/datos_nivel/Nivel_Bosque.tscn
Lee los uid de las piezas de la plantilla (un Nivel_*.tscn ya horneado) para no inventarlos. Necesita `pip install openpyxl`.
Si el Nivel_<Nombre>.tscn o el mapa ya existen NO los pisa: los aparta como *_copia_<fecha> (igual que HorneadorNivel.hornear), porque
el .tscn lleva las ediciones de Pablo. Toda la interpretación de la hoja (qué es cada etiqueta) está en las tablas MARCAS, SUELO_EXTRA y
RECT_EXTRA: si la hoja cambia o una lectura no era la que querías, se cambia ahí y se vuelve a ejecutar.
"""
import math
import os
import random
import re
import sys
import time
from collections import deque

import openpyxl

S = 2.3            # lado de casilla (HorneadorNivel.S)
ALTO = 1.035       # alto de casilla (HorneadorNivel.ALTO)
Y_PIEZA = 1.005
SEMILLA = 10

# --- colores de la hoja -> suelo -------------------------------------------------------------------------------
# (theme, tint) -> letra de suelo. `p` = camino de tierra clara: se hornea como tierra `g`.
COLORES = {
    ("t", 6, 0.8): ".",   # verde claro: suelo
    ("t", 9, 0.0): "#",   # verde oscuro: pared de árboles
    ("t", 4, 0.8): "~",   # azul claro: agua (río)
    ("t", 4, 0.6): "c",   # azul fuerte "V": estanque vacío = cauce seco
    ("t", 5, 0.6): "g",   # salmón: tierra
    ("t", 5, 0.8): "g",   # salmón pálido: camino de tierra
}


def col_idx(letras):
    n = 0
    for ch in letras:
        n = n * 26 + ord(ch) - 64
    return n


def coord(texto):
    m = re.fullmatch(r"([A-Z]+)(\d+)", texto)
    return col_idx(m.group(1)), int(m.group(2))


COL0 = col_idx("E")      # la hoja empieza en E (columna 0 del dibujo)
FILA0 = 6                # primera fila con contenido
MARGEN = 1               # un árbol de borde alrededor


def a_mapa(texto):
    """'N6' -> (x, y) del mapa horneado (con el margen de árboles)."""
    c, f = coord(texto)
    return (c - COL0 + MARGEN, f - FILA0 + MARGEN)


# --- LECTURA DE LA HOJA ---------------------------------------------------------------------------------------
def leer(ruta):
    wb = openpyxl.load_workbook(ruta)
    ws = wb["Nivel_01"]
    pintura = {}
    otros = {}          # celdas coloreadas que no son suelo (marcadores): color crudo
    for fila in ws.iter_rows(min_row=FILA0, max_row=31, min_col=COL0, max_col=col_idx("AD")):
        for c in fila:
            f = c.fill
            if f is None or f.fill_type is None:
                continue
            g = f.fgColor
            clave = g.rgb if g.type == "rgb" else ("t", g.theme, round(g.tint, 1))
            xy = (c.column - COL0 + MARGEN, c.row - FILA0 + MARGEN)
            if clave in COLORES:
                pintura[xy] = COLORES[clave]
            else:
                otros[xy] = clave
    return pintura, otros


# --- INTERPRETACIÓN (acordada con Pablo el 16/10; ver docs/DIARIO.md, entrada 106) ----------------------------
# Marcadores por casilla de la hoja. El tronco del estanque (T19, «V T», sobre el cauce) pasa a la casilla de su orilla oeste (S19): la letra `l`
# SUSTITUYE al cauce `c` en el mapa y el estanque necesita sus 15 casillas `c` (Puzle3D lo exige). Un paso a la izquierda, a propósito.
MARCAS = {
    "F26": "S",
    "F10": "W", "G10": "W",              # «G G»: dos goblins guerreros
    "M8": "r",                           # telaraña (gris)
    "N9": "Z",                           # C_1: cofre del glifo de barrera (oculto hasta que mueran los goblins)
    "AD20": "Z",                         # C_2: cofre final de la demo (aparece al caer el jefe)
    "AC20": "G",                         # E_B: elemental del bosque
    "Y20": "X",                          # P_1: puerta de los tres tótems
    "Q24": "Q",                          # ALC: alquimista
    "N19": "s", "N23": "s",              # I_2: seta reactiva
    "J26": "q",                          # I_1: raíz del mundo
    "W13": "j", "U24": "j", "V30": "j",  # TF_2, TF_3, TF_1: tótems de fuego
    "V14": "T", "W14": "T", "F17": "T",  # braseros (naranja = antorcha)
    "W18": "T", "U21": "T", "U16": "T", "W22": "T",   # T_1..T_4: antorchas secuenciales
}
DECOR_TIENDA = ["N6", "N7"]              # CG: campamento goblin (tienda_goblin, decorado)
# Suelo que la hoja no pinta pero hace falta (conectores y casillas con etiqueta sobre fondo vacío).
SUELO_EXTRA = {
    "T14": ".",                          # T_C: la losa del estanque (casilla gris de la hoja) sobre el borde norte del cauce
    "K10": ".",                          # orilla este del puente (casilla gris «P» de la hoja)
    "I10": ".",                          # paso al otro lado del río (el puente va en J10)
    "H10": ".",                          # H: hueco en el muro de la columna H
    "K20": ".", "L20": ".",              # unen el camino J con el claro
    "V26": ".",                          # une el prado con la zona del tótem 1
    "M10": "g",                          # casilla gris sin etiqueta junto al puente: camino
}
RECT_EXTRA = [("E18", "G19", "."), ("J22", "J26", "."), ("M6", "N9", "."), ("M16", "O25", "."), ("V27", "W29", "v")]
SUELO_FORZADO = {"V30": "v", "V31": "v"}  # el tótem 1 y la casilla bajo él, en hierba alta (propagación del fuego)
PUENTE = {"casilla": "J10"}              # casilla del río que cubre el tronco caído (letra `b` al caer; en el mapa sigue siendo agua `~`)
# Marcadores de DATOS (letra vacía + grupo; los lee escenas/bosque_01_3d.gd en `m._marcas`; la maqueta los ignora):
#   (casilla, grupo, tipo, giro en grados). Respuestas de Pablo (16/10):
#   - tronco_puente: el «P» de la hoja. Tronco visible en la orilla este (K10) con enredaderas; golpeado, cae SIEMPRE hacia delante
#     (su eje X local, giro 180 = hacia el oeste) sobre el río (J10) y queda de puente.
#   - tronco_estanque: el «V T» de la hoja (T19, sobre el cauce): yace al fondo del estanque y sube cuando el agua lo llena.
#   - loberno: los «L» (M19, M23): el modelo aprobado `loberno.glb` (viene del lince).
DATOS_MARCAS = [
    ("K10", "tronco_puente", "", 180), ("T19", "tronco_estanque", "", 0),
    ("M19", "loberno", "", 0), ("M23", "loberno", "", 0),
]
PUERTA_GIRO = {"Y20": 90}                # se cruza de oeste a este

LETRAS = {   # copia mínima de marcador_3d.gd: grupo y tipo de cada letra usada
    "S": ("inicio_jugador", ""), "W": ("goblin", "guerrero"), "G": ("goblin", "elemental"), "X": ("puerta", ""),
    "Q": ("npc", "alquimista"), "j": ("reactivo", "totem_fuego"),
    "T": ("reactivo", "brasero"), "s": ("reactivo", "seta"), "q": ("reactivo", "raiz"), "r": ("reactivo", "telarana"),
    "Z": ("cofre", "cofre"),
}

# Puzles declarados (los lee escenas/puzle.gd): losa T_C -> sube el agua del estanque.
def lineas_puzle():
    lx, ly = a_mapa("T14")
    mx, my = a_mapa("X15")
    x0, y0 = a_mapa("T15")
    x1, y1 = a_mapa("X15")
    xs, ys = a_mapa("T25")
    return [
        "; --- ESTANQUE (sheet: «Estanque vacío con un tronco. Con la losa se sube el agua»): la losa T_C (presencia) abre el manantial.",
        "; --- El manantial es FINITO (volumen 50 u³ ≈ 15 casillas a 0,6 de hondo) y la cuenca es cerrada: una vez llena se queda llena.",
        "; pieza losa_estanque pulsador %d %d modo=presencia" % (lx, ly),
        "; pieza estanque manantial %d %d celdas=%d,%d..%d,%d+%d,%d..%d,%d caudal=1.5 volumen=50 inicia=no"
        % (mx, my, x0, y0, x1, y1, x0, y0 + 1, xs, ys),
        "; puzle losa_sube_agua cuando=losa_estanque.pulsado hace=estanque.abrir_cauce",
    ]


# --- CONSTRUCCIÓN DEL MAPA --------------------------------------------------------------------------------------
def construir(pintura, otros):
    ancho = col_idx("AD") - COL0 + 1 + 2 * MARGEN
    alto = 31 - FILA0 + 1 + 2 * MARGEN
    lado = max(ancho, alto)
    suelo = {}
    for xy, ch in pintura.items():
        suelo[xy] = ch
    for k, ch in SUELO_EXTRA.items():
        suelo[a_mapa(k)] = ch
    for a, b, ch in RECT_EXTRA:
        (xa, ya), (xb, yb) = a_mapa(a), a_mapa(b)
        for y in range(ya, yb + 1):
            for x in range(xa, xb + 1):
                suelo.setdefault((x, y), ch)
    for k, ch in SUELO_FORZADO.items():
        suelo[a_mapa(k)] = ch
    # Casillas con marcador o puerta sobre fondo coloreado (naranja/gris/…): el suelo es el que dominan sus vecinas.
    marcas = {a_mapa(k): v for k, v in MARCAS.items()}
    for xy in list(marcas) + [a_mapa(k) for k in DECOR_TIENDA]:
        if xy in suelo and suelo[xy] != "#":
            continue
        votos = {}
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            v = suelo.get((xy[0] + dx, xy[1] + dy))
            if v in (".", "g", "v"):
                votos[v] = votos.get(v, 0) + 1
        suelo[xy] = max(votos, key=votos.get) if votos else "."
    # Vacío pegado a suelo jugable -> árbol (8 vecinas): el borde natural del nivel.
    nuevos = {}
    for y in range(lado):
        for x in range(lado):
            if (x, y) in suelo:
                continue
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    v = suelo.get((x + dx, y + dy))
                    if v is not None and v != "#":
                        nuevos[(x, y)] = "#"
    suelo.update(nuevos)
    return lado, suelo, marcas


def azar_suelo(suelo, marcas, semilla):
    """Reparte el '.' entre suelo, hierba corta ',' y tierra 'g' con manchas (ruido de valor), como HorneadorNivel._azar_suelo."""
    rng = random.Random(semilla)
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
        if ch != ".":
            continue
        n = ruido(x, y)
        res[(x, y)] = "g" if n > 0.74 else "," if n > 0.5 else "."
    return res


def alcanzable(lado, suelo, marcas):
    """BFS desde S por casillas andables. P (puente) y X (puerta) se cuentan como paso."""
    ini = [xy for xy, v in marcas.items() if v == "S"][0]
    pas = lambda xy: suelo.get(xy) not in (None, "#") and (suelo[xy] != "~" or xy == a_mapa(PUENTE["casilla"]))
    visto = {ini}
    cola = deque([ini])
    while cola:
        x, y = cola.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in visto and pas(q):
                visto.add(q)
                cola.append(q)
    return visto


# --- SALIDAS ---------------------------------------------------------------------------------------------------
LETRA_ITEM = {".": 0, "~": 1, "b": 2, "g": 3, "v": 4, ",": 5, "c": 6, "R": 7, "#": 0}


def apartar(ruta):
    """Si `ruta` existe la renombra a <nombre>_copia_<fecha>.<ext> (no se pierde nada)."""
    if os.path.exists(ruta):
        base, ext = os.path.splitext(ruta)
        copia = "%s_copia_%s%s" % (base, time.strftime("%Y%m%d_%H%M%S"), ext)
        os.rename(ruta, copia)
        print("aviso: ya existía %s; apartado como %s" % (ruta, copia))


def escribir_txt(ruta, nombre, lado, suelo, marcas, tiendas):
    filas = []
    for y in range(lado):
        fila = ""
        for x in range(lado):
            xy = (x, y)
            if xy in marcas:
                m = marcas[xy]
                fila += {"P": "~"}.get(m, m)
            elif xy in tiendas:
                fila += "t"
            else:
                fila += suelo.get(xy, " ")
        filas.append(fila)
    giros = []
    for k, g in PUERTA_GIRO.items():
        x, y = a_mapa(k)
        giros.append("; giro %d %d %d" % (x, y, g))
    cab = [
        "; %s (Fase 16, 16/10). %d × %d con el borde de árboles; salido de la hoja `Nivel_%s.xlsx` con tools/hoja_a_nivel.py." % (nombre, lado, lado, nombre),
        "; Letras: marcador_3d.gd y hornear_nivel.gd. `t` tienda goblin (decorado). El TRONCO-PUENTE (cae sobre J10 del dibujo) es un marcador de datos",
        ";   del Nivel_%s.tscn horneado; aquí la casilla (6, 5) se ve como agua `~`. Lo lee PruebaTest2 (nivel = \"%s\") mientras no exista el .tscn." % (nombre, nombre),
        "; Reglas: escenas/bosque_01_3d.gd (nodo «Reglas» de escenas/PruebaBosque01.tscn). Puzles declarados: las líneas `pieza` y `puzle` de abajo.",
        "; Cofres `Z`: el primero (arriba, campamento) es C_1 (glifo de barrera) y el segundo (este) es C_2 (fin de la demo).",
        "; azar_suelo 1 %d %d" % (lado - 2, SEMILLA),
    ]
    cab += giros + lineas_puzle()
    apartar(ruta)
    open(ruta, "w", encoding="utf-8", newline="\n").write("\n".join(cab + filas) + "\n")
    return filas


def plantilla_recursos(ruta):
    """ext_resource de la plantilla: id -> (type, uid, path)."""
    res = {}
    for l in open(ruta, encoding="utf-8"):
        m = re.match(r'\[ext_resource type="(\w+)" uid="([^"]+)" path="([^"]+)" id="([^"]+)"\]', l)
        if m:
            res[m.group(3)] = (m.group(1), m.group(2), m.group(4))
    return res


def transform(yaw, esc, x, y, z, esc_y=None):
    c, s = math.cos(yaw) * esc, math.sin(yaw) * esc
    ey = esc if esc_y is None else esc_y
    f = lambda v: ("%.7g" % v)
    return "Transform3D(%s, 0, %s, 0, %s, 0, %s, 0, %s, %s, %s, %s)" % (f(c), f(s), f(ey), f(-s), f(c), f(x), f(y), f(z))


def escribir_tscn(ruta, nombre, lado, suelo, marcas, tiendas, plantilla):
    rec = plantilla_recursos(plantilla)
    P = "res://arte/piezas/"
    piezas_usadas = ["setas", "arbusto", "tocon", "piedras", "arbusto_flores", "tienda_goblin", "pino", "arbol_redondo"]
    ids = {}
    cab = ['[gd_scene format=3]', ""]
    n = 1
    lib_path = "res://mundo/datos_nivel/suelo_tipos.tres"
    lib = rec[lib_path]
    cab.append('[ext_resource type="MeshLibrary" uid="%s" path="%s" id="1_lib"]' % (lib[1], lib_path))
    for p in piezas_usadas:
        r = rec[P + p + ".tscn"]
        ids[p] = "%d_%s" % (n + 1, p)
        cab.append('[ext_resource type="PackedScene" uid="%s" path="%s" id="%s"]' % (r[1], P + p + ".tscn", ids[p]))
        n += 1
    sc = rec["res://mundo/marcador_3d.gd"]
    cab.append('[ext_resource type="Script" uid="%s" path="res://mundo/marcador_3d.gd" id="99_mk"]' % sc[1])
    cab.append("")
    nodo_raiz = "Nivel_" + nombre[:1].upper() + nombre[1:]
    out = cab + [
        '[node name="%s" type="Node3D"]' % nodo_raiz,
        "metadata/lado = %d" % lado,
        'metadata/nombre = "%s"' % nombre,
        'metadata/origen = "hoja"',
        'metadata/horneado = "%s"' % time.strftime("%Y-%m-%dT%H:%M:%S"),
        "",
    ]
    # Suelo
    celdas = []
    for y in range(lado):
        for x in range(lado):
            ch = suelo.get((x, y))
            if ch is None:
                continue
            celdas += [x, y, LETRA_ITEM[ch]]
    out += [
        '[node name="Suelo" type="GridMap" parent="."]',
        'mesh_library = ExtResource("1_lib")',
        "cell_size = Vector3(%s, %s, %s)" % (S, ALTO, S),
        "cell_center_y = false",
        "data = {",
        '"cells": PackedInt32Array(%s)' % ", ".join(map(str, celdas)),
        "}",
        "",
    ]
    # Piezas: tiendas + decorado repartido (sin tocar marcadores, caminos estrechos ni la hierba alta)
    rng = random.Random(SEMILLA + 1)
    ocupadas = set(marcas) | set(tiendas)
    cerca = set()
    for (x, y) in ocupadas:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                cerca.add((x + dx, y + dy))
    out += ['[node name="Piezas" type="Node3D" parent="."]', ""]
    nombres = {}
    def pieza(pid, c, sin_bloqueo=False, esc=1.0, padre="Piezas", yaw=None):
        x, y = c
        yw = rng.uniform(0, 2 * math.pi) if yaw is None else yaw
        jx, jz = rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35)
        px, pz = (x + 0.5) * S + jx, (y + 0.5) * S + jz
        base = "%s_%d_%d" % (pid, x, y)
        k = nombres.get(base, 0)
        nombres[base] = k + 1
        nm = base if k == 0 else "%s_%d" % (base, k)
        lin = ['[node name="%s" parent="%s" instance=ExtResource("%s")]' % (nm, padre, ids[pid]),
               "transform = " + transform(yw, esc, px, Y_PIEZA, pz)]
        if sin_bloqueo:
            lin.append("metadata/bloquea = false")
        lin.append("")
        return lin
    for t in tiendas:
        out += pieza("tienda_goblin", t, esc=1.05)
    decor = [("arbusto", True), ("arbusto_flores", True), ("tocon", True), ("piedras", False), ("setas", False)]
    n_dec = 0
    for y in range(lado):
        for x in range(lado):
            ch = suelo.get((x, y))
            if ch not in (".", ",") or (x, y) in cerca:
                continue
            libres = sum(1 for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                         if (dx or dy) and suelo.get((x + dx, y + dy)) not in (None, "#", "~", "c"))
            if libres < 5 or rng.random() > 0.2:
                continue
            pid, sb = decor[rng.randrange(len(decor))]
            out += pieza(pid, (x, y), sb, esc=rng.uniform(0.92, 1.08))
            n_dec += 1
    # Borde: un árbol en cada pared
    out += ['[node name="Borde" type="Node3D" parent="."]', ""]
    for y in range(lado):
        for x in range(lado):
            if suelo.get((x, y)) == "#":
                pid = "pino" if rng.random() < 0.28 else "arbol_redondo"
                out += pieza(pid, (x, y), esc=rng.uniform(1.0, 1.12), padre="Borde")
    # Marcadores
    out += ['[node name="Marcadores" type="Node3D" parent="."]', ""]
    nombre_marca = {}
    orden = sorted(marcas.items(), key=lambda kv: (kv[0][1], kv[0][0]))
    for (x, y), letra in orden:
        nombre_marca[(x, y)] = "%s_%d_%d" % (letra, x, y)
    todos = [(xy, letra, None) for xy, letra in orden] + [(a_mapa(k), "", (g_, t_, gi_)) for k, g_, t_, gi_ in DATOS_MARCAS]
    for (x, y), letra, dato in todos:
        g, t = LETRAS[letra] if letra else (dato[0], dato[1])
        nm = "%s_%d_%d" % (letra or g, x, y)
        grupos = sorted(["marcador", g])
        giro = math.radians(dato[2]) if dato else 0.0
        for k, gr in PUERTA_GIRO.items():
            if a_mapa(k) == (x, y):
                giro = math.radians(gr)
        out.append('[node name="%s" type="Node3D" parent="Marcadores" groups=[%s]]' % (nm, ", ".join('"%s"' % q for q in grupos)))
        f = lambda v: "%.7g" % v
        c, s = math.cos(giro), math.sin(giro)
        if abs(c) < 1e-9:
            c = 0.0
        out.append("transform = Transform3D(%s, 0, %s, 0, 1, 0, %s, 0, %s, %s, %s, %s)" % (f(c), f(s), f(-s), f(c), f((x + 0.5) * S), ALTO, f((y + 0.5) * S)))
        out.append('script = ExtResource("99_mk")')
        if dato:
            out.append('grupo = "%s"' % g)      # marcador de datos: sin letra
        else:
            out.append('letra = "%s"' % letra)
            if t and letra not in ("Q", "Z", "W", "G"):
                out.append('tipo = "%s"' % t)
        out.append("")
    apartar(ruta)
    open(ruta, "w", encoding="utf-8", newline="\n").write("\n".join(out))
    return n_dec


def vista(lado, suelo, marcas, tiendas):
    s = []
    for y in range(lado):
        fila = ""
        for x in range(lado):
            xy = (x, y)
            if xy in marcas:
                fila += marcas[xy]
            elif xy in tiendas:
                fila += "t"
            else:
                fila += suelo.get(xy, " ")
        s.append("%2d %s" % (y, fila))
    return "\n".join(s)


def main():
    hoja, carpeta, nombre = sys.argv[1], sys.argv[2], sys.argv[3]
    plantilla = sys.argv[sys.argv.index("--plantilla") + 1]
    pintura, otros = leer(hoja)
    lado, suelo, marcas = construir(pintura, otros)
    tiendas = {a_mapa(k) for k in DECOR_TIENDA}
    # 1) comprobaciones sobre el suelo sin azar
    vis = alcanzable(lado, suelo, marcas)
    inalc = [(xy, v) for xy, v in marcas.items() if xy not in vis]
    print(vista(lado, suelo, marcas, tiendas))
    print("lado", lado, "· casillas de suelo:", sum(1 for v in suelo.values() if v != "#"), "· árboles:", sum(1 for v in suelo.values() if v == "#"))
    print("marcadores inalcanzables desde S:", inalc, "· losa T_C alcanzable:", a_mapa("T14") in vis)
    # 2) el azar de suelo solo toca '.', y solo en el .tscn; el .txt lleva `; azar_suelo` y lo reparte el horneador al leerlo
    suelo_azar = azar_suelo(suelo, marcas, SEMILLA)
    filas = escribir_txt("%s/mapas/%s.txt" % (carpeta, nombre), nombre, lado, suelo, marcas, tiendas)
    nd = escribir_tscn("%s/Nivel_%s.tscn" % (carpeta, nombre[:1].upper() + nombre[1:]), nombre, lado, suelo_azar, marcas, tiendas, plantilla)
    print("txt: %d filas · decorado: %d piezas" % (len(filas), nd))


if __name__ == "__main__":
    main()
