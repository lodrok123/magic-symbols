"""PREPARAR PRUEBA BOSQUE (26/11/2026): lleva a Godot lo exportado de Unreal para la escena de comparación «bosque con ruinas».

Pasos previos (en Unreal, sin abrir el editor):
    tools/ue_montar_prueba_bosque.py     monta la escena en Unreal y deja docs/capturas/comparativa_ue_godot/escena.json
    tools/ue_exportar_prueba_bosque.py   exporta sus mallas y texturas a E:/ue_proyectos/PruebaBosque_export

Uso (desde la raíz del repo):
    python tools/preparar_prueba_bosque.py "E:/ue_proyectos/PruebaBosque_export"

Copia las mallas FBX a arte/comparativa_bosque/mallas/ y las texturas a arte/comparativa_bosque/texturas/ en PNG, a 2K como
máximo (para comparar con Unreal sin que la resolución sea la diferencia). Las normales de Unreal vienen en convenio DirectX
(verde hacia abajo): se les invierte el verde para Godot (OpenGL). Nada de esto va a git (licencia de Fab).
"""
import json
import os
import shutil
import sys

from PIL import Image

DESTINO = os.path.join("arte", "comparativa_bosque")
LADO_MAX = 2048


def main() -> None:
	if len(sys.argv) < 2:
		print(__doc__)
		sys.exit(1)
	origen = sys.argv[1]
	os.makedirs(os.path.join(DESTINO, "mallas"), exist_ok=True)
	os.makedirs(os.path.join(DESTINO, "texturas"), exist_ok=True)
	with open(os.path.join(origen, "informe.json"), encoding="utf-8") as f:
		informe = json.load(f)
	for f in sorted(os.listdir(os.path.join(origen, "mallas"))):
		shutil.copyfile(os.path.join(origen, "mallas", f), os.path.join(DESTINO, "mallas", f))
	print("mallas: %d" % len(os.listdir(os.path.join(DESTINO, "mallas"))))
	normales = set()
	for m in informe["materiales"].values():
		for param, tex in m["texturas"].items():
			if tex and "normal" in param.lower():
				normales.add(tex)
	for f in sorted(os.listdir(os.path.join(origen, "texturas"))):
		nombre = os.path.splitext(f)[0]
		im = Image.open(os.path.join(origen, "texturas", f))
		im.load()
		im = im.convert("RGBA" if im.mode in ("RGBA", "LA", "P") else "RGB")
		if max(im.size) > LADO_MAX:
			k = LADO_MAX / max(im.size)
			im = im.resize((max(1, round(im.size[0] * k)), max(1, round(im.size[1] * k))), Image.LANCZOS)
		if nombre in normales or nombre.endswith("_N") or "_Normal" in nombre:
			canales = im.split()
			r, g, b = canales[:3]
			im = Image.merge("RGB", (r, g.point(lambda v: 255 - v), b))
		im.save(os.path.join(DESTINO, "texturas", nombre + ".png"))
	print("texturas: %d" % len(os.listdir(os.path.join(DESTINO, "texturas"))))
	shutil.copyfile(os.path.join(origen, "informe.json"), os.path.join(DESTINO, "informe.json"))
	shutil.copyfile(os.path.join("docs", "capturas", "comparativa_ue_godot", "escena.json"), os.path.join(DESTINO, "escena.json"))
	print("listo: %s" % DESTINO)


if __name__ == "__main__":
	main()
