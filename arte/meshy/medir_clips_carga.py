#!/usr/bin/env python3
"""Mide con cinemática directa (sin Godot ni Blender) los clips de arte/meshy/jugadora_carga_clips.glb (o el GLB de Meshy original): cadera, manos, cabeza y pies por instante, y los
instantes que el juego sincroniza (Pj3D.INSTANTE_CLIP): la suelta de LanzarObjeto y CogerLanzar (pico de velocidad de las manos), las manos abajo de Levantar y DejarObjeto y lo que avanza la cadera.
Unidades del GLB (la jugadora de pie mide 1,68 hasta HeadTop_End, +Z es delante).

Uso:  python medir_clips_carga.py jugadora_carga_clips.glb [paso_s]
"""
import sys

import numpy as np

import solo_clips


def acc(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    n = {"SCALAR": 1, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
    ini = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(b[ini:ini + a["count"] * n * 4], dtype="<f4").reshape(a["count"], n).copy()


def quat_mat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def slerp(a, c, f):
    if np.dot(a, c) < 0:
        c = -c
    r = a * (1 - f) + c * f
    return r / np.linalg.norm(r)


class Modelo:
    def __init__(self, ruta):
        self.j, self.b = solo_clips.leer(ruta)
        self.nodos = self.j["nodes"]
        self.padre = {h: i for i, n in enumerate(self.nodos) for h in n.get("children", [])}
        self.nombre = {n["name"]: i for i, n in enumerate(self.nodos)}
        self.anims = {}
        for an in self.j["animations"]:
            self.anims[an["name"]] = {(c["target"]["node"], c["target"]["path"]): (acc(self.j, self.b, an["samplers"][c["sampler"]]["input"])[:, 0],
                                                                                   acc(self.j, self.b, an["samplers"][c["sampler"]]["output"])) for c in an["channels"]}

    def local(self, i, clip, t):
        n = self.nodos[i]
        tr = np.array(n.get("translation", [0, 0, 0]), float)
        q = np.array(n.get("rotation", [0, 0, 0, 1]), float)
        sc = np.array(n.get("scale", [1, 1, 1]), float)
        for path in ("translation", "rotation", "scale"):
            if (i, path) in self.anims[clip]:
                ts, vs = self.anims[clip][(i, path)]
                k = int(np.clip(np.searchsorted(ts, t), 1, len(ts) - 1))
                f = float(np.clip((t - ts[k - 1]) / max(ts[k] - ts[k - 1], 1e-9), 0, 1))
                if path == "rotation":
                    q = slerp(vs[k - 1], vs[k], f)
                else:
                    v = vs[k - 1] * (1 - f) + vs[k] * f
                    tr, sc = (v, sc) if path == "translation" else (tr, v)
        M = np.eye(4)
        M[:3, :3] = quat_mat(q) * sc
        M[:3, 3] = tr
        return M

    def pos(self, hueso, clip, t):
        i = self.nombre["mixamorig:" + hueso]
        M = self.local(i, clip, t)
        while i in self.padre:
            i = self.padre[i]
            M = self.local(i, clip, t) @ M
        return M[:3, 3]


def main(ruta, paso):
    m = Modelo(ruta)
    for clip, ch in m.anims.items():
        largo = max(v[0][-1] for v in ch.values())
        print(f"\n== {clip} ({largo:.2f} s)")
        print("   t     cadera(x,y,z)         mano I (y,z)   mano D (y,z)   cabeza y   pies y I/D")
        t = 0.0
        puntos = []
        while t <= largo + 1e-6:
            h, li, ri = m.pos("Hips", clip, t), m.pos("LeftHand", clip, t), m.pos("RightHand", clip, t)
            hd, fl, fr = m.pos("HeadTop_End", clip, t), m.pos("LeftFoot", clip, t), m.pos("RightFoot", clip, t)
            puntos.append((t, (li + ri) / 2, ri, h))
            print(f"  {t:5.2f}  ({h[0]:+.2f},{h[1]:.2f},{h[2]:+.2f})  y{li[1]:.2f} z{li[2]:+.2f}  y{ri[1]:.2f} z{ri[2]:+.2f}   {hd[1]:.2f}    {fl[1]:.2f}/{fr[1]:.2f}")
            t += paso
        medias = np.array([p[1] for p in puntos])
        derechas = np.array([p[2] for p in puntos])
        print(f"  cadera avanza {puntos[-1][3][2] - puntos[0][3][2]:+.2f} en z; manos (media) y mínima {medias[:, 1].min():.2f} a {puntos[int(medias[:, 1].argmin())][0]:.2f} s; máxima {medias[:, 1].max():.2f}")
        if clip in ("LanzarObjeto", "CogerLanzar"):
            fino = np.arange(0.0, largo, 1 / 60)
            ref = medias if clip == "LanzarObjeto" else derechas
            pts = np.array([(m.pos("LeftHand", clip, x) + m.pos("RightHand", clip, x)) / 2 if clip == "LanzarObjeto" else m.pos("RightHand", clip, x) for x in fino])
            vel = np.linalg.norm(np.diff(pts, axis=0), axis=1) * 60
            i = int(vel.argmax())
            print(f"  SUELTA (pico de velocidad de las manos) a {fino[i]:.3f} s: {vel[i]:.1f} u/s")
        if clip == "CogerLanzar":
            fino = np.arange(0.0, largo, 1 / 60)
            ys = np.array([m.pos("RightHand", clip, x)[1] for x in fino])
            print(f"  AGARRE (mano derecha más baja) a {fino[int(ys.argmin())]:.3f} s, y {ys.min():.2f}")
        if clip in ("Levantar", "DejarObjeto"):
            fino = np.arange(0.0, largo, 1 / 60)
            ys = np.array([(m.pos("LeftHand", clip, x)[1] + m.pos("RightHand", clip, x)[1]) / 2 for x in fino])
            llega = fino[int(np.argmax(ys <= ys.min() + 0.02))]
            print(f"  MANOS ABAJO (primer instante a ≤ 2 cm de su mínimo {ys.min():.2f}) a {llega:.3f} s")


if __name__ == "__main__":
    main(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 0.25)
