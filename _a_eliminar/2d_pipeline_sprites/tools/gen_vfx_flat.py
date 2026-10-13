#!/usr/bin/env python3
"""
gen_vfx_flat.py — sprites de VFX en estilo "Link's Awakening": colores planos (3 tonos por pieza),
contorno oscuro grueso, formas simples y sin degradados ni brillos suaves.

Sustituye a las ilustraciones pintadas de poc_25d/vfx/ (mismos nombres y mismo tamaño 256x256, para que el
código no cambie) y crea las tiras de 8 fotogramas <nombre>_tira8.png que Vfx3D usa solo si existen.

Uso:  python tools/gen_vfx_flat.py <carpeta_de_salida>      (por defecto poc_25d/vfx)
No toca vfx/runas/ (salen de la lámina de runas).

Por qué así: la pegatina pintada tenía degradados y halo suave; sobre un mundo 3D con luz plana se leía como
una pegatina pegada encima. Aquí cada pieza se dibuja con la misma receta -> relleno + sombreado de dos tonos
+ contorno-, así que las 30 piezas parecen de la misma mano.
"""
import math
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw

SS = 1024            # lienzo de trabajo (se reduce a 256 al guardar: borde suave de 1 px)
OUT = 256
RC = 22              # grosor del contorno en el lienzo de trabajo (~5 px en 256)


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# ---------------------------------------------------------------- primitivas
def blank():
    return Image.new("L", (SS, SS), 0)


def poly(pts):
    m = blank()
    ImageDraw.Draw(m).polygon([(float(x), float(y)) for x, y in pts], fill=255)
    return m


def circle(cx, cy, r):
    m = blank()
    ImageDraw.Draw(m).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    return m


def ellipse(cx, cy, rx, ry, rot=0.0):
    pts = [(cx + rx * math.cos(a) * math.cos(rot) - ry * math.sin(a) * math.sin(rot),
            cy + rx * math.cos(a) * math.sin(rot) + ry * math.sin(a) * math.cos(rot))
           for a in np.linspace(0, 2 * math.pi, 72, endpoint=False)]
    return poly(pts)


def thick_line(pts, w, round_caps=True):
    m = blank()
    d = ImageDraw.Draw(m)
    d.line([(float(x), float(y)) for x, y in pts], fill=255, width=int(w), joint="curve")
    if round_caps:
        for x, y in (pts[0], pts[-1]):
            d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=255)
    return m


def union(*ms):
    a = np.zeros((SS, SS), np.uint8)
    for m in ms:
        a = np.maximum(a, np.array(m))
    return Image.fromarray(a)


def inter(a, b):
    return Image.fromarray(np.minimum(np.array(a), np.array(b)))


def minus(a, b):
    return Image.fromarray(np.where(np.array(b) > 127, 0, np.array(a)).astype(np.uint8))


def shift(m, dx, dy):
    a = np.roll(np.array(m), (int(dy), int(dx)), axis=(0, 1))
    return Image.fromarray(a)


def tinte_de(col, f):
    return tuple(int(max(0, min(255, c * f))) for c in col)


class Hoja:
    """Una pieza: capas de color planas + contorno."""

    def __init__(self):
        self.capas = []

    def add(self, mask, color):
        self.capas.append((mask, color))
        return mask

    def celda(self, mask, claro, medio, oscuro, d=34, luz=(-1, -1)):
        """Sombreado de 3 tonos: medio de base, luz arriba-izquierda, sombra abajo-derecha. d = ancho de banda."""
        self.add(mask, medio)
        dx, dy = luz[0] * d, luz[1] * d
        sombra = minus(mask, shift(mask, int(dx), int(dy)))     # lo que sobra al desplazar hacia la luz
        self.add(inter(sombra, mask), oscuro)
        brillo = minus(mask, shift(mask, int(-dx * 1.0), int(-dy * 1.0)))
        self.add(inter(brillo, mask), claro)
        return mask

    def render(self, contorno, r=RC, sin_contorno=False):
        todo = union(*[m for m, _ in self.capas])
        rgba = np.zeros((SS, SS, 4), np.uint8)
        if not sin_contorno:
            k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))
            borde = cv2.dilate(np.array(todo), k)
            rgba[borde > 127] = (*contorno, 255)
        for m, c in self.capas:
            a = np.array(m) > 127
            rgba[a] = (*c, 255)
        # alfa suave de 1 px al reducir: premultiplicar para no dejar halo oscuro/claro
        img = Image.fromarray(rgba, "RGBA")
        a = np.array(img).astype(np.float32)
        al = a[..., 3:4] / 255.0
        pre = a[..., :3] * al
        pre = cv2.resize(pre, (OUT, OUT), interpolation=cv2.INTER_AREA)
        al2 = cv2.resize(al[..., 0], (OUT, OUT), interpolation=cv2.INTER_AREA)[..., None]
        rgb = np.where(al2 > 1e-4, pre / np.maximum(al2, 1e-4), 0)
        out = np.concatenate([rgb, al2 * 255.0], axis=2)
        return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


# ---------------------------------------------------------------- paletas (cuerpo de ARTE.md §1 + 2 tonos)
FUEGO = dict(claro=hexc("FFD25A"), medio=hexc("FF8A24"), oscuro=hexc("E2461A"), nucleo=hexc("FFF1A8"), c=hexc("4A1608"))
AGUA = dict(claro=hexc("9ADBFF"), medio=hexc("3FA9F5"), oscuro=hexc("2370C8"), nucleo=hexc("EAF8FF"), c=hexc("0F2A5C"))
HIELO = dict(claro=hexc("F2FCFF"), medio=hexc("9FE4F7"), oscuro=hexc("5BB4DE"), nucleo=hexc("FFFFFF"), c=hexc("143C66"))
TIERRA = dict(claro=hexc("E9C28F"), medio=hexc("C8875A"), oscuro=hexc("94603C"), nucleo=hexc("F6E2B8"), c=hexc("3F2412"))
VIENTO = dict(claro=hexc("D6F5A8"), medio=hexc("8FD46A"), oscuro=hexc("4E9C4A"), nucleo=hexc("F2FFD8"), c=hexc("1C4A24"))
RAYO = dict(claro=hexc("FFF6B0"), medio=hexc("F7D238"), oscuro=hexc("E0A010"), nucleo=hexc("FFFFFF"), c=hexc("4A3206"))
HUMO = dict(claro=hexc("ECEAF2"), medio=hexc("C4C0D2"), oscuro=hexc("948FAE"), nucleo=hexc("FFFFFF"), c=hexc("38344F"))
POLVO = dict(claro=hexc("F6E6C0"), medio=hexc("E0C690"), oscuro=hexc("BC9C66"), nucleo=hexc("FFF6DA"), c=hexc("5A3E20"))
ROSA = dict(claro=hexc("FFD0E0"), medio=hexc("FF93B8"), oscuro=hexc("E0618F"), nucleo=hexc("FFFFFF"), c=hexc("5A1A38"))
PIEDRA = dict(claro=hexc("E8D6B4"), medio=hexc("C9AE86"), oscuro=hexc("98805C"), nucleo=hexc("F6EBD2"), c=hexc("3F2E1A"))


# ---------------------------------------------------------------- formas reutilizables
def perfil_llama(t):
    if t < 0.30:
        u = (0.30 - t) / 0.30
        return math.sqrt(max(0.0, 1 - u * u))
    return max(0.0, ((1 - t) / 0.70)) ** 0.9


def llama_poly(cx, by, h, w, sway=0.0, ph=0.0, n=44):
    L, R = [], []
    for i in range(n + 1):
        t = i / n
        hw = w * perfil_llama(t) * (1 + 0.10 * math.sin(7 * t + ph) * t)
        c = cx + sway * t ** 2 + 0.05 * w * math.sin(5 * t + ph * 1.3) * t
        y = by - h * t
        L.append((c - hw, y))
        R.append((c + hw, y))
    return L + R[::-1]


def llama(hoja, cx, by, h, w, sway=0.0, ph=0.0, pal=FUEGO):
    hoja.add(poly(llama_poly(cx, by, h, w, sway, ph)), pal["oscuro"])
    hoja.add(poly(llama_poly(cx, by - h * 0.02, h * 0.74, w * 0.72, sway * 0.7, ph + 0.6)), pal["medio"])
    hoja.add(poly(llama_poly(cx, by - h * 0.04, h * 0.44, w * 0.42, sway * 0.4, ph + 1.1)), pal["claro"])
    hoja.add(poly(llama_poly(cx, by - h * 0.05, h * 0.2, w * 0.2, 0, ph)), pal["nucleo"])


def facetada(hoja, pts, c_luz, pal, centro=None, luz=(-0.6, -0.8)):
    """Piedra o cristal a 3 tonos: triángulos desde un centro, tono según hacia dónde mira cada cara."""
    pts = [(float(x), float(y)) for x, y in pts]
    if centro is None:
        centro = (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))
    base = poly(pts)
    hoja.add(base, pal["medio"])
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        mx, my = (a[0] + b[0]) / 2 - centro[0], (a[1] + b[1]) / 2 - centro[1]
        ln = math.hypot(mx, my) or 1.0
        dot = (mx / ln) * luz[0] + (my / ln) * luz[1]
        col = pal["claro"] if dot > 0.35 else (pal["oscuro"] if dot < -0.35 else pal["medio"])
        if col is not pal["medio"]:
            hoja.add(inter(poly([a, b, centro]), base), col)
    return base


def piedra_pts(cx, cy, r, ph=0.0, n=8, ach=0.75):
    pts = []
    for i in range(n):
        a = ph + i * 2 * math.pi / n
        k = 0.82 + 0.18 * math.sin(i * 2.3 + ph * 3)
        pts.append((cx + math.cos(a) * r * k, cy + math.sin(a) * r * k * ach))
    return pts


def nube(hoja, circulos, pal):
    """Nube/ bocanada: unión de círculos con banda de sombra abajo y de luz arriba."""
    m = union(*[circle(x, y, r) for x, y, r in circulos])
    hoja.celda(m, pal["claro"], pal["medio"], pal["oscuro"], d=40, luz=(-0.4, -1))
    return m


def estrella4(cx, cy, r, rin=0.22, rot=0.0):
    pts = []
    for i in range(8):
        a = rot + i * math.pi / 4
        rr = r if i % 2 == 0 else r * rin
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return poly(pts)


def rayo_poly(cx, cy, h, w, sesgo=1.0):
    p = [(0.15, -0.5), (0.55, -0.5), (0.18, -0.08), (0.52, -0.08), (-0.12, 0.5), (0.0, 0.05), (-0.34, 0.05)]
    return [(cx + (x * sesgo) * w, cy + y * h) for x, y in p]


def gota(hoja, cx, cy, r, pal=AGUA, alto=1.0):
    # círculo + triángulo curvo arriba: se arma con 2 máscaras, y se sombrea como una sola
    circ = circle(cx, cy, r)
    tri = poly([(cx, cy - r * 2.0 * alto), (cx - r * 0.93, cy - r * 0.35), (cx + r * 0.93, cy - r * 0.35)])
    m = union(circ, tri)
    hoja.celda(m, pal["claro"], pal["medio"], pal["oscuro"], d=int(r * 0.22), luz=(-1, -0.6))
    hoja.add(ellipse(cx - r * 0.38, cy + r * 0.1, r * 0.16, r * 0.3, 0.4), pal["nucleo"])
    return m


# ---------------------------------------------------------------- piezas (una función por sprite)
def s_llama():
    h = Hoja()
    llama(h, 512, 940, 820, 330, sway=70, ph=0.3)
    llama(h, 240, 950, 360, 140, sway=-40, ph=2.0)
    llama(h, 800, 950, 400, 150, sway=50, ph=4.0)
    return h, FUEGO["c"]


def s_llama_pequena():
    h = Hoja()
    llama(h, 512, 900, 640, 260, sway=-50, ph=1.2)
    llama(h, 760, 910, 290, 110, sway=40, ph=3.1)
    return h, FUEGO["c"]


def frame_llama(k):
    esc = [0.45, 0.78, 1.0, 1.0, 0.92, 0.78, 0.55, 0.32][k]
    sw = [30, 60, 90, -60, -90, 40, -30, 20][k]
    h = Hoja()
    base = 920
    llama(h, 512, base, 720 * esc, 300 * (0.55 + 0.45 * esc), sway=sw, ph=k * 0.9)
    if esc > 0.7:
        llama(h, 270, base, 280 * esc, 120, sway=-sw * 0.5, ph=k * 1.7 + 2)
        llama(h, 760, base, 320 * esc, 130, sway=sw * 0.4, ph=k * 1.3 + 4)
    return h, FUEGO["c"]


def s_brasa(k=None):
    h = Hoja()
    esc = 1.0 if k is None else [0.6, 0.85, 1.0, 0.95, 0.85, 0.7, 0.5, 0.3][k]
    dy = 0 if k is None else -k * 28
    llama(h, 512, 640 + dy // 2, 430 * esc, 190 * esc, sway=30, ph=1.0)
    for (x, y, r) in [(250, 330, 34), (780, 300, 28), (200, 650, 26), (830, 640, 32), (620, 150, 24)]:
        y2 = y + dy * (1 + (x % 3) * 0.3)
        r2 = r * esc
        if y2 > 40:
            h.add(poly([(x, y2 - r2 * 1.6), (x + r2, y2), (x, y2 + r2 * 1.0), (x - r2, y2)]), FUEGO["claro"])
    return h, FUEGO["c"]


def s_burbuja():
    h = Hoja()
    m = circle(480, 520, 360)
    h.celda(m, hexc("EAF9FF"), hexc("BDE6FF"), hexc("7CC0EE"), d=46, luz=(-1, -1))
    h.add(ellipse(330, 340, 70, 110, 0.7), (255, 255, 255))
    h.add(circle(640, 740, 34), (255, 255, 255))
    for (x, y, r) in [(850, 200, 88), (880, 840, 60)]:
        h.celda(circle(x, y, r), hexc("EAF9FF"), hexc("BDE6FF"), hexc("7CC0EE"), d=16)
        h.add(circle(x - r * 0.3, y - r * 0.3, r * 0.2), (255, 255, 255))
    return h, AGUA["c"]


def s_chispa(k=None):
    h = Hoja()
    esc = 1.0 if k is None else [0.25, 0.7, 1.0, 0.9, 0.72, 0.5, 0.3, 0.12][k]
    cx, cy = 512, 512
    for i, (ang, ln, ancho) in enumerate([(-60, 430, 150), (20, 400, 140), (110, 360, 130), (200, 420, 150), (270, 340, 120)]):
        a = math.radians(ang + (0 if k is None else k * 7))
        L = ln * esc
        ex, ey = cx + math.cos(a) * L, cy + math.sin(a) * L
        nx, ny = -math.sin(a), math.cos(a)
        mx, my = (cx + ex) / 2, (cy + ey) / 2
        w = ancho * 0.5 * esc
        pts = [(cx + nx * w * 0.5, cy + ny * w * 0.5), (mx + nx * w * 1.2, my + ny * w * 1.2),
               (mx - nx * w * 0.2 + math.cos(a) * 40, my - ny * w * 0.2 + math.sin(a) * 40),
               (ex, ey), (mx - nx * w * 1.0, my - ny * w * 1.0), (cx - nx * w * 0.5, cy - ny * w * 0.5)]
        h.add(poly(pts), RAYO["medio"])
        h.add(poly([(cx, cy), (mx + nx * w * 0.2, my + ny * w * 0.2), (ex * 0.9 + cx * 0.1, ey * 0.9 + cy * 0.1)]), RAYO["claro"])
    h.add(estrella4(cx, cy, 190 * esc, 0.3, math.radians(20)), (255, 255, 255))
    return h, RAYO["c"]


def s_circulo():
    h = Hoja()
    c = (512, 512)
    anillo_e = minus(ellipse(*c, 430, 430), ellipse(*c, 360, 360))
    anillo_i = minus(ellipse(*c, 320, 320), ellipse(*c, 290, 290))
    h.add(anillo_e, HIELO["medio"])
    h.add(anillo_i, HIELO["claro"])
    for a in (0, 90, 180, 270):
        x, y = c[0] + math.cos(math.radians(a)) * 395, c[1] + math.sin(math.radians(a)) * 395
        h.add(poly([(x, y - 90), (x + 66, y), (x, y + 90), (x - 66, y)]), HIELO["claro"])
    return h, HIELO["c"]


def s_copo():
    h = Hoja()
    c = (512, 512)
    arms = []
    for i in range(6):
        a = math.radians(60 * i - 90)
        d = (math.cos(a), math.sin(a))
        n = (-d[1], d[0])
        pts = [c, (c[0] + d[0] * 400, c[1] + d[1] * 400)]
        arms.append(thick_line(pts, 62))
        for f in (0.55, 0.8):
            bx, by = c[0] + d[0] * 400 * f, c[1] + d[1] * 400 * f
            for s in (-1, 1):
                ln = 150 * (1.25 - f)
                ex = bx + (d[0] * 0.55 + n[0] * s * 0.83) * ln
                ey = by + (d[1] * 0.55 + n[1] * s * 0.83) * ln
                arms.append(thick_line([(bx, by), (ex, ey)], 44))
    m = union(*arms, circle(*c, 90))
    h.celda(m, (255, 255, 255), HIELO["claro"], HIELO["oscuro"], d=18, luz=(-1, -1))
    return h, HIELO["c"]


def s_cristal():
    h = Hoja()
    facetada(h, [(520, 70), (700, 330), (690, 760), (520, 930), (350, 760), (340, 330)], None, HIELO,
             centro=(520, 470))
    for pts in ([(230, 560), (300, 470), (330, 800), (240, 860)], [(790, 520), (850, 640), (830, 860), (740, 800)]):
        facetada(h, pts, None, HIELO)
    h.add(poly([(450, 220), (490, 180), (505, 380), (455, 400)]), (255, 255, 255))
    return h, HIELO["c"]


def s_destello(k=None):
    h = Hoja()
    esc = 1.0 if k is None else [0.2, 0.6, 1.0, 0.85, 0.65, 0.45, 0.25, 0.1][k]
    rot = 0 if k is None else k * 0.12
    h.add(estrella4(512, 512, 430 * esc, 0.2, rot), RAYO["claro"])
    h.add(estrella4(512, 512, 280 * esc, 0.22, rot), (255, 255, 255))
    for (x, y, r) in [(210, 220, 120), (810, 790, 110), (800, 240, 90), (240, 800, 80)]:
        s = r * esc
        if s > 14:
            h.add(estrella4(x, y, s, 0.25, rot), (255, 255, 255))
    return h, hexc("8A5A10")


def s_esporas():
    h = Hoja()
    pal = dict(claro=hexc("E4FFA8"), medio=hexc("B2E862"), oscuro=hexc("6FB540"))
    for (x, y, r) in [(330, 360, 190), (700, 280, 140), (620, 680, 170), (230, 760, 90), (850, 560, 70), (480, 120, 60)]:
        h.celda(circle(x, y, r), pal["claro"], pal["medio"], pal["oscuro"], d=int(r * 0.18))
        h.add(circle(x - r * 0.35, y - r * 0.35, r * 0.2), (255, 255, 255))
    return h, hexc("274E1E")


def s_gota():
    h = Hoja()
    gota(h, 480, 640, 250, AGUA, 1.0)
    gota(h, 820, 760, 70, AGUA, 0.9)
    gota(h, 190, 760, 50, AGUA, 0.9)
    return h, AGUA["c"]


def s_grieta():
    h = Hoja()
    c = (512, 512)
    rng = np.random.RandomState(4)
    ramas = []
    for i in range(7):
        a = i * 2 * math.pi / 7 + rng.uniform(-0.2, 0.2)
        pts = [c]
        x, y = c
        L = rng.uniform(300, 440)
        for s in range(1, 6):
            a += rng.uniform(-0.45, 0.45)
            x += math.cos(a) * L / 5
            y += math.sin(a) * L / 5 * 0.8
            pts.append((x, y))
        ramas.append(thick_line(pts, 48 - i * 2))
    m = union(*ramas, ellipse(*c, 130, 100))
    h.add(m, hexc("5A361C"))
    h.add(inter(m, shift(minus(m, shift(m, 10, 10)), 0, 0)), hexc("2E1A0C"))
    for (x, y, r, ph) in [(240, 320, 70, 0.2), (780, 330, 60, 1.0), (260, 700, 60, 2.0), (770, 720, 74, 3.0), (520, 190, 50, 4.0)]:
        facetada(h, piedra_pts(x, y, r, ph, 6), None, PIEDRA)
    return h, hexc("2E1A0C")


def s_hoja():
    h = Hoja()
    pts = []
    for t in np.linspace(0, 1, 30):
        w = math.sin(math.pi * t) ** 0.8 * 400
        pts.append((250 + t * 560, 800 - t * 560 - w * 0.8))
    for t in np.linspace(1, 0, 30):
        w = math.sin(math.pi * t) ** 0.8 * 400
        pts.append((250 + t * 560, 800 - t * 560 + w * 0.8))
    m = poly(pts)
    pal = dict(claro=hexc("B5EE72"), medio=hexc("6CC24A"), oscuro=hexc("3E8E3A"))
    h.celda(m, pal["claro"], pal["medio"], pal["oscuro"], d=40, luz=(-1, -0.4))
    h.add(thick_line([(230, 820), (830, 220)], 26), hexc("2E6E30"))
    for (x, y, r, a) in [(180, 250, 90, 0.8), (860, 840, 70, -0.8)]:
        pp = [(x + math.cos(a) * r * 1.3, y + math.sin(a) * -r * 1.3), (x + r * 0.7, y), (x, y + r * 0.8), (x - r * 0.7, y)]
        h.celda(poly(pp), pal["claro"], pal["medio"], pal["oscuro"], d=14)
    return h, hexc("1C4A24")


def s_humo(k=None):
    h = Hoja()
    esc = 1.0 if k is None else [0.42, 0.68, 0.88, 1.0, 1.0, 0.95, 0.82, 0.6][k]
    dy = 0 if k is None else -k * 18
    base = [(360, 600, 230), (620, 520, 250), (520, 330, 190), (300, 360, 120), (760, 700, 130), (460, 760, 150)]
    nube(h, [(512 + (x - 512) * esc, 600 + (y - 600) * esc + dy, r * esc) for x, y, r in base], HUMO)
    return h, HUMO["c"]


def s_polvo(k=None):
    h = Hoja()
    esc = 1.0 if k is None else [0.4, 0.66, 0.86, 1.0, 1.0, 0.94, 0.8, 0.55][k]
    dy = 0 if k is None else -k * 10
    base = [(300, 640, 190), (520, 560, 240), (730, 650, 190), (420, 740, 160), (640, 760, 150), (510, 380, 150)]
    nube(h, [(512 + (x - 512) * esc, 640 + (y - 640) * esc + dy, r * esc) for x, y, r in base], POLVO)
    return h, POLVO["c"]


def s_ondas():
    h = Hoja()
    c = (512, 600)
    for i, (rx, ry, w) in enumerate([(470, 190, 34), (340, 135, 30), (210, 82, 26)]):
        a = minus(ellipse(*c, rx, ry), ellipse(*c, rx - w * 1.4, ry - w * 0.7))
        h.add(a, AGUA["claro"] if i == 1 else AGUA["medio"])
    gota(h, 512, 520, 52, AGUA, 1.0)
    return h, AGUA["c"]


def s_pasadero():
    h = Hoja()
    top = [(190, 520), (330, 330), (700, 300), (850, 470), (800, 620), (400, 660)]
    lado = [(190, 520), (400, 660), (800, 620), (840, 760), (400, 830), (200, 690)]
    h.add(poly(lado), PIEDRA["oscuro"])
    h.add(poly(top), PIEDRA["claro"])
    h.add(poly([(500, 312), (520, 480), (440, 655), (400, 660), (470, 480), (460, 312)]), PIEDRA["medio"])
    h.add(thick_line([(520, 480), (810, 470)], 16), PIEDRA["medio"])
    return h, PIEDRA["c"]


def s_petalo():
    h = Hoja()
    pts = []
    for t in np.linspace(0, 1, 30):
        w = math.sin(math.pi * t) ** 0.7 * 330
        pts.append((220 + t * 600, 780 - t * 470 - w * 0.85))
    for t in np.linspace(1, 0, 30):
        w = math.sin(math.pi * t) ** 0.7 * 330
        pts.append((220 + t * 600, 780 - t * 470 + w * 0.85))
    m = poly(pts)
    h.celda(m, ROSA["claro"], ROSA["medio"], ROSA["oscuro"], d=44, luz=(-1, -0.5))
    for (x, y, r) in [(180, 250, 60), (850, 850, 50)]:
        h.celda(ellipse(x, y, r, r * 1.5, 0.5), ROSA["claro"], ROSA["medio"], ROSA["oscuro"], d=12)
    return h, ROSA["c"]


def s_piedrecitas():
    h = Hoja()
    for i, (x, y, r) in enumerate([(300, 280, 120), (700, 240, 100), (500, 520, 140), (220, 700, 90), (780, 640, 110), (560, 840, 70), (880, 380, 60)]):
        facetada(h, piedra_pts(x, y, r, i * 0.9, 7), None, PIEDRA)
    return h, PIEDRA["c"]


def s_pua():
    h = Hoja()
    for (x, base, alto, w) in [(512, 880, 760, 150), (300, 900, 420, 110), (730, 900, 480, 120)]:
        facetada(h, [(x, base - alto), (x + w, base - alto * 0.18), (x + w * 0.7, base), (x - w * 0.7, base), (x - w, base - alto * 0.18)],
                 None, TIERRA, centro=(x, base - alto * 0.4))
    for i, (x, y, r) in enumerate([(190, 860, 55), (860, 880, 60), (420, 920, 40)]):
        facetada(h, piedra_pts(x, y, r, i, 6), None, TIERRA)
    return h, TIERRA["c"]


def s_rayo():
    h = Hoja()
    m = poly(rayo_poly(512, 512, 820, 560))
    h.celda(m, RAYO["claro"], RAYO["medio"], RAYO["oscuro"], d=30, luz=(-1, -0.3))
    h.add(poly(rayo_poly(512 - 10, 512 - 20, 600, 330)), (255, 255, 255))
    return h, RAYO["c"]


def s_remolino():
    h = Hoja()
    c = (512, 520)
    circ = []
    for t in np.linspace(0, 1, 160):
        a = 0.4 + t * 4.6 * math.pi
        r = 70 + t * 380
        circ.append(circle(c[0] + math.cos(a) * r, c[1] + math.sin(a) * r * 0.82, 22 + (1 - t) * 38))
    m = union(*circ)
    h.celda(m, VIENTO["claro"], VIENTO["medio"], VIENTO["oscuro"], d=24, luz=(-1, -1))
    for (x, y, r) in [(840, 250, 40), (180, 820, 36)]:
        h.add(circle(x, y, r), VIENTO["medio"])
    return h, VIENTO["c"]


def s_roca(grande):
    h = Hoja()
    if grande:
        facetada(h, piedra_pts(500, 520, 380, 0.3, 9), None, PIEDRA)
        for i, (x, y, r) in enumerate([(160, 780, 70), (880, 730, 80), (860, 220, 56), (170, 270, 50)]):
            facetada(h, piedra_pts(x, y, r, i, 6), None, PIEDRA)
    else:
        facetada(h, piedra_pts(500, 540, 300, 1.1, 8), None, PIEDRA)
        for i, (x, y, r) in enumerate([(180, 800, 60), (850, 790, 66), (840, 250, 48)]):
            facetada(h, piedra_pts(x, y, r, i + 2, 6), None, PIEDRA)
    return h, PIEDRA["c"]


def s_salpicadura():
    h = Hoja()
    base = minus(ellipse(512, 800, 440, 120), ellipse(512, 800, 300, 70))
    h.add(base, AGUA["claro"])
    dedos = []
    for ang, alto in [(-62, 470), (-30, 600), (0, 690), (30, 600), (62, 470)]:
        x = 512 + math.sin(math.radians(ang)) * 300
        y = 800 - alto * 0.8
        dedos.append(thick_line([(512 + (x - 512) * 0.3, 790), (x, y + 70)], 120 - abs(ang) * 0.6))
        dedos.append(circle(x, y + 60, 82))
    h.celda(union(*dedos), AGUA["claro"], AGUA["medio"], AGUA["oscuro"], d=26, luz=(-1, -0.4))
    for (x, y, r) in [(200, 300, 46), (830, 280, 52), (512, 130, 40)]:
        gota(h, x, y, r, AGUA, 1.0)
    return h, AGUA["c"]


def s_telarana():
    h = Hoja()
    c = (512, 512)
    ms = []
    n = 8
    R = 450
    for i in range(n):
        a = 2 * math.pi * i / n
        ms.append(thick_line([c, (c[0] + math.cos(a) * R, c[1] + math.sin(a) * R)], 20))
    for f in (0.28, 0.5, 0.74, 1.0):
        pts = []
        for i in range(n + 1):
            a = 2 * math.pi * i / n
            r = R * f
            pts.append((c[0] + math.cos(a) * r, c[1] + math.sin(a) * r))
        for i in range(n):
            a0, a1 = pts[i], pts[i + 1]
            mid = ((a0[0] + a1[0]) / 2 * 0.93 + c[0] * 0.07, (a0[1] + a1[1]) / 2 * 0.93 + c[1] * 0.07)
            ms.append(thick_line([a0, mid, a1], 18, False))
    m = union(*ms)
    h.add(m, hexc("F2F0F6"))
    return h, hexc("4A4560")


def s_terrones():
    h = Hoja()
    nube(h, [(300, 720, 140), (520, 680, 180), (730, 730, 140)], POLVO)
    for i, (x, y, r) in enumerate([(220, 340, 100), (520, 260, 120), (800, 380, 90), (380, 560, 76), (660, 540, 80)]):
        facetada(h, piedra_pts(x, y, r, i * 1.3, 7), None, TIERRA)
    return h, TIERRA["c"]


def s_anillo_polvo():
    h = Hoja()
    cs = []
    for i in range(14):
        a = i * 2 * math.pi / 14
        cs.append((512 + math.cos(a) * 360, 520 + math.sin(a) * 290, 105 + 22 * math.sin(i * 2.1)))
    nube(h, cs, POLVO)
    return h, POLVO["c"]


# ---------------------------------------------------------------- salida
SPRITES = {
    "llama": s_llama, "llama_pequena": s_llama_pequena, "brasa": s_brasa, "burbuja": s_burbuja,
    "chispa_electrica": s_chispa, "circulo_runico": s_circulo, "copo": s_copo, "cristal_hielo": s_cristal,
    "destello": s_destello, "esporas": s_esporas, "gota": s_gota, "grieta": s_grieta, "hoja": s_hoja,
    "humo": s_humo, "ondas": s_ondas, "pasadero": s_pasadero, "petalo": s_petalo, "piedrecitas": s_piedrecitas,
    "polvo": s_polvo, "pua_tierra": s_pua, "rayo": s_rayo, "remolino_viento": s_remolino,
    "roca_grande": lambda: s_roca(True), "roca_mediana": lambda: s_roca(False), "salpicadura": s_salpicadura,
    "telarana": s_telarana, "terrones": s_terrones, "anillo_polvo": s_anillo_polvo,
}
TIRAS = {
    "llama_tira8": frame_llama, "brasa_tira8": lambda k: s_brasa(k), "humo_tira8": lambda k: s_humo(k),
    "polvo_tira8": lambda k: s_polvo(k), "chispa_electrica_tira8": lambda k: s_chispa(k),
    "destello_tira8": lambda k: s_destello(k),
}


def main():
    salida = sys.argv[1] if len(sys.argv) > 1 else os.path.join("poc_25d", "vfx")
    os.makedirs(salida, exist_ok=True)
    for nombre, f in SPRITES.items():
        hoja, contorno = f()
        hoja.render(contorno).save(os.path.join(salida, nombre + ".png"))
    for nombre, f in TIRAS.items():
        tira = Image.new("RGBA", (OUT * 8, OUT), (0, 0, 0, 0))
        for k in range(8):
            hoja, contorno = f(k)
            tira.paste(hoja.render(contorno), (k * OUT, 0))
        tira.save(os.path.join(salida, nombre + ".png"))
    print("hecho:", len(SPRITES), "sprites y", len(TIRAS), "tiras en", salida)


if __name__ == "__main__":
    main()
