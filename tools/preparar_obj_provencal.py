#!/usr/bin/env python3
"""Prepara los OBJ del pack Fantasy Provencal (Leartes Studios) para Godot: escribe arte/provencal/obj/<pieza>.obj con el LOD que dice
`arte/provencal/tabla_provencal.gd` (campo "lod" de cada pieza y de sus "aspas").

Por que hace falta: los OBJ del paquete traen los submallas como comentarios (`#Section 0 Offset 0 NumIndices 13440 MaterialIndex 1 MI_Atlas`) y no como `usemtl`,
asi que Godot los importa como UNA superficie. Aqui se inserta `usemtl M_<material>` donde empieza cada seccion (y se quita el `mtllib`), para que cada superficie
lleve el material (y la textura) que le toca. Los de Polybrush (casas, santuario...) ya traen `usemtl` y se copian tal cual.

Uso (desde la raiz del repo; las rutas por defecto son las del equipo de Pablo):
    python tools/preparar_obj_provencal.py [--indice ...\\provencal_unity\\index.csv] [--x ...\\provencal_unity\\x] [--polybrush ...\\provencal_polybrush_obj]
Despues: godot --headless --path . --import  y  godot --headless --path . --script res://herramientas/generar_piezas_provencal.gd
"""
import argparse
import csv
import os
import re
import sys

BASE = r"C:\Users\pablo\AppData\Local\Temp\claude\E--magic-symbols--claude-worktrees-interactuables-database-list-ab3478\e2136824-0f58-4496-a7a8-9800c190c80d\scratchpad"
# Los OBJ de Unreal llaman distinto a algunos materiales: se pasan a los nombres del Unity del pack (los de la tabla).
RENOMBRAR = {"M_Barrel_Jars": "M_BarrelJars", "M_Flora_02": "M_Flora2", "M_Flora_02_TwoSided": "M_Flora2_doublesided", "M_Flora_02_TwoSided_2_Field": "M_Flora2_doublesided",
             "M_Flora_Flowers": "M_FloraFlower", "M_Flora_Flowers_02": "M_FloraFlower02", "M_GrassField": "M_Grass_a", "M_Rocks_": "M_Rocks", "M_Rocks_Bricks": "M_RocksBricks02",
             "M_Rocks_Bricks_2": "M_RocksBricks2", "M_Shrine_Candle": "M_ShrineCandle"}
SECCION = re.compile(r"^#Section\s+(\d+)\s+Offset\s+(\d+)\s+NumIndices\s+(\d+)\s+MaterialIndex\s+(\d+)\s+(\S+)")


def leer_tabla(ruta):
    """pieza -> (lod, lod de las aspas o None) leyendo las lineas de PIEZAS de la tabla."""
    res = {}
    for linea in open(ruta, encoding="utf-8"):
        m = re.match(r'\t"(SM_\w+)": \{.*?"lod": (\d+)', linea)
        if not m:
            continue
        lod = int(m.group(2))
        a = re.search(r'"aspas": \{"obj": "(SM_\w+)"(?:, "lod": (\d+))?', linea)
        res[m.group(1)] = (lod, (a.group(1), int(a.group(2)) if a.group(2) else lod) if a else None)
    return res


def nombre_fichero(pieza, lod):
    return pieza + (".obj" if lod == 0 else "_LOD%d.obj" % lod)


def buscar_fuente(pieza, lod, indice, x, polybrush):
    pb = os.path.join(polybrush, pieza + "_LOD%d.obj" % lod)
    if os.path.exists(pb):
        return pb
    fich = nombre_fichero(pieza, lod)
    for fila in indice:
        if fila["path"].endswith("/Meshes/" + fich):
            return os.path.join(x, fila["guid"], "asset")
    return None


def convertir(origen, destino):
    lineas = open(origen, encoding="utf-8", errors="replace").read().split("\n")
    secciones = []                       # (primera cara, nombre de material)
    for l in lineas:
        m = SECCION.match(l)
        if m:
            nombre = m.group(5)
            nombre = "M_" + nombre[3:] if nombre.startswith("MI_") else nombre
            nombre = RENOMBRAR.get(nombre, nombre)
            secciones.append((int(m.group(2)) // 3, nombre))
    salida = []
    cara = 0
    for l in lineas:
        if l.startswith("mtllib"):
            continue
        if l.startswith("f "):
            for desde, mat in secciones:
                if desde == cara:
                    salida.append("usemtl " + mat)
            cara += 1
        salida.append(l)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    open(destino, "w", encoding="utf-8", newline="\n").write("\n".join(salida))
    return len(secciones), cara


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--tabla", default="arte/provencal/tabla_provencal.gd")
    p.add_argument("--destino", default="arte/provencal/obj")
    p.add_argument("--indice", default=os.path.join(BASE, "provencal_unity", "index.csv"))
    p.add_argument("--x", default=os.path.join(BASE, "provencal_unity", "x"))
    p.add_argument("--polybrush", default=os.path.join(BASE, "provencal_polybrush_obj"))
    a = p.parse_args()
    indice = list(csv.DictReader(open(a.indice, encoding="utf-8-sig")))
    fallos = 0
    for pieza, (lod, aspas) in sorted(leer_tabla(a.tabla).items()):
        for nombre, l in [(pieza, lod)] + ([aspas] if aspas else []):
            fuente = buscar_fuente(nombre, l, indice, a.x, a.polybrush)
            if fuente is None:
                print("FALLO  sin fuente para %s LOD%d" % (nombre, l))
                fallos += 1
                continue
            secc, caras = convertir(fuente, os.path.join(a.destino, nombre + ".obj"))
            print("OK     %-26s LOD%d  %5d caras  %d secciones  <- %s" % (nombre, l, caras, secc, os.path.basename(os.path.dirname(fuente)) if fuente.endswith("asset") else os.path.basename(fuente)))
    return 1 if fallos else 0


if __name__ == "__main__":
    sys.exit(main())
