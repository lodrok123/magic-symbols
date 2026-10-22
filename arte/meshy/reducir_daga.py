#!/usr/bin/env python3
"""Reduce la daga del goblin asesino (Tripo, 124 568 triángulos) a una pieza de equipo lista para colgar de una mano.

Usa el mismo reductor por cuádricas que `recibir_assets.py` (conserva la textura: recalcula los UV de cada esquina) y deja la pieza
como pide `jugador/equipo_3d.gd`: el centro de la empuñadura en el origen, la hoja hacia +Y, el filo curvo hacia -X y el grosor en Z.

Uso:  python reducir_daga.py entrada.glb salida.glb [triangulos=3000] [largo=0.5]
  largo = longitud total de la pieza (m del modelo) tras escalar; la daga viene con 0,98.
"""
import sys
from pathlib import Path

import numpy as np

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
from recibir_assets import Hoja, Reductor, malla_soldada, normales_y_vertices, recortar_textura, escribir_pieza  # noqa: E402

# Dónde cae el centro de la empuñadura, en fracción del largo medido desde la punta (hoja ≈ 53 %, empuñadura y pomo el resto).
AGARRE_DESDE_PUNTA = 0.75


def main(entrada, salida, tris=3000, largo=0.5):
    h = Hoja(entrada)
    caras = np.arange(len(h.F))
    Pw, Fw, UVc = malla_soldada(h, caras)
    print(f"origen: {len(Fw):,} triángulos, {len(Pw):,} vértices soldados")
    r = Reductor(Pw, Fw, UVc)
    r.reducir_a(tris)
    P, F, UV = r.resultado()
    # Orientación: la daga viene tumbada, con la punta hacia -X y el pomo hacia +X (el filo curvo, hacia -Y).
    # Se gira para que la punta mire a +Y (x' = y, y' = -x) y el filo quede hacia -X.
    x0 = P[:, 0].min()
    x1 = P[:, 0].max()
    agarre_x = x0 + (x1 - x0) * AGARRE_DESDE_PUNTA
    # El eje de la empuñadura (y, z) se mide en los vértices que rodean al agarre: ahí va el origen.
    cerca = np.abs(P[:, 0] - agarre_x) < (x1 - x0) * 0.08
    yc = float(np.median(P[cerca, 1]))
    zc = float(np.median(P[cerca, 2]))
    Q = np.empty_like(P)
    Q[:, 0] = P[:, 1] - yc
    Q[:, 1] = -(P[:, 0] - agarre_x)
    Q[:, 2] = P[:, 2] - zc
    # El giro es de 90° alrededor de Z (sin espejo): el orden de las caras no cambia.
    k = largo / (x1 - x0)
    Q *= k
    pos, nor, uv, idx = normales_y_vertices(Q, F, UV)
    base, normal, uv2 = recortar_textura(h, uv)
    n = escribir_pieza(Path(salida), "daga_goblin", pos, nor, uv2, idx, base, normal, centrar=False)
    print(f"{salida}: {n:,} triángulos; caja {pos.min(0)} .. {pos.max(0)}")


if __name__ == "__main__":
    a = sys.argv
    main(a[1], a[2], int(a[3]) if len(a) > 3 else 3000, float(a[4]) if len(a) > 4 else 0.5)
