"""Hoja HOJA_TAMANO_HACES.png (12/11/2026): una fila por elemento (fuego, agua, viento, rayo) y tres columnas (antes, nuevo básico, nuevo máximo),
contra el muro y con la cámara del juego. Las capturas las hace herramientas/prueba_haz_tamano.gd (con ventana):
    godot ... --script res://herramientas/prueba_haz_tamano.gd -- res://docs/capturas/vfx_en_juego/haz_gas_elementos/tamano nuevo
y las de «antes», la misma prueba con el código anterior y la etiqueta «hoy».
    python herramientas/hoja_tamano_haces.py
"""
import json
import os
from PIL import Image, ImageDraw, ImageFont

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DIR = os.path.join(RAIZ, "docs", "capturas", "vfx_en_juego", "haz_gas_elementos")
TAM = os.path.join(DIR, "tamano")
ELEMENTOS = [("fuego", "Fuego"), ("agua", "Agua"), ("viento", "Viento"), ("rayo", "Rayo")]
COLUMNAS = [("hoy", "basico", "Antes (k = 1, cualquier receta)"), ("nuevo", "basico", "Nuevo · básico (1 glifo, k = 0,5)"), ("nuevo", "max", "Nuevo · máximo (6 glifos, k = 1)")]
W, H = 600, 373
M = 12
CAB = 44
IZQ = 110


def fuente(t):
    for f in ["C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf"]:
        if os.path.exists(f):
            return ImageFont.truetype(f, t)
    return ImageFont.load_default()


def medidas(etiqueta):
    p = os.path.join(TAM, etiqueta + ".json")
    return json.load(open(p, encoding="utf-8")) if os.path.exists(p) else {}


def main():
    med = {"hoy": medidas("hoy"), "nuevo": medidas("nuevo")}
    hoja = Image.new("RGB", (IZQ + len(COLUMNAS) * (W + M) + M, CAB + 40 + len(ELEMENTOS) * (H + M) + M), (24, 24, 28))
    d = ImageDraw.Draw(hoja)
    f1, f2, f3 = fuente(26), fuente(20), fuente(16)
    d.text((M, 8), "Tamaño de los haces (12/11): básico = 50 %, máximo = el de antes · contra un muro, cámara del juego", fill=(240, 240, 240), font=f1)
    for c, (_, _, titulo) in enumerate(COLUMNAS):
        d.text((IZQ + c * (W + M) + 8, CAB + 8), titulo, fill=(230, 210, 160), font=f2)
    for r, (e, nombre) in enumerate(ELEMENTOS):
        y = CAB + 40 + r * (H + M)
        d.text((M, y + H // 2 - 14), nombre, fill=(240, 240, 240), font=f1)
        for c, (et, rec, _) in enumerate(COLUMNAS):
            x = IZQ + c * (W + M)
            p = os.path.join(TAM, "%s_%s_%s.jpg" % (et, e, rec))
            if os.path.exists(p):
                hoja.paste(Image.open(p).convert("RGB").resize((W, H), Image.LANCZOS), (x, y))
            m = med[et].get("%s_%s" % (e, rec), {})
            if m:
                txt = "chorro %.2f m · choque %.2f m · %.2f ms GPU" % (m.get("chorro", 0), m.get("lados", 0), m.get("ms", 0))
                d.rectangle((x, y + H - 26, x + W, y + H), fill=(0, 0, 0))
                d.text((x + 8, y + H - 24), txt, fill=(255, 255, 255), font=f3)
    sal = os.path.join(DIR, "HOJA_TAMANO_HACES.png")
    hoja.save(sal)
    print(sal)


if __name__ == "__main__":
    main()
