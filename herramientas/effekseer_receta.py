"""Saca la «receta» de un efecto de Effekseer (.efkefc) sin instalar el editor.

El .efkefc guarda, en el bloque EDIT, el XML del editor comprimido con zlib y
codificado como tablas de nombres y valores (formato de Effekseer:
Dev/Editor/EffekseerCore/IO/EfkEfc.cs, clase EfkEfcXml). Aquí se deshace y se
escribe el XML legible: capas (nodos), tiempos, curvas, escalas, colores y
texturas. Solo se guardan los valores que el autor cambió; el resto son los
valores por defecto del editor.

Uso:
    python herramientas/effekseer_receta.py efecto.efkefc [más.efkefc ...] --salida carpeta

Escribe <carpeta>/<nombre>.xml (el XML completo) y <carpeta>/<nombre>_plano.txt
(cada capa con sus valores, una línea por parámetro) por cada efecto, y muestra
un resumen de capas.
Unidades de Effekseer: tiempos en fotogramas a 60 fps; colores 0-255;
FadeIn/FadeOut en fotogramas.
"""

import argparse
import os
import struct
import sys
import zlib
from xml.dom import minidom
import xml.etree.ElementTree as ET


def _bloques(datos: bytes) -> dict:
    if datos[:4] != b"EFKE":
        raise ValueError("no es un .efkefc (falta la cabecera EFKE)")
    p = 8
    bloques = {}
    while p < len(datos):
        nombre = datos[p:p + 4].decode("ascii", "replace")
        tam = struct.unpack_from("<i", datos, p + 4)[0]
        bloques[nombre] = datos[p + 8:p + 8 + tam]
        p += 8 + tam
    return bloques


class _Lector:
    def __init__(self, datos: bytes):
        self.d = datos
        self.p = 0

    def i16(self) -> int:
        v = struct.unpack_from("<h", self.d, self.p)[0]
        self.p += 2
        return v

    def booleano(self) -> bool:          # en el formato de Effekseer los bool ocupan 4 bytes
        v = struct.unpack_from("<i", self.d, self.p)[0]
        self.p += 4
        return v != 0

    def texto(self) -> str:
        n = struct.unpack_from("<H", self.d, self.p)[0]
        self.p += 2
        s = self.d[self.p:self.p + n].decode("utf-8")
        self.p += n
        return s

    def tabla(self) -> dict:
        t = {}
        for _ in range(self.i16()):
            s = self.texto()
            t[self.i16()] = s
        return t


def xml_del_efecto(ruta: str) -> ET.Element:
    with open(ruta, "rb") as f:
        bloques = _bloques(f.read())
    if "EDIT" not in bloques:
        raise ValueError("el efecto no trae el bloque EDIT (datos del editor)")
    r = _Lector(zlib.decompress(bloques["EDIT"]))
    claves = r.tabla()
    valores = r.tabla()
    raiz = ET.Element("efecto", {"archivo": os.path.basename(ruta)})

    def leer(padre: ET.Element) -> None:
        for _ in range(r.i16()):
            el = ET.SubElement(padre, claves[r.i16()])
            if r.booleano():
                el.text = valores[r.i16()]
            if r.booleano():
                leer(el)

    leer(raiz)
    return raiz


def resumen(raiz: ET.Element) -> list:
    """Una línea por capa: profundidad, nombre, tipo de dibujo, vida y texturas."""
    lineas = []
    tipos = {"0": "nada", "2": "sprite", "3": "cinta", "4": "anillo", "5": "modelo", "6": "rastro"}   # sin <Type> = sprite

    def nodo(n: ET.Element, prof: int) -> None:
        nombre = n.findtext("Name", "?")
        tipo = n.findtext("DrawingValues/Type", "2")
        vida = n.find("CommonValues/Life")
        vida_txt = ""
        if vida is not None:
            vida_txt = " vida %s-%s" % (vida.findtext("Min", "100"), vida.findtext("Max", "100"))
        cuantos = n.findtext("CommonValues/MaxGeneration", "1")
        tex = sorted({t.text for t in n.iter() if t.text and t.text.endswith((".png", ".efkmat", ".efkmodel"))
                      and t is not None and _es_de_este_nodo(n, t)})
        lineas.append("%s- %s [%s] x%s%s %s" % ("  " * prof, nombre, tipos.get(tipo, tipo), cuantos, vida_txt, ", ".join(os.path.basename(x) for x in tex)))
        hijos = n.find("Children")
        if hijos is not None:
            for h in hijos.findall("Node"):
                nodo(h, prof + 1)

    raiz_nodo = raiz.find("EffekseerProject/Root")
    if raiz_nodo is not None:
        hijos = raiz_nodo.find("Children")
        for h in (hijos.findall("Node") if hijos is not None else []):
            nodo(h, 0)
    return lineas


def plano(raiz: ET.Element) -> list:
    """Cada capa con sus valores propios en una línea por parámetro (ruta=valor), sin las capas hijas.
    Un trío Center/Max/Min se escribe «min..max» (o un solo número si son iguales)."""
    lineas = []

    def valor_de(el: ET.Element):
        hijos = {h.tag: h for h in el}
        if set(hijos) and set(hijos) <= {"Center", "Max", "Min"}:
            mn = hijos.get("Min", hijos.get("Center"))
            mx = hijos.get("Max", hijos.get("Center"))
            a, b = (mn.text if mn is not None else "?"), (mx.text if mx is not None else "?")
            return a if a == b else "%s..%s" % (a, b)
        return None

    def recorrer(el: ET.Element, ruta: str, salida: list) -> None:
        for h in el:
            if h.tag in ("Children", "Name"):
                continue
            r = ruta + "/" + h.tag if ruta else h.tag
            v = valor_de(h)
            if v is not None:
                salida.append("%s=%s" % (r, v))
            elif len(h):
                recorrer(h, r, salida)
            elif h.text:
                salida.append("%s=%s" % (r, h.text))

    def nodo(n: ET.Element, prof: int) -> None:
        sal = []
        recorrer(n, "", sal)
        lineas.append("%s## %s" % ("  " * prof, n.findtext("Name", "?")))
        lineas.extend("%s   %s" % ("  " * prof, s) for s in sal)
        hijos = n.find("Children")
        for h in (hijos.findall("Node") if hijos is not None else []):
            nodo(h, prof + 1)

    raiz_nodo = raiz.find("EffekseerProject/Root")
    hijos = raiz_nodo.find("Children") if raiz_nodo is not None else None
    for h in (hijos.findall("Node") if hijos is not None else []):
        nodo(h, 0)
    return lineas


def _es_de_este_nodo(nodo: ET.Element, el: ET.Element) -> bool:
    """True si `el` cuelga de `nodo` sin pasar por sus capas hijas."""
    hijos = nodo.find("Children")
    if hijos is None:
        return True
    return all(el not in list(h.iter()) for h in hijos.findall("Node"))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("efectos", nargs="+")
    ap.add_argument("--salida", default=".")
    a = ap.parse_args()
    os.makedirs(a.salida, exist_ok=True)
    for ruta in a.efectos:
        raiz = xml_del_efecto(ruta)
        texto = minidom.parseString(ET.tostring(raiz, encoding="unicode")).toprettyxml(indent="  ")
        destino = os.path.join(a.salida, os.path.splitext(os.path.basename(ruta))[0] + ".xml")
        with open(destino, "w", encoding="utf-8") as f:
            f.write(texto)
        with open(os.path.splitext(destino)[0] + "_plano.txt", "w", encoding="utf-8") as f:
            f.write("\n".join(plano(raiz)) + "\n")
        print("==", os.path.basename(ruta), "->", destino)
        for l in resumen(raiz):
            print(l)
    return 0


if __name__ == "__main__":
    sys.exit(main())
