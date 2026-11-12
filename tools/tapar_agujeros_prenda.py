"""
Tapa los AGUJEROS pequeños de la malla de una prenda .glb sin reexportarla: añade triángulos entre los vértices que ya hay.

    python tools/tapar_agujeros_prenda.py <entrada.glb> <salida.glb> [unidad=100] [max_vertices=40] [max_perimetro=0.6] [doble_cara] [medir]

Para qué (Pablo, 12/11, capa y capucha rojas de Sumicio: «Sí, arréglalos»): la capa salía llena de rajas por las que se veía la
túnica y la camisa. tools/auditar_malla_prenda.py contaba 121 bucles de borde pequeños en la capa y 125 en la capucha: agujeros
que dejaron el recorte del forro y el decimado, no bordes de la prenda.

Qué hace: suelda las posiciones (las costuras de UV no cuentan), busca las aristas con una sola cara y las encadena en bucles.
Cada bucle de hasta `max_vertices` vértices y `max_perimetro` metros se cierra con triángulos (recorte de orejas sobre su plano
medio) entre COPIAS de los vértices del propio borde, con el mismo sentido de giro que las caras vecinas. Los bucles grandes son los
bordes de verdad (cuello, bajo, abertura de la cara) y no se tocan. Las copias llevan la posición, la normal y los pesos de su
vértice y, todas las de un parche, la UV del primero: el parche sale de un color. Lo que ya había (posiciones, UV, pesos, huesos,
texturas) no cambia; los atributos y los índices ampliados se escriben al final del binario.
`unidad` es cuántos metros mide una unidad de la malla (las prendas del juego: 100). `medir` no escribe.
"""
import json
import math
import struct
import sys

TIPOS = {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4)}


def argumentos():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else a[1:]


def resta(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cruz(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def punto(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def largo(a):
    return math.sqrt(punto(a, a))


def orejas(pts):
    """Triangula un polígono 3D casi plano. Devuelve ternas de posiciones en el orden del polígono."""
    n = len(pts)
    if n < 3:
        return []
    if n == 3:
        return [(0, 1, 2)]
    nor = [0.0, 0.0, 0.0]                      # normal de Newell
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        nor[0] += (a[1] - b[1]) * (a[2] + b[2])
        nor[1] += (a[2] - b[2]) * (a[0] + b[0])
        nor[2] += (a[0] - b[0]) * (a[1] + b[1])
    ln = largo(nor)
    if ln < 1e-20:
        return [(0, i, i + 1) for i in range(1, n - 1)]
    nor = (nor[0] / ln, nor[1] / ln, nor[2] / ln)
    eje = (1.0, 0.0, 0.0) if abs(nor[0]) < 0.9 else (0.0, 1.0, 0.0)
    u = cruz(nor, eje)
    lu = largo(u)
    u = (u[0] / lu, u[1] / lu, u[2] / lu)
    v = cruz(nor, u)
    p2 = [(punto(p, u), punto(p, v)) for p in pts]      # visto desde la normal de Newell el polígono gira en positivo

    def giro(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

    vivos = list(range(n))
    tris = []
    while len(vivos) > 3:
        mejor, mejor_g = None, -1e30
        for k in range(len(vivos)):
            ia, ib, ic = vivos[k - 1], vivos[k], vivos[(k + 1) % len(vivos)]
            g = giro(p2[ia], p2[ib], p2[ic])
            if g <= 0.0:
                if g > mejor_g and mejor is None:
                    pass
                continue
            dentro = False
            for j in vivos:
                if j in (ia, ib, ic):
                    continue
                if giro(p2[ia], p2[ib], p2[j]) > 0 and giro(p2[ib], p2[ic], p2[j]) > 0 and giro(p2[ic], p2[ia], p2[j]) > 0:
                    dentro = True
                    break
            if not dentro and g > mejor_g:
                mejor, mejor_g = k, g
        if mejor is None:                       # polígono retorcido: se corta por donde menos daño haga
            mejor = max(range(len(vivos)), key=lambda k: giro(p2[vivos[k - 1]], p2[vivos[k]], p2[vivos[(k + 1) % len(vivos)]]))
        tris.append((vivos[mejor - 1], vivos[mejor], vivos[(mejor + 1) % len(vivos)]))
        vivos.pop(mejor)
    tris.append((vivos[0], vivos[1], vivos[2]))
    return tris


def main():
    a = argumentos()
    entrada, salida = a[0], a[1]
    unidad, max_v, max_p = 100.0, 40, 0.6
    for x in a[2:]:
        if x.startswith("unidad="):
            unidad = float(x[7:])
        if x.startswith("max_vertices="):
            max_v = int(x[13:])
        if x.startswith("max_perimetro="):
            max_p = float(x[14:])
    medir = "medir" in a
    with open(entrada, "rb") as f:
        datos = f.read()
    largo_json = struct.unpack_from("<I", datos, 12)[0]
    gltf = json.loads(datos[20:20 + largo_json].decode("utf-8"))
    ini_bin = 20 + largo_json + 8
    largo_bin = struct.unpack_from("<I", datos, 20 + largo_json)[0]
    binario = bytearray(datos[ini_bin:ini_bin + largo_bin])

    def leer(i_acc, n_comp, fmt, tam):
        acc = gltf["accessors"][i_acc]
        vista = gltf["bufferViews"][acc["bufferView"]]
        paso = vista.get("byteStride", tam * n_comp)
        base = vista.get("byteOffset", 0) + acc.get("byteOffset", 0)
        return [struct.unpack_from("<%d%s" % (n_comp, fmt), binario, base + i * paso) for i in range(acc["count"])]

    for malla in gltf.get("meshes", []):
        for prim in malla["primitives"]:
            if prim.get("mode", 4) != 4 or "indices" not in prim:
                continue
            pos = leer(prim["attributes"]["POSITION"], 3, "f", 4)
            acc_i = gltf["accessors"][prim["indices"]]
            fmt, tam = TIPOS[acc_i["componentType"]]
            idx = [t[0] for t in leer(prim["indices"], 1, fmt, tam)]
            # soldar por posición (a 0,05 mm)
            clave, sold = {}, []
            for p in pos:
                c = (round(p[0] * unidad * 20000), round(p[1] * unidad * 20000), round(p[2] * unidad * 20000))
                sold.append(clave.setdefault(c, len(clave)))
            pos_s = {}
            for i, s in enumerate(sold):
                pos_s.setdefault(s, tuple(c * unidad for c in pos[i]))
            uso = {}
            dirigidas = []
            for t in range(0, len(idx), 3):
                tri = idx[t:t + 3]
                st = [sold[v] for v in tri]
                if len(set(st)) < 3:
                    continue
                for k in range(3):
                    sa, sb = st[k], st[(k + 1) % 3]
                    uso[(min(sa, sb), max(sa, sb))] = uso.get((min(sa, sb), max(sa, sb)), 0) + 1
                    dirigidas.append((sa, sb, tri[k]))
            sale = {}
            for sa, sb, va in dirigidas:
                if uso[(min(sa, sb), max(sa, sb))] == 1:
                    sale.setdefault(sa, []).append((sb, va))
            n_borde = sum(len(v) for v in sale.values())
            # Bucles: se camina por el borde; cuando el camino vuelve a un punto por el que ya pasó, ese tramo es un bucle y se
            # saca (un borde que se toca a sí mismo en un punto son dos agujeros, no uno «raro»).
            bucles = []
            raros = 0
            for s0 in list(sale):
                while sale.get(s0):
                    camino, donde = [], {}
                    s = s0
                    while True:
                        if s in donde:
                            k = donde[s]
                            bucles.append(camino[k:])
                            for b in camino[k:]:
                                del donde[b[0]]
                            del camino[k:]
                        if not sale.get(s):
                            break
                        sb, va = sale[s].pop()
                        donde[s] = len(camino)
                        camino.append((s, va))
                        s = sb
                    if camino:
                        raros += 1          # un tramo de borde que no cierra
            nuevos, tapados, grandes = [], 0, 0
            copias = []                     # (vértice del que se copia todo, vértice del que se copia la UV)
            n_vert = len(pos)
            for bucle in bucles:
                if len(bucle) < 3:
                    continue
                per = sum(largo(resta(pos_s[bucle[i][0]], pos_s[bucle[(i + 1) % len(bucle)][0]])) for i in range(len(bucle)))
                if len(bucle) > max_v or per > max_p:
                    grandes += 1
                    continue
                bucle.reverse()             # la cara nueva recorre el borde al revés que la vecina
                # Vértices NUEVOS para el parche, copia de los del borde pero todos con la UV del primero: el parche sale de un
                # solo color. Con los vértices del borde tal cual, un parche entre dos islas de UV pintaba media textura en rayas.
                propios = []
                for _s, v in bucle:
                    propios.append(n_vert + len(copias))
                    copias.append((v, bucle[0][1]))
                for ia, ib, ic in orejas([pos_s[b[0]] for b in bucle]):
                    nuevos.extend((propios[ia], propios[ib], propios[ic]))
                tapados += 1
            if not medir and copias:
                for nombre, i_acc in prim["attributes"].items():
                    acc = gltf["accessors"][i_acc]
                    vista = gltf["bufferViews"][acc["bufferView"]]
                    n_comp = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[acc["type"]]
                    tam_el = n_comp * {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}[acc["componentType"]]
                    paso = vista.get("byteStride", tam_el)
                    base = vista.get("byteOffset", 0) + acc.get("byteOffset", 0)
                    trozo = bytearray()
                    for i in range(acc["count"]):
                        trozo += binario[base + i * paso:base + i * paso + tam_el]
                    for v, v_uv in copias:
                        de = v_uv if nombre.startswith("TEXCOORD") else v
                        trozo += binario[base + de * paso:base + de * paso + tam_el]
                    while len(binario) % 4:
                        binario.append(0)
                    gltf["bufferViews"].append({"buffer": 0, "byteOffset": len(binario), "byteLength": len(trozo), "target": 34962})
                    binario += trozo
                    acc["bufferView"] = len(gltf["bufferViews"]) - 1
                    acc.pop("byteOffset", None)
                    acc["count"] += len(copias)
            print("TAP malla «%s»: %d caras, %d aristas de borde; %d agujeros tapados con %d caras nuevas; %d bucles grandes (bordes de la prenda) y %d raros sin tocar" % (
                malla.get("name", "?"), len(idx) // 3, n_borde, tapados, len(nuevos) // 3, grandes, raros))
            if medir or not nuevos:
                continue
            todos = idx + nuevos
            while len(binario) % 4:
                binario.append(0)
            desde = len(binario)
            binario += struct.pack("<%dI" % len(todos), *todos)
            gltf["bufferViews"].append({"buffer": 0, "byteOffset": desde, "byteLength": len(todos) * 4, "target": 34963})
            gltf["accessors"].append({"bufferView": len(gltf["bufferViews"]) - 1, "componentType": 5125, "count": len(todos), "type": "SCALAR"})
            prim["indices"] = len(gltf["accessors"]) - 1
    if medir:
        return
    if "doble_cara" in a:
        # una prenda de una sola pared se ve también por dentro (y una cara que quedó girada no deja un hueco)
        for m in gltf.get("materials", []):
            m["doubleSided"] = True
        print("TAP materiales a doble cara: %d" % len(gltf.get("materials", [])))
    while len(binario) % 4:
        binario.append(0)
    gltf["buffers"][0]["byteLength"] = len(binario)
    texto = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    texto += b" " * ((4 - len(texto) % 4) % 4)
    fuera = bytearray(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(texto) + 8 + len(binario)))
    fuera += struct.pack("<I4s", len(texto), b"JSON") + texto + struct.pack("<I4s", len(binario), b"BIN\x00") + binario
    with open(salida, "wb") as f:
        f.write(fuera)
    print("TAP ESCRITO: %s" % salida)


main()
