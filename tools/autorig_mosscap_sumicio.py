"""Adapta los clips de goblin_base a la aprendiz Mosscap."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from autorig_aprendices_sumicio import EXTREMIDADES, TRONCO  # noqa: E402
from autorig_tendera import riggear  # noqa: E402


TRONCO_MOSSCAP = {
    **TRONCO,
    "Hips": (0, 0.023, 0.354),
    "Spine": (0, 0.021, 0.399),
    "Spine1": (0, 0.018, 0.453),
    "Spine2": (0, 0.019, 0.506),
    "Neck": (0, 0.025, 0.584),
    "Head": (0, -0.001, 0.619),
}
EXTREMIDADES_MOSSCAP = {
    **EXTREMIDADES,
    "Shoulder": (0.043, 0.017, 0.550),
    "Arm": (0.102, 0.013, 0.526),
    "ForeArm": (0.179, -0.008, 0.441),
    "Hand": (0.236, -0.045, 0.382),
    "UpLeg": (0.064, 0.019, 0.329),
    "Leg": (0.084, -0.022, 0.181),
    "Foot": (0.117, 0.024, 0.069),
    "ToeBase": (0.123, -0.075, 0.026),
}


if __name__ == "__main__":
    entrada, salida = sys.argv[sys.argv.index("--") + 1:]
    riggear(entrada, salida, "MosscapSumicio", TRONCO_MOSSCAP, EXTREMIDADES_MOSSCAP,
            (0.581, 0.615), None)
