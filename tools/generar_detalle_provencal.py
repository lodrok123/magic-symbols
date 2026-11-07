#!/usr/bin/env python3
"""Regenera los mapas de DETALLE EN GRIS y las normales de arte/provencal/detalle/ desde los TGA del pack Fantasy Provencal (Leartes Studios).

Es un envoltorio de `herramientas/generar_detalle_provencal.gd` (mismo redimensionado Lanczos de Godot que genero los PNG que ya hay: asi la salida es identica byte a byte).
La formula esta en la cabecera de ese .gd (general: d = 1 + 0,6·(L - media)/media recortado a [0,4 ; 1,25]; las ventanas, estiradas a su percentil 2-98 sin recortar).

Uso (desde la raiz del repo):
    python tools/generar_detalle_provencal.py [--tga <carpeta con los TGA>] [--salida arte/provencal/detalle] [--godot <Godot.exe>]
Por defecto --tga es la carpeta del pack extraido de Pablo y --godot el de tools/. Para comprobar sin pisar nada: --salida <carpeta temporal> y comparar.
"""
import argparse
import os
import subprocess
import sys

BASE = r"C:\Users\pablo\AppData\Local\Temp\claude\E--magic-symbols--claude-worktrees-interactuables-database-list-ab3478\e2136824-0f58-4496-a7a8-9800c190c80d\scratchpad"
TGA_POR_DEFECTO = os.path.join(BASE, "tga")
GODOT_POR_DEFECTO = r"E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--tga", default=TGA_POR_DEFECTO)
    p.add_argument("--salida", default="arte/provencal/detalle")
    p.add_argument("--godot", default=GODOT_POR_DEFECTO)
    a = p.parse_args()
    if not os.path.isdir(a.tga):
        print("FALLO  no existe la carpeta de TGA:", a.tga)
        return 2
    salida = os.path.abspath(a.salida)
    cmd = [a.godot, "--headless", "--path", ".", "--script", "res://herramientas/generar_detalle_provencal.gd", "--", os.path.abspath(a.tga), salida]
    print(" ".join(cmd))
    return subprocess.call(cmd)


if __name__ == "__main__":
    sys.exit(main())
