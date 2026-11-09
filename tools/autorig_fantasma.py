"""
Autorig del fantasma elfo (Meshy, SIN rig) con el ESQUELETO DE elfo_base, en Blender (modo fondo, determinista, relanzable):

    blender.exe -b --python tools/autorig_fantasma.py -- [elfo_base.glb] [fantasma_elfo.glb] [salida.glb]

Por defecto: arte/modelos/elfo_base.glb + arte/modelos/fantasma_elfo.glb -> arte/modelos/fantasma_elfo_rig.glb (el original queda intacto).

Es el mismo flujo que tools/autorig_chaman.py (docs/PLAN_RIGGING.md Â§3), con DOS diferencias:

  1. ENCAJE POR ESCALADO, sin constantes medidas a mano. El chaman necesitaba una tabla `J_*` con cada articulacion medida sobre su malla
     porque Marimanta (anciana encorvada, 1,70 u) y el no se parecen. Aqui las dos mallas salen de la misma base: miden 0,9783 y 0,9497 de alto
     y su ANCHURA coincide (0,6183 y 0,6187, la punta de los dedos de las dos manos), asi que el esqueleto del donante escalado por la relacion
     de alturas ya cae dentro de la malla en las 23 articulaciones principales. Se escala en z por la altura y en x/y por la anchura (K_XY, K_Z),
     que es lo correcto cuando un modelo es mas bajo pero igual de ancho, y CADA HUESO CONSERVA LA BASE COMPLETA (orientacion y roll) del donante:
     asi el reposo tiene los mismos ejes locales y los clips de la elfa (chibi_elf, via ClipsFamilia) se traducen casi sin diferencia.

  2. REGLA DE TELA para la capa y la tunica abierta (Pablo, 9/11: la capa va FUNDIDA en la malla, no como pieza de Ropa3D). El donante no lleva
     capa, asi que sus picos quedan lejos del maniqui y, por cercania, los cogerian las PIERNAS: al andar, la tela se rasgaria entre las dos.
     Los vertices de tela por debajo de la cadera se pesan a Hips (con una rampa hacia las piernas segun lo cerca que esten de ellas), que es como
     se resuelve una falda: cuelga rigida de la cadera en vez de romperse. Los de arriba (la capa sobre los hombros) los coge la transferencia normal.

Pasos: 1) lee el donante (huesos, malla y pesos) 2) encaja el esqueleto escalado 3) transfiere los pesos deformando la malla del donante hasta el
esqueleto nuevo (maniqui) y tomando para cada vertice el punto mas cercano de esa superficie 4) reduce texturas y exporta GLB sin animaciones.
"""
import os
import sys

import bpy
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from mathutils.interpolate import poly_3d_calc

TEXTURA = 1024
LEJOS_MAX = 0.06              # un vertice a mas de esto (m) de la superficie del maniqui no recibe pesos por transferencia
PESO_MIN = 0.02
MAX_INFLUENCIAS = 4
N_SUAVIZADO = 3
FACTOR_SUAVIZADO = 0.5

# Cabeza rigida: por encima de Z_CABEZA (fraccion de la altura) todo es del hueso Head (cara, orejas puntiagudas, melena, diadema).
# El pelo del fantasma baja hasta la mandibula, asi que el corte va bajo el menton y la rampa lo funde con el cuello.
F_Z_CABEZA = 0.80
F_RAMPA_CABEZA = 0.05

# Regla de tela (capa y tunica): por debajo de la cadera, un vertice a mas de LEJOS_TELA del maniqui es tela suelta.
LEJOS_TELA = 0.050            # el brazo del destino es mas largo que el del donante, asi que su PIEL tambien se separa algo del maniqui:
                              # por debajo de este umbral se transfiere normal, y solo lo muy despegado (la capa llega a 0,12) es tela
R_BRAZO = 0.050               # un vertice a menos de esto del eje del brazo nunca es tela: es piel del brazo o manga
F_PEGADO_PIERNA = 0.045       # a menos de esto del eje de una pierna, la tela sigue a la pierna; mas lejos, a la cadera

PRINCIPALES = ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "HeadTop_End"] + [
    l + p for l in ("Left", "Right") for p in ("Shoulder", "Arm", "ForeArm", "Hand", "UpLeg", "Leg", "Foot", "ToeBase", "Toe_End")]


def argumentos():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


def raiz_proyecto():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def importar(ruta):
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=ruta)
    return [o for o in bpy.data.objects if o not in antes]


# ---------------------------------------------------------------------------------------------------------------------------------------
#  Donante: huesos (orientacion y posicion en el mundo), malla y pesos
# ---------------------------------------------------------------------------------------------------------------------------------------
def leer_donante(ruta):
    """elfo_base trae una Icosphere suelta de 42 vertices (basura del exportador): se toma la malla CON modificador Armature."""
    nuevos = importar(ruta)
    ao = [o for o in nuevos if o.type == "ARMATURE"][0]
    pesadas = [o for o in nuevos if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers)]
    if not pesadas:
        pesadas = [o for o in nuevos if o.type == "MESH" and o.parent == ao]
    malla = max(pesadas, key=lambda o: len(o.data.vertices))
    sueltas = [o.name for o in nuevos if o.type == "MESH" and o is not malla]
    if sueltas:
        print("donante: mallas sueltas ignoradas: %s" % sueltas)
    mw = ao.matrix_world
    huesos = {}
    for b in ao.data.bones:
        W = mw @ b.matrix_local
        huesos[b.name] = {"cabeza": (mw @ b.head_local).copy(), "cola": (mw @ b.tail_local).copy(),
                          "R": W.to_3x3().normalized(), "padre": b.parent.name if b.parent else None}
    mm = malla.matrix_world
    vs = [mm @ v.co for v in malla.data.vertices]
    grupos = [g.name for g in malla.vertex_groups]
    pesos = [{grupos[g.group]: g.weight for g in v.groups if g.weight > 1e-4} for v in malla.data.vertices]
    malla.data.calc_loop_triangles()
    tris = [(t.vertices[0], t.vertices[1], t.vertices[2]) for t in malla.data.loop_triangles]
    caja = (min(v.x for v in vs), max(v.x for v in vs), min(v.z for v in vs), max(v.z for v in vs))
    for o in nuevos:
        bpy.data.objects.remove(o, do_unlink=True)
    return huesos, vs, pesos, tris, caja


def prefijo_de(huesos):
    """'mixamorig:' en elfo_base (Tripo), 'mixamorig_' en los que pasaron por FBX. Se CONSERVAN los nombres del donante."""
    n = next(iter(huesos))
    for p in ("mixamorig:", "mixamorig_"):
        if n.startswith(p):
            return p
    return ""


# ---------------------------------------------------------------------------------------------------------------------------------------
#  Destino: malla con los pies en z = 0 y centrada en x
# ---------------------------------------------------------------------------------------------------------------------------------------
def leer_destino(ruta):
    nuevos = importar(ruta)
    obj = max((o for o in nuevos if o.type == "MESH"), key=lambda o: len(o.data.vertices))
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if obj.parent:
        bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in nuevos:
        if o is not obj:
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


def comprobar_orientacion(vs, huesos, pre):
    """Los dos miran al mismo lado si la punta del pie del destino cae del mismo lado en y que la del donante."""
    pie_don = huesos[pre + "LeftToeBase"]["cola"].y - huesos[pre + "LeftFoot"]["cabeza"].y
    alto = max(v.z for v in vs)
    bajos = [v for v in vs if v.z < alto * 0.04]
    centro_y = sum((v.y for v in bajos), 0.0) / len(bajos)
    punta = min(bajos, key=lambda v: v.y) if pie_don < 0 else max(bajos, key=lambda v: v.y)
    pie_dst = punta.y - centro_y
    ok = (pie_don < 0) == (pie_dst < 0)
    print("orientacion: punta del pie donante %+.3f, destino %+.3f -> %s" % (pie_don, pie_dst, "igual" if ok else "*** OPUESTA ***"))
    return ok


# ---------------------------------------------------------------------------------------------------------------------------------------
#  Encaje: el esqueleto del donante escalado a la malla nueva
# ---------------------------------------------------------------------------------------------------------------------------------------
def eje_brazo(vs, signo, z0, alto, z_hombro):
    """Polilinea del eje de un brazo, medida en la malla: por rebanadas de altura, el centro del CLUSTER MAS EXTERNO en x.

    Hace falta porque el brazo del destino y el del donante no estan en la misma A-pose (el donante se abre a 32 grados y el
    fantasma cuelga mas recto, con el brazo mas largo): escalar el esqueleto deja el hueso fuera del brazo y, al animarlo, se estira.
    El cluster externo descarta la capa y la tunica, que a esas alturas quedan mas cerca del eje del cuerpo que la mano.
    """
    puntos = []
    f0 = (z_hombro - z0) / alto
    n = 14
    for i in range(n + 1):
        f = f0 - (f0 - 0.30) * i / n
        z = z0 + alto * f
        s = [v for v in vs if abs(v.z - z) < alto * 0.013 and v.x * signo > 0.085]
        if len(s) < 8:
            continue
        s.sort(key=lambda v: -v.x * signo)
        ext = s[:max(6, int(len(s) * 0.35))]
        c = sum(ext, Vector()) / len(ext)
        puntos.append(Vector((c.x, c.y, z)))
    return puntos


def sobre_polilinea(pts, f):
    """Punto a la fraccion f (0..1) de la longitud de la polilinea."""
    if not pts:
        return None
    largos = [0.0]
    for a, b in zip(pts, pts[1:]):
        largos.append(largos[-1] + (b - a).length)
    total = largos[-1]
    if total < 1e-6:
        return pts[0].copy()
    d = f * total
    for i in range(1, len(largos)):
        if largos[i] >= d:
            t = (d - largos[i - 1]) / max(largos[i] - largos[i - 1], 1e-9)
            return pts[i - 1].lerp(pts[i], t)
    return pts[-1].copy()


def encajar_brazos(huesos, pre, pos, vs_dst, alto):
    """Mueve ForeArm, Hand y los dedos al eje real del brazo del destino, conservando las fracciones del donante."""
    z0 = 0.0
    hijos = hijos_de(huesos)
    for lado, signo in (("Left", 1.0), ("Right", -1.0)):
        nA, nF, nH = pre + lado + "Arm", pre + lado + "ForeArm", pre + lado + "Hand"
        punta_don = huesos.get(pre + lado + "HandMiddle4", huesos[nH])["cola"]
        a_don, f_don, h_don = huesos[nA]["cabeza"], huesos[nF]["cabeza"], huesos[nH]["cabeza"]
        tot = (punta_don - a_don).length
        f1 = (f_don - a_don).length / tot
        f2 = (h_don - a_don).length / tot

        pts = eje_brazo(vs_dst, signo, z0, alto, pos[nA].z)
        if len(pts) < 4:
            print("  brazo %s: no se pudo medir el eje (%d rebanadas), se deja el escalado" % (lado, len(pts)))
            continue
        # el eje empieza en el hombro ya colocado
        pts[0] = pos[nA].copy()
        nuevo_F = sobre_polilinea(pts, f1)
        nuevo_H = sobre_polilinea(pts, f2)
        punta_new = pts[-1]
        viejo_F, viejo_H = pos[nF].copy(), pos[nH].copy()
        k_mano = (punta_new - nuevo_H).length / max((punta_don - h_don).length, 1e-6)
        pos[nF] = nuevo_F
        pos[nH] = nuevo_H
        # los dedos cuelgan de Hand: se mueven con el y se escalan con la mano
        for n in huesos:
            if n in (nA, nF, nH):
                continue
            p = n
            dedo = False
            while p is not None:
                if p == nH:
                    dedo = True
                    break
                p = huesos[p]["padre"]
            if dedo:
                pos[n] = nuevo_H + (huesos[n]["cabeza"] - h_don) * k_mano
        print("  brazo %-5s: codo (%.3f,%.3f,%.3f)->(%.3f,%.3f,%.3f)  muneca (%.3f,%.3f,%.3f)->(%.3f,%.3f,%.3f)  mano x%.2f"
              % (lado, viejo_F.x, viejo_F.y, viejo_F.z, nuevo_F.x, nuevo_F.y, nuevo_F.z,
                 viejo_H.x, viejo_H.y, viejo_H.z, nuevo_H.x, nuevo_H.y, nuevo_H.z, k_mano))
    return pos


def posiciones_escaladas(huesos, caja_don, vs_dst):
    """Cabeza de cada hueso: la del donante, con z por la relacion de ALTURAS y x/y por la de ANCHURAS (mismo ancho, menos alto)."""
    x0d, x1d, z0d, z1d = caja_don
    alto_don = z1d - z0d
    ancho_don = x1d - x0d
    alto_dst = max(v.z for v in vs_dst)
    ancho_dst = max(v.x for v in vs_dst) - min(v.x for v in vs_dst)
    kz = alto_dst / alto_don
    kxy = ancho_dst / ancho_don
    print("escala: altura %.4f -> %.4f (kz %.4f)   anchura %.4f -> %.4f (kxy %.4f)" % (alto_don, alto_dst, kz, ancho_don, ancho_dst, kxy))
    pos = {}
    for n, d in huesos.items():
        c = d["cabeza"]
        pos[n] = Vector((c.x * kxy, c.y * kxy, (c.z - z0d) * kz))
    return pos, kz, kxy


def hijos_de(huesos):
    h = {n: [] for n in huesos}
    for n, d in huesos.items():
        if d["padre"]:
            h[d["padre"]].append(n)
    return h


def crear_armadura(huesos, pos):
    arm = bpy.data.armatures.new("Armature")
    ao = bpy.data.objects.new("Armature", arm)
    bpy.context.scene.collection.objects.link(ao)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = ao
    ao.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.edit_bones
    hijos = hijos_de(huesos)
    for n, d in huesos.items():
        b = eb.new(n)
        h = pos[n]
        b.head = h
        b.tail = h + Vector((0.0, 0.0, 0.05))
        b.matrix = Matrix.Translation(h) @ d["R"].to_4x4()
        if hijos[n]:
            L = sum(((pos[c] - h).length for c in hijos[n]), 0.0) / len(hijos[n])
        else:
            L = (d["cola"] - d["cabeza"]).length
        b.length = max(L, 0.010)
    for n, d in huesos.items():
        if d["padre"]:
            eb[n].parent = eb[d["padre"]]
    bpy.ops.object.mode_set(mode="OBJECT")
    return ao


# ---------------------------------------------------------------------------------------------------------------------------------------
#  Pesos
# ---------------------------------------------------------------------------------------------------------------------------------------
def escalas_hueso(huesos, pos):
    """Escala del maniqui por hueso: longitud nueva / vieja hasta su primer hijo (los extremos heredan la de su padre)."""
    k = {}
    hijos = hijos_de(huesos)
    for n, d in huesos.items():
        if hijos[n]:
            lo = sum(((huesos[c]["cabeza"] - d["cabeza"]).length for c in hijos[n]), 0.0) / len(hijos[n])
            ln = sum(((pos[c] - pos[n]).length for c in hijos[n]), 0.0) / len(hijos[n])
            k[n] = ln / lo if lo > 1e-6 else 1.0
        else:
            k[n] = None
    for n in list(k):
        if k[n] is None:
            p = huesos[n]["padre"]
            k[n] = k.get(p) or 1.0
    return k


def maniqui(vs_don, pesos_don, huesos, pos, k):
    """La malla del donante llevada al esqueleto nuevo (piel lineal: traslacion + escala por hueso)."""
    res = []
    for v, w in zip(vs_don, pesos_don):
        p = Vector()
        tot = 0.0
        for n, x in w.items():
            if n not in huesos:
                continue
            p += x * (pos[n] + k[n] * (v - huesos[n]["cabeza"]))
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
    """Une los vertices duplicados por las costuras de UV: etiqueta por vertice, posicion por grupo y vecinos por grupo."""
    me = obj.data
    claves = {}
    et = []
    pos = []
    for v in me.vertices:
        c = (round(v.co.x * 20000), round(v.co.y * 20000), round(v.co.z * 20000))
        if c not in claves:
            claves[c] = len(pos)
            pos.append(v.co.copy())
        et.append(claves[c])
    vec = [set() for _ in pos]
    for e in me.edges:
        a, b = et[e.vertices[0]], et[e.vertices[1]]
        if a != b:
            vec[a].add(b)
            vec[b].add(a)
    return et, pos, vec


def calcular_pesos(obj, huesos, pre, vs_don, pesos_don, tris_don, pos, k, alto):
    et, gpos, vecinos = soldar(obj)
    print("vertices %d, posiciones soldadas %d" % (len(et), len(gpos)))
    mq = maniqui(vs_don, pesos_don, huesos, pos, k)
    bvh = BVHTree.FromPolygons([tuple(p) for p in mq], tris_don)
    hijos = hijos_de(huesos)
    segs = {}
    for n in huesos:
        h = pos[n]
        t = (sum((pos[c] for c in hijos[n]), Vector()) / len(hijos[n])) if hijos[n] else (h + huesos[n]["R"].col[1] * 0.02)
        segs[n] = (h, t)
    piernas = [(pre + l + p) for l in ("Left", "Right") for p in ("UpLeg", "Leg")]
    columna = [pre + n for n in ("Hips", "Spine", "Spine1", "Spine2")]
    brazos = [(pre + l + p) for l in ("Left", "Right") for p in ("Arm", "ForeArm", "Hand")]
    z_cadera = pos[pre + "Hips"].z
    z_cuello = pos[pre + "Neck"].z

    W = []
    lejos = tela = 0
    maxd = 0.0
    for p in gpos:
        loc, nor, idx, d = bvh.find_nearest(p)
        d = d if loc is not None else 1e9
        maxd = max(maxd, d if d < 1e8 else 0.0)
        # TELA: despegada del cuerpo (el donante no lleva capa, asi que su piel SI esta en el maniqui y la tela no) y por debajo del
        # cuello, para no robarle el pelo ni las orejas a la cabeza.
        db = min(dist_segmento(p, *segs[n]) for n in brazos)
        if p.z < z_cuello and d > LEJOS_TELA and db > R_BRAZO:
            if p.z < z_cadera:
                # falda y picos bajos: cuelgan de la cadera, con mezcla hacia la pierna que tengan al lado
                dp = min(dist_segmento(p, *segs[n]) for n in piernas)
                t = min(1.0, max(0.0, (dp - F_PEGADO_PIERNA) / F_PEGADO_PIERNA))
                t = t * t * (3.0 - 2.0 * t)
                w = pesos_por_segmento(p, {n: segs[n] for n in piernas})
                w = {n: x * (1.0 - t) for n, x in w.items()}
                w[pre + "Hips"] = w.get(pre + "Hips", 0.0) + t
            else:
                # capa sobre los hombros: cuelga de la COLUMNA. Sin esto se la llevan los brazos, que pasan justo por dentro de ella,
                # y al levantarlos la capa sube como un ala.
                w = pesos_por_segmento(p, {n: segs[n] for n in columna})
            W.append(w)
            tela += 1
            continue
        if loc is None or d > LEJOS_MAX:
            W.append(pesos_por_segmento(p, segs))
            lejos += 1
            continue
        tri = tris_don[idx]
        wb = poly_3d_calc([mq[i] for i in tri], loc)
        w = {}
        for i, b in zip(tri, wb):
            for n, x in pesos_don[i].items():
                w[n] = w.get(n, 0.0) + x * b
        s = sum(w.values())
        W.append({n: x / s for n, x in w.items()} if s > 1e-6 else pesos_por_segmento(p, segs))
    print("transferencia: %d posiciones de TELA a la cadera, %d lejos del maniqui por segmento de hueso; distancia maxima %.3f"
          % (tela, lejos, maxd))

    # cabeza rigida (cara, orejas, melena, diadema) con rampa hacia el cuello
    head = pre + "Head"
    z_cab = alto * F_Z_CABEZA
    rampa = alto * F_RAMPA_CABEZA
    congelado = [False] * len(gpos)
    for i, p in enumerate(gpos):
        if p.z >= z_cab:
            W[i] = {head: 1.0}
            congelado[i] = True
        elif p.z > z_cab - rampa:
            t = (p.z - (z_cab - rampa)) / rampa
            t = t * t * (3.0 - 2.0 * t)
            w = {n: x * (1.0 - t) for n, x in W[i].items()}
            w[head] = w.get(head, 0.0) + t
            W[i] = w

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

    final = []
    for w in W:
        items = sorted(((x, n) for n, x in w.items() if x >= PESO_MIN), reverse=True)[:MAX_INFLUENCIAS]
        if not items:
            items = sorted(((x, n) for n, x in w.items()), reverse=True)[:1]
        s = sum(x for x, _ in items)
        final.append({n: x / s for x, n in items})
    return et, final


def aplicar_pesos(obj, ao, huesos, et, W):
    for g in list(obj.vertex_groups):
        obj.vertex_groups.remove(g)
    for n in huesos:
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
    ruta_don = a[0] if len(a) > 0 else os.path.join(r, "arte", "modelos", "elfo_base.glb")
    ruta_dst = a[1] if len(a) > 1 else os.path.join(r, "arte", "modelos", "fantasma_elfo.glb")
    salida = a[2] if len(a) > 2 else os.path.join(r, "arte", "modelos", "fantasma_elfo_rig.glb")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    huesos, vs_don, pesos_don, tris_don, caja_don = leer_donante(ruta_don)
    pre = prefijo_de(huesos)
    print("donante: %d huesos (prefijo '%s'), %d vertices" % (len(huesos), pre, len(vs_don)))
    faltan = [n for n in PRINCIPALES if pre + n not in huesos]
    if faltan:
        print("*** el donante no tiene: %s" % faltan)

    obj = leer_destino(ruta_dst)
    vs = [v.co.copy() for v in obj.data.vertices]
    alto = max(v.z for v in vs)
    print("destino: %d vertices, alto %.4f" % (len(vs), alto))
    comprobar_orientacion(vs, huesos, pre)

    pos, kz, kxy = posiciones_escaladas(huesos, caja_don, vs)
    pos = encajar_brazos(huesos, pre, pos, vs, alto)
    for n in ("Hips", "Spine2", "Neck", "Head", "LeftArm", "LeftForeArm", "LeftHand", "LeftUpLeg", "LeftLeg", "LeftFoot"):
        p = pos[pre + n]
        print("  %-12s (%6.3f, %6.3f, %6.3f)" % (n, p.x, p.y, p.z))

    ao = crear_armadura(huesos, pos)
    peor = 0.0
    for b in ao.data.bones:
        d = b.matrix_local.to_3x3().normalized() - huesos[b.name]["R"]
        peor = max(peor, max(abs(x) for f in d for x in f))
    print("diferencia maxima de base de hueso respecto al donante: %.6f" % peor)

    k = escalas_hueso(huesos, pos)
    et, W = calcular_pesos(obj, huesos, pre, vs_don, pesos_don, tris_don, pos, k, alto)
    aplicar_pesos(obj, ao, huesos, et, W)

    inf = [len(w) for w in W]
    print("influencias por vertice: max %d, media %.2f" % (max(inf), sum(inf) / len(inf)))

    for img in bpy.data.images:
        if img.size[0] > TEXTURA:
            img.scale(TEXTURA, TEXTURA)
    print("texturas:", [(im.name, tuple(im.size)) for im in bpy.data.images])

    # Solo la malla y su esqueleto: elfo_base trae una Icosphere suelta que, si se queda en la escena, acaba dentro del GLB.
    for o in list(bpy.data.objects):
        if o is not obj and o is not ao:
            print("se descarta de la escena: %s (%s)" % (o.name, o.type))
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    ao.select_set(True)
    bpy.context.view_layer.objects.active = ao
    bpy.ops.export_scene.gltf(filepath=salida, export_format="GLB", use_selection=True,
                              export_animations=False, export_skins=True, export_image_format="JPEG",
                              export_yup=True)
    print("ESCRITO: %s" % salida)


main()
