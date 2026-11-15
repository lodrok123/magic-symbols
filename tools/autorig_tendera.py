"""Encaja la tendera al rig de goblin_base y hornea sus tres clips.

blender -b --python tools/autorig_tendera.py -- modelo_meshy.glb salida.glb
"""

import sys
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.interpolate import poly_3d_calc

sys.path.insert(0, str(Path(__file__).resolve().parent))
from autorig_fantasma import (  # noqa: E402
    aplicar_pesos, color_por_vertice, comprobar_orientacion, crear_armadura,
    datos_donante, escalas_hueso, importar, leer_destino, maniqui,
    pesos_por_segmento, prefijo_de, soldar,
)


CLIPS = ("idle", "walk", "hablar")
RAIZ = Path(__file__).resolve().parents[1]

# Articulaciones medidas sobre la malla de Bramblebraid, con pies en z=0.
TRONCO = {
    "Hips": (0, 0.008, 0.409),
    "Spine": (0, 0.009, 0.449),
    "Spine1": (0, 0.012, 0.498),
    "Spine2": (0, 0.014, 0.551),
    "Neck": (0, 0.008, 0.624),
    "Head": (0, -0.010, 0.664),
    "HeadTop_End": (0, -0.020, 0.911),
}
EXTREMIDADES = {
    "Shoulder": (0.035, 0.012, 0.579),
    "Arm": (0.095, 0.010, 0.575),
    "ForeArm": (0.174, -0.009, 0.510),
    "Hand": (0.272, -0.053, 0.426),
    "UpLeg": (0.068, 0.012, 0.365),
    "Leg": (0.107, -0.003, 0.238),
    "Foot": (0.129, 0.031, 0.078),
    "ToeBase": (0.133, -0.072, 0.025),
    "Toe_End": (0.140, -0.127, 0.017),
}


def encajar(huesos, pre, tronco=TRONCO, extremidades=EXTREMIDADES):
    pos = {pre + nombre: Vector(p) for nombre, p in tronco.items()}
    for lado, signo in (("Left", 1), ("Right", -1)):
        mano = pre + lado + "Hand"
        for nombre, (x, y, z) in extremidades.items():
            pos[pre + lado + nombre] = Vector((x * signo, y, z))
        for nombre, hueso in huesos.items():
            if nombre.startswith(mano) and nombre not in pos:
                delta = hueso["cabeza"] - huesos[mano]["cabeza"]
                pos[nombre] = pos[mano] + Vector((delta.x * 0.97, delta.y * 0.83, delta.z * 0.83))
    if pos.keys() != huesos.keys():
        raise ValueError(f"Huesos del donante sin encaje: {set(huesos) - set(pos)}")
    return pos


def rampa(x, a, b):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def mezclar(a, b, t):
    return {n: a.get(n, 0) * (1 - t) + b.get(n, 0) * t for n in a.keys() | b.keys()}


def pesos_goblin(obj, pre, huesos, pos, vs, pesos, tris, umbral_cabeza, ajustar_pesos=None):
    origen = maniqui(vs, pesos, huesos, pos, escalas_hueso(huesos, pos))
    # Descarta del donante los triángulos de la punta del gorro. El pelo de la tendera
    # sigue la cabeza completa y no debe heredar pesos de un accesorio que no tiene.
    tris = [t for t in tris if max(vs[i].z for i in t) < 0.89]
    bvh = BVHTree.FromPolygons(origen, tris, all_triangles=True)
    etiquetas, vertices, vecinos = soldar(obj)
    colores_malla = color_por_vertice(obj) if ajustar_pesos else []
    colores = {}
    for i, grupo in enumerate(etiquetas):
        if colores_malla:
            colores.setdefault(grupo, colores_malla[i])

    segmentos = {
        n: (pos[d["padre"]], pos[n]) for n, d in huesos.items() if d["padre"]
    }
    directos = []
    for i, p in enumerate(vertices):
        superficie, _, cara, d = bvh.find_nearest(p)
        w = {}
        if cara is not None and d < 0.11:
            t = tris[cara]
            for vi, factor in zip(t, poly_3d_calc([origen[v] for v in t], superficie)):
                for n, v in pesos[vi].items():
                    w[n] = w.get(n, 0) + max(0.0, factor) * v
        if not w:
            w = pesos_por_segmento(p, segmentos)
        cabeza = rampa(p.z, *umbral_cabeza)
        if cabeza > 0:
            w = mezclar(w, {pre + "Head": 1.0}, cabeza)

        if ajustar_pesos:
            w = ajustar_pesos(p, colores.get(i, (0.0, 0.0, 0.0)), w, pre)
        directos.append(w)

    for _ in range(4):
        tratados = []
        for i, w in enumerate(directos):
            alrededor = vecinos[i]
            if not alrededor or vertices[i].z > umbral_cabeza[1] + 0.002:
                tratados.append(w)
                continue
            promedio = {}
            for j in alrededor:
                for n, x in directos[j].items():
                    promedio[n] = promedio.get(n, 0) + x / len(alrededor)
            tratados.append(mezclar(w, promedio, 0.48))
        directos = tratados

    pesos_finales = []
    for w in directos:
        mejores = sorted(w.items(), key=lambda par: par[1], reverse=True)[:4]
        mejores = [par for par in mejores if par[1] >= 0.012] or mejores[:1]
        total = sum(x for _, x in mejores)
        pesos_finales.append({n: x / total for n, x in mejores})
    return etiquetas, vertices, pesos_finales


def ajustar_trenza(p, color, w, pre):
    # La trenza pasa delante del brazo derecho y su punta acompaña el torso.
    r, g, _ = color
    if -0.156 < p.x < -0.038 and 0.346 < p.z < 0.656 and r > 1.13 * g:
        delante = 1.0 - rampa(p.y, -0.102, -0.068)
        borde = rampa(p.x, -0.156, -0.121) * (1 - rampa(p.x, -0.057, -0.038))
        pelo = delante * borde * rampa(p.z, 0.346, 0.377)
        alto = rampa(p.z, 0.498, 0.643)
        tronco = rampa(p.z, 0.415, 0.520)
        return mezclar(w, {pre + "Head": alto, pre + "Spine2": (1 - alto) * tronco,
                          pre + "Spine1": (1 - alto) * (1 - tronco)}, pelo)
    return w


def clips_de(rig):
    return {strip.action.name: (strip.action, strip.action_slot)
            for track in rig.animation_data.nla_tracks for strip in track.strips}


def alinear_brazos(donante, rig, pre, pre_origen):
    """Lleva la pose A de la malla a la referencia de brazos de Mixamo."""
    ajustes = {}
    for lado in ("Left", "Right"):
        for tramo, extremo in (("Arm", "ForeArm"), ("ForeArm", "Hand")):
            origen = donante.data.bones[pre_origen + lado + tramo]
            distal = donante.data.bones[pre_origen + lado + extremo]
            punto = rig.data.bones[pre + lado + tramo]
            vector_d = rig.data.bones[pre + lado + extremo].head_local - punto.head_local
            vector_o = donante.matrix_world.to_3x3() @ (distal.head_local - origen.head_local)
            ajustes[punto.name] = vector_d.rotation_difference(vector_o)
        for hueso in rig.data.bones:
            if hueso.name.startswith(pre + lado + "Hand"):
                ajustes[hueso.name] = ajustes[pre + lado + "ForeArm"]
    return ajustes


def hornear_clips(rig, pre, vertices, pesos, clips):
    data = rig.animation_data_create()
    cadera = rig.pose.bones[pre + "Hips"]
    ejes = cadera.bone.matrix_local.to_3x3().normalized()
    inversa = ejes.inverted()
    suelo = [(p, w) for p, w in zip(vertices, pesos) if p.z < 0.013][::3]
    rest = {b.name: b.bone.matrix_local.inverted() for b in rig.pose.bones}
    for nombre, (donante, fuente, slot, alinear) in clips.items():
        donante.animation_data.use_nla = False
        donante.animation_data.action = fuente
        donante.animation_data.action_slot = slot
        # La rotación relativa al reposo se traslada entre los ejes de cada hueso.
        pre_origen = prefijo_de(donante.pose.bones.keys())
        ajustes = alinear_brazos(donante, rig, pre, pre_origen) if alinear else {}
        huesos_clip = {}
        for b in rig.pose.bones:
            origen = donante.pose.bones[pre_origen + b.name.removeprefix(pre)]
            base_o = (donante.matrix_world @ origen.bone.matrix_local).to_quaternion()
            base_d = b.bone.matrix_local.to_quaternion()
            ajuste_padre = ajustes.get(b.parent.name) if b.parent else None
            ajuste = ajustes.get(b.name)
            izquierda = base_d.inverted()
            derecha = base_d
            if ajuste_padre is not None:
                izquierda = izquierda @ ajuste_padre.inverted()
            if ajuste is not None:
                derecha = ajuste @ derecha
            huesos_clip[b.name] = (origen, izquierda @ base_o, base_o.inverted() @ derecha)
        accion = bpy.data.actions.new(rig.name + "_" + nombre)
        data.action = accion
        anterior = {}
        primero, ultimo = map(round, fuente.frame_range)
        cuadros = list(range(primero, ultimo, 2)) + [ultimo]
        for f in cuadros:
            bpy.context.scene.frame_set(f)
            for b in rig.pose.bones:
                origen, base, inversa_base = huesos_clip[b.name]
                q = base @ origen.matrix_basis.to_quaternion() @ inversa_base
                if b.name in anterior and q.dot(anterior[b.name]) < 0:
                    q.negate()
                b.rotation_mode = "QUATERNION"
                b.rotation_quaternion = q
                anterior[b.name] = q.copy()
                b.keyframe_insert(data_path="rotation_quaternion", frame=f, group=b.name)
            # Traslada la cadera solo en vertical. El personaje del juego aplica
            # el movimiento, así que el ciclo de andar se exporta en el sitio.
            cadera.location = Vector((0, 0, 0))
            bpy.context.view_layer.update()
            deformacion = {b.name: b.matrix @ rest[b.name] for b in rig.pose.bones}
            fondo = min(sum((deformacion[n] @ p).z * x for n, x in w.items()) for p, w in suelo)
            cadera.location = inversa @ Vector((0, 0, -fondo))
            cadera.keyframe_insert(data_path="location", frame=f, group=cadera.name)
        data.action = None
        pista = data.nla_tracks.new()
        pista.name = nombre
        pista.strips.new(nombre, 0, accion)
        pista.mute = True
        print(f"{nombre}: {len(cuadros)} muestras, {ultimo / bpy.context.scene.render.fps:.2f} s", flush=True)
    for pista in data.nla_tracks:
        pista.mute = False


def riggear(destino, salida, nombre, tronco, extremidades, umbral_cabeza, ajustar_pesos,
            clips_mixamo=None, animar=None, clips_base=CLIPS):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 24
    fuentes = importar(str(RAIZ / "arte/modelos/goblin_base.glb"))
    donante, huesos, vs, pesos, tris, _ = datos_donante(fuentes)
    obj = leer_destino(destino)
    obj.name = nombre
    comprobar_orientacion([v.co for v in obj.data.vertices], huesos, prefijo_de(huesos))
    pre = prefijo_de(huesos)
    pos = encajar(huesos, pre, tronco, extremidades)
    rig = crear_armadura(huesos, pos)
    rig.name = "Esqueleto" + nombre
    etiquetas, vertices, w = pesos_goblin(obj, pre, huesos, pos, vs, pesos, tris, umbral_cabeza, ajustar_pesos)
    aplicar_pesos(obj, rig, huesos, etiquetas, w)
    if clips_mixamo is not None or animar is None:
        base = clips_de(donante)
        clips = {n: (donante, *base[n], False) for n in clips_base}
    else:
        clips = {}
    if clips_mixamo:
        mixamo = importar(str(RAIZ / "arte/meshy/mixamo_clips.glb"))
        donante_mixamo = next(o for o in mixamo if o.type == "ARMATURE")
        extras = clips_de(donante_mixamo)
        clips.update({n: (donante_mixamo, *extras[clip], True) for n, clip in clips_mixamo.items()})
        fuentes.extend(mixamo)
    if clips:
        hornear_clips(rig, pre, vertices, w, clips)
    if animar is not None:
        animar(rig, pre)
    for o in fuentes:
        bpy.data.objects.remove(o, do_unlink=True)
    for material in obj.data.materials:
        for nodo in material.node_tree.nodes:
            if nodo.type == "BSDF_PRINCIPLED":
                nodo.inputs["Roughness"].default_value = 0.82
            if nodo.type == "TEX_IMAGE" and nodo.image and max(nodo.image.size) > 1024:
                nodo.image.scale(1024, 1024)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=salida, export_format="GLB", use_selection=True,
                             export_animations=True, export_animation_mode="NLA_TRACKS",
                             export_skins=True, export_image_format="JPEG")


def main():
    destino, salida = sys.argv[sys.argv.index("--") + 1:]
    riggear(destino, salida, "Tendera", TRONCO, EXTREMIDADES, (0.619, 0.651),
             ajustar_trenza, {"atender_mostrador": "Bartending"})


if __name__ == "__main__":
    main()
