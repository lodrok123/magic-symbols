#!/usr/bin/env python3
"""Páginas del GRIMORIO en estilo pastel (prueba de concepto).

Dibuja la doble página que se ve al abrir el libro con T, en varios estilos y para dos niveles de libro:

  s1g3  1 sello (elemento) en el núcleo + 3 huecos de glifo   (libro de aprendiz)
  s2g6  2 sellos (núcleo partido en dos)  + 6 huecos de glifo (libro avanzado)

La página izquierda es donde se dibuja: el círculo con el núcleo (sello) y la corona de 8 sectores (glifos).
Debajo, los huecos de glifo: se van llenando a medida que dibujas (es el presupuesto de la página).
La página derecha es el catálogo: los 12 glifos conocidos y los 6 elementos.

Además de cada PNG escribe `paginas.json` con las medidas (centro y radios del círculo, huecos, rejilla) en
píxeles de la imagen: Godot coloca el dibujo encima con esos números, igual que spellbook.gd con la lámina
actual. Una lámina pintada a mano o con IA vale si respeta estas medidas (ver PROMPTS_GRIMORIO.md).

Uso:  python generar_paginas.py            -> todos los estilos y distribuciones en esta carpeta
Solo necesita Pillow y numpy.
"""
from __future__ import annotations

import json
import zlib
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

AQUI = Path(__file__).resolve().parent
W, H = 1600, 1000            # tamaño final de la doble página
SS = 2                       # supermuestreo para líneas suaves

ESTILOS = {
    # papel, tinta, acento 1, acento 2, oro, nombre
    "botanico": dict(papel=(246, 238, 218), tinta=(92, 74, 60), a1=(122, 160, 118), a2=(214, 170, 168),
                     oro=(204, 168, 96), fondo=(58, 92, 88), cuero=(52, 106, 104)),
    "astral": dict(papel=(240, 238, 248), tinta=(70, 74, 112), a1=(150, 168, 222), a2=(206, 182, 230),
                   oro=(222, 190, 112), fondo=(52, 58, 98), cuero=(70, 82, 140)),
    "acuarela": dict(papel=(250, 244, 234), tinta=(110, 86, 74), a1=(150, 206, 190), a2=(244, 176, 172),
                     oro=(226, 186, 120), fondo=(120, 86, 70), cuero=(150, 104, 80)),
}

ELEMENTOS = [("fuego", (244, 140, 92)), ("agua", (110, 170, 236)), ("tierra", (196, 150, 96)),
             ("viento", (150, 214, 176)), ("rayo", (240, 206, 90)), ("hielo", (160, 214, 240))]

DISTRIBUCIONES = {"s1g3": dict(sellos=1, glifos=3), "s2g6": dict(sellos=2, glifos=6)}


# ------------------------------------------------------------------ utilidades
def ruido(w: int, h: int, escala: int, semilla: int) -> np.ndarray:
    """Ruido de valor suave 0..1 (bilineal sobre una rejilla aleatoria)."""
    rng = np.random.default_rng(semilla)
    gw, gh = w // escala + 2, h // escala + 2
    g = rng.random((gh, gw)).astype(np.float32)
    im = Image.fromarray((g * 255).astype(np.uint8)).resize((gw * escala, gh * escala), Image.BICUBIC)
    return np.asarray(im, dtype=np.float32)[:h, :w] / 255.0


def mezclar(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def con_alfa(c, a):
    return (c[0], c[1], c[2], int(a))


class Lienzo:
    """Capa RGBA a escala SS con utilidades de dibujo en coordenadas finales."""

    def __init__(self):
        self.im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def p(self, x, y):
        return (x * SS, y * SS)

    def circulo(self, c, r, color, ancho=2.0, relleno=None):
        x, y = c
        self.d.ellipse([(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS], outline=color,
                       width=max(1, int(ancho * SS)), fill=relleno)

    def punteado(self, c, r, color, n=90, tam=1.6):
        for i in range(n):
            a = i / n * math.tau
            self.circulo((c[0] + math.cos(a) * r, c[1] + math.sin(a) * r), tam, None, 1, color)

    def linea(self, a, b, color, ancho=2.0):
        self.d.line([self.p(*a), self.p(*b)], fill=color, width=max(1, int(ancho * SS)))

    def poligono(self, pts, color):
        self.d.polygon([self.p(*q) for q in pts], fill=color)

    def arco(self, c, r, a0, a1, color, ancho=2.0):
        x, y = c
        self.d.arc([(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS], a0, a1, fill=color,
                   width=max(1, int(ancho * SS)))

    def final(self):
        return self.im.resize((W, H), Image.LANCZOS)


def estrella(L: Lienzo, c, r, color, puntas=4, interior=0.32, giro=0.0):
    pts = []
    for i in range(puntas * 2):
        a = giro + i / (puntas * 2) * math.tau - math.pi / 2
        rr = r if i % 2 == 0 else r * interior
        pts.append((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr))
    L.poligono(pts, color)


def hoja(L: Lienzo, base, ang, largo, ancho, color):
    """Hoja en forma de almendra que sale de `base` hacia `ang`."""
    pts = []
    for i in range(21):
        t = i / 20
        x = t * largo
        y = math.sin(t * math.pi) * ancho * 0.5
        pts.append((x, y))
    pts += [(x, -y) for x, y in reversed(pts)]
    ca, sa = math.cos(ang), math.sin(ang)
    L.poligono([(base[0] + x * ca - y * sa, base[1] + x * sa + y * ca) for x, y in pts], color)


def rama(L: Lienzo, p0, p1, color_tallo, color_hoja, n_hojas=7, curva=40.0, semilla=0, ancho=2.4):
    """Rama curva de p0 a p1 con hojas alternas."""
    rng = random.Random(semilla)
    mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    ln = math.hypot(dx, dy) or 1
    nx, ny = -dy / ln, dx / ln
    ctrl = (mx + nx * curva, my + ny * curva)
    pts = []
    for i in range(41):
        t = i / 40
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * ctrl[0] + t * t * p1[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * ctrl[1] + t * t * p1[1]
        pts.append((x, y))
    for a, b in zip(pts, pts[1:]):
        L.linea(a, b, color_tallo, ancho)
    for k in range(n_hojas):
        t = (k + 0.7) / (n_hojas + 0.4)
        i = min(39, int(t * 40))
        a, b = pts[i], pts[i + 1]
        ang = math.atan2(b[1] - a[1], b[0] - a[0]) + (0.9 if k % 2 == 0 else -0.9)
        tam = 22 * (1.0 - t * 0.45) * rng.uniform(0.85, 1.15)
        hoja(L, a, ang, tam, tam * 0.5, color_hoja)


# ------------------------------------------------------------------ geometría
def geometria(dist: str) -> dict:
    """Medidas de la doble página (las mismas para todos los estilos)."""
    g: dict = {"tamano": [W, H]}
    izq = (70, 60, 770, 900)          # x, y, ancho, alto de la página izquierda
    der = (W - 70 - 770, 60, 770, 900)
    g["pagina_izq"] = list(izq)
    g["pagina_der"] = list(der)
    cx = izq[0] + izq[2] / 2
    g["circulo_centro"] = [cx, 400.0]
    g["circulo_radio"] = 255.0
    g["nucleo_radio"] = 105.0
    g["sectores"] = 8
    n = DISTRIBUCIONES[dist]["glifos"]
    g["sellos"] = DISTRIBUCIONES[dist]["sellos"]
    g["glifos"] = n
    # Huecos de glifo: una fila (3) o dos filas de 3 (6), debajo del círculo.
    huecos = []
    filas = 1 if n <= 3 else 2
    por_fila = math.ceil(n / filas)
    for f in range(filas):
        for i in range(por_fila):
            if len(huecos) >= n:
                break
            x = cx + (i - (por_fila - 1) / 2) * 96
            y = 735 + f * 82 if filas == 2 else 760
            huecos.append([x, y])
    g["huecos"] = huecos
    g["hueco_radio"] = 32.0
    # Catálogo de la derecha: 4 x 3 glifos y una fila de 6 elementos.
    g["rejilla_origen"] = [der[0] + 175.0, 215.0]
    g["rejilla_paso"] = [140.0, 150.0]
    g["rejilla_columnas"] = 4
    g["rejilla_filas"] = 3
    g["rejilla_radio"] = 52.0
    g["elementos"] = [[der[0] + 135.0 + i * 100.0, 760.0] for i in range(6)]
    g["elemento_radio"] = 34.0
    return g


# ------------------------------------------------------------------ dibujo
def papel(est: dict, semilla: int) -> Image.Image:
    """Fondo (el cuero del libro asomando) + las dos hojas de papel con su textura y el pliegue."""
    fondo = Image.new("RGB", (W, H), est["cuero"])
    n = ruido(W, H, 60, semilla)
    f = np.asarray(fondo, dtype=np.float32) * (0.88 + 0.16 * n[..., None])
    fondo = Image.fromarray(np.clip(f, 0, 255).astype(np.uint8))
    mascara = Image.new("L", (W, H), 0)
    dm = ImageDraw.Draw(mascara)
    dm.rounded_rectangle([40, 30, W // 2 - 4, H - 40], 26, fill=255)
    dm.rounded_rectangle([W // 2 + 4, 30, W - 40, H - 40], 26, fill=255)
    hoja_ = np.zeros((H, W, 3), np.float32) + np.array(est["papel"], np.float32)
    n1 = ruido(W, H, 90, semilla + 1)
    n2 = ruido(W, H, 12, semilla + 2)
    hoja_ *= (0.94 + 0.07 * n1 + 0.025 * n2)[..., None]
    # Pliegue del centro y bordes algo más tostados.
    xs = np.abs(np.arange(W, dtype=np.float32) - W / 2) / (W / 2)
    pliegue = 1.0 - 0.16 * np.exp(-(xs * 9.0) ** 2)
    hoja_ *= pliegue[None, :, None]
    ys = np.arange(H, dtype=np.float32)[:, None]
    xx = np.arange(W, dtype=np.float32)[None, :]
    borde = np.minimum(np.minimum(xx - 40, W - 40 - xx), np.minimum(ys - 30, H - 40 - ys))
    tostado = np.clip(1.0 - borde / 70.0, 0, 1) ** 2
    hoja_ = hoja_ * (1 - 0.10 * tostado[..., None]) + np.array([170, 130, 90], np.float32) * 0.10 * tostado[..., None]
    hoja_img = Image.fromarray(np.clip(hoja_, 0, 255).astype(np.uint8))
    sombra = mascara.filter(ImageFilter.GaussianBlur(14))
    fondo = Image.composite(Image.new("RGB", (W, H), mezclar(est["cuero"], (0, 0, 0), 0.55)), fondo,
                            sombra.point(lambda v: int(v * 0.6)))
    return Image.composite(hoja_img, fondo, mascara)


def manchas_acuarela(base: Image.Image, est: dict, semilla: int) -> Image.Image:
    """Manchas suaves de color en las esquinas (solo estilo acuarela)."""
    rng = random.Random(semilla)
    capa = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(capa)
    for (x, y) in [(120, 110), (690, 120), (130, 860), (700, 850), (900, 120), (1480, 130), (910, 860), (1470, 860)]:
        for _ in range(5):
            r = rng.uniform(40, 110)
            c = est["a1"] if rng.random() < 0.5 else est["a2"]
            d.ellipse([x - r + rng.uniform(-40, 40), y - r + rng.uniform(-40, 40),
                       x + r + rng.uniform(-40, 40), y + r + rng.uniform(-40, 40)], fill=con_alfa(c, 38))
    capa = capa.filter(ImageFilter.GaussianBlur(18))
    return Image.alpha_composite(base.convert("RGBA"), capa)


def marco(L: Lienzo, est: dict, rect, estilo: str, semilla: int):
    x, y, w, h = rect
    t = con_alfa(est["tinta"], 150)
    oro = con_alfa(est["oro"], 230)
    L.d.rounded_rectangle([(x + 18) * SS, (y + 18) * SS, (x + w - 18) * SS, (y + h - 18) * SS], 18 * SS,
                          outline=t, width=int(2 * SS))
    L.d.rounded_rectangle([(x + 28) * SS, (y + 28) * SS, (x + w - 28) * SS, (y + h - 28) * SS], 12 * SS,
                          outline=con_alfa(est["tinta"], 70), width=int(1 * SS))
    esquinas = [(x + 28, y + 28), (x + w - 28, y + 28), (x + 28, y + h - 28), (x + w - 28, y + h - 28)]
    for k, (cx, cy) in enumerate(esquinas):
        if estilo == "botanico" or estilo == "acuarela":
            sx = 1 if k % 2 == 0 else -1
            sy = 1 if k < 2 else -1
            rama(L, (cx, cy), (cx + sx * 200, cy + sy * 30), con_alfa(est["tinta"], 170),
                 con_alfa(est["a1"], 220), 6, 18 * sy * sx, semilla + k)
            rama(L, (cx, cy), (cx + sx * 25, cy + sy * 190), con_alfa(est["tinta"], 170),
                 con_alfa(est["a1"], 220), 5, -18 * sy * sx, semilla + 10 + k)
            for j in range(3):
                fx, fy = cx + sx * (60 + j * 55), cy + sy * (14 + (j % 2) * 18)
                for p in range(5):
                    a = p / 5 * math.tau
                    L.circulo((fx + math.cos(a) * 6, fy + math.sin(a) * 6), 5, None, 1, con_alfa(est["a2"], 230))
                L.circulo((fx, fy), 3, None, 1, oro)
        else:
            estrella(L, (cx, cy), 20, oro, 4, 0.3)
            estrella(L, (cx, cy), 9, con_alfa(est["a1"], 255), 4, 0.35, math.pi / 4)
    if estilo == "astral":
        # Fases de la luna arriba, constelación abajo.
        for i in range(7):
            mx = x + w / 2 + (i - 3) * 46
            L.circulo((mx, y + 52), 9, con_alfa(est["tinta"], 160), 1.5)
            fase = (i - 3) / 3.0
            L.circulo((mx + fase * 9, y + 52), 9, None, 1, con_alfa(est["papel"], 255))
        rng = random.Random(semilla)
        pts = [(x + 80 + rng.uniform(0, w - 160), y + h - 70 + rng.uniform(-12, 12)) for _ in range(7)]
        pts.sort()
        for a, b in zip(pts, pts[1:]):
            L.linea(a, b, con_alfa(est["tinta"], 70), 1)
        for q in pts:
            estrella(L, q, 6, oro, 4, 0.3)


def circulo_hechizo(L: Lienzo, est: dict, g: dict, estilo: str):
    c = g["circulo_centro"]
    r = g["circulo_radio"]
    rn = g["nucleo_radio"]
    tinta = con_alfa(est["tinta"], 200)
    suave = con_alfa(est["tinta"], 80)
    oro = con_alfa(est["oro"], 235)
    L.circulo(c, r + 22, suave, 1.2)
    L.punteado(c, r + 11, suave, 120, 1.4)
    L.circulo(c, r, tinta, 2.4)
    # 8 sectores: radios punteados entre el núcleo y el borde, y una marca en cada sector.
    for i in range(8):
        a = i / 8 * math.tau - math.pi / 2 - math.pi / 8
        for k in range(14):
            t = rn + 8 + (r - rn - 16) * k / 13
            L.circulo((c[0] + math.cos(a) * t, c[1] + math.sin(a) * t), 1.6, None, 1, suave)
        am = a + math.pi / 8
        pm = (c[0] + math.cos(am) * (r - 22), c[1] + math.sin(am) * (r - 22))
        if estilo == "astral":
            estrella(L, pm, 9, oro, 4, 0.3, am)
        elif estilo == "botanico":
            hoja(L, (pm[0] - math.cos(am) * 8, pm[1] - math.sin(am) * 8), am, 18, 9, con_alfa(est["a1"], 230))
        else:
            L.circulo(pm, 5, None, 1, con_alfa(est["a2"], 230))
    # Núcleo: uno o dos sellos.
    L.circulo(c, rn + 8, suave, 1.2)
    L.circulo(c, rn, tinta, 2.4, con_alfa(est["a1"], 26))
    if g["sellos"] == 2:
        # Núcleo partido por una S (como el yin-yang): un sello a cada lado.
        L.arco((c[0], c[1] - rn / 2), rn / 2, 90, 270, tinta, 2.2)
        L.arco((c[0], c[1] + rn / 2), rn / 2, 270, 90, tinta, 2.2)
        for s, dy in ((-1, -rn / 2), (1, rn / 2)):
            L.circulo((c[0] + s * 4, c[1] + dy), 12, con_alfa(est["tinta"], 120), 1.4)
            estrella(L, (c[0] + s * 4, c[1] + dy), 7, oro, 4, 0.35)
    else:
        L.circulo(c, 16, con_alfa(est["tinta"], 120), 1.4)
        estrella(L, c, 10, oro, 4, 0.35)
    # Cruz de guía muy suave.
    L.linea((c[0], c[1] - r - 34), (c[0], c[1] - rn - 14), con_alfa(est["tinta"], 40), 1)
    L.linea((c[0], c[1] + rn + 14), (c[0], c[1] + r + 34), con_alfa(est["tinta"], 40), 1)


def huecos(L: Lienzo, est: dict, g: dict, estilo: str):
    r = g["hueco_radio"]
    for (x, y) in g["huecos"]:
        L.circulo((x, y), r + 6, con_alfa(est["tinta"], 60), 1)
        L.circulo((x, y), r, con_alfa(est["tinta"], 190), 2, con_alfa(est["a2"] if estilo != "astral" else est["a1"], 40))
        estrella(L, (x, y), 8, con_alfa(est["tinta"], 70), 4, 0.3)
    # Cinta que une los huecos.
    xs = [h[0] for h in g["huecos"]]
    ys = sorted({h[1] for h in g["huecos"]})
    for y in ys:
        fila = [h for h in g["huecos"] if h[1] == y]
        L.linea((min(h[0] for h in fila) - r - 30, y), (min(h[0] for h in fila) - r - 6, y), con_alfa(est["tinta"], 90), 1.4)
        L.linea((max(h[0] for h in fila) + r + 6, y), (max(h[0] for h in fila) + r + 30, y), con_alfa(est["tinta"], 90), 1.4)
    _ = xs


def catalogo(L: Lienzo, est: dict, g: dict, estilo: str):
    ox, oy = g["rejilla_origen"]
    px, py = g["rejilla_paso"]
    r = g["rejilla_radio"]
    for fila in range(g["rejilla_filas"]):
        for col in range(g["rejilla_columnas"]):
            c = (ox + col * px, oy + fila * py)
            L.circulo(c, r, con_alfa(est["tinta"], 150), 1.8, con_alfa(est["papel"], 0))
            L.punteado(c, r - 8, con_alfa(est["tinta"], 50), 40, 1.0)
            estrella(L, c, 7, con_alfa(est["tinta"], 60), 4, 0.3)
    # Separador y los 6 elementos.
    der = g["pagina_der"]
    y = g["elementos"][0][1] - 70
    L.linea((der[0] + 90, y), (der[0] + der[2] - 90, y), con_alfa(est["tinta"], 90), 1.2)
    estrella(L, (der[0] + der[2] / 2, y), 10, con_alfa(est["oro"], 230), 4, 0.3)
    for (x, ye), (_, col) in zip(g["elementos"], ELEMENTOS):
        L.circulo((x, ye), g["elemento_radio"] + 5, con_alfa(est["oro"], 200), 2)
        L.circulo((x, ye), g["elemento_radio"], con_alfa(est["tinta"], 160), 1.6, con_alfa(col, 70))


def generar(estilo: str, dist: str) -> dict:
    est = ESTILOS[estilo]
    semilla = zlib.crc32((estilo + dist).encode()) % 10000
    g = geometria(dist)
    base = papel(est, semilla)
    if estilo == "acuarela":
        base = manchas_acuarela(base, est, semilla)
    L = Lienzo()
    marco(L, est, g["pagina_izq"], estilo, semilla)
    marco(L, est, g["pagina_der"], estilo, semilla + 50)
    circulo_hechizo(L, est, g, estilo)
    huecos(L, est, g, estilo)
    catalogo(L, est, g, estilo)
    final = Image.alpha_composite(base.convert("RGBA"), L.final()).convert("RGB")
    final.save(AQUI / f"pagina_{estilo}_{dist}.png", optimize=True)
    return g


def main() -> None:
    medidas = {}
    for dist in DISTRIBUCIONES:
        for estilo in ESTILOS:
            medidas[dist] = generar(estilo, dist)
            print("ok", estilo, dist)
    (AQUI / "paginas.json").write_text(json.dumps({"estilos": list(ESTILOS), "distribuciones": medidas},
                                                  indent=1, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    main()
