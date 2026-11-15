"""Adapta los dos reposos al rig de Grumbletwig y Forest Witch."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from autorig_aprendices_sumicio import EXTREMIDADES, EXTREMIDADES_MIRA, TRONCO  # noqa: E402
from autorig_tendera import mezclar, rampa, riggear  # noqa: E402


GRUMBLETWIG = {
    **EXTREMIDADES,
    "Arm": (0.104, 0.010, 0.535),
    "ForeArm": (0.174, -0.008, 0.431),
    "Hand": (0.230, -0.025, 0.371),
    "Leg": (0.085, -0.001, 0.154),
    "Foot": (0.110, 0.025, 0.061),
}
FOREST_WITCH = {
    **EXTREMIDADES_MIRA,
    "Arm": (0.096, 0.016, 0.525),
    "ForeArm": (0.175, -0.007, 0.435),
    "Hand": (0.228, -0.029, 0.385),
}


def ajustar_trenzas(p, color, pesos, prefijo):
    r, g, b = color
    if p.y > 0.015 and 0.052 < abs(p.x) < 0.155 and r > 1.10 * g and r > 1.20 * b:
        pelo = rampa(p.z, 0.503, 0.562)
        return mezclar(pesos, {prefijo + "Head": 1.0}, pelo)
    return pesos


if __name__ == "__main__":
    variante, entrada, salida = sys.argv[sys.argv.index("--") + 1:]
    variantes = {
        "grumbletwig": ("Grumbletwig", GRUMBLETWIG, None),
        "forest_witch": ("ForestWitch", FOREST_WITCH, ajustar_trenzas),
    }
    nombre, extremidades, ajustar_pesos = variantes[variante]
    riggear(entrada, salida, nombre, TRONCO, extremidades, (0.553, 0.585),
            ajustar_pesos, {"idle_mixamo": "Idle"}, clips_base=("idle",))
