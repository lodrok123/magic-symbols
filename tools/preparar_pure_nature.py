"""PREPARAR PURE NATURE (26/11/2026): lleva a Godot lo exportado de Unreal de TODOS los packs «Pure Nature» de BK (Fab).

Paso previo (en Unreal, sin abrir el editor): tools/ue_exportar_pure_nature.py -> E:/ue_proyectos/PureNature_export

Uso (desde la raíz del repo):
    python tools/preparar_pure_nature.py "E:/ue_proyectos/PureNature_export"

Copia las mallas FBX a arte/pure_nature/mallas/ y las texturas a arte/pure_nature/texturas/ en PNG a 2K como máximo (el tamaño con el
que se calibró en LabComparativaBosque). Las normales de Unreal vienen en convenio DirectX: se les invierte el verde para Godot (OpenGL).
Solo convierte lo que falta (añadir un pack no rehace los demás). Nada de esto va a git (licencia de Fab).
Después: importar en Godot y herramientas/generar_piezas_pure_nature.gd (ver arte/pure_nature/LEEME.md).
"""
import json
import os
import shutil
import sys

from PIL import Image

DESTINO = os.path.join("arte", "pure_nature")
LADO_MAX = 2048


def main() -> None:
	if len(sys.argv) < 2:
		print(__doc__)
		sys.exit(1)
	origen = sys.argv[1]
	for d in ("mallas", "texturas"):
		os.makedirs(os.path.join(DESTINO, d), exist_ok=True)
	with open(os.path.join(origen, "informe.json"), encoding="utf-8") as f:
		informe = json.load(f)
	nm = 0
	for f in sorted(os.listdir(os.path.join(origen, "mallas"))):
		dst = os.path.join(DESTINO, "mallas", f)
		if not os.path.exists(dst):
			shutil.copyfile(os.path.join(origen, "mallas", f), dst)
			nm += 1
	normales = set()
	for m in informe["materiales"].values():
		for param, tex in m["texturas"].items():
			if tex and "normal" in param.lower():
				normales.add(tex)
	nt = 0
	for f in sorted(os.listdir(os.path.join(origen, "texturas"))):
		nombre = os.path.splitext(f)[0]
		dst = os.path.join(DESTINO, "texturas", nombre + ".png")
		if os.path.exists(dst):
			continue
		im = Image.open(os.path.join(origen, "texturas", f))
		im.load()
		im = im.convert("RGBA" if im.mode in ("RGBA", "LA", "P") else "RGB")
		if max(im.size) > LADO_MAX:
			k = LADO_MAX / max(im.size)
			im = im.resize((max(1, round(im.size[0] * k)), max(1, round(im.size[1] * k))), Image.LANCZOS)
		if nombre in normales or nombre.endswith("_n") or nombre.endswith("_N"):
			r, g, b = im.split()[:3]
			im = Image.merge("RGB", (r, g.point(lambda v: 255 - v), b))
		im.save(dst)
		nt += 1
	shutil.copyfile(os.path.join(origen, "informe.json"), os.path.join(DESTINO, "informe.json"))
	print("nuevas: mallas %d, texturas %d · packs %s" % (nm, nt, informe.get("packs")))


if __name__ == "__main__":
	main()
