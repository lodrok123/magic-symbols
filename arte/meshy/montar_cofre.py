"""MONTAR UN COFRE QUE SE ABRE a partir de una hoja de Tripo con el cuerpo y la tapa como trozos aparte (23/10, hoja D2 de la Cueva).

Por qué existe: `recibir_assets.py lote` centra CADA trozo en su base, así que la tapa pierde su sitio sobre el cuerpo y su bisagra. El cofre animado
(`presentacion/cofre_3d.gd`) busca dos nodos, `cofre_cuerpo` y `cofre_tapa`, hermanos bajo la raíz de la pieza, con el origen de la tapa EN LA BISAGRA
(eje X, borde de atrás = -Z; abre girando -105° sobre X, así que el frente del cofre es +Z). Este script hace ese montaje:

  1. reduce el cuerpo y la tapa por separado (mismo Reductor que `lote`), cada uno a sus triángulos;
  2. baja la tapa a la pose CERRADA (su base apoyada en el borde del cuerpo; la hoja las trae separadas en vertical);
  3. escribe UN .glb con la raíz `<id>` y dos hijos: `cofre_cuerpo` (origen = centro de la base, base en y = 0) y `cofre_tapa` (nodo trasladado a la
     bisagra, malla relativa a ella); las dos mallas comparten material y textura (recortada a la caja de UV de ambas);
  4. escribe además la tapa suelta `<id>_tapa.glb` (centrada en su base, como las demás piezas), disponible por id.

Uso:  python montar_cofre.py entrada/cueva_recompensas.glb cofre_legendario 3 4 1800 900
                                                         hoja            id    cuerpo tapa tris_cuerpo tris_tapa
(`cuerpo` y `tapa` son los números de trozo que enseña `recibir_assets.py ver`). Deja los .glb en `piezas/` directamente (es lo que Pablo ordenó
sustituir: la tapa y el cuerpo no se ven por separado antes de instalarlos).
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
import recibir_assets as ra  # noqa: E402

BISAGRA_ATRAS = 1.0     # la bisagra va en el borde de atrás (menor z) de la tapa


def _reducir(h, caras, tris):
    Pw, Fw, UVc = ra.malla_soldada(h, caras)
    r = ra.Reductor(Pw, Fw, UVc)
    r.reducir_a(tris)
    P, F, UV = r.resultado()
    pos, nor, uv, idx = ra.normales_y_vertices(P, F, UV)
    return pos, nor, uv, idx


def _glb(ruta, ident, mallas, nodos, base, normal):
    """mallas: [(nombre, pos, nor, uv, idx)], nodos: [(nombre, indice_malla, traslacion|None)] hijos de la raíz `ident`."""
    trozos, vistas, accesores = [], [], []

    def anadir(data, target=None):
        pad = (4 - len(data) % 4) % 4
        o = sum(len(x) for x in trozos)
        trozos.append(data + b"\0" * pad)
        v = {"buffer": 0, "byteOffset": o, "byteLength": len(data)}
        if target:
            v["target"] = target
        vistas.append(v)
        return len(vistas) - 1

    js_mallas = []
    for nombre, pos, nor, uv, idx in mallas:
        pos, nor, uv = pos.astype(np.float32), nor.astype(np.float32), uv.astype(np.float32)
        flat = idx.reshape(-1)
        t = np.uint16 if int(flat.max()) < 65535 else np.uint32
        flat = flat.astype(t)
        a0 = len(accesores)
        for arr, tipo in ((pos, "VEC3"), (nor, "VEC3"), (uv, "VEC2")):
            a = {"bufferView": anadir(arr.tobytes(), 34962), "componentType": 5126, "count": len(arr), "type": tipo}
            if arr is pos:
                a["min"], a["max"] = pos.min(0).tolist(), pos.max(0).tolist()
            accesores.append(a)
        accesores.append({"bufferView": anadir(flat.tobytes(), 34963), "componentType": 5123 if t == np.uint16 else 5125,
                          "count": int(len(flat)), "type": "SCALAR"})
        js_mallas.append({"name": nombre, "primitives": [{"attributes": {"POSITION": a0, "NORMAL": a0 + 1, "TEXCOORD_0": a0 + 2},
                                                          "indices": a0 + 3, "material": 0}]})
    pbr = {"metallicFactor": 0.0, "roughnessFactor": 0.85}
    material = {"name": ident, "doubleSided": True, "pbrMetallicRoughness": pbr}
    imagenes, texturas = [], []
    if base is not None:
        imagenes.append({"bufferView": anadir(ra._jpeg(base)), "mimeType": "image/jpeg"})
        texturas.append({"source": len(imagenes) - 1})
        pbr["baseColorTexture"] = {"index": len(texturas) - 1}
    if normal is not None:
        imagenes.append({"bufferView": anadir(ra._jpeg(normal)), "mimeType": "image/jpeg"})
        texturas.append({"source": len(imagenes) - 1})
        material["normalTexture"] = {"index": len(texturas) - 1}
    js_nodos = [{"name": ident, "children": list(range(1, len(nodos) + 1))}]
    for nombre, im, tr in nodos:
        n = {"name": nombre, "mesh": im}
        if tr is not None:
            n["translation"] = [float(x) for x in tr]
        js_nodos.append(n)
    j = {"asset": {"version": "2.0", "generator": "montar_cofre.py"}, "scene": 0, "scenes": [{"nodes": [0]}], "nodes": js_nodos,
         "meshes": js_mallas, "accessors": accesores, "bufferViews": vistas, "materials": [material]}
    if imagenes:
        j["images"], j["textures"] = imagenes, texturas
    binario = b"".join(trozos)
    j["buffers"] = [{"byteLength": len(binario)}]
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(binario)
    Path(ruta).write_bytes(struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js
                           + struct.pack("<II", len(binario), 0x004E4942) + binario)


def main():
    hoja, ident, i_cuerpo, i_tapa, t_cuerpo, t_tapa = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6])
    h = ra.Hoja(Path(hoja))
    trozos = ra.trozos_de(h)
    zc, zt = trozos[i_cuerpo], trozos[i_tapa]
    pc, nc, uc, ic = _reducir(h, zc["caras"], t_cuerpo)
    pt, nt, ut, it = _reducir(h, zt["caras"], t_tapa)
    # textura recortada a la caja de UV de las dos piezas; los UV nuevos se reparten otra vez
    uv_todos = np.vstack([uc, ut])
    base, normal, uv2 = ra.recortar_textura(h, uv_todos)
    uc2, ut2 = uv2[:len(uc)], uv2[len(uc):]

    # cuerpo: origen en el centro de su base, base en y = 0
    lo_c, hi_c = zc["lo"], zc["hi"]
    origen = np.array([(lo_c[0] + hi_c[0]) / 2, lo_c[1], (lo_c[2] + hi_c[2]) / 2])
    pc = pc - origen
    # tapa: a la pose cerrada (su base sobre el borde del cuerpo, centrada en él) y la bisagra en su borde de atrás
    lo_t, hi_t = zt["lo"], zt["hi"]
    desplazo = np.array([(lo_c[0] + hi_c[0]) / 2 - (lo_t[0] + hi_t[0]) / 2, hi_c[1] - lo_t[1], 0.0])
    bis_mundo = np.array([(lo_c[0] + hi_c[0]) / 2, hi_c[1], lo_t[2] if BISAGRA_ATRAS > 0 else hi_t[2]])
    pt_cerrada = pt + desplazo
    pt_rel = pt_cerrada - bis_mundo
    tr_tapa = bis_mundo - origen
    ruta = AQUI / "piezas" / f"{ident}.glb"
    _glb(ruta, ident, [("cofre_cuerpo", pc, nc, uc2, ic), ("cofre_tapa", pt_rel, nt, ut2, it)],
         [("cofre_cuerpo", 0, None), ("cofre_tapa", 1, tr_tapa)], base, normal)
    print(f"{ident}: cuerpo {len(ic)} + tapa {len(it)} = {len(ic) + len(it)} tris, bisagra en {np.round(tr_tapa, 3)}, {ruta.stat().st_size // 1024} KB")
    # tapa suelta (centrada en su base) disponible por id
    suelta = AQUI / "piezas" / f"{ident}_tapa.glb"
    ra.escribir_pieza(suelta, f"{ident}_tapa", pt, nt, ut2, it, base, normal)
    print(f"{ident}_tapa: {len(it)} tris (suelta)")


if __name__ == "__main__":
    main()
