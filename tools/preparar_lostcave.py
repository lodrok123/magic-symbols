"""PREPARAR LOST CAVE (24/11/2026): saca del zip de Cosmos lo que el juego usa del pack «Stylized Lost Cave» (StylArts / Leartes).

Uso (desde la raíz del repo; solo librería estándar):
    python tools/preparar_lostcave.py "C:/Users/pablo/Downloads/StylizedLostCaveForward.zip"

Qué hace:
  1. Copia las 182 texturas PNG originales a  arte/lostcave/_fuente/texturas/  (carpeta con .gdignore: Godot no la importa;
     el generador las baja a 1K desde aquí).
  2. Lee los 68 materiales de Unity (Art/Materials/*.mat, en texto) y guarda su receta en  arte/lostcave/_fuente/materiales_unity.json
     (texturas por hueco, colores y números). Los nombres de textura salen del mapa GUID -> ruta que dejó Unidot.
  3. Copia las 208 mallas glTF a  arte/lostcave/mallas/  LIMPIAS: sin imágenes ni texturas (el material lo pone el generador),
     sin la animación vacía «Unreal Take» y sin los LOD1/LOD2 (Godot genera sus propios LOD al importar). Se quedan la malla
     (LOD0) y el nodo «*_ConvexHulls», que es la colisión hecha por el autor.

Después: importar en Godot y lanzar  herramientas/generar_piezas_lostcave.gd  (ver arte/lostcave/LEEME.md o tools/preparar_lostcave.cmd).
Lo que sale de aquí NO va a git (licencia de Cosmos: nada de assets sueltos en un repo público). Ver .gitignore.
"""
import json
import os
import re
import sys
import zipfile

RAIZ_ZIP = "Forward_Stylized_Lost_Cave/"
ASSETS = RAIZ_ZIP + "Assets/LeartesStudios/LostCave/Art/"
UNITY = RAIZ_ZIP + ".godot/unidot_temp/Assets/LeartesStudios/LostCave/Art/Materials/"
TAR = RAIZ_ZIP + ".godot/unidot_extracted_tar/"


def _escribir(ruta: str, datos: bytes) -> None:
	os.makedirs(os.path.dirname(ruta), exist_ok=True)
	with open(ruta, "wb") as f:
		f.write(datos)


def _guid_a_nombre(z: zipfile.ZipFile) -> dict:
	"""GUID de Unity -> nombre de archivo sin extensión (T_Arch_BC), sacado de unidot_extracted_tar/<guid>/pathname."""
	mapa = {}
	for i in z.infolist():
		if i.filename.startswith(TAR) and i.filename.endswith("/pathname"):
			ruta = z.read(i).decode("utf8", "replace").strip()
			mapa[i.filename.split("/")[-2]] = ruta.rsplit("/", 1)[-1].rsplit(".", 1)[0]
	return mapa


def _materiales(z: zipfile.ZipFile, guid: dict) -> dict:
	"""Receta de cada .mat de Unity: shader, texturas por hueco, números y colores (lo que el generador traduce a Godot)."""
	mats = {}
	for i in z.infolist():
		if not (i.filename.startswith(UNITY) and i.filename.endswith(".mat")):
			continue
		t = z.read(i).decode("utf8", "replace")
		nombre = re.search(r"m_Name: (\w+)\n  m_Shader", t).group(1)
		sh = re.search(r"m_Shader: \{fileID: -?\d+, guid: (\w+)", t).group(1)
		tex = {}
		for hueco, g in re.findall(r"    - (\w+):\n        m_Texture: \{fileID: \d+, guid: (\w+)", t):
			if not hueco.startswith("_SampleTexture2D") and g in guid:
				tex[hueco] = guid[g]
		num = {k: float(v) for k, v in re.findall(r"    - (\w+): (-?[\d.e-]+)\n", t) if not k.startswith(("_Stencil", "_BUILTIN"))}
		col = {k: [float(a), float(b), float(c), float(d)] for k, a, b, c, d in
			re.findall(r"    - (\w+): \{r: ([-\d.e]+), g: ([-\d.e]+), b: ([-\d.e]+), a: ([-\d.e]+)\}", t) if not k.startswith("_BUILTIN")}
		mats[nombre] = {"shader": guid.get(sh, "?"), "tex": tex, "num": num, "color": col}
	return mats


def _limpiar_gltf(g: dict) -> dict:
	"""Quita imágenes, texturas, animaciones y las mallas de LOD1+ (el nodo se queda vacío para no renumerar)."""
	for clave in ("images", "textures", "samplers", "animations"):
		g.pop(clave, None)
	for m in g.get("materials", []):
		pbr = m.get("pbrMetallicRoughness", {})
		for k in ("baseColorTexture", "metallicRoughnessTexture"):
			pbr.pop(k, None)
		for k in ("normalTexture", "emissiveTexture", "occlusionTexture"):
			m.pop(k, None)
	for n in g.get("nodes", []):
		if re.search(r"_LOD[1-9]$", n.get("name", "")):
			n.pop("mesh", None)
	return g


def main() -> int:
	if len(sys.argv) < 2:
		print(__doc__)
		return 1
	zip_ruta = sys.argv[1]
	repo = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
	destino = os.path.join(repo, "arte", "lostcave")
	fuente = os.path.join(destino, "_fuente")
	z = zipfile.ZipFile(zip_ruta)
	nombres = z.namelist()
	if ASSETS + "Meshes/SM_Arch.gltf" not in nombres:
		print("FALLO  este zip no parece el de Stylized Lost Cave convertido con Unidot (falta %s)" % (ASSETS + "Meshes/SM_Arch.gltf"))
		return 1
	_escribir(os.path.join(fuente, ".gdignore"), b"")

	n_tex = 0
	for n in nombres:
		if n.startswith(ASSETS + "Textures/") and n.lower().endswith(".png") and ".." not in n:
			_escribir(os.path.join(fuente, "texturas", os.path.basename(n)), z.read(n))
			n_tex += 1

	mats = _materiales(z, _guid_a_nombre(z))
	with open(os.path.join(fuente, "materiales_unity.json"), "w", encoding="utf8") as f:
		json.dump(mats, f, indent=1, sort_keys=True, ensure_ascii=False)

	n_mallas = 0
	for n in nombres:
		if n.startswith(ASSETS + "Meshes/") and n.endswith(".gltf") and ".." not in n:
			base = os.path.basename(n)[:-5]
			g = _limpiar_gltf(json.loads(z.read(n).decode("utf8")))
			for b in g.get("buffers", []):
				uri = b.get("uri", "")
				if uri and not uri.startswith("data:"):
					_escribir(os.path.join(destino, "mallas", os.path.basename(uri)), z.read(ASSETS + "Meshes/" + uri))
					b["uri"] = os.path.basename(uri)
			_escribir(os.path.join(destino, "mallas", base + ".gltf"), json.dumps(g, ensure_ascii=False).encode("utf8"))
			n_mallas += 1

	print("OK     texturas %d · materiales %d · mallas %d  ->  %s" % (n_tex, len(mats), n_mallas, destino))
	return 0


if __name__ == "__main__":
	sys.exit(main())
