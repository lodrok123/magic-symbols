"""Encaja el rig de Brambletooth y hornea la rutina de la mesa del pan."""

import sys
from math import cos, pi, sin
from pathlib import Path

from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from autorig_aprendices_sumicio import ARRIBA, FRENTE, cuerpo, hornear, mano, piernas  # noqa: E402
from autorig_tendera import riggear  # noqa: E402


TRONCO = {
    "Hips": (0, 0.013, 0.400),
    "Spine": (0, 0.021, 0.443),
    "Spine1": (0, 0.013, 0.496),
    "Spine2": (0, 0.008, 0.555),
    "Neck": (0, 0.024, 0.625),
    "Head": (0, 0.004, 0.668),
    "HeadTop_End": (0, 0.031, 0.923),
}
EXTREMIDADES = {
    "Shoulder": (0.041, 0.018, 0.598),
    "Arm": (0.101, 0.020, 0.586),
    "ForeArm": (0.187, 0.005, 0.516),
    "Hand": (0.251, -0.029, 0.435),
    "UpLeg": (0.064, 0.020, 0.380),
    "Leg": (0.089, -0.018, 0.238),
    "Foot": (0.117, 0.024, 0.082),
    "ToeBase": (0.127, -0.084, 0.024),
    "Toe_End": (0.126, -0.138, 0.014),
}
DURACION = 4


def amasar(h, t):
    fase = t * 4 * pi / DURACION
    avance = (1.0 - cos(fase)) / 2.0
    recuperar = max(0.0, -sin(fase)) * 0.026
    cuerpo(h, -0.009 - 0.014 * avance, -0.015 * avance, 0.18 + 0.17 * avance, 0.20)
    piernas(h, False)
    for lado, signo in (("Left", 1), ("Right", -1)):
        x = signo * (0.075 + 0.016 * avance) + 0.010 * sin(fase)
        destino = Vector((x, -0.207 - 0.086 * avance, 0.505 + recuperar - 0.014 * avance))
        mano(h, lado, destino, FRENTE - ARRIBA * 0.39, 0.09 + 0.20 * (1 - avance))


def animar(rig, prefijo):
    hornear(rig, prefijo, "amasar", DURACION, amasar)


if __name__ == "__main__":
    entrada, salida = sys.argv[sys.argv.index("--") + 1:]
    riggear(entrada, salida, "IriaSumicio", TRONCO, EXTREMIDADES, (0.621, 0.655), None,
            clips_mixamo={}, animar=animar, clips_base=("hablar",))
