#!/usr/bin/env python3
"""Integra piezas REGENERADAS de Meshy (una pieza por GLB) en la maqueta, sin partir láminas.

  1. Descarga el GLB de Meshy y déjalo en  poc_25d\\meshy\\entrada\\  con el NOMBRE DEL ID:
         cartel.glb, baldosa_guardado.glb, pasadero.glb, seto_seco.glb, arbusto.glb...
     (el id es el de docs/PLAN_ACCION_TEST2.md §2.1 / meshy/REGENERAR.md; los "_texture" de Meshy se quitan solos)
  2. Doble clic en INTEGRAR_PIEZAS.cmd
  3. En Godot: CatalogoAssets.tscn (F6) y tecla H = hoja de contacto: cada pieza nueva junto a la chibi,
     a la medida de la maqueta. Si está bien, PruebaTest2 ya la usa en lugar de la de la lámina.

Qué hace con cada GLB (solo stdlib):
  - mete todo lo que trae debajo de un nodo llamado como el id (así lo encuentran la maqueta y el catálogo);
  - cuenta triángulos y avisa si pasa de 5.000 (lo pedido: 3.000-5.000) o si no es un id conocido;
  - lo escribe en meshy\\piezas\\<id>.glb (si ya había uno, el viejo va a piezas\\_anteriores\\ con la fecha);
  - mueve el original a entrada\\_procesados\\.
Para deshacer: borra piezas\\<id>.glb (la maqueta vuelve a la pieza de la lámina).
"""
from __future__ import annotations

import json
import re
import shutil
import struct
import sys
from datetime import datetime
from pathlib import Path

AQUI = Path(__file__).resolve().parent
ENTRADA = AQUI / "entrada"
PIEZAS = AQUI / "piezas"
MAQUETA = AQUI.parent / "prueba_test2.gd"
MAX_TRIS = 5000


def leer_glb(p: Path) -> tuple[dict, bytes]:
    d = p.read_bytes()
    if d[:4] != b"glTF":
        raise ValueError("no es un GLB")
    jl = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + jl])
    o = 20 + jl
    bin_ = b""
    if o < len(d):
        bl = struct.unpack("<I", d[o:o + 4])[0]
        bin_ = d[o + 8:o + 8 + bl]
    return j, bin_


def escribir_glb(p: Path, j: dict, bin_: bytes) -> None:
    js = json.dumps(j, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    b = bin_ + b"\0" * ((4 - len(bin_) % 4) % 4)
    total = 12 + 8 + len(js) + (8 + len(b) if b else 0)
    out = struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js
    if b:
        out += struct.pack("<II", len(b), 0x004E4942) + b
    p.write_bytes(out)


def ids_conocidos() -> set[str]:
    """Las claves de MEDIDA / MEDIDA_ANCHO de la maqueta (los ids que sabe medir)."""
    try:
        t = MAQUETA.read_text(encoding="utf-8")
    except OSError:
        return set()
    ids: set[str] = set()
    for nombre in ("MEDIDA", "MEDIDA_ANCHO"):
        m = re.search(nombre + r": Dictionary = \{([^}]*)\}", t)
        if m:
            ids |= set(re.findall(r'"([a-z0-9_]+)"\s*:', m.group(1)))
    return ids


def id_de(p: Path) -> str:
    s = p.stem.lower()
    s = re.sub(r"[^a-z0-9]+", "_", s).strip("_")
    s = re.sub(r"_(texture|textured|withskin)(_\d+)?$", "", s)
    return s


def triangulos(j: dict) -> int:
    t = 0
    for m in j.get("meshes", []):
        for pr in m.get("primitives", []):
            if "indices" in pr:
                t += j["accessors"][pr["indices"]]["count"] // 3
            else:
                t += j["accessors"][pr["attributes"]["POSITION"]]["count"] // 3
    return t


def integrar(p: Path, conocidos: set[str], sello: str) -> bool:
    ident = id_de(p)
    print(f"\n== {p.name}  ->  {ident}")
    try:
        j, bin_ = leer_glb(p)
    except Exception as e:  # noqa: BLE001
        print(f"   ERROR: {e}")
        return False
    tris = triangulos(j)
    print(f"   {tris} triangulos, {len(j.get('meshes', []))} mallas, {len(j.get('images', []))} texturas")
    if tris > MAX_TRIS:
        print(f"   AVISO: pasa de {MAX_TRIS} triangulos (se pidieron 3.000-5.000). Vale para probar; para el juego, rehacer o reducir.")
    if conocidos and ident not in conocidos:
        print(f"   AVISO: '{ident}' no es un id de la maqueta. Si es una pieza que sustituye a otra, renombra el GLB a ese id.")
    escena = j.get("scenes", [{}])[j.get("scene", 0)]
    raices = list(escena.get("nodes", []))
    if len(raices) == 1 and j["nodes"][raices[0]].get("name") == ident and "mesh" not in j["nodes"][raices[0]]:
        pass   # ya preparado
    else:
        j["nodes"].append({"name": ident, "children": raices})
        escena["nodes"] = [len(j["nodes"]) - 1]
    for n in j["nodes"][:-1]:        # que ningún otro nodo se llame igual (el catálogo busca por nombre)
        if n.get("name") == ident:
            n["name"] = ident + "_malla"
    PIEZAS.mkdir(exist_ok=True)
    destino = PIEZAS / f"{ident}.glb"
    if destino.exists():
        viejos = PIEZAS / "_anteriores"
        viejos.mkdir(exist_ok=True)
        (viejos / ".gdignore").touch()
        shutil.move(str(destino), str(viejos / f"{ident}_{sello}.glb"))
        print(f"   la anterior queda en piezas\\_anteriores\\{ident}_{sello}.glb")
    escribir_glb(destino, j, bin_)
    hecho = ENTRADA / "_procesados"
    hecho.mkdir(exist_ok=True)
    shutil.move(str(p), str(hecho / p.name))
    print(f"   -> meshy\\piezas\\{ident}.glb")
    return True


def main() -> int:
    if not ENTRADA.is_dir():
        print(f"No existe {ENTRADA}")
        return 1
    glbs = sorted(x for x in ENTRADA.glob("*.glb") if x.is_file())
    if not glbs:
        print("No hay .glb en meshy\\entrada\\. Deja ahi la pieza de Meshy con el nombre de su id (cartel.glb...).")
        return 0
    conocidos = ids_conocidos()
    sello = datetime.now().strftime("%Y%m%d_%H%M%S")
    ok = [integrar(p, conocidos, sello) for p in glbs]
    print(f"\n{sum(ok)} de {len(ok)} integradas. Abre Godot (reimporta solo) -> CatalogoAssets.tscn, F6, tecla H.")
    return 0 if all(ok) else 1


if __name__ == "__main__":
    sys.exit(main())
