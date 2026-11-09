#!/usr/bin/env python3
"""Monta el PACK de un bioma: junta en UN solo GLB las piezas de Meshy que ya han llegado, con un nodo por pieza.

  1. Deja los GLB de las piezas del bioma en  arte\\meshy\\entrada\\  con el NOMBRE DEL ID (arbol_manglar.glb, cipres_calvo.glb...).
     (los sufijos "_texture" de Meshy se quitan solos)
  2. Lanza:   python arte\\meshy\\montar_pack_bioma.py pantano
     o doble clic en  MONTAR_PACK_BIOMA.cmd  (pide el bioma; por defecto «pantano»).
  3. Sale arte\\meshy\\packs\\pack_<bioma>.glb: UN NODO POR PIEZA, llamado como su id, con la BASE EN EL ORIGEN (su centro en X/Z y su suelo en y = 0).
     Es la convencion de las laminas que lee `Pieza3D.BIBLIOTECAS` (mundo/pieza_3d.gd): la maqueta busca el nodo por nombre y lo mide con MEDIDA / MEDIDA_ANCHO.
     Los nodos se reparten en fila (en X) para poder verlos juntos al abrir el pack; la maqueta les quita esa posicion.
  4. Dice que ids del bioma FALTAN (los de `accion = conseguir` de docs/assets_biomas.tsv, o de arte/meshy/packs/assets_biomas.tsv si el de docs no existe)
     y cuales de entrada/ no son del bioma.

Es REEJECUTABLE: cada vez se vuelve a montar el pack entero con lo que haya en entrada/. Los GLB de entrada NO se mueven ni se borran
(a diferencia de integrar_piezas.py, que los pasa a piezas/): el pack se rehace desde ellos. Si una pieza ya llego a `meshy/piezas/<id>.glb`
(integrar_piezas.py), esa pieza suelta manda en el juego (Pieza3D mira primero meshy/piezas/); el pack sirve a las que se quedan solo en el pack.

Opciones (para pruebas):  --entrada <carpeta>  --salida <carpeta>  --tsv <archivo>  --separacion <u>
Solo stdlib. Quita animaciones y esqueletos (las piezas de decorado son estaticas).
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import re
import struct
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parent.parent
ENTRADA = AQUI / "entrada"
PACKS = AQUI / "packs"
TSV_CANDIDATOS = [RAIZ / "docs" / "assets_biomas.tsv", PACKS / "assets_biomas.tsv"]
MAX_TRIS = 5000


# ---------------------------------------------------------------- GLB ---------------------------------------------------------------
def leer_glb(p: Path) -> tuple[dict, bytes]:
    d = p.read_bytes()
    if d[:4] != b"glTF":
        raise ValueError("no es un GLB")
    jl = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + jl])
    o = 20 + jl
    bin_ = b""
    if o < len(d):
        bl = struct.unpack("<I", d[o:o + 4])[0]
        bin_ = d[o + 8:o + 8 + bl]
    return j, bin_


def escribir_glb(p: Path, j: dict, bin_: bytes) -> None:
    js = json.dumps(j, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    b = bin_ + b"\0" * ((4 - len(bin_) % 4) % 4)
    total = 12 + 8 + len(js) + (8 + len(b) if b else 0)
    out = struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js
    if b:
        out += struct.pack("<II", len(b), 0x004E4942) + b
    p.write_bytes(out)


def id_de(p: Path) -> str:
    s = p.stem.lower()
    s = re.sub(r"[^a-z0-9]+", "_", s).strip("_")
    s = re.sub(r"_(texture|textured|withskin)(_\d+)?$", "", s)
    return s


def triangulos(j: dict) -> int:
    t = 0
    for m in j.get("meshes", []):
        for pr in m.get("primitives", []):
            if "indices" in pr:
                t += j["accessors"][pr["indices"]]["count"] // 3
            else:
                t += j["accessors"][pr["attributes"]["POSITION"]]["count"] // 3
    return t


# ------------------------------------------------------------ geometria (caja) -------------------------------------------------------
def _mat_trs(n: dict) -> list[list[float]]:
    """Matriz 4x4 (filas) del nodo `n` (glTF: `matrix` va por columnas)."""
    if "matrix" in n:
        m = n["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    t = n.get("translation", [0.0, 0.0, 0.0])
    q = n.get("rotation", [0.0, 0.0, 0.0, 1.0])
    s = n.get("scale", [1.0, 1.0, 1.0])
    x, y, z, w = q
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    return [[r[0][0] * s[0], r[0][1] * s[1], r[0][2] * s[2], t[0]],
            [r[1][0] * s[0], r[1][1] * s[1], r[1][2] * s[2], t[1]],
            [r[2][0] * s[0], r[2][1] * s[1], r[2][2] * s[2], t[2]],
            [0.0, 0.0, 0.0, 1.0]]


def _por(a: list[list[float]], b: list[list[float]]) -> list[list[float]]:
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def caja_de(j: dict) -> tuple[list[float], list[float]] | None:
    """Caja (min, max) de la escena entera, con las transformaciones de los nodos. None si no hay geometria."""
    lo = [math.inf] * 3
    hi = [-math.inf] * 3
    ident = [[1.0 if r == c else 0.0 for c in range(4)] for r in range(4)]

    def visita(i: int, acum: list[list[float]]) -> None:
        n = j["nodes"][i]
        m = _por(acum, _mat_trs(n))
        if "mesh" in n:
            for pr in j["meshes"][n["mesh"]].get("primitives", []):
                a = j["accessors"][pr["attributes"]["POSITION"]]
                if "min" not in a or "max" not in a:
                    continue
                for cx in (a["min"][0], a["max"][0]):
                    for cy in (a["min"][1], a["max"][1]):
                        for cz in (a["min"][2], a["max"][2]):
                            for k in range(3):
                                v = m[k][0] * cx + m[k][1] * cy + m[k][2] * cz + m[k][3]
                                lo[k] = min(lo[k], v)
                                hi[k] = max(hi[k], v)
        for h in n.get("children", []):
            visita(h, m)

    escena = j.get("scenes", [{}])[j.get("scene", 0)]
    for r in escena.get("nodes", []):
        visita(r, ident)
    if lo[0] == math.inf:
        return None
    return lo, hi


# ------------------------------------------------------------------ fusion -----------------------------------------------------------
def _remap_texturas(d: object, base: int) -> None:
    """Suma `base` al `index` de cualquier *Texture de un material (y de sus extensiones)."""
    if isinstance(d, dict):
        for k, v in d.items():
            if k.endswith("Texture") and isinstance(v, dict) and "index" in v:
                v["index"] += base
            else:
                _remap_texturas(v, base)
    elif isinstance(d, list):
        for v in d:
            _remap_texturas(v, base)


def anadir(dst: dict, dbin: bytearray, src: dict, sbin: bytes, ident: str, x: float) -> dict:
    """Mete el GLB `src` en `dst` bajo un nodo `ident` con la base en el origen. Devuelve datos de lo que hizo."""
    src = copy.deepcopy(src)
    caja = caja_de(src)
    tris = triangulos(src)              # antes de remapear los indices de los accesores
    # Datos binarios (alineados a 4).
    while len(dbin) % 4:
        dbin.append(0)
    off = len(dbin)
    dbin.extend(sbin)
    bv0, ac0 = len(dst["bufferViews"]), len(dst["accessors"])
    im0, sa0, te0 = len(dst["images"]), len(dst["samplers"]), len(dst["textures"])
    ma0, me0, no0 = len(dst["materials"]), len(dst["meshes"]), len(dst["nodes"])

    for bv in src.get("bufferViews", []):
        bv["buffer"] = 0
        bv["byteOffset"] = bv.get("byteOffset", 0) + off
        dst["bufferViews"].append(bv)
    for a in src.get("accessors", []):
        if "bufferView" in a:
            a["bufferView"] += bv0
        sp = a.get("sparse")
        if sp:
            sp["indices"]["bufferView"] += bv0
            sp["values"]["bufferView"] += bv0
        dst["accessors"].append(a)
    for im in src.get("images", []):
        if "bufferView" in im:
            im["bufferView"] += bv0
        dst["images"].append(im)
    dst["samplers"].extend(src.get("samplers", []))
    for t in src.get("textures", []):
        if "sampler" in t:
            t["sampler"] += sa0
        if "source" in t:
            t["source"] += im0
        for ext in t.get("extensions", {}).values():      # EXT_texture_webp, etc.
            if isinstance(ext, dict) and "source" in ext:
                ext["source"] += im0
        dst["textures"].append(t)
    for m in src.get("materials", []):
        _remap_texturas(m, te0)
        dst["materials"].append(m)
    for me in src.get("meshes", []):
        for pr in me.get("primitives", []):
            pr["attributes"] = {k: v + ac0 for k, v in pr["attributes"].items()}
            if "indices" in pr:
                pr["indices"] += ac0
            if "material" in pr:
                pr["material"] += ma0
            for tg in pr.get("targets", []):
                for k in list(tg):
                    tg[k] += ac0
        dst["meshes"].append(me)
    quitados = 0
    for n in src["nodes"]:
        if "children" in n:
            n["children"] = [c + no0 for c in n["children"]]
        if "mesh" in n:
            n["mesh"] += me0
        if "skin" in n:
            del n["skin"]
            quitados += 1
        if n.get("name") == ident:                      # que ningun otro nodo se llame igual (la maqueta busca por nombre)
            n["name"] = ident + "_malla"
        dst["nodes"].append(n)
    for e in src.get("extensionsUsed", []):
        if e not in dst["extensionsUsed"]:
            dst["extensionsUsed"].append(e)
    for e in src.get("extensionsRequired", []):
        if e not in dst["extensionsRequired"]:
            dst["extensionsRequired"].append(e)

    escena = src.get("scenes", [{}])[src.get("scene", 0)]
    raices = [r + no0 for r in escena.get("nodes", [])]
    cx = cy = cz = 0.0
    tam = [0.0, 0.0, 0.0]
    if caja is not None:
        lo, hi = caja
        cx, cy, cz = (lo[0] + hi[0]) * 0.5, lo[1], (lo[2] + hi[2]) * 0.5       # centro X/Z y suelo
        tam = [hi[k] - lo[k] for k in range(3)]
    dst["nodes"].append({"name": ident + "_modelo", "translation": [-cx, -cy, -cz], "children": raices})
    dst["nodes"].append({"name": ident, "translation": [x, 0.0, 0.0], "children": [len(dst["nodes"]) - 1]})
    return {"nodo": len(dst["nodes"]) - 1, "tam": tam, "tris": tris, "sin_esqueleto": quitados,
            "animaciones": len(src.get("animations", [])), "sin_geometria": caja is None}


def compactar(dst: dict, dbin: bytearray) -> tuple[bytearray, int]:
    """Deduplica las imagenes iguales (mismo hash de bytes = una sola imagen en el GLB, compartida por las piezas de una misma lamina) y tira los bufferViews que ya nadie usa.
    Devuelve (binario nuevo, imagenes que se han fusionado)."""
    imgs = dst.get("images", [])
    vistos: dict[str, int] = {}
    remap: list[int] = []
    nuevas: list[dict] = []
    for im in imgs:
        bv = dst["bufferViews"][im["bufferView"]] if "bufferView" in im else None
        clave = hashlib.sha1(bytes(dbin[bv["byteOffset"]:bv["byteOffset"] + bv["byteLength"]])).hexdigest() if bv else repr(im)
        if clave in vistos:
            remap.append(vistos[clave])
        else:
            vistos[clave] = len(nuevas)
            remap.append(len(nuevas))
            nuevas.append(im)
    fusionadas = len(imgs) - len(nuevas)
    if imgs:
        dst["images"] = nuevas
        for t in dst.get("textures", []):
            if "source" in t:
                t["source"] = remap[t["source"]]
            for ext in t.get("extensions", {}).values():
                if isinstance(ext, dict) and "source" in ext:
                    ext["source"] = remap[ext["source"]]
    usados: set[int] = set()
    for a in dst["accessors"]:
        if "bufferView" in a:
            usados.add(a["bufferView"])
        sp = a.get("sparse")
        if sp:
            usados.add(sp["indices"]["bufferView"])
            usados.add(sp["values"]["bufferView"])
    for im in dst.get("images", []):
        if "bufferView" in im:
            usados.add(im["bufferView"])
    nuevo = bytearray()
    mapa: dict[int, int] = {}
    bvs: list[dict] = []
    for i, bv in enumerate(dst["bufferViews"]):
        if i not in usados:
            continue
        while len(nuevo) % 4:
            nuevo.append(0)
        mapa[i] = len(bvs)
        datos = bytes(dbin[bv["byteOffset"]:bv["byteOffset"] + bv["byteLength"]])
        bv = dict(bv)
        bv["byteOffset"] = len(nuevo)
        nuevo.extend(datos)
        bvs.append(bv)
    dst["bufferViews"] = bvs
    for a in dst["accessors"]:
        if "bufferView" in a:
            a["bufferView"] = mapa[a["bufferView"]]
        sp = a.get("sparse")
        if sp:
            sp["indices"]["bufferView"] = mapa[sp["indices"]["bufferView"]]
            sp["values"]["bufferView"] = mapa[sp["values"]["bufferView"]]
    for im in dst.get("images", []):
        if "bufferView" in im:
            im["bufferView"] = mapa[im["bufferView"]]
    return nuevo, fusionadas

# ------------------------------------------------------------------- lista ----------------------------------------------------------
def leer_tsv(ruta: Path, bioma: str) -> list[dict]:
    """Filas del bioma de assets_biomas.tsv (cabecera: bioma pack id accion familia descripcion medida tris_objetivo prioridad prompt nota)."""
    filas: list[dict] = []
    lineas = ruta.read_text(encoding="utf-8-sig").splitlines()
    cab = lineas[0].split("\t")
    for l in lineas[1:]:
        c = l.split("\t")
        if len(c) < len(cab):
            c += [""] * (len(cab) - len(c))
        f = dict(zip(cab, c))
        if f.get("bioma") == bioma:
            filas.append(f)
    return filas


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description="Monta arte/meshy/packs/pack_<bioma>.glb con las piezas del bioma que hay en entrada/.")
    ap.add_argument("bioma", nargs="?", default="pantano")
    ap.add_argument("--entrada", type=Path, default=ENTRADA)
    ap.add_argument("--salida", type=Path, default=PACKS)
    ap.add_argument("--tsv", type=Path, default=None)
    ap.add_argument("--separacion", type=float, default=0.0, help="separacion en X entre piezas (0 = automatica, segun su ancho)")
    a = ap.parse_args()

    tsv = a.tsv or next((t for t in TSV_CANDIDATOS if t.is_file()), None)
    filas = leer_tsv(tsv, a.bioma) if tsv else []
    if tsv:
        print(f"Lista del bioma «{a.bioma}»: {tsv} ({len(filas)} filas)")
    else:
        print("AVISO: no encuentro docs/assets_biomas.tsv ni packs/assets_biomas.tsv: no se puede decir que ids faltan.")
    del_bioma = {f["id"]: f for f in filas}
    a_conseguir = [f for f in filas if f.get("accion") == "conseguir"]

    if not a.entrada.is_dir():
        print(f"No existe {a.entrada}")
        return 1
    glbs = sorted(x for x in a.entrada.glob("*.glb") if x.is_file())
    propios = [(id_de(p), p) for p in glbs if not filas or id_de(p) in del_bioma]
    ajenos = [id_de(p) for p in glbs if filas and id_de(p) not in del_bioma]

    dst: dict = {"asset": {"version": "2.0", "generator": "montar_pack_bioma.py"}, "scene": 0, "scenes": [{"name": f"pack_{a.bioma}", "nodes": []}],
                 "nodes": [], "meshes": [], "materials": [], "textures": [], "images": [], "samplers": [], "accessors": [], "bufferViews": [],
                 "buffers": [{"byteLength": 0}], "extensionsUsed": [], "extensionsRequired": []}
    dbin = bytearray()
    puestas: list[str] = []
    x = 0.0
    for ident, p in propios:
        try:
            j, b = leer_glb(p)
            r = anadir(dst, dbin, j, b, ident, x)
        except Exception as e:  # noqa: BLE001
            print(f"  ERROR en {p.name}: {e}")
            continue
        dst["scenes"][0]["nodes"].append(r["nodo"])
        puestas.append(ident)
        ancho = max(r["tam"][0], r["tam"][2])
        x += a.separacion if a.separacion > 0 else max(1.0, ancho) * 1.3 + 0.5
        extra = []
        if r["tris"] > MAX_TRIS:
            extra.append(f"AVISO: pasa de {MAX_TRIS} triangulos")
        if r["sin_geometria"]:
            extra.append("AVISO: sin geometria")
        if r["animaciones"]:
            extra.append(f"{r['animaciones']} animaciones quitadas")
        if r["sin_esqueleto"]:
            extra.append("esqueleto quitado")
        print(f"  + {ident:<20} {r['tris']:>6} tris  caja {r['tam'][0]:.2f} x {r['tam'][1]:.2f} x {r['tam'][2]:.2f}  {'; '.join(extra)}")

    destino = a.salida / f"pack_{a.bioma}.glb"
    if puestas:
        a.salida.mkdir(parents=True, exist_ok=True)
        dbin, fusionadas = compactar(dst, dbin)
        print(f"\nTexturas: {fusionadas} imagen(es) repetida(s) fusionada(s) (una imagen por lamina de origen)")
        for k in ("samplers", "images", "textures", "materials", "meshes", "extensionsUsed", "extensionsRequired"):
            if not dst[k]:
                del dst[k]
        dst["buffers"][0]["byteLength"] = len(dbin) + (4 - len(dbin) % 4) % 4
        escribir_glb(destino, dst, bytes(dbin))
        print(f"\nPack: {destino}  ({len(puestas)} piezas, {destino.stat().st_size // 1024} KB)")
    else:
        print("\nNo hay piezas del bioma en entrada/: no se escribe pack" + (" (el que hubiera se queda como esta)." if destino.exists() else "."))

    if filas:
        faltan = [f for f in a_conseguir if f["id"] not in puestas]
        if faltan:
            print(f"\nFALTAN {len(faltan)} de {len(a_conseguir)} piezas por conseguir de «{a.bioma}» (prioridad 1 primero):")
            for f in sorted(faltan, key=lambda f: (f.get("prioridad", "9"), f["id"])):
                print(f"   P{f.get('prioridad', '?')}  {f['id']:<20} {f.get('medida', ''):<14} {f.get('descripcion', '')}")
        else:
            print(f"\nEstan todas las piezas por conseguir de «{a.bioma}».")
        reutil = [f["id"] for f in filas if f.get("accion") == "reutilizar" and f["id"] in puestas]
        if reutil:
            print(f"(en el pack hay ademas piezas marcadas «reutilizar»: {', '.join(reutil)})")
    if ajenos:
        print(f"\nIgnorados (no son del bioma «{a.bioma}»): {len(ajenos)} GLB" + (f" ({', '.join(ajenos[:6])}{', ...' if len(ajenos) > 6 else ''})" if ajenos else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
