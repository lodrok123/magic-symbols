"""
Ayudas compartidas de glb_quitar_islas.py y glb_pesos_a_cadera.py: editar un GLB «en sitio», tocando solo unos bytes de su trozo BIN.

No se usa solo; se importa (los dos programas lo hacen con sys.path). Siempre `python -I`.

Para qué existe (20/11, Moura viajera e Inquisidor, rigs de Pablo con Meshy + Mixamo): re-exportar con Blender reordena las articulaciones y recorta cada clip hasta un
fotograma (un andar en bucle da un tirón), así que los arreglos de malla se hacen sobre el propio GLB: se lee el JSON y el BIN, se cambian solo los índices de triángulos
(quitar piezas) o solo JOINTS_0/WEIGHTS_0 (repesar), y se vuelve a escribir. Esqueleto, clips, texturas, posiciones, normales y UV quedan idénticos byte a byte.

Eje de la malla: la de Meshy va en Y arriba y el frente del personaje en +Z (la espalda en -Z).
"""
import colorsys
import io
import json
import struct

from PIL import Image


class Glb:
    """Un GLB leído: `j` (JSON), `binc` (bytearray del trozo BIN, editable), `raw` (bytes originales del fichero)."""

    def __init__(self, ruta: str) -> None:
        self.raw: bytes = open(ruta, "rb").read()
        b = self.raw
        self.jl, self.jt = struct.unpack("<II", b[12:20])
        self.j: dict = json.loads(b[20:20 + self.jl])
        self.bo: int = 20 + self.jl                       # inicio de la cabecera del trozo BIN
        self.bl, self.bt = struct.unpack("<II", b[self.bo:self.bo + 8])
        self.binc: bytearray = bytearray(b[self.bo + 8:self.bo + 8 + self.bl])
        self.resto: bytes = b[self.bo + 8 + self.bl:]
        self.prim: dict = self.j["meshes"][0]["primitives"][0]

    # --- accesores -------------------------------------------------------------------------------------------------------------
    def inicio(self, acc: dict) -> int:
        bv = self.j["bufferViews"][acc["bufferView"]]
        return bv["byteOffset"] + acc.get("byteOffset", 0)

    def atributo(self, nombre: str) -> tuple:
        """(offset en el BIN, nº de elementos) de un atributo de la primitiva."""
        a = self.j["accessors"][self.prim["attributes"][nombre]]
        return self.inicio(a), a["count"]

    def posiciones(self) -> list:
        o, n = self.atributo("POSITION")
        return [struct.unpack_from("<3f", self.binc, o + 12 * i) for i in range(n)]

    def uvs(self) -> list:
        o, n = self.atributo("TEXCOORD_0")
        return [struct.unpack_from("<2f", self.binc, o + 8 * i) for i in range(n)]

    def jointas(self) -> list:
        o, n = self.atributo("JOINTS_0")
        return [struct.unpack_from("<4B", self.binc, o + 4 * i) for i in range(n)]

    def pesos(self) -> list:
        o, n = self.atributo("WEIGHTS_0")
        return [struct.unpack_from("<4f", self.binc, o + 16 * i) for i in range(n)]

    def indices(self) -> tuple:
        """(accesor, formato struct, tamaño de cada índice, offset, lista de índices)."""
        a = self.j["accessors"][self.prim["indices"]]
        fmt = {5123: "H", 5125: "I", 5121: "B"}[a["componentType"]]
        o = self.inicio(a)
        return a, fmt, struct.calcsize(fmt), o, list(struct.unpack_from("<%d%s" % (a["count"], fmt), self.binc, o))

    def nombres_huesos(self) -> list:
        sk = self.j["skins"][0]
        return [self.j["nodes"][x]["name"].split(":")[-1] for x in sk["joints"]]

    def reposo_hueso(self, i: int) -> list:
        """Posición de reposo (espacio de la malla) del hueso i del skin, desde su matriz de enlace inversa."""
        sk = self.j["skins"][0]
        a = self.j["accessors"][sk["inverseBindMatrices"]]
        m = struct.unpack_from("<16f", self.binc, self.inicio(a) + i * 64)
        r = [[m[0], m[4], m[8]], [m[1], m[5], m[9]], [m[2], m[6], m[10]]]
        t = [m[12], m[13], m[14]]
        return [-sum(r[k][c] * t[k] for k in range(3)) for c in range(3)]

    def imagen_base(self) -> Image.Image:
        """La textura de color base del material (no la primera imagen: en los GLB de Meshy la 0 suele ser la emisiva)."""
        j = self.j
        tx = j["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
        im = j["images"][j["textures"][tx]["source"]]
        bv = j["bufferViews"][im["bufferView"]]
        return Image.open(io.BytesIO(bytes(self.binc[bv["byteOffset"]:bv["byteOffset"] + bv["byteLength"]]))).convert("RGB")

    # --- escritura -------------------------------------------------------------------------------------------------------------
    def guardar(self, ruta: str, con_json: bool = False) -> None:
        """Escribe el GLB. Con `con_json` vuelve a serializar el JSON (cuando se cambió un accesor); si no, el JSON queda como estaba."""
        if con_json:
            js = json.dumps(self.j, separators=(",", ":")).encode()
            while len(js) % 4:
                js += b" "
            out = (struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(self.binc) + len(self.resto))
                   + struct.pack("<II", len(js), self.jt) + js + struct.pack("<II", len(self.binc), self.bt) + bytes(self.binc) + self.resto)
        else:
            o = bytearray(self.raw)
            o[self.bo + 8:self.bo + 8 + len(self.binc)] = self.binc
            out = bytes(o)
        open(ruta, "wb").write(out)


def grupos_soldados(pos: list) -> tuple:
    """Une los vértices que están en la misma posición (a 1e-5): las costuras de UV no cuentan como piezas distintas.
    Devuelve (raiz, grupos): raiz(i) da el representante soldado del vértice i; grupos = {representante: [vértices]}."""
    n = len(pos)
    wp = list(range(n))

    def raiz(x: int) -> int:
        while wp[x] != x:
            wp[x] = wp[wp[x]]
            x = wp[x]
        return x
    visto: dict = {}
    for i, p in enumerate(pos):
        k = tuple(round(c, 5) for c in p)
        if k in visto:
            wp[raiz(i)] = raiz(visto[k])
        else:
            visto[k] = i
    grupos: dict = {}
    for i in range(n):
        grupos.setdefault(raiz(i), []).append(i)
    return raiz, grupos


def islas(pos: list, idx: list) -> dict:
    """Piezas conectadas de la malla (por vértices compartidos y soldando posiciones iguales): {representante: [vértices]}."""
    n = len(pos)
    par = list(range(n))

    def f(x: int) -> int:
        while par[x] != x:
            par[x] = par[par[x]]
            x = par[x]
        return x
    d: dict = {}
    for i, p in enumerate(pos):
        k = tuple(round(c, 5) for c in p)
        if k in d:
            par[f(i)] = f(d[k])
        else:
            d[k] = i
    for t in range(0, len(idx), 3):
        par[f(idx[t + 1])] = f(idx[t])
        par[f(idx[t + 2])] = f(idx[t])
    out: dict = {}
    for i in range(n):
        out.setdefault(f(i), []).append(i)
    return out


def color_de(img: Image.Image, uv: tuple) -> tuple:
    x = int(uv[0] * img.size[0]) % img.size[0]
    y = int(uv[1] * img.size[1]) % img.size[1]
    return img.getpixel((x, y))


def hsv_de(rgb: tuple) -> tuple:
    return colorsys.rgb_to_hsv(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255)


def suavizado(x: float) -> float:
    """smoothstep sobre [0, 1] (el argumento se recorta)."""
    x = max(0, min(1, x))
    return x * x * (3 - 2 * x)


def vecinos_soldados(raiz, idx: list) -> dict:
    """Adyacencia entre grupos soldados (por triángulos): {grupo: {grupos vecinos}}."""
    nb: dict = {}
    for t in range(0, len(idx), 3):
        tri = [raiz(v) for v in idx[t:t + 3]]
        for a in tri:
            for b in tri:
                if a != b:
                    nb.setdefault(a, set()).add(b)
    return nb


def reponderar(glb: Glb, candidato, mezcla, anillo_ok, pasadas: int = 3) -> tuple:
    """Cambia JOINTS_0/WEIGHTS_0 de los vértices que cumplen `candidato(i)`: sus pesos pasan a `mezcla(i)` (dict hueso -> peso, ya mezclado) y luego se suavizan
    `pasadas` veces (Laplaciano de factor 0,5 sobre la adyacencia soldada) en esos vértices y en los de su 1-anillo que cumplan `anillo_ok(vértice)`; se renormaliza
    y se dejan los 4 pesos mayores. JOINTS_0 es ubyte y WEIGHTS_0 float32 (los tipos que traen los GLB de Meshy).
    Devuelve (vértices candidatos, grupos soldados candidatos, grupos suavizados). `candidato` y `mezcla` se evalúan sobre los pesos originales."""
    pos = glb.posiciones()
    n = len(pos)
    jo, _ = glb.atributo("JOINTS_0")
    wo, _ = glb.atributo("WEIGHTS_0")
    J = glb.jointas()
    W = glb.pesos()
    raiz, wg = grupos_soldados(pos)
    idx = glb.indices()[4]
    nb = vecinos_soldados(raiz, idx)
    tocados = {i for i in range(n) if candidato(i)}
    tg = {raiz(i) for i in tocados}
    anillo: set = set()
    for x in tg:
        anillo |= nb.get(x, set())
    S = set(tg)
    for x in anillo:
        if anillo_ok(wg[x][0]):
            S.add(x)

    def peso_grupo(x: int) -> dict:
        acum: dict = {}
        for i in wg[x]:
            w = mezcla(i) if i in tocados else {jj: ww for jj, ww in zip(J[i], W[i]) if ww > 0}
            for k, v in w.items():
                acum[k] = acum.get(k, 0) + v / len(wg[x])
        return acum
    todos = set(S)
    for x in S:
        todos |= nb.get(x, set())
    cur = {x: peso_grupo(x) for x in todos}
    for _ in range(pasadas):
        nuevo: dict = {}
        for x in S:
            ns = [cur[y] for y in nb.get(x, ()) if y in cur]
            if not ns:
                continue
            w: dict = {}
            for k, v in cur[x].items():
                w[k] = w.get(k, 0) + 0.5 * v
            for nw in ns:
                for k, v in nw.items():
                    w[k] = w.get(k, 0) + 0.5 * v / len(ns)
            nuevo[x] = w
        cur.update(nuevo)
    for x in S:
        w = sorted(cur[x].items(), key=lambda kv: -kv[1])[:4]
        tot = sum(v for _, v in w)
        w = [(k, v / tot) for k, v in w]
        while len(w) < 4:
            w.append((0, 0.0))
        for i in wg[x]:
            struct.pack_into("<4B", glb.binc, jo + 4 * i, *[k for k, _ in w])
            struct.pack_into("<4f", glb.binc, wo + 16 * i, *[v for _, v in w])
    return len(tocados), len(tg), len(S)
