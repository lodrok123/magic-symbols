"""
Autorig del goblin chaman (Meshy, SIN rig) con el ESQUELETO DE MARIMANTA, en Blender (modo fondo, determinista, relanzable):

    blender.exe -b --python tools/autorig_chaman.py -- [marimanta.glb] [goblin_chaman.glb] [salida.glb]

Por defecto: arte/modelos/marimanta.glb + arte/modelos/goblin_chaman.glb -> arte/modelos/goblin_chaman_rig.glb (el original queda intacto).
Pasos:
  1. Importa Marimanta (esqueleto de 66 huesos `mixamorig_*` con dedos + `headfront`, con su malla y sus pesos) y el chaman (malla sin rig, A-pose, origen en el centro).
     Lleva el chaman a los pies en z = 0 y centrado en x (queda a su altura de origen, ~0,95; no se escala la malla).
  2. ENCAJE DEL ESQUELETO: las articulaciones principales (cadera, columna, cuello, cabeza, hombros, codos, munecas, rodillas, tobillos, pies) se colocan en la malla del chaman
     (constantes `J_*` abajo, en metros para la altura de 0,95, medidas sobre goblin_chaman.glb y comprobadas con captura_rig_chaman.gd; las puntas de los dedos y de los pies se
     MIDEN de la malla). Los demas huesos (dedos, headfront) se colocan respecto a su hueso principal con la escala de la mano / la cabeza.
     CADA HUESO CONSERVA LA ORIENTACION (la base completa, con su roll) que tiene en Marimanta: asi el reposo del chaman tiene los mismos ejes locales y los clips de Marimanta
     se traducen casi sin diferencia (ClipsFamilia solo corrige proporciones: la cadera y la altura de los pies). La A-pose de la malla (41 grados) es la de ella.
  3. PESOS: se deforma la malla de Marimanta con SUS pesos hasta la pose y proporciones del esqueleto nuevo (piel lineal con una traslacion + escala por hueso: un «maniqui» a medida)
     y de esa superficie se transfieren los pesos a cada vertice del chaman por el punto mas cercano de la superficie, interpolado (equivale a Data Transfer, «Interpolated Nearest
     Face», hecho a mano para poder soldar las costuras de UV). Los vertices a mas de LEJOS_MAX del maniqui reciben pesos por cercania a los segmentos de hueso (en vez del
     Automatic Weights de Blender: no necesita colas de hueso razonables y es determinista). Reglas: el SOMBRERO y la cabeza (z >= Z_CABEZA) van enteros a `Head`, rigidos, con una
     rampa hasta el cuello; luego Smooth (promedio con los vecinos, N_SUAVIZADO pasadas, menos en la cabeza), maximo 4 influencias por vertice, normalizado.
  4. Reduce las texturas a TEXTURA px y exporta GLB (JPEG) con piel, textura embebida y SIN animaciones, en la misma orientacion (Y arriba, +Z delante).
Salida por consola: medidas y estadisticas.
"""
import os
import sys
import bpy
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from mathutils.interpolate import poly_3d_calc

TEXTURA = 1024
H_REF = 0.95                  # altura para la que van las constantes J_* (el GLB mide 0,9507)
LEJOS_MAX = 0.06              # un vertice a mas de esto (m) de la superficie del maniqui usa los pesos por segmento de hueso
Z_CABEZA = 0.600              # por encima, todo es del hueso Head (cara, orejas, sombrero)
RAMPA_CABEZA = 0.035          # por debajo de Z_CABEZA, el peso de Head baja a 0 en esta altura (cuello, solapa del sombrero, barba)
N_SUAVIZADO = 3               # pasadas de Smooth sobre los pesos
FACTOR_SUAVIZADO = 0.5
PESO_MIN = 0.02               # pesos menores se descartan
MAX_INFLUENCIAS = 4
Z_MANO_RIGIDA = False         # True = las manos enteras al hueso Hand (sin dedos independientes)

# Articulaciones del chaman (m, para H_REF; x del lado izquierdo del personaje = +x; Blender: z arriba, delante = -y). Medidas del GLB y comprobadas en captura.
YC = -0.010                   # eje de la columna y de la cabeza
J_ZC = {"Hips": 0.385, "Spine": 0.430, "Spine1": 0.476, "Spine2": 0.521, "Neck": 0.552, "Head": 0.593}
Z_CABEZA_TOP = 0.950
X_PIERNA = {"UpLeg": 0.062, "Leg": 0.068, "Foot": 0.077}
Z_PIERNA = {"UpLeg": 0.340, "Leg": 0.205, "Foot": 0.068}
Z_TOBILLO_PIE = 0.030         # altura de ToeBase
SHOULDER = Vector((0.088, -0.010, 0.500))       # origen del hueso Arm (el clavicula Shoulder nace en x = CLAVICULA_X sobre Spine2)
CLAVICULA_X = 0.030

PRINCIPALES = ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "HeadTop_End"] + [l + p for l in ("Left", "Right") for p in
               ("Shoulder", "Arm", "ForeArm", "Hand", "UpLeg", "Leg", "Foot", "ToeBase", "Toe_End")]
PRE = "mixamorig_"


def argumentos():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


def raiz_proyecto():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def corto(n):
    return n[len(PRE):] if n.startswith(PRE) else n


def importar(ruta):
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=ruta)
    return [o for o in bpy.data.objects if o not in antes]


# ---------------------------------------------------------------------------------------------------------------------------------------
#  Marimanta: huesos (orientacion y posicion en el mundo), malla y pesos
# ---------------------------------------------------------------------------------------------------------------------------------------
def leer_marimanta(ruta):
    nuevos = importar(ruta)
    ao = [o for o in nuevos if o.type == "ARMATURE"][0]
    malla = [o for o in nuevos if o.type == "MESH" and o.parent == ao][0]
    mw = ao.matrix_world
    huesos = {}
    for b in ao.data.bones:
        W = mw @ b.matrix_local
        huesos[b.name] = {"cabeza": (mw @ b.head_local).copy(), "cola": (mw @ b.tail_local).copy(), "R": W.to_3x3().normalized(),
                          "padre": b.parent.name if b.parent else None}
    mm = malla.matrix_world
    vs = [mm @ v.co for v in malla.data.vertices]
    grupos = [g.name for g in malla.vertex_groups]
    pesos = []
    for v in malla.data.vertices:
        pesos.append({grupos[g.group]: g.weight for g in v.groups if g.weight > 1e-4})
    malla.data.calc_loop_triangles()
    tris = [(t.vertices[0], t.vertices[1], t.vertices[2]) for t in malla.data.loop_triangles]
    for o in nuevos:
        bpy.data.objects.remove(o, do_unlink=True)
    return huesos, vs, pesos, tris


# ---------------------------------------------------------------------------------------------------------------------------------------
#  Chaman: malla en el origen
# ---------------------------------------------------------------------------------------------------------------------------------------
def leer_chaman(ruta):
    nuevos = importar(ruta)
    obj = [o for o in nuevos if o.type == "MESH"][0]
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in nuevos:
        if o != obj and o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    me = obj.data
    zmin = min(v.co.z for v in me.vertices)
    xmin = min(v.co.x for v in me.vertices)
    xmax = max(v.co.x for v in me.vertices)
    dx = -(xmin + xmax) / 2
    for v in me.vertices:
        v.co.z -= zmin
        v.co.x += dx
    me.update()
    return obj


def punta_mano(vs, signo):
    """Centro de los vertices mas alejados a lo largo del brazo (la punta de los dedos), del lado `signo` (+1 = izquierda del personaje)."""
    d = Vector((0.652 * signo, 0.0, -0.758))
    cand = [v for v in vs if v.x * signo > 0.17 and 0.26 < v.z < 0.42]
    cand.sort(key=lambda v: -(Vector((v.x, 0.0, v.z)).dot(d)))
    top = cand[:60]
    return sum(top, Vector()) / len(top)


def articulaciones(vs, hm):
    """Diccionario {nombre sin prefijo: posicion} de los huesos principales del chaman."""
    zmin = min(v.z for v in vs)
    H = max(v.z for v in vs) - zmin
    k = H / H_REF
    J = {}
    for n, z in J_ZC.items():
        J[n] = Vector((0.0, YC, z * k))
    J["HeadTop_End"] = Vector((0.0, YC + 0.01, Z_CABEZA_TOP * k))
    pie = [v for v in vs if v.z < 0.05 * k]
    y_punta = min(v.y for v in pie)
    for lado, s in (("Left", 1.0), ("Right", -1.0)):
        J[lado + "UpLeg"] = Vector((s * X_PIERNA["UpLeg"] * k, YC, Z_PIERNA["UpLeg"] * k))
        J[lado + "Leg"] = Vector((s * X_PIERNA["Leg"] * k, YC - 0.005, Z_PIERNA["Leg"] * k))
        J[lado + "Foot"] = Vector((s * X_PIERNA["Foot"] * k, -0.013, Z_PIERNA["Foot"] * k))
        J[lado + "ToeBase"] = Vector((s * (X_PIERNA["Foot"] + 0.002) * k, y_punta * 0.55 - 0.013 * 0.45, Z_TOBILLO_PIE * k))
        J[lado + "Toe_End"] = Vector((s * (X_PIERNA["Foot"] + 0.003) * k, y_punta + 0.006, 0.013 * k))
        J[lado + "Shoulder"] = Vector((s * CLAVICULA_X * k, YC, J_ZC["Spine2"] * k - 0.006))
        sh = Vector((s * SHOULDER.x * k, SHOULDER.y, SHOULDER.z * k))
        J[lado + "Arm"] = sh
        punta = punta_mano(vs, s)
        # fracciones del brazo de Marimanta a lo largo de hombro -> punta de dedos (HandMiddle4)
        a = hm[PRE + lado + "Arm"]["cabeza"]
        codo = hm[PRE + lado + "ForeArm"]["cabeza"]
        mu = hm[PRE + lado + "Hand"]["cabeza"]
        pm = hm[PRE + lado + "HandMiddle4"]["cola"]
        tot = (pm - a).length
        f1 = (codo - a).length / tot
        f2 = (mu - a).length / tot
        J[lado + "ForeArm"] = sh + (punta - sh) * f1
        J[lado + "Hand"] = sh + (punta - sh) * f2
        J[lado + "_punta"] = punta
    return J


# ---------------------------------------------------------------------------------------------------------------------------------------
#  Armadura nueva: misma jerarquia, mismas orientaciones, posiciones del chaman
# ---------------------------------------------------------------------------------------------------------------------------------------
def ancestro_principal(nombre, hm):
    """El hueso principal del que cuelga (o el mismo si lo es)."""
    n = nombre
    while n is not None:
        if corto(n) in PRINCIPALES:
            return corto(n)
        n = hm[n]["padre"]
    return None


def posiciones_nuevas(hm, J, vs_ch):
    """Cabeza de cada hueso en el chaman. Principales: de J. El resto: respecto a su principal, con la escala de la mano o de la cabeza."""
    esc_mano = {}
    for lado in ("Left", "Right"):
        wm = hm[PRE + lado + "Hand"]["cabeza"]
        tm = hm[PRE + lado + "HandMiddle4"]["cola"]
        esc_mano[lado] = (J[lado + "_punta"] - J[lado + "Hand"]).length / (tm - wm).length
    hd_m = hm[PRE + "HeadTop_End"]["cabeza"] - hm[PRE + "Head"]["cabeza"]
    esc_cabeza = (J["HeadTop_End"] - J["Head"]).length / hd_m.length
    pos, esc = {}, {}
    for n, h in hm.items():
        c = corto(n)
        anc = ancestro_principal(n, hm)
        if c in PRINCIPALES:
            pos[n] = J[c].copy()
            esc[n] = 1.0
            continue
        if anc is None:
            anc = "Head"
        if anc.endswith("Hand"):
            k = esc_mano["Left" if anc.startswith("Left") else "Right"]
        elif anc in ("Head", "HeadTop_End"):
            k = esc_cabeza
        else:
            k = 1.0
        pos[n] = J[anc] + (h["cabeza"] - hm[PRE + anc]["cabeza"]) * k
        esc[n] = k
    # headfront: delante de la cara (superficie real del chaman a la altura de la cabeza)
    cara = [v for v in vs_ch if abs(v.x) < 0.04 and 0.60 < v.z < 0.72]
    if cara and "headfront" in pos:
        pos["headfront"] = Vector((0.0, min(v.y for v in cara) + 0.01, J["Head"].z))
    return pos, esc


def hijos_de(hm):
    h = {n: [] for n in hm}
    for n, d in hm.items():
        if d["padre"]:
            h[d["padre"]].append(n)
    return h


def crear_armadura(hm, pos, esc):
    arm = bpy.data.armatures.new("Armature")
    ao = bpy.data.objects.new("Armature", arm)
    bpy.context.scene.collection.objects.link(ao)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = ao
    ao.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.edit_bones
    hijos = hijos_de(hm)
    for n, d in hm.items():
        b = eb.new(n)
        h = pos[n]
        b.head = h
        b.tail = h + Vector((0.0, 0.0, 0.05))
        b.matrix = Matrix.Translation(h) @ d["R"].to_4x4()
        # longitud: hasta el hijo (en el chaman) si lo hay; si no, la de Marimanta escalada
        if hijos[n]:
            L = sum(((pos[c] - h).length for c in hijos[n]), 0.0) / len(hijos[n])
        else:
            L = (d["cola"] - d["cabeza"]).length * esc[n]
        b.length = max(L, 0.012)
    for n, d in hm.items():
        if d["padre"]:
            eb[n].parent = eb[d["padre"]]
    bpy.ops.object.mode_set(mode="OBJECT")
    return ao


# ---------------------------------------------------------------------------------------------------------------------------------------
#  Pesos
# ---------------------------------------------------------------------------------------------------------------------------------------
def escalas_hueso(hm, pos, esc):
    """Escala por hueso del maniqui: distancia al hijo principal nuevo / vieja (los dedos y la cabeza, la de su grupo)."""
    k = {}
    hijos = hijos_de(hm)
    for n, d in hm.items():
        if corto(n) in PRINCIPALES and hijos[n]:
            best = None
            for c in hijos[n]:
                if corto(c) in PRINCIPALES:
                    best = c
                    break
            if best is None and corto(n).endswith("Hand"):
                k[n] = esc.get(hijos[n][0], 1.0)
                continue
            if best is not None:
                lo = (hm[best]["cabeza"] - d["cabeza"]).length
                ln = (pos[best] - pos[n]).length
                k[n] = ln / lo if lo > 1e-6 else 1.0
                continue
        k[n] = esc[n]
    # la cabeza escala como su altura (HeadTop_End no tiene hijo)
    k[PRE + "HeadTop_End"] = k[PRE + "Head"]
    return k


def maniqui(vs_m, pesos_m, hm, pos, k):
    """Posiciones de los vertices de Marimanta llevados al esqueleto del chaman (piel lineal: traslacion + escala por hueso)."""
    res = []
    for v, w in zip(vs_m, pesos_m):
        p = Vector()
        tot = 0.0
        for n, x in w.items():
            if n not in hm:
                continue
            p += x * (pos[n] + k[n] * (v - hm[n]["cabeza"]))
            tot += x
        res.append(p / tot if tot > 1e-6 else v.copy())
    return res


def dist_segmento(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
    return (p - (a + ab * t)).length


def pesos_por_segmento(p, segs):
    ds = sorted((dist_segmento(p, a, b), n) for n, (a, b) in segs.items())[:3]
    w = {n: 1.0 / (d + 0.01) ** 3 for d, n in ds}
    t = sum(w.values())
    return {n: x / t for n, x in w.items()}


def soldar(obj):
    """Etiqueta cada vertice con su grupo de posicion (las costuras de UV duplican vertices). Devuelve (etiqueta por vertice, posiciones del grupo, vecinos por grupo)."""
    me = obj.data
    claves = {}
    et = []
    pos = []
    for v in me.vertices:
        k = (round(v.co.x * 20000), round(v.co.y * 20000), round(v.co.z * 20000))
        if k not in claves:
            claves[k] = len(pos)
            pos.append(v.co.copy())
        et.append(claves[k])
    vec = [set() for _ in pos]
    for e in me.edges:
        a, b = et[e.vertices[0]], et[e.vertices[1]]
        if a != b:
            vec[a].add(b)
            vec[b].add(a)
    return et, pos, vec


def calcular_pesos(obj, hm, vs_m, pesos_m, tris_m, pos, k):
    et, gpos, vecinos = soldar(obj)
    print("vertices %d, posiciones soldadas %d" % (len(et), len(gpos)))
    mq = maniqui(vs_m, pesos_m, hm, pos, k)
    bvh = BVHTree.FromPolygons([tuple(p) for p in mq], tris_m)
    segs = {}
    hijos = hijos_de(hm)
    for n in hm:
        h = pos[n]
        if hijos[n]:
            t = sum((pos[c] for c in hijos[n]), Vector()) / len(hijos[n])
        else:
            t = h + hm[n]["R"].col[1] * 0.02
        segs[n] = (h, t)
    W = []
    lejos = 0
    maxd = 0.0
    for p in gpos:
        loc, nor, idx, d = bvh.find_nearest(p)
        if loc is None:
            W.append(pesos_por_segmento(p, segs))
            lejos += 1
            continue
        maxd = max(maxd, d)
        if d > LEJOS_MAX:
            W.append(pesos_por_segmento(p, segs))
            lejos += 1
            continue
        tri = tris_m[idx]
        wb = poly_3d_calc([mq[i] for i in tri], loc)
        w = {}
        for i, b in zip(tri, wb):
            for n, x in pesos_m[i].items():
                w[n] = w.get(n, 0.0) + x * b
        t = sum(w.values())
        W.append({n: x / t for n, x in w.items()} if t > 1e-6 else pesos_por_segmento(p, segs))
    print("transferencia: %d posiciones a mas de %.2f m del maniqui (por segmento de hueso); distancia maxima %.3f" % (lejos, LEJOS_MAX, maxd))
    # reglas
    head = PRE + "Head"
    congelado = [False] * len(gpos)
    for i, p in enumerate(gpos):
        if p.z >= Z_CABEZA:
            W[i] = {head: 1.0}
            congelado[i] = True
        elif p.z > Z_CABEZA - RAMPA_CABEZA:
            t = (p.z - (Z_CABEZA - RAMPA_CABEZA)) / RAMPA_CABEZA
            t = t * t * (3.0 - 2.0 * t)
            w = {n: x * (1.0 - t) for n, x in W[i].items()}
            w[head] = w.get(head, 0.0) + t
            W[i] = w
    if Z_MANO_RIGIDA:
        for i, p in enumerate(gpos):
            if abs(p.x) > 0.20 and p.z < 0.38:
                W[i] = {PRE + ("LeftHand" if p.x > 0 else "RightHand"): 1.0}
                congelado[i] = True
    # smooth
    for _ in range(N_SUAVIZADO):
        nuevo = []
        for i, w in enumerate(W):
            if congelado[i] or not vecinos[i]:
                nuevo.append(w)
                continue
            acc = {n: x * (1.0 - FACTOR_SUAVIZADO) for n, x in w.items()}
            f = FACTOR_SUAVIZADO / len(vecinos[i])
            for j in vecinos[i]:
                for n, x in W[j].items():
                    acc[n] = acc.get(n, 0.0) + x * f
            nuevo.append(acc)
        W = nuevo
    # maximo 4 influencias, normalizado
    final = []
    for w in W:
        items = sorted(((x, n) for n, x in w.items() if x >= PESO_MIN), reverse=True)[:MAX_INFLUENCIAS]
        if not items:
            items = sorted(((x, n) for n, x in w.items()), reverse=True)[:1]
        t = sum(x for x, _ in items)
        final.append({n: x / t for x, n in items})
    return et, final


def aplicar_pesos(obj, ao, hm, et, W):
    for g in list(obj.vertex_groups):
        obj.vertex_groups.remove(g)
    for n in hm:
        obj.vertex_groups.new(name=n)
    por_grupo = {}
    for i, e in enumerate(et):
        for n, x in W[e].items():
            por_grupo.setdefault((n, round(x, 4)), []).append(i)
    for (n, x), idx in por_grupo.items():
        obj.vertex_groups[n].add(idx, x, "REPLACE")
    obj.parent = ao
    md = obj.modifiers.new("Armature", "ARMATURE")
    md.object = ao


def main():
    a = argumentos()
    r = raiz_proyecto()
    ruta_m = a[0] if len(a) > 0 else os.path.join(r, "arte", "modelos", "marimanta.glb")
    ruta_c = a[1] if len(a) > 1 else os.path.join(r, "arte", "modelos", "goblin_chaman.glb")
    salida = a[2] if len(a) > 2 else os.path.join(r, "arte", "modelos", "goblin_chaman_rig.glb")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    hm, vs_m, pesos_m, tris_m = leer_marimanta(ruta_m)
    print("Marimanta: %d huesos, %d vertices" % (len(hm), len(vs_m)))
    obj = leer_chaman(ruta_c)
    vs = [v.co.copy() for v in obj.data.vertices]
    J = articulaciones(vs, hm)
    for n in ("Hips", "Head", "LeftArm", "LeftForeArm", "LeftHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "LeftToe_End", "Left_punta"):
        if n in J:
            print("  J[%s] = (%.3f, %.3f, %.3f)" % (n, J[n].x, J[n].y, J[n].z))
    pos, esc = posiciones_nuevas(hm, J, vs)
    ao = crear_armadura(hm, pos, esc)
    # comprobacion: la base de cada hueso nueva = la de Marimanta
    peor = 0.0
    for b in ao.data.bones:
        d = b.matrix_local.to_3x3().normalized() - hm[b.name]["R"]
        peor = max(peor, max(abs(x) for f in d for x in f))
    print("diferencia maxima de base de hueso respecto a Marimanta: %.5f" % peor)
    k = escalas_hueso(hm, pos, esc)
    et, W = calcular_pesos(obj, hm, vs_m, pesos_m, tris_m, pos, k)
    aplicar_pesos(obj, ao, hm, et, W)
    for img in bpy.data.images:
        if img.size[0] > TEXTURA:
            img.scale(TEXTURA, TEXTURA)
    print("texturas:", [(im.name, tuple(im.size)) for im in bpy.data.images])
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    ao.select_set(True)
    bpy.context.view_layer.objects.active = ao
    bpy.ops.export_scene.gltf(filepath=salida, export_format="GLB", use_selection=True, export_animations=False, export_skins=True, export_yup=True,
                              export_image_format="JPEG", export_jpeg_quality=85)
    print("exportado", salida)


main()
