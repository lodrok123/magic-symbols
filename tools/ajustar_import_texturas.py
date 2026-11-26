"""AJUSTAR IMPORT DE TEXTURAS (26/11/2026): deja las texturas de una carpeta COMPRIMIDAS para la GPU, con mipmaps y las normales como normales.

    python tools/ajustar_import_texturas.py arte/pure_nature/texturas arte/comparativa_bosque/texturas

Toca los .import que Godot crea al importar (hay que importar una vez antes) y después hay que volver a importar:
    tools\\Godot_v4.7.2-stable_win64.exe --headless --path . --import

POR QUÉ. Importadas sin pérdida (compress/mode=0), las 587 texturas de Pure Nature ocupaban 7,9 GB de memoria de vídeo al abrir el
muestrario de LabComparativaBosque: la RTX 3070 (8 GB) se quedaba sin memoria y el laboratorio parecía colgado. Comprimidas (mode=2,
VRAM) ocupan unas 4 veces menos. Las normales (_n / _N) van con compress/normal_map=1 para que la compresión no las estropee.
"""
import os
import re
import sys


def ajustar(carpeta: str) -> int:
	n = 0
	for f in sorted(os.listdir(carpeta)):
		if not f.endswith(".png.import"):
			continue
		ruta = os.path.join(carpeta, f)
		with open(ruta, encoding="utf-8") as fh:
			t = fh.read()
		nuevo = re.sub(r"compress/mode=\d", "compress/mode=2", t)
		nuevo = nuevo.replace("mipmaps/generate=false", "mipmaps/generate=true")
		nuevo = re.sub(r"detect_3d/compress_to=\d", "detect_3d/compress_to=0", nuevo)
		base = f[: -len(".png.import")]
		if base.endswith("_n") or base.endswith("_N"):
			nuevo = re.sub(r"compress/normal_map=\d", "compress/normal_map=1", nuevo)
		if nuevo != t:
			with open(ruta, "w", encoding="utf-8", newline="\n") as fh:
				fh.write(nuevo)
			n += 1
	return n


def main() -> None:
	if len(sys.argv) < 2:
		print(__doc__)
		sys.exit(1)
	for carpeta in sys.argv[1:]:
		print("%s: %d .import cambiados" % (carpeta, ajustar(carpeta)))


if __name__ == "__main__":
	main()
