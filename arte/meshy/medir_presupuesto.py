#!/usr/bin/env python3
"""Mide triángulos, texturas y huesos de los GLB del arte y los compara con el presupuesto de PLAN_EOW F4.

Por qué: F4 pide decir qué decimar, y eso solo se puede afirmar midiendo. Lee la cabecera JSON del GLB (no
carga Godot), así que va en cualquier sitio con Python + Pillow.
Presupuesto (docs de EoW, ANEXO 4, con nuestras palabras): protagonista 5–10k tris, enemigos 1,5–4k,
piezas 300–1.500, texturas 256–1024², sin LODs.

Uso:  python medir_presupuesto.py [carpeta_arte]     (por defecto la carpeta `arte` junto a este script)
Escribe una tabla TSV por la salida estándar: archivo, categoría, tris, nº imágenes, lado máx., Mpíxeles, huesos, clips, KB, veredicto.
"""
import glob
import io
import json
import os
import struct
import sys
from PIL import Image

PRESUPUESTO = {"personaje": (5000, 10000), "enemigo": (1500, 4000), "pieza": (300, 1500), "equipo": (300, 1500)}
LADO_MAX = 1024


def categoria(ruta):
    n = os.path.basename(ruta)
    if "equipo" in ruta.replace("\\", "/").split("/"):
        return "equipo"
    if "piezas" in ruta.replace("\\", "/").split("/"):
        return "pieza"
    if n.startswith(("goblin", "canouro", "loberno", "lince", "elemental", "gato")):
        return "enemigo"
    return "personaje"


def medir(ruta):
    d = open(ruta, "rb").read()
    lj = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + lj])
    lb = struct.unpack("<I", d[20 + lj:24 + lj])[0]
    b = d[28 + lj:28 + lj + lb]
    tris = 0
    for m in j.get("meshes", []):
        for p in m["primitives"]:
            if p.get("mode", 4) != 4:
                continue
            a = j["accessors"][p["indices"]] if "indices" in p else j["accessors"][p["attributes"]["POSITION"]]
            tris += a["count"] // 3
    lados, pix = [], 0
    for im in j.get("images", []):
        if "bufferView" in im:
            bv = j["bufferViews"][im["bufferView"]]
            o = bv.get("byteOffset", 0)
            try:
                w, h = Image.open(io.BytesIO(b[o:o + bv["byteLength"]])).size
            except Exception:
                w = h = 0
            lados.append(max(w, h))
            pix += w * h
    huesos = sum(len(s["joints"]) for s in j.get("skins", []))
    return tris, len(lados), max(lados, default=0), pix / 1e6, huesos, len(j.get("animations", [])), os.path.getsize(ruta) // 1024


def main():
    raiz = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    rutas = sorted(glob.glob(os.path.join(raiz, "modelos", "*.glb")) + glob.glob(os.path.join(raiz, "equipo", "*.glb"))
                   + glob.glob(os.path.join(raiz, "meshy", "piezas", "*.glb")))
    print("archivo\tcategoria\ttris\timagenes\tlado_max\tMpixeles\thuesos\tclips\tKB\tveredicto")
    for r in rutas:
        t, ni, lado, mp, h, c, kb = medir(r)
        cat = categoria(r)
        lo, hi = PRESUPUESTO[cat]
        v = []
        if t > hi:
            v.append("tris x%.1f" % (t / hi))
        if lado > LADO_MAX:
            v.append("tex %d" % lado)
        print("%s\t%s\t%d\t%d\t%d\t%.2f\t%d\t%d\t%d\t%s" % (os.path.relpath(r, raiz), cat, t, ni, lado, mp, h, c, kb, ", ".join(v) or "ok"))


if __name__ == "__main__":
    main()
