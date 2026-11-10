"""
Parte un GLB de varios objetos sueltos (una «lamina» de Meshy: reliquias, utiles, adornos) en un GLB por objeto:

    blender.exe -b --python tools/separar_piezas.py -- <entrada.glb> <carpeta_salida> [prefijo] [umbral]

Meshy entrega la lamina como UNA malla partida en cientos de trozos (las reliquias: 12 195 vertices en 579 trozos), asi que
separar por islas conectadas no sirve. Aqui los trozos se agrupan por CERCANIA: dos trozos cuyas cajas se tocan (hasta `umbral`
unidades) son del mismo objeto. Cada grupo sale centrado en x/z y con su base en y = 0, que es como `Equipo3D` espera una pieza
de mano, y con el nombre <prefijo><n> ordenado de mayor a menor.

Imprime la medida de cada objeto para poder reconocerlos y renombrarlos despues.
"""
import os
import sys

import bpy
from mathutils import Vector

UMBRAL = 0.02        # unidades del GLB; dos trozos a menos de esto son el mismo objeto
MIN_VERTICES = 24    # un grupo con menos que esto es ruido y se descarta


def argumentos():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


def cajas_de(objs):
    cajas = []
    for o in objs:
        vs = [o.matrix_world @ v.co for v in o.data.vertices]
        cajas.append((Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))),
                      Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))))
    return cajas


def se_tocan(a, b, u):
    return (a[0].x - u <= b[1].x and b[0].x - u <= a[1].x
            and a[0].y - u <= b[1].y and b[0].y - u <= a[1].y
            and a[0].z - u <= b[1].z and b[0].z - u <= a[1].z)


def agrupar(cajas, u):
    """Union-find sobre los trozos: devuelve la lista de grupos (indices)."""
    padre = list(range(len(cajas)))

    def raiz(i):
        while padre[i] != i:
            padre[i] = padre[padre[i]]
            i = padre[i]
        return i

    for i in range(len(cajas)):
        for j in range(i + 1, len(cajas)):
            if se_tocan(cajas[i], cajas[j], u):
                ri, rj = raiz(i), raiz(j)
                if ri != rj:
                    padre[ri] = rj
    grupos = {}
    for i in range(len(cajas)):
        grupos.setdefault(raiz(i), []).append(i)
    return list(grupos.values())


def main():
    a = argumentos()
    entrada = a[0]
    carpeta = a[1]
    prefijo = a[2] if len(a) > 2 else "pieza_"
    u = float(a[3]) if len(a) > 3 else UMBRAL

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=entrada)
    obj = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if obj.parent:
        bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    print("malla de entrada: %d vertices" % len(obj.data.vertices))

    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    trozos = [o for o in bpy.data.objects if o.type == "MESH"]
    print("trozos sueltos: %d" % len(trozos))

    cajas = cajas_de(trozos)
    grupos = agrupar(cajas, u)
    grupos = [g for g in grupos if sum(len(trozos[i].data.vertices) for i in g) >= MIN_VERTICES]
    grupos.sort(key=lambda g: -sum(len(trozos[i].data.vertices) for i in g))
    print("objetos encontrados: %d (umbral %.3f)" % (len(grupos), u))

    os.makedirs(carpeta, exist_ok=True)
    for n, g in enumerate(grupos, 1):
        bpy.ops.object.select_all(action="DESELECT")
        for i in g:
            trozos[i].select_set(True)
        act = trozos[g[0]]
        bpy.context.view_layer.objects.active = act
        if len(g) > 1:
            bpy.ops.object.join()
        pieza = bpy.context.view_layer.objects.active
        vs = [pieza.matrix_world @ v.co for v in pieza.data.vertices]
        x0, x1 = min(v.x for v in vs), max(v.x for v in vs)
        y0, y1 = min(v.y for v in vs), max(v.y for v in vs)
        z0, z1 = min(v.z for v in vs), max(v.z for v in vs)
        # Centrado en planta y apoyado en el suelo. OJO: dentro de Blender el suelo es XY y el alto es Z (el importador de glTF
        # pasa el Y-up del GLB a Z-up); al exportar con export_yup vuelve a Y-up, que es lo que espera Equipo3D.
        d = Vector((-(x0 + x1) / 2.0, -(y0 + y1) / 2.0, -z0))
        for v in pieza.data.vertices:
            v.co += d
        pieza.data.update()
        nombre = "%s%d" % (prefijo, n)
        pieza.name = nombre
        salida = os.path.join(carpeta, nombre + ".glb")
        bpy.ops.object.select_all(action="DESELECT")
        pieza.select_set(True)
        bpy.context.view_layer.objects.active = pieza
        bpy.ops.export_scene.gltf(filepath=salida, export_format="GLB", use_selection=True,
                                  export_animations=False, export_image_format="JPEG", export_yup=True)
        print("  %-14s %5d v  trozos %3d  planta %.3f x %.3f, ALTO %.3f  -> %s"
              % (nombre, len(vs), len(g), x1 - x0, y1 - y0, z1 - z0, os.path.basename(salida)))


main()
