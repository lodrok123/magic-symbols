# Promedia medir_tonos_fuego.py sobre las 6 fotos param_*_cerca_N.png y val_*_cerca_N.png de captura_fuego_parametrico.gd (modo tonos). Uso: python herramientas/medir_tonos_promedio.py <carpeta>
import sys, os, glob, subprocess
sys.path.insert(0, "herramientas")
d = sys.argv[1]
import importlib.util, io, contextlib
spec = importlib.util.spec_from_file_location("m", "herramientas/medir_tonos_fuego.py")
src = open("herramientas/medir_tonos_fuego.py", encoding="utf-8-sig").read().split("for f in sys.argv")[0]
ns = {}
exec(src, ns)
import re
for fig in ["bola", "muro", "pilar", "barrera"]:
    for pre in ["param", "val"]:
        res = []
        for f in sorted(glob.glob(os.path.join(d, "%s_%s_cerca_*.png" % (pre, fig)))):
            r = ns["medir"](f)
            m = re.findall(r"(\d+)%", r)
            res.append([int(x) for x in m])
        n = len(res)
        print(fig, pre, n, "medias rojo-naranja / naranja / amarillo: %.0f / %.0f / %.0f" % tuple(sum(c) / n for c in zip(*res)))


