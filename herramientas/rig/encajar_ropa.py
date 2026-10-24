"""ENCAJA las prendas de `vestido.glb` (Tripo, sin esqueleto: capa corta con capucha + túnica sin mangas en UNA malla) sobre `jugadora_base.glb`.
Es el paso de Blender de PLAN_RIGGING §3 (pasos 2-3), para la ropa en piezas aparte de la jugadora base (arte/meshy/PROMPTS_JUGADORA_BASE.md §2).

    blender -b -P herramientas/rig/encajar_ropa.py -- <vestido.glb> <jugadora_base.glb> <carpeta_salida> [<config.json>]

Qué hace, por cada prenda (se separan por el hueco en X que deja Tripo entre la capa y la túnica):
  1. la reduce con Decimate (colapso) a ~`tris` triángulos, conservando UV y el cierre de las costuras;
  2. la escala y coloca sobre la base en A-pose (`config`: escala, desplazamiento y qué punto se alinea con qué punto de la base; o `perfil` por alturas, con
     escala X / Y delante / Y detrás y desplazamiento Y por nudo; `nivela_borde` baja la parte delantera para que el borde quede a una altura);
  3. la separa de la piel donde quedaba dentro de la base (empuja a `margen` por la normal, con el desplazamiento suavizado; las orejas no empujan;
     `normal_suave`, `profundidad_max` y `pasadas_piel` lo afinan para la capa);
  4. le pasa los pesos de la base: para cada vértice, el punto más cercano de la superficie de la base y los pesos de ese triángulo (baricéntrico),
     suavizados sobre la malla soldada (las costuras de UV no dejan huecos), con las piernas atenuadas en la túnica para que la falda no se parta en dos,
     máximo 4 influencias, normalizados (con `cabeza`, por debajo de una altura el peso de la cabeza pasa al torso);
  4b. si la prenda lleva `capucha` en la config (z del corte, `inclina`), la parte por esa altura en DOS prendas (`capa` abajo, `capucha` arriba); y con `brazo.borde`
     (gradiente con nombre de la orla trasera) quita peso de brazo y suaviza más los pesos de ese borde para que no se estire en dientes al levantar los brazos;
  5. escribe `<salida>/<prenda>.json` (geometría en el espacio de la malla de la base, Y arriba, tal cual la espera Godot) y las texturas.
La malla definitiva la monta Godot (`herramientas/montar_ropa_glb.gd`) sobre el esqueleto y el Skin de la base, para que sea EL MISMO esqueleto sin
pasar por una reexportación de Blender (que reorienta huesos). Blender 5.x, modo fondo.
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

# --- parámetros por omisión (se pisan con config.json) ---
CORTE_X: float = 0.068          # en el vestido de Tripo: capa a la izquierda (x < corte), túnica a la derecha
CONFIG: dict = {
    "capa": {"tris": 9000, "escala": 1.5, "punto": "cima", "destino": [0.003, -0.02, 1.72], "margen": 0.012},
    "tunica": {"tris": 9000, "escala": 1.05, "punto": "cima", "destino": [0.003, -0.07, 1.075], "margen": 0.008, "atenuar_piernas": True},
}
INFLUENCIAS: int = 4
SUAVIZADO_PESOS: int = 6        # pasadas de promedio con los vecinos
SUAVIZADO_EMPUJE: int = 8      # pasadas sobre el desplazamiento de «sacar de la piel»
OREJA_X: float = 0.27           # por fuera de esto y por encima de OREJA_Z, el punto de la base cuenta como oreja (no se empuja)
OREJA_Z: float = 1.30
PIERNAS: tuple = ("UpLeg", "Leg", "Foot", "ToeBase", "Toe_End")
HULL_Z_MIN: float = 1.08         # por encima de esto (cabeza y pelo) las prendas con `casco` se separan por radio y no por normal
FACTOR_MAX: float = 1.3         # tope del factor radial de la capucha (los vértices cerca del eje darían factores enormes)
FRENTE_LIBRE: float = 55.0      # grados a cada lado de la cara en los que la capucha no se ensancha
FRENTE_RAMPA: float = 100.0
HULL_ANGULOS: int = 48
HULL_PASO_Z: float = 0.03
BANDA_INFORME: float = 0.05     # alto de las bandas en que el informe (con ROPA_DEPURA) cuenta los vértices que quedan dentro


def importar(ruta: str) -> list:
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=ruta)
    return [o for o in bpy.data.objects if o not in antes]


def soldar_clave(p: Vector) -> tuple:
    return (round(p.x, 5), round(p.y, 5), round(p.z, 5))


def separar_prenda(o_vestido: bpy.types.Object, nombre: str, lado_derecho: bool) -> bpy.types.Object:
    """Copia del vestido con solo las caras de un lado del corte; sin vértices sueltos."""
    copia = o_vestido.copy()
    copia.data = o_vestido.data.copy()
    copia.name = nombre
    bpy.context.scene.collection.objects.link(copia)
    bm = bmesh.new()
    bm.from_mesh(copia.data)
    borrar = [f for f in bm.faces if (sum(v.co.x for v in f.verts) / len(f.verts) > CORTE_X) != lado_derecho]
    bmesh.ops.delete(bm, geom=borrar, context='FACES')
    sueltos = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=sueltos, context='VERTS')
    bm.to_mesh(copia.data)
    bm.free()
    return copia


def reducir(o: bpy.types.Object, tris_objetivo: int) -> None:
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    m = o.modifiers.new("reducir", 'DECIMATE')
    m.decimate_type = 'COLLAPSE'
    m.ratio = min(1.0, tris_objetivo / float(tris))
    m.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=m.name)


def puntos_mundo(o: bpy.types.Object) -> list:
    return [o.matrix_world @ v.co for v in o.data.vertices]


def interpolar(nudos: list, z: float, col: int) -> float:
    """Valor lineal a trozos de la columna `col` de `nudos` ([[z_propia, ...]...], z creciente) en `z` (se queda en los extremos fuera del rango)."""
    if z <= nudos[0][0]:
        return nudos[0][col]
    for a, b in zip(nudos, nudos[1:]):
        if z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return a[col] + (b[col] - a[col]) * t
    return nudos[-1][col]


def colocar_con_perfil(o: bpy.types.Object, cfg: dict) -> None:
    """Colocación por alturas: `perfil` = [[z de la prenda, z en el mundo, escala en X/Y]...]. La capucha de Tripo tiene proporciones de adulto y la cabeza de la
    jugadora es enorme: la parte de la capucha se estira más (en Z y en X/Y) que la de la capa sobre los hombros. El centro en X/Y de la prenda va a `destino`[0:2].
    La escala de un nudo puede ser un número (la misma en X y en Y), [escala X, escala Y] o [escala X, escala Y delante, escala Y detrás]: la capa tiene que
    ser ancha de lado (los brazos en A-pose), separarse del pecho por delante y no colgar lejos de la espalda. Un 4.º valor opcional desplaza en Y del mundo
    (Blender: +Y atrás) esa altura de la prenda (centrar la capa sobre el brazo, adelantar la cima de la capucha hacia la cabeza); si no lo lleva vale 0."""
    perfil = [nudo_perfil(n) for n in cfg["perfil"]]
    xs = [v.co.x for v in o.data.vertices]
    ys = [v.co.y for v in o.data.vertices]
    cx, cy = (min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5
    dx, dy = float(cfg["destino"][0]), float(cfg["destino"][1])
    for v in o.data.vertices:
        z = v.co.z
        sy = interpolar(perfil, z, 3 if v.co.y < cy else 4)
        v.co = Vector(((v.co.x - cx) * interpolar(perfil, z, 2) + dx, (v.co.y - cy) * sy + dy + interpolar(perfil, z, 5), interpolar(perfil, z, 1)))


def nivelar_borde(o: bpy.types.Object, cfg: dict) -> None:
    """Deja el borde de la capa a la altura `z` en todo el contorno. El borde de Tripo va inclinado (detrás 0,017, de lado 0,05, delante 0,09): sin esto la
    capelina acababa en el codo detrás y en el hombro delante, y el concept la quiere al codo en todo el contorno. Por `sectores` de ángulo alrededor del eje
    vertical de la parte baja se mide el punto más bajo y se baja lo que sobra, interpolando entre los centros de los sectores (el borde no hace escalones);
    entero en el borde y nada desde `z_hasta` (gradiente lineal entre medias)."""
    n = int(cfg["sectores"])
    z_obj, z1 = float(cfg["z"]), float(cfg["z_hasta"])
    bajos = [v.co for v in o.data.vertices if v.co.z < z1]
    cx = (min(p.x for p in bajos) + max(p.x for p in bajos)) * 0.5
    cy = (min(p.y for p in bajos) + max(p.y for p in bajos)) * 0.5

    def angulo(p: Vector) -> float:
        return (math.atan2(p.x - cx, p.y - cy) + math.pi) / (2.0 * math.pi) * n
    minimo = [z1] * n
    for p in bajos:
        s = int(angulo(p)) % n
        minimo[s] = min(minimo[s], p.z)
    for v in o.data.vertices:
        if v.co.z >= z1:
            continue
        a = angulo(v.co) - 0.5
        s0 = int(math.floor(a))
        f = a - s0
        borde = minimo[s0 % n] * (1.0 - f) + minimo[(s0 + 1) % n] * f
        sobra = max(0.0, borde - z_obj)
        t = (z1 - v.co.z) / max(z1 - borde, 1e-6)
        v.co.z -= sobra * max(0.0, min(1.0, t))


def nudo_perfil(n: list) -> list:
    """[z prenda, z mundo, escala | [X, Y] | [X, Y delante, Y detrás], (desplazamiento Y)] -> [z prenda, z mundo, X, Y delante, Y detrás, desplazamiento Y]."""
    esc = n[2] if isinstance(n[2], list) else [n[2], n[2]]
    if len(esc) == 2:
        esc = [esc[0], esc[1], esc[1]]
    return [float(n[0]), float(n[1]), float(esc[0]), float(esc[1]), float(esc[2]), float(n[3]) if len(n) > 3 else 0.0]


def colocar(o: bpy.types.Object, cfg: dict) -> None:
    if "perfil" in cfg:
        colocar_con_perfil(o, cfg)
        return
    """Escala sobre el origen y mueve: el centro de la caja de la prenda en X/Y y su cima en Z caen en `destino`."""
    esc = cfg["escala"]
    esc = Vector(esc) if isinstance(esc, list) else Vector((esc, esc, esc))
    pts = [Vector((v.co.x * esc.x, v.co.y * esc.y, v.co.z * esc.z)) for v in o.data.vertices]
    zmax = max(p.z for p in pts)
    cima = [p for p in pts if p.z > zmax - 0.01]
    ref = Vector((sum(p.x for p in cima) / len(cima), sum(p.y for p in cima) / len(cima), zmax))
    # X/Y: el centro de la caja de la prenda (no el de la cima) con el destino; la cima de la capucha va algo adelantada
    xs = [p.x for p in pts]
    ys = [p.y for p in pts]
    centro = Vector(((min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5, 0.0))
    dest = Vector(cfg["destino"])
    desp = Vector((dest.x - centro.x, dest.y - centro.y, dest.z - ref.z))
    for v in o.data.vertices:
        v.co = Vector((v.co.x * esc.x, v.co.y * esc.y, v.co.z * esc.z)) + desp


def arbol_base(base: bpy.types.Object) -> BVHTree:
    dg = bpy.context.evaluated_depsgraph_get()
    ev = base.evaluated_get(dg)
    me = ev.to_mesh()
    verts = [base.matrix_world @ v.co for v in me.vertices]
    me.calc_loop_triangles()
    tris = [tuple(t.vertices) for t in me.loop_triangles]
    return BVHTree.FromPolygons(verts, tris, all_triangles=True), verts, tris


class NormalSuave:
    """Normal de la base en un punto de su superficie interpolando las normales de los vértices del triángulo (baricéntricas). La normal de la cara que da
    `find_nearest` falla en las esquinas convexas (la punta del codo en A-pose): si el punto más cercano cae en una arista o un vértice, la cara elegida puede
    mirar hacia otro lado y un punto de la capa a 8 cm del codo salía «dentro» y se arrastraba hasta él. La interpolada mira hacia fuera también ahí.
    Se activa con `normal_suave` en la config de la prenda (la túnica sigue con la de la cara, como se hizo)."""

    def __init__(self, base: bpy.types.Object, verts: list, tris: list):
        dg = bpy.context.evaluated_depsgraph_get()
        me = base.evaluated_get(dg).to_mesh()
        me.calc_loop_triangles()
        rot = base.matrix_world.to_3x3().inverted().transposed()
        # Las normales de las esquinas (las del glTF, las mismas que usa Godot), por triángulo y en el orden de `arbol_base`.
        esquinas = me.corner_normals
        self.normales = [tuple((rot @ esquinas[lp].vector).normalized() for lp in t.loops) for t in me.loop_triangles]
        self.verts = verts
        self.tris = tris

    def en(self, loc: Vector, ti: int) -> Vector:
        a, b, c = self.tris[ti]
        ws = baricentricas(loc, self.verts[a], self.verts[b], self.verts[c])
        na, nb, nc = self.normales[ti]
        n = na * ws[0] + nb * ws[1] + nc * ws[2]
        return n.normalized() if n.length > 1e-9 else na


def baricentricas(p: Vector, pa: Vector, pb: Vector, pc: Vector) -> tuple:
    v0, v1, v2 = pb - pa, pc - pa, p - pa
    d00, d01, d11, d20, d21 = v0.dot(v0), v0.dot(v1), v1.dot(v1), v2.dot(v0), v2.dot(v1)
    den = d00 * d11 - d01 * d01
    if abs(den) < 1e-14:
        return (1.0, 0.0, 0.0)
    y = (d11 * d20 - d01 * d21) / den
    z = (d00 * d21 - d01 * d20) / den
    return (1.0 - y - z, y, z)


def adyacencia_soldada(o: bpy.types.Object) -> tuple:
    """Vecinos por posición: los vértices duplicados por las costuras de UV cuentan como uno (`grupo[i]` = id soldado)."""
    grupo = {}
    ids = []
    for v in o.data.vertices:
        k = soldar_clave(v.co)
        if k not in grupo:
            grupo[k] = len(grupo)
        ids.append(grupo[k])
    vecinos = [set() for _ in range(len(grupo))]
    for e in o.data.edges:
        a, b = ids[e.vertices[0]], ids[e.vertices[1]]
        if a != b:
            vecinos[a].add(b)
            vecinos[b].add(a)
    return ids, vecinos


class CascoCabeza:
    """Radio máximo de la cabeza (pelo incluido, sin las orejas) por ángulo y altura: el pelo son tiras abiertas y dobles, y el signo de la normal no vale para
    saber si un punto está dentro; el radio sí. El eje es el centro del pelo."""

    def __init__(self, verts: list):
        pts = [p for p in verts if p.z > HULL_Z_MIN and not (abs(p.x) > OREJA_X and p.z > OREJA_Z)]
        self.cx = sum(p.x for p in pts) / len(pts)
        self.cy = sum(p.y for p in pts) / len(pts)
        self.tabla = {}
        for p in pts:
            r = math.hypot(p.x - self.cx, p.y - self.cy)
            a = int(((math.atan2(p.y - self.cy, p.x - self.cx) + math.pi) / (2 * math.pi)) * HULL_ANGULOS) % HULL_ANGULOS
            z = int((p.z - HULL_Z_MIN) / HULL_PASO_Z)
            k = (a, z)
            if r > self.tabla.get(k, 0.0):
                self.tabla[k] = r

    def casilla(self, dx: float, dy: float, z: float) -> tuple:
        a = int(((math.atan2(dy, dx) + math.pi) / (2 * math.pi)) * HULL_ANGULOS) % HULL_ANGULOS
        return (a, int((z - HULL_Z_MIN) / HULL_PASO_Z))

    def radio(self, x: float, y: float, z: float) -> float:
        a0 = int(((math.atan2(y - self.cy, x - self.cx) + math.pi) / (2 * math.pi)) * HULL_ANGULOS) % HULL_ANGULOS
        z0 = int((z - HULL_Z_MIN) / HULL_PASO_Z)
        m = 0.0
        for da in (-3, -2, -1, 0, 1, 2, 3):
            for dz in (-2, -1, 0, 1, 2):
                m = max(m, self.tabla.get(((a0 + da) % HULL_ANGULOS, z0 + dz), 0.0))
        return m


class CampoFactor:
    """Factor radial (>= 1) que hay que dar a cada zona de la capucha para que su parte más metida (el forro) quede `margen` fuera del casco de la cabeza.
    Se calcula por casilla (ángulo, altura) como el máximo de need/r de los vértices que caen en ella, se extiende a las vecinas y se suaviza."""

    def __init__(self, o: bpy.types.Object, casco: CascoCabeza, margen: float):
        self.casco = casco
        bruto = {}
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            if p.z <= HULL_Z_MIN:
                continue
            r = math.hypot(p.x - casco.cx, p.y - casco.cy)
            if r < 1e-6:
                continue
            radio = casco.radio(p.x, p.y, p.z)
            if radio <= 0.0 or CampoFactor.peso_lateral(p.x - casco.cx, p.y - casco.cy) < 0.5:
                continue
            k = min((radio + margen) / r, FACTOR_MAX)
            c = casco.casilla(p.x - casco.cx, p.y - casco.cy, p.z)
            if k > bruto.get(c, 1.0):
                bruto[c] = k
        z_max = int((max((o.matrix_world @ v.co).z for v in o.data.vertices) - HULL_Z_MIN) / HULL_PASO_Z) + 2
        self.tabla = {}
        for a in range(HULL_ANGULOS):
            for z in range(-1, z_max):
                m = 1.0
                for da in range(-2, 3):
                    for dz in range(-1, 2):
                        m = max(m, bruto.get(((a + da) % HULL_ANGULOS, z + dz), 1.0))
                self.tabla[(a, z)] = m
        for _ in range(3):   # suavizado en ángulo y altura
            nueva = {}
            for (a, z), k in self.tabla.items():
                vec = [self.tabla.get(((a + da) % HULL_ANGULOS, z + dz), k) for da in (-1, 0, 1) for dz in (-1, 0, 1)]
                nueva[(a, z)] = max(k * 0.5 + 0.5 * sum(vec) / len(vec), 1.0)
            self.tabla = nueva

    @staticmethod
    def peso_lateral(dx: float, dy: float) -> float:
        """0 delante (la abertura de la capucha, que enmarca la cara y no se ensancha), 1 de lado y detrás; con una rampa entre FRENTE_LIBRE y FRENTE_RAMPA grados."""
        ang = abs(math.degrees(math.atan2(dx, -dy)))   # 0 = justo delante (-Y)
        t = (ang - FRENTE_LIBRE) / (FRENTE_RAMPA - FRENTE_LIBRE)
        t = max(0.0, min(1.0, t))
        return t * t * (3.0 - 2.0 * t)

    def factor(self, x: float, y: float, z: float) -> float:
        k = self.tabla.get(self.casco.casilla(x, y, z), 1.0)
        return 1.0 + (k - 1.0) * self.peso_lateral(x, y)


def sacar_de_la_piel(o: bpy.types.Object, arbol: BVHTree, margen: float, ids: list, vecinos: list, casco: CascoCabeza = None,
                    margen_casco: float = 0.0, suave: NormalSuave = None, profundidad_max: float = math.inf,
                    suavizado: int = SUAVIZADO_EMPUJE) -> int:
    """Empuja fuera de la base los vértices que quedan dentro o a menos de `margen` (por la normal del punto más cercano). Solo cuenta como dentro un punto a
    menos de `profundidad_max` de la superficie (por debajo de la cabeza, HULL_Z_MIN; arriba manda el casco): más lejos, el signo de la normal de un pliegue (la
    raja de las nalgas, la punta del codo) no dice nada y un vértice de la orla a 15 cm se arrastraba hasta allí. `suavizado`: pasadas sobre el desplazamiento."""
    campo = CampoFactor(o, casco, margen_casco) if casco is not None else None
    desp = {}
    for v in o.data.vertices:
        g = ids[v.index]
        if g in desp:
            continue
        p = o.matrix_world @ v.co
        loc, nor, ti, dist = arbol.find_nearest(p)
        if suave is not None and loc is not None:
            nor = suave.en(loc, ti)
        d_piel = Vector()
        if loc is not None and not (abs(loc.x) > OREJA_X and loc.z > OREJA_Z) and (p - loc).dot(nor) < margen \
                and (dist <= profundidad_max or p.z > HULL_Z_MIN):
            d_piel = loc + nor * margen - p
        if casco is not None and p.z > HULL_Z_MIN:
            # Un único factor radial por (ángulo, altura), el mismo para el forro y la capa de fuera: conserva el grosor y la forma de la capucha.
            # Delante (la abertura de la cara) manda la normal de la piel, de lado y detrás el casco del pelo.
            k = campo.factor(p.x - casco.cx, p.y - casco.cy, p.z)
            d_casco = Vector(((p.x - casco.cx) * (k - 1.0), (p.y - casco.cy) * (k - 1.0), 0.0))
            w = CampoFactor.peso_lateral(p.x - casco.cx, p.y - casco.cy)
            desp[g] = d_casco * w + d_piel * (1.0 - w)
            continue
        desp[g] = d_piel
    for _ in range(suavizado):
        nuevo = {}
        for g, d in desp.items():
            if vecinos[g]:
                media = sum((desp[h] for h in vecinos[g]), Vector()) / len(vecinos[g])
                nuevo[g] = d if d.length > media.length else d * 0.5 + media * 0.5
            else:
                nuevo[g] = d
        desp = nuevo
    movidos = 0
    for v in o.data.vertices:
        d = desp[ids[v.index]]
        if d.length > 1e-5:
            v.co = v.co + d
            movidos += 1
    return movidos


def suave(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def pesos_brazo(p: Vector, cfg: dict) -> float:
    """Cuánto del peso de un vértice de la capa se pasa al brazo de su lado (0..`peso`): sube con la distancia lateral al eje (`x0`..`x1`, el hombro y lo que cuelga
    de él) y baja a cero con la altura (a partir de `z_baja0` hasta `z_baja1`: la capucha y el cuello siguen a la cabeza y al torso)."""
    lat = abs(p.x - float(cfg.get("eje_x", 0.003)))
    t_lat = suave((lat - float(cfg["x0"])) / (float(cfg["x1"]) - float(cfg["x0"])))
    t_alto = 1.0 - suave((p.z - float(cfg["z_baja0"])) / (float(cfg["z_baja1"]) - float(cfg["z_baja0"])))
    return float(cfg["peso"]) * t_lat * t_alto


def pesos_desde_base(o: bpy.types.Object, base: bpy.types.Object, arbol: BVHTree, verts_b: list, tris_b: list, ids: list, vecinos: list,
                     atenuar_piernas: bool, brazo: dict = None, cabeza: dict = None) -> list:
    """Pesos por vértice de la prenda: [{hueso: peso}] (ya suavizados, recortados a 4 y normalizados)."""
    nombres = {g.index: g.name for g in base.vertex_groups}
    pesos_b = [{nombres[g.group]: g.weight for g in v.groups} for v in base.data.vertices]
    por_grupo = {}
    for v in o.data.vertices:
        gid = ids[v.index]
        if gid in por_grupo:
            continue
        p = o.matrix_world @ v.co
        loc, nor, ti, dist = arbol.find_nearest(p)
        a, b, c = tris_b[ti]
        ws = baricentricas(loc, verts_b[a], verts_b[b], verts_b[c])   # del punto más cercano
        acum = {}
        for w, i in zip(ws, (a, b, c)):
            for hueso, pv in pesos_b[i].items():
                acum[hueso] = acum.get(hueso, 0.0) + w * pv
        por_grupo[gid] = acum
    for _ in range(SUAVIZADO_PESOS):
        nuevo = {}
        for g, d in por_grupo.items():
            if not vecinos[g]:
                nuevo[g] = d
                continue
            suma = dict(d)
            for h in vecinos[g]:
                for hueso, pv in por_grupo[h].items():
                    suma[hueso] = suma.get(hueso, 0.0) + pv
            tot = len(vecinos[g]) + 1.0
            mezcla = {k: 0.5 * d.get(k, 0.0) + 0.5 * suma.get(k, 0.0) / tot for k in set(d) | set(suma)}
            nuevo[g] = mezcla
        por_grupo = nuevo
    res = []
    for v in o.data.vertices:
        d = dict(por_grupo[ids[v.index]])
        if cabeza is not None:
            # Bajo la cabeza enorme de la jugadora lo más cercano a los hombros de la capa es el pelo: sin esto la capa se llevaba peso de Head hasta el borde y
            # giraba con la cabeza. Por debajo de `z0` ese peso pasa a `a` (el torso), con gradiente hasta `z1` (el cuello de la capa sigue a la cabeza).
            quita = 1.0 - suave(((o.matrix_world @ v.co).z - float(cabeza["z0"])) / (float(cabeza["z1"]) - float(cabeza["z0"])))
            movido = 0.0
            for hueso in cabeza["huesos"]:
                if hueso in d:
                    movido += d[hueso] * quita
                    d[hueso] *= 1.0 - quita
            if movido > 0.0:
                d[cabeza["a"]] = d.get(cabeza["a"], 0.0) + movido
        if brazo is not None:
            # La capa acompaña al brazo al levantarlo (no hace falta un movimiento realista): parte del peso pasa al brazo (y algo a la clavícula) de su lado, con
            # gradiente; el resto se reparte como estaba. En reposo no se nota (todos los huesos están en su pose de enlace).
            pv = o.matrix_world @ v.co
            w_b = pesos_brazo(pv, brazo)
            if "borde" in brazo:
                # La orla trasera de la capa lleva menos brazo (gradiente con nombre): al levantarlo no se estira en dientes.
                w_b *= 1.0 - float(brazo["borde"]["quita_brazo"]) * gradiente_borde_trasero(pv, brazo["borde"])
            if w_b > 1e-4:
                lado = "Left" if pv.x > float(brazo.get("eje_x", 0.003)) else "Right"
                d = {k: x * (1.0 - w_b) for k, x in d.items()}
                d["mixamorig_%sArm" % lado] = d.get("mixamorig_%sArm" % lado, 0.0) + w_b * (1.0 - float(brazo["parte_clavicula"]))
                d["mixamorig_%sShoulder" % lado] = d.get("mixamorig_%sShoulder" % lado, 0.0) + w_b * float(brazo["parte_clavicula"])
        if atenuar_piernas:
            # La falda de la túnica no debe partirse con cada pierna: las piernas pesan menos cuanto más abajo de la cadera (el resto se lo lleva Hips).
            z = (o.matrix_world @ v.co).z
            k = max(0.0, min(1.0, (0.80 - z) / 0.25))   # 0 hasta z=0.80 (la ingle), 1 a z=0.55
            atenua = 0.55 * (1.0 - k) + 0.25 * k
            quitado = 0.0
            for hueso in list(d.keys()):
                if hueso.split("mixamorig_")[-1].replace("Left", "").replace("Right", "") in PIERNAS:
                    quitado += d[hueso] * (1.0 - atenua)
                    d[hueso] *= atenua
            d["mixamorig_Hips"] = d.get("mixamorig_Hips", 0.0) + quitado
        top = sorted(d.items(), key=lambda kv: -kv[1])[:INFLUENCIAS]
        tot = sum(w for _, w in top)
        if tot < 1e-9:
            top = [("mixamorig_Hips", 1.0)]
            tot = 1.0
        res.append([(h, w / tot) for h, w in top])
    return res


def gradiente_borde_trasero(p: Vector, cfg: dict) -> float:
    """0..1: cuánto es un punto de la capa borde inferior TRASERO (la orla de la espalda): 1 en el borde bajo y por detrás, 0 por encima de `z1` y hacia delante
    (a partir de `y0` hacia atrás sube hasta `y1`). Con él se quita peso de brazo y se suavizan más los pesos para que la orla no se estire en dientes."""
    t_bajo = 1.0 - suave((p.z - float(cfg["z0"])) / (float(cfg["z1"]) - float(cfg["z0"])))
    t_atras = suave((p.y - float(cfg["y0"])) / (float(cfg["y1"]) - float(cfg["y0"])))
    return t_bajo * t_atras


def suavizar_borde_trasero(o: bpy.types.Object, pesos: list, ids: list, vecinos: list, cfg: dict) -> int:
    """Pasadas extra de promedio de pesos con los vecinos soldados, mezcladas con el gradiente del borde trasero (fuera de él no tocan nada). Devuelve los pesos
    nuevos y cuántos vértices tienen gradiente > 0."""
    g_de = {}
    for v in o.data.vertices:
        g_de.setdefault(ids[v.index], v.index)
    grad = {g: gradiente_borde_trasero(o.matrix_world @ o.data.vertices[i].co, cfg) for g, i in g_de.items()}
    por_grupo = {g: dict(pesos[i]) for g, i in g_de.items()}
    for _ in range(int(cfg["pasadas"])):
        nuevo = {}
        for g, d in por_grupo.items():
            t = grad[g]
            if t < 1e-4 or not vecinos[g]:
                nuevo[g] = d
                continue
            suma = dict(d)
            for h in vecinos[g]:
                for hueso, pv in por_grupo[h].items():
                    suma[hueso] = suma.get(hueso, 0.0) + pv
            tot = len(vecinos[g]) + 1.0
            nuevo[g] = {k: (1.0 - t) * d.get(k, 0.0) + t * suma.get(k, 0.0) / tot for k in set(d) | set(suma)}
        por_grupo = nuevo
    res = []
    for v in o.data.vertices:
        d = por_grupo[ids[v.index]]
        top = sorted(d.items(), key=lambda kv: -kv[1])[:INFLUENCIAS]
        tot = sum(w for _, w in top) or 1.0
        res.append([(h, w / tot) for h, w in top])
    return res, sum(1 for t in grad.values() if t > 1e-4)


def altura_corte(p: Vector, cfg: dict) -> float:
    """Altura (mundo) del corte entre la capa y la capucha en el punto `p`: `z` en el eje y `inclina` más por cada unidad que se avanza hacia delante (-Y)."""
    return float(cfg["z"]) - float(cfg.get("inclina", 0.0)) * p.y


def exportar(o: bpy.types.Object, pesos: list, base: bpy.types.Object, carpeta: str, nombre: str, filtro=None) -> dict:
    """Vértices únicos por (vértice, UV, normal); posiciones en el espacio de la malla de la base (Blender Z arriba -> glTF Y arriba). `filtro(triángulo)` deja
    elegir qué triángulos se escriben (para partir una prenda en dos)."""
    me = o.data
    me.calc_loop_triangles()
    inv = base.matrix_world.inverted()
    uv_l = me.uv_layers.active.data
    normales = me.corner_normals
    claves = {}
    pos, nor, uvs, joints, weights, idx = [], [], [], [], [], []
    huesos = []
    for t in me.loop_triangles:
        if filtro is not None and not filtro(t):
            continue
        for lp in t.loops:
            vi = me.loops[lp].vertex_index
            n = normales[lp].vector
            uv = uv_l[lp].uv
            k = (vi, round(uv.x, 5), round(uv.y, 5), round(n.x, 3), round(n.y, 3), round(n.z, 3))
            if k not in claves:
                claves[k] = len(pos)
                p = inv @ (o.matrix_world @ me.vertices[vi].co)
                nn = (base.matrix_world.to_3x3().inverted().transposed() @ (o.matrix_world.to_3x3() @ n)).normalized()
                pos.append([p.x, p.z, -p.y])
                nor.append([nn.x, nn.z, -nn.y])
                uvs.append([uv.x, 1.0 - uv.y])
                js, ws = [], []
                for h, w in pesos[vi]:
                    if h not in huesos:
                        huesos.append(h)
                    js.append(huesos.index(h))
                    ws.append(w)
                while len(js) < INFLUENCIAS:
                    js.append(0)
                    ws.append(0.0)
                joints.append(js)
                weights.append(ws)
            idx.append(claves[k])
    # el giro de ejes (x, z, -y) es una rotación propia: el orden de las caras se conserva
    datos = {"nombre": nombre, "huesos": huesos, "pos": pos, "nor": nor, "uv": uvs, "joints": joints, "weights": weights, "idx": idx}
    with open(os.path.join(carpeta, nombre + ".json"), "w") as f:
        json.dump(datos, f)
    return datos


def guardar_texturas(o: bpy.types.Object, carpeta: str) -> None:
    for m in o.data.materials:
        for n in m.node_tree.nodes:
            if n.type == 'TEX_IMAGE' and n.image is not None:
                nombre = "basecolor" if "basecolor" in n.image.name else ("normal" if "normal" in n.image.name else "rm")
                n.image.filepath_raw = os.path.join(carpeta, "ropa_" + nombre + ".png")
                n.image.file_format = 'PNG'
                n.image.save()


def perfil_cabeza(o: bpy.types.Object, verts_b: list) -> None:
    """Depuración: extensión en X/Y del pelo (sin orejas) y de la prenda por bandas de altura."""
    for z0 in [1.2 + 0.05 * i for i in range(11)]:
        def caja(pts):
            if not pts:
                return None
            return tuple(round(v, 3) for v in (min(p.x for p in pts), max(p.x for p in pts), min(p.y for p in pts), max(p.y for p in pts)))
        pelo = [p for p in verts_b if z0 <= p.z < z0 + 0.05 and not (abs(p.x) > OREJA_X and p.z > OREJA_Z)]
        pr = [o.matrix_world @ v.co for v in o.data.vertices]
        pr = [p for p in pr if z0 <= p.z < z0 + 0.05]
        print("PERFIL z=%.2f pelo x[%s] y[%s] | prenda x[%s] y[%s]" % (z0, *(("%.3f %.3f" % c[:2], "%.3f %.3f" % c[2:]) if (c := caja(pelo)) else ("-", "-")),
              *(("%.3f %.3f" % c[:2], "%.3f %.3f" % c[2:]) if (c := caja(pr)) else ("-", "-"))))


def informe(o: bpy.types.Object, arbol: BVHTree, nombre: str, suave: NormalSuave = None, profundidad_max: float = math.inf) -> None:
    """Cuántos vértices quedan dentro de la base (distancia con signo < 0, con el mismo criterio que sacar_de_la_piel) y la mínima distancia (con ROPA_DEPURA,
    también por bandas de altura)."""
    dentro, total, peor = 0, 0, 1e9
    por_altura = {}
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        loc, nor, ti, dist = arbol.find_nearest(p)
        if abs(loc.x) > OREJA_X and loc.z > OREJA_Z:
            continue
        if suave is not None:
            nor = suave.en(loc, ti)
        s = (p - loc).dot(nor) if dist <= profundidad_max or p.z > HULL_Z_MIN else dist
        total += 1
        peor = min(peor, s)
        if s < 0.0:
            dentro += 1
            banda = round(math.floor(p.z / BANDA_INFORME) * BANDA_INFORME, 2)
            por_altura[banda] = por_altura.get(banda, 0) + 1
    if os.environ.get("ROPA_DEPURA"):
        print("DENTRO %s por altura (bandas de %.2f): %s" % (nombre, BANDA_INFORME, sorted(por_altura.items())))
    ws = puntos_mundo(o)
    print("INFORME %s: tris=%d vértices=%d dentro_de_la_base=%d/%d distancia_mínima_con_signo=%.4f caja_min=%s caja_max=%s" % (
        nombre, sum(len(p.vertices) - 2 for p in o.data.polygons), len(o.data.vertices), dentro, total, peor,
        tuple(round(min(w[i] for w in ws), 3) for i in range(3)), tuple(round(max(w[i] for w in ws), 3) for i in range(3))))


def main() -> None:
    a = sys.argv[sys.argv.index("--") + 1:]
    ruta_vestido, ruta_base, carpeta = a[0], a[1], a[2]
    cfg = json.loads(json.dumps(CONFIG))
    if len(a) > 3:
        with open(a[3]) as f:
            for k, v in json.load(f).items():
                cfg.setdefault(k, {}).update(v)
    os.makedirs(carpeta, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs_v = importar(ruta_vestido)
    objs_b = importar(ruta_base)
    # El importador de glTF añade una «Icosphere» (la forma con que dibuja los huesos): la malla buena es la de más vértices.
    base = max((o for o in objs_b if o.type == 'MESH'), key=lambda o: len(o.data.vertices))
    vestido = max((o for o in objs_v if o.type == 'MESH'), key=lambda o: len(o.data.vertices))
    for o in objs_v + objs_b:
        if o.type == 'MESH' and o is not vestido and o is not base:
            bpy.data.objects.remove(o)
    arbol, verts_b, tris_b = arbol_base(base)
    for nombre, derecha in (("capa", False), ("tunica", True)):
        c = cfg[nombre]
        o = separar_prenda(vestido, nombre, derecha)
        reducir(o, int(c["tris"]))
        colocar(o, c)
        if "nivela_borde" in c:
            nivelar_borde(o, c["nivela_borde"])
        ids, vecinos = adyacencia_soldada(o)
        # El casco se mide solo con los vértices de la cabeza y el pelo (peso de Head): por encima de HULL_Z_MIN también están los hombros y los brazos.
        g_cabeza = base.vertex_groups["mixamorig_Head"].index
        verts_cabeza = [verts_b[v.index] for v in base.data.vertices if any(g.group == g_cabeza and g.weight > 0.5 for g in v.groups)]
        casco = CascoCabeza(verts_cabeza) if "margen_casco" in c else None
        suave = NormalSuave(base, verts_b, tris_b) if c.get("normal_suave", False) else None
        profundidad = float(c.get("profundidad_max", math.inf))
        movidos = sacar_de_la_piel(o, arbol, float(c["margen"]), ids, vecinos, casco, float(c.get("margen_casco", 0.0)), suave, profundidad)
        # Con `pasadas_piel` > 1 se repasa solo la piel (sin el casco, que volvería a ensanchar la capucha): el suavizado del desplazamiento mezcla direcciones y
        # deja vértices a pocos milímetros bajo la piel (el cuello de la capa, que abraza el de la jugadora). La última pasada va sin suavizar (cada vértice por
        # su normal). Con 8 pasadas, los vértices dentro de la base bajan de 607 a 25 (informe).
        extra = int(c.get("pasadas_piel", 1)) - 1
        for i in range(extra):
            sacar_de_la_piel(o, arbol, float(c["margen"]), ids, vecinos, None, 0.0, suave, profundidad, 0 if i == extra - 1 else SUAVIZADO_EMPUJE)
        print("PRENDA %s: %d vértices empujados fuera de la piel" % (nombre, movidos))
        informe(o, arbol, nombre, suave, profundidad)
        if nombre == "capa" and os.environ.get("ROPA_DEPURA"):
            perfil_cabeza(o, verts_b)
        pesos = pesos_desde_base(o, base, arbol, verts_b, tris_b, ids, vecinos, bool(c.get("atenuar_piernas", False)), c.get("brazo"),
                                 c.get("cabeza"))
        borde = (c.get("brazo") or {}).get("borde")
        if borde is not None:
            pesos, con_gradiente = suavizar_borde_trasero(o, pesos, ids, vecinos, borde)
            print("BORDE %s: %d vértices con gradiente de orla trasera" % (nombre, con_gradiente))
        corte = c.get("capucha")
        if corte is None:
            d = exportar(o, pesos, base, carpeta, nombre)
            print("EXPORTADA %s: %d vértices, %d triángulos, %d huesos" % (nombre, len(d["pos"]), len(d["idx"]) // 3, len(d["huesos"])))
        else:
            # Se parte en dos prendas por una altura (algo inclinada): lo de arriba es la capucha y lo de abajo la capa. Cada triángulo, por su centro.
            def es_capucha(t) -> bool:
                cen = sum((o.matrix_world @ o.data.vertices[i].co for i in t.vertices), Vector()) / 3.0
                return cen.z > altura_corte(cen, corte)
            for parte, filtro in (("capa", lambda t: not es_capucha(t)), (corte.get("nombre", "capucha"), es_capucha)):
                d = exportar(o, pesos, base, carpeta, parte, filtro)
                print("EXPORTADA %s: %d vértices, %d triángulos, %d huesos" % (parte, len(d["pos"]), len(d["idx"]) // 3, len(d["huesos"])))
        guardar_texturas(o, carpeta)


main()
