"""
Autorig de un cuerpo humanoide RIGIDO (golem de piedra) con huesos Mixamo, en Blender (modo fondo):

    blender.exe -b --python tools/autorig_golem.py -- <entrada.glb> <salida.glb> [--sin-auto]

Pasos (todo se MIDE de la malla; solo van fijas unas fracciones de la altura, abajo):
  1. Importa el GLB (el importador pasa de Y-arriba/+Z-delante de glTF a Z-arriba/-Y-delante de Blender) y aplica transformaciones.
  1b. Borra los triangulos con una arista larga (hilos entre piezas separadas).
  2. Parte la malla en PIEZAS CONEXAS soldando por posicion (las costuras de UV duplican vertices: 276 piezas = cada roca).
  3. Mide: la altura, las piezas del brazo (centro a mas de LADO_BRAZO del eje) y de la pierna (el resto bajo la cadera), y de ahi coloca hombros, codos,
     munecas, cadera, rodillas, tobillos y puntas. La cabeza es la pieza cercana al eje a ~FRAC_CABEZA de la altura. El cuello es minimo (cabeza hundida).
  4. Crea la armadura con nombres Mixamo con guion bajo (`mixamorig_Hips`...; Godot cambia ':' por '_' al importar, y asi coincide con los goblins del proyecto).
  5. Pesos: ARMATURE_AUTO sobre una COPIA soldada (la malla original no esta soldada y el calor de hueso falla); los pesos pasan al original por vertice mas cercano.
     Los vertices sin peso (o si falla) reciben una mezcla suave de los 3 huesos mas cercanos. `--sin-auto` salta el automatico.
  6. RIGIDIZA: cada pieza conexa entera al hueso dominante de la mayoria de sus vertices si esa mayoria es >= UMBRAL_RIGIDA o la roca es pequena (DIAG_PEQUENA); si no (piezas grandes que cruzan huesos: el torso),
     conserva la mezcla.
  7. Reduce las texturas a TEXTURA px y exporta GLB (imagenes JPEG) con piel, textura embebida y SIN animaciones, en la misma orientacion (Y arriba, +Z delante).
Salida por consola: medidas y estadisticas. Reutilizable para otro cuerpo parecido: cambia las constantes.
"""
import sys
import bpy
import bmesh
from mathutils import Vector, kdtree

UMBRAL_RIGIDA = 0.75         # fraccion de vertices de la pieza cuyo hueso dominante es el mismo para mandar la pieza entera a ese hueso
DIAG_PEQUENA = 0.25          # una roca con la diagonal de su caja menor que esto es siempre rigida (al hueso dominante de la mayoria de sus vertices)
PIEZA_MINUSCULA = 50         # una pieza con menos vertices que esto es musgo o helecho: sigue a la roca grande mas cercana
LARGA_MAX = 0.15             # los triangulos con una arista mas larga que esto (hilos que unen cosas separadas, p. ej. los dos pies) se borran
TEXTURA = 1024               # las imagenes se reducen a este lado antes de exportar
LADO_BRAZO = 0.20            # |x| del centro de una pieza a partir del cual es del brazo
FRAC_CADERA = 0.385          # altura de la cadera / altura total
FRAC_PECHO = 0.67
FRAC_CABEZA = 0.85


def argumentos():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


def importar(ruta):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=ruta)
    obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def quitar_triangulos_largos(obj):
    """Borra los triangulos con una arista mayor que LARGA_MAX (3 triangulos finos unian los dos pies del golem en una sola pieza)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    malos = [f for f in bm.faces if max(e.calc_length() for e in f.edges) > LARGA_MAX]
    print("triangulos largos borrados:", len(malos))
    bmesh.ops.delete(bm, geom=malos, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


def componentes(obj):
    """Etiqueta cada vertice con su pieza conexa (soldando por posicion). Devuelve (etiquetas, n)."""
    me = obj.data
    n = len(me.vertices)
    padre = list(range(n))

    def raiz(i):
        while padre[i] != i:
            padre[i] = padre[padre[i]]
            i = padre[i]
        return i

    claves = {}
    for v in me.vertices:
        k = (round(v.co.x * 20000), round(v.co.y * 20000), round(v.co.z * 20000))
        if k in claves:
            padre[raiz(v.index)] = raiz(claves[k])
        else:
            claves[k] = v.index
    for p in me.polygons:
        vs = p.vertices
        for i in range(1, len(vs)):
            a, b = raiz(vs[0]), raiz(vs[i])
            if a != b:
                padre[b] = a
    et = {}
    lab = [0] * n
    for i in range(n):
        r = raiz(i)
        if r not in et:
            et[r] = len(et)
        lab[i] = et[r]
    return lab, len(et)


def medir(obj, lab, nc):
    vs = [v.co.copy() for v in obj.data.vertices]
    cajas = [[Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9)), 0] for _ in range(nc)]
    for v, l in zip(vs, lab):
        c = cajas[l]
        c[0] = Vector((min(c[0].x, v.x), min(c[0].y, v.y), min(c[0].z, v.z)))
        c[1] = Vector((max(c[1].x, v.x), max(c[1].y, v.y), max(c[1].z, v.z)))
        c[2] += 1
    return vs, cajas


def banda(vs, mask, zc, ancho):
    """Centro (x, y) de los vertices de `mask` con z dentro de zc +- ancho, a la altura zc."""
    sel = [v for v, m in zip(vs, mask) if m and abs(v.z - zc) <= ancho]
    if not sel:
        sel = [v for v, m in zip(vs, mask) if m]
    return Vector((sum(v.x for v in sel) / len(sel), sum(v.y for v in sel) / len(sel), zc))


def articulaciones(vs, lab, cajas):
    zmin = min(v.z for v in vs)
    zmax = max(v.z for v in vs)
    H = zmax - zmin
    print("altura %.3f  (z %.3f..%.3f)" % (H, zmin, zmax))
    cen = [(c[0] + c[1]) / 2 for c in cajas]
    J = {}
    for lado, s in (("Left", 1.0), ("Right", -1.0)):
        mb = [cen[l].x * s > LADO_BRAZO and cen[l].z > zmin + 0.04 for l in lab]
        zt = max(v.z for v, m in zip(vs, mb) if m)
        zb = min(v.z for v, m in zip(vs, mb) if m)
        L = zt - zb
        sh = banda(vs, mb, zt - 0.22 * L, 0.05)
        co = banda(vs, mb, zb + 0.52 * L, 0.05)
        mu = banda(vs, mb, zb + 0.26 * L, 0.05)
        pu = banda(vs, mb, zb + 0.02 * L, 0.03)
        print(lado, "brazo z %.3f..%.3f  hombro %s codo %s muneca %s punta %s" % (zb, zt, sh, co, mu, pu))
        J[lado + "Arm"], J[lado + "ForeArm"], J[lado + "Hand"], J[lado + "HandTip"] = sh, co, mu, pu
        zc = zmin + FRAC_CADERA * H
        ml = [0.02 < cen[l].x * s <= LADO_BRAZO and cen[l].z < zc for l in lab]
        zb_l = min(v.z for v, m in zip(vs, ml) if m)
        Ll = zc - zb_l
        cad = banda(vs, ml, zc - 0.04 * Ll, 0.04)
        rod = banda(vs, ml, zb_l + 0.55 * Ll, 0.04)
        tob = banda(vs, ml, zb_l + 0.25 * Ll, 0.04)
        pie = [v for v, m in zip(vs, ml) if m and v.z < zb_l + 0.35 * Ll]
        ydel = min(v.y for v in pie)  # delante = -Y en Blender
        dedo = Vector((tob.x, (tob.y + ydel) / 2.0, zb_l + 0.1 * Ll))
        punta = Vector((tob.x, ydel, zb_l + 0.05 * Ll))
        print(lado, "pierna z %.3f..%.3f  cadera %s rodilla %s tobillo %s punta pie y=%.3f" % (zb_l, zc, cad, rod, tob, ydel))
        J[lado + "UpLeg"], J[lado + "Leg"], J[lado + "Foot"], J[lado + "Toe"], J[lado + "ToeEnd"] = cad, rod, tob, dedo, punta
    cad_c = (J["LeftUpLeg"] + J["RightUpLeg"]) / 2
    z_cad = zmin + FRAC_CADERA * H
    z_pec = zmin + FRAC_PECHO * H
    mejor = None
    for i, c in enumerate(cajas):
        if c[2] < 100:
            continue
        d = (cen[i] - Vector((0.0, cad_c.y, zmin + FRAC_CABEZA * H))).length
        if mejor is None or d < mejor[0]:
            mejor = (d, i)
    ch = cajas[mejor[1]]
    cc = cen[mejor[1]]
    print("cabeza: pieza %d  centro %s  z %.3f..%.3f" % (mejor[1], cc, ch[0].z, ch[1].z))
    y_t = cad_c.y
    J["Hips"] = Vector((0.0, y_t, z_cad))
    J["Spine"] = Vector((0.0, y_t, z_cad + 0.2 * (z_pec - z_cad)))
    J["Spine1"] = Vector((0.0, y_t, z_cad + 0.55 * (z_pec - z_cad)))
    J["Spine2"] = Vector((0.0, y_t, z_pec))
    J["Neck"] = Vector((0.0, cc.y, ch[0].z - 0.01))
    J["Head"] = Vector((0.0, cc.y, ch[0].z + 0.35 * (ch[1].z - ch[0].z)))
    J["HeadTop"] = Vector((0.0, cc.y, ch[1].z))
    return J


def armadura(J):
    arm = bpy.data.armatures.new("Armature")
    ao = bpy.data.objects.new("Armature", arm)
    bpy.context.scene.collection.objects.link(ao)
    bpy.context.view_layer.objects.active = ao
    ao.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.edit_bones
    huesos = {}

    def hueso(nombre, cabeza, cola, padre=None):
        b = eb.new("mixamorig_" + nombre)
        b.head = cabeza
        b.tail = cola if (cola - cabeza).length >= 0.01 else cabeza + Vector((0, 0, 0.01))
        if padre:
            b.parent = huesos[padre]
        huesos[nombre] = b

    hueso("Hips", J["Hips"], J["Spine"])
    hueso("Spine", J["Spine"], J["Spine1"], "Hips")
    hueso("Spine1", J["Spine1"], J["Spine2"], "Spine")
    hueso("Spine2", J["Spine2"], J["Neck"], "Spine1")
    hueso("Neck", J["Neck"], J["Head"], "Spine2")
    hueso("Head", J["Head"], J["HeadTop"], "Neck")
    hueso("HeadTop_End", J["HeadTop"], J["HeadTop"] + Vector((0, 0, 0.03)), "Head")
    for lado in ("Left", "Right"):
        s = 1.0 if lado == "Left" else -1.0
        sh = J[lado + "Arm"]
        hueso(lado + "Shoulder", Vector((s * 0.03, J["Spine2"].y, J["Spine2"].z)), sh, "Spine2")
        hueso(lado + "Arm", sh, J[lado + "ForeArm"], lado + "Shoulder")
        hueso(lado + "ForeArm", J[lado + "ForeArm"], J[lado + "Hand"], lado + "Arm")
        hueso(lado + "Hand", J[lado + "Hand"], J[lado + "HandTip"], lado + "ForeArm")
        hueso(lado + "HandMiddle4", J[lado + "HandTip"], J[lado + "HandTip"] + Vector((0, 0, -0.03)), lado + "Hand")
        hueso(lado + "UpLeg", J[lado + "UpLeg"], J[lado + "Leg"], "Hips")
        hueso(lado + "Leg", J[lado + "Leg"], J[lado + "Foot"], lado + "UpLeg")
        hueso(lado + "Foot", J[lado + "Foot"], J[lado + "Toe"], lado + "Leg")
        hueso(lado + "ToeBase", J[lado + "Toe"], J[lado + "ToeEnd"], lado + "Foot")
        hueso(lado + "Toe_End", J[lado + "ToeEnd"], J[lado + "ToeEnd"] + Vector((0, -0.02, 0)), lado + "ToeBase")
    bpy.ops.object.mode_set(mode="OBJECT")
    return ao


def dist_segmento(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
    return (p - (a + ab * t)).length


def region_de(caja, zmin, H, huesos):
    """Huesos que puede usar una roca segun donde esta su centro (evita que un puno cuelgue de un pie: los dedos estan mas cerca de la pierna que de la muñeca).
    Brazo (|x| > LADO_BRAZO): solo los huesos de ese brazo. Pierna (bajo la cadera y |x| <= LADO_BRAZO): Hips y la pierna de ese lado (o las dos en el centro).
    Hombros (rocas de arriba y a un lado): torso mas Shoulder/Arm de ese lado. Resto: columna, cuello y cabeza, mas Shoulder y Hips."""
    c = (caja[0] + caja[1]) / 2
    z = c.z - zmin
    pre = "mixamorig_"
    todos = set(huesos)

    def lado_h(s, partes):
        return {pre + s + p for p in partes}
    brazo = lambda s: lado_h(s, ["Shoulder", "Arm", "ForeArm", "Hand", "HandMiddle4"])
    pierna = lambda s: lado_h(s, ["UpLeg", "Leg", "Foot", "ToeBase", "Toe_End"])
    columna = {pre + n for n in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "HeadTop_End"]}
    if abs(c.x) > LADO_BRAZO and z > 0.04:
        return brazo("Left" if c.x > 0 else "Right") & todos
    if z < FRAC_CADERA * H:
        s = "Left" if c.x > 0.02 else ("Right" if c.x < -0.02 else None)
        base = {pre + "Hips"}
        return (base | (pierna(s) if s else pierna("Left") | pierna("Right") | {pre + "Spine"})) & todos
    if abs(c.x) > 0.12 and z > 0.55 * H:
        s = "Left" if c.x > 0 else "Right"
        return (columna | {pre + s + "Shoulder", pre + s + "Arm"}) & todos
    return (columna | {pre + "LeftShoulder", pre + "RightShoulder"}) & todos


def pesos_auto(obj, ao):
    """ARMATURE_AUTO sobre una copia soldada; devuelve {vertice_original: {hueso: peso}} (puede quedar incompleto)."""
    cp = obj.copy()
    cp.data = obj.data.copy()
    bpy.context.scene.collection.objects.link(cp)
    bm = bmesh.new()
    bm.from_mesh(cp.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(cp.data)
    bm.free()
    bpy.ops.object.select_all(action="DESELECT")
    cp.select_set(True)
    ao.select_set(True)
    bpy.context.view_layer.objects.active = ao
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    nombres = {g.index: g.name for g in cp.vertex_groups}
    kd = kdtree.KDTree(len(cp.data.vertices))
    for v in cp.data.vertices:
        kd.insert(v.co, v.index)
    kd.balance()
    pc = {v.index: {nombres[g.group]: g.weight for g in v.groups if g.weight > 1e-4} for v in cp.data.vertices}
    res = {}
    for v in obj.data.vertices:
        _, j, _ = kd.find(v.co)
        if pc.get(j):
            res[v.index] = dict(pc[j])
    print("pesos auto: copia soldada %d vertices, %d sin peso" % (len(cp.data.vertices), sum(1 for d in pc.values() if not d)))
    bpy.data.objects.remove(cp, do_unlink=True)
    return res


def main():
    a = argumentos()
    obj = importar(a[0])
    quitar_triangulos_largos(obj)
    lab, nc = componentes(obj)
    vs, cajas = medir(obj, lab, nc)
    print("piezas conexas:", nc)
    J = articulaciones(vs, lab, cajas)
    ao = armadura(J)
    huesos = {b.name: (ao.matrix_world @ b.head_local, ao.matrix_world @ b.tail_local) for b in ao.data.bones}
    pesos = {}
    if "--sin-auto" not in a:
        try:
            pesos = pesos_auto(obj, ao)
        except Exception as e:  # noqa: BLE001
            print("AUTO fallo:", e)
    n = len(obj.data.vertices)
    sin_peso = [i for i in range(n) if i not in pesos]
    print("vertices con peso auto %d / %d; sin peso %d (mezcla suave de los huesos mas cercanos)" % (len(pesos), n, len(sin_peso)))
    zmin = min(v.z for v in vs)
    H = max(v.z for v in vs) - zmin
    permitidos = [region_de(cajas[c], zmin, H, huesos) for c in range(nc)]
    for i in sin_peso:  # ultimo recurso: mezcla suave de los 3 huesos mas cercanos DE LA REGION de su roca (peso ~ 1/distancia^3)
        p = obj.data.vertices[i].co
        ds = sorted((dist_segmento(p, h0, h1), nom) for nom, (h0, h1) in huesos.items() if nom in permitidos[lab[i]])[:3]
        w = {nom: 1.0 / (d + 0.01) ** 3 for d, nom in ds}
        t = sum(w.values())
        pesos[i] = {nom: x / t for nom, x in w.items()}
    rigidas = mezcla = 0
    rigido = {}
    for c in range(nc):
        idx = [i for i in range(n) if lab[i] == c]
        votos = {}
        for i in idx:
            dom = max(pesos[i], key=pesos[i].get)
            votos[dom] = votos.get(dom, 0) + 1
        top = max(votos, key=votos.get)
        pequena = (cajas[c][1] - cajas[c][0]).length < DIAG_PEQUENA
        # una roca mixta entre Shoulder y Arm del mismo lado (el monton del hombro) va entera al Arm: los hombros de piedra suben con el brazo
        solo_hombro = all(h in ("mixamorig_%sShoulder" % s, "mixamorig_%sArm" % s) for h in votos for s in [("Left" if "Left" in top else "Right")])
        if votos[top] / len(idx) >= UMBRAL_RIGIDA or pequena or solo_hombro:
            if solo_hombro and ("Shoulder" in top or "Arm" in top):
                top = "mixamorig_%sArm" % ("Left" if "Left" in top else "Right")
            for i in idx:
                pesos[i] = {top: 1.0}
            rigido[c] = top
            rigidas += 1
        else:
            mezcla += 1
    # Musgo y helechos (piezas diminutas): siguen a la roca grande MAS CERCANA (si es rigida, a su hueso; si no, a su mezcla), en vez de a la region de su centro.
    grandes = [i for i in range(n) if cajas[lab[i]][2] >= PIEZA_MINUSCULA]
    if grandes:
        kd = kdtree.KDTree(len(grandes))
        for k, i in enumerate(grandes):
            kd.insert(obj.data.vertices[i].co, k)
        kd.balance()
        movidas = 0
        for c in range(nc):
            if cajas[c][2] >= PIEZA_MINUSCULA:
                continue
            idx = [i for i in range(n) if lab[i] == c]
            cen = sum((obj.data.vertices[i].co for i in idx), Vector((0, 0, 0))) / len(idx)
            _, k, _ = kd.find(cen)
            ref = grandes[k]
            if lab[ref] in rigido:
                for i in idx:
                    pesos[i] = {rigido[lab[ref]]: 1.0}
            else:
                for i in idx:
                    pesos[i] = dict(pesos[ref])
            movidas += 1
        print("piezas diminutas (musgo) pegadas a la roca grande mas cercana: %d" % movidas)
    print("piezas rigidas %d  con mezcla %d" % (rigidas, mezcla))
    for g in list(obj.vertex_groups):
        obj.vertex_groups.remove(g)
    for m in list(obj.modifiers):
        obj.modifiers.remove(m)
    obj.parent = None
    for h in huesos:
        obj.vertex_groups.new(name=h)
    for i, d in pesos.items():
        tot = sum(d.values())
        for h, w in d.items():
            obj.vertex_groups[h].add([i], w / tot, "REPLACE")
    obj.parent = ao
    md = obj.modifiers.new("Armature", "ARMATURE")
    md.object = ao
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    ao.select_set(True)
    for img in bpy.data.images:
        if img.size[0] > TEXTURA:
            img.scale(TEXTURA, TEXTURA)
    print("texturas:", [(im.name, tuple(im.size)) for im in bpy.data.images])
    bpy.ops.export_scene.gltf(filepath=a[1], export_format="GLB", use_selection=True, export_animations=False, export_skins=True, export_yup=True,
                              export_image_format="JPEG", export_jpeg_quality=85)
    print("exportado", a[1])


main()
