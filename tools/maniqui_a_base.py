"""
Pone un CUERPO NUEVO sin esqueleto (un .glb de Meshy) sobre el esqueleto de un personaje del juego, copiándole los pesos.

    blender.exe -b --python tools/maniqui_a_base.py -- <base_con_esqueleto.glb> <cuerpo_nuevo.glb> <salida.glb> [botas=<altura en m>]

Con `botas=0.43` (la altura de BOTA_Z_MAX en partir_base_zonas.gd) el cuerpo nuevo se queda además con las BOTAS de la base: sus
triángulos, con sus pesos y su textura (en un atlas con la nueva), y se le quita lo que quedaría dentro de ellas.

Para qué (Pablo, 19/11: «intégrala en vez de la jugadora existente y pruébale los atuendos a ver si da menos problemas»): la
jugadora_base lleva la ropa fundida en el cuerpo (camisa, chaleco, pantalón, botas) y las prendas chocan con ella: el pantalón
asomaba por el cinturón de la túnica del loberno. El cuerpo nuevo es un MANIQUÍ en ropa interior, más estrecho que cualquier prenda.

Qué hace, sin pasar por el exportador de Blender (así el esqueleto, la piel y las unidades salen IDÉNTICOS a los de la base, que
es lo que esperan las prendas y partir_base_zonas.gd):
  1. Lee los dos .glb a mano. Del de la base se quedan los nodos, la piel (huesos y matrices de enlace) y la escena tal cual.
  2. Escala el cuerpo nuevo a la altura de la base, lo apoya en el suelo y lo centra (las dos figuras salen del mismo personaje
     en la misma pose en A: cabeza, brazos y manos caen encima).
  3. PESOS: cada vértice nuevo busca el punto más cercano de la superficie de la base y toma los pesos de ese triángulo,
     interpolados; se queda con los 4 huesos de más peso.
  4. Escribe un .glb con la malla y la textura nuevas colgadas del esqueleto de la base.
Blender solo se usa por su árbol de búsqueda (mathutils); no se abre ninguna escena.
"""
import json
import struct
import sys

from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform  # noqa: F401  (se deja a mano: los pesos baricéntricos se hacen abajo)

COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class Glb:
    def __init__(self, ruta):
        with open(ruta, "rb") as f:
            d = f.read()
        n = struct.unpack_from("<I", d, 12)[0]
        self.json = json.loads(d[20:20 + n].decode("utf-8"))
        nb = struct.unpack_from("<I", d, 20 + n)[0]
        self.bin = d[20 + n + 8:20 + n + 8 + nb]

    def leer(self, i_acc):
        acc = self.json["accessors"][i_acc]
        vista = self.json["bufferViews"][acc["bufferView"]]
        fmt, tam = COMP[acc["componentType"]]
        n = NCOMP[acc["type"]]
        paso = vista.get("byteStride", tam * n)
        base = vista.get("byteOffset", 0) + acc.get("byteOffset", 0)
        norm = acc.get("normalized", False)
        res = []
        for i in range(acc["count"]):
            t = struct.unpack_from("<%d%s" % (n, fmt), self.bin, base + i * paso)
            if norm and fmt in "BH":
                t = tuple(x / (255.0 if fmt == "B" else 65535.0) for x in t)
            res.append(t)
        return res

    def crudo(self, i_acc):
        acc = self.json["accessors"][i_acc]
        vista = self.json["bufferViews"][acc["bufferView"]]
        fmt, tam = COMP[acc["componentType"]]
        base = vista.get("byteOffset", 0) + acc.get("byteOffset", 0)
        return self.bin[base:base + acc["count"] * tam * NCOMP[acc["type"]]]

    def imagen(self, i_img):
        img = self.json["images"][i_img]
        vista = self.json["bufferViews"][img["bufferView"]]
        return self.bin[vista.get("byteOffset", 0):vista.get("byteOffset", 0) + vista["byteLength"]], img.get("mimeType", "image/png")


def atlas(datos_a, mime_a, datos_b, mime_b, lado=2048):
    """Dos imágenes una al lado de la otra (a | b), cada una a `lado` px como mucho. Devuelve los bytes del PNG."""
    import os
    import tempfile

    import bpy
    import numpy as np

    carpeta = tempfile.mkdtemp(prefix="maniqui_")
    imgs = []
    for k, (datos, mime) in enumerate(((datos_a, mime_a), (datos_b, mime_b))):
        ruta = os.path.join(carpeta, "t%d.%s" % (k, "png" if "png" in mime else "jpg"))
        with open(ruta, "wb") as f:
            f.write(datos)
        imgs.append(bpy.data.images.load(ruta))
    w = min(lado, imgs[0].size[0])
    h = min(lado, imgs[0].size[1])
    trozos = []
    for img in imgs:
        if img.size[0] != w or img.size[1] != h:
            img.scale(w, h)
        px = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        trozos.append(px.reshape(h, w, 4))
    junto = np.concatenate(trozos, axis=1)
    junto[:, :, 3] = 1.0
    out = bpy.data.images.new("atlas", w * 2, h, alpha=False)
    out.pixels.foreach_set(junto.ravel())
    ruta = os.path.join(carpeta, "atlas.png")
    out.filepath_raw = ruta
    out.file_format = "PNG"
    out.save()
    with open(ruta, "rb") as f:
        datos = f.read()
    print("MAN ATLAS de %d x %d px (%d KB): textura nueva | textura de la base" % (w * 2, h, len(datos) // 1024))
    return datos, "image/png", trozos[1]


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    base, nuevo, salida = Glb(a[0]), Glb(a[1]), a[2]

    pb = base.json["meshes"][0]["primitives"][0]
    pos_b = base.leer(pb["attributes"]["POSITION"])
    art_b = base.leer(pb["attributes"]["JOINTS_0"])
    pes_b = base.leer(pb["attributes"]["WEIGHTS_0"])
    idx_b = [t[0] for t in base.leer(pb["indices"])]
    pn = nuevo.json["meshes"][0]["primitives"][0]
    pos_n = nuevo.leer(pn["attributes"]["POSITION"])
    nor_n = nuevo.leer(pn["attributes"]["NORMAL"]) if "NORMAL" in pn["attributes"] else None
    uv_n = nuevo.leer(pn["attributes"]["TEXCOORD_0"])
    idx_n = [t[0] for t in nuevo.leer(pn["indices"])]

    def caja(p):
        return [(min(v[k] for v in p), max(v[k] for v in p)) for k in range(3)]
    cb, cn = caja(pos_b), caja(pos_n)
    esc = (cb[1][1] - cb[1][0]) / (cn[1][1] - cn[1][0])
    cx_n = (cn[0][0] + cn[0][1]) * 0.5
    cx_b = (cb[0][0] + cb[0][1]) * 0.5
    cz_n = (cn[2][0] + cn[2][1]) * 0.5
    cz_b = (cb[2][0] + cb[2][1]) * 0.5
    pos = [((p[0] - cx_n) * esc + cx_b, (p[1] - cn[1][0]) * esc + cb[1][0], (p[2] - cz_n) * esc + cz_b) for p in pos_n]
    print("MAN base: %d vertices, alto %.4f; nuevo: %d vertices, alto %.4f -> escala %.4f" % (
        len(pos_b), cb[1][1] - cb[1][0], len(pos_n), cn[1][1] - cn[1][0], esc))

    arbol = BVHTree.FromPolygons([Vector(p) for p in pos_b], [tuple(idx_b[t:t + 3]) for t in range(0, len(idx_b), 3)])
    art, pes = [], []
    lejos = 0
    d_max = 0.0
    for p in pos:
        q = Vector(p)
        loc, _nor, i_tri, dist = arbol.find_nearest(q)
        d_max = max(d_max, dist)
        if dist > 0.0006:             # 6 cm en unidades de la malla (1/100)
            lejos += 1
        va, vb, vc = idx_b[i_tri * 3], idx_b[i_tri * 3 + 1], idx_b[i_tri * 3 + 2]
        A, B, C = Vector(pos_b[va]), Vector(pos_b[vb]), Vector(pos_b[vc])
        v0, v1, v2 = B - A, C - A, loc - A
        d00, d01, d11, d20, d21 = v0.dot(v0), v0.dot(v1), v1.dot(v1), v2.dot(v0), v2.dot(v1)
        den = d00 * d11 - d01 * d01
        if abs(den) < 1e-20:
            bar = (1.0, 0.0, 0.0)
        else:
            bv = (d11 * d20 - d01 * d21) / den
            bw = (d00 * d21 - d01 * d20) / den
            bar = (max(0.0, 1.0 - bv - bw), max(0.0, bv), max(0.0, bw))
        suma = {}
        for v, w_tri in zip((va, vb, vc), bar):
            for j, w in zip(art_b[v], pes_b[v]):
                if w > 0.0:
                    suma[j] = suma.get(j, 0.0) + w * w_tri
        top = sorted(suma.items(), key=lambda x: -x[1])[:4]
        tot = sum(w for _j, w in top) or 1.0
        top += [(0, 0.0)] * (4 - len(top))
        art.append(tuple(int(j) for j, _w in top))
        pes.append(tuple(w / tot for _j, w in top))
    print("MAN pesos copiados; %d vertices a mas de 6 cm de la base (el mas lejano, %.1f cm)" % (lejos, d_max * 100.0 * 100.0))

    datos_img, mime = nuevo.imagen(nuevo.json["textures"][nuevo.json["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"])
    uv = [tuple(t) for t in uv_n]
    nor = [tuple(t) for t in nor_n] if nor_n else None
    idx = list(idx_n)

    # ---- EL PELO, A LA CABEZA (Pablo, 19/11: «hay pelos hacia afuera»). Las puntas de la melena caen junto a los hombros y el punto más
    # cercano de la base era la camisa: heredaban el peso del hombro, se estiraban con el brazo y partir_base_zonas.gd no las
    # contaba como cabeza (no las tapaba la capucha). En el maniquí lo único de color saturado es el pelo (la piel y la ropa
    # interior son claras): todo vértice así cuelga entero del hueso Head.
    if "pelo_a_cabeza" in a:
        import os
        import tempfile

        import bpy
        import numpy as np
        ruta_t = os.path.join(tempfile.mkdtemp(prefix="maniqui_"), "nueva.png" if "png" in mime else "nueva.jpg")
        with open(ruta_t, "wb") as f:
            f.write(datos_img)
        img_n = bpy.data.images.load(ruta_t)
        wn, hn = img_n.size[0], img_n.size[1]
        px_n = np.empty(wn * hn * 4, dtype=np.float32)
        img_n.pixels.foreach_get(px_n)
        px_n = px_n.reshape(hn, wn, 4)
        nombres_j = [base.json["nodes"][j].get("name", "") for j in base.json["skins"][0]["joints"]]
        j_cabeza = nombres_j.index("mixamorig_Head")
        y_min = cb[1][0] + (cb[1][1] - cb[1][0]) * 0.60          # solo de los hombros para arriba
        cambiados = 0
        for v in range(len(pos)):
            if pos[v][1] < y_min:
                continue
            c = px_n[min(hn - 1, max(0, int((1.0 - uv[v][1]) * hn))), min(wn - 1, max(0, int(uv[v][0] * wn)))]
            mx, mn = max(c[0], c[1], c[2]), min(c[0], c[1], c[2])
            if mx > 0.3 and (mx - mn) / mx > 0.33 and c[0] >= c[1] >= c[2]:
                if art[v][0] != j_cabeza or pes[v][0] < 0.999:
                    cambiados += 1
                art[v] = (j_cabeza, 0, 0, 0)
                pes[v] = (1.0, 0.0, 0.0, 0.0)
        print("MAN PELO: %d vertices de color de pelo pasan a colgar solo de la cabeza" % cambiados)

    # ---- BOTAS de la base (Pablo, 19/11: «mete las botas de la jugadora base»; van a ser siempre las mismas)
    z_bota = None
    for x in a[3:]:
        if x.startswith("botas="):
            z_bota = float(x[6:]) / 100.0        # metros -> unidades de la malla
    if z_bota is not None:
        nombres = [base.json["nodes"][j].get("name", "") for j in base.json["skins"][0]["joints"]]
        dom = [nombres[art_b[v][max(range(4), key=lambda k: pes_b[v][k])]].replace("mixamorig_", "") for v in range(len(pos_b))]
        nor_b = base.leer(pb["attributes"]["NORMAL"])
        uv_b = base.leer(pb["attributes"]["TEXCOORD_0"])
        # los triángulos de la zona «botas», con la misma regla que herramientas/partir_base_zonas.gd
        tris_bota = []
        for t in range(0, len(idx_b), 3):
            va, vb, vc = idx_b[t:t + 3]
            h = dom[vb] if dom[vb] == dom[vc] else dom[va]
            alto = (pos_b[va][1] + pos_b[vb][1] + pos_b[vc][1]) / 3.0
            if h.endswith("Foot") or "Toe" in h or (h.endswith("Leg") and not h.endswith("UpLeg") and alto < z_bota):
                tris_bota.append((va, vb, vc))
        # del cuerpo nuevo se va lo que queda DENTRO de la bota (5 cm por debajo de su boca): los pies descalzos asomarían por la puntera
        corte = z_bota - 0.0005
        quedan = [t for t in range(0, len(idx), 3) if not all(pos[idx[t + k]][1] < corte for k in range(3))]
        usados = sorted(set(idx[t + k] for t in quedan for k in range(3)))
        nuevo_de = {v: i for i, v in enumerate(usados)}
        quitadas = len(idx) // 3 - len(quedan)
        idx = [nuevo_de[idx[t + k]] for t in quedan for k in range(3)]
        pos = [pos[v] for v in usados]
        uv = [uv[v] for v in usados]
        art = [art[v] for v in usados]
        pes = [pes[v] for v in usados]
        if nor:
            nor = [nor[v] for v in usados]
        # ATLAS: la textura nueva a la izquierda y la de la base a la derecha, en una sola imagen (el cuerpo sigue siendo una malla
        # con un material, que es lo que esperan Pj3D y partir_base_zonas.gd). Las U se parten por la mitad.
        datos_img, mime, px_base = atlas(datos_img, mime, *base.imagen(base.json["textures"][base.json["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]))
        uv = [(u * 0.5, v) for u, v in uv]
        # Fuera el PANTALÓN: la regla de zonas coge también el bajo del pantalón verde metido en la bota, que sin pantalón quedaba
        # como una corona de picos verdes en la boca de la bota. Un triángulo de bota es de cuero: más rojo que verde.
        alto_px, ancho_px = px_base.shape[0], px_base.shape[1]

        def verde(tri):
            # basta UNA muestra verde (esquinas y centro): los picos son triángulos largos con una esquina en el cuero
            us = [uv_b[v] for v in tri]
            us.append((sum(u[0] for u in us) / 3.0, sum(u[1] for u in us) / 3.0))
            for u, v in us:
                c = px_base[min(alto_px - 1, max(0, int((1.0 - v) * alto_px))), min(ancho_px - 1, max(0, int(u * ancho_px)))]
                if c[1] >= c[0] * 0.92:
                    return True
            return False
        antes = len(tris_bota)
        tris_bota = [t for t in tris_bota if not verde(t)]
        print("MAN BOTAS: %d caras verdes (pantalon) descartadas" % (antes - len(tris_bota)))
        de_bota = {}
        for tri in tris_bota:
            for v in tri:
                if v not in de_bota:
                    de_bota[v] = len(pos)
                    pos.append(pos_b[v])
                    uv.append((0.5 + min(1.0, max(0.0, uv_b[v][0])) * 0.5, uv_b[v][1]))
                    art.append(tuple(int(j) for j in art_b[v]))
                    pes.append(tuple(pes_b[v]))
                    if nor is not None:
                        nor.append(nor_b[v])
            idx.extend(de_bota[v] for v in tri)
        print("MAN BOTAS: %d caras y %d vertices de las botas de la base (por debajo de %.2f m); %d caras del cuerpo nuevo quitadas de dentro" % (
            len(tris_bota), len(de_bota), z_bota * 100.0, quitadas))
    uv_n, nor_n, idx_n = uv, nor, idx

    # ---- escribir
    binario = bytearray()
    vistas, accs = [], []

    def meter(datos, comp, tipo, cuenta, destino=None, extra=None):
        while len(binario) % 4:
            binario.append(0)
        v = {"buffer": 0, "byteOffset": len(binario), "byteLength": len(datos)}
        if destino:
            v["target"] = destino
        vistas.append(v)
        binario.extend(datos)
        acc = {"bufferView": len(vistas) - 1, "componentType": comp, "count": cuenta, "type": tipo}
        if extra:
            acc.update(extra)
        accs.append(acc)
        return len(accs) - 1

    c2 = caja(pos)
    a_pos = meter(b"".join(struct.pack("<3f", *p) for p in pos), 5126, "VEC3", len(pos), 34962,
                  {"min": [c2[0][0], c2[1][0], c2[2][0]], "max": [c2[0][1], c2[1][1], c2[2][1]]})
    atributos = {"POSITION": a_pos}
    if nor_n:
        atributos["NORMAL"] = meter(b"".join(struct.pack("<3f", *p) for p in nor_n), 5126, "VEC3", len(nor_n), 34962)
    atributos["TEXCOORD_0"] = meter(b"".join(struct.pack("<2f", *p) for p in uv_n), 5126, "VEC2", len(uv_n), 34962)
    atributos["JOINTS_0"] = meter(b"".join(struct.pack("<4H", *p) for p in art), 5123, "VEC4", len(art), 34962)
    atributos["WEIGHTS_0"] = meter(b"".join(struct.pack("<4f", *p) for p in pes), 5126, "VEC4", len(pes), 34962)
    a_idx = meter(struct.pack("<%dI" % len(idx_n), *idx_n), 5125, "SCALAR", len(idx_n), 34963)
    skin = base.json["skins"][0]
    a_ibm = meter(base.crudo(skin["inverseBindMatrices"]), 5126, "MAT4", len(skin["joints"]))
    while len(binario) % 4:
        binario.append(0)
    vistas.append({"buffer": 0, "byteOffset": len(binario), "byteLength": len(datos_img)})
    binario.extend(datos_img)
    while len(binario) % 4:
        binario.append(0)

    g = {
        "asset": {"version": "2.0", "generator": "tools/maniqui_a_base.py"},
        "scene": base.json.get("scene", 0),
        "scenes": base.json["scenes"],
        "nodes": base.json["nodes"],
        "skins": [dict(skin, inverseBindMatrices=a_ibm)],
        "meshes": [{"name": base.json["meshes"][0].get("name", "cuerpo"),
                    "primitives": [{"attributes": atributos, "indices": a_idx, "material": 0}]}],
        "materials": [{"name": "BakedMaterial", "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0,
                                                                         "roughnessFactor": 1.0}}],
        "textures": [{"source": 0, "sampler": 0}],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
        "images": [{"name": "BakedMaterial_albedo", "bufferView": len(vistas) - 1, "mimeType": mime}],
        "accessors": accs,
        "bufferViews": vistas,
        "buffers": [{"byteLength": len(binario)}],
    }
    texto = json.dumps(g, separators=(",", ":")).encode("utf-8")
    texto += b" " * ((4 - len(texto) % 4) % 4)
    fuera = bytearray(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(texto) + 8 + len(binario)))
    fuera += struct.pack("<I4s", len(texto), b"JSON") + texto + struct.pack("<I4s", len(binario), b"BIN\x00") + binario
    with open(salida, "wb") as f:
        f.write(fuera)
    print("MAN ESCRITO: %s (%d vertices, %d caras, %d huesos, textura %s de %d KB)" % (
        salida, len(pos), len(idx_n) // 3, len(skin["joints"]), mime, len(datos_img) // 1024))


main()
