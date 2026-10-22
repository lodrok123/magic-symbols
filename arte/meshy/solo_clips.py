#!/usr/bin/env python3
"""Deja de un GLB de Meshy/Mixamo SOLO el esqueleto y las animaciones (sin malla, materiales ni texturas).

Por qué existe: los clips del goblin asesino salen de un goblin de Meshy («Gribble the Goblin, All Animations», 9 MB con tres
texturas de 2048) cuya malla no se usa: solo se leen su esqueleto y sus clips (jugador/clips_familia.gd). Con la malla, el
importador de Godot extraería además tres JPG de 2 MB al lado del GLB.

Qué conserva: la jerarquía de nodos, la piel (`skins`, para que Godot cree el Skeleton3D) con sus matrices inversas y las
animaciones con sus entradas y salidas. Qué quita: mallas, materiales, texturas, imágenes y todo accesorio que no use nadie.

Uso:  python solo_clips.py entrada.glb salida.glb
"""
import json
import struct
import sys
from pathlib import Path


def leer(ruta):
    b = Path(ruta).read_bytes()
    assert b[:4] == b"glTF", "no es un GLB"
    lj = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + lj])
    p = 20 + lj
    lb = struct.unpack("<I", b[p:p + 4])[0]
    return j, b[p + 8:p + 8 + lb]


def main(entrada, salida):
    j, binario = leer(entrada)
    # 1) fuera las mallas: el nodo conserva su piel pero ya no dibuja nada
    for n in j["nodes"]:
        n.pop("mesh", None)
        n.pop("weights", None)
    for clave in ("meshes", "materials", "textures", "images", "samplers"):
        j.pop(clave, None)
    # 2) accesorios que siguen en uso: entradas y salidas de las animaciones y matrices inversas de las pieles
    usados = []
    for a in j.get("animations", []):
        for s in a["samplers"]:
            usados += [s["input"], s["output"]]
    for sk in j.get("skins", []):
        if "inverseBindMatrices" in sk:
            usados.append(sk["inverseBindMatrices"])
    nuevo_id = {}
    accesorios, vistas, trozos = [], [], []
    desplazamiento = 0
    for i in sorted(set(usados)):
        a = dict(j["accessors"][i])
        bv = j["bufferViews"][a["bufferView"]]
        assert not bv.get("byteStride"), "accesor con byteStride: no soportado"
        ini = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        tam = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]] * {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}[a["componentType"]] * a["count"]
        datos = binario[ini:ini + tam]
        relleno = (4 - len(datos) % 4) % 4
        trozos.append(datos + b"\0" * relleno)
        vistas.append({"buffer": 0, "byteOffset": desplazamiento, "byteLength": len(datos)})
        desplazamiento += len(datos) + relleno
        a["bufferView"] = len(vistas) - 1
        a.pop("byteOffset", None)
        nuevo_id[i] = len(accesorios)
        accesorios.append(a)
    for an in j.get("animations", []):
        for s in an["samplers"]:
            s["input"], s["output"] = nuevo_id[s["input"]], nuevo_id[s["output"]]
    for sk in j.get("skins", []):
        if "inverseBindMatrices" in sk:
            sk["inverseBindMatrices"] = nuevo_id[sk["inverseBindMatrices"]]
    j["accessors"], j["bufferViews"] = accesorios, vistas
    nuevo_bin = b"".join(trozos)
    j["buffers"] = [{"byteLength": len(nuevo_bin)}]
    j.get("asset", {})["generator"] = "solo_clips.py"
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(nuevo_bin)
    Path(salida).write_bytes(struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js
                             + struct.pack("<II", len(nuevo_bin), 0x004E4942) + nuevo_bin)
    print(f"{salida}: {len(accesorios)} accesorios, {len(nuevo_bin) // 1024} KB de datos, {len(j.get('animations', []))} animaciones")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
