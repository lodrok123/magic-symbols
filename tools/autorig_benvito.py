"""Rig y clips de Benvito Brisaboa, el guardabosques goblin del puesto del bosque (Meshy, capucha y coroza de paja).

blender -b --python tools/autorig_benvito.py -- modelo_meshy.glb salida.glb
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from autorig_tendera import mezclar, rampa, riggear  # noqa: E402


# Articulaciones en metros medidas sobre la malla de Benvito, con pies en z=0.
TRONCO = {
    "Hips": (0, -0.025, 0.360),
    "Spine": (0, -0.030, 0.400),
    "Spine1": (0, -0.035, 0.450),
    "Spine2": (0, -0.040, 0.500),
    "Neck": (0, -0.045, 0.570),
    "Head": (0, -0.045, 0.615),
    "HeadTop_End": (0, -0.040, 0.950),
}
EXTREMIDADES = {
    "Shoulder": (0.035, -0.035, 0.525),
    "Arm": (0.100, -0.030, 0.505),
    "ForeArm": (0.170, -0.040, 0.425),
    "Hand": (0.215, -0.055, 0.375),
    "UpLeg": (0.070, -0.025, 0.325),
    "Leg": (0.075, -0.025, 0.215),
    "Foot": (0.075, -0.020, 0.065),
    "ToeBase": (0.075, -0.090, 0.020),
    "Toe_End": (0.075, -0.135, 0.015),
}

# Cuantos vertices toca cada regla (se imprime al final).
tocados = {"coroza": 0, "bolsa": 0}


def es_paja(color):
    # Paja naranja-tostada (r~0.74, g~0.51, b~0.22). La piel tiene g ~ r; la tunica verde, g >= r;
    # pantalon, botas y bolsa son marrones oscuros (r < 0.5).
    r, g, b = color
    return r > 0.55 and r > 1.2 * g and g > b + 0.15


def es_cuero(color):
    # Marron oscuro del cinturon, la bolsa, el pantalon y las botas: r bien sobre g y sin brillo.
    r, g, b = color
    return 0.25 < r < 0.55 and r > 1.25 * g and g > b


def ajustar_benvito(p, color, w, pre):
    # a) La coroza (tira de paja que cuelga a la espalda) sigue a la pelvis y a la columna, no a cada pierna,
    #    para que no se parta entre las piernas al caminar. Se funde con la capa de los hombros hacia z 0.50.
    if p.z < 0.50 and p.y > 0.0 and es_paja(color):
        s = rampa(p.z, 0.42, 0.48)
        t = 0.9 * (1 - rampa(p.z, 0.46, 0.50))
        if t > 0:
            tocados["coroza"] += 1
            return mezclar(w, {pre + "Hips": 1 - s, pre + "Spine": s}, t)
    # b) La bolsa de cuero de la cadera izquierda va rigida a la pelvis, para que el muslo no la deforme.
    if 0.02 < p.x < 0.12 and 0.32 < p.z < 0.43 and p.y < -0.04 and es_cuero(color):
        tocados["bolsa"] += 1
        return {pre + "Hips": 1.0}
    # c) La piel (manos), el pantalon y las botas conservan sus pesos.
    return w


def main():
    destino, salida = sys.argv[sys.argv.index("--") + 1:]
    riggear(destino, salida, "Benvito", TRONCO, EXTREMIDADES, (0.585, 0.625),
            ajustar_benvito, {"atender_mostrador": "Bartending"})
    print(f"Coroza: {tocados['coroza']} vertices; bolsa: {tocados['bolsa']} vertices")


if __name__ == "__main__":
    main()
