"""
Separa el ORBE de cristal del baston del chaman en una malla propia (para teñirlo desde el juego), en Blender (modo fondo):

    blender.exe -b --python tools/separar_orbe_baston.py -- [entrada.glb] [salida.glb]

Por defecto arte/modelos/baston_chaman.glb -> arte/modelos/baston_chaman_equipo.glb (el original queda intacto). El baston de Meshy es UNA malla con UNA textura donde el orbe es una zona
blanca; se toman las caras que (a) caen dentro de la esfera del orbe (centro ORBE_CENTRO, radio ORBE_RADIO, medidos sobre el GLB: 0,38 sobre el centro del baston, ~0,048 de radio) y (b) tienen un
color de textura casi blanco y sin saturar. Quedan dos objetos, «Baston» y «Orbe», con el mismo material y la misma orientacion y origen (centro del baston) que el original.
"""
import os
import sys
import bpy
from mathutils import Vector

ORBE_CENTRO = Vector((-0.001, -0.008, 0.380))   # en Blender (z arriba); en el GLB es +Y
ORBE_RADIO = 0.062                              # las caras con algun vertice a mas de esto del centro no son del orbe (las astas lo tocan)
BLANCO_MIN = 0.55                               # el minimo de r, g, b del color medio de la cara
SATURACION_MAX = 0.12


def argumentos():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


def main():
    a = argumentos()
    r = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    entrada = a[0] if len(a) > 0 else os.path.join(r, "arte", "modelos", "baston_chaman.glb")
    salida = a[1] if len(a) > 1 else os.path.join(r, "arte", "modelos", "baston_chaman_equipo.glb")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=entrada)
    o = [x for x in bpy.context.scene.objects if x.type == "MESH"][0]
    me = o.data
    img = None
    for m in me.materials:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE":
                img = n.image
                break
    W, H = img.size
    px = list(img.pixels)
    uv = me.uv_layers.active.data

    def color(u, v):
        x = min(W - 1, max(0, int(u * W)))
        y = min(H - 1, max(0, int(v * H)))
        i = (y * W + x) * 4
        return px[i], px[i + 1], px[i + 2]

    n_orbe = 0
    elegidas = []
    for p in me.polygons:
        cs = [color(*uv[li].uv) for li in p.loop_indices]
        c = [sum(x[i] for x in cs) / len(cs) for i in range(3)]
        dentro = all((me.vertices[v].co - ORBE_CENTRO).length <= ORBE_RADIO for v in p.vertices)
        elegida = bool(dentro and min(c) > BLANCO_MIN and max(c) - min(c) < SATURACION_MAX)
        elegidas.append(elegida)
        n_orbe += 1 if elegida else 0
    print("caras del orbe: %d de %d" % (n_orbe, len(me.polygons)))
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    for v in me.vertices:
        v.select = False
    for e in me.edges:
        e.select = False
    for p, ok in zip(me.polygons, elegidas):
        p.select = ok
        if ok:
            for v in p.vertices:
                me.vertices[v].select = True
    for e in me.edges:
        e.select = me.vertices[e.vertices[0]].select and me.vertices[e.vertices[1]].select
    bpy.context.tool_settings.mesh_select_mode = (False, False, True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    objs = [x for x in bpy.context.scene.objects if x.type == "MESH"]
    objs.sort(key=lambda x: len(x.data.polygons))
    orbe, baston = objs[0], objs[-1]
    orbe.name = "Orbe"
    baston.name = "Baston"
    print("Baston %d caras, Orbe %d caras" % (len(baston.data.polygons), len(orbe.data.polygons)))
    for im in bpy.data.images:
        if im.size[0] > 1024:
            im.scale(1024, 1024)      # las texturas del juego van a 1024
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=salida, export_format="GLB", use_selection=True, export_animations=False, export_yup=True,
                              export_image_format="JPEG", export_jpeg_quality=85)
    print("exportado", salida)


main()
