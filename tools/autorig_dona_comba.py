"""Rig y clips de Doña Comba, la tendera de Monte Sumicio (Meshy, goblin con vestido y falda larga).

blender -b --python tools/autorig_dona_comba.py -- modelo_meshy.glb salida.glb
"""

import sys
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from autorig_tendera import mezclar, rampa, riggear  # noqa: E402


# Articulaciones en metros medidas sobre la malla de Doña Comba, con pies en z=0.
TRONCO = {
    "Hips": (0, 0.0, 0.400),
    "Spine": (0, 0.0, 0.445),
    "Spine1": (0, 0.0, 0.505),
    "Spine2": (0, 0.005, 0.565),
    "Neck": (0, -0.015, 0.645),
    "Head": (0, -0.010, 0.685),
    "HeadTop_End": (0, -0.010, 0.950),
}
EXTREMIDADES = {
    "Shoulder": (0.050, 0.005, 0.615),
    "Arm": (0.155, 0.010, 0.595),
    "ForeArm": (0.225, 0.000, 0.510),
    "Hand": (0.285, -0.010, 0.440),
    "UpLeg": (0.085, 0.0, 0.365),
    "Leg": (0.090, 0.0, 0.200),
    "Foot": (0.110, 0.010, 0.065),
    "ToeBase": (0.115, -0.075, 0.020),
    "Toe_End": (0.115, -0.125, 0.015),
}

# 20/11: Doña Comba es mas ancha de cadera que el donante goblin y, con los clips tal cual, las manos
# (sobre todo en "hablar", con la mano en la cadera) se hunden en la falda. Se separan los brazos del
# cuerpo girandolos este angulo sobre el eje delantero-trasero en cada cuadro de cada clip.
ABRIR_BRAZOS_GRADOS = 10.0

tocados = 0


def es_piel_comba(color):
    # Piel amarillo-verdosa: verde casi igual de alto que el rojo y claramente sobre el azul.
    # El vestido (azul marino) tiene g < b; el delantal crema, g < 0.82 r; cinturon y bolso, g < 0.65 r.
    r, g, b = color
    return g >= 0.85 * r and g >= b + 0.10


def ajustar_comba(p, color, w, pre):
    # Regla de la falda: la tela entre la cintura y el bajo sigue a la pelvis, no a cada pierna,
    # para que la falda no se parta entre las piernas al caminar. La piel conserva sus pesos.
    global tocados
    if not 0.13 < p.z < 0.47:
        return w
    if abs(p.x) > 0.24 and p.z > 0.37:
        return w
    if es_piel_comba(color):
        return w
    s = rampa(p.z, 0.42, 0.47)
    objetivo = {pre + "Hips": 1 - s, pre + "Spine": s}
    t = 0.9 * rampa(p.z, 0.13, 0.17)
    if t <= 0:
        return w
    tocados += 1
    return mezclar(w, objetivo, t)


def _curvas_rotacion(accion, hueso):
    ruta = f'pose.bones["{hueso}"].rotation_quaternion'
    capas = [c for capa in accion.layers for tira in capa.strips for c in tira.channelbags]
    curvas = {}
    for bolsa in capas:
        for fc in bolsa.fcurves:
            if fc.data_path == ruta:
                curvas[fc.array_index] = fc
    return curvas


def _x_manos(rig, pre):
    bpy.context.view_layer.update()
    return {lado: (rig.matrix_world @ rig.pose.bones[pre + lado + "Hand"].head).x
            for lado in ("Left", "Right")}


def abrir_brazos(rig, pre):
    """Separa los brazos del cuerpo en todos los clips horneados (cuaterniones de pose)."""
    angulo = ABRIR_BRAZOS_GRADOS * 3.14159265 / 180
    pistas = list(rig.animation_data.nla_tracks)
    acciones = {p.name: p.strips[0].action for p in pistas}

    def solo(nombre):
        for p in pistas:
            p.mute = p.name != nombre

    def rotacion(lado, signo):
        hueso = rig.pose.bones[pre + lado + "Arm"]
        eje = (hueso.bone.matrix_local.to_3x3().inverted() @ Vector((0, 1, 0))).normalized()
        return Quaternion(eje, signo * angulo)

    # El signo de cada lado se decide midiendo: la mano debe alejarse del cuerpo.
    solo("idle")
    bpy.context.scene.frame_set(0)
    antes = _x_manos(rig, pre)
    print("Manos (x) idle cuadro 0 antes:", {k: round(v, 4) for k, v in antes.items()})
    signos = {}
    for lado in ("Left", "Right"):
        hueso = rig.pose.bones[pre + lado + "Arm"]
        q0 = hueso.rotation_quaternion.copy()
        mejor = None
        for signo in (1, -1):
            hueso.rotation_quaternion = rotacion(lado, signo) @ q0
            d = abs(_x_manos(rig, pre)[lado]) - abs(antes[lado])
            if mejor is None or d > mejor[0]:
                mejor = (d, signo)
        hueso.rotation_quaternion = q0
        signos[lado] = mejor[1]

    for nombre, accion in acciones.items():
        for lado in ("Left", "Right"):
            hueso = pre + lado + "Arm"
            curvas = _curvas_rotacion(accion, hueso)
            if len(curvas) != 4:
                raise ValueError(f"{nombre}: {hueso} sin 4 canales de cuaternion")
            giro = rotacion(lado, signos[lado])
            n = len(curvas[0].keyframe_points)
            for i in range(n):
                q = Quaternion([curvas[k].keyframe_points[i].co[1] for k in range(4)])
                nuevo = giro @ q
                if nuevo.dot(q) < 0:
                    nuevo.negate()
                for k in range(4):
                    punto = curvas[k].keyframe_points[i]
                    punto.co[1] = nuevo[k]
                    punto.handle_left[1] = nuevo[k]
                    punto.handle_right[1] = nuevo[k]
            for k in range(4):
                curvas[k].update()

    solo("idle")
    bpy.context.scene.frame_set(0)
    despues = _x_manos(rig, pre)
    print("Manos (x) idle cuadro 0 despues:", {k: round(v, 4) for k, v in despues.items()})
    print("Signos de apertura:", signos)
    for p in pistas:
        p.mute = False


def main():
    destino, salida = sys.argv[sys.argv.index("--") + 1:]
    riggear(destino, salida, "DonaComba", TRONCO, EXTREMIDADES, (0.645, 0.675),
             ajustar_comba, {"atender_mostrador": "Bartending"}, animar=abrir_brazos)
    print(f"Regla de la falda: {tocados} vertices tocados")


if __name__ == "__main__":
    main()
