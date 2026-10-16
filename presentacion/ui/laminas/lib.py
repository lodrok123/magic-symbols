"""Generador de los PNG de la mano con pluma, los iconos de objeto, la bolsa y el diario (Fase 14, Pipeline). Uso: python mano.py <carpeta>  (igual iconos.py, bolsa.py, diario.py). Necesita Pillow."""
"""Utilidades de dibujo para los assets 2D de la Fase 14 (Pipeline). Todo se dibuja a SS× y se reduce: bordes suaves sin depender de nada más que PIL."""
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import math

SS = 4
CONTORNO = (107, 58, 42, 255)      # marrón oscuro del contorno (como objeto_pocion.png)

def nuevo(w, h, ss=SS):
    im = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im), ss

def reducir(im, w, h):
    return im.resize((w, h), Image.LANCZOS)

def p(v, ss):
    return [(x * ss, y * ss) for x, y in v]

def cap(d, a, b, r, col, ss):
    """Cápsula (segmento con extremos redondos) de a a b con radio r."""
    d.line([(a[0]*ss, a[1]*ss), (b[0]*ss, b[1]*ss)], fill=col, width=int(2*r*ss))
    for q in (a, b):
        d.ellipse([(q[0]-r)*ss, (q[1]-r)*ss, (q[0]+r)*ss, (q[1]+r)*ss], fill=col)

def elipse(d, c, rx, ry, col, ss, ang=0):
    if ang == 0:
        d.ellipse([(c[0]-rx)*ss, (c[1]-ry)*ss, (c[0]+rx)*ss, (c[1]+ry)*ss], fill=col)
    else:
        pts = []
        for i in range(48):
            t = i / 48 * 2 * math.pi
            x, y = rx * math.cos(t), ry * math.sin(t)
            pts.append((c[0] + x*math.cos(ang) - y*math.sin(ang), c[1] + x*math.sin(ang) + y*math.cos(ang)))
        d.polygon(p(pts, ss), fill=col)

def contorno(capa, grosor, col=CONTORNO, ss=SS):
    """Devuelve una copia de `capa` con un contorno de `grosor` px (a escala 1) alrededor de todo lo opaco."""
    a = capa.split()[3]
    k = int(grosor * ss) * 2 + 1
    dil = a.filter(ImageFilter.MaxFilter(k if k % 2 else k + 1))
    base = Image.new("RGBA", capa.size, col)
    base.putalpha(dil)
    base.alpha_composite(capa)
    return base

def sombra_de(alfa_img, desenfoque, opacidad):
    """Mancha oscura suave con la silueta de `alfa_img` (RGBA)."""
    a = alfa_img.split()[3].filter(ImageFilter.GaussianBlur(desenfoque))
    a = a.point(lambda v: int(v * opacidad))
    s = Image.new("RGBA", alfa_img.size, (28, 18, 22, 255))
    s.putalpha(a)
    return s
