#!/usr/bin/env python3
"""Parte el pack `sm_rocks_objects.glb` (10 rocas x 3 materiales A/B/C en un solo GLB) en UN GLB POR ROCA.

El pack trae las mismas 10 mallas tres veces (A = tierra parda, B = con musgo, C = volcanica con venas rojas) con las MISMAS UV
(comprobado: acceso a acceso identico), asi que el albedo de A y el normal + roughness de C valen para todas. Este script:
  - toma la malla del material A de cada roca (posicion, normal, UV, indices),
  - la centra en X/Z y apoya la base en y = 0 (origen en el centro de la base, como todas las piezas), en METROS DEL PACK
    (la escala final la pone `MEDIDA` de mundo/pieza_3d.gd),
  - la escribe como GLB con un nodo llamado como el id y UN material con SOLO el juego A (albedo; roughness fija 0,9; sin normal,
    sin roughness de C y sin emissive: mezclar juegos enseñaba las grietas de la lava sobre el color de A),
  - las texturas NO van embebidas (serian 3,3 MB x 10): se referencian por URI relativa, una sola copia compartida.

Uso:  python -I separar_rocas.py <sm_rocks_objects.glb> <carpeta_texturas_origen>
Escribe en esta misma carpeta (fuentes, texturas en ./texturas) y en arte/meshy/piezas (instaladas, texturas en ./tex_rocas_est).
"""
from __future__ import annotations

import json
import shutil
import struct
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
PIEZAS = AQUI.parent.parent / "piezas"

# indice de malla del pack (material A) -> id. Criterio: lado mayor >= 1,1 m del pack = roca; menos = piedra.
IDS = {
    1: "roca_est_0",   # stoneB2   1,29 m  bolo redondeado, el mayor
    7: "roca_est_1",   # stone6    1,22 m  macizo, ~cubico
    8: "roca_est_2",   # stoneK    1,22 m  macizo, mas estrecho en Z
    4: "roca_est_3",   # stone3    1,17 m
    5: "roca_est_4",   # stone4    1,18 m  alto y estrecho (menhir)
    0: "piedra_est_0",  # stoneB1  0,82 m
    6: "piedra_est_1",  # stone5   0,69 m
    9: "piedra_est_2",  # stoneG   1,00 m plana
    3: "piedra_est_3",  # stone2   1,01 m losa
    2: "piedra_est_4",  # stone1   0,98 m losa baja
}
# Tres variantes del pack, cada una con SU juego de texturas completo (nunca se mezclan): sufijo del id, texturas de origen -> nombre instalado.
VARIANTES = {
    "": {"albedo": ("T_rocks_A_col_0.png", "rocas_albedo.png")},                                  # neutra (A, parda): cueva
    "musgo_": {"albedo": ("T_rocks_B_colors_1.png", "rocas_musgo_albedo.png")},                    # con musgo (B): bosque
    "magma_": {"albedo": ("T_rocks_C_col_4.png", "rocas_magma_albedo.png"),                        # volcanica (C): magma
               "normal": ("T_rocks_C_normal_3.png", "rocas_magma_normal.png"),
               "rough": ("T_rocks_C_roughtness_5@channels=G.png", "rocas_magma_rough.png"),
               "emisivo": ("T_rocks_C_emissives_2.png", "rocas_magma_emisivo.png")},
}


def leer_glb(p: Path):
    d = p.read_bytes()
    jl = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + jl])
    o = 20 + jl
    bl = struct.unpack("<I", d[o:o + 4])[0]
    return j, d[o + 8:o + 8 + bl]


def escribir_glb(p: Path, j: dict, b: bytes) -> None:
    js = json.dumps(j, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    b += b"\0" * ((4 - len(b) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(b)
    p.write_bytes(struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js
                  + struct.pack("<II", len(b), 0x004E4942) + b)


def datos(j: dict, b: bytes, acc: int, comp: int, n: int) -> bytes:
    a = j["accessors"][acc]
    v = j["bufferViews"][a["bufferView"]]
    ini = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    return b[ini:ini + a["count"] * comp * n]


def main() -> None:
    glb = Path(sys.argv[1])
    tex = Path(sys.argv[2])
    j, b = leer_glb(glb)
    (AQUI / "texturas").mkdir(exist_ok=True)
    (PIEZAS / "tex_rocas_est").mkdir(exist_ok=True)
    for v in VARIANTES.values():
        for o, n in v.values():
            shutil.copy2(tex / o, AQUI / "texturas" / n)
            shutil.copy2(tex / o, PIEZAS / "tex_rocas_est" / n)
    lote = {}
    for im, id_ in IDS.items():
        at = j["meshes"][im]["primitives"][0]["attributes"]
        idx_acc = j["meshes"][im]["primitives"][0]["indices"]
        pos = list(struct.unpack("<%df" % (j["accessors"][at["POSITION"]]["count"] * 3), datos(j, b, at["POSITION"], 4, 3)))
        nor = datos(j, b, at["NORMAL"], 4, 3)
        uv = datos(j, b, at["TEXCOORD_0"], 4, 2)
        ia = j["accessors"][idx_acc]
        fmt = {5123: "H", 5125: "I"}[ia["componentType"]]
        tam = {"H": 2, "I": 4}[fmt]
        ind = struct.unpack("<%d%s" % (ia["count"], fmt), datos(j, b, idx_acc, tam, 1))
        xs, ys, zs = pos[0::3], pos[1::3], pos[2::3]
        cx, cz, y0 = (min(xs) + max(xs)) / 2, (min(zs) + max(zs)) / 2, min(ys)
        for k in range(0, len(pos), 3):
            pos[k] -= cx
            pos[k + 1] -= y0
            pos[k + 2] -= cz
        mn = [min(pos[0::3]), min(pos[1::3]), min(pos[2::3])]
        mx = [max(pos[0::3]), max(pos[1::3]), max(pos[2::3])]
        bp = struct.pack("<%df" % len(pos), *pos)
        bi = struct.pack("<%dI" % len(ind), *ind)
        cuerpo = bp + nor + uv + bi
        nv = len(pos) // 3
        for suf, tx in VARIANTES.items():
            vid = id_.replace("_est_", "_est_" + suf)
            for destino, base in ((AQUI, "texturas/"), (PIEZAS, "tex_rocas_est/")):
                orden = ["albedo"] + [k for k in ("normal", "rough", "emisivo") if k in tx]
                idx = {k: n for n, k in enumerate(orden)}
                mat = {"name": "m_rocas", "pbrMetallicRoughness": {"baseColorTexture": {"index": idx["albedo"]}, "metallicFactor": 0.0, "roughnessFactor": 0.9}}
                if "normal" in tx:
                    mat["normalTexture"] = {"index": idx["normal"]}
                if "rough" in tx:
                    mat["pbrMetallicRoughness"]["roughnessFactor"] = 1.0
                    mat["pbrMetallicRoughness"]["metallicRoughnessTexture"] = {"index": idx["rough"]}
                if "emisivo" in tx:
                    mat["emissiveTexture"] = {"index": idx["emisivo"]}
                    mat["emissiveFactor"] = [1.0, 1.0, 1.0]
                jj = {
                    "asset": {"version": "2.0", "generator": "separar_rocas.py (pack LeLu sm_rocks_objects)"},
                    "scene": 0, "scenes": [{"nodes": [0]}],
                    "nodes": [{"name": vid, "mesh": 0}],
                    "meshes": [{"name": vid, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "material": 0}]}],
                    "materials": [mat],
                    "textures": [{"source": n, "sampler": 0} for n in range(len(orden))],
                    "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
                    "images": [{"uri": base + tx[k][1]} for k in orden],
                    "accessors": [
                        {"bufferView": 0, "componentType": 5126, "count": nv, "type": "VEC3", "min": mn, "max": mx},
                        {"bufferView": 1, "componentType": 5126, "count": nv, "type": "VEC3"},
                        {"bufferView": 2, "componentType": 5126, "count": nv, "type": "VEC2"},
                        {"bufferView": 3, "componentType": 5125, "count": len(ind), "type": "SCALAR"},
                    ],
                    "bufferViews": [
                        {"buffer": 0, "byteOffset": 0, "byteLength": len(bp), "target": 34962},
                        {"buffer": 0, "byteOffset": len(bp), "byteLength": len(nor), "target": 34962},
                        {"buffer": 0, "byteOffset": len(bp) + len(nor), "byteLength": len(uv), "target": 34962},
                        {"buffer": 0, "byteOffset": len(bp) + len(nor) + len(uv), "byteLength": len(bi), "target": 34963},
                    ],
                    "buffers": [{"byteLength": len(cuerpo)}],
                }
                escribir_glb(destino / (vid + ".glb"), jj, cuerpo)
            lote[vid] = {"estado": "procesado", "directo": True, "origen": "sm_rocks_objects.glb (malla %s)" % j["meshes"][im]["name"],
                         "variante": {"": "neutra (A)", "musgo_": "musgo (B)", "magma_": "magma (C)"}[suf],
                         "tris": len(ind) // 3, "vertices": nv,
                         "tam_m": [round(mx[0] - mn[0], 3), round(mx[1] - mn[1], 3), round(mx[2] - mn[2], 3)],
                         "nota": "roca estilizada del pack LeLu; origen en el centro de la base; un solo juego de texturas (%s)" % ", ".join(tx)}
            print(vid, lote[vid]["tam_m"], lote[vid]["tris"])


main()
