"""
Quita piezas sueltas (islas conectadas) de un GLB tocando SOLO sus índices de triángulos:

    python -I tools/glb_quitar_islas.py <entrada.glb> <salida.glb> --preset moura_pendientes
    python -I tools/glb_quitar_islas.py <entrada.glb> <salida.glb> [--min-verts N] [--max-verts N] [--excluir-verts A-B]
            [--x-abs-min V] [--x-min V] [--x-max V] [--y-min V] [--y-max V] [--z-min V] [--z-max V]

Para qué (Pablo, 20/11): Meshy dejó en la Moura viajera dos colgantes de pendiente flotando a la altura del hombro, desprendidos de los aros. Se borraron
sin re-exportar con Blender (que recorta los clips un fotograma y reordena las articulaciones): se calculan las piezas conectadas (soldando vértices en la misma
posición), se eligen por el centroide y el nº de vértices, y se descartan los triángulos que usan algún vértice de ellas. Los vértices, el skin, los clips y las
texturas quedan intactos; el accesor de índices solo encoge (los bytes sobrantes se ponen a 0).

Selección (todas las condiciones a la vez; los límites del centroide están en el espacio de la malla, Y arriba y el frente en +Z):
  --min-verts / --max-verts   nº de vértices de la pieza (vértices del GLB), mínimo y máximo, ambos incluidos
  --excluir-verts A-B         no quitar piezas con entre A y B vértices (p. ej. los aros que sí se quedan)
  --x-abs-min V               |x| del centroide mayor que V (simetría: una pieza a cada lado)
  --x-min --x-max --y-min --y-max --z-min --z-max   caja del centroide (límites estrictos)

Preset moura_pendientes: el colgante de cada pendiente de la Moura (2 piezas por lado: 30 y 96-102 vértices; el aro de la oreja, de 71-81, se queda):
  --min-verts 30 --max-verts 109 --excluir-verts 71-81 --x-abs-min 0.13 --y-min 1.23 --y-max 1.28 --z-min 0.1
Resultado verificado con el original de Meshy: 258 vértices y 355 triángulos menos (14976 -> 14621).

Se imprime cada pieza quitada. Si no se quita ninguna, termina con error y no escribe nada. Orden de uso en la Moura: primero este programa y después
glb_pesos_a_cadera.py --preset moura_falda sobre su salida.
"""
import argparse
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glb_util import Glb, islas

PRESETS = {
    "moura_pendientes": {"min_verts": 30, "max_verts": 109, "excluir_verts": (71, 81), "x_abs_min": 0.13, "y_min": 1.23, "y_max": 1.28, "z_min": 0.1},
}


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description="Quita islas de un GLB editando solo los índices.")
    ap.add_argument("entrada")
    ap.add_argument("salida")
    ap.add_argument("--preset", choices=sorted(PRESETS))
    ap.add_argument("--min-verts", type=int)
    ap.add_argument("--max-verts", type=int)
    ap.add_argument("--excluir-verts")
    for k in ("x-abs-min", "x-min", "x-max", "y-min", "y-max", "z-min", "z-max"):
        ap.add_argument("--" + k, type=float)
    a = ap.parse_args()
    c = dict(PRESETS.get(a.preset, {}))
    for k in ("min_verts", "max_verts", "x_abs_min", "x_min", "x_max", "y_min", "y_max", "z_min", "z_max"):
        if getattr(a, k) is not None:
            c[k] = getattr(a, k)
    if a.excluir_verts:
        lo, hi = a.excluir_verts.split("-")
        c["excluir_verts"] = (int(lo), int(hi))

    g = Glb(a.entrada)
    pos = g.posiciones()
    acc, fmt, sz, io_, idx = g.indices()
    quitar: set = set()
    for _, vs in islas(pos, idx).items():
        cen = [sum(pos[i][k] for i in vs) / len(vs) for k in range(3)]
        if len(vs) < c.get("min_verts", 0) or len(vs) > c.get("max_verts", 10 ** 9):
            continue
        if "excluir_verts" in c and c["excluir_verts"][0] <= len(vs) <= c["excluir_verts"][1]:
            continue
        if "x_abs_min" in c and not abs(cen[0]) > c["x_abs_min"]:
            continue
        if ("x_min" in c and not cen[0] > c["x_min"]) or ("x_max" in c and not cen[0] < c["x_max"]):
            continue
        if ("y_min" in c and not cen[1] > c["y_min"]) or ("y_max" in c and not cen[1] < c["y_max"]):
            continue
        if ("z_min" in c and not cen[2] > c["z_min"]) or ("z_max" in c and not cen[2] < c["z_max"]):
            continue
        print("quito isla de", len(vs), "vértices, centroide", [round(x, 3) for x in cen])
        quitar |= set(vs)
    if not quitar:
        print("ERROR: la selección no coincide con ninguna isla; no se escribe nada")
        return 1
    nuevo: list = []
    for t in range(0, len(idx), 3):
        tri = idx[t:t + 3]
        if not any(v in quitar for v in tri):
            nuevo += tri
    print("vértices quitados", len(quitar), "· triángulos", len(idx) // 3, "->", len(nuevo) // 3)
    struct.pack_into("<%d%s" % (len(nuevo), fmt), g.binc, io_, *nuevo)
    acc["count"] = len(nuevo)
    if "max" in acc:
        acc["max"] = [max(nuevo)]
        acc["min"] = [min(nuevo)]
    for k in range(io_ + len(nuevo) * sz, io_ + len(idx) * sz):
        g.binc[k] = 0
    g.guardar(a.salida, con_json=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
