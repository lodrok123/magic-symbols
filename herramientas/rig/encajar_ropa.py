"""ENCAJA las prendas de `vestido.glb` (Tripo, sin esqueleto: capa corta con capucha + túnica sin mangas en UNA malla) sobre `jugadora_base.glb`.
Es el paso de Blender de PLAN_RIGGING §3 (pasos 2-3), para la ropa en piezas aparte de la jugadora base (arte/meshy/PROMPTS_JUGADORA_BASE.md §2).

    blender -b -P herramientas/rig/encajar_ropa.py -- <vestido.glb> <jugadora_base.glb> <carpeta_salida> [<config.json> [<solo esta prenda>]]

Qué hace, por cada prenda (se separan por el hueco en X que deja Tripo entre la capa y la túnica):
  1. la reduce con Decimate (colapso) a ~`tris` triángulos, conservando UV y el cierre de las costuras;
  2. la escala y coloca sobre la base en A-pose (`config`: escala, desplazamiento y qué punto se alinea con qué punto de la base; o `perfil` por alturas, con
     escala X / Y delante / Y detrás y desplazamiento Y por nudo; `nivela_borde` baja la parte delantera para que el borde quede a una altura);
  3. la separa de la piel donde quedaba dentro de la base (empuja a `margen` por la normal, con el desplazamiento suavizado; las orejas no empujan;
     `normal_suave`, `profundidad_max` y `pasadas_piel` lo afinan para la capa; `sobre` mete en la piel las prendas ya encajadas de debajo; `margen_zonas`
     da más holgura en cajas; `celdas` reparte el empuje radial por celdas cilíndricas entre capas a radio parecido, para que faldón, panel y cinturón
     salgan juntos; `quitar_forro` quita la pared interior, con `por_rayo` y `tapadas` para las caras giradas y las tapadas por otra capa);
  4. le pasa los pesos de la base: para cada vértice, el punto más cercano de la superficie de la base y los pesos de ese triángulo (baricéntrico),
     suavizados sobre la malla soldada (las costuras de UV no dejan huecos), con las piernas atenuadas en la túnica para que la falda no se parta en dos,
     máximo 4 influencias, normalizados (con `cabeza`, por debajo de una altura el peso de la cabeza pasa al torso);
  4b. si la prenda lleva `capucha` en la config (z del corte, `inclina`), la parte por esa altura en DOS prendas (`capa` abajo, `capucha` arriba; con `banda`, por
     un plano y con la capa metida esa franja bajo la capucha: `partir_con_solape`); y con `brazo.borde`
     (gradiente con nombre de la orla trasera) quita peso de brazo y suaviza más los pesos de ese borde para que no se estire en dientes al levantar los brazos;
  5. escribe `<salida>/<prenda>.json` (geometría en el espacio de la malla de la base, Y arriba, tal cual la espera Godot) y las texturas.
La malla definitiva la monta Godot (`herramientas/montar_ropa_glb.gd`) sobre el esqueleto y el Skin de la base, para que sea EL MISMO esqueleto sin
pasar por una reexportación de Blender (que reorienta huesos). Blender 5.x, modo fondo.

11/11 (uniforme de Sumicio, arte/meshy/PROMPTS_UNIFORME_MID.md): el .glb puede traer UNA prenda entera (Meshy: la capa con capucha en un archivo, las piernas en
otro). En la config, `_prendas` dice qué prendas se procesan (por omisión `capa` y `tunica`) y cada prenda `parte`: "izquierda" / "derecha" (el corte en X del
vestido de Tripo) o "todo" (la malla entera). La capucha con PUNTA CAÍDA (`capucha.punta`): lo que cuelga por debajo del corte sin estar unido a la capa se va con
la capucha y pesa entero en Head (`separar_punta`). La textura de color se reconoce por el enchufe al que va (Meshy no la llama «basecolor»).
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


def separar_prenda(o_vestido: bpy.types.Object, nombre: str, parte: str) -> bpy.types.Object:
    """Copia del vestido con solo las caras de un lado del corte ("izquierda" / "derecha"; "todo" = la malla entera); sin vértices sueltos."""
    copia = o_vestido.copy()
    copia.data = o_vestido.data.copy()
    copia.name = nombre
    bpy.context.scene.collection.objects.link(copia)
    if parte == "todo":
        return copia
    lado_derecho = parte == "derecha"
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
    # (12/11: `delimit` solo vale para el modo PLANAR; el colapso ya interpola las UV por esquina. Las motas negras y blancas de las prendas de Meshy venían del
    # filtrado en los bordes de sus islas diminutas sobre fondo negro: ver `rellenar_fondo`.)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=m.name)


def quitar_forro(o: bpy.types.Object, cfg: dict, ids: list, excluir: set) -> int:
    """Quita la PARED INTERIOR de la capa (11/11: la capa de Meshy es de doble pared, con la de dentro a los mismos radios que la de fuera). Con la cámara del
    juego a 60° nunca se ve, cuesta la mitad de los triángulos y era lo que los antebrazos atravesaban al balancearse (queda entre el brazo y el torso). Por debajo
    de `z_max` (mundo), las caras cuya normal mira hacia el eje vertical de la prenda (producto con la dirección radial < `radial`); la punta caída (`excluir`) no
    se toca. El forro de la capucha se ve por la abertura y se queda. Devuelve cuántas caras quita."""
    z_max, umbral = float(cfg["z_max"]), float(cfg.get("radial", -0.3))
    bajos = [o.matrix_world @ v.co for v in o.data.vertices if (o.matrix_world @ v.co).z < z_max]
    cx = (min(p.x for p in bajos) + max(p.x for p in bajos)) * 0.5
    cy = (min(p.y for p in bajos) + max(p.y for p in bajos)) * 0.5
    # `ejes_x` (12/11, mallas): un eje por pierna (x de cada uno); cada cara mira al más cercano. Con un solo eje, la cara de fuera del muslo interior «miraba
    # al eje» (al otro muslo) y se borraba.
    ejes_x = [float(e) for e in cfg.get("ejes_x", [])]
    rot = o.matrix_world.to_3x3()
    bm = bmesh.new()
    bm.from_mesh(o.data)
    # 12/11: la normal sola no basta: Meshy trae algunas caras EXTERIORES con la normal girada (bajo el cinturón de la túnica, la boca de los zapatos) y se
    # borraban (agujeros). Ahora una cara es interior solo si, además, un rayo desde su centro hacia fuera (dirección radial) choca con otra cara de la
    # misma prenda a menos de `grosor` (la pared de fuera). Una cara exterior con la normal al revés no tiene nada delante y se queda.
    grosor = float(cfg.get("grosor", 0.03))
    arbol_propio = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
    inv = o.matrix_world.inverted()
    borrar = []
    for f in bm.faces:
        if any(ids[v.index] in excluir for v in f.verts):
            continue
        c = o.matrix_world @ f.calc_center_median()
        if c.z >= z_max or c.z < float(cfg.get("z_min", -math.inf)):
            continue
        # `ejes_x_z_max`: por encima de esa altura (la cadera, donde las dos piernas son un tubo) vuelve a mandar el eje único.
        ex = min(ejes_x, key=lambda e: abs(c.x - e)) if ejes_x and c.z < float(cfg.get("ejes_x_z_max", math.inf)) else cx
        dx, dy = c.x - ex, c.y - cy
        l = math.hypot(dx, dy)
        if l < 1e-6:
            continue
        n = (rot @ f.normal).normalized()
        if (n.x * dx + n.y * dy) / l >= umbral:
            # `tapadas` (12/11, mallas): una cara que mira hacia fuera pero tiene OTRA cara de la prenda a menos de `tapadas` por delante (por su normal) está
            # debajo de una capa (la pared de la malla bajo el puño blanco del tobillo y bajo el zapato) y pelea con ella en motas: fuera.
            tapadas = float(cfg.get("tapadas", 0.0))
            if tapadas > 0.0:
                origen = inv @ (c + n * 0.002)
                loc, _nor, _idx, dist = arbol_propio.ray_cast(origen, inv.to_3x3() @ n, tapadas / o.matrix_world.to_scale().x)
                if loc is not None:
                    borrar.append(f)
            continue
        if not bool(cfg.get("por_rayo", False)):
            borrar.append(f)           # solo por la normal (la túnica: con el rayo, el faldón azul perdía caras bajo el panel rojo)
            continue
        radial = Vector((dx / l, dy / l, 0.0))
        origen = inv @ (c + radial * 0.002)
        loc, _nor, _idx, dist = arbol_propio.ray_cast(origen, inv.to_3x3() @ radial, grosor / o.matrix_world.to_scale().x)
        if loc is not None:
            borrar.append(f)
    if os.environ.get("ROPA_DEPURA"):
        bandas = {}
        for f in borrar:
            b = round(math.floor((o.matrix_world @ f.calc_center_median()).z / BANDA_INFORME) * BANDA_INFORME, 2)
            bandas[b] = bandas.get(b, 0) + 1
        print("FORRO por altura (bandas de %.2f): %s" % (BANDA_INFORME, sorted(bandas.items())))
    bmesh.ops.delete(bm, geom=borrar, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(o.data)
    bm.free()
    return len(borrar)


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


def nivelar_borde(o: bpy.types.Object, cfg: dict, ids: list = None, excluir: set = None) -> None:
    """Deja el borde de la capa a la altura `z` en todo el contorno. El borde de Tripo va inclinado (detrás 0,017, de lado 0,05, delante 0,09): sin esto la
    capelina acababa en el codo detrás y en el hombro delante, y el concept la quiere al codo en todo el contorno. Por `sectores` de ángulo alrededor del eje
    vertical de la parte baja se mide el punto más bajo y se baja lo que sobra, interpolando entre los centros de los sectores (el borde no hace escalones);
    entero en el borde y nada desde `z_hasta` (gradiente lineal entre medias)."""
    n = int(cfg["sectores"])
    z_obj, z1 = float(cfg["z"]), float(cfg["z_hasta"])
    # La punta caída de la capucha (`excluir`, ver detectar_punta) cuelga por debajo del borde y no es borde: ni se mide ni se mueve.
    fuera = (lambda v: excluir is not None and ids is not None and ids[v.index] in excluir)
    bajos = [v.co for v in o.data.vertices if v.co.z < z1 and not fuera(v)]
    cx = (min(p.x for p in bajos) + max(p.x for p in bajos)) * 0.5
    cy = (min(p.y for p in bajos) + max(p.y for p in bajos)) * 0.5

    def angulo(p: Vector) -> float:
        return (math.atan2(p.x - cx, p.y - cy) + math.pi) / (2.0 * math.pi) * n
    minimo = [z1] * n
    for p in bajos:
        s = int(angulo(p)) % n
        minimo[s] = min(minimo[s], p.z)
    for v in o.data.vertices:
        if v.co.z >= z1 or fuera(v):
            continue
        a = angulo(v.co) - 0.5
        s0 = int(math.floor(a))
        f = a - s0
        borde = minimo[s0 % n] * (1.0 - f) + minimo[(s0 + 1) % n] * f
        sobra = max(0.0, borde - z_obj)
        t = (z1 - v.co.z) / max(z1 - borde, 1e-6)
        # Nunca por debajo de `z`: entre un sector alto y uno vecino ya en el codo, la interpolación bajaba de más los vértices del bajo (11/11: 0,872 -> 0,811).
        v.co.z -= min(sobra * max(0.0, min(1.0, t)), max(0.0, v.co.z - z_obj))


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


def arbol_base(base: bpy.types.Object, debajo: list = None) -> BVHTree:
    """El árbol de la piel de la base y, con `debajo` (rutas de .json de prendas ya encajadas, `sobre` en la config), también sus triángulos: la prenda se
    empuja fuera de la piel Y de la ropa de debajo (12/11: la túnica del loberno sobre las mallas, que la atravesaban por la cadera). Los pesos siguen
    saliendo solo de la base (los triángulos de debajo van DESPUÉS de los suyos: `pesos_desde_base` y `NormalSuave` lo saben por el índice)."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = base.evaluated_get(dg)
    me = ev.to_mesh()
    verts = [base.matrix_world @ v.co for v in me.vertices]
    me.calc_loop_triangles()
    tris = [tuple(t.vertices) for t in me.loop_triangles]
    solo_base = BVHTree.FromPolygons(verts, tris, all_triangles=True) if debajo else None
    for ruta in (debajo or []):
        with open(ruta) as f:
            d = json.load(f)
        n0 = len(verts)
        for q in d["pos"]:
            verts.append(base.matrix_world @ Vector((q[0], -q[2], q[1])))
        idx = d["idx"]
        giradas = 0
        for i in range(0, len(idx), 3):
            t = (n0 + idx[i], n0 + idx[i + 1], n0 + idx[i + 2])
            # 12/11: Meshy trae caras con la normal girada; con ella al revés, el empuje mandaba la túnica 7 cm HACIA DENTRO (y el informe la contaba dentro).
            # Cada triángulo de la prenda de debajo se orienta hacia fuera de la piel de la base (su normal, en el sentido de la piel al triángulo).
            a, b, c = verts[t[0]], verts[t[1]], verts[t[2]]
            cen = (a + b + c) / 3.0
            loc, _nor, _ti, _dist = solo_base.find_nearest(cen)
            if loc is not None and (b - a).cross(c - a).dot(cen - loc) < 0.0:
                t = (t[0], t[2], t[1])
                giradas += 1
            tris.append(t)
        print("SOBRE: %s (%d triángulos, %d girados hacia fuera) cuenta como piel" % (os.path.basename(ruta), len(idx) // 3, giradas))
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

    def en(self, loc: Vector, ti: int, nor: Vector = None) -> Vector:
        if ti >= len(self.normales):
            return nor if nor is not None else Vector((0.0, 0.0, 1.0))      # un triángulo de la prenda de debajo (`sobre`): la normal de su cara
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
                    suavizado: int = SUAVIZADO_EMPUJE, sin_casco: set = None, caja_sin_casco: dict = None, margen_zonas: list = None,
                    radio_empuje: float = 0.0, celdas: dict = None) -> int:
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
            nor = suave.en(loc, ti, nor)
        d_piel = Vector()
        # `margen_zonas` (12/11): holgura mayor en cajas [{x_min, z_min, z_max, margen}] (los hombros de la túnica sin mangas: el brazo cuelga más pegado
        # que en la A-pose y se metía por la manga corta).
        margen_v = margen
        for caja in (margen_zonas or []):
            if abs(p.x) >= float(caja.get("x_min", 0.0)) and p.z >= float(caja.get("z_min", -math.inf)) and p.z <= float(caja.get("z_max", math.inf)):
                margen_v = max(margen_v, float(caja["margen"]))
        if loc is not None and not (abs(loc.x) > OREJA_X and loc.z > OREJA_Z) and (p - loc).dot(nor) < margen_v \
                and (dist <= profundidad_max or p.z > HULL_Z_MIN):
            d_piel = loc + nor * margen_v - p
        # `caja_sin_casco`: cajas (lista o una) donde el casco no empuja: x < x_max, y > y_min, z < z_max (las que falten no limitan); con `rampa`, el empuje
        # vuelve suavemente entre z_max y z_max + rampa (sin escalón en la pared de la capucha).
        con_casco = 1.0
        for caja in (caja_sin_casco if isinstance(caja_sin_casco, list) else ([caja_sin_casco] if caja_sin_casco else [])):
            if p.x < float(caja.get("x_max", math.inf)) and p.y > float(caja.get("y_min", -math.inf)):
                r = float(caja.get("rampa", 0.0))
                # (`suave` aquí es la NormalSuave: la rampa va escrita a mano)
                t = max(0.0, min(1.0, (p.z - float(caja.get("z_max", math.inf))) / r)) if r > 0.0 else (0.0 if p.z < float(caja.get("z_max", math.inf)) else 1.0)
                dentro = 1.0 - t * t * (3.0 - 2.0 * t)
                con_casco *= 1.0 - dentro
        if casco is not None and p.z > HULL_Z_MIN and not (sin_casco and g in sin_casco) and con_casco > 1e-4:
            # Un único factor radial por (ángulo, altura), el mismo para el forro y la capa de fuera: conserva el grosor y la forma de la capucha.
            # La punta caída (`sin_casco`) comparte casillas con la pared de atrás de la capucha y el factor la lanzaba 20 cm hacia atrás: solo la piel. Su raíz, por
            # encima del corte, es capucha y no está en `sin_casco`: la excluye `caja_sin_casco` (x < x_max, y > y_min, z < z_max: detrás a la derecha, bajo la oreja).
            # Delante (la abertura de la cara) manda la normal de la piel, de lado y detrás el casco del pelo.
            k = campo.factor(p.x - casco.cx, p.y - casco.cy, p.z)
            d_casco = Vector(((p.x - casco.cx) * (k - 1.0), (p.y - casco.cy) * (k - 1.0), 0.0))
            w = CampoFactor.peso_lateral(p.x - casco.cx, p.y - casco.cy)
            desp[g] = d_casco * w * con_casco + d_piel * (1.0 - w * con_casco)
            continue
        desp[g] = d_piel
    if radio_empuje > 0.0:
        # 12/11 (túnica del loberno, varias capas de tela: chaleco, panel rojo, cinturón): el empuje se CONTAGIA en el espacio, no solo por la malla. Cada
        # vértice toma el mayor empuje de los que tiene a menos de `radio_empuje`, de cualquier capa: si el faldón azul sale empujado fuera de las mallas, el
        # panel rojo y el cinturón que van encima salen con él (antes se quedaban donde estaban y acababan por debajo del azul).
        from mathutils.kdtree import KDTree
        pos_g = {}
        for v in o.data.vertices:
            pos_g.setdefault(ids[v.index], o.matrix_world @ v.co)
        kd = KDTree(len(pos_g))
        claves = list(pos_g.keys())
        for i, g in enumerate(claves):
            kd.insert(pos_g[g], i)
        kd.balance()
        nuevo = {}
        contagiados = 0
        for g in claves:
            mejor = desp[g]
            for (_co, i, _dist) in kd.find_range(pos_g[g], radio_empuje):
                d = desp[claves[i]]
                if d.length > mejor.length:
                    mejor = d
            if mejor is not desp[g]:
                contagiados += 1
            nuevo[g] = mejor
        desp = nuevo
        print("EMPUJE contagiado a %d vértices (radio %.3f)" % (contagiados, radio_empuje))
    if celdas:
        # 12/11 (túnica del loberno, trece pasadas: chaleco azul + panel rojo + cinturón, capas a radios distintos): el empuje se reparte por CELDAS CILÍNDRICAS
        # (sector de ángulo alrededor del eje de la prenda × banda de altura), sin mirar el radio: todos los vértices de una celda, de la capa que sean, toman el
        # mayor empuje de la celda. Así el faldón azul, el panel rojo que va encima y el cinturón salen JUNTOS fuera de las mallas y conservan el orden de las
        # capas (con el contagio esférico `radio_empuje`, un vértice tomaba el empuje de otro en dirección distinta y se hundía en la piel). Solo por debajo
        # de `z_max`; `sectores` y `alto` dan el tamaño de la celda; cada celda se ensancha con el máximo de sus vecinas (sin escalones). Se reparte solo la
        # COMPONENTE RADIAL (hacia fuera del eje) del empuje: compartiendo el vector entero, el del manto entre el brazo y el costado (que apunta al torso)
        # hundía el chaleco 13 cm en la piel.
        z_max = float(celdas.get("z_max", math.inf))
        sectores, alto = int(celdas.get("sectores", 36)), float(celdas.get("alto", 0.03))
        pos_g = {}
        for v in o.data.vertices:
            pos_g.setdefault(ids[v.index], o.matrix_world @ v.co)
        bajos = [q for q in pos_g.values() if q.z < z_max]
        cx = (min(q.x for q in bajos) + max(q.x for q in bajos)) * 0.5 if bajos else 0.0
        cy = (min(q.y for q in bajos) + max(q.y for q in bajos)) * 0.5 if bajos else 0.0
        def celda(q: Vector) -> tuple:
            return (int((math.atan2(q.y - cy, q.x - cx) + math.pi) / (2.0 * math.pi) * sectores) % sectores, int(math.floor(q.z / alto)))
        def radial(q: Vector) -> Vector:
            r = Vector((q.x - cx, q.y - cy, 0.0))
            return r.normalized() if r.length > 1e-6 else Vector()
        # `radio` (12/11): solo entre vértices a radio parecido (±radio del eje): el cuello del chaleco (a 6 cm del eje) está en el mismo sector y altura
        # que la manga corta (a 20 cm) y tomaba su empuje de 3 cm: el cuello salía desgarrado. Las capas (faldón, panel, cinturón; chaleco y manto en la
        # espalda) están a 1–2 cm unas de otras y sí lo comparten.
        radio_max = float(celdas.get("radio", 0.04))
        def rad(q: Vector) -> float:
            return math.hypot(q.x - cx, q.y - cy)
        mejor = {}
        for g, q in pos_g.items():
            if q.z >= z_max:
                continue
            r = desp[g].dot(radial(q))
            if r > 1e-6:
                mejor.setdefault(celda(q), []).append((rad(q), r))
        ancho = {}
        for (a, b), lista in mejor.items():
            for da in (-1, 0, 1):
                for db in (-1, 0, 1):
                    ancho.setdefault(((a + da) % sectores, b + db), []).extend(lista)
        repartidos = 0
        for g, q in pos_g.items():
            if q.z >= z_max:
                continue
            rq = rad(q)
            falta = max((r for (rv, r) in ancho.get(celda(q), []) if abs(rv - rq) <= radio_max), default=0.0) - desp[g].dot(radial(q))
            if falta > 1e-6:
                desp[g] = desp[g] + radial(q) * falta
                repartidos += 1
        print("EMPUJE repartido por celdas a %d vértices (%d sectores × %.3f)" % (repartidos, sectores, alto))
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


def rellenar_pliegue(o: bpy.types.Object, cfg: dict, ids: list, vecinos: list, excluir: set, cajas: list) -> int:
    """RELLENA EL PLIEGUE de la espalda de la capucha (11/11, Pablo: «La capucha sale partida en dos»). La capucha de Meshy trae una raja honda en el centro de
    la espalda entre dos lóbulos y el casco la ahonda (infla más los lóbulos); en el juego el pelo del hueco está apagado y por la raja se ve la capa. Por
    encima de `z_min` y en la mitad trasera (ángulo desde delante > `angulo_min`), los vértices que miran hacia fuera (producto normal·radial > `radial`)
    suben de radio hasta el mayor radio de su banda de altura en los `vecinos` sectores a cada lado (un cierre morfológico en ángulo: tapa rajas de hasta
    2·vecinos sectores); el forro no se toca. La punta (`excluir`) y las cajas sin casco (`cajas`, la raíz de la punta) ni se miden ni se mueven. El
    desplazamiento se suaviza con los vecinos como en sacar_de_la_piel. Devuelve cuántos vértices sube."""
    z_min, ang_min = float(cfg["z_min"]), float(cfg.get("angulo_min", 110.0))
    n_sec, paso_z, n_vec = int(cfg.get("sectores", 48)), float(cfg.get("banda", 0.03)), int(cfg.get("vecinos", 4))
    umbral = float(cfg.get("radial", 0.3))
    pts = [o.matrix_world @ v.co for v in o.data.vertices]
    cabeza = [p for p in pts if p.z > z_min]
    cx = sum(p.x for p in cabeza) / len(cabeza)
    cy = sum(p.y for p in cabeza) / len(cabeza)
    rot = o.matrix_world.to_3x3()
    normales = {}
    for v in o.data.vertices:
        normales[ids[v.index]] = normales.get(ids[v.index], Vector()) + (rot @ v.normal)

    def en_caja(p: Vector) -> bool:
        for caja in cajas:
            if p.x < float(caja.get("x_max", math.inf)) and p.y > float(caja.get("y_min", -math.inf)) and p.z < float(caja.get("z_max", math.inf)):
                return True
        return False

    def celda(p: Vector) -> tuple:
        ang = math.degrees(math.atan2(p.x - cx, -(p.y - cy)))   # 0 = delante (-Y)
        return (int(((ang + 180.0) / 360.0) * n_sec) % n_sec, int((p.z - z_min) / paso_z), abs(ang))
    cand = {}
    tabla = {}
    for v in o.data.vertices:
        g = ids[v.index]
        if g in cand:
            continue
        p = pts[v.index]
        if p.z <= z_min or g in excluir or en_caja(p):
            continue
        dx, dy = p.x - cx, p.y - cy
        r = math.hypot(dx, dy)
        n = normales[g]
        if r < 1e-6 or n.length < 1e-9 or (n.x * dx + n.y * dy) / (r * n.length) < umbral:
            continue
        sec, fila, ang = celda(p)
        tabla[(sec, fila)] = max(tabla.get((sec, fila), 0.0), r)
        if ang > ang_min:
            cand[g] = (v.index, sec, fila, r, dx, dy)
    desp = {}
    for g, (vi, sec, fila, r, dx, dy) in cand.items():
        objetivo = max(tabla.get(((sec + k) % n_sec, fila), 0.0) for k in range(-n_vec, n_vec + 1))
        if objetivo > r + 1e-4:
            desp[g] = Vector((dx / r * (objetivo - r), dy / r * (objetivo - r), 0.0))
    for _ in range(SUAVIZADO_EMPUJE):
        nuevo = {}
        for g in set(desp) | {h for g in desp for h in vecinos[g]}:
            vec = [desp.get(h, Vector()) for h in vecinos[g]]
            media = sum(vec, Vector()) / len(vec) if vec else Vector()
            d = desp.get(g, Vector())
            nuevo[g] = d if d.length > media.length else d * 0.5 + media * 0.5
        desp = {g: d for g, d in nuevo.items() if d.length > 1e-6 and g not in excluir}
    movidos = 0
    for v in o.data.vertices:
        d = desp.get(ids[v.index])
        if d is not None and pts[v.index].z > z_min - 0.05 and not en_caja(pts[v.index]):
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
    # `lado` (12/11, la hombrera roja del manto del loberno, Pablo: «la parte azul puede ser estática PERO la hombrera roja debe seguir el movimiento»):
    # solo un lado del personaje ("izquierda" = +X) acompaña al brazo; el otro queda como estaba (rígido al torso con `sin_brazos`).
    lado = str(cfg.get("lado", ""))
    if (lado == "izquierda" and p.x < float(cfg.get("eje_x", 0.003))) or (lado == "derecha" and p.x > float(cfg.get("eje_x", 0.003))):
        return 0.0
    t_lat = suave((lat - float(cfg["x0"])) / (float(cfg["x1"]) - float(cfg["x0"])))
    if "z_sube0" in cfg:
        # 12/11 (manga corta del chaleco del loberno): al revés que en la capa, el peso de brazo SUBE con la altura (de nada en z_sube0 a todo en z_sube1): la
        # manga que cubre el hombro acompaña al brazo; el costado del chaleco, no.
        t_alto = suave((p.z - float(cfg["z_sube0"])) / (float(cfg["z_sube1"]) - float(cfg["z_sube0"])))
    else:
        t_alto = 1.0 - suave((p.z - float(cfg["z_baja0"])) / (float(cfg["z_baja1"]) - float(cfg["z_baja0"])))
    return float(cfg["peso"]) * t_lat * t_alto


def pesos_desde_base(o: bpy.types.Object, base: bpy.types.Object, arbol: BVHTree, verts_b: list, tris_b: list, ids: list, vecinos: list,
                     atenuar_piernas: bool, brazo: dict = None, cabeza: dict = None, sin_brazos: bool = False, con_clavicula: bool = False) -> list:
    """Pesos por vértice de la prenda: [{hueso: peso}] (ya suavizados, recortados a 4 y normalizados)."""
    nombres = {g.index: g.name for g in base.vertex_groups}
    pesos_b = [{nombres[g.group]: g.weight for g in v.groups} for v in base.data.vertices]
    por_grupo = {}
    n_base = len(pesos_b)
    arbol_solo_base = None
    for v in o.data.vertices:
        gid = ids[v.index]
        if gid in por_grupo:
            continue
        p = o.matrix_world @ v.co
        loc, nor, ti, dist = arbol.find_nearest(p)
        if max(tris_b[ti]) >= n_base:
            # el punto más cercano es la ropa de debajo (`sobre`): los pesos salen de la base
            if arbol_solo_base is None:
                tb = [t for t in tris_b if max(t) < n_base]
                arbol_solo_base = BVHTree.FromPolygons(verts_b[:n_base], tb, all_triangles=True)
                arbol_solo_base_tris = tb
            loc, nor, ti, dist = arbol_solo_base.find_nearest(p)
            a, b, c = arbol_solo_base_tris[ti]
        else:
            a, b, c = tris_b[ti]
        if False:
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
        if sin_brazos:   # (antes de `brazo`, que puede devolver una parte al brazo a propósito: la manga corta)
            # 12/11 (atuendo del loberno): una prenda SIN MANGAS (chaleco, banda) no debe pesar en los brazos, aunque la sisa tenga el brazo como superficie más
            # cercana: al levantarlo se llevaba tiras de tela (lo mismo que la capa, ver CapaMuelles3D «REPARTO DE PESOS»). Todo a Spine2, clavícula incluida
            # (Pablo: «es una túnica sin mangas y se está cosiendo a los brazos»); con `con_clavicula` la sisa acompaña al hombro (probado: la banda se deformaba a cada paso).
            quitado = 0.0
            for hueso in list(d.keys()):
                if hueso.endswith("Arm") or hueso.endswith("ForeArm") or "Hand" in hueso or (hueso.endswith("Shoulder") and not con_clavicula):
                    quitado += d.pop(hueso)
            if quitado > 0.0:
                d["mixamorig_Spine2"] = d.get("mixamorig_Spine2", 0.0) + quitado
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


def detectar_punta(o: bpy.types.Object, corte: dict, ids: list, vecinos: list) -> set:
    """La PUNTA CAÍDA de la capucha (11/11, uniforme de Sumicio; decidido por Pablo: rígida, al hueso Head). Cuelga por detrás hasta por debajo del corte
    capa/capucha, así que por altura se iría con la capa (Spine2 y muelles) y se estiraría entre la cabeza y el torso. Por debajo del corte, los vértices
    (soldados por posición) que NO están unidos a la pieza mayor (la capa) y cuyo centro cae en x < `x_max` (la punta cae hacia la derecha del personaje, -X) son
    la punta. Devuelve sus ids soldados (vacío si no hay). Se detecta nada más colocar la prenda: `nivelar_borde` y el casco de `sacar_de_la_piel` la dejan en
    paz, y al final `separar_punta` la saca de la prenda y `partir_con_solape` la une a la capucha con peso 1 en Head."""
    pc = corte["punta"]
    pos = {}
    for v in o.data.vertices:
        pos.setdefault(ids[v.index], o.matrix_world @ v.co)
    abajo = {g for g, p in pos.items() if p.z < altura_corte(p, corte)}
    visto = set()
    comps = []
    for g in abajo:
        if g in visto:
            continue
        pila = [g]
        visto.add(g)
        miembros = []
        while pila:
            u = pila.pop()
            miembros.append(u)
            for w in vecinos[u]:
                if w in abajo and w not in visto:
                    visto.add(w)
                    pila.append(w)
        comps.append(miembros)
    comps.sort(key=len, reverse=True)
    punta = set()
    for m in comps[1:]:
        cx = sum(pos[g].x for g in m) / len(m)
        if cx < float(pc["x_max"]):
            punta.update(m)
    if not punta:
        print("PUNTA: no hay trozos sueltos bajo el corte (%d componentes)" % len(comps))
    return punta


def separar_punta(o: bpy.types.Object, punta: set, ids: list) -> bpy.types.Object:
    """Saca de `o` las caras de la punta (ver detectar_punta), enteras las que cruzan el corte (así no quedan astillas en la capa), como objeto aparte."""
    if not punta:
        return None
    caras = {p.index for p in o.data.polygons if any(ids[i] in punta for i in p.vertices)}
    copia = o.copy()
    copia.data = o.data.copy()
    copia.name = o.name + "_punta"
    bpy.context.scene.collection.objects.link(copia)
    for obj, quedarse in ((copia, True), (o, False)):
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if (f.index in caras) != quedarse], context='FACES')
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
        bm.to_mesh(obj.data)
        bm.free()
    zs = [(copia.matrix_world @ v.co).z for v in copia.data.vertices]
    print("PUNTA: %d caras y %d vértices a la capucha (Head); z %.3f..%.3f" % (len(caras), len(copia.data.vertices), min(zs), max(zs)))
    return copia


def partir_con_solape(o: bpy.types.Object, pesos: list, corte: dict, punta: bpy.types.Object = None) -> list:
    """Parte la prenda en capucha y capa con un corte LIMPIO y con SOLAPE (26/10, Pablo: «hay una textura rota ahí», junto a la cara y detrás de la oreja).
    Antes cada triángulo iba entero a una pieza por la altura de su centro: el borde quedaba en dientes, las dos piezas solo se tocaban en esos dientes y, como la
    capucha va con Head y la capa con Spine2 (y con la cabeza encogida a 0,80 encima), al andar y al correr se abrían rendijas por las que se veía el cuello.
    Ahora: la capucha se corta con `bisect_plane` por el plano de `altura_corte` (borde recto, los triángulos partidos y con UV y pesos interpolados); la capa se
    corta igual pero `banda` más arriba, y esa franja de más se mete por debajo de la capucha: cada vértice se hunde `hundir` hacia atrás de su propia cara (la
    de fuera hacia dentro y el forro hacia fuera: queda entre las dos capas de la tela de la capucha), con una rampa de `rampa` que acaba en el corte. En
    reposo no se ve (la tapa la capucha); cuando la cabeza se mueve, lo que asoma por debajo del borde de la capucha es la capa y no el cuello.
    Los pesos viajan como grupos de vértices para que bmesh los interpole en los vértices nuevos. Devuelve [(nombre, objeto, pesos)]."""
    for h in sorted({h for vp in pesos for h, _ in vp}):
        o.vertex_groups.new(name=h)
    for v in o.data.vertices:
        for h, w in pesos[v.index]:
            o.vertex_groups[h].add([v.index], w, 'REPLACE')
    inv = o.matrix_world.inverted()
    z0 = float(corte["z"])
    normal = (inv.to_3x3() @ Vector((0.0, float(corte.get("inclina", 0.0)), 1.0))).normalized()
    res = []
    for parte, subir, es_capa in ((corte.get("nombre", "capucha"), 0.0, False), ("capa", float(corte["banda"]), True)):
        copia = o.copy()
        copia.data = o.data.copy()
        copia.name = "%s_%s" % (o.name, parte)
        bpy.context.scene.collection.objects.link(copia)
        bm = bmesh.new()
        bm.from_mesh(copia.data)
        # clear_outer quita lo que queda del lado de la normal (arriba): la capa se queda con lo de abajo; la capucha, con lo de arriba.
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-6, plane_co=inv @ Vector((0.0, 0.0, z0 + subir)),
                               plane_no=normal, clear_outer=es_capa, clear_inner=not es_capa)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
        bm.to_mesh(copia.data)
        bm.free()
        if es_capa:
            print("BANDA %s: %d vértices metidos bajo la capucha" % (parte, meter_banda(copia, corte)))
        elif punta is not None:
            # La punta caída se une a la capucha con todo su peso en Head; los vértices de la costura (duplicados al separarla) se vuelven a soldar.
            g = punta.vertex_groups.new(name="mixamorig_Head")
            g.add([v.index for v in punta.data.vertices], 1.0, 'REPLACE')
            bpy.ops.object.select_all(action='DESELECT')
            copia.select_set(True)
            punta.select_set(True)
            bpy.context.view_layer.objects.active = copia
            bpy.ops.object.join()
            bm = bmesh.new()
            bm.from_mesh(copia.data)
            bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
            bm.to_mesh(copia.data)
            bm.free()
        res.append((parte, copia, pesos_de_grupos(copia)))
    return res


def meter_banda(o: bpy.types.Object, corte: dict) -> int:
    """Hunde la franja de la capa que pasa del corte hacia atrás de su cara (normal soldada por posición): `hundir` entero desde el corte hacia arriba y nada a
    `rampa` por debajo de él (suave). Devuelve cuántos vértices se movieron."""
    ids, _ = adyacencia_soldada(o)
    normales = {}
    for v in o.data.vertices:
        normales[ids[v.index]] = normales.get(ids[v.index], Vector()) + v.normal
    rot = o.matrix_world.to_3x3()
    inv = o.matrix_world.inverted()
    hundir, rampa = float(corte["hundir"]), float(corte["rampa"])
    movidos = 0
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        t = suave((p.z - (altura_corte(p, corte) - rampa)) / rampa)
        n = normales[ids[v.index]]
        if t <= 0.0 or n.length < 1e-9:
            continue
        v.co = inv @ (p - (rot @ n).normalized() * hundir * t)
        movidos += 1
    return movidos


def pesos_de_grupos(o: bpy.types.Object) -> list:
    """Pesos por vértice desde los grupos de vértices: [(hueso, peso)], los INFLUENCIAS mayores, normalizados (el formato de `pesos_desde_base`)."""
    nombres = {g.index: g.name for g in o.vertex_groups}
    res = []
    sin_peso = 0
    for v in o.data.vertices:
        top = sorted(((nombres[g.group], g.weight) for g in v.groups if g.weight > 0.0), key=lambda kv: -kv[1])[:INFLUENCIAS]
        tot = sum(w for _, w in top)
        if tot < 1e-9:
            sin_peso += 1
            top, tot = [("mixamorig_Head", 1.0)], 1.0
        res.append([(h, w / tot) for h, w in top])
    if sin_peso:
        print("AVISO %s: %d vértices sin peso tras el corte (a Head)" % (o.name, sin_peso))
    return res


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


def rellenar_fondo(img: bpy.types.Image, pasadas: int = 12) -> int:
    """12/11: el fondo NEGRO entre las islas de UV de Meshy se rellena con el color de la isla más cercana (dilatación, `pasadas` píxeles), para que el filtrado
    bilineal y los mipmaps no oscurezcan los bordes de cada isla. Solo la textura de color. Devuelve cuántos píxeles de fondo había."""
    import numpy as np
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    fondo = px[:, :, :3].max(axis=2) < 0.03
    n_fondo = int(fondo.sum())
    if n_fondo == 0 or n_fondo == w * h:
        return n_fondo
    lleno = ~fondo
    for _ in range(pasadas):
        if lleno.all():
            break
        nuevo = px.copy()
        cuenta = np.zeros((h, w), dtype=np.float32)
        suma = np.zeros((h, w, 3), dtype=np.float32)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                vec_lleno = np.roll(np.roll(lleno, dy, axis=0), dx, axis=1)
                vec_px = np.roll(np.roll(px[:, :, :3], dy, axis=0), dx, axis=1)
                suma += vec_px * vec_lleno[:, :, None]
                cuenta += vec_lleno
        toca = (~lleno) & (cuenta > 0)
        nuevo[toca, :3] = suma[toca] / cuenta[toca][:, None]
        px = nuevo
        lleno = lleno | toca
    img.pixels = px.reshape(-1).tolist()
    return n_fondo


def guardar_texturas(o: bpy.types.Object, carpeta: str) -> None:
    for m in o.data.materials:
        for n in m.node_tree.nodes:
            if n.type == 'TEX_IMAGE' and n.image is not None:
                # Por el nombre (Tripo) o, si no dice nada, por el enchufe al que va (Meshy: una sola imagen sin nombre, al Base Color del Principled).
                enlaces = [l for sal in n.outputs for l in sal.links]
                enchufes = {l.to_socket.name.lower() for l in enlaces}
                nombre_img = n.image.name.lower()
                if "basecolor" in nombre_img or "base color" in enchufes:
                    nombre = "basecolor"
                elif "normal" in nombre_img or any(l.to_node.type == 'NORMAL_MAP' for l in enlaces):
                    nombre = "normal"
                else:
                    nombre = "rm"
                if nombre == "basecolor":
                    print("FONDO %s: %d píxeles de fondo rellenados con la isla vecina" % (o.name, rellenar_fondo(n.image)))
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
    por_altura, hondos = {}, []
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        loc, nor, ti, dist = arbol.find_nearest(p)
        if abs(loc.x) > OREJA_X and loc.z > OREJA_Z:
            continue
        if suave is not None:
            nor = suave.en(loc, ti, nor)
        s = (p - loc).dot(nor) if dist <= profundidad_max or p.z > HULL_Z_MIN else dist
        total += 1
        peor = min(peor, s)
        if s < 0.0:
            dentro += 1
            banda = round(math.floor(p.z / BANDA_INFORME) * BANDA_INFORME, 2)
            por_altura[banda] = por_altura.get(banda, 0) + 1
            hondos.append((round(s, 4), tuple(round(c, 3) for c in p), tuple(round(c, 3) for c in loc)))
    if os.environ.get("ROPA_DEPURA"):
        print("DENTRO %s por altura (bandas de %.2f): %s" % (nombre, BANDA_INFORME, sorted(por_altura.items())))
        print("DENTRO %s los más hondos (profundidad, vértice, punto de la piel): %s" % (nombre, sorted(hondos)[:8]))
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
                if k.startswith("_"):
                    cfg[k] = v
                else:
                    cfg.setdefault(k, {}).update(v)
    prendas = list(cfg.get("_prendas", ["capa", "tunica"]))
    if len(a) > 4:
        prendas = [a[4]]      # 12/11: un 5.º argumento procesa SOLO esa prenda (una config con varias prendas, cada una con su .glb)
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
    for nombre in prendas:
        c = cfg[nombre]
        if c.get("sobre"):
            # Las prendas de debajo ya encajadas: sus .json están junto a la carpeta de salida de ESTA (../<prenda>/<prenda>.json).
            rutas = [os.path.join(os.path.dirname(os.path.abspath(carpeta)), str(q), str(q) + ".json") for q in c["sobre"]]
            arbol, verts_b, tris_b = arbol_base(base, rutas)
        else:
            arbol, verts_b, tris_b = arbol_base(base)
        o = separar_prenda(vestido, nombre, str(c.get("parte", "derecha" if nombre == "tunica" else "izquierda")))
        corte = c.get("capucha")
        if "quitar_forro" in c:
            # Antes de reducir (así el presupuesto de triángulos se gasta en lo que se ve) y ya colocada (el corte de la punta es en alturas del mundo).
            colocar(o, c)
            ids, vecinos = adyacencia_soldada(o)
            punta_ids = detectar_punta(o, corte, ids, vecinos) if corte is not None and "punta" in corte else set()
            print("FORRO %s: %d caras de la pared interior quitadas" % (nombre, quitar_forro(o, c["quitar_forro"], ids, punta_ids)))
            reducir(o, int(c["tris"]))
        else:
            reducir(o, int(c["tris"]))
            colocar(o, c)
        ids, vecinos = adyacencia_soldada(o)
        punta_ids = detectar_punta(o, corte, ids, vecinos) if corte is not None and "punta" in corte else set()
        if "nivela_borde" in c:
            nivelar_borde(o, c["nivela_borde"], ids, punta_ids)
        # El casco se mide solo con los vértices de la cabeza y el pelo (peso de Head): por encima de HULL_Z_MIN también están los hombros y los brazos.
        g_cabeza = base.vertex_groups["mixamorig_Head"].index
        verts_cabeza = [verts_b[v.index] for v in base.data.vertices if any(g.group == g_cabeza and g.weight > 0.5 for g in v.groups)]
        casco = CascoCabeza(verts_cabeza) if "margen_casco" in c else None
        suave = NormalSuave(base, verts_b, tris_b) if c.get("normal_suave", False) else None
        profundidad = float(c.get("profundidad_max", math.inf))
        movidos = sacar_de_la_piel(o, arbol, float(c["margen"]), ids, vecinos, casco, float(c.get("margen_casco", 0.0)), suave, profundidad,
                                   sin_casco=punta_ids, caja_sin_casco=(corte or {}).get("punta", {}).get("sin_casco"), margen_zonas=c.get("margen_zonas"),
                                   radio_empuje=float(c.get("radio_empuje", 0.0)), celdas=c.get("celdas"))
        # Con `pasadas_piel` > 1 se repasa solo la piel (sin el casco, que volvería a ensanchar la capucha): el suavizado del desplazamiento mezcla direcciones y
        # deja vértices a pocos milímetros bajo la piel (el cuello de la capa, que abraza el de la jugadora). La última pasada va sin suavizar (cada vértice por
        # su normal). Con 8 pasadas, los vértices dentro de la base bajan de 607 a 25 (informe).
        extra = int(c.get("pasadas_piel", 1)) - 1
        for i in range(extra):
            sacar_de_la_piel(o, arbol, float(c["margen"]), ids, vecinos, None, 0.0, suave, profundidad, 0 if i == extra - 1 else SUAVIZADO_EMPUJE,
                             margen_zonas=c.get("margen_zonas"), radio_empuje=float(c.get("radio_empuje", 0.0)), celdas=c.get("celdas"))
        print("PRENDA %s: %d vértices empujados fuera de la piel" % (nombre, movidos))
        if "rellenar_pliegue" in c:
            cajas = (corte or {}).get("punta", {}).get("sin_casco", [])
            print("PLIEGUE %s: %d vértices subidos de radio" % (nombre, rellenar_pliegue(o, c["rellenar_pliegue"], ids, vecinos, punta_ids,
                                                                                          cajas if isinstance(cajas, list) else [cajas])))
        informe(o, arbol, nombre, suave, profundidad)
        if nombre == "capa" and os.environ.get("ROPA_DEPURA"):
            perfil_cabeza(o, verts_b)
        punta = separar_punta(o, punta_ids, ids)
        if punta is not None:
            ids, vecinos = adyacencia_soldada(o)
        pesos = pesos_desde_base(o, base, arbol, verts_b, tris_b, ids, vecinos, bool(c.get("atenuar_piernas", False)), c.get("brazo"),
                                 c.get("cabeza"), bool(c.get("sin_brazos", False)), bool(c.get("con_clavicula", False)))
        borde = (c.get("brazo") or {}).get("borde")
        if borde is not None:
            pesos, con_gradiente = suavizar_borde_trasero(o, pesos, ids, vecinos, borde)
            print("BORDE %s: %d vértices con gradiente de orla trasera" % (nombre, con_gradiente))
        if corte is None:
            d = exportar(o, pesos, base, carpeta, nombre)
            print("EXPORTADA %s: %d vértices, %d triángulos, %d huesos" % (nombre, len(d["pos"]), len(d["idx"]) // 3, len(d["huesos"])))
        elif "banda" not in corte:
            # Se parte en dos prendas por una altura (algo inclinada): lo de arriba es la capucha y lo de abajo la capa. Cada triángulo, por su centro.
            def es_capucha(t) -> bool:
                cen = sum((o.matrix_world @ o.data.vertices[i].co for i in t.vertices), Vector()) / 3.0
                return cen.z > altura_corte(cen, corte)
            for parte, filtro in (("capa", lambda t: not es_capucha(t)), (corte.get("nombre", "capucha"), es_capucha)):
                d = exportar(o, pesos, base, carpeta, parte, filtro)
                print("EXPORTADA %s: %d vértices, %d triángulos, %d huesos" % (parte, len(d["pos"]), len(d["idx"]) // 3, len(d["huesos"])))
        else:
            # 26/10: corte limpio y con solape (ver `partir_con_solape`).
            for parte, malla, pesos_parte in partir_con_solape(o, pesos, corte, punta):
                d = exportar(malla, pesos_parte, base, carpeta, parte)
                print("EXPORTADA %s: %d vértices, %d triángulos, %d huesos" % (parte, len(d["pos"]), len(d["idx"]) // 3, len(d["huesos"])))
        guardar_texturas(o, carpeta)


main()
