"""
Desplaza de lado (X) los vértices de una prenda .glb SIN reexportarla: reescribe solo las posiciones dentro del binario.

    python tools/desplazar_prenda.py <entrada.glb> <salida.glb> dx=<metros> [z0=<z> z1=<z>] [unidad=100] [medir]

Para qué (Pablo, 12/11, capucha roja de Sumicio: «yo lo que haría sería mover ligeramente a la izquierda la capucha»): la capucha
quedaba corrida hacia la izquierda del personaje y el pelo la atravesaba por la derecha. Rehacerla con encajar_ropa.py desde el
.glb de Meshy movía también la capa, los pesos y las texturas; aquí solo cambian las X.

Qué hace: suma dx a la X de cada vértice (X negativa = la DERECHA del personaje, que mira hacia -Y; en pantalla, de frente, la
izquierda). Con z0/z1 el desplazamiento entra en rampa: nada por debajo de z0, entero por encima de z1 (así el borde de abajo de la
capucha sigue casando con el cuello de la capa). Caras, UV, normales, pesos, huesos y texturas quedan byte a byte como estaban.
La altura es el eje Y del glTF (Y arriba). `medir` no escribe: dice los límites de la malla.
Con `lado=<x0,x1,f>` el desplazamiento es entero hasta x0 y se queda en la fracción f desde x1: la pared del lado hacia el que NO
se mueve la prenda se acerca menos a la cabeza (la capucha roja con todo a -7 cm metía 87 vértices bajo la piel de la izquierda).
Con `delante=<metros> caja=<x0,x1,y0,y1,z0,z1>` (metros, ejes de Blender: delante es -Y) empuja además hacia delante lo que cae
dentro de la caja, entrando poco a poco desde sus caras: para abombar un hundimiento por el que asoma el pelo.
La capucha roja del juego (12/11) sale de la de antes (git: 64fbf0e9) con dos pasadas:
    dx=-0.07 z0=1.22 z1=1.32 unidad=100 lado=-0.12,0.02,0.0
    unidad=100 delante=0.06 caja=-0.36,0.02,-0.60,-0.12,1.46,1.76
(prueba_ropa_capa: 25 vértices de la capucha bajo la piel, 14 antes; probado y descartado: todo a -7 cm, 87; rampa de lado más
ancha -0.24..0.10, 39 y vuelve a asomar el mechón de la frente).
Vale con cualquier Python 3 (también el de Blender: blender -b --python tools/desplazar_prenda.py -- ...).
"""
import json
import struct
import sys


BORDE_CAJA = 0.06       # metros en los que el empuje de la caja entra poco a poco desde cada cara


def argumentos():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else a[1:]


def suave(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def main():
    a = argumentos()
    entrada, salida = a[0], a[1]
    dx, z0, z1, unidad = 0.0, None, None, 1.0
    delante, caja, lado = 0.0, None, None
    for x in a[2:]:
        if x.startswith("dx="):
            dx = float(x[3:])
        if x.startswith("z0="):
            z0 = float(x[3:])
        if x.startswith("z1="):
            z1 = float(x[3:])
        if x.startswith("unidad="):
            unidad = float(x[7:])
        if x.startswith("delante="):
            delante = float(x[8:])
        if x.startswith("lado="):
            lado = [float(v) for v in x[5:].split(",")]
        if x.startswith("caja="):
            caja = [float(v) for v in x[5:].split(",")]
    medir = "medir" in a
    # dx, z0 y z1 se dan en METROS; `unidad` es cuanto mide en metros una unidad de la malla (las prendas del juego: 100,
    # porque su armadura va a escala 0,01 y la malla mide 0,017 de alto para 1,70 m; con `medir unidad=100` se comprueba)
    dx /= unidad
    if z0 is not None and z1 is not None:
        z0, z1 = z0 / unidad, z1 / unidad
    with open(entrada, "rb") as f:
        datos = bytearray(f.read())
    magia, _version, _largo = struct.unpack_from("<4sII", datos, 0)
    if magia != b"glTF":
        print("DES *** no es un .glb")
        return
    largo_json, tipo = struct.unpack_from("<I4s", datos, 12)
    gltf = json.loads(datos[20:20 + largo_json].decode("utf-8"))
    ini_bin = 20 + largo_json + 8
    hechos = set()
    for malla in gltf.get("meshes", []):
        for prim in malla["primitives"]:
            i_acc = prim["attributes"]["POSITION"]
            if i_acc in hechos:
                continue
            hechos.add(i_acc)
            acc = gltf["accessors"][i_acc]
            vista = gltf["bufferViews"][acc["bufferView"]]
            paso = vista.get("byteStride", 12)
            base = ini_bin + vista.get("byteOffset", 0) + acc.get("byteOffset", 0)
            mn = [1e9] * 3
            mx = [-1e9] * 3
            movidos = 0
            for i in range(acc["count"]):
                x, y, z = struct.unpack_from("<3f", datos, base + i * paso)
                peso = 1.0
                if z0 is not None and z1 is not None:
                    peso = suave((y - z0) / (z1 - z0))
                if lado is not None:
                    # el lado contrario se mueve menos: factor 1 hasta x0 y `f` desde x1 (X de antes de mover, en metros)
                    peso *= 1.0 + (lado[2] - 1.0) * suave((x * unidad - lado[0]) / (lado[1] - lado[0]))
                if not medir and peso > 0.0 and dx != 0.0:
                    x += dx * peso
                    struct.pack_into("<f", datos, base + i * paso, x)
                    movidos += 1
                if not medir and caja is not None and delante != 0.0:
                    # caja en metros, ejes del juego en Blender: X, Y (delante = -Y = +Z del glTF), Z (alto = Y del glTF)
                    xm, ym, zm = x * unidad, -z * unidad, y * unidad
                    pc = 1.0
                    for v, a0, a1 in ((xm, caja[0], caja[1]), (ym, caja[2], caja[3]), (zm, caja[4], caja[5])):
                        pc *= suave(min(v - a0, a1 - v) / BORDE_CAJA + 0.0)
                    if pc > 0.0:
                        z += delante / unidad * pc
                        struct.pack_into("<f", datos, base + i * paso + 8, z)
                        movidos += 1
                x = struct.unpack_from("<f", datos, base + i * paso)[0]
                for k, v in enumerate((x, y, z)):
                    mn[k] = min(mn[k], v)
                    mx[k] = max(mx[k], v)
            acc["min"], acc["max"] = mn, mx
            print("DES malla «%s»: %d vertices, %d movidos; X %.3f..%.3f, alto %.3f..%.3f, fondo %.3f..%.3f" % (
                malla.get("name", "?"), acc["count"], movidos, mn[0] * unidad, mx[0] * unidad, mn[1] * unidad, mx[1] * unidad,
                mn[2] * unidad, mx[2] * unidad))
    for n in gltf.get("nodes", []):
        if "mesh" in n and any(k in n for k in ("translation", "rotation", "scale", "matrix")):
            print("DES *** OJO: el nodo de la malla «%s» trae transformacion propia: %s" % (
                n.get("name"), {k: n[k] for k in ("translation", "rotation", "scale", "matrix") if k in n}))
    if medir:
        return
    # el JSON cambia (min/max): se recoloca con su relleno a 4 bytes y se rehace la cabecera
    nuevo = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    nuevo += b" " * ((4 - len(nuevo) % 4) % 4)
    resto = bytes(datos[20 + largo_json:])
    fuera = bytearray(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(nuevo) + len(resto)))
    fuera += struct.pack("<I4s", len(nuevo), b"JSON") + nuevo + resto
    with open(salida, "wb") as f:
        f.write(fuera)
    print("DES ESCRITO: %s (dx %+.3f m)" % (salida, dx * unidad))


main()
