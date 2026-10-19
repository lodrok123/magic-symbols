#!/usr/bin/env python3
"""RECEPCIÓN AUTOMÁTICA DE OBJETOS 3D (Pipeline, 19/10). De una lámina de Meshy/Tripo a piezas listas para el juego.

POR QUÉ. Las láminas nuevas traen 1–2,6 millones de triángulos en UN solo mesh con 10–20 objetos juntos. Antes había que partirlas
(separar_lamina / agrupar_3d), reducirlas a mano y renombrarlas. Este script hace todo el camino y deja a Pablo mirar antes de que
nada pise lo que ya hay (misma regla que recortar_assets.py: «nada llega a su sitio final sin que Pablo lo haya visto»; la única
excepción es lo que Pablo ordena sustituir directamente con --directo, y aun así la pieza vieja queda en piezas/_anteriores/).

CÓMO SE USA (necesita numpy, scipy y Pillow: como los demás .py de meshy, se ejecuta en el entorno de Claude con los archivos de
`arte/meshy/entrada/`; en el chat basta «hay nuevos»):

  python recibir_assets.py ver   entrada/hoja.glb                    inventario + hoja de contacto numerada + hoja.piezas.json
  python recibir_assets.py lote  entrada/hoja.glb [--tris 6000]      reduce cada pieza con nombre (en hoja.piezas.json) y deja el LOTE
                                  [--escalera 2500,6000,12000,24000]  en aprobacion3d/<hoja>/ con la escalera de calidad
  python recibir_assets.py instalar <hoja> [--solo id,id]            copia a meshy/piezas/<id>.glb las APROBADAS (o las que tengan
                                  "directo": true en el json) y guarda la vieja en piezas/_anteriores/

`hoja.piezas.json`: {"pieza": {"trozos": [0], "id": "roca_grande", "tris": 6000, "directo": true, "nota": ""}, ...}. `ver` lo
crea con los trozos detectados y el id vacío (no se procesa lo que no tenga id); se rellena mirando `hoja_ver.png`.

QUÉ HACE CON CADA PIEZA (todo con numpy, sin librerías de malla):
  1. Trozos = partes conectadas de la malla (vértices soldados por posición). Un trozo casi metido en otro (≥ 80 % de su caja dentro)
     se une solo a él (hojas sueltas de un árbol).
  2. Reducción por colapso de aristas con cuádricas (Garland-Heckbert) sobre la malla SOLDADA por posición: así las costuras de UV no
     se rompen ni fijan el mínimo (el decimador de Godot no baja de ~63 k triángulos por eso). Cada esquina de cada cara guarda su UV
     y, al mover un vértice, la recalcula con el mapa afín de su propia cara: la textura no se estira. Los bordes abiertos (hojas, telas)
     pesan más para que no se encojan; no se permiten colapsos que den la vuelta a una cara ni que dejen la malla no variedad.
  3. Normales nuevas con ángulo de pliegue de 55° (el relieve fino ya viene en el mapa de normales de la textura).
  4. La textura se RECORTA a la caja de UV de la pieza (una lámina de 2048 con 20 piezas pesaría 20 × 4 MB); se quita el mapa de
     metal/rugosidad y se pone metal 0 (como separar_lamina: Meshy lo deja en 1 y sin reflejos se ve negro).
  5. Pieza centrada en el centro de su base (x, z) y con la base en y = 0; nodo raíz llamado como su id (lo que busca Pieza3D).
"""
from __future__ import annotations

import argparse
import heapq
import io
import json
import math
import shutil
import struct
import sys
import time
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
from separar_lamina import accesor, leer_glb, matriz_nodo  # noqa: E402

ESCALERA = [2500, 6000, 12000, 24000]
# Decisión de Pablo: 8000 triángulos por defecto y 12000 para árboles y objetos grandes (por debajo se pierde mucho detalle).
TRIS_POR_DEFECTO = 8000
TRIS_GRANDES = 12000   # ponlo a mano en `tris` de la pieza en <hoja>.piezas.json (árboles, arcos, troncos grandes, tótems)
CARPETA_LOTES = AQUI / "aprobacion3d"          # borradores (con .gdignore): Godot no los importa
PIEZAS = AQUI / "piezas"
ANGULO_PLIEGUE = 55.0


# ================================================================================================================ lectura
class Hoja:
    """Una lámina entera, en espacio de mundo: P (n,3), N (n,3), UV (n,2), F (m,3) y las dos texturas."""

    def __init__(self, ruta: Path):
        self.ruta = Path(ruta)
        j, b = leer_glb(self.ruta)
        self.j = j
        prims = []

        def recorrer(ni, padre):
            n = j["nodes"][ni]
            m = padre @ matriz_nodo(n)
            if "mesh" in n:
                for p in j["meshes"][n["mesh"]]["primitives"]:
                    prims.append((p, m))
            for h in n.get("children", []):
                recorrer(h, m)

        for ni in j["scenes"][j.get("scene", 0)]["nodes"]:
            recorrer(ni, np.eye(4))
        Ps, Ns, Us, Fs, base = [], [], [], [], 0
        for p, m in prims:
            pos = accesor(j, b, p["attributes"]["POSITION"]).astype(np.float64)
            Ps.append((np.c_[pos, np.ones(len(pos))] @ m.T)[:, :3])
            if "NORMAL" in p["attributes"]:
                nor = accesor(j, b, p["attributes"]["NORMAL"]).astype(np.float64)
                Ns.append(nor @ m[:3, :3].T)
            else:
                Ns.append(np.zeros_like(pos))
            Us.append(accesor(j, b, p["attributes"]["TEXCOORD_0"]).astype(np.float64) if "TEXCOORD_0" in p["attributes"] else np.zeros((len(pos), 2)))
            idx = accesor(j, b, p["indices"]).reshape(-1, 3).astype(np.int64) if "indices" in p else np.arange(len(pos)).reshape(-1, 3)
            Fs.append(idx + base)
            base += len(pos)
        self.P, self.N, self.UV, self.F = np.vstack(Ps), np.vstack(Ns), np.vstack(Us), np.vstack(Fs)
        mats = {p.get("material", 0) for p, _ in prims}
        self.aviso = "" if len(mats) <= 1 else f"{len(mats)} materiales: se usa el del primero"
        mat = j["materials"][prims[0][0].get("material", 0)] if j.get("materials") else {}
        pbr = mat.get("pbrMetallicRoughness", {})
        self.base = self._textura(j, b, pbr.get("baseColorTexture"))
        self.normal = self._textura(j, b, mat.get("normalTexture"))
        self.color_factor = pbr.get("baseColorFactor", [1, 1, 1, 1])

    @staticmethod
    def _textura(j, b, ref):
        if not ref:
            return None
        try:
            bv = j["bufferViews"][j["images"][j["textures"][ref["index"]]["source"]]["bufferView"]]
        except (KeyError, IndexError):
            return None
        o = bv.get("byteOffset", 0)
        return Image.open(io.BytesIO(b[o:o + bv["byteLength"]])).convert("RGB")


# ================================================================================================================ trozos
def trozos_de(h: Hoja):
    """Partes conectadas (vértices soldados por posición). Devuelve (etiqueta por cara, lista de dicts con tris/lo/hi)."""
    _, w = np.unique(np.round(h.P * 1e5).astype(np.int64), axis=0, return_inverse=True)
    w = w.reshape(-1)
    t = w[h.F]
    nv = int(w.max()) + 1
    g = coo_matrix((np.ones(len(t) * 3), (np.r_[t[:, 0], t[:, 1], t[:, 2]], np.r_[t[:, 1], t[:, 2], t[:, 0]])), shape=(nv, nv))
    _, comp = connected_components(g, directed=False)
    por_cara = comp[t[:, 0]]
    trozos = []
    for c in np.unique(por_cara):
        caras = np.where(por_cara == c)[0]
        pts = h.P[h.F[caras].reshape(-1)]
        trozos.append({"caras": caras, "lo": pts.min(0), "hi": pts.max(0)})
    trozos.sort(key=lambda z: -len(z["caras"]))
    # un trozo ≥ 80 % dentro de la caja de otro mayor se une a él (hojas flotando dentro de la copa, tapas...)
    union = list(range(len(trozos)))
    for i in range(len(trozos) - 1, 0, -1):
        a = trozos[i]
        va = float(np.prod(np.maximum(a["hi"] - a["lo"], 1e-9)))
        for k in range(i):
            b = trozos[k]
            inter = np.maximum(np.minimum(a["hi"], b["hi"]) - np.maximum(a["lo"], b["lo"]), 0.0)
            if float(np.prod(inter)) >= 0.8 * va:
                union[i] = union[k]
                break
    grupos: dict[int, list[int]] = {}
    for i in range(len(trozos)):
        r = i
        while union[r] != r:
            r = union[r]
        grupos.setdefault(r, []).append(i)
    res = []
    for r, miembros in sorted(grupos.items()):
        caras = np.concatenate([trozos[i]["caras"] for i in miembros])
        pts = h.P[h.F[caras].reshape(-1)]
        res.append({"caras": caras, "lo": pts.min(0), "hi": pts.max(0), "origen": miembros})
    res.sort(key=lambda z: (-round(float(z["lo"][2] + z["hi"][2]) / 2 / 0.5), float(z["lo"][0])))   # filas de atrás a delante, de izquierda a derecha
    return res


def unir(trozos, indices):
    caras = np.concatenate([trozos[i]["caras"] for i in indices])
    return caras


# ================================================================================================================ dibujo (hoja de contacto)
def dibujar_pieza(h: Hoja, caras, lado=220, az=35.0, el=25.0, muestras=300000):
    """Vista de la pieza con puntos sobre los centros de las caras (z-buffer), con el color de la textura y una luz simple."""
    f = h.F[caras]
    # Puntos repartidos por la SUPERFICIE (peso = área), no solo en el centro de cada cara: con pocas caras grandes
    # los centros dejaban huecos que parecían agujeros en la malla y no lo eran.
    a0, a1, a2 = h.P[f[:, 0]], h.P[f[:, 1]], h.P[f[:, 2]]
    cr = np.cross(a1 - a0, a2 - a0)
    area = np.linalg.norm(cr, axis=1)
    rng = np.random.default_rng(1)
    s = rng.choice(len(f), muestras, p=area / area.sum())
    r1, r2 = np.sqrt(rng.random(muestras)), rng.random(muestras)
    w0, w1, w2 = (1 - r1)[:, None], (r1 * (1 - r2))[:, None], (r1 * r2)[:, None]
    c = a0[s] * w0 + a1[s] * w1 + a2[s] * w2
    n = cr[s] / np.maximum(area[s, None], 1e-12)
    uv = h.UV[f[s, 0]] * w0 + h.UV[f[s, 1]] * w1 + h.UV[f[s, 2]] * w2
    if h.base is not None:
        t = np.asarray(h.base)
        col = t[np.clip((uv[:, 1] * t.shape[0]).astype(int) % t.shape[0], 0, t.shape[0] - 1), np.clip((uv[:, 0] * t.shape[1]).astype(int) % t.shape[1], 0, t.shape[1] - 1)].astype(float)
    else:
        col = np.full((len(c), 3), 170.0)
    a, e = math.radians(az), math.radians(el)
    ry = np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])
    rx = np.array([[1, 0, 0], [0, math.cos(e), -math.sin(e)], [0, math.sin(e), math.cos(e)]])
    R = rx @ ry
    q = c @ R.T
    nq = n @ R.T
    nq *= np.where(nq[:, 2:3] < 0, -1.0, 1.0)            # las caras miran a la cámara (hojas de dos caras)
    luz = np.array([-0.4, 0.7, 0.6])
    luz /= np.linalg.norm(luz)
    sh = np.clip(nq @ luz, 0.0, 1.0) * 0.55 + 0.55
    col = np.clip(col * sh[:, None], 0, 255)
    # Se dibuja al doble de tamaño con z-buffer real (gana el punto más cercano en cada píxel) y se reduce después:
    # así los huecos entre puntos se rellenan y los bordes salen suaves.
    L = lado * 2
    lo, hi = q[:, :2].min(0), q[:, :2].max(0)
    esc = (L - 24) / max(float((hi - lo).max()), 1e-9)
    px0 = (q[:, 0] - lo[0]) * esc + 12 + (L - 24 - (hi[0] - lo[0]) * esc) / 2
    py0 = L - 12 - (q[:, 1] - lo[1]) * esc - (L - 24 - (hi[1] - lo[1]) * esc) / 2
    img = np.full((L * L, 3), 52.0)
    zb = np.full(L * L, -1e18)
    for dx in (0, 1, 2):
        for dy in (0, 1, 2):
            xx = np.clip((px0 + dx - 1).astype(int), 0, L - 1)
            yy = np.clip((py0 + dy - 1).astype(int), 0, L - 1)
            k = yy * L + xx
            np.maximum.at(zb, k, q[:, 2])
    for dx in (0, 1, 2):
        for dy in (0, 1, 2):
            xx = np.clip((px0 + dx - 1).astype(int), 0, L - 1)
            yy = np.clip((py0 + dy - 1).astype(int), 0, L - 1)
            k = yy * L + xx
            gana = q[:, 2] >= zb[k] - 1e-6
            img[k[gana]] = col[gana]
    img = Image.fromarray(img.reshape(L, L, 3).astype(np.uint8)).resize((lado, lado), Image.LANCZOS)
    return img


def hoja_contacto(imagenes, rotulos, ruta, cols=5, lado=220):
    filas = (len(imagenes) + cols - 1) // cols
    hoja = Image.new("RGB", (cols * lado, filas * (lado + 18)), (30, 30, 36))
    d = ImageDraw.Draw(hoja)
    for i, (im, r) in enumerate(zip(imagenes, rotulos)):
        x, y = (i % cols) * lado, (i // cols) * (lado + 18)
        hoja.paste(im, (x, y))
        d.text((x + 4, y + lado + 3), r, fill=(255, 235, 120))
    hoja.save(ruta)


# ================================================================================================================ reducción
class Reductor:
    """Colapso de aristas con cuádricas sobre la malla soldada por posición, con UV por esquina de cara."""

    def __init__(self, P, F, UVc, borde=3.0):
        # P (k,3) soldadas, F (m,3) ids soldados, UVc (m,3,2) UV de cada esquina
        ok = (F[:, 0] != F[:, 1]) & (F[:, 1] != F[:, 2]) & (F[:, 0] != F[:, 2])
        F, UVc = F[ok], UVc[ok]
        self.pos = [tuple(p) for p in P.tolist()]
        self.k = len(self.pos)
        self.fv = F.tolist()
        self.fuv = [[tuple(c) for c in cara] for cara in UVc.tolist()]
        self.vivo_f = [True] * len(self.fv)
        self.n_vivas = len(self.fv)
        self.vf = [set() for _ in range(self.k)]
        for fi, (a, b, c) in enumerate(self.fv):
            self.vf[a].add(fi)
            self.vf[b].add(fi)
            self.vf[c].add(fi)
        self.vivo_v = [bool(s) for s in self.vf]
        self.ver = [0] * self.k
        self.Q = self._cuadricas(P, F, borde)
        self.cuenta = 0
        self.heap: list = []
        self._llenar()

    # ---- cuádricas: 10 números por vértice (a11 a12 a13 a14 a22 a23 a24 a33 a34 a44)
    def _cuadricas(self, P, F, borde):
        p0, p1, p2 = P[F[:, 0]], P[F[:, 1]], P[F[:, 2]]
        cr = np.cross(p1 - p0, p2 - p0)
        area2 = np.linalg.norm(cr, axis=1)
        n = cr / np.maximum(area2[:, None], 1e-30)
        d = -np.einsum("ij,ij->i", n, p0)
        w = area2 * 0.5
        a, b, c = n[:, 0], n[:, 1], n[:, 2]
        K = np.stack([a * a, a * b, a * c, a * d, b * b, b * c, b * d, c * c, c * d, d * d], axis=1) * w[:, None]
        Q = np.zeros((len(P), 10))
        for k in range(3):
            np.add.at(Q, F[:, k], K)
        # bordes abiertos: una arista que solo tiene una cara → plano perpendicular a la cara que pasa por la arista
        e = np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]])
        cara_de = np.tile(np.arange(len(F)), 3)
        clave = np.sort(e, axis=1)
        _, inv, cnt = np.unique(clave, axis=0, return_inverse=True, return_counts=True)
        inv = inv.reshape(-1)
        solo = cnt[inv] == 1
        for (u, v), fi in zip(e[solo], cara_de[solo]):
            ev = P[v] - P[u]
            ln = float(np.linalg.norm(ev))
            if ln < 1e-12:
                continue
            nb = np.cross(ev / ln, n[fi])
            nn = float(np.linalg.norm(nb))
            if nn < 1e-12:
                continue
            nb /= nn
            db = -float(nb @ P[u])
            kk = borde * ln * ln * np.array([nb[0] ** 2, nb[0] * nb[1], nb[0] * nb[2], nb[0] * db, nb[1] ** 2, nb[1] * nb[2], nb[1] * db, nb[2] ** 2, nb[2] * db, db * db])
            Q[u] += kk
            Q[v] += kk
        return [tuple(q) for q in Q.tolist()]

    @staticmethod
    def _error(q, p):
        x, y, z = p
        return (q[0] * x * x + 2 * q[1] * x * y + 2 * q[2] * x * z + 2 * q[3] * x + q[4] * y * y + 2 * q[5] * y * z + 2 * q[6] * y
                + q[7] * z * z + 2 * q[8] * z + q[9])

    def _mejor(self, a, b):
        """(coste, posición) de colapsar a y b: la mejor entre a, b, el punto medio y el óptimo si cae cerca."""
        qa, qb = self.Q[a], self.Q[b]
        q = tuple(x + y for x, y in zip(qa, qb))
        pa, pb = self.pos[a], self.pos[b]
        mid = ((pa[0] + pb[0]) * 0.5, (pa[1] + pb[1]) * 0.5, (pa[2] + pb[2]) * 0.5)
        mejor_c, mejor_p = None, None
        cands = [pa, pb, mid]
        det = (q[0] * (q[4] * q[7] - q[5] * q[5]) - q[1] * (q[1] * q[7] - q[5] * q[2]) + q[2] * (q[1] * q[5] - q[4] * q[2]))
        if abs(det) > 1e-18:
            # resolver A p = -b con la regla de Cramer
            bx, by, bz = -q[3], -q[6], -q[8]
            dx = (bx * (q[4] * q[7] - q[5] * q[5]) - q[1] * (by * q[7] - q[5] * bz) + q[2] * (by * q[5] - q[4] * bz)) / det
            dy = (q[0] * (by * q[7] - q[5] * bz) - bx * (q[1] * q[7] - q[5] * q[2]) + q[2] * (q[1] * bz - by * q[2])) / det
            dz = (q[0] * (q[4] * bz - by * q[5]) - q[1] * (q[1] * bz - by * q[2]) + bx * (q[1] * q[5] - q[4] * q[2])) / det
            ln = math.dist(pa, pb)
            if math.dist((dx, dy, dz), mid) <= 0.75 * ln:
                cands.append((dx, dy, dz))
        for p in cands:
            c = self._error(q, p)
            if mejor_c is None or c < mejor_c:
                mejor_c, mejor_p = c, p
        return max(mejor_c, 0.0), mejor_p

    def _llenar(self):
        vistas = set()
        for a, b, c in self.fv:
            for u, v in ((a, b), (b, c), (c, a)):
                kk = (u, v) if u < v else (v, u)
                if kk in vistas:
                    continue
                vistas.add(kk)
                cst, _ = self._mejor(kk[0], kk[1])
                self.heap.append((cst, self.cuenta, kk[0], kk[1], 0, 0))
                self.cuenta += 1
        heapq.heapify(self.heap)

    # ---- geometría local
    @staticmethod
    def _normal(p0, p1, p2):
        ux, uy, uz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
        vx, vy, vz = p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2]
        return (uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx)

    def _uv_nuevo(self, fi, esquina, p_nuevo):
        """UV de la esquina `esquina` de la cara `fi` si pasa a estar en p_nuevo: mapa afín de la propia cara (con λ acotado)."""
        v = self.fv[fi]
        i, j, k = esquina, (esquina + 1) % 3, (esquina + 2) % 3
        pi, pj, pk = self.pos[v[i]], self.pos[v[j]], self.pos[v[k]]
        e1 = (pj[0] - pi[0], pj[1] - pi[1], pj[2] - pi[2])
        e2 = (pk[0] - pi[0], pk[1] - pi[1], pk[2] - pi[2])
        d = (p_nuevo[0] - pi[0], p_nuevo[1] - pi[1], p_nuevo[2] - pi[2])
        g11 = e1[0] * e1[0] + e1[1] * e1[1] + e1[2] * e1[2]
        g12 = e1[0] * e2[0] + e1[1] * e2[1] + e1[2] * e2[2]
        g22 = e2[0] * e2[0] + e2[1] * e2[1] + e2[2] * e2[2]
        det = g11 * g22 - g12 * g12
        ui, uj, uk = self.fuv[fi][i], self.fuv[fi][j], self.fuv[fi][k]
        if det <= 1e-24:
            return ui
        r1 = e1[0] * d[0] + e1[1] * d[1] + e1[2] * d[2]
        r2 = e2[0] * d[0] + e2[1] * d[1] + e2[2] * d[2]
        l1 = min(max((r1 * g22 - r2 * g12) / det, -0.5), 1.5)
        l2 = min(max((r2 * g11 - r1 * g12) / det, -0.5), 1.5)
        return (ui[0] + l1 * (uj[0] - ui[0]) + l2 * (uk[0] - ui[0]), ui[1] + l1 * (uj[1] - ui[1]) + l2 * (uk[1] - ui[1]))

    def _legal(self, a, b, p):
        fa, fb = self.vf[a], self.vf[b]
        comunes = fa & fb
        na = {x for f in fa for x in self.fv[f]}
        nb = {x for f in fb for x in self.fv[f]}
        if len((na & nb) - {a, b}) > len(comunes):
            return False                                                 # dejaría la malla no variedad
        for f in fa | fb:
            if f in comunes:
                continue
            v = self.fv[f]
            viejo = self._normal(self.pos[v[0]], self.pos[v[1]], self.pos[v[2]])
            nuevo_p = [p if x in (a, b) else self.pos[x] for x in v]
            nuevo = self._normal(*nuevo_p)
            lo = math.sqrt(viejo[0] ** 2 + viejo[1] ** 2 + viejo[2] ** 2)
            ln = math.sqrt(nuevo[0] ** 2 + nuevo[1] ** 2 + nuevo[2] ** 2)
            if lo < 1e-20:
                continue
            if ln < 1e-20 or (viejo[0] * nuevo[0] + viejo[1] * nuevo[1] + viejo[2] * nuevo[2]) / (lo * ln) < 0.25:
                return False
        return True

    def reducir_a(self, objetivo: int):
        while self.n_vivas > objetivo and self.heap:
            cst, _, a, b, va, vb = heapq.heappop(self.heap)
            if not (self.vivo_v[a] and self.vivo_v[b]) or va != self.ver[a] or vb != self.ver[b]:
                continue
            c2, p = self._mejor(a, b)
            if not self._legal(a, b, p):
                continue
            self._colapsar(a, b, p)

    def _colapsar(self, a, b, p):
        comunes = self.vf[a] & self.vf[b]
        # 1) UV nuevos con las posiciones viejas
        cambios = []
        for f in self.vf[a] - comunes:
            cambios.append((f, self.fv[f].index(a), self._uv_nuevo(f, self.fv[f].index(a), p)))
        for f in self.vf[b] - comunes:
            cambios.append((f, self.fv[f].index(b), self._uv_nuevo(f, self.fv[f].index(b), p)))
        # 2) aplicar
        self.pos[b] = p
        self.Q[b] = tuple(x + y for x, y in zip(self.Q[a], self.Q[b]))
        for f in comunes:
            self.vivo_f[f] = False
            self.n_vivas -= 1
            for x in self.fv[f]:
                self.vf[x].discard(f)
        for f in list(self.vf[a]):
            i = self.fv[f].index(a)
            self.fv[f][i] = b
            self.vf[b].add(f)
        self.vf[a] = set()
        self.vivo_v[a] = False
        for f, i, uv in cambios:
            if self.vivo_f[f]:
                self.fuv[f][i] = uv
        self.ver[b] += 1
        # 3) aristas alrededor de b
        vecinos = {x for f in self.vf[b] for x in self.fv[f]} - {b}
        for n in vecinos:
            cst, _ = self._mejor(b, n)
            kk = (b, n) if b < n else (n, b)
            heapq.heappush(self.heap, (cst, self.cuenta, kk[0], kk[1], self.ver[kk[0]], self.ver[kk[1]]))
            self.cuenta += 1

    # ---- salida: arrays compactos con normales de ángulo de pliegue
    def resultado(self):
        vivas = [i for i, v in enumerate(self.vivo_f) if v]
        F = np.array([self.fv[i] for i in vivas], dtype=np.int64)
        UV = np.array([self.fuv[i] for i in vivas], dtype=np.float64)
        P = np.array(self.pos, dtype=np.float64)
        return P, F, UV


def malla_soldada(h: Hoja, caras):
    """(P soldados, F con ids soldados, UV por esquina) de un grupo de caras."""
    f = h.F[caras]
    p = h.P[f.reshape(-1)]
    _, w = np.unique(np.round(p * 1e5).astype(np.int64), axis=0, return_inverse=True)
    w = w.reshape(-1)
    k = int(w.max()) + 1
    Pw = np.zeros((k, 3))
    Pw[w] = p
    return Pw, w.reshape(-1, 3), h.UV[f.reshape(-1)].reshape(-1, 3, 2)


def normales_y_vertices(P, F, UV, pliegue=ANGULO_PLIEGUE):
    """Construye vértices de salida: uno por (id soldado, grupo de suavizado, UV). Devuelve pos, nor, uv, índices."""
    p0, p1, p2 = P[F[:, 0]], P[F[:, 1]], P[F[:, 2]]
    cr = np.cross(p1 - p0, p2 - p0)
    ar = np.linalg.norm(cr, axis=1)
    ok = ar > 1e-14
    F, UV, cr, ar = F[ok], UV[ok], cr[ok], ar[ok]
    nf = cr / ar[:, None]
    por_v: dict[int, list[int]] = {}
    for fi, tri in enumerate(F.tolist()):
        for x in tri:
            por_v.setdefault(x, []).append(fi)
    cos_p = math.cos(math.radians(pliegue))
    pos_o, nor_o, uv_o, idx_o, mapa = [], [], [], [], {}
    for fi, tri in enumerate(F.tolist()):
        for ci, x in enumerate(tri):
            vec = por_v[x]
            ns = nf[vec]
            sel = (ns @ nf[fi]) > cos_p
            n = (cr[vec][sel]).sum(axis=0)
            ln = float(np.linalg.norm(n))
            n = n / ln if ln > 1e-18 else nf[fi]
            uv = UV[fi, ci]
            clave = (x, round(float(n[0]), 2), round(float(n[1]), 2), round(float(n[2]), 2), round(float(uv[0]), 5), round(float(uv[1]), 5))
            i = mapa.get(clave)
            if i is None:
                i = len(pos_o)
                mapa[clave] = i
                pos_o.append(P[x])
                nor_o.append(n)
                uv_o.append(uv)
            idx_o.append(i)
    return np.array(pos_o), np.array(nor_o), np.array(uv_o), np.array(idx_o, dtype=np.int64).reshape(-1, 3)


# ================================================================================================================ GLB de salida
def _jpeg(im: Image.Image, calidad=90) -> bytes:
    b = io.BytesIO()
    im.save(b, "JPEG", quality=calidad)
    return b.getvalue()


def recortar_textura(h: Hoja, uv: np.ndarray, margen=3):
    """Recorta base y normal a la caja de UV de la pieza y devuelve (base, normal, uv remapeados)."""
    if h.base is None or uv.size == 0:
        return h.base, h.normal, uv
    w, hh = h.base.size
    if uv.min() < -0.001 or uv.max() > 1.001:                       # UV que repiten: no se toca
        return h.base, h.normal, uv
    x0 = max(int(math.floor(uv[:, 0].min() * w)) - margen, 0)
    x1 = min(int(math.ceil(uv[:, 0].max() * w)) + margen, w)
    y0 = max(int(math.floor(uv[:, 1].min() * hh)) - margen, 0)
    y1 = min(int(math.ceil(uv[:, 1].max() * hh)) + margen, hh)
    if x1 - x0 < 16 or y1 - y0 < 16:
        return h.base, h.normal, uv
    caja = (x0, y0, x1, y1)
    nuevo = np.empty_like(uv)
    nuevo[:, 0] = (uv[:, 0] * w - x0) / (x1 - x0)
    nuevo[:, 1] = (uv[:, 1] * hh - y0) / (y1 - y0)
    base = h.base.crop(caja)
    normal = h.normal.crop(caja) if h.normal is not None and h.normal.size == h.base.size else None
    return base, normal, nuevo


def escribir_pieza(ruta: Path, ident: str, P, N, UV, F, base, normal, centrar=True):
    # centrada en el centro de su base, base en y = 0 (con centrar=False se respetan las posiciones de la lámina)
    lo, hi = P.min(0), P.max(0)
    if centrar:
        P = P - np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    pos = P.astype(np.float32)
    nor = N.astype(np.float32)
    uv = UV.astype(np.float32)
    idx = F.reshape(-1)
    tipo_i = np.uint16 if int(idx.max()) < 65535 else np.uint32
    idx = idx.astype(tipo_i)
    trozos = []
    vistas = []

    def añadir(data: bytes, target=None):
        pad = (4 - len(data) % 4) % 4
        o = sum(len(x) for x in trozos)
        trozos.append(data + b"\0" * pad)
        v = {"buffer": 0, "byteOffset": o, "byteLength": len(data)}
        if target:
            v["target"] = target
        vistas.append(v)
        return len(vistas) - 1

    j = {"asset": {"version": "2.0", "generator": "recibir_assets.py"}, "scene": 0, "scenes": [{"nodes": [0]}],
         "nodes": [{"name": ident, "children": [1]}, {"name": ident + "_malla", "mesh": 0}],
         "meshes": [{"name": ident, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "material": 0}]}],
         "accessors": [], "bufferViews": vistas, "materials": [{"name": ident, "doubleSided": True,
                                                                "pbrMetallicRoughness": {"metallicFactor": 0.0, "roughnessFactor": 0.85}}]}
    for arr, tipo, comp in ((pos, "VEC3", 5126), (nor, "VEC3", 5126), (uv, "VEC2", 5126)):
        bv = añadir(arr.tobytes(), 34962)
        a = {"bufferView": bv, "componentType": comp, "count": len(arr), "type": tipo}
        if arr is pos:
            a["min"], a["max"] = pos.min(0).tolist(), pos.max(0).tolist()
        j["accessors"].append(a)
    bv = añadir(idx.tobytes(), 34963)
    j["accessors"].append({"bufferView": bv, "componentType": 5123 if tipo_i == np.uint16 else 5125, "count": int(len(idx)), "type": "SCALAR"})
    imagenes, texturas = [], []
    pbr = j["materials"][0]["pbrMetallicRoughness"]
    if base is not None:
        imagenes.append({"bufferView": añadir(_jpeg(base)), "mimeType": "image/jpeg"})
        texturas.append({"source": len(imagenes) - 1})
        pbr["baseColorTexture"] = {"index": len(texturas) - 1}
    if normal is not None:
        imagenes.append({"bufferView": añadir(_jpeg(normal)), "mimeType": "image/jpeg"})
        texturas.append({"source": len(imagenes) - 1})
        j["materials"][0]["normalTexture"] = {"index": len(texturas) - 1}
    if imagenes:
        j["images"], j["textures"] = imagenes, texturas
    binario = b"".join(trozos)
    j["buffers"] = [{"byteLength": len(binario)}]
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(binario)
    ruta.write_bytes(struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js
                     + struct.pack("<II", len(binario), 0x004E4942) + binario)
    return int(len(F))


# ================================================================================================================ órdenes
def ruta_json(glb: Path) -> Path:
    return glb.with_suffix("").with_name(glb.stem + ".piezas.json")


def nombre_lote(glb: Path) -> str:
    s = "".join(c if c.isalnum() else "_" for c in glb.stem.lower()).strip("_")
    return s.replace("_3d_model", "")[:40]


def cmd_ver(args):
    glb = Path(args.glb)
    t = time.time()
    h = Hoja(glb)
    print(f"{glb.name}: {len(h.F):,} triángulos, {len(h.P):,} vértices, textura base {h.base.size if h.base else '-'}"
          f"{', normal ' + str(h.normal.size) if h.normal else ''}  ({time.time() - t:.1f} s)")
    if h.aviso:
        print("  AVISO:", h.aviso)
    trozos = trozos_de(h)
    imgs, rots, datos = [], [], {}
    for i, z in enumerate(trozos):
        tam = z["hi"] - z["lo"]
        imgs.append(dibujar_pieza(h, z["caras"]))
        rots.append(f"#{i} {len(z['caras']) // 1000}k  {tam[0]:.2f}x{tam[1]:.2f}x{tam[2]:.2f}")
        datos[f"p{i}"] = {"trozos": [i], "id": "", "tris": TRIS_POR_DEFECTO, "directo": False, "nota": ""}
        print(f"  #{i}: {len(z['caras']):>8,} tris  caja {tam[0]:.2f} x {tam[1]:.2f} x {tam[2]:.2f}  en ({(z['lo'][0] + z['hi'][0]) / 2:+.2f}, {(z['lo'][2] + z['hi'][2]) / 2:+.2f})")
    salida = glb.with_name(glb.stem + "_ver.png")
    hoja_contacto(imgs, rots, salida)
    print(f"  hoja de contacto: {salida}")
    rj = ruta_json(glb)
    if rj.exists():
        print(f"  (ya existe {rj.name}: no se sobrescribe)")
    else:
        rj.write_text(json.dumps(datos, indent=1, ensure_ascii=False), encoding="utf-8")
        print(f"  piezas detectadas en {rj.name}: pon el `id` de cada una (las que no lo tengan no se procesan)")
    return 0


def cmd_lote(args):
    glb = Path(args.glb)
    escalera = sorted(int(x) for x in args.escalera.split(","))
    rj = ruta_json(glb)
    if not rj.exists():
        print(f"Falta {rj.name}: ejecuta primero `ver`.")
        return 1
    piezas = json.loads(rj.read_text(encoding="utf-8"))
    h = Hoja(glb)
    trozos = trozos_de(h)
    lote = CARPETA_LOTES / nombre_lote(glb)
    lote.mkdir(parents=True, exist_ok=True)
    (CARPETA_LOTES / ".gdignore").touch()
    estado_ruta = lote / "lote.json"
    estado = json.loads(estado_ruta.read_text(encoding="utf-8")) if estado_ruta.exists() else {}
    imgs, rots = [], []
    for clave, d in piezas.items():
        ident = d.get("id", "").strip()
        if not ident:
            continue
        if args.solo and ident not in args.solo.split(","):
            continue
        t = time.time()
        caras = unir(trozos, d["trozos"])
        Pw, Fw, UVc = malla_soldada(h, caras)
        objetivo = int(d.get("tris", TRIS_POR_DEFECTO))
        niveles = sorted({x for x in escalera if x < len(Fw)} | {objetivo})
        r = Reductor(Pw, Fw, UVc)
        print(f"{ident}: {len(Fw):,} tris de origen")
        info = {}
        for n in sorted(niveles, reverse=True):
            r.reducir_a(n)
            P, F, UV = r.resultado()
            pos, nor, uv, idx = normales_y_vertices(P, F, UV)
            base, normal, uv2 = recortar_textura(h, uv)
            nombre = f"{ident}.glb" if n == objetivo else f"{ident}_{n}.glb"
            tris = escribir_pieza(lote / nombre, ident, pos, nor, uv2, idx, base, normal)
            info[str(n)] = {"archivo": nombre, "tris": tris, "kb": (lote / nombre).stat().st_size // 1024}
            print(f"   -> {nombre}: {tris:,} tris, {info[str(n)]['kb']} KB")
            if n in (objetivo,):
                pass
        # vistas para la hoja de comparación: original + cada nivel
        imgs.append(dibujar_pieza(h, caras))
        rots.append(f"{ident} origen {len(Fw) // 1000}k")
        for n in sorted(niveles, reverse=True):
            im = _dibujar_glb(lote / info[str(n)]["archivo"])
            imgs.append(im)
            rots.append(f"{ident} {info[str(n)]['tris']} tris" + (" *" if n == objetivo else ""))
        prev = estado.get(ident, {})
        estado[ident] = {"estado": prev.get("estado", "pendiente"), "directo": bool(d.get("directo", False)), "objetivo": objetivo,
                         "niveles": info, "origen": glb.name, "nota": d.get("nota", ""), "seg": round(time.time() - t, 1)}
    estado_ruta.write_text(json.dumps(estado, indent=1, ensure_ascii=False), encoding="utf-8")
    if imgs:
        cols = max(len(escalera) + 1, 3)
        hoja_contacto(imgs, rots, lote / "escalera.png", cols=min(cols, 6), lado=200)
        print(f"hoja de comparación: {lote / 'escalera.png'}")
    return 0


def _dibujar_glb(ruta: Path, lado=200):
    h = Hoja(ruta)
    return dibujar_pieza(h, np.arange(len(h.F)), lado=lado)


def cmd_hoja(args):
    """Rehace escalera.png de un lote ya reducido (sin volver a reducir)."""
    lote = CARPETA_LOTES / args.lote
    estado = json.loads((lote / "lote.json").read_text(encoding="utf-8"))
    imgs, rots = [], []
    for ident, e in estado.items():
        for n in sorted((int(k) for k in e["niveles"]), reverse=True):
            imgs.append(_dibujar_glb(lote / e["niveles"][str(n)]["archivo"]))
            rots.append(f"{ident} {e['niveles'][str(n)]['tris']}" + (" *" if n == e["objetivo"] else ""))
    hoja_contacto(imgs, rots, lote / "escalera.png", cols=5, lado=200)
    print(lote / "escalera.png")
    return 0


def cmd_retex(args):
    """Baja la textura de los .glb de un lote a `--max` px (las láminas de 2048 pesaban 2,5 MB por pieza)."""
    lote = CARPETA_LOTES / args.lote
    n = 0
    for ruta in sorted(lote.glob("*.glb")):
        h = Hoja(ruta)
        if h.base is None or max(h.base.size) <= args.max:
            continue
        r = args.max / max(h.base.size)
        tam = (int(h.base.size[0] * r), int(h.base.size[1] * r))
        base = h.base.resize(tam, Image.LANCZOS)
        normal = h.normal.resize(tam, Image.LANCZOS) if h.normal is not None else None
        escribir_pieza(ruta, _id_de(ruta), h.P, h.N, h.UV, h.F, base, normal)
        n += 1
    print(f"{n} .glb con textura reducida a {args.max}")
    return 0


def _id_de(ruta: Path) -> str:
    j, _ = leer_glb(ruta)
    return j["nodes"][j["scenes"][0]["nodes"][0]]["name"]


def cmd_lamina(args):
    """Lámina REAL reducida: un solo .glb con todas las piezas en su sitio, cada una a --tris triángulos. No toca nada más."""
    glb = Path(args.glb)
    h = Hoja(glb)
    trozos = trozos_de(h)
    Ps, Ns, Us, Is, base_i, total_ini = [], [], [], [], 0, len(h.F)
    for i, z in enumerate(trozos):
        t = time.time()
        Pw, Fw, UVc = malla_soldada(h, z["caras"])
        r = Reductor(Pw, Fw, UVc)
        r.reducir_a(args.tris)
        P, F, UV = r.resultado()
        pos, nor, uv, idx = normales_y_vertices(P, F, UV)
        Ps.append(pos); Ns.append(nor); Us.append(uv); Is.append(idx + base_i); base_i += len(pos)
        print(f"  pieza #{i}: {len(Fw):,} -> {len(idx):,} tris ({time.time() - t:.0f} s)")
    F = np.vstack(Is)
    salida = glb.with_name(f"{glb.stem}_{args.tris // 1000}k.glb")
    n = escribir_pieza(salida, glb.stem[:30], np.vstack(Ps), np.vstack(Ns), np.vstack(Us), F, h.base, h.normal, centrar=False)
    print(f"{salida.name}: {n:,} triángulos (de {total_ini:,}: -{100 - 100 * n / total_ini:.1f} %), {salida.stat().st_size // 1024} KB")
    return 0


def cmd_instalar(args):
    lote = CARPETA_LOTES / args.lote
    ruta = lote / "lote.json"
    if not ruta.exists():
        print(f"No existe {ruta}")
        return 1
    estado = json.loads(ruta.read_text(encoding="utf-8"))
    sello = datetime.now().strftime("%Y%m%d_%H%M%S")
    solo = args.solo.split(",") if args.solo else None
    n = 0
    instaladas = []
    for ident, e in estado.items():
        if solo and ident not in solo:
            continue
        if not (e["estado"] == "aprobado" or e.get("directo")):
            print(f"  {ident}: {e['estado']} (no instalada: falta aprobación; usa marcar o directo)")
            continue
        origen = lote / e["niveles"][str(e["objetivo"])]["archivo"]
        PIEZAS.mkdir(exist_ok=True)
        destino = PIEZAS / f"{ident}.glb"
        if destino.exists():
            viejos = PIEZAS / "_anteriores"
            viejos.mkdir(exist_ok=True)
            (viejos / ".gdignore").touch()
            shutil.move(str(destino), str(viejos / f"{ident}_{sello}.glb"))
            print(f"  {ident}: la anterior queda en piezas/_anteriores/{ident}_{sello}.glb")
        shutil.copy2(origen, destino)
        e["estado"] = "procesado"
        n += 1
        instaladas.append(ident)
        print(f"  {ident}: -> meshy/piezas/{ident}.glb")
    ruta.write_text(json.dumps(estado, indent=1, ensure_ascii=False), encoding="utf-8")
    if instaladas:
        # Los niveles usan las escenas horneadas arte/piezas/<id>.tscn: GENERAR_ESCENAS_PIEZAS.cmd lee esta lista para re-hornearlas.
        (AQUI / "ULTIMAS_INSTALADAS.txt").write_text("\n".join(instaladas) + "\n", encoding="utf-8")
        print("Para que los niveles usen los modelos nuevos: GENERAR_ESCENAS_PIEZAS.cmd (re-hornea arte/piezas/<id>.tscn).")
    print(f"{n} instaladas.")
    return 0


def cmd_marcar(args):
    ruta = CARPETA_LOTES / args.lote / "lote.json"
    estado = json.loads(ruta.read_text(encoding="utf-8"))
    for ident in args.ids:
        if ident in estado:
            estado[ident]["estado"] = args.estado
    ruta.write_text(json.dumps(estado, indent=1, ensure_ascii=False), encoding="utf-8")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = ap.add_subparsers(dest="cmd", required=True)
    a = sp.add_parser("ver")
    a.add_argument("glb")
    a.set_defaults(f=cmd_ver)
    a = sp.add_parser("lote")
    a.add_argument("glb")
    a.add_argument("--escalera", default=",".join(map(str, ESCALERA)))
    a.add_argument("--solo", default="")
    a.set_defaults(f=cmd_lote)
    a = sp.add_parser("lamina")
    a.add_argument("glb")
    a.add_argument("--tris", type=int, default=12000)
    a.set_defaults(f=cmd_lamina)
    a = sp.add_parser("hoja")
    a.add_argument("lote")
    a.set_defaults(f=cmd_hoja)
    a = sp.add_parser("retex")
    a.add_argument("lote")
    a.add_argument("--max", type=int, default=1024)
    a.set_defaults(f=cmd_retex)
    a = sp.add_parser("instalar")
    a.add_argument("lote")
    a.add_argument("--solo", default="")
    a.set_defaults(f=cmd_instalar)
    a = sp.add_parser("marcar")
    a.add_argument("lote")
    a.add_argument("estado", choices=["pendiente", "aprobado", "rechazado"])
    a.add_argument("ids", nargs="+")
    a.set_defaults(f=cmd_marcar)
    args = ap.parse_args()
    return args.f(args)


if __name__ == "__main__":
    sys.exit(main())
