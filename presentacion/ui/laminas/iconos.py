from lib import *
import tempfile
import sys, os, json
C = CONTORNO
def col(t, k=1.0): return tuple(int(max(0, min(255, v * 255 * k))) for v in t) + (255,)
def claro(c, f=0.35): return tuple(int(v + (255 - v) * f) for v in c[:3]) + (255,)
def oscuro(c, f=0.25): return tuple(int(v * (1 - f)) for v in c[:3]) + (255,)

def brillo(d, c, r, ss): elipse(d, c, r, r * 0.7, (255, 255, 255, 190), ss, -0.6)

def flor(d, c, ss, color, centro=(255, 214, 90, 255)):
    for i in range(5):
        a = math.radians(-90 + i * 72)
        elipse(d, (c[0] + math.cos(a) * 17, c[1] + math.sin(a) * 17), 15, 11, color, ss, a)
    elipse(d, c, 9, 9, centro, ss)
    elipse(d, (c[0] - 2, c[1] - 3), 3, 3, (255, 255, 255, 200), ss)

def tallo(d, ss, base=(64, 112), top=(64, 74), verde=(88, 170, 96, 255)):
    cap(d, base, top, 4, verde, ss)
    d.polygon(p([(64, 100), (86, 86), (80, 104)], ss), fill=verde)
    d.polygon(p([(62, 92), (42, 80), (48, 98)], ss), fill=verde)

def seta(d, ss, color):
    cap(d, (64, 82), (64, 104), 13, (240, 226, 196, 255), ss)
    d.pieslice([22*ss, 28*ss, 106*ss, 112*ss], 180, 360, fill=color)
    d.rectangle([22*ss, 70*ss, 106*ss, 76*ss], fill=oscuro(color, 0.2))
    for q in ((46, 54), (76, 48), (64, 62)): elipse(d, q, 5, 4, (255, 255, 255, 215), ss)

def baya(d, ss, color):
    for q, r in (((46, 82), 19), ((80, 78), 19), ((63, 56), 19)):
        elipse(d, q, r, r, color, ss); elipse(d, (q[0] - 6, q[1] - 7), 5, 4, (255, 255, 255, 200), ss)
    cap(d, (63, 38), (66, 22), 3, (90, 140, 70, 255), ss)
    d.polygon(p([(66, 24), (92, 16), (84, 38)], ss), fill=(98, 170, 84, 255))

def hoja(d, ss, color):
    cap(d, (30, 108), (92, 28), 4, oscuro(color, 0.35), ss)
    for i in range(7):
        s = 0.12 + i * 0.12
        c = (30 + 62 * s, 108 - 80 * s); r = 24 * (1 - abs(s - 0.45) * 0.9)
        elipse(d, (c[0] + 7, c[1] + 8), r, 7, color, ss, 0.9)
        elipse(d, (c[0] - 8, c[1] - 6), r, 7, claro(color, 0.12), ss, 0.9)

def piedra(d, ss, color):
    d.polygon(p([(26, 96), (22, 70), (40, 42), (72, 34), (100, 54), (106, 86), (86, 104), (46, 106)], ss), fill=color)
    d.polygon(p([(40, 42), (72, 34), (100, 54), (70, 62), (46, 70)], ss), fill=claro(color, 0.25))
    d.polygon(p([(106, 86), (86, 104), (46, 106), (70, 86)], ss), fill=oscuro(color, 0.2))

def raiz(d, ss, color):
    pts = [(30, 100), (44, 82), (58, 80), (66, 62), (82, 54), (96, 36)]
    for a, b in zip(pts, pts[1:]): cap(d, a, b, 9, color, ss)
    for a, b in (((58, 80), (44, 100)), ((66, 62), (50, 52)), ((82, 54), (100, 66))): cap(d, a, b, 5, oscuro(color, 0.1), ss)
    cap(d, (34, 98), (62, 76), 2.5, claro(color, 0.3), ss)

def cristal(d, ss, color):
    d.polygon(p([(64, 18), (92, 46), (84, 104), (44, 104), (36, 46)], ss), fill=color)
    d.polygon(p([(64, 18), (92, 46), (64, 52)], ss), fill=claro(color, 0.4))
    d.polygon(p([(64, 52), (92, 46), (84, 104), (64, 104)], ss), fill=oscuro(color, 0.2))
    d.polygon(p([(40, 100), (20, 74), (36, 62), (46, 100)], ss), fill=claro(color, 0.1))
    d.line(p([(64, 18), (64, 104)], ss), fill=(255, 255, 255, 120), width=2 * ss)

def particulas(d, ss, color):
    import random; r = random.Random(4)
    for i in range(16):
        q = (24 + r.random() * 80, 24 + r.random() * 80); elipse(d, q, 6 + r.random() * 6, 6 + r.random() * 6, color if i % 2 else claro(color, 0.35), ss)

def petalos(d, ss, color):
    for i in range(5):
        a = math.radians(i * 72 + 12)
        elipse(d, (64 + math.cos(a) * 28, 64 + math.sin(a) * 28), 17, 10, color if i % 2 else claro(color, 0.3), ss, a + 1.2)

# efectos superpuestos
def fx_rayo(d, ss):
    d.polygon(p([(84, 12), (58, 52), (74, 52), (50, 98), (96, 40), (78, 40)], ss), fill=(255, 238, 90, 255))
def fx_brasa(d, ss):
    for q in ((92, 30), (106, 54), (86, 14)): elipse(d, q, 4, 4, (255, 170, 60, 255), ss)
def fx_hielo(d, ss):
    for q in ((26, 30), (104, 34), (98, 94)):
        for a in (0, 60, 120): cap(d, (q[0] - math.cos(math.radians(a)) * 9, q[1] - math.sin(math.radians(a)) * 9), (q[0] + math.cos(math.radians(a)) * 9, q[1] + math.sin(math.radians(a)) * 9), 1.6, (230, 250, 255, 255), ss)
def fx_gotas(d, ss):
    for q in ((28, 34), (102, 40), (96, 98)):
        d.polygon(p([(q[0], q[1] - 12), (q[0] + 8, q[1] + 2), (q[0] - 8, q[1] + 2)], ss), fill=(120, 190, 255, 255)); elipse(d, (q[0], q[1] + 3), 8, 8, (120, 190, 255, 255), ss)
def fx_hollin(d, ss):
    cap(d, (50, 60), (70, 84), 1.6, (30, 26, 26, 255), ss); cap(d, (70, 84), (62, 100), 1.6, (30, 26, 26, 255), ss)
def fx_iman(d, ss):
    d.arc([76*ss, 10*ss, 112*ss, 46*ss], 180, 360, fill=(200, 60, 60, 255), width=7 * ss); cap(d, (78, 28), (78, 40), 3.5, (200, 60, 60, 255), ss); cap(d, (110, 28), (110, 40), 3.5, (210, 210, 220, 255), ss)

def fx_eco(d, ss):
    for r in (46, 56):
        d.arc([(64 - r) * ss, (52 - r) * ss, (64 + r) * ss, (52 + r) * ss], 200, 250, fill=(150, 215, 255, 255), width=4 * ss)
        d.arc([(64 - r) * ss, (52 - r) * ss, (64 + r) * ss, (52 + r) * ss], 290, 340, fill=(150, 215, 255, 255), width=4 * ss)
def fx_epico(d, ss):
    # destellos morados en cuatro puntas: la calidad épica (PLAN_PULSO_RESONANTE §7)
    for q, r in (((24, 30), 11), ((104, 24), 8), ((100, 96), 10)):
        d.polygon(p([(q[0], q[1] - r), (q[0] + r * 0.3, q[1] - r * 0.3), (q[0] + r, q[1]), (q[0] + r * 0.3, q[1] + r * 0.3),
                     (q[0], q[1] + r), (q[0] - r * 0.3, q[1] + r * 0.3), (q[0] - r, q[1]), (q[0] - r * 0.3, q[1] - r * 0.3)], ss), fill=(178, 102, 255, 255))
def fx_epico_eco(d, ss): fx_eco(d, ss); fx_epico(d, ss)

# id → (forma, color de Objetos.DATOS, efecto)
ICONOS = {
 "lavanda": ("flor", (0.7, 0.55, 0.95), None), "baya": ("baya", (0.85, 0.2, 0.35), None), "helecho": ("hoja", (0.35, 0.75, 0.4), None),
 "piedra": ("piedra", (0.62, 0.62, 0.66), None), "flor_silvestre": ("flor", (1.0, 0.9, 0.4), None),
 "seta": ("seta", (0.85, 0.75, 0.6), None), "seta_electrificada": ("seta", (1.0, 0.95, 0.35), fx_rayo), "seta_asada": ("seta", (0.85, 0.45, 0.2), fx_brasa),
 "seta_helada": ("seta", (0.6, 0.9, 1.0), fx_hielo), "seta_humeda": ("seta", (0.45, 0.65, 0.95), fx_gotas), "esporas": ("esporas", (0.75, 0.9, 0.6), None),
 "flor_luna": ("flor", (0.85, 0.85, 1.0), None), "flor_ardiente": ("flor", (1.0, 0.5, 0.2), fx_brasa), "flor_rocio": ("flor", (0.4, 0.8, 1.0), fx_gotas),
 "flor_chispa": ("flor", (1.0, 0.95, 0.4), fx_rayo), "petalos": ("petalos", (1.0, 0.75, 0.9), None), "flor_escarcha": ("flor", (0.7, 0.95, 1.0), fx_hielo),
 "raiz": ("raiz", (0.6, 0.45, 0.3), None), "raiz_cenizas": ("raiz", (0.3, 0.27, 0.27), fx_hollin), "raiz_hinchada": ("raiz", (0.5, 0.7, 0.9), fx_gotas),
 "raiz_magnetica": ("raiz", (0.8, 0.85, 1.0), fx_iman), "cristal_tierra": ("cristal", (0.7, 0.55, 0.3), None),
 # Materiales de la Cueva (docs/MATERIALES_CUEVA.md): comunes sin efecto de calidad; los épicos, con destellos morados
 "seta_resonante": ("seta", (0.6, 0.85, 1.0), fx_eco), "alga_cueva": ("hoja", (0.35, 0.7, 0.62), None), "alga_seca": ("hoja", (0.68, 0.6, 0.38), None),
 "mineral_veta": ("piedra", (0.5, 0.58, 0.78), None), "esquirla_cristal": ("cristal", (0.78, 0.92, 1.0), None), "basalto": ("piedra", (0.36, 0.35, 0.38), None),
 "colmillo_goblin": ("raiz", (0.92, 0.88, 0.74), None),
 "nucleo_eco": ("cristal", (0.72, 0.42, 1.0), fx_epico_eco), "geoda_resonante": ("cristal", (0.62, 0.36, 0.95), fx_epico),
}

def dibujar(forma, c, fx):
    im, d, ss = nuevo(128, 128)
    capa, dc, _ = nuevo(128, 128)
    if forma == "flor":
        tallo(dc, ss); flor(dc, (64, 52), ss, c)
    elif forma == "seta": seta(dc, ss, c)
    elif forma == "baya": baya(dc, ss, c)
    elif forma == "hoja": hoja(dc, ss, c)
    elif forma == "piedra": piedra(dc, ss, c)
    elif forma == "raiz": raiz(dc, ss, c)
    elif forma == "cristal": cristal(dc, ss, c)
    elif forma == "esporas": particulas(dc, ss, c)
    elif forma == "petalos": petalos(dc, ss, c)
    capa = contorno(capa, 2.4)
    if fx:
        capf, df, _ = nuevo(128, 128); fx(df, ss); capf = contorno(capf, 1.8); capa.alpha_composite(capf)
    # sombrita en el suelo
    sh, ds, _ = nuevo(128, 128); elipse(ds, (64, 116), 34, 6, (60, 40, 30, 70), ss)
    im.alpha_composite(sh); im.alpha_composite(capa)
    return reducir(im, 128, 128)

if __name__ == "__main__":
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    for k, (f, c, fx) in ICONOS.items():
        dibujar(f, col(c), fx).save(f"{out}/objeto_{k}.png")
    hoja_ = Image.new("RGBA", (128 * 6, 128 * 4), (239, 231, 211, 255))
    for i, k in enumerate(ICONOS):
        hoja_.alpha_composite(Image.open(f"{out}/objeto_{k}.png"), ((i % 6) * 128, (i // 6) * 128))
    hoja_.convert("RGB").save(tempfile.gettempdir() + "/prev_iconos.png")
