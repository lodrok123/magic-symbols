"""Tiras de efecto en el MISMO formato que fire/water/wind/earth:
celdas de 128x128 en rejilla de 6 columnas, dibujadas sobre una malla
logica de 32x32 y ampliadas x4 con NEAREST -> pixelado limpio, sin
antialias, que es lo que mantiene la coherencia con las que ya hay.

Tres actos en los tres efectos, como en el fuego: NACE, PEGA, SE VA.
El acto del medio es el que tiene que leerse de un vistazo, asi que se
le dan los fotogramas mas contrastados y el resto le hace sitio."""
from PIL import Image
import math, random

G, CELL, COLS, FRAMES = 32, 128, 6, 18


class Canvas:
    def __init__(self):
        self.px = {}

    def put(self, x, y, color, a=255):
        x, y = int(round(x)), int(round(y))
        if not (0 <= x < G and 0 <= y < G) or a <= 0:
            return
        old = self.px.get((x, y))
        # Lo mas brillante gana, para que un trazo de relleno posterior
        # no apague el nucleo que ya estaba puesto.
        if old is None or sum(color) >= sum(old[:3]):
            self.px[(x, y)] = color + (a,)

    def blob(self, x, y, r, color, a=255):
        r = int(r)
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r:
                    self.put(x + dx, y + dy, color, a)

    def line(self, p0, p1, color, a, width=0):
        (x0, y0), (x1, y1) = p0, p1
        n = int(max(abs(x1 - x0), abs(y1 - y0))) * 2 + 1
        for i in range(n + 1):
            t = i / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            self.blob(x, y, width, color, a) if width else self.put(x, y, color, a)

    def image(self):
        img = Image.new("RGBA", (G, G), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            img.putpixel((x, y), c)
        return img.resize((CELL, CELL), Image.NEAREST)


def tail(t, start):
    """Desvanecido que llega a cero justo en el ultimo fotograma."""
    return 255 if t <= start else int(255 * max(0.0, 1.0 - (t - start) / (1.0 - start)))


# ---------------------------------------------------------------- RAYO
# Amarillo saturado, no palido: sobre fondo claro un amarillo suave se
# pierde. El ambar de fuera hace de contorno y es lo que le da cuerpo.
L_GLOW, L_BODY, L_CORE = (245, 147, 0), (255, 198, 26), (255, 246, 192)


def bolt_path(jitter):
    """UN solo trazado, con un temblor de un pixel.

    Antes habia dos caminos distintos alternandose y no se leia como un
    rayo parpadeando, sino como dos rayos turnandose. El parpadeo de un
    relampago es un temblor, no un cambio de sitio."""
    rnd = random.Random(7)
    pts, x, y = [], 16, 1
    while y < 29:
        pts.append((x + jitter, y))
        x = max(6, min(25, x + rnd.choice([-5, -4, 4, 5])))
        y += rnd.randint(3, 5)
    pts.append((max(6, min(25, x)) + jitter, 30))
    return pts


def frame_rayo(t):
    c = Canvas()
    pts = bolt_path(0 if int(t * FRAMES) % 2 == 0 else 1)

    if t < 0.22:                                  # baja buscando el suelo
        limit = 1 + (t / 0.22) * 29
        for i in range(len(pts) - 1):
            if pts[i][1] > limit:
                break
            c.line(pts[i], pts[i + 1], L_BODY, 230)
            c.line(pts[i], pts[i + 1], L_CORE, 230) if i < 2 else None
        return c.image()

    a = tail(t, 0.62)
    if a <= 0:
        return c.image()

    flash = t < 0.34                              # el impacto
    for w, col, mul in ((2, L_GLOW, 0.85), (1, L_BODY, 1.0)):
        for i in range(len(pts) - 1):
            c.line(pts[i], pts[i + 1], col, int(a * mul), width=w)
    for i in range(len(pts) - 1):
        c.line(pts[i], pts[i + 1], L_CORE, a)

    mid = pts[len(pts) // 2]
    c.line(mid, (mid[0] + 8 * (1 if t * 10 % 2 < 1 else -1), mid[1] + 6),
           L_BODY, int(a * 0.85), width=1)

    if flash:                                     # fogonazo en el suelo
        for k in range(14):
            ang = math.pi * (1.02 + 0.96 * k / 13)
            d = 6 + (0.34 - t) * 40
            c.line(pts[-1], (pts[-1][0] + math.cos(ang) * d,
                             30 + math.sin(ang) * d * 0.55), L_BODY, int(a * 0.7))
    else:                                         # chispas que se alejan
        rnd = random.Random(99)
        spread = (t - 0.34) * 30
        for k in range(12):
            ang = rnd.uniform(math.pi * 1.05, math.pi * 1.95)
            d = spread * rnd.uniform(0.4, 1.0)
            c.blob(pts[-1][0] + math.cos(ang) * d, 30 + math.sin(ang) * d * 0.6,
                   1 if k % 3 == 0 else 0, L_BODY, a)
    return c.image()


# --------------------------------------------------------------- HIELO
# Blanco celeste, con un azul mas hondo SOLO de contorno: sin el, el
# cristal se funde con el fondo claro y no se lee la silueta.
I_EDGE, I_BODY, I_CORE = (79, 168, 216), (168, 232, 255), (255, 255, 255)


def ice_arm(c, cx, cy, ang, r, a, spikes):
    tip = (cx + math.cos(ang) * r, cy + math.sin(ang) * r)
    c.line((cx, cy), tip, I_EDGE, a, width=1)
    c.line((cx, cy), tip, I_BODY, a)
    if spikes:
        for frac in (0.45, 0.75):
            base = (cx + math.cos(ang) * r * frac, cy + math.sin(ang) * r * frac)
            for s in (-1, 1):
                sub = ang + s * 0.85
                c.line(base, (base[0] + math.cos(sub) * r * 0.3,
                              base[1] + math.sin(sub) * r * 0.3), I_BODY, a)
    return tip


def frame_hielo(t):
    c = Canvas()
    cx = cy = 16
    FULL = 14.0

    if t < 0.36:                                  # cuaja
        grow = t / 0.36
        r = 3 + grow * (FULL - 3)
        for k in range(6):
            ice_arm(c, cx, cy, math.tau * k / 6, r, 255, grow > 0.5)
        c.blob(cx, cy, 1 + grow * 2, I_CORE, 255)
        return c.image()

    if t < 0.6:                                   # aguanta: es el fotograma
        for k in range(6):                        # que de verdad se ve
            ice_arm(c, cx, cy, math.tau * k / 6, FULL, 255, True)
        c.blob(cx, cy, 3, I_CORE, 255)
        return c.image()

    # Se resquebraja. El cristal NO desaparece de golpe: los brazos se
    # acortan mientras las puntas salen despedidas, asi se lee que se ha
    # roto y no que alguien lo ha borrado.
    a = tail(t, 0.72)
    if a <= 0:
        return c.image()

    crack = (t - 0.6) / 0.4
    stub = FULL * (1.0 - crack)
    for k in range(6):
        ang = math.tau * k / 6
        if stub > 2:
            ice_arm(c, cx, cy, ang, stub, a, False)

        d = FULL + crack * 13
        p = (cx + math.cos(ang) * d, cy + math.sin(ang) * d)
        back = (p[0] - math.cos(ang) * 3.5, p[1] - math.sin(ang) * 3.5)
        c.line(back, p, I_EDGE, a, width=1)       # esquirla con cuerpo,
        c.line(back, p, I_BODY, a)                # no un pixel suelto
        c.put(p[0], p[1], I_CORE, a)

    rnd = random.Random(21)
    for k in range(10):
        ang = rnd.uniform(0, math.tau)
        d = rnd.uniform(4, 10) + crack * 7
        c.put(cx + math.cos(ang) * d, cy + math.sin(ang) * d, I_EDGE, int(a * 0.85))

    c.blob(cx, cy, max(0, 3 - crack * 4), I_CORE, a)
    return c.image()


# -------------------------------------------------------------- TIEMPO
T_DEEP, T_BODY, T_CORE = (110, 91, 184), (179, 157, 232), (239, 230, 255)


def ring(c, cx, cy, r, color, a, phase=0.0, dashed=0):
    n = max(8, int(r * 7))
    for k in range(n):
        if dashed and (k * dashed // n) % 2:
            continue
        ang = math.tau * k / n + phase
        c.put(cx + math.cos(ang) * r, cy + math.sin(ang) * r, color, a)


def frame_tiempo(t):
    c = Canvas()
    cx = cy = 16
    a = tail(t, 0.66)
    if a <= 0:
        return c.image()

    # El anillo exterior se CIERRA sobre el centro mientras el interior
    # se abre. Esa lectura —algo se recoge hacia dentro— es la runa.
    outer, inner = 15 - t * 10, 2 + t * 6

    ring(c, cx, cy, outer, T_DEEP, a)
    ring(c, cx, cy, outer - 1, T_BODY, a)
    for k in range(12):                           # marcas de esfera
        ang = math.tau * k / 12 + t * 2.2
        c.line((cx + math.cos(ang) * (outer - 2.5), cy + math.sin(ang) * (outer - 2.5)),
               (cx + math.cos(ang) * (outer - 1), cy + math.sin(ang) * (outer - 1)),
               T_CORE, a)
    ring(c, cx, cy, inner, T_DEEP, int(a * 0.9), phase=-t * 5.0, dashed=16)

    for direction, length, color in ((1, 9, T_DEEP), (-1, 5.5, T_BODY)):
        ang = direction * t * math.tau * 1.6 - math.pi / 2
        c.line((cx, cy), (cx + math.cos(ang) * length, cy + math.sin(ang) * length),
               color, a)

    c.blob(cx, cy, 1, T_CORE, a)
    return c.image()


# ------------------------------------------------------------- montaje
def sheet(maker, name):
    rows = math.ceil(FRAMES / COLS)
    img = Image.new("RGBA", (COLS * CELL, rows * CELL), (0, 0, 0, 0))
    for i in range(FRAMES):
        img.paste(maker(i / FRAMES), ((i % COLS) * CELL, (i // COLS) * CELL))
    img.save(name)
    print(f"{name}: {img.size}  {FRAMES} fotogramas en {COLS}x{rows}")


sheet(frame_rayo, "lightning.png")
sheet(frame_hielo, "ice.png")
sheet(frame_tiempo, "time.png")
