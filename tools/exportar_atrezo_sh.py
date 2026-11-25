# -*- coding: utf-8 -*-
"""Exporta cada OBJETO PEQUEÑO (atrezo y vegetación) del pack «SH assets.blend» a su propio .glb, TAL CUAL (sin optimizar).

Prueba de rendimiento (25/11/2026). Igual que tools/montar_casa_sh.py: la geometría es la del pack con sus modificadores,
lattices y curvas aplicados; cada pieza sigue siendo un objeto suelto; la madera, la piedra y el metal procedurales se
sustituyen por un color plano con el mismo nombre (lo procedural no viaja a glTF). Las plantas conservan sus texturas.
Cada objeto queda centrado en planta y apoyado en el suelo. Escribe también <carpeta>/atrezo_sh.json con sus cifras.

Uso (no modifica el .blend):
  "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b "C:\\Users\\pablo\\Downloads\\SH assets.blend" --python E:\\magic-symbols\\tools\\exportar_atrezo_sh.py -- E:\\magic-symbols\\arte\\sh_assets\\atrezo
"""
import bpy, sys, os, json
from mathutils import Vector

CARPETA = sys.argv[sys.argv.index("--") + 1]
os.makedirs(CARPETA, exist_ok=True)
D = bpy.data

# nombre en el juego -> (categoría, unidad del pack: objeto raíz o colección entera)
OBJETOS = {
    "barril": ("contenedor", "Empty.Barrel"),
    "barril_bajo": ("contenedor", "Empty.Barrel.001"),
    "arcon": ("contenedor", "Crate"),
    "cajon_abierto": ("contenedor", "Crate.003"),
    "caja_cerrada": ("contenedor", "EmptyCrateBoxA"),
    "caja_abierta": ("contenedor", "EmptyCrateBoxB"),
    "troncos": ("contenedor", "Empty_Logs"),
    "farol_pared": ("adorno", "EmptyLampHolder"),
    "tinaja_colgante": ("adorno", "EmptyHangingPot"),
    "veleta": ("adorno", "WindVane"),
    "cartel": ("adorno", "Plane.033"),
    "cadena": ("adorno", "COL:chain"),
    "tinaja_a": ("ceramica", "PotA"), "tinaja_b": ("ceramica", "PotB"), "tinaja_c": ("ceramica", "PotC"),
    "tinaja_d": ("ceramica", "PotD"), "tinaja_e": ("ceramica", "PotE"), "tinaja_f": ("ceramica", "PotF"),
    "cuenco_d2": ("ceramica", "PotD.002"), "cuenco_d3": ("ceramica", "PotD.003"),
    "piedra_rota_1": ("piedra", "damaged_stone"), "piedra_rota_2": ("piedra", "damaged_stone.001"),
    "piedra_rota_3": ("piedra", "damaged_stone.002"), "piedra_rota_4": ("piedra", "damaged_stone.003"),
    "flor_amarilla": ("vegetacion", "Yellow Flower_Baked"), "flor_blanca": ("vegetacion", "White Flower_Baked"),
    "rosal": ("vegetacion", "Rose._Baked"), "matojo": ("vegetacion", "3PlansGP.002_Baked"),
    "enredadera": ("vegetacion", "vines_Plant_Baked"),
    "hierba_1": ("vegetacion", "BagaPie_Grass_001_Baked"), "hierba_2": ("vegetacion", "BagaPie_Grass_007_Baked"),
    "planta_1": ("vegetacion", "BagaPie_Plant_044_Baked"), "planta_2": ("vegetacion", "BagaPie_Plant_140_Baked"),
    "planta_3": ("vegetacion", "BagaPie_Plant_157_Baked"),
    "planta_c1": ("vegetacion", "Cylinder.001_Baked"), "planta_c2": ("vegetacion", "Cylinder.003_Baked"),
    "planta_c3": ("vegetacion", "Cylinder.005_Baked"), "planta_c4": ("vegetacion", "Plane.019_Baked"),
    "planta_c5": ("vegetacion", "Plane.021_Baked"), "planta_c6": ("vegetacion", "Plane.022_Baked"),
    "arbusto_1": ("vegetacion", "bush1"), "arbusto_2": ("vegetacion", "bush2"), "arbusto_3": ("vegetacion", "bush3"),
}
# los 20 cántaros pequeños del Pot Generator (colección Various)
for i, n in enumerate(sorted(o.name for o in D.collections["Various"].objects if o.name.startswith("Pot Generator."))):
    OBJETOS["cantaro_%02d" % (i + 1)] = ("ceramica", n)

COLORES = {
    "wood": (0.78, 0.68, 0.52), "Wall": (0.80, 0.86, 0.90), "Rooftile": (0.62, 0.26, 0.30),
    "ArcBrickStone": (0.62, 0.66, 0.72), "BrickStone": (0.55, 0.32, 0.32), "BigBrickStone": (0.62, 0.66, 0.58),
    "LargeBrickStone": (0.62, 0.66, 0.60), "StoneFence": (0.50, 0.46, 0.55), "Metal": (0.30, 0.30, 0.33),
    "windowglass": (0.10, 0.20, 0.22), "Pots": (0.75, 0.60, 0.55), "Rope": (0.60, 0.45, 0.30),
    "Lamp": (0.80, 0.85, 0.95), "Sign": (0.70, 0.60, 0.45),
}
TRABAJO = D.collections.new("ATREZO_EXPORT")
bpy.context.scene.collection.children.link(TRABAJO)


def _arbol(o):
    r = [o]
    for c in o.children:
        r += _arbol(c)
    return r


def _unidad(clave):
    if clave.startswith("COL:"):
        return list(D.collections[clave[4:]].objects)
    return _arbol(D.objects[clave])


_hechos = set()


def _plano(m):
    col = next((c for k, c in COLORES.items() if m.name.startswith(k)), None)
    if col is None or m.name in _hechos:
        return
    _hechos.add(m.name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    bsdf.inputs["Base Color"].default_value = (*col, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.8
    if m.name.startswith("Metal"):
        bsdf.inputs["Metallic"].default_value = 0.6


dg = bpy.context.evaluated_depsgraph_get()
resumen = []
for nombre, (cat, clave) in OBJETOS.items():
    objs = [o for o in _unidad(clave) if o.type in {"MESH", "CURVE"}]
    nuevos = []
    for o in objs:
        me = D.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        if len(me.polygons) == 0:
            continue
        c = D.objects.new(o.name, me)
        TRABAJO.objects.link(c)
        c.matrix_world = o.matrix_world.copy()
        nuevos.append(c)
    bpy.context.view_layer.update()
    pts = [c.matrix_world @ Vector(v) for c in nuevos for v in c.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centro = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    tris = 0
    mats = set()
    for c in nuevos:
        c.matrix_world.translation -= centro
        c.data.calc_loop_triangles()
        tris += len(c.data.loop_triangles)
        for m in c.data.materials:
            if m:
                _plano(m)
                mats.add(m.name)
    bpy.ops.object.select_all(action="DESELECT")
    for c in nuevos:
        c.select_set(True)
    bpy.context.view_layer.objects.active = nuevos[0]
    ruta = os.path.join(CARPETA, "sh_%s.glb" % nombre)
    bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                              export_animations=False, export_lights=False, export_cameras=False)
    d = mx - mn
    resumen.append({"nombre": nombre, "categoria": cat, "pack": clave, "piezas": len(nuevos), "triangulos": tris,
                    "materiales": len(mats), "x": round(d.x, 2), "y": round(d.y, 2), "z": round(d.z, 2),
                    "kb": round(os.path.getsize(ruta) / 1024)})
    for c in nuevos:
        D.objects.remove(c)
    print("ATREZO", nombre, tris, len(nuevos))

with open(os.path.join(CARPETA, "atrezo_sh.json"), "w", encoding="utf-8") as f:
    json.dump(resumen, f, ensure_ascii=False, indent=1)
print("HECHO", len(resumen))
