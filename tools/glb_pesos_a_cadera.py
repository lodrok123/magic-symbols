"""
Pasa el peso de una falda o capa larga de las piernas a la cadera/columna, tocando SOLO JOINTS_0 y WEIGHTS_0 de un GLB:

    python -I tools/glb_pesos_a_cadera.py <entrada.glb> <salida.glb> --preset moura_falda
    python -I tools/glb_pesos_a_cadera.py <entrada.glb> <salida.glb> --preset inquisidor_capa [--t 0.70]

Para qué (Pablo, 20/11, rigs de Meshy + Mixamo): el autorig pesa la parte baja de una falda larga o de una capa a las piernas, así que al andar la falda se abre
por detrás (cada mitad sigue su pierna), salen jirones en el bajo y la capa se levanta de lado como una bandera. Aquí los vértices de esa tela pasan a seguir la cadera
(y la columna más arriba): w_nuevo = mezcla(w_viejo, destino, t), con t creciente hacia abajo; después 3 pasadas de Laplaciano (0,5) sobre esos vértices y su 1-anillo,
renormalizado y con 4 influencias como máximo. No se re-exporta con Blender (recorta los clips y reordena las articulaciones): esqueleto, clips, índices, texturas y
posiciones quedan idénticos byte a byte; solo cambian los bytes de JOINTS_0 y WEIGHTS_0 (ubyte y float32, como los trae Meshy).

Presets (los números salen de medir cada rig en reposo; se imprimen las alturas de los huesos):
  moura_falda       t máximo 0,85 (el bajo conserva el 15 % del movimiento de la pierna). Vértices de color no marrón oscuro (piel, pelo, cuero y botas quedan fuera) entre
                    y = 0,10 y la cadera, fuera de las dos islas de las botas, con hueso dominante en cadera/columna/piernas/pies. t sube con suavizado de 0 en la altura de la
                    cadera a su máximo en la rodilla, y se multiplica por max(espalda, centro): espalda = suavizado((0,06 - z)/0,12), centro = 1 - suavizado(|x|/0,12). Así solo la
                    espalda y la franja central siguen a la cadera; los costados delanteros conservan el peso de las piernas (con la regla en toda la falda las botas atravesaban
                    la tela por delante y el borde del chaleco salía con dientes). El destino es Hips, que en los 5 cm bajo la altura de la cadera se mezcla con Spine (para que no haya escalón).
                    Úsalo DESPUÉS de glb_quitar_islas.py --preset moura_pendientes.
  inquisidor_capa   t máximo 0,70 (0,85 también cierra la raja, pero la capa queda más rígida; ver diario 20/11). Vértices ROJOS (matiz < 0,04 o > 0,95, saturación > 0,5,
                    valor > 0,2) detrás del cuerpo (z < -0,05) y bajo los omóplatos (y < altura de Spine2 - 4 cm), con hueso dominante en cadera/columna/piernas/pies o en el
                    hueso de capa Bone_022. El cuello de bufanda (Bone_030/031, Head, hombros), el emblema del pecho (delante) y los brazos quedan fuera. t sube con suavizado
                    de 0 bajo los omóplatos a su máximo en la cadera. El destino sigue la cadena de la columna por altura: Spine2 -> Spine1 -> Spine -> Hips.

Opciones: --t V cambia el t máximo del preset. Imprime las alturas de reposo de los huesos usados y cuántos vértices se tocaron.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glb_util import Glb, hsv_de, islas, color_de, suavizado


def preparar_moura(g: Glb, tmax: float) -> tuple:
    names = g.nombres_huesos()
    ID = {nm: i for i, nm in enumerate(names)}
    HIPS, SPINE = ID["Hips"], ID["Spine"]
    LOW = {ID[k] for k in ("Hips", "Spine", "Spine1", "LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg", "LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase")}
    pos, uv, J, W, img = g.posiciones(), g.uvs(), g.jointas(), g.pesos(), g.imagen_base()
    hip_y = g.reposo_hueso(HIPS)[1]
    rodilla = (g.reposo_hueso(ID["LeftLeg"])[1] + g.reposo_hueso(ID["RightLeg"])[1]) / 2
    print("alturas de reposo: cadera", round(hip_y, 3), "· rodilla", round(rodilla, 3), "· tobillo", round(g.reposo_hueso(ID["LeftFoot"])[1], 3))
    botas: set = set()
    for _, vs in islas(pos, g.indices()[4]).items():
        if len(vs) > 400 and max(pos[i][1] for i in vs) < 0.25:
            botas |= set(vs)
            print("isla de bota:", len(vs), "vértices, altura máxima", round(max(pos[i][1] for i in vs), 3))

    def oscuro(i: int) -> bool:
        h, s, v = hsv_de(color_de(img, uv[i]))
        return (h < 0.12 or h > 0.95) and v < 0.5

    def dom(i: int) -> int:
        return J[i][max(range(4), key=lambda a: W[i][a])]

    def candidato(i: int) -> bool:
        return 0.10 < pos[i][1] < hip_y and i not in botas and not oscuro(i) and dom(i) in LOW

    def mezcla(i: int) -> dict:
        y = pos[i][1]
        z = pos[i][2]
        x = pos[i][0]
        b = suavizado((0.06 - z) / 0.12)
        c = 1 - suavizado(abs(x) / 0.12)
        fct = max(b, c)
        t = tmax * suavizado((hip_y - y) / (hip_y - rodilla)) * fct
        s = max(0, min(1, 1 - (hip_y - y) / 0.05))
        w: dict = {}
        for jj, ww in zip(J[i], W[i]):
            if ww > 0:
                w[jj] = w.get(jj, 0) + ww * (1 - t)
        w[HIPS] = w.get(HIPS, 0) + t * (1 - s)
        w[SPINE] = w.get(SPINE, 0) + t * s
        return w

    def anillo_ok(r: int) -> bool:
        return r not in botas and pos[r][1] <= hip_y and not oscuro(r)
    return candidato, mezcla, anillo_ok


def preparar_inquisidor(g: Glb, tmax: float) -> tuple:
    names = g.nombres_huesos()
    ID = {nm: i for i, nm in enumerate(names)}
    pos, uv, J, W, img = g.posiciones(), g.uvs(), g.jointas(), g.pesos(), g.imagen_base()
    cadena = [(g.reposo_hueso(ID[k])[1], ID[k]) for k in ("Hips", "Spine", "Spine1", "Spine2")]
    print("alturas de reposo:", {k: round(g.reposo_hueso(ID[k])[1], 3) for k in ("Hips", "Spine", "Spine1", "Spine2", "Neck", "LeftUpLeg", "LeftLeg", "LeftFoot", "Bone_022")})
    y_top = cadena[3][0] - 0.04
    y_hip = cadena[0][0]
    PERMITIDOS = {ID[k] for k in ("Hips", "Spine", "Spine1", "Spine2", "LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg", "LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase", "Bone_022")}
    print("t = 0 en y", round(y_top, 3), "· t máximo", tmax, "en y", round(y_hip, 3))

    def destino(y: float) -> dict:
        if y <= cadena[0][0]:
            return {cadena[0][1]: 1.0}
        if y >= cadena[3][0]:
            return {cadena[3][1]: 1.0}
        for (y0, j0), (y1, j1) in zip(cadena, cadena[1:]):
            if y0 <= y <= y1:
                u = (y - y0) / (y1 - y0)
                return {j0: 1 - u, j1: u}
        return {}

    def rojo(i: int) -> bool:
        h, s, v = hsv_de(color_de(img, uv[i]))
        return (h < 0.04 or h > 0.95) and s > 0.5 and v > 0.2

    def dom(i: int) -> int:
        return J[i][max(range(4), key=lambda a: W[i][a])]

    def candidato(i: int) -> bool:
        p = pos[i]
        return p[2] < -0.05 and 0.05 < p[1] < y_top and dom(i) in PERMITIDOS and rojo(i)

    def mezcla(i: int) -> dict:
        y = pos[i][1]
        t = tmax * suavizado((y_top - y) / (y_top - y_hip))
        tg = destino(y)
        w: dict = {}
        for jj, ww in zip(J[i], W[i]):
            if ww > 0:
                w[jj] = w.get(jj, 0) + ww * (1 - t)
        for k, v in tg.items():
            w[k] = w.get(k, 0) + t * v
        return w

    def anillo_ok(r: int) -> bool:
        return pos[r][1] < y_top and rojo(r) and pos[r][2] < -0.05 and dom(r) in PERMITIDOS
    return candidato, mezcla, anillo_ok


PRESETS = {"moura_falda": (preparar_moura, 0.85), "inquisidor_capa": (preparar_inquisidor, 0.70)}


def main() -> int:
    from glb_util import reponderar
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description="Pasa a la cadera el peso de una falda o capa larga, editando solo JOINTS_0/WEIGHTS_0.")
    ap.add_argument("entrada")
    ap.add_argument("salida")
    ap.add_argument("--preset", choices=sorted(PRESETS), required=True)
    ap.add_argument("--t", type=float, help="t máximo (por defecto el del preset)")
    a = ap.parse_args()
    preparar, tmax = PRESETS[a.preset]
    if a.t is not None:
        tmax = a.t
    g = Glb(a.entrada)
    candidato, mezcla, anillo_ok = preparar(g, tmax)
    n, grupos, suavizados = reponderar(g, candidato, mezcla, anillo_ok)
    print("vértices tocados", n, "· grupos soldados", grupos, "· suavizados", suavizados)
    if n == 0:
        print("ERROR: ningún vértice cumple la regla; no se escribe nada")
        return 1
    g.guardar(a.salida)
    return 0


if __name__ == "__main__":
    sys.exit(main())
