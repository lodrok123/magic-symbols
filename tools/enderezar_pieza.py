"""
Endereza una pieza larga (bastón, cruz, lanza) cuyo palo NO va por el eje vertical del GLB:

    blender.exe -b --python tools/enderezar_pieza.py -- <entrada.glb> <salida.glb> [fraccion_mango]

Para qué: la cruz de la Santa Compaña salía de Meshy con el mango a 38° de la vertical dentro de su propio archivo. Colgada de
la mano eso no se nota (va torcida como todo lo demás), pero en cuanto se la planta en el suelo con PiezaApoyada3D, que la pone
vertical, lo que se ve torcido es el palo: la pieza está recta y el palo dentro de ella no. Medirlo costó varias pasadas, porque
desde fuera parece un fallo del rig o del agarre.

Qué hace: ajusta una recta a los centros de las rebanadas horizontales de la MITAD BAJA (el mango, sin el travesaño), gira la
malla para llevar esa recta a la vertical, y la deja centrada en planta y apoyada en el suelo, como la dejó separar_piezas.py.
"""
import math
import sys

import bpy
from mathutils import Vector

FRACCION_MANGO = 0.55     # hasta qué altura se considera mango (por encima está el travesaño y falsearía la recta)
N_REBANADAS = 9


def argumentos():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


def eje_del_mango(vs, z0, alto, hasta):
    """Dirección del mango: recta por los centros de las rebanadas horizontales de la parte baja."""
    centros = []
    for i in range(N_REBANADAS):
        f = (i + 0.5) / N_REBANADAS * hasta
        z = z0 + alto * f
        s = [v for v in vs if abs(v.z - z) < alto * 0.02]
        if len(s) < 5:
            continue
        centros.append(Vector((sum(v.x for v in s) / len(s), sum(v.y for v in s) / len(s), z)))
    if len(centros) < 2:
        return None
    medio = sum(centros, Vector()) / len(centros)
    # dirección principal: la que más varianza explica, que con un palo es el propio palo
    mejor = (centros[-1] - centros[0])
    return mejor.normalized() if mejor.length > 1e-6 else None


def main():
    a = argumentos()
    entrada, salida = a[0], a[1]
    hasta = float(a[2]) if len(a) > 2 else FRACCION_MANGO

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=entrada)
    obj = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if obj.parent:
        bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    vs = [v.co.copy() for v in obj.data.vertices]
    z0 = min(v.z for v in vs)
    alto = max(v.z for v in vs) - z0
    eje = eje_del_mango(vs, z0, alto, hasta)
    if eje is None:
        print("no se pudo medir el mango; se deja como está")
        return
    ang = math.degrees(eje.angle(Vector((0.0, 0.0, 1.0))))
    print("eje del mango: %s   inclinación %.1f°" % (tuple(round(c, 4) for c in eje), ang))
    if ang > 0.5:
        giro = eje.rotation_difference(Vector((0.0, 0.0, 1.0))).to_matrix()
        for v in obj.data.vertices:
            v.co = giro @ v.co
        obj.data.update()
        print("enderezada")

    # otra vez centrada en planta y apoyada en el suelo (Blender: suelo XY, alto Z)
    vs = [v.co for v in obj.data.vertices]
    x0, x1 = min(v.x for v in vs), max(v.x for v in vs)
    y0, y1 = min(v.y for v in vs), max(v.y for v in vs)
    z0 = min(v.z for v in vs)
    d = Vector((-(x0 + x1) / 2.0, -(y0 + y1) / 2.0, -z0))
    for v in obj.data.vertices:
        v.co += d
    obj.data.update()
    vs = [v.co for v in obj.data.vertices]
    print("resultado: planta %.3f x %.3f   ALTO %.3f"
          % (max(v.x for v in vs) - min(v.x for v in vs), max(v.y for v in vs) - min(v.y for v in vs),
             max(v.z for v in vs) - min(v.z for v in vs)))

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=salida, export_format="GLB", use_selection=True,
                              export_animations=False, export_image_format="JPEG", export_yup=True)
    print("ESCRITO: %s" % salida)


main()
