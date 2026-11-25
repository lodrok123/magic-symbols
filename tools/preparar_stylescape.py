"""PREPARAR STYLESCAPE: RUINS (25/11/2026, PRUEBA): lleva a Godot lo exportado de Unreal del pack «Stylescape: Ruins» (Fab).

Paso previo (en Unreal, sin abrir el editor): tools/ue_exportar_stylescape.py exporta todas las mallas a FBX y las texturas a TGA/PNG
en E:/ue_proyectos/StylescapeRuins_export (con informe.json: qué material usa cada malla y qué texturas cada material).

Uso (desde la raíz del repo):
    python tools/preparar_stylescape.py "E:/ue_proyectos/StylescapeRuins_export"

Qué hace:
  1. Copia las mallas FBX (menos la rampa del escaparate, SM_Slope) a  arte/stylescape/mallas/.
  2. Baja las texturas que usan las piezas a 1K como máximo (PNG) en  arte/stylescape/texturas/. Las normales de Unreal vienen
     en convenio DirectX (verde hacia abajo): se les invierte el canal verde para el convenio de Godot (OpenGL).
  3. Copia informe.json e informe_padres.json (las recetas de material) a arte/stylescape/.
Nada de esto va a git (licencia de Fab: nada de assets sueltos en un repo público). Ver .gitignore.
"""
import json
import os
import shutil
import sys

from PIL import Image

DESTINO = os.path.join("arte", "stylescape")
LADO_MAX = 1024
FUERA = {"SM_Slope"}
TEXTURAS = [
	"T_WallTrim_NoMoss_D", "T_WallTrim_NoMoss_N", "T_WallTrim_NoMoss_AORS",
	"T_WallTrim_Dmg_D", "T_WallTrim_Dmg_N", "T_WallTrim_Dmg_AORM",
	"T_StoneRuins_D", "T_StoneRuins_N", "T_StoneRuins_AORM",
	"T_Wood_D", "T_Wood_N", "T_Wood_AORM",
	"T_RockyMoss_D", "T_RockyMoss_N",
	"T_IvyBranch_01_D", "T_IvyBranch_02_D", "T_IvyLeaves_D",
]


def _fuente(carpeta: str, nombre: str) -> str:
	for ext in (".tga", ".png", ".bmp"):
		r = os.path.join(carpeta, "texturas", nombre + ext)
		if os.path.exists(r):
			return r
	raise FileNotFoundError(nombre)


def main() -> None:
	if len(sys.argv) < 2:
		print(__doc__)
		sys.exit(1)
	origen = sys.argv[1]
	os.makedirs(os.path.join(DESTINO, "mallas"), exist_ok=True)
	os.makedirs(os.path.join(DESTINO, "texturas"), exist_ok=True)
	n = 0
	for f in sorted(os.listdir(os.path.join(origen, "mallas"))):
		if f.endswith(".fbx") and f[:-4] not in FUERA:
			shutil.copyfile(os.path.join(origen, "mallas", f), os.path.join(DESTINO, "mallas", f))
			n += 1
	print("mallas: %d" % n)
	for t in TEXTURAS:
		im = Image.open(_fuente(origen, t))
		im.load()
		modo = "RGBA" if im.mode in ("RGBA", "LA", "P") and t.startswith("T_Ivy") else "RGB"
		im = im.convert(modo)
		if max(im.size) > LADO_MAX:
			k = LADO_MAX / max(im.size)
			im = im.resize((max(1, round(im.size[0] * k)), max(1, round(im.size[1] * k))), Image.LANCZOS)
		if t.endswith("_N"):
			r, g, b = im.split()[:3]
			g = g.point(lambda v: 255 - v)
			im = Image.merge("RGB", (r, g, b))
		im.save(os.path.join(DESTINO, "texturas", t + ".png"))
		print("textura: %s %dx%d %s" % (t, im.size[0], im.size[1], modo))
	for j in ("informe.json", "informe_padres.json"):
		shutil.copyfile(os.path.join(origen, j), os.path.join(DESTINO, j))
	print("listo: %s" % DESTINO)


if __name__ == "__main__":
	main()
