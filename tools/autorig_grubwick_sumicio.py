"""Adapta el rig de goblin y hornea el gesto de trabajar en el telar."""

import sys
from math import cos, pi, sin
from pathlib import Path

from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from autorig_aprendices_sumicio import ARRIBA, FRENTE, cuerpo, hornear, mano, piernas  # noqa: E402
from autorig_iria_sumicio import EXTREMIDADES, TRONCO  # noqa: E402
from autorig_tendera import riggear  # noqa: E402


TRONCO_GRUBWICK = {
    **TRONCO,
    "Hips": (0, 0.024, 0.420),
    "Spine": (0, 0.023, 0.467),
    "Spine1": (0, 0.014, 0.523),
    "Spine2": (0, 0.018, 0.571),
    "Neck": (0, 0.031, 0.655),
    "Head": (0, 0.009, 0.686),
}
EXTREMIDADES_GRUBWICK = {
    **EXTREMIDADES,
    "Shoulder": (0.049, 0.023, 0.624),
    "Arm": (0.120, 0.021, 0.600),
    "ForeArm": (0.204, 0.005, 0.534),
    "Hand": (0.275, -0.034, 0.460),
    "UpLeg": (0.073, 0.023, 0.398),
    "Leg": (0.095, -0.015, 0.236),
    "Foot": (0.129, 0.026, 0.082),
}
DURACION = 4.5


def tejer(h, t):
    fase = 2 * pi * t / DURACION
    cruce = (1 - cos(fase)) / 2
    tensar = sin(fase) ** 2
    cuerpo(h, -0.008 - 0.010 * tensar, 0, 0.10 + 0.10 * cruce, 0.13 + 0.08 * tensar)
    piernas(h, False)
    derecha = Vector((-0.115 + 0.158 * cruce, -0.235 - 0.023 * tensar,
                      0.517 + 0.048 * tensar))
    izquierda = Vector((0.116 + 0.018 * sin(fase), -0.236 + 0.025 * cruce,
                        0.561 - 0.045 * cruce))
    mano(h, "Right", derecha, FRENTE + ARRIBA * 0.20, 0.36 + 0.16 * cruce)
    mano(h, "Left", izquierda, FRENTE - ARRIBA * 0.24, 0.20 + 0.24 * tensar)


def animar(rig, prefijo):
    hornear(rig, prefijo, "tejer", DURACION, tejer)


if __name__ == "__main__":
    entrada, salida = sys.argv[sys.argv.index("--") + 1:]
    riggear(entrada, salida, "GrubwickSumicio", TRONCO_GRUBWICK, EXTREMIDADES_GRUBWICK,
            (0.646, 0.680), None, animar=animar)
