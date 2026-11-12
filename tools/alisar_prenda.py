"""
Alisa una zona de la malla de una prenda .glb (y rehace ahí las normales) sin reexportarla.

    python tools/alisar_prenda.py <entrada.glb> <salida.glb> caja=<x0,x1,y0,y1,z0,z1> [pasadas=8] [fuerza=0.5] [unidad=100]

Para qué (Pablo, 12/11, capucha roja de Sumicio): donde nace la punta la capucha traía un pliegue hundido que se veía como una
mancha oscura de cantos rectos. Aquí se relaja: cada vértice de dentro de la caja se acerca a la media de sus vecinos (`pasadas`
veces, `fuerza` de 0 a 1), entrando poco a poco desde las caras de la caja, y al final sus normales se recalculan con las caras.
Caja en metros y ejes de Blender (X; Y, con delante = -Y; Z = alto). Las posiciones se sueldan para que las costuras de UV se
muevan juntas. Solo cambian posiciones y normales de esos vértices; caras, UV, pesos y texturas quedan igual.

OJO: alisar ENCOGE la tela. Con 10 pasadas a 0,5 el pliegue desaparecía pero la capucha se hundía y el pelo de la frente la
atravesaba otra vez (y ponerla a doble cara lo empeoraba: salían parches oscuros de la pared de dentro). La del juego lleva,
después de tools/tapar_agujeros_prenda.py (max_vertices=45 max_perimetro=0.9):
    alisar_prenda.py    caja=-0.50,0.05,-0.50,0.05,1.42,1.80 pasadas=3 fuerza=0.4
    desplazar_prenda.py unidad=100 delante=0.05 caja=-0.40,0.04,-0.60,-0.10,1.44,1.78
"""
import json
import math
import struct
import sys

TIPOS = {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4)}
BORDE = 0.05


def suave(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    entrada, salida = a[0], a[1]
    caja, pasadas, fuerza, unidad = None, 8, 0.5, 100.0
    for x in a[2:]:
        if x.startswith("caja="):
            caja = [float(v) for v in x[5:].split(",")]
        if x.startswith("pasadas="):
            pasadas = int(x[8:])
        if x.startswith("fuerza="):
            fuerza = float(x[7:])
        if x.startswith("unidad="):
            unidad = float(x[7:])
    with open(entrada, "rb") as f:
        datos = bytearray(f.read())
    largo_json = struct.unpack_from("<I", datos, 12)[0]
    gltf = json.loads(datos[20:20 + largo_json].decode("utf-8"))
    ini = 20 + largo_json + 8

    def donde(i_acc, tam_el):
        acc = gltf["accessors"][i_acc]
        vista = gltf["bufferViews"][acc["bufferView"]]
        return ini + vista.get("byteOffset", 0) + acc.get("byteOffset", 0), vista.get("byteStride", tam_el), acc["count"]

    for malla in gltf["meshes"]:
        for prim in malla["primitives"]:
            bp, pp, n = donde(prim["attributes"]["POSITION"], 12)
            pos = [list(struct.unpack_from("<3f", datos, bp + i * pp)) for i in range(n)]
            acc_i = gltf["accessors"][prim["indices"]]
            fmt, tam = TIPOS[acc_i["componentType"]]
            bi, pi, ni = donde(prim["indices"], tam)
            idx = [struct.unpack_from("<" + fmt, datos, bi + i * pi)[0] for i in range(ni)]
            clave, sold = {}, []
            for p in pos:
                c = (round(p[0] * unidad * 20000), round(p[1] * unidad * 20000), round(p[2] * unidad * 20000))
                sold.append(clave.setdefault(c, len(clave)))
            ps = [None] * len(clave)
            for i, s in enumerate(sold):
                ps[s] = list(pos[i])
            vec = [set() for _ in ps]
            for t in range(0, len(idx), 3):
                st = [sold[v] for v in idx[t:t + 3]]
                for k in range(3):
                    if st[k] != st[(k + 1) % 3]:
                        vec[st[k]].add(st[(k + 1) % 3])
                        vec[st[(k + 1) % 3]].add(st[k])
            peso = []
            for p in ps:
                xm, ym, zm = p[0] * unidad, -p[2] * unidad, p[1] * unidad
                w = 1.0
                for v, a0, a1 in ((xm, caja[0], caja[1]), (ym, caja[2], caja[3]), (zm, caja[4], caja[5])):
                    w *= suave(min(v - a0, a1 - v) / BORDE)
                peso.append(w)
            dentro = [s for s, w in enumerate(peso) if w > 0.0 and vec[s]]
            for _ in range(pasadas):
                nuevo = {}
                for s in dentro:
                    m = [sum(ps[v][k] for v in vec[s]) / len(vec[s]) for k in range(3)]
                    f = fuerza * peso[s]
                    nuevo[s] = [ps[s][k] + (m[k] - ps[s][k]) * f for k in range(3)]
                for s, p in nuevo.items():
                    ps[s] = p
            # normales por cara, sumadas en los soldados de la caja
            nor = {s: [0.0, 0.0, 0.0] for s in dentro}
            for t in range(0, len(idx), 3):
                st = [sold[v] for v in idx[t:t + 3]]
                if not any(s in nor for s in st):
                    continue
                a0, b0, c0 = ps[st[0]], ps[st[1]], ps[st[2]]
                u = [b0[k] - a0[k] for k in range(3)]
                v = [c0[k] - a0[k] for k in range(3)]
                cr = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
                for s in st:
                    if s in nor:
                        for k in range(3):
                            nor[s][k] += cr[k]
            tiene_n = "NORMAL" in prim["attributes"]
            if tiene_n:
                bn, pn, _ = donde(prim["attributes"]["NORMAL"], 12)
            mn, mx = [1e9] * 3, [-1e9] * 3
            for i, s in enumerate(sold):
                if peso[s] > 0.0 and vec[s]:
                    struct.pack_into("<3f", datos, bp + i * pp, *ps[s])
                    l = math.sqrt(sum(c * c for c in nor[s]))
                    if tiene_n and l > 1e-20:
                        viejo = struct.unpack_from("<3f", datos, bn + i * pn)
                        nn = [nor[s][k] / l for k in range(3)]
                        w = peso[s]
                        mez = [viejo[k] * (1.0 - w) + nn[k] * w for k in range(3)]
                        lm = math.sqrt(sum(c * c for c in mez)) or 1.0
                        struct.pack_into("<3f", datos, bn + i * pn, *[c / lm for c in mez])
                for k in range(3):
                    mn[k] = min(mn[k], ps[s][k])
                    mx[k] = max(mx[k], ps[s][k])
            acc = gltf["accessors"][prim["attributes"]["POSITION"]]
            acc["min"], acc["max"] = mn, mx
            print("ALI malla «%s»: %d vertices soldados dentro de la caja, %d pasadas con fuerza %.2f" % (
                malla.get("name", "?"), len(dentro), pasadas, fuerza))
    texto = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    texto += b" " * ((4 - len(texto) % 4) % 4)
    resto = bytes(datos[20 + largo_json:])
    fuera = bytearray(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(texto) + len(resto)))
    fuera += struct.pack("<I4s", len(texto), b"JSON") + texto + resto
    with open(salida, "wb") as f:
        f.write(fuera)
    print("ALI ESCRITO: %s" % salida)


main()
