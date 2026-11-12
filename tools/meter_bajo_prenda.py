"""
Mete una prenda de DENTRO por debajo de una de FUERA en una franja de altura, sin recortarla:

    blender.exe -b --python tools/meter_bajo_prenda.py -- <dentro.glb> <fuera.glb> <salida.glb> <z_min> <z_max> [margen=0.012] [z_interior=<z>] [medir]

Para qué (Pablo, 12/11): la túnica del loberno que encajó él en Blender es más estrecha de cadera que las mallas del juego, que se
habían encajado para la túnica anterior, y las mallas asomaban por la cintura en bultos oscuros a los lados del cinturón.
Recortar las mallas por encima de la cadera dejaba un hueco a la vista por debajo del faldón al rodar; aquí se quedan enteras.

Qué hace: en la franja [z_min, z_max] reparte el espacio alrededor del eje del cuerpo en celdas (sectores de ángulo × rebanadas de
altura). En cada celda mide el radio MÁS GRANDE de la prenda de fuera (su pared más EXTERIOR) y, a cada vértice de la de dentro
que quede más lejos del eje que ese radio menos el margen, lo acerca al eje hasta ahí. La pared exterior y no la interior
(probado el 12/11): una túnica tiene varias capas, y unas mallas metidas entre dos de ellas no se ven; con la interior se
contaban 1988 vértices «por fuera» y se habrían aplastado los muslos bajo el faldón sin necesidad. Con una rampa en los bordes de la franja
para que no haga escalón. Solo mueve posiciones: caras, UV, pesos y esqueleto quedan como estaban.
`medir` no escribe nada: dice cuántos vértices asoman y cuánto.

OJO con `z_interior` (12/11, túnica del loberno): tiene que quedar POR DEBAJO del cinturón, no por encima. Con 0.78 el cinturón
(z 0,63 a 0,745) caía en la zona de «pared exterior», que en la cadera izquierda es el manto que cuelga lejos, y las mallas
salían por delante del cinturón en una mancha oscura que se tomó por un hueco de la túnica. Las mallas del juego se hicieron con
    <mallas originales> ropa_tunica_lobo.glb ropa_piernas_lobo.glb 0.44 1.02 z_interior=0.57
"""
import math
import sys

import bpy

SECTORES = 48
ALTO_CELDA = 0.015
VENTANA = 5             # sectores a cada lado (5 de 48 = 37 grados) de los que se toma el radio en la franja cenida
F_RAMPA = 0.20          # fracción de la franja, en cada borde, en la que el efecto entra poco a poco


def argumentos():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


def malla_principal(ruta):
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=ruta)
    nuevos = [o for o in bpy.data.objects if o not in antes]
    mallas = [o for o in nuevos if o.type == "MESH" and o.vertex_groups]
    obj = max(mallas, key=lambda o: len(o.data.vertices))
    return obj, nuevos


def main():
    a = argumentos()
    ruta_d, ruta_f, salida = a[0], a[1], a[2]
    z_min, z_max = float(a[3]), float(a[4])
    margen = 0.012
    medir = "medir" in a
    z_interior = 1e9
    for x in a[5:]:
        if x.startswith("margen="):
            margen = float(x.split("=")[1])
        if x.startswith("z_interior="):
            z_interior = float(x.split("=")[1])

    bpy.ops.wm.read_factory_settings(use_empty=True)
    fuera, nuevos_f = malla_principal(ruta_f)
    pts_f = [fuera.matrix_world @ v.co for v in fuera.data.vertices]
    # los vértices de fuera se densifican con los puntos medios de sus aristas: una pared de caras grandes no deja celdas vacías
    me_f = fuera.data
    for e in me_f.edges:
        pts_f.append((pts_f[e.vertices[0]] + pts_f[e.vertices[1]]) * 0.5)
    en_franja = [p for p in pts_f if z_min - ALTO_CELDA <= p.z <= z_max + ALTO_CELDA]
    if not en_franja:
        print("MET *** la prenda de fuera no tiene nada entre %.2f y %.2f" % (z_min, z_max))
        return
    cx = sum(p.x for p in en_franja) / len(en_franja)
    cy = sum(p.y for p in en_franja) / len(en_franja)
    n_z = int(math.ceil((z_max - z_min) / ALTO_CELDA)) + 2

    def celda(p):
        ang = math.atan2(p.y - cy, p.x - cx)
        s = int((ang + math.pi) / (2.0 * math.pi) * SECTORES) % SECTORES
        k = int((p.z - (z_min - ALTO_CELDA)) / ALTO_CELDA)
        return s, k

    r_min = {}          # la pared mas EXTERIOR de cada celda
    r_int = {}          # y la mas INTERIOR
    for p in en_franja:
        c = celda(p)
        r = math.hypot(p.x - cx, p.y - cy)
        if c not in r_min or r > r_min[c]:
            r_min[c] = r
        if c not in r_int or r < r_int[c]:
            r_int[c] = r
    print("MET eje del cuerpo en la franja (%.3f, %.3f); %d celdas con pared de fuera de %d posibles" % (cx, cy, len(r_min), SECTORES * n_z))

    def radio_fuera(p):
        """El radio interior de la prenda de fuera en la celda de p; si la celda está vacía, el menor de las vecinas."""
        s, k = celda(p)
        # Por encima de z_interior (la franja CENIDA: el cinturon) manda la pared interior: ahi la prenda de fuera va pegada al
        # cuerpo y lo que la atraviesa se ve, aunque mas afuera cuelgue otra capa suya (el manto sobre el cinturon).
        tabla = r_int if p.z >= z_interior else r_min
        if tabla is r_int:
            # En la franja cenida se toma el radio mas pequeño de una VENTANA de sectores a cada lado, no el de la celda sola. El
            # cinturon de la tunica del loberno tiene un HUECO en la cadera izquierda, donde cruza el manto: en esas celdas la pared
            # «interior» es el manto, que cuelga lejos, y las mallas no se movian y abultaban por el hueco. Con la ventana cogen el
            # radio del cinturon de los tramos vecinos y quedan a ras por dentro.
            vent = [r_int[((s + d) % SECTORES, kk)] for d in range(-VENTANA, VENTANA + 1) for kk in (k - 1, k, k + 1)
                    if ((s + d) % SECTORES, kk) in r_int]
            return min(vent) if vent else None
        if (s, k) in tabla:
            return tabla[(s, k)]
        vec = [tabla[(ss % SECTORES, kk)] for ss in (s - 1, s, s + 1) for kk in (k - 1, k, k + 1) if (ss % SECTORES, kk) in tabla]
        return (min(vec) if tabla is r_int else max(vec)) if vec else None

    for o in nuevos_f:
        bpy.data.objects.remove(o, do_unlink=True)

    dentro, nuevos_d = malla_principal(ruta_d)
    mw = dentro.matrix_world
    mwi = mw.inverted()
    asoman = movidos = 0
    peor = 0.0
    por_altura = {}         # decima de metro -> [vertices de la franja, los que asoman, el que mas asoma]
    rampa = (z_max - z_min) * F_RAMPA
    for v in dentro.data.vertices:
        p = mw @ v.co
        if p.z < z_min or p.z > z_max:
            continue
        rf = radio_fuera(p)
        if rf is None:
            continue
        r = math.hypot(p.x - cx, p.y - cy)
        tope = rf - margen
        d = por_altura.setdefault(int(p.z * 20.0), [0, 0, 0.0])
        d[0] += 1
        if r > rf:
            d[1] += 1
            d[2] = max(d[2], r - rf)
        if r <= tope or r < 1e-6:
            continue
        if r > rf:
            asoman += 1
        peor = max(peor, r - tope)
        # rampa en los bordes de la franja
        t = min(1.0, (p.z - z_min) / rampa, (z_max - p.z) / rampa) if rampa > 0 else 1.0
        t = max(0.0, t)
        t = t * t * (3.0 - 2.0 * t)
        nuevo_r = r + (tope - r) * t
        k = nuevo_r / r
        p.x = cx + (p.x - cx) * k
        p.y = cy + (p.y - cy) * k
        v.co = mwi @ p
        movidos += 1
    dentro.data.update()
    print("MET %d vertices de la prenda de dentro quedaban POR FUERA de la de fuera; %d se acercan al eje (el que mas, %.3f) con margen %.3f" % (
        asoman, movidos, peor, margen))
    for k in sorted(por_altura, reverse=True):
        d = por_altura[k]
        print("MET   altura %.2f-%.2f: %4d vertices, %4d asoman (el que mas, %.3f)" % (k / 20.0, (k + 1) / 20.0, d[0], d[1], d[2]))
    if medir:
        return

    # se exporta la prenda con su armadura; lo demás que traía el .glb (la Icosphere suelta del montaje) se queda fuera
    arm = None
    for m in dentro.modifiers:
        if m.type == "ARMATURE":
            arm = m.object
    bpy.ops.object.select_all(action="DESELECT")
    dentro.select_set(True)
    if arm is not None:
        arm.select_set(True)
        bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=salida, export_format="GLB", use_selection=True, export_animations=False, export_skins=True,
                              export_image_format="JPEG", export_yup=True)
    print("MET ESCRITO: %s" % salida)


main()
