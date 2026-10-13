"""Genera las hojas de animacion del personaje.

=====================================================================
CONTRATO DE HOJA  (lo lee actor_animator.gd; ver docs/ANIMACION.md)
=====================================================================
  celda          64 x 64
  filas          8, SIEMPRE en este orden:  E SE S SO O NO N NE
  columnas       los fotogramas de ESE clip
  los pies       en y = 45 de la celda  -> foot_offset = 45 - 32 = 13

Cualquier personaje futuro —dibujado, o renderizado desde un modelo 3D—
solo tiene que cumplir esto. El animador no sabe nada del mago: sabe
leer hojas con esta forma. Cambiar de personaje es cambiar los PNG.

El orden de las filas no es un capricho: sale de medir el angulo del
movimiento desde "derecha" girando hacia abajo de 45 en 45, que es lo
que hace _row_for(). Si un pack futuro trae otro orden, se reordenan
las filas al importarlo, NO se toca el animador.
"""
from PIL import Image, ImageDraw
import math

CELL, ROWS = 64, 8
FOOT_Y = 52                                   # suelo dentro de la celda
DIRS = [(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1),(0,-1),(1,-1)]


# --- Paleta, medida del propio Sketch Town -------------------------
# Dos hallazgos que cambian el aspecto por completo:
#   1. NO hay contorno negro. El borde es el mismo color al 57%.
#   2. La cara en sombra solo baja al 89%, no a la mitad.
# Con contorno negro y sombras duras el personaje parecia de otro juego.
BORDE_F  = 0.57
SOMBRA_F = 0.89
LUZ_F    = 1.10

def oscurecer(c, f):
    return tuple(max(0, min(255, int(v*f))) for v in c)

TUNICA = (124, 104, 196)      # violeta: destaca sobre terracota y verde
PIEL   = (232, 186, 148)
BOTA   = (96, 74, 68)
CHISPA = (206, 190, 255)

BORDE_TUNICA = oscurecer(TUNICA, BORDE_F)
BORDE_PIEL   = oscurecer(PIEL, BORDE_F)
BORDE_BOTA   = oscurecer(BOTA, BORDE_F)


def mezclar(c, otro, k):
    return tuple(int(a + (b-a)*k) for a, b in zip(c, otro))


def figura(d, dx, dy, pose):
    """`pose`: paso, bob, brazo, caida, tinte, aura."""
    paso  = pose.get("paso", 0.0)
    bob   = pose.get("bob", 0.0)
    brazo = pose.get("brazo", 0.0)
    caida = pose.get("caida", 0.0)
    tinte = pose.get("tinte", 0.0)
    aura  = pose.get("aura", 0.0)

    tunica = mezclar(TUNICA, (214, 84, 84), tinte)
    borde_t = oscurecer(tunica, BORDE_F)
    sombra_t = oscurecer(tunica, SOMBRA_F)
    luz_t = oscurecer(tunica, LUZ_F)

    cx = CELL/2
    suelo = FOOT_Y + caida*6
    alto = 1.0 - caida*0.5                     # al caer pierde estatura

    de_lado = dy == 0
    de_espaldas = dy < 0

    if aura > 0.01:
        r = 11 + aura*11
        d.ellipse([cx-r, suelo-4-r*0.42, cx+r, suelo-4+r*0.42],
                  outline=mezclar(CHISPA, (255,255,255), aura*0.6), width=2)

    # --- botas ---
    for signo, avance in ((-1, paso), (1, -paso)):
        px = cx + (avance*dx if de_lado else signo*3 + avance*dx*0.5)
        py = suelo + (0 if de_lado else avance*dy*0.3)
        d.ellipse([px-3.5, py-4, px+3.5, py+1], fill=BOTA, outline=BORDE_BOTA)

    # --- tunica: mas alta y estrecha que antes, silueta de mago ---
    ancho = 8 if de_lado else 10.5
    hombros = suelo - 25*alto + bob
    bajo = suelo - 1
    d.polygon([(cx-ancho*0.5, hombros), (cx+ancho*0.5, hombros),
               (cx+ancho, bajo), (cx-ancho, bajo)],
              fill=tunica, outline=borde_t)
    # Lado en sombra: apenas un 11% mas oscuro, como los cubos.
    if dx != 0:
        d.polygon([(cx-ancho*0.5*dx, hombros), (cx-ancho*0.15*dx, hombros),
                   (cx-ancho*0.3*dx, bajo), (cx-ancho*dx, bajo)], fill=sombra_t)

    # --- brazo ---
    if not de_espaldas or brazo > 0.3:
        bx = cx + (dx*5 if de_lado else 7) + brazo*4*(dx if dx else 1)
        by = suelo - 20*alto + bob - brazo*12
        d.ellipse([bx-2.5, by-2.5, bx+2.5, by+2.5], fill=PIEL, outline=BORDE_PIEL)
        if aura > 0.2:
            d.ellipse([bx-2, by-2, bx+2, by+2], fill=CHISPA)

    # --- cabeza ---
    hx = cx + dx*1.5
    hy = suelo - 28*alto + bob
    d.ellipse([hx-5.5, hy-5.5, hx+5.5, hy+5.5], fill=PIEL, outline=BORDE_PIEL)
    if not de_espaldas:
        ojos = [(hx+dx*2.5, hy)] if de_lado else [(hx-2, hy), (hx+2, hy)]
        for ox, oy in ojos:
            if caida > 0.5:
                d.line([ox-1.5, oy, ox+1.5, oy], fill=borde_t, width=1)
            else:
                d.ellipse([ox-1, oy-1, ox+1, oy+1], fill=BORDE_PIEL)

    # --- SOMBRERO PICUDO ---
    # Es lo que mas hace por el personaje: una silueta reconocible de un
    # vistazo y, al inclinarse con la marcha, dice hacia donde mira sin
    # necesidad de verle la cara.
    ala = hy - 4
    punta_x = hx + dx*8 - (0 if dy == 0 else dx*2)
    punta_y = ala - 12*alto - abs(bob)*0.3
    d.polygon([(hx-6.5, ala), (hx+6.5, ala), (punta_x, punta_y)],
              fill=tunica, outline=borde_t)
    d.polygon([(hx-6.5, ala), (punta_x*0.35+hx*0.65, (punta_y+ala)/2),
               (hx-1.5, ala)], fill=luz_t)      # brillo en el ala
    d.ellipse([hx-8.5, ala-2.2, hx+8.5, ala+2.2], fill=tunica, outline=borde_t)


def pose_walk(t):
    return {"paso": math.sin(t*math.tau)*9.0,
            "bob": -abs(math.sin(t*math.tau))*2.5}

def pose_idle(t):
    return {"bob": -abs(math.sin(t*math.pi))*1.5}

def pose_cast(t):
    subida = min(1.0, t*2.2)
    bajada = max(0.0, (t-0.75)/0.25)
    brazo = subida*(1.0-bajada)
    return {"brazo": brazo, "bob": -brazo*2.0,
            "aura": max(0.0, math.sin(min(t,0.85)*math.pi*1.2))}

def pose_hurt(t):
    return {"tinte": 1.0-t*0.6, "bob": 3.0*(1.0-t), "paso": -4.0*(1.0-t)}

def pose_death(t):
    return {"caida": t, "tinte": 0.3*(1.0-t)}


CLIPS = [("hero_walk.png", 8, pose_walk, True), ("hero_idle.png", 4, pose_idle, True),
         ("hero_cast.png", 6, pose_cast, False), ("hero_hurt.png", 3, pose_hurt, False),
         ("hero_death.png", 6, pose_death, False)]

for nombre, cols, pose_de, ciclo in CLIPS:
    hoja = Image.new("RGBA", (cols*CELL, ROWS*CELL), (0,0,0,0))
    for fila, (dx, dy) in enumerate(DIRS):
        for col in range(cols):
            # Un ciclo reparte t en `cols` tramos (el ultimo enlaza con
            # el primero); un disparo llega hasta 1 de verdad.
            t = col/cols if ciclo else col/max(1, cols-1)
            celda = Image.new("RGBA", (CELL, CELL), (0,0,0,0))
            figura(ImageDraw.Draw(celda), dx, dy, pose_de(t))
            hoja.paste(celda, (col*CELL, fila*CELL))
    hoja.save(nombre)
    print(f"{nombre:16s} {hoja.size}  {cols} x {ROWS}")

print(f"\ncontrato: celda {CELL}, pies en y={FOOT_Y}, foot_offset={FOOT_Y - CELL//2}")
