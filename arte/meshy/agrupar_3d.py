#!/usr/bin/env python3
"""Separa un GLB de Meshy con varias piezas SIN usar la imagen de la lámina: agrupa en 3D los trozos de malla
que se tocan o se solapan. Sirve cuando las piezas están en varias filas y se tapan vistas de frente.

    python agrupar_3d.py <entrada.glb> <carpeta> --ver           -> grupos numerados y una hoja de miniaturas
    python agrupar_3d.py <entrada.glb> <carpeta> --nombres 0=arco,3=puesto,... --nombre objetos
          -> <carpeta>/<nombre>.glb con un objeto por grupo nombrado (los grupos sin nombre se descartan)
"""
import io
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

sys.path.insert(0, str(Path(__file__).parent))
from separar_lamina import leer_glb, accesor, matriz_nodo, escribir_glb  # noqa: E402


def trozos_de(j, binario):
    prims = []

    def recorrer(ni, padre):
        n = j["nodes"][ni]
        m = padre @ matriz_nodo(n)
        if "mesh" in n:
            for pi, p in enumerate(j["meshes"][n["mesh"]]["primitives"]):
                prims.append((n["mesh"], pi, p, m))
        for h in n.get("children", []):
            recorrer(h, m)
    for ni in j["scenes"][j.get("scene", 0)]["nodes"]:
        recorrer(ni, np.eye(4))
    trozos = []
    for k, (_, _, p, m) in enumerate(prims):
        pos = accesor(j, binario, p["attributes"]["POSITION"]).astype(np.float64)
        mundo = (np.c_[pos, np.ones(len(pos))] @ m.T)[:, :3]
        idx = accesor(j, binario, p["indices"]).reshape(-1, 3).astype(np.int64)
        _, unico = np.unique(np.round(pos, 5), axis=0, return_inverse=True)
        unico = unico.reshape(-1)
        t = unico[idx]
        nv = unico.max() + 1
        g = coo_matrix((np.ones(len(t) * 3), (np.r_[t[:, 0], t[:, 1], t[:, 2]], np.r_[t[:, 1], t[:, 2], t[:, 0]])),
                       shape=(nv, nv))
        _, et = connected_components(g, directed=False)
        et_tri = et[t[:, 0]]
        for e in np.unique(et_tri):
            tris = np.where(et_tri == e)[0]
            pts = mundo[idx[tris].reshape(-1)]
            trozos.append({"k": k, "tris": tris, "lo": pts.min(0), "hi": pts.max(0)})
    return prims, trozos


def agrupar(trozos, holgura):
    n = len(trozos)
    padre = list(range(n))

    def raiz(a):
        while padre[a] != a:
            padre[a] = padre[padre[a]]
            a = padre[a]
        return a
    lo = np.array([t["lo"] for t in trozos])
    hi = np.array([t["hi"] for t in trozos])
    for a in range(n):
        toca = np.all((lo[a] - holgura <= hi) & (lo <= hi[a] + holgura), axis=1)
        for b in np.where(toca)[0]:
            if b > a:
                padre[raiz(b)] = raiz(a)
    grupos = {}
    for i in range(n):
        grupos.setdefault(raiz(i), []).append(i)
    lista = sorted(grupos.values(), key=lambda g: -sum(len(trozos[i]["tris"]) for i in g))
    return lista


def miniaturas(j, binario, prims, trozos, grupos, ruta):
    tex = None
    try:
        mat = j["materials"][prims[0][2]["material"]]
        ti = mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]
        bv = j["bufferViews"][j["images"][j["textures"][ti]["source"]]["bufferView"]]
        o = bv.get("byteOffset", 0)
        tex = np.array(Image.open(io.BytesIO(binario[o:o + bv["byteLength"]])).convert("RGB"))
    except (KeyError, IndexError):
        pass
    cols = 6
    filas = (len(grupos) + cols - 1) // cols
    hoja = Image.new("RGB", (cols * 210, filas * 230), (40, 40, 46))
    d = ImageDraw.Draw(hoja)
    for gi, g in enumerate(grupos):
        tris_all = []
        for i in g:
            t = trozos[i]
            _, _, p, m = prims[t["k"]]
            pos = accesor(j, binario, p["attributes"]["POSITION"]).astype(np.float64)
            mundo = (np.c_[pos, np.ones(len(pos))] @ m.T)[:, :3]
            uv = accesor(j, binario, p["attributes"]["TEXCOORD_0"]) if "TEXCOORD_0" in p["attributes"] else None
            idx = accesor(j, binario, p["indices"]).reshape(-1, 3)[t["tris"]]
            for tri in idx:
                col = (180, 180, 180)
                if tex is not None and uv is not None:
                    u = uv[tri].mean(0)
                    h, w = tex.shape[:2]
                    col = tuple(int(c) for c in tex[min(h - 1, max(0, int(u[1] * h))), min(w - 1, max(0, int(u[0] * w)))])
                tris_all.append((mundo[tri], col))
        pts = np.vstack([a for a, _ in tris_all])
        lo, hi = pts.min(0), pts.max(0)
        esc = 180 / max(hi[0] - lo[0], hi[1] - lo[1], 1e-6)
        ox, oy = (gi % cols) * 210 + 15, (gi // cols) * 230 + 15
        for tri, col in sorted(tris_all, key=lambda x: x[0][:, 2].mean()):
            d.polygon([(ox + (v[0] - lo[0]) * esc, oy + (hi[1] - v[1]) * esc) for v in tri], fill=col)
        ntri = sum(len(trozos[i]["tris"]) for i in g)
        c = (lo + hi) / 2
        d.text((ox, (gi // cols) * 230 + 200), f"#{gi} {ntri}t x{c[0]:+.2f} z{c[2]:+.2f}", fill=(255, 255, 0))
    hoja.save(ruta)


if __name__ == "__main__":
    entrada, salida = sys.argv[1], Path(sys.argv[2])
    salida.mkdir(parents=True, exist_ok=True)
    holgura = float(sys.argv[sys.argv.index("--holgura") + 1]) if "--holgura" in sys.argv else 0.004
    j, binario = leer_glb(entrada)
    prims, trozos = trozos_de(j, binario)
    grupos = agrupar(trozos, holgura)
    # --partir G:N[,G:N]: parte el grupo G en N piezas por la posición X de sus trozos (para piezas cuyas bases se tocan)
    if "--partir" in sys.argv:
        nuevos = []
        partes = dict((int(a), int(b)) for a, b in (x.split(":") for x in sys.argv[sys.argv.index("--partir") + 1].split(",")))
        for gi, g in enumerate(grupos):
            if gi not in partes:
                nuevos.append(g)
                continue
            n = partes[gi]
            xs = np.array([(trozos[i]["lo"][0] + trozos[i]["hi"][0]) / 2 for i in g])
            pesos = np.array([len(trozos[i]["tris"]) for i in g], dtype=float)
            centros = np.quantile(xs, np.linspace(0.1, 0.9, n))
            for _ in range(30):
                asig = np.argmin(np.abs(xs[:, None] - centros[None, :]), axis=1)
                for c in range(n):
                    if (asig == c).any():
                        centros[c] = np.average(xs[asig == c], weights=pesos[asig == c])
            for c in np.argsort(centros):
                nuevos.append([g[i] for i in range(len(g)) if asig[i] == c])
        grupos = nuevos
    print(f"{len(trozos)} trozos -> {len(grupos)} grupos")
    if "--ver" in sys.argv:
        miniaturas(j, binario, prims, trozos, grupos, salida / "grupos.png")
        for gi, g in enumerate(grupos):
            print(f"  #{gi}: {sum(len(trozos[i]['tris']) for i in g)} triángulos")
    if "--nombres" in sys.argv:
        pares = dict(p.split("=") for p in sys.argv[sys.argv.index("--nombres") + 1].split(","))
        nombre = sys.argv[sys.argv.index("--nombre") + 1] if "--nombre" in sys.argv else "biblioteca"
        piezas = []
        por_nombre = {}
        for gi_txt, id_ in pares.items():
            for gi in gi_txt.split("+"):
                por_nombre.setdefault(id_, []).extend(grupos[int(gi)])
        for id_, miembros in por_nombre.items():
            sel = {}
            for i in miembros:
                sel.setdefault(trozos[i]["k"], []).append(trozos[i]["tris"])
            piezas.append((id_, sel))
        ruta = salida / f"{nombre}.glb"
        cuentas = escribir_glb(j, binario, prims, piezas, ruta)
        print(f"  {ruta}  {ruta.stat().st_size / 1e6:.2f} MB  {cuentas}")
