"""
Auditoria de la MALLA de una prenda (o de cualquier GLB): agujeros, jirones y pesos.

    blender.exe -b --python tools/auditar_malla_prenda.py -- <prenda.glb> [otro.glb ...]

Para qué (Pablo, 12/11, atuendo del loberno: «se ven mallas estiradas, agujeros»): decir con numeros que le pasa a la malla, sin
depender de fotos. Tres medidas, con las posiciones soldadas (las costuras de UV no cuentan como borde):
  BORDES ABIERTOS  aristas con una sola cara, agrupadas en bucles. Una prenda tiene bordes de verdad (cuello, mangas, bajo): son
                   pocos y largos. Muchos bucles pequeños son AGUJEROS en la tela.
  JIRONES          caras mucho mas largas que lo normal (arista > K veces la mediana) y vertices sueltos: picos y tiras.
  ISLAS            trozos de malla sin conexion con el resto. Una prenda de una pieza deberia ser una isla, o unas pocas grandes;
                   las islas diminutas son motas o colgajos.
  PESOS            de que huesos cuelga la prenda y cuantos vertices cuelgan de uno solo (rigidos).
"""
import sys
from collections import defaultdict

import bpy

K_LARGA = 6.0


def argumentos():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


def auditar(ruta):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=ruta)
    mallas = [o for o in bpy.data.objects if o.type == "MESH"]
    print("=== %s · %d mallas" % (ruta.replace("\\", "/").split("/")[-1], len(mallas)))
    for obj in mallas:
        me = obj.data
        mw = obj.matrix_world
        # soldar por posicion
        clave = {}
        et = []
        pos = []
        for v in me.vertices:
            p = mw @ v.co
            c = (round(p.x * 20000), round(p.y * 20000), round(p.z * 20000))
            if c not in clave:
                clave[c] = len(pos)
                pos.append(p)
            et.append(clave[c])
        caras = []
        for poly in me.polygons:
            g = [et[me.loops[li].vertex_index] for li in poly.loop_indices]
            if len(set(g)) >= 3:
                caras.append(g)
        uso = defaultdict(int)
        for g in caras:
            for i in range(len(g)):
                a, b = g[i], g[(i + 1) % len(g)]
                uso[(min(a, b), max(a, b))] += 1
        z0 = min(p.z for p in pos)
        alto = max(p.z for p in pos) - z0
        print("  %s: %d vertices (%d soldados), %d caras, alto %.3f (de z %.3f a %.3f)" % (
            obj.name, len(me.vertices), len(pos), len(caras), alto, z0, z0 + alto))

        # bordes abiertos -> bucles
        borde = [e for e, n in uso.items() if n == 1]
        mas_de_dos = sum(1 for n in uso.values() if n > 2)
        vec = defaultdict(list)
        for a, b in borde:
            vec[a].append(b)
            vec[b].append(a)
        visto = set()
        bucles = []
        for v0 in vec:
            if v0 in visto:
                continue
            pila = [v0]
            comp = []
            visto.add(v0)
            while pila:
                v = pila.pop()
                comp.append(v)
                for w in vec[v]:
                    if w not in visto:
                        visto.add(w)
                        pila.append(w)
            largo = sum((pos[a] - pos[b]).length for a, b in borde if a in set(comp)) if len(comp) < 4000 else -1.0
            cx = sum(pos[v].x for v in comp) / len(comp)
            cy = sum(pos[v].y for v in comp) / len(comp)
            cz = sum(pos[v].z for v in comp) / len(comp)
            bucles.append((len(comp), largo, cx, cy, cz))
        bucles.sort(reverse=True)
        chicos = [b for b in bucles if b[0] <= 40]
        print("  BORDES ABIERTOS: %d aristas en %d bucles; %d bucles pequeños (<= 40 vertices: agujeros); aristas con mas de 2 caras: %d" % (
            len(borde), len(bucles), len(chicos), mas_de_dos))
        for n, largo, cx, cy, cz in bucles[:30]:
            print("      bucle de %4d vertices, perimetro %.3f, centro (x %+.3f, y %+.3f, z %.3f; alto %.0f %%)" % (
                n, largo, cx, cy, cz, 100.0 * (cz - z0) / max(alto, 1e-6)))
        # donde estan los agujeros pequeños, por franjas de altura
        if chicos:
            franjas = defaultdict(int)
            for n, largo, cx, cy, cz in chicos:
                franjas[int(10.0 * (cz - z0) / max(alto, 1e-6))] += 1
            print("      agujeros pequeños por altura (decima del alto: cuantos): " + "  ".join(
                "%d0%%: %d" % (k, franjas[k]) for k in sorted(franjas)))

        # jirones: aristas largas
        largos = sorted((pos[a] - pos[b]).length for a, b in uso)
        med = largos[len(largos) // 2]
        n_largas = sum(1 for x in largos if x > med * K_LARGA)
        print("  JIRONES: arista mediana %.4f; %d aristas (%.2f %%) de mas de %.0f veces la mediana; la mas larga %.3f (%.0f veces)" % (
            med, n_largas, 100.0 * n_largas / len(largos), K_LARGA, largos[-1], largos[-1] / max(med, 1e-9)))

        # islas
        padre = list(range(len(pos)))

        def raiz(i):
            while padre[i] != i:
                padre[i] = padre[padre[i]]
                i = padre[i]
            return i
        for a, b in uso:
            ra, rb = raiz(a), raiz(b)
            if ra != rb:
                padre[ra] = rb
        tam = defaultdict(int)
        usados = set()
        for g in caras:
            usados.update(g)
        for v in usados:
            tam[raiz(v)] += 1
        islas = sorted(tam.values(), reverse=True)
        print("  ISLAS: %d (%d de menos de 30 vertices); las mayores: %s" % (
            len(islas), sum(1 for t in islas if t < 30), islas[:6]))

        # pesos
        if obj.vertex_groups:
            nombres = [g.name for g in obj.vertex_groups]
            suma = defaultdict(float)
            rigidos = 0
            for v in me.vertices:
                gs = [(g.weight, nombres[g.group]) for g in v.groups if g.weight > 0.001]
                if len(gs) == 1:
                    rigidos += 1
                for w, n in gs:
                    suma[n] += w
            tot = sum(suma.values())
            top = sorted(suma.items(), key=lambda x: -x[1])[:8]
            print("  PESOS: %.0f %% de los vertices cuelga de UN solo hueso; reparto: %s" % (
                100.0 * rigidos / len(me.vertices), "  ".join("%s %.0f %%" % (n.replace("mixamorig:", ""), 100.0 * w / tot) for n, w in top)))


for r in argumentos():
    auditar(r)
