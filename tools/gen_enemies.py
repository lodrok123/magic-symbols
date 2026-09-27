"""Sprites de arquero, guerrero y flecha, con la paleta de Sketch Town.

Misma regla que el mago: NO hay contorno negro —el borde es el mismo
color al 57%— y la cara en sombra solo baja al 89%. Lo que distingue a
los enemigos del jugador no es el estilo, es el COLOR: el mago es
violeta, el guerrero rojo y el arquero verde. Que se lean de un vistazo
importa mas que el detalle.
"""
from PIL import Image, ImageDraw
import math

CELL, FOOT_Y = 64, 52
BORDE_F, SOMBRA_F = 0.57, 0.89

def osc(c, f): return tuple(max(0, min(255, int(v*f))) for v in c)

PIEL = (232, 186, 148)
BOTA = (96, 74, 68)


def cuerpo(d, base, cx, suelo, ancho, alto, casco):
    borde, sombra = osc(base, BORDE_F), osc(base, SOMBRA_F)
    # botas
    for s in (-1, 1):
        d.ellipse([cx+s*3-3.5, suelo-4, cx+s*3+3.5, suelo+1],
                  fill=BOTA, outline=osc(BOTA, BORDE_F))
    # cuerpo
    hombros = suelo - alto
    d.polygon([(cx-ancho*0.5, hombros), (cx+ancho*0.5, hombros),
               (cx+ancho, suelo-1), (cx-ancho, suelo-1)],
              fill=base, outline=borde)
    d.polygon([(cx-ancho*0.5, hombros), (cx-ancho*0.2, hombros),
               (cx-ancho*0.35, suelo-1), (cx-ancho, suelo-1)], fill=sombra)
    # cabeza
    hy = hombros - 6
    d.ellipse([cx-5.5, hy-5.5, cx+5.5, hy+5.5], fill=PIEL, outline=osc(PIEL, BORDE_F))
    for ox in (-2, 2):
        d.ellipse([cx+ox-1, hy-1, cx+ox+1, hy+1], fill=osc(PIEL, BORDE_F))
    if casco:
        d.chord([cx-6.5, hy-7.5, cx+6.5, hy+4], 180, 360, fill=base, outline=borde)
    return cx, hy


def arquero():
    im = Image.new("RGBA", (CELL, CELL), (0,0,0,0))
    d = ImageDraw.Draw(im)
    VERDE = (86, 140, 76)
    cx, hy = cuerpo(d, VERDE, CELL/2, FOOT_Y, 9, 24, False)
    # capucha en punta corta: silueta de arquero, no de mago
    d.polygon([(cx-7, hy-2), (cx+7, hy-2), (cx+2, hy-13)],
              fill=VERDE, outline=osc(VERDE, BORDE_F))
    # arco: el rasgo que lo identifica a 64px
    madera = (132, 96, 56)
    d.arc([cx+4, hy+2, cx+18, hy+24], -80, 80, fill=osc(madera, BORDE_F), width=3)
    d.line([cx+11, hy+4, cx+11, hy+22], fill=(220, 214, 200), width=1)
    im.save("archer.png"); print("archer.png", im.size)


def guerrero():
    im = Image.new("RGBA", (CELL, CELL), (0,0,0,0))
    d = ImageDraw.Draw(im)
    ROJO = (168, 72, 62)
    cx, hy = cuerpo(d, ROJO, CELL/2, FOOT_Y, 11, 22, True)
    # espada al costado
    acero = (198, 202, 210)
    d.line([cx+13, hy+22, cx+13, hy+6], fill=osc(acero, BORDE_F), width=4)
    d.line([cx+13, hy+21, cx+13, hy+7], fill=acero, width=2)
    d.line([cx+9, hy+8, cx+17, hy+8], fill=osc(acero, BORDE_F), width=2)
    im.save("warrior.png"); print("warrior.png", im.size)


def flecha():
    # Apunta a la DERECHA en reposo: arrow.gd la gira segun su direccion,
    # y el angulo cero de Godot es hacia la derecha.
    W, H = 24, 8
    im = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(im)
    madera, punta = (132, 96, 56), (198, 202, 210)
    d.line([2, H/2, W-6, H/2], fill=madera, width=2)
    d.polygon([(W-8, 1), (W-1, H/2), (W-8, H-1)], fill=punta,
              outline=osc(punta, BORDE_F))
    d.line([2, 1, 6, H/2], fill=(220, 214, 200), width=1)
    d.line([2, H-1, 6, H/2], fill=(220, 214, 200), width=1)
    im.save("arrow.png"); print("arrow.png", im.size)


arquero(); guerrero(); flecha()
