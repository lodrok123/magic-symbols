import sys, colorsys
from PIL import Image
def medir(f):
    im = Image.open(f).convert("RGB")
    W, H = im.size
    px = im.load()
    n = r = o = y = 0
    for j in range(0, H, 2):
        for i in range(0, W, 2):
            if j < 340 and i < 620: continue   # panel de texto
            R, G, B = px[i, j]
            h, s, v = colorsys.rgb_to_hsv(R/255, G/255, B/255)
            if s <= 0.4 or v < 0.35: continue
            d = h * 360
            if d > 60 or d < 0: continue
            n += 1
            if d < 20: r += 1
            elif d < 40: o += 1
            else: y += 1
    if n == 0: return "sin fuego"
    return "fuego %d px: rojo-naranja %.0f%%  naranja %.0f%%  amarillo %.0f%%" % (n, 100*r/n, 100*o/n, 100*y/n)
for f in sys.argv[1:]:
    print(f.split("\\")[-1], medir(f))
