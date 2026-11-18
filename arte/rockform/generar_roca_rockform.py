# Genera una roca de prueba con los nodos de RockForm y la exporta a GLB.
# Uso: blender --background --factory-startup --python rf_generar.py -- <glb> <png> <blend> [tris]
import bpy, bmesh, os, sys, math, time
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
RUTA_GLB, RUTA_PNG, RUTA_BLEND = args[0], args[1], args[2]
TRIS = int(args[3]) if len(args) > 3 else 2500

# --- Parámetros de la roca (los mismos que se ven en el panel de RockForm) ---
FAMILIA = 'SIG07: Boulders'
SEMILLA = 7
DENSIDAD = 0.35
VOXEL = 0.08
ESCALA_MIN, ESCALA_MAX = 0.5, 1.0
GUIA_ESCALA = (1.3, 1.0, 0.75)   # semiejes de la guía en metros

blend = os.path.join(os.environ['APPDATA'], 'Blender Foundation', 'Blender', '5.2', 'extensions',
                     'user_default', 'rockform', 'assets', 'RockForm_v140_B5.blend')

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
bpy.ops.wm.append(directory=blend + '\\Collection', filename='RockForm Assets', link=False)
# El ejemplo que trae el .blend no nos hace falta en la escena de prueba.
for nombre in ('RockForm Settings Object', 'RockForm Guide Object'):
    if nombre in bpy.data.objects:
        bpy.data.objects[nombre].hide_viewport = True
        bpy.data.objects[nombre].hide_render = True

col = bpy.context.scene.collection


def poner(mod, ident, valor):
    # Blender 5.2: las entradas ya no son mod[ident], van en mod.properties.inputs
    e = getattr(mod.properties.inputs, ident)
    print('RF_IN', ident, type(e).__name__, [a for a in dir(e) if not a.startswith('_')][:12])
    e.value = valor


# Guía: una esfera achatada.
m = bpy.data.meshes.new('RocaPrueba')
bm = bmesh.new()
bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
for v in bm.verts:
    v.co = Vector((v.co.x * GUIA_ESCALA[0], v.co.y * GUIA_ESCALA[1], v.co.z * GUIA_ESCALA[2]))
bm.to_mesh(m); bm.free()
guia = bpy.data.objects.new('RocaPrueba', m)
col.objects.link(guia)
guia.display_type = 'WIRE'
guia.hide_render = True

# Objeto de ajustes, igual que hace el botón «Create RockForm».
roca = bpy.data.objects.new('RocaPrueba_RF_Settings', bpy.data.meshes.new('RocaPrueba_RF_Settings'))
col.objects.link(roca)
forma = roca.modifiers.new('RF Shape Formation', 'NODES')
forma.node_group = bpy.data.node_groups['RF_SetShape']
poner(forma, 'Input_3', guia)
poner(forma, 'Input_2', bpy.data.collections[FAMILIA])
poner(forma, 'Input_16', 0)          # 0 volumen, 1 caras, 2 vértices
poner(forma, 'Input_11', SEMILLA)
poner(forma, 'Input_17', DENSIDAD)
poner(forma, 'Input_19', VOXEL)
poner(forma, 'Input_9', ESCALA_MIN)
poner(forma, 'Input_10', ESCALA_MAX)
dec = roca.modifiers.new('RF Decimater', 'DECIMATE')
dec.ratio = 0.01
dec.show_viewport = False
dec.show_render = False
mat = roca.modifiers.new('RF Material and Displacer', 'NODES')
mat.node_group = bpy.data.node_groups['RF_SetMat']
roca.data.materials.append(bpy.data.materials['RF_MAT_Master'])

t0 = time.time()
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
alta = bpy.data.meshes.new_from_object(roca.evaluated_get(dg), depsgraph=dg)
print('RF_ALTA verts', len(alta.vertices), 'caras', len(alta.polygons), 'seg', round(time.time() - t0, 1))
if len(alta.polygons) == 0:
    raise SystemExit('RF_ERROR: la roca salió vacía')

# Versión low-poly: copia horneada + decimate.
alta.name = 'RocaPrueba_low'
baja = bpy.data.objects.new('RocaPrueba_low', alta)
col.objects.link(baja)
alta.materials.clear()
tris_alta = sum(len(p.vertices) - 2 for p in alta.polygons)
d = baja.modifiers.new('RF Final Decimater', 'DECIMATE')
d.decimate_type = 'COLLAPSE'
d.ratio = min(1.0, TRIS / tris_alta)
d.use_collapse_triangulate = True
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
final = bpy.data.meshes.new_from_object(baja.evaluated_get(dg), depsgraph=dg)
baja.modifiers.clear()
baja.data = final
final.name = 'RocaPrueba_low'
# Apoyar en el suelo y centrar en XY.
xs = [v.co.x for v in final.vertices]; ys = [v.co.y for v in final.vertices]; zs = [v.co.z for v in final.vertices]
desp = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)))
LADO_MAYOR = 2.0   # metros que mide el lado más largo de la roca ya exportada
k = LADO_MAYOR / max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
for v in final.vertices:
    v.co = (v.co - desp) * k
for p in final.polygons:
    p.use_smooth = True
print('RF_BAJA verts', len(final.vertices), 'tris', len(final.polygons), 'tam_original',
      round(max(xs) - min(xs), 2), round(max(ys) - min(ys), 2), round(max(zs) - min(zs), 2), 'escala', round(k, 3),
      'tam_final', round((max(xs) - min(xs)) * k, 2), round((max(ys) - min(ys)) * k, 2), round((max(zs) - min(zs)) * k, 2))
baja.location.x = 6.0   # al lado de la original para compararlas en Blender

# Exportar solo la low-poly, en el origen.
for o in bpy.data.objects:
    o.select_set(False)
pos = baja.location.copy()
baja.location = (0, 0, 0)
baja.select_set(True)
bpy.context.view_layer.objects.active = baja
bpy.ops.export_scene.gltf(filepath=RUTA_GLB, export_format='GLB', use_selection=True,
                          export_materials='NONE', export_apply=True, export_yup=True)
print('RF_GLB', RUTA_GLB, os.path.getsize(RUTA_GLB))

# Vista previa para comprobar la forma.
gris = bpy.data.materials.new('PreviaGris')
final.materials.append(gris)
cam = bpy.data.objects.new('Camara', bpy.data.cameras.new('Camara'))
col.objects.link(cam)
cam.location = (3.2, -3.6, 2.4)
cam.rotation_euler = (Vector((0, 0, 0.6)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc = bpy.context.scene
sc.camera = cam
ocultos = [o for o in bpy.data.objects if o not in (baja, cam) and not o.hide_render]
for o in ocultos:
    o.hide_render = True
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'
sc.display.shading.show_cavity = True
sc.display.shading.show_shadows = True
sc.render.resolution_x, sc.render.resolution_y = 1100, 800
sc.render.filepath = RUTA_PNG
bpy.ops.render.render(write_still=True)
for o in ocultos:
    o.hide_render = False
baja.location = pos

bpy.ops.wm.save_as_mainfile(filepath=RUTA_BLEND)
print('RF_OK')
