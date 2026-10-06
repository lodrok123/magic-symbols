from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path


GLB_MAGIC = 0x46546C67
GLB_VERSION = 2
CHUNK_JSON = 0x4E4F534A


def read_glb_json(path: Path) -> dict:
    data = path.read_bytes()
    if len(data) < 20:
        raise ValueError("Archivo demasiado pequeño para ser un GLB válido.")

    magic, version, total_length = struct.unpack_from("<III", data, 0)
    if magic != GLB_MAGIC:
        raise ValueError("El archivo no tiene magic GLB.")
    if version != GLB_VERSION:
        raise ValueError(f"Versión GLB no soportada: {version}")
    if total_length != len(data):
        raise ValueError(
            f"Longitud GLB inconsistente: header={total_length}, real={len(data)}"
        )

    offset = 12
    while offset + 8 <= len(data):
        chunk_length, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk = data[offset:offset + chunk_length]
        offset += chunk_length

        if chunk_type == CHUNK_JSON:
            text = chunk.decode("utf-8").rstrip("\x00 \t\r\n")
            return json.loads(text)

    raise ValueError("No se encontró el chunk JSON dentro del GLB.")


def index_name(items: list[dict], index: int | None, fallback: str) -> str:
    if index is None:
        return "<none>"
    if index < 0 or index >= len(items):
        return f"<invalid index {index}>"
    return items[index].get("name") or f"{fallback}[{index}]"


def texture_info(gltf: dict, texture_index: int | None) -> str:
    if texture_index is None:
        return "<none>"

    textures = gltf.get("textures", [])
    images = gltf.get("images", [])
    samplers = gltf.get("samplers", [])

    if texture_index < 0 or texture_index >= len(textures):
        return f"<invalid texture index {texture_index}>"

    texture = textures[texture_index]
    image_index = texture.get("source")
    sampler_index = texture.get("sampler")

    image_name = index_name(images, image_index, "image")
    image_uri = None

    if image_index is not None and 0 <= image_index < len(images):
        image_uri = images[image_index].get("uri")
        if image_uri is None and "bufferView" in images[image_index]:
            image_uri = f"<embedded bufferView {images[image_index]['bufferView']}>"

    sampler_name = index_name(samplers, sampler_index, "sampler")

    return (
        f"texture[{texture_index}]"
        f" -> image={image_name}"
        f" uri={image_uri or '<embedded/unnamed>'}"
        f" sampler={sampler_name}"
    )


def print_materials(gltf: dict) -> None:
    materials = gltf.get("materials", [])
    if not materials:
        print("No hay materiales en el GLB.")
        return

    print(f"Materiales: {len(materials)}")
    print()

    for i, material in enumerate(materials):
        name = material.get("name") or f"material[{i}]"
        pbr = material.get("pbrMetallicRoughness", {})

        base_color_texture = pbr.get("baseColorTexture", {}).get("index")
        mr_texture = pbr.get("metallicRoughnessTexture", {}).get("index")
        normal_texture = material.get("normalTexture", {}).get("index")
        emissive_texture = material.get("emissiveTexture", {}).get("index")

        print(f"[{i}] {name}")
        print("  baseColorFactor:", pbr.get("baseColorFactor", [1, 1, 1, 1]))
        print("  baseColorTexture:", texture_info(gltf, base_color_texture))
        print("  metallicRoughnessTexture:", texture_info(gltf, mr_texture))
        print("  normalTexture:", texture_info(gltf, normal_texture))
        print("  emissiveTexture:", texture_info(gltf, emissive_texture))
        print("  alphaMode:", material.get("alphaMode", "OPAQUE"))
        print("  alphaCutoff:", material.get("alphaCutoff", "<none>"))
        print("  doubleSided:", material.get("doubleSided", False))
        print()


def print_images(gltf: dict) -> None:
    images = gltf.get("images", [])
    print(f"Images: {len(images)}")

    for i, image in enumerate(images):
        print(
            f"  [{i}] name={image.get('name')!r} "
            f"uri={image.get('uri')!r} "
            f"bufferView={image.get('bufferView')!r} "
            f"mimeType={image.get('mimeType')!r}"
        )

    print()


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Inspecciona materiales/texturas de un GLB y muestra qué imagen "
            "está siendo usada como Base Color."
        )
    )
    parser.add_argument("glb", type=Path, help="Ruta al archivo .glb")
    parser.add_argument(
        "--json",
        dest="json_output",
        type=Path,
        default=None,
        help="Opcional: guardar el chunk JSON completo a un archivo.",
    )

    args = parser.parse_args()
    glb_path = args.glb.resolve()

    if not glb_path.exists():
        raise SystemExit(f"No existe: {glb_path}")

    gltf = read_glb_json(glb_path)

    print()
    print("MAGIC SYMBOLS — GLB MATERIAL INSPECTOR")
    print(f"GLB: {glb_path}")
    print()

    print_images(gltf)
    print_materials(gltf)

    if args.json_output is not None:
        out = args.json_output.resolve()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(
            json.dumps(gltf, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        print(f"JSON completo guardado en: {out}")


if __name__ == "__main__":
    main()
