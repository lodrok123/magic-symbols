# Genera una roca con los nodos de RockForm (addon de Blender) y la exporta a GLB low-poly, sin material ni UV.
# Uso (Blender 5.2, sin ventana):
#   blender --background --factory-startup --python generar_roca_rockform.py -- --glb salida.glb [opciones]
# Ejemplo (plataforma de tierra con la familia 8):
#   ... -- --glb plataforma_rf_08.glb --familia 8 --guia 8 8 1.2 --lado 2.3 --tris 1200
import bpy, bmesh, os, sys, time, argparse
from mathutils import Vector

ap = argparse.ArgumentParser()
ap.add_argument('--glb', required=True)
ap.add_argument('--png', default='')                    # vista previa (opcional)
ap.add_argument('--blend', default='')                  # guardar el .blend editable (opcional)
ap.add_argument('--familia', type=int, default=7)       # 1..24, el número de la lámina de RockForm
ap.add_argument('--guia', type=float, nargs=3, default=[2.6, 2.0, 1.5])   # tamaño X Y Z (m, Z arriba) de la caja guía
ap.add_argument('--guia_esfera', action='store_true')   # guía elipsoide en vez de caja
ap.add_argument('--reparto', type=int, default=0)       # 0 volumen, 1 caras, 2 vértices
ap.add_argument('--alinear', action='store_true')       # alinear las piezas a las caras
ap.add_argument('--semilla', type=int, default=7)
ap.add_argument('--densidad', type=float, default=0.35)
ap.add_argument('--voxel', type=float, default=0.08)
ap.add_argument('--escala', type=float, nargs=2, default=[0.5, 1.0])     # escala mínima y máxima de las piezas
ap.add_argument('--giro_z', type=float, default=0.0)    # giro aleatorio de las piezas en Z (radianes, ±)
ap.add_argument('--desplaza', type=float, default=1.0)  # fuerza del desplazamiento (relieve fino)
ap.add_argument('--suaviza', type=int, default=10)      # iteraciones de suavizado
ap.add_argument('--facetas', action='store_true')       # sombreado plano (caras marcadas, como las rocas del juego)
ap.add_argument('--tris', type=int, default=2500)      # triángulos de la versión exportada
ap.add_argument('--lado', type=float, default=2.0)      # metros del lado horizontal más largo ya exportada
ap.add_argument('--corte_abajo', type=float, default=0.0)   # fracción del alto que se recorta por abajo (base plana)
ap.add_argument('--corte_arriba', type=float, default=0.0)  # fracción del alto que se recorta por arriba (techo plano y pisable)
a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:])

blend = os.path.join(os.environ['APPDATA'], 'Blender Foundation', 'Blender', '5.2', 'extensions',
                     'user_default', 'rockform', 'assets', 'RockForm_v140_B5.blend')
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
bpy.ops.wm.append(directory=blend + '\\Collection', filename='RockForm Assets', link=False)
for n in ('RockForm Settings Object', 'RockForm Guide Object'):
    if n in bpy.data.objects:
        bpy.data.objects[n].hide_viewport = True
        bpy.data.objects[n].hide_render = True
familia = next(c for c in bpy.data.collections if c.name.startswith('SIG%02d:' % a.familia))
col = bpy.context.scene.collection


def poner(mod, ident, valor):
    # Blender 5.2: las entradas ya no son mod[ident], van en mod.properties.inputs
    getattr(mod.properties.inputs, ident).value = valor


# Guía: caja o elipsoide del tamaño pedido, apoyada en el suelo.
m = bpy.data.meshes.new('Roca')
bm = bmesh.new()
if a.guia_esfera:
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.5)
else:
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=3, use_grid_fill=True)
for v in bm.verts:
    v.co = Vector((v.co.x * a.guia[0], v.co.y * a.guia[1], (v.co.z + 0.5) * a.guia[2]))
bm.to_mesh(m); bm.free()
guia = bpy.data.objects.new('Roca', m)
col.objects.link(guia)
guia.display_type = 'WIRE'
guia.hide_render = True

# Objeto de ajustes, igual que hace el botón «Create RockForm».
roca = bpy.data.objects.new('Roca_RF_Settings', bpy.data.meshes.new('Roca_RF_Settings'))
col.objects.link(roca)
forma = roca.modifiers.new('RF Shape Formation', 'NODES')
forma.node_group = bpy.data.node_groups['RF_SetShape']
poner(forma, 'Input_3', guia)
poner(forma, 'Input_2', familia)
poner(forma, 'Input_16', a.reparto)
poner(forma, 'Socket_1', a.alinear)
poner(forma, 'Input_11', a.semilla)
poner(forma, 'Input_17', a.densidad)
poner(forma, 'Input_19', a.voxel)
poner(forma, 'Input_9', a.escala[0])
poner(forma, 'Input_10', a.escala[1])
poner(forma, 'Socket_6', -a.giro_z)
poner(forma, 'Socket_7', a.giro_z)
dec = roca.modifiers.new('RF Decimater', 'DECIMATE')
dec.ratio = 0.01
dec.show_viewport = False
dec.show_render = False
mat = roca.modifiers.new('RF Material and Displacer', 'NODES')
mat.node_group = bpy.data.node_groups['RF_SetMat']
poner(mat, 'Input_5', a.desplaza)
poner(mat, 'Socket_18', a.suaviza)
roca.data.materials.append(bpy.data.materials['RF_MAT_Master'])

t0 = time.time()
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
alta = bpy.data.meshes.new_from_object(roca.evaluated_get(dg), depsgraph=dg)
print('RF_ALTA', familia.name, 'caras', len(alta.polygons), 'seg', round(time.time() - t0, 1))
if len(alta.polygons) == 0:
    raise SystemExit('RF_ERROR: la roca salió vacía')
alta.materials.clear()

# Recortes planos (base y techo) sobre la malla densa, tapando el hueco.
if a.corte_abajo > 0.0 or a.corte_arriba > 0.0:
    zs = [v.co.z for v in alta.vertices]
    z0, z1 = min(zs), max(zs)
    bm = bmesh.new()
    bm.from_mesh(alta)
    for frac, normal, z in ((a.corte_abajo, (0, 0, -1), z0 + (z1 - z0) * a.corte_abajo),
                            (a.corte_arriba, (0, 0, 1), z1 - (z1 - z0) * a.corte_arriba)):
        if frac <= 0.0:
            continue
        r = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, z),
                                   plane_no=normal, clear_outer=True)
        bordes = [e for e in r['geom_cut'] if isinstance(e, bmesh.types.BMEdge)]
        if bordes:
            # La tapa mira hacia fuera del corte (no se recalculan las normales del resto: en una malla abierta se pueden invertir).
            tapa = bmesh.ops.triangle_fill(bm, edges=bordes, use_beauty=True)
            for f in tapa['geom']:
                if isinstance(f, bmesh.types.BMFace):
                    f.normal_update()
                    if f.normal.dot(Vector(normal)) < 0.0:
                        f.normal_flip()
    bm.to_mesh(alta); bm.free()

# Versión low-poly: decimate hasta los triángulos pedidos.
nombre = os.path.splitext(os.path.basename(a.glb))[0]
baja = bpy.data.objects.new(nombre, alta)
col.objects.link(baja)
tris_alta = sum(len(p.vertices) - 2 for p in alta.polygons)
d = baja.modifiers.new('RF Final Decimater', 'DECIMATE')
d.decimate_type = 'COLLAPSE'
d.ratio = min(1.0, a.tris / tris_alta)
d.use_collapse_triangulate = True
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
final = bpy.data.meshes.new_from_object(baja.evaluated_get(dg), depsgraph=dg)
baja.modifiers.clear()
baja.data = final
final.name = nombre
# Apoyar en el suelo, centrar en XY y dejar el lado horizontal mayor en `lado` metros.
xs = [v.co.x for v in final.vertices]; ys = [v.co.y for v in final.vertices]; zs = [v.co.z for v in final.vertices]
desp = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)))
k = a.lado / max(max(xs) - min(xs), max(ys) - min(ys))
for v in final.vertices:
    v.co = (v.co - desp) * k
for p in final.polygons:
    p.use_smooth = not a.facetas
print('RF_BAJA', nombre, 'tris', len(final.polygons), 'tam_final_xyz',
      round((max(xs) - min(xs)) * k, 2), round((max(ys) - min(ys)) * k, 2), round((max(zs) - min(zs)) * k, 2))

for o in bpy.data.objects:
    o.select_set(False)
baja.select_set(True)
bpy.context.view_layer.objects.active = baja
bpy.ops.export_scene.gltf(filepath=a.glb, export_format='GLB', use_selection=True,
                          export_materials='NONE', export_apply=True, export_yup=True)
print('RF_GLB', a.glb, os.path.getsize(a.glb))

if a.png:
    final.materials.append(bpy.data.materials.new('PreviaGris'))
    cam = bpy.data.objects.new('Camara', bpy.data.cameras.new('Camara'))
    col.objects.link(cam)
    alto = (max(zs) - min(zs)) * k
    cam.location = Vector((1.9, -2.1, 0.95)) * a.lado * 0.75 + Vector((0, 0, alto * 0.5))
    cam.rotation_euler = (Vector((0, 0, alto * 0.5)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc = bpy.context.scene
    sc.camera = cam
    for o in bpy.data.objects:
        if o not in (baja, cam):
            o.hide_render = True
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.show_cavity = True
    sc.display.shading.show_shadows = True
    sc.render.resolution_x, sc.render.resolution_y = 800, 560
    sc.render.filepath = a.png
    bpy.ops.render.render(write_still=True)
if a.blend:
    baja.location.x = a.guia[0] + a.lado
    bpy.ops.wm.save_as_mainfile(filepath=a.blend)
print('RF_OK')
