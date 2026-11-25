"""Tanda reproducible de Blender: fuentes exportadas por Godot, originales intactos.
Ejecutar con blender --background --python herramientas/blender_interacciones.py.
Los derivados Cosmos permanecen bajo arte/lostcave, excluido de git.
"""
import bpy
import bmesh
import json
import math
from array import array
from pathlib import Path
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[1]
SALIDA = RAIZ / 'arte/meshy/blender_interacciones'
COSMOS = RAIZ / 'arte/lostcave/blender_interacciones'
QA = RAIZ / 'output/blender_interacciones_2026-11-25'
FUENTES = json.loads((QA / 'fuentes.json').read_text(encoding='utf-8-sig'))
INVENTARIO = []
for p in [SALIDA, COSMOS]: p.mkdir(parents=True, exist_ok=True)

def material(nombre, color):
    m = bpy.data.materials.new(nombre)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = .85
    return m

def importar(nombre):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.data.orphans_purge(do_recursive=True)
    bpy.ops.import_scene.gltf(filepath=FUENTES[nombre])
    objetos = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for o in objetos:
        tf = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = tf
    for o in list(bpy.context.scene.objects):
        if o.type != 'MESH': bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objetos: o.select_set(True)
    bpy.context.view_layer.objects.active = objetos[0]
    bpy.ops.object.join()
    o = bpy.context.object
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.name = nombre
    return o

def limites(o):
    vs = [o.matrix_world @ Vector(v) for v in o.bound_box]
    return Vector(tuple(min(v[i] for v in vs) for i in range(3))), Vector(tuple(max(v[i] for v in vs) for i in range(3)))

def guardar(nombre, fuente, carpeta=SALIDA, notas=''):
    for im in bpy.data.images:
        if im.has_data and not im.packed_file:
            try: im.pack()
            except RuntimeError: pass
    bpy.ops.object.select_all(action='SELECT')
    ruta = carpeta / (nombre + '.glb')
    bpy.ops.export_scene.gltf(filepath=str(ruta), export_format='GLB', use_selection=True, export_animations=True, export_yup=True)
    editables = carpeta / 'editables'
    editables.mkdir(exist_ok=True)
    (editables / '.gdignore').touch()
    bpy.ops.wm.save_as_mainfile(filepath=str(editables / (nombre + '.blend')))
    objetos = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    INVENTARIO.append({'id': nombre, 'fuente': fuente, 'glb': str(ruta.relative_to(RAIZ)).replace('\\','/'),
        'blend': str((editables/(nombre+'.blend')).relative_to(RAIZ)).replace('\\','/'),
        'mallas': len(objetos), 'triangulos': sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objetos), 'notas': notas})
    print('ASSET_OK', nombre, flush=True)

def recortar(o, punto, normal, conservar_positivo, interior):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    # glTF duplica vértices en costuras de UV/normales. Soldar la topología
    # mantiene las UV por esquina y permite cerrar los bucles de cada corte.
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-5)
    r = bmesh.ops.bisect_plane(bm, geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
        dist=1e-6, plane_co=Vector(punto), plane_no=Vector(normal),
        clear_inner=conservar_positivo, clear_outer=not conservar_positivo)
    bordes = [e for e in r['geom_cut'] if isinstance(e, bmesh.types.BMEdge) and e.is_boundary]
    if bordes:
        caras = bmesh.ops.holes_fill(bm, edges=bordes, sides=0)['faces']
        for f in caras: f.material_index = interior
        if caras: bmesh.ops.triangulate(bm, faces=caras)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    return len(o.data.polygons) > 3

def fracturar(fuente, nombre, carpeta=SALIDA):
    o = importar(fuente)
    if fuente.startswith('jarron'):
        bm=bmesh.new(); bm.from_mesh(o.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-5)
        abiertos=sum(e.is_boundary for e in bm.edges)
        bm.to_mesh(o.data); bm.free()
        if abiertos:
            # Las vasijas abiertas necesitan pared interior antes de cortarlas.
            bpy.context.view_layer.objects.active=o
            pared=o.modifiers.new('Espesor cerámica','SOLIDIFY')
            pared.thickness=.018; pared.offset=-1
            bpy.ops.object.modifier_apply(modifier=pared.name)
    lo, hi = limites(o)
    medio = (lo+hi)*.5
    interior = material('Interior_'+fuente, (.42,.25,.12) if fuente=='caja' else ((.52,.31,.19) if fuente.startswith('jarron') else (.30,.29,.27)))
    o.data.materials.append(interior)
    slot = len(o.data.materials)-1
    piezas = [o]
    for eje in [0,1,2]:
        nuevas = []
        normal = [0,0,0]; normal[eje] = 1
        for pieza in piezas:
            for positivo in [True,False]:
                copia = pieza.copy(); copia.data = pieza.data.copy()
                bpy.context.collection.objects.link(copia)
                if recortar(copia,medio,normal,positivo,slot): nuevas.append(copia)
                else: bpy.data.objects.remove(copia, do_unlink=True)
            bpy.data.objects.remove(pieza, do_unlink=True)
        piezas = nuevas
    for i,p in enumerate(piezas):
        p.name = f'fragmento_{i:02d}'
        bpy.context.view_layer.objects.active = p
        bpy.ops.object.select_all(action='DESELECT'); p.select_set(True)
        bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
    guardar(nombre,fuente,carpeta,'Fragmentos recompuestos en su pose original; UV exteriores conservadas, cortes con material interior.')

def separar_bayas():
    o = importar('bayas')
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-5)
    uv = bm.loops.layers.uv.active
    pixeles = {}
    def color(f):
        mat=o.data.materials[f.material_index]
        im=next((n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and n.image.colorspace_settings.name=='sRGB'),None)
        if im is None or uv is None: return (0,0,0)
        if im.name not in pixeles:
            datos=array('f',[0])*(im.size[0]*im.size[1]*4)
            im.pixels.foreach_get(datos)
            pixeles[im.name]=datos
        coord=sum((l[uv].uv for l in f.loops),Vector((0,0)))/len(f.loops)
        pos=(int((coord.y%1)*im.size[1])*im.size[0]+int((coord.x%1)*im.size[0]))*4
        return pixeles[im.name][pos:pos+3]
    rojas=set()
    for f in bm.faces:
        r,g,b=color(f)
        if (r-g)/max(r,.001)>.5: rojas.add(f)
    semillas=[]; informe=[]
    while rojas:
        grupo={rojas.pop()}; cola=list(grupo)
        while cola:
            f=cola.pop()
            for e in f.edges:
                for v in e.link_faces:
                    if v in rojas:
                        rojas.remove(v); grupo.add(v); cola.append(v)
        verts={v for f in grupo for v in f.verts}
        lo=Vector(tuple(min(v.co[i] for v in verts) for i in range(3)))
        hi=Vector(tuple(max(v.co[i] for v in verts) for i in range(3)))
        dim=hi-lo
        candidato=len(grupo)>12 and min(dim)>.035 and max(dim)/max(min(dim),.001)<2.8
        informe.append({'caras':len(grupo),'dim':list(dim),'centro':list((lo+hi)*.5),'fruto':candidato})
        if candidato: semillas.append(((lo+hi)*.5,max(dim)*.62))
    (QA/'componentes_bayas.json').write_text(json.dumps(informe,indent=2))
    assert semillas,'No se identificaron regiones de frutos'
    # La reconstrucción original soldó hojas y frutos. Las regiones compactas
    # rojas localizan cada fruto; su esfera incluye también los brillos claros.
    for v in bm.verts: v.select=False
    for e in bm.edges: e.select=False
    bm.select_mode={'FACE'}
    for f in bm.faces:
        p=f.calc_center_median()
        f.select=any((p-c).length<=r for c,r in semillas)
    bm.select_flush_mode()
    bm.to_mesh(o.data); bm.free()
    bpy.context.view_layer.objects.active=o
    bpy.context.tool_settings.mesh_select_mode=(False,False,True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.separate(type='SELECTED')
    bpy.ops.object.mode_set(mode='OBJECT')
    arbusto = bpy.data.objects.new('arbusto',None)
    frutos = bpy.data.objects.new('frutos',None)
    bpy.context.collection.objects.link(arbusto); bpy.context.collection.objects.link(frutos)
    for parte in [x for x in bpy.context.scene.objects if x.type=='MESH']:
        es_fruto=parte != o
        parte.parent = frutos if es_fruto else arbusto
    assert len(frutos.children)>0,'No se identificaron frutos completos'
    guardar('bayas_separadas','bayas',notas=f'{len(semillas)} regiones de frutos, agrupadas en una malla separada; UV conservadas.')
    for parte in list(frutos.children): bpy.data.objects.remove(parte,do_unlink=True)
    bpy.data.objects.remove(frutos,do_unlink=True)
    guardar('bayas_agotadas','bayas',notas='Solo ramas y hojas; frutos retirados geométricamente.')

def danados():
    o=importar('caldera'); lo,hi=limites(o); dim=hi-lo; c=(hi+lo)*.5
    for v in o.data.vertices:
        p=v.co
        fuerza=math.exp(-((p.x-c.x)/(dim.x*.24))**2-((p.z-(lo.z+dim.z*.57))/(dim.z*.23))**2)
        frente=max(0,min(1,(c.y-p.y)/(dim.y*.3)))
        p.y+=dim.y*.17*fuerza*frente
    guardar('caldera_abollada','caldera',notas='Abolladura frontal real; asas y UV preservadas.')
    fracturar('roca','roca_fragmentos')
    for p in bpy.context.scene.objects:
        if p.type=='MESH':
            centro=p.location.copy()
            p.location += Vector((centro.x,centro.y,0))*.055
            p.rotation_euler.z += .018 if centro.x>0 else -.018
    guardar('roca_agrietada','roca',notas='Grietas con separación real y caras interiores; sin shader de grietas.')
    o=importar('cristal'); lo,hi=limites(o)
    m=material('Interior_cristal',(.24,.48,.58)); o.data.materials.append(m)
    recortar(o,(0,0,lo.z+(hi.z-lo.z)*.65),(0.12,.08,1),False,len(o.data.materials)-1)
    guardar('cristal_agotado','cristal',notas='Puntas truncadas; la base permanece.')
    o=importar('tocon'); lo,hi=limites(o); dim=hi-lo
    for v in o.data.vertices:
        f=max(0,(v.co.z-lo.z)/max(dim.z,.001)-.35)
        v.co.z += dim.z*.12*f*math.sin(v.co.x*37+v.co.y*21)
    carbon=material('Madera_carbonizada',(.045,.030,.020))
    o.data.materials.clear(); o.data.materials.append(carbon)
    for p in o.data.polygons: p.material_index=0
    guardar('tocon_quemado','tocon',notas='Borde superior erosionado y material carbonizado.')
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    ceniza=material('Ceniza',(.17,.16,.15))
    for i in range(14):
        a=i*2.399963; r=.06+float(i%5)*.045
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(math.cos(a)*r,math.sin(a)*r,.025))
        p=bpy.context.object; p.name=f'carbon_{i:02d}'
        p.scale=(.06+float(i%3)*.02,.045,.02+float(i%4)*.007)
        p.data.materials.append(ceniza)
    guardar('ceniza_restos','procedural',notas='Ceniza y carbones con volumen; sin colisión.')

def tapa_barril():
    o=importar('barril'); lo,hi=limites(o); dim=hi-lo
    o.name='cuerpo'
    # El original es un barril abierto: añadir una tapa completa de cinco
    # tablas recortadas al círculo, conservando cuerpo y UV sin deformarlos.
    radio=min(dim.x,dim.y)*.40
    cx=(lo.x+hi.x)*.5; cy=(lo.y+hi.y)*.5; corte=hi.z-.012
    madera=material('Madera_tapa',(.19,.085,.032))
    tablas=[]
    for i in range(5):
        bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=radio,depth=.035,location=(cx,cy,corte))
        tabla=bpy.context.object; tabla.name=f'tabla_tapa_{i}'
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        tabla.data.materials.append(madera)
        xmin=cx-radio+i*(2*radio/5)+.0015
        xmax=cx-radio+(i+1)*(2*radio/5)-.0015
        recortar(tabla,(xmin,0,0),(1,0,0),True,0)
        recortar(tabla,(xmax,0,0),(1,0,0),False,0)
        tablas.append(tabla)
    bpy.ops.object.select_all(action='DESELECT')
    for tabla in tablas: tabla.select_set(True)
    bpy.context.view_layer.objects.active=tablas[0]
    bpy.ops.object.join()
    tapa=bpy.context.object; tapa.name='tapa'
    bisagra=bpy.data.objects.new('bisagra_tapa',None); bpy.context.collection.objects.link(bisagra)
    bisagra.location=(cx,cy+radio,corte)
    bpy.context.view_layer.update()
    tf=tapa.matrix_world.copy(); tapa.parent=bisagra; tapa.matrix_world=tf
    bisagra.rotation_euler.x=0; bisagra.keyframe_insert(data_path='rotation_euler',frame=1)
    bisagra.rotation_euler.x=math.radians(-105); bisagra.keyframe_insert(data_path='rotation_euler',frame=25)
    if bisagra.animation_data and bisagra.animation_data.action: bisagra.animation_data.action.name='abrir_tapa'
    bpy.context.scene.frame_set(1)
    bpy.context.scene.frame_end=25
    guardar('barril_articulado','barril',COSMOS,'Tapa y cuerpo separados; bisagra en borde trasero y animación abrir_tapa.')

print('BLENDER_VERSION',bpy.app.version_string,flush=True)
fracturar('caja','caja_fragmentos',COSMOS)
fracturar('jarron','jarron_fragmentos')
fracturar('jarron_alto','jarron_alto_fragmentos')
separar_bayas()
danados()
tapa_barril()
(QA/'inventario_blender.json').write_text(json.dumps(INVENTARIO,indent=2,ensure_ascii=False),encoding='utf-8')
print('TANDA_COMPLETA',len(INVENTARIO),flush=True)
