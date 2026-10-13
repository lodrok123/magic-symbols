#!/usr/bin/env python3
"""Separa un GLB de Meshy hecho a partir de la LÁMINA (13 piezas en un solo modelo) en un GLB por pieza.

    python separar_lamina.py <lamina.glb> <carpeta_salida> [--lamina referencias/_lamina.png] [--biblioteca]
                             [--ids id1,id2,...] [--nombre bosque]

--ids: nombres de las piezas en orden de lectura de la lámina (filas de arriba abajo, cada fila de izquierda a
derecha). Por defecto, las 13 de la lámina 1. --nombre: nombre del GLB de biblioteca (por defecto "bosque").

Con --biblioteca escribe UN solo GLB (<carpeta_salida>/bosque.glb) con las 13 piezas como objetos separados
que se llaman como su id y comparten material y texturas (lo normal cuando Meshy texturiza la lámina entera:
la textura es un atlas único, y separarla en 13 archivos la copiaría 13 veces). Cada objeto tiene su origen en
el centro de su base. Sin --biblioteca, un GLB por pieza.
En los dos casos se quita el mapa de metal/rugosidad y se pone metal 0 (Meshy deja metal 1,0, que sin
reflejos se ve oscuro).

Cómo decide qué triángulo es de qué pieza: parte la malla en trozos conectados, proyecta el centro de cada trozo
sobre el plano de la lámina (los dos ejes más largos del modelo) y lo asigna a la pieza de la lámina cuya caja
lo contiene (o la más cercana). Las cajas salen de la propia imagen de la lámina, en el orden de IDS.
Cada GLB de salida conserva atributos (normales, UV, colores), material y texturas del original.
Necesita numpy y scipy (se ejecuta en el entorno de Claude, no en el PC).
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

IDS = ["arbol_redondo", "pino", "arbusto", "arbusto_flores", "matas", "flores", "roca_grande", "piedras",
       "tocon", "tronco", "setas", "valla", "cartel"]
COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def leer_glb(ruta):
    b = Path(ruta).read_bytes()
    assert b[:4] == b"glTF", "no es un GLB"
    l = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + l])
    p = 20 + l
    binario = b""
    if p < len(b):
        lb = struct.unpack("<I", b[p:p + 4])[0]
        binario = b[p + 8:p + 8 + lb]
    return j, binario


def accesor(j, binario, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    n = NCOMP[a["type"]]
    dt = np.dtype(COMP[a["componentType"]])
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    paso = bv.get("byteStride", 0)
    if paso and paso != n * dt.itemsize:
        filas = [np.frombuffer(binario, dtype=dt, count=n, offset=off + k * paso) for k in range(a["count"])]
        datos = np.array(filas)
    else:
        datos = np.frombuffer(binario, dtype=dt, count=a["count"] * n, offset=off).reshape(a["count"], n)
    if a.get("normalized") and dt != np.float32:
        datos = datos.astype(np.float32) / np.iinfo(dt).max
    return datos.astype(np.float32) if dt == np.float32 else datos


def matriz_nodo(n):
    if "matrix" in n:
        return np.array(n["matrix"], dtype=np.float64).reshape(4, 4).T
    m = np.eye(4)
    if "scale" in n:
        m = m @ np.diag(list(n["scale"]) + [1.0])
    if "rotation" in n:
        x, y, z, w = n["rotation"]
        r = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                      [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                      [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
        rm = np.eye(4)
        rm[:3, :3] = r
        m = rm @ m
    if "translation" in n:
        t = np.eye(4)
        t[:3, 3] = n["translation"]
        m = t @ m
    return m


def cajas_lamina(ruta, ids):
    a = np.array(Image.open(ruta).convert("RGB")).astype(int)
    fondo = (a.min(axis=2) > 238) & ((a.max(axis=2) - a.min(axis=2)) < 12)
    obj = ndimage.binary_fill_holes(ndimage.binary_closing(~fondo, iterations=4))
    lab, _ = ndimage.label(obj)
    cajas = []
    minimo = obj.size * 0.0015
    for i, s in enumerate(ndimage.find_objects(lab)):
        if (lab[s] == i + 1).sum() > minimo:
            cajas.append((s[1].start, s[0].start, s[1].stop, s[0].stop))  # x0, y0, x1, y1
    # Orden de lectura: se agrupan en filas las cajas cuyo centro cae dentro de la franja de la fila.
    cajas.sort(key=lambda c: (c[1] + c[3]) / 2)
    filas = []
    for c in cajas:
        cy = (c[1] + c[3]) / 2
        if filas and filas[-1]["y0"] <= cy <= filas[-1]["y1"]:
            filas[-1]["cajas"].append(c)
            filas[-1]["y0"] = min(filas[-1]["y0"], c[1])
            filas[-1]["y1"] = max(filas[-1]["y1"], c[3])
        else:
            filas.append({"y0": c[1], "y1": c[3], "cajas": [c]})
    ordenadas = [c for f in filas for c in sorted(f["cajas"], key=lambda c: c[0])]
    assert len(ordenadas) == len(ids), f"la lámina tiene {len(ordenadas)} piezas y se dieron {len(ids)} ids"
    return np.array(ordenadas, dtype=np.float64)


def separar(ruta_glb, salida, ruta_lamina, biblioteca=False, ids=None, nombre="bosque"):
    ids = ids or IDS
    j, binario = leer_glb(ruta_glb)
    cajas = cajas_lamina(ruta_lamina, ids)
    # Todas las primitivas con su transformación de mundo (solo para decidir a qué pieza va cada triángulo).
    prims = []

    def recorrer(ni, padre):
        n = j["nodes"][ni]
        m = padre @ matriz_nodo(n)
        if "mesh" in n:
            for pi, p in enumerate(j["meshes"][n["mesh"]]["primitives"]):
                prims.append((n["mesh"], pi, p, m))
        for h in n.get("children", []):
            recorrer(h, m)
    escena = j["scenes"][j.get("scene", 0)]
    for ni in escena["nodes"]:
        recorrer(ni, np.eye(4))

    trozos = []   # (prim_idx, array de triángulos, centro en mundo)
    todos = []
    for k, (mi, pi, p, m) in enumerate(prims):
        pos = accesor(j, binario, p["attributes"]["POSITION"]).astype(np.float64)
        mundo = (np.c_[pos, np.ones(len(pos))] @ m.T)[:, :3]
        idx = accesor(j, binario, p["indices"]).reshape(-1, 3).astype(np.int64) if "indices" in p else \
            np.arange(len(pos)).reshape(-1, 3)
        # Trozos conectados: dos vértices están unidos si comparten triángulo. Se sueldan por posición para
        # que las costuras de UV no partan una pieza en cien trozos.
        _, unico = np.unique(np.round(pos, 5), axis=0, return_inverse=True)
        unico = unico.reshape(-1)
        t = unico[idx]
        filas = np.r_[t[:, 0], t[:, 1], t[:, 2]]
        cols = np.r_[t[:, 1], t[:, 2], t[:, 0]]
        nv = unico.max() + 1
        g = coo_matrix((np.ones(len(filas)), (filas, cols)), shape=(nv, nv))
        _, etiqueta = connected_components(g, directed=False)
        et_tri = etiqueta[t[:, 0]]
        for e in np.unique(et_tri):
            tris = np.where(et_tri == e)[0]
            centro = mundo[idx[tris].reshape(-1)].mean(axis=0)
            trozos.append((k, tris, centro))
        todos.append(mundo)
    todo = np.vstack(todos)
    lo, hi = todo.min(axis=0), todo.max(axis=0)
    ext = hi - lo
    eje_h, eje_v = np.argsort(ext)[::-1][:2]
    if eje_h == 1:     # si el eje más largo es Y, la lámina está de pie al revés: Y es la vertical
        eje_h, eje_v = eje_v, eje_h
    x0, y0 = cajas[:, 0].min(), cajas[:, 1].min()
    x1, y1 = cajas[:, 2].max(), cajas[:, 3].max()

    def a_lamina(c, voltear_h):
        u = (c[eje_h] - lo[eje_h]) / ext[eje_h]
        if voltear_h:
            u = 1.0 - u
        v = (hi[eje_v] - c[eje_v]) / ext[eje_v]
        return np.array([x0 + u * (x1 - x0), y0 + v * (y1 - y0)])

    def asignar(voltear_h):
        res = []
        for (_, tris, centro) in trozos:
            q = a_lamina(centro, voltear_h)
            dx = np.maximum(np.maximum(cajas[:, 0] - q[0], 0), q[0] - cajas[:, 2])
            dy = np.maximum(np.maximum(cajas[:, 1] - q[1], 0), q[1] - cajas[:, 3])
            res.append(int(np.argmin(dx * dx + dy * dy)))
        return res
    # Se prueba con y sin espejo horizontal y se queda la que deja todas las piezas con algo de malla.
    mejor = None
    for voltear in (False, True):
        r = asignar(voltear)
        llenas = len(set(r))
        if mejor is None or llenas > mejor[0]:
            mejor = (llenas, r, voltear)
    asignacion = mejor[1]
    print(f"  ejes lámina: horizontal={'XYZ'[eje_h]} vertical={'XYZ'[eje_v]} espejo={mejor[2]}  piezas con malla: {mejor[0]}/{len(ids)}")

    salida = Path(salida)
    salida.mkdir(parents=True, exist_ok=True)
    grupos = []
    for pieza, id_ in enumerate(ids):
        sel = {}
        for (k, tris, _), a in zip(trozos, asignacion):
            if a == pieza:
                sel.setdefault(k, []).append(tris)
        grupos.append((id_, sel))
    informe = []
    if biblioteca:
        ruta = salida / f"{nombre}.glb"
        cuentas = escribir_glb(j, binario, prims, [(i, s_) for i, s_ in grupos if s_], ruta)
        for id_, _ in grupos:
            informe.append((id_, cuentas.get(id_, 0)))
        print(f"  biblioteca: {ruta}  {ruta.stat().st_size / 1e6:.2f} MB")
        for id_, n in informe:
            print(f"  {id_:16s} {n:7d} triángulos" if n else f"  {id_:16s}  (vacía)")
        return informe
    for id_, sel in grupos:
        if not sel:
            print(f"  {id_:16s}  (vacía)")
            continue
        ruta = salida / f"{id_}.glb"
        n = escribir_glb(j, binario, prims, [(id_, sel)], ruta)[id_]
        print(f"  {id_:16s} {n:7d} triángulos  {ruta.stat().st_size / 1e6:6.2f} MB")
        informe.append((id_, n))
    return informe


def escribir_glb(j, binario, prims, piezas, ruta):
    """Un GLB con una o varias piezas [(id, {prim: [triángulos]})]: un nodo con nombre por pieza, con su origen en el
    centro de su base, y material y texturas compartidos."""
    nuevo = {"asset": {"version": "2.0", "generator": "separar_lamina.py"}, "buffers": [], "bufferViews": [],
             "accessors": [], "meshes": [], "nodes": [], "scenes": [{"nodes": []}], "scene": 0}
    bloques = []
    largo = 0

    def meter(datos, destino=None):
        nonlocal largo
        crudo = datos.tobytes() if isinstance(datos, np.ndarray) else datos
        relleno = (-largo) % 4
        if relleno:
            bloques.append(b"\0" * relleno)
            largo += relleno
        bv = {"buffer": 0, "byteOffset": largo, "byteLength": len(crudo)}
        if destino:
            bv["target"] = destino
        bloques.append(crudo)
        largo += len(crudo)
        nuevo["bufferViews"].append(bv)
        return len(nuevo["bufferViews"]) - 1

    mapa_mat = {}
    mapa_tex = {}
    mapa_img = {}

    def copiar_imagen(ii):
        if ii in mapa_img:
            return mapa_img[ii]
        im = dict(j["images"][ii])
        if "bufferView" in im:
            bv = j["bufferViews"][im["bufferView"]]
            off = bv.get("byteOffset", 0)
            im["bufferView"] = meter(binario[off:off + bv["byteLength"]])
        nuevo.setdefault("images", []).append(im)
        mapa_img[ii] = len(nuevo["images"]) - 1
        return mapa_img[ii]

    def copiar_textura(ti):
        if ti in mapa_tex:
            return mapa_tex[ti]
        t = dict(j["textures"][ti])
        if "source" in t:
            t["source"] = copiar_imagen(t["source"])
        if "sampler" in t:
            nuevo.setdefault("samplers", []).append(j["samplers"][t["sampler"]])
            t["sampler"] = len(nuevo["samplers"]) - 1
        nuevo.setdefault("textures", []).append(t)
        mapa_tex[ti] = len(nuevo["textures"]) - 1
        return mapa_tex[ti]

    def copiar_material(mi):
        if mi in mapa_mat:
            return mapa_mat[mi]
        m = json.loads(json.dumps(j["materials"][mi]))
        pbr = m.setdefault("pbrMetallicRoughness", {})
        pbr.pop("metallicRoughnessTexture", None)
        pbr["metallicFactor"] = 0.0
        pbr["roughnessFactor"] = 1.0

        def arreglar(d):
            for clave, val in list(d.items()):
                if isinstance(val, dict):
                    if "index" in val and clave.endswith("Texture"):
                        val["index"] = copiar_textura(val["index"])
                    arreglar(val)
        arreglar(m)
        nuevo.setdefault("materials", []).append(m)
        mapa_mat[mi] = len(nuevo["materials"]) - 1
        return mapa_mat[mi]

    cuentas = {}
    for id_, sel in piezas:
        # Centro de la base de la pieza (en el espacio del modelo), para usarlo de origen del nodo.
        todas = []
        for k, listas in sel.items():
            _, _, p, m = prims[k]
            idx = accesor(j, binario, p["indices"]).reshape(-1, 3).astype(np.int64) if "indices" in p else \
                np.arange(j["accessors"][p["attributes"]["POSITION"]]["count"]).reshape(-1, 3)
            pos = accesor(j, binario, p["attributes"]["POSITION"]).astype(np.float64)
            usados_k = np.unique(idx[np.concatenate(listas)].reshape(-1))
            todas.append((np.c_[pos[usados_k], np.ones(len(usados_k))] @ m.T)[:, :3])
        todas = np.vstack(todas)
        lo, hi = todas.min(axis=0), todas.max(axis=0)
        base = np.array([(lo[0] + hi[0]) * 0.5, lo[1], (lo[2] + hi[2]) * 0.5])
        malla = {"name": id_, "primitives": []}
        total = 0
        for k, listas in sel.items():
            _, _, p, m = prims[k]
            tris = np.concatenate(listas)
            idx = accesor(j, binario, p["indices"]).reshape(-1, 3).astype(np.int64) if "indices" in p else \
                np.arange(j["accessors"][p["attributes"]["POSITION"]]["count"]).reshape(-1, 3)
            sub = idx[tris]
            usados, nuevos = np.unique(sub.reshape(-1), return_inverse=True)
            prim = {"attributes": {}}
            for nombre, ai in p["attributes"].items():
                a = j["accessors"][ai]
                datos = accesor(j, binario, ai)[usados]
                datos = np.ascontiguousarray(datos.astype(COMP[a["componentType"]]))
                extra = {}
                if nombre == "POSITION":
                    mundo = (np.c_[datos.astype(np.float64), np.ones(len(datos))] @ m.T)[:, :3] - base
                    datos = np.ascontiguousarray(mundo.astype(np.float32))
                    extra = {"min": datos.min(axis=0).tolist(), "max": datos.max(axis=0).tolist()}
                elif nombre == "NORMAL":
                    n3 = datos.astype(np.float64) @ m[:3, :3].T
                    n3 /= np.maximum(np.linalg.norm(n3, axis=1, keepdims=True), 1e-9)
                    datos = np.ascontiguousarray(n3.astype(np.float32))
                acc = {"bufferView": meter(datos, 34962), "componentType": a["componentType"],
                       "count": int(len(datos)), "type": a["type"]}
                acc.update(extra)
                if a.get("normalized"):
                    acc["normalized"] = True
                nuevo["accessors"].append(acc)
                prim["attributes"][nombre] = len(nuevo["accessors"]) - 1
            ind = np.ascontiguousarray(nuevos.astype(np.uint32))
            nuevo["accessors"].append({"bufferView": meter(ind, 34963), "componentType": 5125,
                                       "count": int(len(ind)), "type": "SCALAR"})
            prim["indices"] = len(nuevo["accessors"]) - 1
            if "material" in p:
                prim["material"] = copiar_material(p["material"])
            malla["primitives"].append(prim)
            total += len(tris)
        nuevo["meshes"].append(malla)
        nuevo["nodes"].append({"name": id_, "mesh": len(nuevo["meshes"]) - 1,
                               "translation": base.tolist() if len(piezas) > 1 else [0.0, 0.0, 0.0]})
        nuevo["scenes"][0]["nodes"].append(len(nuevo["nodes"]) - 1)
        cuentas[id_] = total
    cuerpo = b"".join(bloques)
    cuerpo += b"\0" * ((-len(cuerpo)) % 4)
    nuevo["buffers"].append({"byteLength": len(cuerpo)})
    js = json.dumps(nuevo, separators=(",", ":")).encode()
    js += b" " * ((-len(js)) % 4)
    glb = b"glTF" + struct.pack("<II", 2, 12 + 8 + len(js) + 8 + len(cuerpo))
    glb += struct.pack("<I", len(js)) + b"JSON" + js + struct.pack("<I", len(cuerpo)) + b"BIN\0" + cuerpo
    Path(ruta).write_bytes(glb)
    return cuentas


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    lam = sys.argv[sys.argv.index("--lamina") + 1] if "--lamina" in sys.argv else str(Path(__file__).parent / "referencias" / "_lamina.png")
    ids = sys.argv[sys.argv.index("--ids") + 1].split(",") if "--ids" in sys.argv else None
    nombre = sys.argv[sys.argv.index("--nombre") + 1] if "--nombre" in sys.argv else "bosque"
    separar(sys.argv[1], sys.argv[2], lam, "--biblioteca" in sys.argv, ids, nombre)
