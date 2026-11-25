# -*- coding: utf-8 -*-
"""Monta UNA casa con las piezas del pack «SH assets.blend» TAL CUAL (sin optimizar) y la exporta a glTF.

Es una prueba de rendimiento (25/11/2026): la geometría es la del pack, con sus modificadores aplicados, cada pieza
sigue siendo un objeto suelto y se conserva el número de materiales. Lo único que cambia son los materiales: la
madera y la piedra del pack son procedurales y no viajan a glTF, así que se sustituyen por un color plano con el
MISMO nombre (mismo número de superficies, mismas llamadas de dibujo).

Uso (no modifica el .blend: trabaja en memoria y no guarda):
  "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b "C:\\Users\\pablo\\Downloads\\SH assets.blend" --python E:\\magic-symbols\\tools\\montar_casa_sh.py -- E:\\magic-symbols\\arte\\sh_assets\\casa_sh_sin_optimizar.glb

Planta: 8 × 4 m (Blender: X ancho, Y fondo, la fachada mira a -Y), muros de 4 m, tejado a dos aguas de tejas sueltas.

Opciones de OPTIMIZACIÓN (después de la ruta de salida):
  --diezmar 0.5   cada pieza pasa por un Decimate (colapso) que deja esa fracción de triángulos (0.5 = la mitad)
  --unir          al final se unen todas las piezas en UN objeto (una superficie por material)
Ejemplo de la casa optimizada:  ... -- E:\\magic-symbols\\arte\\sh_assets\\casa_sh_d50_unida.glb --diezmar 0.5 --unir
"""
import bpy, sys, math, os, json
from mathutils import Vector, Matrix

ARGS = sys.argv[sys.argv.index("--") + 1:]
SALIDA = ARGS[0]
DIEZMAR = float(ARGS[ARGS.index("--diezmar") + 1]) if "--diezmar" in ARGS else 1.0
UNIR = "--unir" in ARGS
MIN_TRIS_DIEZMAR = 64     # las piezas más pequeñas que esto se dejan como están (no ganan nada y se deforman)
os.makedirs(os.path.dirname(SALIDA), exist_ok=True)
D = bpy.data
CASA = D.collections.new("CASA_PRUEBA")
bpy.context.scene.collection.children.link(CASA)
nuevos = []


def _arbol(o):
    r = [o]
    for c in o.children:
        r += _arbol(c)
    return r


_congeladas = {}   # nombre del objeto original -> malla con sus modificadores aplicados (se comparte entre copias)


def _congelar(o):
    """Malla del objeto con modificadores, lattices y curvas ya aplicados, evaluada en su sitio original."""
    if o.name not in _congeladas:
        dg = bpy.context.evaluated_depsgraph_get()
        me = D.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        if DIEZMAR < 1.0:
            me = _diezmar(me)
        _congeladas[o.name] = me
    return _congeladas[o.name]


def _diezmar(me):
    """Decimate por colapso sobre una malla suelta: devuelve una malla nueva con DIEZMAR de sus triángulos."""
    me.calc_loop_triangles()
    if len(me.loop_triangles) < MIN_TRIS_DIEZMAR:
        return me
    tmp = D.objects.new("_diezmar", me)
    CASA.objects.link(tmp)
    mod = tmp.modifiers.new("d", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = DIEZMAR
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    nueva = D.meshes.new_from_object(tmp.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    D.objects.remove(tmp)
    return nueva


def _copiar(objs):
    """Copia de una unidad: un objeto por cada pieza con malla del pack (como en el pack: sin unir), bajo un empty nuevo."""
    raiz = D.objects.new("pieza", None)
    CASA.objects.link(raiz)
    nuevos.append(raiz)
    for o in objs:
        if o.type not in {"MESH", "CURVE"}:
            continue
        me = _congelar(o)
        if len(me.polygons) == 0:
            continue
        c = D.objects.new(o.name, me)
        CASA.objects.link(c)
        nuevos.append(c)
        c.parent = raiz
        c.matrix_basis = o.matrix_world.copy()
    return raiz


def unidad(nombre):
    """Objetos de una unidad: la raíz y sus hijos, o toda una colección de muro (wallN)."""
    if nombre in D.collections:
        return list(D.collections[nombre].objects)
    return _arbol(D.objects[nombre])


def caja(raiz):
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in _arbol(raiz):
        if o.type in {"MESH", "CURVE"}:
            ev = o.evaluated_get(dg)
            pts += [ev.matrix_world @ Vector(v) for v in ev.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def poner(nombre, x, y, z, giro=0.0, incl=0.0):
    """Copia la unidad y la coloca: (x, y) es el centro de su caja en planta y z su base.
    giro en grados sobre Z; incl en radianes sobre X (se aplica antes del giro)."""
    r = _copiar(unidad(nombre))
    r.rotation_euler = (incl, 0.0, math.radians(giro))
    mn, mx = caja(r)
    c = (mn + mx) * 0.5
    r.location += Vector((x - c.x, y - c.y, z - mn.z))
    return r


# --- muros: 8 paneles (2 y 4 m) alrededor de una planta de 8 × 4 m
poner("wall1", 2.0, 0.0, 0.0)              # fachada, izquierda
poner("wall4", 7.0, 0.0, 0.0)              # fachada, derecha (hueco de puerta entre 4 y 6)
poner("wall2", 2.0, 4.0, 0.0, 180)         # trasera
poner("wall1", 6.0, 4.0, 0.0, 180)
poner("wall3", 0.0, 1.0, 0.0, 90)          # lado izquierdo
poner("wall5", 0.0, 3.0, 0.0, 90)
poner("wall4", 8.0, 1.0, 0.0, -90)         # lado derecho
poner("wall3", 8.0, 3.0, 0.0, -90)
# --- puerta, arco de piedra, escalón y ventanas
poner("EmptyDoor.001", 5.0, 0.0, 0.0)
poner("Empty.DoorArc.001", 5.0, -0.12, 0.0)
poner("stair_stone", 5.0, -0.9, 0.0)
poner("Emptywindow1", 2.0, -0.12, 1.0)
poner("Emptywindow2", 6.0, 4.12, 0.6, 180)
poner("Emptywindow1", -0.12, 2.0, 1.0, 90)
# --- zócalo de ladrillo en fachada y trasera (se repiten las 20 variantes)
ladrillos = [f"brick_standing{'' if i == 0 else '.%03d' % i}" for i in range(20)]
for fila_y, giro in ((-0.3, 0), (4.3, 180)):
    x = 0.15
    i = 0
    while x < 7.9:
        if not (fila_y < 0 and 3.6 < x < 6.4):       # no tapar la puerta
            poner(ladrillos[i % 20], x, fila_y, 0.0, giro)
        x += 0.25
        i += 1
# --- tejado a dos aguas: filas de tejas sueltas desde el alero hasta la cumbrera
ALTO_MURO = 4.0
SUBIDA = 2.4
VUELO = 0.6
for lado in (-1, 1):
    y0 = 2.0 + lado * (2.0 + VUELO)           # alero
    pend = math.atan2(SUBIDA, 2.0 + VUELO)
    largo = math.hypot(SUBIDA, 2.0 + VUELO)
    filas = int(largo / 0.9) + 1
    for f in range(filas):
        t = (f + 0.5) / filas
        y = y0 - lado * t * (2.0 + VUELO)
        z = ALTO_MURO - 0.3 + t * SUBIDA - 0.45 * math.sin(pend)
        x = -0.4
        k = 0
        while x < 8.4:
            poner(f"rooftile{'' if k % 7 == 0 else '.%03d' % (k % 7)}", x, y, z, 0 if lado < 0 else 180, pend)
            x += 0.74
            k += 1
# cumbrera (dos vigas de 4 m) y piñones de revoque (un triángulo por lado, del material «Wall»)
for xc in (2.0, 6.0):
    poner("woodnew.003", xc, 2.0, ALTO_MURO + SUBIDA - 0.1, 90)
me = D.meshes.new("pinon")
me.from_pydata([(0, 0.0, 0), (0, 4.0, 0), (0, 2.0, SUBIDA), (0, 0.0, 0), (0, 4.0, 0), (0, 2.0, SUBIDA)], [],
               [(0, 1, 2), (5, 4, 3)])   # dos caras: se ve por dentro y por fuera
me.materials.append(D.materials["Wall"])
for xp in (0.0, 8.0):
    p = D.objects.new("pinon", me)
    p.location = (xp, 0.0, ALTO_MURO)
    CASA.objects.link(p)
    nuevos.append(p)
# buhardilla en el faldón delantero
poner("EmptysidewindowA.002", 2.0, 0.9, ALTO_MURO + 0.2)
# --- atrezo de la entrada
poner("Empty.Barrel", 7.6, -1.1, 0.0)
poner("EmptyCrateBoxA", 8.9, -0.6, 0.0)
poner("EmptyLampHolder", 3.7, -0.5, 2.6)
poner("Empty_Logs", -1.4, 2.0, 0.0, 90)
for i, pot in enumerate(["PotA", "PotD", "PotF"]):
    poner(pot, 0.6 + i * 1.1, -1.0, 0.0)

# --- materiales: color plano con el mismo nombre (lo procedural no viaja a glTF)
COLORES = {
    "wood": (0.78, 0.68, 0.52), "Wall": (0.80, 0.86, 0.90), "Rooftile": (0.62, 0.26, 0.30),
    "ArcBrickStone": (0.62, 0.66, 0.72), "BrickStone": (0.55, 0.32, 0.32), "BigBrickStone": (0.62, 0.66, 0.58),
    "LargeBrickStone": (0.62, 0.66, 0.60), "StoneFence": (0.50, 0.46, 0.55), "Metal": (0.30, 0.30, 0.33),
    "windowglass": (0.10, 0.20, 0.22), "Pots": (0.75, 0.60, 0.55), "Rope": (0.60, 0.45, 0.30),
    "Lamp": (0.80, 0.85, 0.95),
}
usados = set()
for o in nuevos:
    for s in getattr(o, "material_slots", []):
        if s.material:
            usados.add(s.material)
for m in usados:
    col = next((c for k, c in COLORES.items() if m.name.startswith(k)), None)
    if col is None:
        continue
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

# --- unir (opcional): todas las piezas en un solo objeto; Blender agrupa las caras por material
if UNIR:
    bpy.context.view_layer.update()
    mallas_casa = [o for o in CASA.objects if o.type == "MESH"]
    for o in mallas_casa:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    for o in [o for o in CASA.objects if o.type == "EMPTY"]:
        D.objects.remove(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in mallas_casa:
        o.select_set(True)
    bpy.context.view_layer.objects.active = mallas_casa[0]
    bpy.ops.object.join()
    unida = bpy.context.view_layer.objects.active
    unida.name = "casa_sh"

# --- exportar solo la casa (los lattices y curvas no se exportan; sus deformaciones van aplicadas)
nuevos = [o for o in CASA.objects]
bpy.ops.object.select_all(action="DESELECT")
for o in nuevos:
    o.select_set(True)
bpy.context.view_layer.objects.active = nuevos[0]
bpy.ops.export_scene.gltf(filepath=SALIDA, export_format="GLB", use_selection=True, export_apply=True,
                          export_yup=True, export_animations=False, export_lights=False, export_cameras=False)

# informe: triángulos evaluados y objetos con malla
dg = bpy.context.evaluated_depsgraph_get()
tris = 0
mallas = 0
for o in nuevos:
    if o.type in {"MESH", "CURVE"}:
        me2 = o.evaluated_get(dg).to_mesh()
        me2.calc_loop_triangles()
        tris += len(me2.loop_triangles)
        mallas += 1
        o.evaluated_get(dg).to_mesh_clear()
mats = len({s.material.name for o in nuevos for s in getattr(o, "material_slots", []) if s.material})
inf = {"triangulos": tris, "objetos_con_malla": mallas, "materiales": mats, "diezmar": DIEZMAR, "unida": UNIR,
       "glb": SALIDA, "mb": round(os.path.getsize(SALIDA) / 1048576, 1)}
with open(os.path.splitext(SALIDA)[0] + ".json", "w", encoding="utf-8") as f:
    json.dump(inf, f, ensure_ascii=False, indent=1)
print("CASA", inf)
