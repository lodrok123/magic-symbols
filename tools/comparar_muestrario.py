"""COMPARAR MUESTRARIO (26/11/2026): pone lado a lado, por pack, la foto de Unreal y la de Godot del muestrario Pure Nature.

    python tools/comparar_muestrario.py

Lee docs/capturas/comparativa_ue_godot/unreal_Cam_<Pack>.png (tools/ue_capturar_prueba_bosque.py muestrario) y muestrario_<pack>.png
(LabComparativaBosque -- --muestrario). Deja comparativa_muestrario_<pack>.png (Unreal izquierda | Godot derecha) y todas_muestrario.png.
Imprime, por pack, el color medio de cada foto (para ver de un vistazo si una sale más oscura, más azul…).
"""
import json
import os

from PIL import Image, ImageStat

D = os.path.join("docs", "capturas", "comparativa_ue_godot")


def main() -> None:
	with open(os.path.join(D, "muestrario.json"), encoding="utf-8") as f:
		camaras = [c["nombre"] for c in json.load(f)["camaras"]]
	parejas = []
	for cam in camaras:
		pack = cam[len("Cam_"):]
		ue = os.path.join(D, "unreal_%s.png" % cam)
		go = os.path.join(D, "muestrario_%s.png" % pack.lower())
		if not (os.path.exists(ue) and os.path.exists(go)):
			print("falta alguna foto de", pack)
			continue
		a = Image.open(ue).convert("RGB").resize((960, 540), Image.LANCZOS)
		b = Image.open(go).convert("RGB").resize((960, 540), Image.LANCZOS)
		t = Image.new("RGB", (1920, 540))
		t.paste(a, (0, 0))
		t.paste(b, (960, 0))
		t.save(os.path.join(D, "comparativa_muestrario_%s.png" % pack.lower()))
		parejas.append(t)
		ma = [round(x) for x in ImageStat.Stat(a).mean]
		mb = [round(x) for x in ImageStat.Stat(b).mean]
		print("%-14s Unreal %s   Godot %s" % (pack, ma, mb))
	if parejas:
		todo = Image.new("RGB", (1920, 540 * len(parejas)))
		for i, p in enumerate(parejas):
			todo.paste(p, (0, 540 * i))
		todo.resize((1280, 360 * len(parejas)), Image.LANCZOS).save(os.path.join(D, "todas_muestrario.png"))


if __name__ == "__main__":
	main()
