"""Rig y clips del anciano de Sumicio.

blender -b --python tools/autorig_anciano_sumicio.py -- modelo_meshy.glb salida.glb
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from autorig_tendera import riggear  # noqa: E402


# Articulaciones en metros sobre la malla de Elder Goblin Sage, con z=0 en los pies.
TRONCO = {
    "Hips": (0, 0.020, 0.420),
    "Spine": (0, 0.028, 0.463),
    "Spine1": (0, 0.023, 0.523),
    "Spine2": (0, 0.020, 0.582),
    "Neck": (0, 0.024, 0.663),
    "Head": (0, 0.007, 0.703),
    "HeadTop_End": (0, -0.009, 0.925),
}
EXTREMIDADES = {
    "Shoulder": (0.053, 0.021, 0.637),
    "Arm": (0.124, 0.025, 0.622),
    "ForeArm": (0.199, 0.024, 0.562),
    "Hand": (0.263, 0.003, 0.478),
    "UpLeg": (0.075, 0.018, 0.395),
    "Leg": (0.100, -0.022, 0.243),
    "Foot": (0.132, 0.024, 0.097),
    "ToeBase": (0.134, -0.075, 0.031),
    "Toe_End": (0.139, -0.142, 0.019),
}
CLIPS_MIXAMO = {"idle": "Old_Man_Idle", "walk": "Old_Man_Walk", "rezar": "Praying_2"}


if __name__ == "__main__":
    destino, salida = sys.argv[sys.argv.index("--") + 1:]
    riggear(destino, salida, "AncianoSumicio", TRONCO, EXTREMIDADES, (0.654, 0.686),
             None, CLIPS_MIXAMO)
