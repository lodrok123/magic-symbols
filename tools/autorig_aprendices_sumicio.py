"""Hornea la recolección de Wanderer o la escritura sentada de Mira para Godot.

blender -b --python tools/autorig_aprendices_sumicio.py -- wanderer|mira entrada.glb salida.glb
"""

import sys
from math import cos, pi, sin
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from autorig_tendera import mezclar, rampa, riggear  # noqa: E402


TRONCO = {
    "Hips": (0, 0.012, 0.321),
    "Spine": (0, 0.012, 0.364),
    "Spine1": (0, 0.016, 0.407),
    "Spine2": (0, 0.014, 0.467),
    "Neck": (0, 0.006, 0.553),
    "Head": (0, -0.015, 0.600),
    "HeadTop_End": (0, 0.012, 0.854),
}
EXTREMIDADES = {
    "Shoulder": (0.044, 0.011, 0.511),
    "Arm": (0.094, 0.008, 0.507),
    "ForeArm": (0.166, -0.000, 0.436),
    "Hand": (0.228, -0.049, 0.365),
    "UpLeg": (0.060, 0.012, 0.304),
    "Leg": (0.086, -0.022, 0.173),
    "Foot": (0.111, 0.032, 0.064),
    "ToeBase": (0.114, -0.067, 0.028),
    "Toe_End": (0.115, -0.121, 0.016),
}
EXTREMIDADES_MIRA = {
    **EXTREMIDADES,
    "Arm": (0.098, 0.011, 0.493),
    "ForeArm": (0.169, -0.007, 0.438),
    "Hand": (0.228, -0.046, 0.377),
    "UpLeg": (0.068, 0.013, 0.317),
    "Leg": (0.105, 0.002, 0.156),
    "Foot": (0.117, 0.025, 0.065),
    "ToeBase": (0.121, -0.054, 0.027),
}
EJE_X = Vector((1, 0, 0))
FRENTE = Vector((0, -1, 0))
ARRIBA = Vector((0, 0, 1))
IDENTIDAD = Quaternion()


def ajustar_ropa(p, color, pesos, pre):
    # La falda se cose a pelvis y muslos; el libro sujeto al cinturón sigue la cadera.
    r, g, b = color
    if 0.168 < p.z < 0.393 and abs(p.x) < 0.183:
        pierna = rampa(0.361 - p.z, 0.0, 0.148) * 0.94
        lado = rampa(p.x, -0.037, 0.037)
        ropa = {pre + "Hips": 1 - pierna, pre + "LeftUpLeg": lado * pierna,
                pre + "RightUpLeg": (1 - lado) * pierna}
        falda = rampa(p.z, 0.168, 0.191) * (1 - rampa(p.z, 0.359, 0.393))
        if p.x > 0.058 and p.y < -0.037 and r > b * 1.17 and p.z > 0.277:
            ropa = {pre + "Hips": 1.0}
        return mezclar(pesos, ropa, falda)
    return pesos


def orientar(hueso, rotacion_mundo):
    marco = hueso.bone.matrix_local.to_quaternion()
    if hueso.parent:
        padre = hueso.parent
        marco = padre.matrix.to_quaternion() @ padre.bone.matrix_local.to_quaternion().inverted() @ marco
    hueso.rotation_quaternion = marco.inverted() @ rotacion_mundo
    bpy.context.view_layer.update()


def apuntar(hueso, hijo, destino):
    actual = hijo.head - hueso.head
    nueva = destino - hueso.head
    rotacion = actual.rotation_difference(nueva) @ hueso.matrix.to_quaternion()
    orientar(hueso, rotacion)


def extremidad(inicio, medio, final, destino, polo):
    origen = inicio.head.copy()
    a = (medio.bone.head_local - inicio.bone.head_local).length
    b = (final.bone.head_local - medio.bone.head_local).length
    direccion = (destino - origen).normalized()
    distancia = min(a + b - 0.001, max(abs(a - b) + 0.001, (destino - origen).length))
    avance = (a * a + distancia * distancia - b * b) / (2 * distancia)
    lateral = (polo - direccion * polo.dot(direccion)).normalized()
    articulacion = origen + direccion * avance + lateral * (a * a - avance * avance) ** 0.5
    apuntar(inicio, medio, articulacion)
    apuntar(medio, final, origen + direccion * distancia)


def mano(h, lado, posicion, actividad, flexion):
    brazo, codo, palma = (h[lado + parte] for parte in ("Arm", "ForeArm", "Hand"))
    signo = 1.0 if lado == "Left" else -1.0
    polo = Vector((signo * 0.83, 0.12, -0.75))
    extremidad(brazo, codo, palma, posicion, polo)
    dedo = h[lado + "HandMiddle1"]
    apuntar(palma, dedo, palma.head + actividad)
    for tipo in ("Index", "Middle", "Ring", "Pinky"):
        for falange in (1, 2):
            d = h[f"{lado}Hand{tipo}{falange}"]
            eje = d.bone.matrix_local.to_quaternion().inverted() @ Vector((signo, 0.2, 0.0))
            d.rotation_quaternion = Quaternion(eje, flexion * (0.82 if tipo == "Index" else 1.0))


def piernas(h, sentado):
    for lado in ("Left", "Right"):
        muslo, rodilla, pie = (h[lado + parte] for parte in ("UpLeg", "Leg", "Foot"))
        punto = pie.bone.head_local.copy()
        if sentado:
            punto.y -= 0.176 if lado == "Right" else 0.200
        extremidad(muslo, rodilla, pie, punto, FRENTE)
        orientar(pie, pie.bone.matrix_local.to_quaternion())


def cuerpo(h, altura, atraso, inclinacion, mirada):
    cadera = h["Hips"]
    cadera.location = cadera.bone.matrix_local.to_3x3().inverted() @ Vector((0, atraso, altura))
    bpy.context.view_layer.update()
    for nombre, grados in (("Spine", inclinacion * 0.70), ("Spine2", inclinacion * 0.30),
                           ("Head", mirada)):
        h[nombre].rotation_quaternion = Quaternion(
            h[nombre].bone.matrix_local.to_quaternion().inverted() @ EJE_X, grados)
    bpy.context.view_layer.update()


def recolectar(h, t):
    bajar = rampa(t, 0.7, 2.05) * (1 - rampa(t, 3.8, 5.15))
    alcanzar = rampa(t, 1.70, 2.39) * (1 - rampa(t, 3.05, 3.88))
    coger = rampa(t, 2.40, 2.70) * (1 - rampa(t, 4.4, 5.1))
    respiracion = sin(t * 2 * pi / 6.5) * 0.003 * (1 - bajar)
    cuerpo(h, -0.157 * bajar + respiracion, 0.052 * bajar, 0.90 * bajar, -0.22 * bajar)
    piernas(h, False)
    derecha = Vector((-0.135, -0.022, 0.273)).lerp(Vector((-0.102, -0.242, 0.069)), alcanzar)
    derecha -= ARRIBA * 0.043 * bajar * (1 - alcanzar)
    izquierda = Vector((0.136, -0.020, 0.280)).lerp(Vector((0.120, -0.135, 0.203)), bajar)
    mano(h, "Right", derecha, (-ARRIBA).lerp(FRENTE * 0.65 - ARRIBA * 0.4, alcanzar), 0.1 + 0.55 * coger)
    mano(h, "Left", izquierda, (-ARRIBA).lerp(FRENTE, bajar), 0.13)


def escribir(h, t):
    fase = t * 2 * pi / (106 / 24)
    pausa = rampa(cos(fase), 0.46, 0.88)
    cuerpo(h, -0.073, 0.012, 0.20 - 0.08 * pausa, 0.24 - 0.15 * pausa)
    piernas(h, True)
    linea = sin(fase) * 0.031
    trazo = sin(fase * 6.0) * 0.009 * (1 - pausa)
    derecha = Vector((-0.109 + linea, -0.237 + trazo, 0.522 + 0.025 * pausa))
    izquierda = Vector((0.092, -0.222, 0.505))
    mano(h, "Right", derecha, Vector((0.24, -0.92, -0.30)), 0.55)
    mano(h, "Left", izquierda, FRENTE - ARRIBA * 0.28, 0.12)


def hornear(rig, prefijo, nombre, segundos, pose):
    datos = rig.animation_data_create()
    datos.use_nla = False
    accion = bpy.data.actions.new(nombre)
    datos.action = accion
    huesos = {b.name.removeprefix(prefijo): b for b in rig.pose.bones}
    anteriores = {}
    ultimo = round(segundos * 24)
    for cuadro in range(0, ultimo + 1, 2):
        bpy.context.scene.frame_set(cuadro)
        for hueso in huesos.values():
            hueso.rotation_mode = "QUATERNION"
            hueso.rotation_quaternion = IDENTIDAD
        pose(huesos, min(segundos, cuadro / 24))
        for hueso in huesos.values():
            q = hueso.rotation_quaternion.copy()
            if hueso.name in anteriores and q.dot(anteriores[hueso.name]) < 0:
                q.negate()
                hueso.rotation_quaternion = q
            anteriores[hueso.name] = q
            hueso.keyframe_insert(data_path="rotation_quaternion", frame=cuadro, group=hueso.name)
        huesos["Hips"].keyframe_insert(data_path="location", frame=cuadro, group=huesos["Hips"].name)
    datos.action = None
    pista = datos.nla_tracks.new()
    pista.name = nombre
    pista.strips.new(nombre, 0, accion)
    datos.use_nla = True


def animar_wanderer(rig, prefijo):
    hornear(rig, prefijo, "recolectar", 6.5, recolectar)


def animar_mira(rig, prefijo):
    hornear(rig, prefijo, "escribir", 106 / 24, escribir)


if __name__ == "__main__":
    variante, entrada, salida = sys.argv[sys.argv.index("--") + 1:]
    if variante == "mira":
        riggear(entrada, salida, "MiraMossfang", TRONCO, EXTREMIDADES_MIRA, (0.542, 0.579),
                ajustar_ropa, animar=animar_mira)
    elif variante == "wanderer":
        riggear(entrada, salida, "GoblinWanderer", TRONCO, EXTREMIDADES, (0.556, 0.580),
                None, animar=animar_wanderer)
    else:
        raise ValueError(f"Variante desconocida: {variante}")
