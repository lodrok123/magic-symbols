"""Saca UNA prenda de un .blend (retocada a mano en Blender: vértices recortados, pesos repintados) al mismo `<prenda>.json` que escribe `encajar_ropa.py`, para
montarla con `herramientas/montar_ropa_glb.gd` sobre el esqueleto de la base (una reexportación a .glb desde Blender reorienta los huesos). Blender 5.x, modo fondo:

    blender -b <archivo.blend> -P herramientas/rig/blend_a_prenda.py -- <objeto> <jugadora_base.glb> <carpeta_salida> [<nombre_prenda>]

Posiciones y normales van en el espacio de la malla de la base (Blender Z arriba -> glTF Y arriba), igual que `encajar_ropa.exportar`; los pesos son los grupos de
vértices del objeto (los 4 mayores, normalizados).
"""
import json
import os
import sys

import bpy

INFLUENCIAS: int = 4


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:]
    objeto, ruta_base, carpeta = args[0], args[1], args[2]
    nombre = args[3] if len(args) > 3 else objeto
    o = bpy.data.objects[objeto]
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=ruta_base)
    nuevos = [x for x in bpy.data.objects if x not in antes and x.type == 'MESH']
    base = max(nuevos, key=lambda x: len(x.data.vertices))
    me = o.data
    me.calc_loop_triangles()
    inv = base.matrix_world.inverted()
    norm_m = base.matrix_world.to_3x3().inverted().transposed() @ o.matrix_world.to_3x3()
    nom = {g.index: g.name for g in o.vertex_groups}
    uv_l = me.uv_layers.active.data
    normales = me.corner_normals
    claves = {}
    pos, nor, uvs, joints, weights, idx, huesos = [], [], [], [], [], [], []
    for t in me.loop_triangles:
        for lp in t.loops:
            vi = me.loops[lp].vertex_index
            n = normales[lp].vector
            uv = uv_l[lp].uv
            k = (vi, round(uv.x, 5), round(uv.y, 5), round(n.x, 3), round(n.y, 3), round(n.z, 3))
            if k not in claves:
                claves[k] = len(pos)
                p = inv @ (o.matrix_world @ me.vertices[vi].co)
                nn = (norm_m @ n).normalized()
                pos.append([p.x, p.z, -p.y])
                nor.append([nn.x, nn.z, -nn.y])
                uvs.append([uv.x, 1.0 - uv.y])
                gs = sorted(((nom[g.group], g.weight) for g in me.vertices[vi].groups if g.weight > 1e-5), key=lambda kv: -kv[1])[:INFLUENCIAS]
                tot = sum(w for _, w in gs) or 1.0
                js, ws = [], []
                for h, w in gs:
                    if h not in huesos:
                        huesos.append(h)
                    js.append(huesos.index(h))
                    ws.append(w / tot)
                while len(js) < INFLUENCIAS:
                    js.append(0)
                    ws.append(0.0)
                joints.append(js)
                weights.append(ws)
            idx.append(claves[k])
    datos = {"nombre": nombre, "huesos": huesos, "pos": pos, "nor": nor, "uv": uvs, "joints": joints, "weights": weights, "idx": idx}
    os.makedirs(carpeta, exist_ok=True)
    with open(os.path.join(carpeta, nombre + ".json"), "w") as f:
        json.dump(datos, f)
    print("EXPORTADA %s: %d vértices, %d triángulos, %d huesos" % (nombre, len(pos), len(idx) // 3, len(huesos)))


main()
