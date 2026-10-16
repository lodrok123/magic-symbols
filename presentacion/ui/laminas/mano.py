from lib import *
import tempfile
import sys, os
W = H = 560
PUNTA = (92, 330)                  # la punta de la pluma en cada imagen (el ancla)
PIEL = (243, 205, 170, 255); PIEL_S = (222, 170, 135, 255)
MANGA = (66, 82, 150, 255); MANGA_S = (48, 60, 118, 255); PUNO = (239, 231, 211, 255)
PLUMA = (246, 242, 230, 255); PLUMA_S = (205, 196, 176, 255); PLUMA_AZUL = (110, 150, 214, 255)

def u(ang_deg, l):
    a = math.radians(ang_deg); return (math.cos(a) * l, math.sin(a) * l)

def sumar(a, b): return (a[0] + b[0], a[1] + b[1])

def pluma(ang=-52.0, largo=380):
    im, d, ss = nuevo(W, H)
    t = PUNTA
    fin = sumar(t, u(ang, largo))
    # cálamo (la parte dura) y vexilo (la barba), con dos mitades de color
    pc = sumar(t, u(ang, 110))
    cap(d, t, pc, 4.5, PLUMA_S, ss)
    perp = u(ang + 90, 1)
    def lado(sg, col):
        pts = []
        for i in range(0, 41):
            s = i / 40
            c = sumar(t, u(ang, 110 + (largo - 110) * s))
            anch = 21 * math.sin(math.pi * min(1, s * 0.92 + 0.05)) ** 0.8 * (1 - 0.15 * s)
            pts.append((c[0] + sg * perp[0] * anch, c[1] + sg * perp[1] * anch))
        base = [sumar(t, u(ang, 110))] + pts + [fin]
        d.polygon(p(base, ss), fill=col)
    lado(1, PLUMA); lado(-1, PLUMA_S)
    # raquis
    d.line(p([sumar(t, u(ang, 110)), fin], ss), fill=(150, 140, 120, 255), width=3 * ss)
    # unos cortes de la barba para que no sea una hoja lisa
    for k in range(7):
        s = 0.25 + k * 0.1
        c = sumar(t, u(ang, 110 + (largo - 110) * s))
        d.line(p([c, (c[0] + perp[0] * 26, c[1] + perp[1] * 26 + 6)], ss), fill=PLUMA_AZUL if k % 2 else (255, 255, 255, 255), width=2 * ss)
    # punta con tinta
    cap(d, t, sumar(t, u(ang, 16)), 3.2, (40, 30, 70, 255), ss)
    im = contorno(im, 2.2)
    return reducir(im, W, H)

def difuminar_manga(im, tramo=170):
    """La manga sigue fuera del PNG: se desvanece en los últimos `tramo` px del borde derecho e inferior para que no acabe en un corte recto."""
    a = im.split()[3]; w, h = im.size
    g = Image.new("L", im.size, 255); px = g.load()
    for y in range(h):
        for x in range(w):
            k = min((w - x) / tramo, (h - y) / tramo, 1.0)
            px[x, y] = int(255 * max(0.0, k))
    im.putalpha(ImageChops.multiply(a, g))
    return im

def mano(pose):
    im, d, ss = nuevo(W, H)
    t = PUNTA
    ang = -52.0 if pose != "reposo" else -40.0
    dx = 0
    esc = 1.0
    if pose == "levantada":
        ang = -56.0; esc = 1.0
    # puntos de agarre sobre la pluma
    ag = sumar(t, u(ang, 118))
    # manga y puño: hacia abajo a la derecha
    dirm = 28.0
    muneca = sumar(ag, (110, 82)) if pose != "reposo" else sumar(ag, (118, 74))
    cod = sumar(muneca, u(dirm, 150))
    # manga (trapecio ancho que sale del borde)
    ancho = 62
    pm = u(dirm + 90, 1)
    pts = [(muneca[0] - pm[0] * ancho, muneca[1] - pm[1] * ancho), (muneca[0] + pm[0] * ancho, muneca[1] + pm[1] * ancho),
           (W + 40 + pm[0] * 110, H + 90 + pm[1] * 110), (W + 40 - pm[0] * 110, H + 90 - pm[1] * 110)]
    d.polygon(p(pts, ss), fill=MANGA)
    # sombra de pliegue
    d.polygon(p([(muneca[0], muneca[1]), (muneca[0] + pm[0] * ancho, muneca[1] + pm[1] * ancho),
                 (W + 40 + pm[0] * 110, H + 90 + pm[1] * 110), (W + 60, H + 110)], ss), fill=MANGA_S)
    # puño de la camisa
    pa = (muneca[0] - pm[0] * (ancho + 4), muneca[1] - pm[1] * (ancho + 4)); pb = (muneca[0] + pm[0] * (ancho + 4), muneca[1] + pm[1] * (ancho + 4))
    pa2 = sumar(pa, u(dirm, 30)); pb2 = sumar(pb, u(dirm, 30))
    d.polygon(p([pa, pb, pb2, pa2], ss), fill=PUNO)
    # palma: elipse entre la muñeca y el agarre
    pal = ((ag[0] + muneca[0]) / 2 + 6, (ag[1] + muneca[1]) / 2 + 6)
    elipse(d, pal, 70, 52, PIEL, ss, math.radians(35))
    # dedos que sujetan: pulgar (por encima de la pluma) e índice; resto enroscados debajo
    sube = u(ang - 90, 1)           # perpendicular que mira «arriba» de la pluma
    base_ind = sumar(pal, (-38, -14))
    punta_ind = sumar(ag, (sube[0] * 4 - 10, sube[1] * 4 + 12)) if pose != "levantada" else sumar(ag, (-6, 14))
    cap(d, base_ind, punta_ind, 17, PIEL, ss)
    base_pul = sumar(pal, (-6, -44))
    punta_pul = sumar(sumar(t, u(ang, 128)), (sube[0] * -14, sube[1] * -14 - 4))
    cap(d, base_pul, punta_pul, 15, PIEL_S, ss)
    # los tres dedos de abajo, curvados hacia la palma
    for i, (a0, a1) in enumerate([((-30, 22), (-40, 52)), ((-12, 34), (-18, 66)), ((8, 40), (6, 70))]):
        cap(d, sumar(pal, a0), sumar(pal, a1), 13 - i * 1.2, PIEL, ss)
    # uñas
    for q in (punta_ind, punta_pul):
        elipse(d, sumar(q, (-4, -3)), 6, 4.5, (252, 228, 210, 255), ss)
    im = contorno(im, 2.4)
    # sombra interna de los dedos (una línea por dedo) encima del contorno
    d2 = ImageDraw.Draw(im)
    d2.arc([((pal[0] - 40) * ss), ((pal[1] - 10) * ss), ((pal[0] + 40) * ss), ((pal[1] + 56) * ss)], 20, 160, fill=CONTORNO, width=2 * ss)
    return difuminar_manga(reducir(im, W, H))

if __name__ == "__main__":
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    pl = pluma()
    pl.save(out + "/mano_pluma.png")
    for pose in ("reposo", "escribiendo", "levantada"):
        m = mano(pose)
        m.save(f"{out}/mano_{pose}.png")
        comp = Image.new("RGBA", (W, H), (0, 0, 0, 0)); comp.alpha_composite(pl); comp.alpha_composite(m)
        op = {"reposo": 0.55, "escribiendo": 0.5, "levantada": 0.35}[pose]
        sombra_de(comp, {"reposo": 7, "escribiendo": 6, "levantada": 14}[pose], op).save(f"{out}/sombra_{pose}.png")
    # vista previa compuesta sobre pergamino
    prev = Image.new("RGBA", (W * 3, H), (239, 231, 211, 255))
    for i, pose in enumerate(("reposo", "escribiendo", "levantada")):
        x = i * W
        prev.alpha_composite(Image.open(f"{out}/sombra_{pose}.png"), (x + (6 if pose != "levantada" else 22), 8 if pose != "levantada" else 30))
        prev.alpha_composite(pl, (x, 0))
        prev.alpha_composite(Image.open(f"{out}/mano_{pose}.png"), (x, 0))
        ImageDraw.Draw(prev).ellipse([x + PUNTA[0] - 4, PUNTA[1] - 4, x + PUNTA[0] + 4, PUNTA[1] + 4], outline=(255, 0, 0, 255))
    prev.convert("RGB").save(tempfile.gettempdir() + "/prev_mano.png")
