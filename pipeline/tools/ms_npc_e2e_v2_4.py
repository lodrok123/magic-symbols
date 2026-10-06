from __future__ import annotations

import argparse
import json
import math
import shutil
import sys
from pathlib import Path
from typing import Any

import bpy


PIPELINE_VERSION = "2.4"
PREFIX = "MSE2E_"


class PipelineError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1 :] if "--" in argv else []
    p = argparse.ArgumentParser(description="Magic Symbols NPC E2E v2.4")
    p.add_argument("--input-glb", required=True, type=Path)
    p.add_argument("--profile", required=True, type=Path)
    p.add_argument("--workspace", required=True, type=Path)
    p.add_argument(
        "--stage",
        required=True,
        choices=("ingest", "prepare", "bake", "export", "all"),
    )
    p.add_argument("--report", type=Path)
    p.add_argument("--allow-overwrite", action="store_true")
    return p.parse_args(argv)


def rp(path: Path) -> Path:
    return path.expanduser().resolve()


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def require_missing(path: Path, allow_overwrite: bool, label: str) -> None:
    if path.exists() and not allow_overwrite:
        raise PipelineError(f"{label} ya existe: {path}")
    ensure_parent(path)


def load_json(path: Path) -> dict[str, Any]:
    path = rp(path)
    if not path.exists():
        raise PipelineError(f"No existe: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: Any) -> None:
    path = rp(path)
    ensure_parent(path)
    path.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (
        bpy.data.meshes,
        bpy.data.armatures,
        bpy.data.materials,
        bpy.data.images,
    ):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def import_glb(path: Path) -> None:
    path = rp(path)
    if not path.exists():
        raise PipelineError(f"No existe input GLB: {path}")
    bpy.ops.import_scene.gltf(filepath=str(path))


def discover_scene() -> dict[str, Any]:
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    actions = list(bpy.data.actions)

    mesh_data = []
    for obj in meshes:
        mods = [m for m in obj.modifiers if m.type == "ARMATURE"]
        uv_layers = [uv.name for uv in obj.data.uv_layers]
        mats = []
        for slot in obj.material_slots:
            mat = slot.material
            if mat is None:
                continue
            mats.append(inspect_material(mat))
        mesh_data.append({
            "name": obj.name,
            "vertex_count": len(obj.data.vertices),
            "polygon_count": len(obj.data.polygons),
            "uv_layers": uv_layers,
            "armature_modifiers": [
                {
                    "name": m.name,
                    "object": m.object.name if m.object else None,
                }
                for m in mods
            ],
            "vertex_groups": len(obj.vertex_groups),
            "materials": mats,
        })

    return {
        "pipeline_version": PIPELINE_VERSION,
        "meshes": mesh_data,
        "armatures": [
            {
                "name": a.name,
                "bone_count": len(a.data.bones),
            }
            for a in armatures
        ],
        "actions": [
            {
                "name": a.name,
                "frame_range": [float(a.frame_range[0]), float(a.frame_range[1])],
            }
            for a in actions
        ],
    }


def inspect_material(mat: bpy.types.Material) -> dict[str, Any]:
    result = {
        "name": mat.name,
        "use_nodes": bool(mat.use_nodes),
        "principled": None,
        "images": [],
    }
    if not mat.use_nodes or not mat.node_tree:
        return result

    nodes = mat.node_tree.nodes
    principled = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)

    if principled:
        result["principled"] = {
            "name": principled.name,
            "base_color_linked": principled.inputs["Base Color"].is_linked,
            "roughness_linked": principled.inputs["Roughness"].is_linked,
            "metallic_linked": principled.inputs["Metallic"].is_linked,
            "normal_linked": principled.inputs["Normal"].is_linked,
        }

    for node in nodes:
        if node.type == "TEX_IMAGE" and node.image:
            result["images"].append({
                "node": node.name,
                "image": node.image.name,
                "filepath": bpy.path.abspath(node.image.filepath) if node.image.filepath else "",
                "colorspace": node.image.colorspace_settings.name,
                "size": list(node.image.size),
            })
    return result


def validate_discovery(report: dict[str, Any]) -> list[str]:
    problems = []
    if not report["meshes"]:
        problems.append("NO_MESH")
    if not report["armatures"]:
        problems.append("NO_ARMATURE")
    skinned = any(m["armature_modifiers"] for m in report["meshes"])
    if not skinned:
        problems.append("NO_ARMATURE_MODIFIER")
    if any(not m["uv_layers"] for m in report["meshes"]):
        problems.append("MESH_WITHOUT_UV")
    if not report["actions"]:
        problems.append("NO_ACTIONS")
    return problems


def save_blend(path: Path, allow_overwrite: bool) -> None:
    path = rp(path)
    require_missing(path, allow_overwrite, "Blend de salida")
    bpy.ops.wm.save_as_mainfile(filepath=str(path))


def find_principled(mat: bpy.types.Material):
    if not mat.use_nodes or not mat.node_tree:
        return None
    return next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)


def find_base_color_source(principled):
    inp = principled.inputs["Base Color"]
    if not inp.is_linked:
        return None
    return inp.links[0].from_socket


def find_roughness_source(principled):
    inp = principled.inputs["Roughness"]
    if not inp.is_linked:
        return None
    return inp.links[0].from_socket


def add_or_get(nodes, bl_idname, name, label, x, y):
    node = nodes.get(name)
    if node is None:
        node = nodes.new(bl_idname)
        node.name = name
        node.label = label
        node.location = (x, y)
    return node


def disconnect_input(links, socket):
    for link in list(socket.links):
        links.remove(link)


def link_replace(links, src, dst):
    disconnect_input(links, dst)
    links.new(src, dst)


def prepare_material(mat: bpy.types.Material, profile: dict[str, Any]) -> dict[str, Any]:
    principled = find_principled(mat)
    if principled is None:
        return {"material": mat.name, "status": "SKIPPED_NO_PRINCIPLED"}

    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    base_src = find_base_color_source(principled)
    if base_src is None:
        return {"material": mat.name, "status": "SKIPPED_NO_BASECOLOR_TEXTURE_LINK"}

    for node in list(nodes):
        if node.name.startswith(PREFIX):
            nodes.remove(node)

    # Global pastel treatment.
    pastel = profile["look"]["global_pastel"]
    global_hsv = add_or_get(
        nodes, "ShaderNodeHueSaturation",
        PREFIX + "GLOBAL_HSV", "GLOBAL PASTEL", 600, 900
    )
    global_hsv.inputs["Hue"].default_value = 0.5
    global_hsv.inputs["Saturation"].default_value = float(pastel["saturation"])
    global_hsv.inputs["Value"].default_value = float(pastel["value"])
    global_hsv.inputs["Factor"].default_value = 1.0
    links.new(base_src, global_hsv.inputs["Color"])

    # Skin classification from immutable incoming base-color.
    skin = profile["look"]["skin"]
    hsv = add_or_get(
        nodes, "ShaderNodeSeparateColor",
        PREFIX + "SKIN_HSV", "SKIN MASK HSV", 600, 550
    )
    hsv.mode = "HSV"
    links.new(base_src, hsv.inputs["Color"])

    def cond(name, op, src, value, x, y):
        n = add_or_get(nodes, "ShaderNodeMath", PREFIX + name, name, x, y)
        n.operation = op
        n.inputs[1].default_value = float(value)
        links.new(src, n.inputs[0])
        return n.outputs[0]

    hue = hsv.outputs["Red"]
    sat = hsv.outputs["Green"]
    val = hsv.outputs["Blue"]
    mask = skin["mask"]

    parts = [
        cond("SKIN_HUE_GT", "GREATER_THAN", hue, mask["hue_min"], 820, 720),
        cond("SKIN_HUE_LT", "LESS_THAN", hue, mask["hue_max"], 820, 640),
        cond("SKIN_SAT_GT", "GREATER_THAN", sat, mask["saturation_min"], 820, 540),
        cond("SKIN_SAT_LT", "LESS_THAN", sat, mask["saturation_max"], 820, 460),
        cond("SKIN_VAL_GT", "GREATER_THAN", val, mask["value_min"], 820, 360),
    ]

    current = parts[0]
    for i, other in enumerate(parts[1:], start=1):
        n = add_or_get(
            nodes, "ShaderNodeMath",
            PREFIX + f"SKIN_AND_{i}", "AND",
            1030 + 130 * i, 530
        )
        n.operation = "MULTIPLY"
        links.new(current, n.inputs[0])
        links.new(other, n.inputs[1])
        current = n.outputs[0]
    skin_mask = current

    skin_grade = add_or_get(
        nodes, "ShaderNodeHueSaturation",
        PREFIX + "SKIN_GRADE", "SKIN PASTEL GRADE", 1500, 760
    )
    skin_grade.inputs["Hue"].default_value = 0.5
    skin_grade.inputs["Saturation"].default_value = float(skin["grade"]["saturation"])
    skin_grade.inputs["Value"].default_value = float(skin["grade"]["value"])
    skin_grade.inputs["Factor"].default_value = 1.0
    links.new(global_hsv.outputs["Color"], skin_grade.inputs["Color"])

    bc = add_or_get(
        nodes, "ShaderNodeBrightContrast",
        PREFIX + "SKIN_BC", "SKIN BRIGHTNESS CONTRAST", 1710, 760
    )
    bc.inputs["Brightness"].default_value = float(skin["brightness_contrast"]["brightness"])
    bc.inputs["Contrast"].default_value = float(skin["brightness_contrast"]["contrast"])
    links.new(skin_grade.outputs["Color"], bc.inputs["Color"])

    mix = add_or_get(
        nodes, "ShaderNodeMix",
        PREFIX + "MIX_SKIN", "MIX SKIN", 1940, 700
    )
    mix.data_type = "RGBA"
    mix.blend_type = "MIX"
    mix.clamp_factor = True

    factor = next(s for s in mix.inputs if s.name == "Factor" and s.type == "VALUE")
    a = next(s for s in mix.inputs if s.name == "A" and s.type == "RGBA")
    b = next(s for s in mix.inputs if s.name == "B" and s.type == "RGBA")
    result = next(s for s in mix.outputs if s.name == "Result" and s.type == "RGBA")

    links.new(skin_mask, factor)
    links.new(global_hsv.outputs["Color"], a)
    links.new(bc.outputs["Color"], b)
    link_replace(links, result, principled.inputs["Base Color"])

    # Roughness: preserve incoming roughness if present, otherwise use scalar default.
    rough_src = find_roughness_source(principled)
    if rough_src is None:
        base_rough = add_or_get(
            nodes, "ShaderNodeValue",
            PREFIX + "ROUGHNESS_BASE", "ROUGHNESS BASE", 1480, 180
        )
        base_rough.outputs[0].default_value = float(
            profile["look"]["fallback_roughness"]
        )
        rough_src = base_rough.outputs[0]

    boost = add_or_get(
        nodes, "ShaderNodeMath",
        PREFIX + "SKIN_ROUGHNESS_BOOST", "SKIN ROUGHNESS BOOST", 1740, 180
    )
    boost.operation = "MULTIPLY"
    boost.inputs[1].default_value = float(skin["roughness_boost"])
    links.new(skin_mask, boost.inputs[0])

    final_r = add_or_get(
        nodes, "ShaderNodeMath",
        PREFIX + "FINAL_ROUGHNESS", "FINAL ROUGHNESS", 1960, 180
    )
    final_r.operation = "ADD"
    final_r.use_clamp = True
    links.new(rough_src, final_r.inputs[0])
    links.new(boost.outputs[0], final_r.inputs[1])
    link_replace(links, final_r.outputs[0], principled.inputs["Roughness"])

    return {
        "material": mat.name,
        "status": "PREPARED",
        "skin_saturation": skin["grade"]["saturation"],
        "skin_value": skin["grade"]["value"],
        "skin_brightness": skin["brightness_contrast"]["brightness"],
        "skin_contrast": skin["brightness_contrast"]["contrast"],
        "skin_roughness_boost": skin["roughness_boost"],
        "global_pastel_saturation": pastel["saturation"],
        "global_pastel_value": pastel["value"],
    }


def stage_ingest(input_glb, workspace, profile, allow_overwrite):
    reset_scene()
    import_glb(input_glb)

    discovery = discover_scene()
    discovery["problems"] = validate_discovery(discovery)
    discovery["input_glb"] = str(rp(input_glb))

    manifest_path = workspace / "reports" / "01_ingest_report.json"
    write_json(manifest_path, discovery)

    blend_path = workspace / "blend" / "01_ingested.blend"
    save_blend(blend_path, allow_overwrite)

    return discovery


def stage_prepare(workspace, profile, allow_overwrite):
    results = []
    for mat in bpy.data.materials:
        if mat.users == 0:
            continue
        results.append(prepare_material(mat, profile))

    report = {
        "pipeline_version": PIPELINE_VERSION,
        "status": "PREPARE_OK",
        "materials": results,
    }
    write_json(workspace / "reports" / "02_prepare_report.json", report)
    save_blend(workspace / "blend" / "02_prepared.blend", allow_overwrite)
    return report


def _socket_key(socket):
    node = socket.node
    return {
        "node_name": node.name,
        "socket_identifier": socket.identifier,
        "socket_name": socket.name,
    }


def _resolve_output_socket(mat, key):
    if not mat.use_nodes or mat.node_tree is None:
        raise PipelineError(f"{mat.name}: material sin node tree")

    node = mat.node_tree.nodes.get(key["node_name"])
    if node is None:
        raise PipelineError(
            f"{mat.name}: no existe nodo origen {key['node_name']}"
        )

    for socket in node.outputs:
        if socket.identifier == key["socket_identifier"]:
            return socket

    for socket in node.outputs:
        if socket.name == key["socket_name"]:
            return socket

    raise PipelineError(
        f"{mat.name}: no existe socket "
        f"{key['node_name']}::{key['socket_name']}"
    )


def _input_source_key(input_socket):
    if not input_socket.is_linked:
        return None

    link = input_socket.links[0]
    key = _socket_key(link.from_socket)

    del link
    return key


def bake_material_signal(obj, mat, signal_key, image, label):
    if not mat.use_nodes or mat.node_tree is None:
        raise PipelineError(f"{mat.name}: material sin nodos")

    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    output = next(
        (node for node in nodes if node.type == "OUTPUT_MATERIAL"),
        None,
    )
    if output is None:
        raise PipelineError(f"{mat.name}: falta Material Output")

    surface = output.inputs.get("Surface")
    if surface is None:
        raise PipelineError(f"{mat.name}: Material Output sin Surface")

    old_surface_key = _input_source_key(surface)

    target_name = PREFIX + f"BAKE_TARGET_{label}"
    emission_name = PREFIX + f"BAKE_EMISSION_{label}"

    old_target = nodes.get(target_name)
    if old_target is not None:
        nodes.remove(old_target)

    old_emission = nodes.get(emission_name)
    if old_emission is not None:
        nodes.remove(old_emission)

    target = nodes.new("ShaderNodeTexImage")
    target.name = target_name
    target.label = f"BAKE TARGET {label}"
    target.image = image

    for node in nodes:
        node.select = False

    target.select = True
    nodes.active = target

    emission = nodes.new("ShaderNodeEmission")
    emission.name = emission_name
    emission.label = f"BAKE EMISSION {label}"
    emission.inputs["Strength"].default_value = 1.0

    signal_socket = _resolve_output_socket(mat, signal_key)
    links.new(signal_socket, emission.inputs["Color"])

    disconnect_input(links, surface)

    emission = nodes.get(emission_name)
    output = next(
        (node for node in nodes if node.type == "OUTPUT_MATERIAL"),
        None,
    )

    if emission is None or output is None:
        raise PipelineError(
            f"{mat.name}: nodos temporales inválidos antes del bake"
        )

    links.new(
        emission.outputs["Emission"],
        output.inputs["Surface"],
    )

    for scene_obj in bpy.context.view_layer.objects:
        scene_obj.select_set(False)

    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    print(
        f"[BAKE:START] "
        f"object={obj.name} "
        f"material={mat.name} "
        f"signal={label} "
        f"image={image.name}",
        flush=True,
    )

    try:
        bpy.ops.object.bake(
            type="EMIT",
            margin=16,
            use_clear=True,
        )

        print(
            f"[BAKE:DONE] "
            f"object={obj.name} "
            f"material={mat.name} "
            f"signal={label}",
            flush=True,
        )

    finally:
        output = next(
            (node for node in nodes if node.type == "OUTPUT_MATERIAL"),
            None,
        )

        if output is not None:
            surface = output.inputs.get("Surface")

            if surface is not None:
                disconnect_input(links, surface)

                if old_surface_key is not None:
                    try:
                        restored_socket = _resolve_output_socket(
                            mat,
                            old_surface_key,
                        )
                        links.new(restored_socket, surface)
                    except Exception as exc:
                        print(
                            f"[BAKE:WARN] No se pudo restaurar Surface "
                            f"material={mat.name}: {exc}",
                            flush=True,
                        )

        emission = nodes.get(emission_name)
        if emission is not None:
            nodes.remove(emission)

        target = nodes.get(target_name)
        if target is not None:
            nodes.remove(target)

        print(
            f"[BAKE:CLEAN] "
            f"object={obj.name} "
            f"material={mat.name} "
            f"signal={label}",
            flush=True,
        )
        
def stage_bake(workspace, profile, allow_overwrite):
    baked = []

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"

    size = int(profile["bake"]["resolution"])

    tex_dir = workspace / "textures"
    tex_dir.mkdir(parents=True, exist_ok=True)

    processed = set()

    mesh_objects = [
        obj
        for obj in bpy.context.scene.objects
        if obj.type == "MESH"
    ]

    for obj in mesh_objects:
        if not obj.data.uv_layers:
            print(
                f"[BAKE:SKIP] object={obj.name} reason=NO_UV",
                flush=True,
            )
            continue

        for slot_index, slot in enumerate(obj.material_slots):
            mat = slot.material

            if mat is None:
                continue

            if not mat.use_nodes or mat.node_tree is None:
                continue

            # Un mismo material puede aparecer varias veces en slots.
            # Para una misma malla/material no debemos hornearlo dos veces.
            job_key = (obj.name, mat.name)

            if job_key in processed:
                print(
                    f"[BAKE:SKIP] "
                    f"object={obj.name} "
                    f"material={mat.name} "
                    f"reason=DUPLICATE",
                    flush=True,
                )
                continue

            processed.add(job_key)

            principled = find_principled(mat)
            if principled is None:
                print(
                    f"[BAKE:SKIP] "
                    f"object={obj.name} "
                    f"material={mat.name} "
                    f"reason=NO_PRINCIPLED",
                    flush=True,
                )
                continue

            base_input = principled.inputs.get("Base Color")
            rough_input = principled.inputs.get("Roughness")

            if base_input is None or rough_input is None:
                continue

            base_key = _input_source_key(base_input)
            rough_key = _input_source_key(rough_input)

            if base_key is None:
                print(
                    f"[BAKE:SKIP] "
                    f"object={obj.name} "
                    f"material={mat.name} "
                    f"reason=BASE_UNLINKED",
                    flush=True,
                )
                continue

            if rough_key is None:
                print(
                    f"[BAKE:SKIP] "
                    f"object={obj.name} "
                    f"material={mat.name} "
                    f"reason=ROUGH_UNLINKED",
                    flush=True,
                )
                continue

            safe_obj = "".join(
                c if c.isalnum() or c in "-_" else "_"
                for c in obj.name
            )

            safe_mat = "".join(
                c if c.isalnum() or c in "-_" else "_"
                for c in mat.name
            )

            # Incluimos objeto para evitar colisiones si un material
            # compartido aparece en varias mallas con UVs diferentes.
            file_stem = f"{safe_obj}__{safe_mat}"

            base_path = tex_dir / f"{file_stem}_basecolor.png"
            rough_path = tex_dir / f"{file_stem}_roughness.png"

            require_missing(
                base_path,
                allow_overwrite,
                "BaseColor bake",
            )
            require_missing(
                rough_path,
                allow_overwrite,
                "Roughness bake",
            )

            print(
                f"[BAKE:JOB] "
                f"object={obj.name} "
                f"slot={slot_index} "
                f"material={mat.name} "
                f"resolution={size}",
                flush=True,
            )

            base_img = bpy.data.images.new(
                f"{PREFIX}{file_stem}_BASECOLOR",
                width=size,
                height=size,
                alpha=True,
                float_buffer=False,
            )
            base_img.colorspace_settings.name = "sRGB"
            base_img.file_format = "PNG"
            base_img.filepath_raw = str(base_path)

            try:
                bake_material_signal(
                    obj,
                    mat,
                    base_key,
                    base_img,
                    "BASE",
                )

                base_img.save()

                print(
                    f"[BAKE:SAVED] {base_path}",
                    flush=True,
                )

            except Exception:
                if base_img.name in bpy.data.images:
                    bpy.data.images.remove(base_img)
                raise

            rough_img = bpy.data.images.new(
                f"{PREFIX}{file_stem}_ROUGHNESS",
                width=size,
                height=size,
                alpha=True,
                float_buffer=False,
            )
            rough_img.colorspace_settings.name = "Non-Color"
            rough_img.file_format = "PNG"
            rough_img.filepath_raw = str(rough_path)

            try:
                bake_material_signal(
                    obj,
                    mat,
                    rough_key,
                    rough_img,
                    "ROUGH",
                )

                rough_img.save()

                print(
                    f"[BAKE:SAVED] {rough_path}",
                    flush=True,
                )

            except Exception:
                if rough_img.name in bpy.data.images:
                    bpy.data.images.remove(rough_img)
                raise

            baked.append({
                "object": obj.name,
                "slot": slot_index,
                "material": mat.name,
                "basecolor": str(base_path),
                "roughness": str(rough_path),
            })

            print(
                f"[BAKE:JOB_DONE] "
                f"object={obj.name} "
                f"material={mat.name}",
                flush=True,
            )

    report = {
        "pipeline_version": PIPELINE_VERSION,
        "status": "BAKE_OK",
        "baked": baked,
    }

    write_json(
        workspace / "reports" / "03_bake_report.json",
        report,
    )

    save_blend(
        workspace / "blend" / "03_baked.blend",
        allow_overwrite,
    )

    return report



def _safe_name(value: str) -> str:
    return "".join(c if c.isalnum() or c in "-_" else "_" for c in value)


def _find_bake_record(bake_report, obj_name, mat_name):
    for item in bake_report.get("baked", []):
        if item.get("object") == obj_name and item.get("material") == mat_name:
            return item
    return None


def _load_or_reuse_image(path: Path, colorspace: str):
    path = rp(path)
    if not path.exists():
        raise PipelineError(f"No existe textura baked: {path}")

    for image in bpy.data.images:
        try:
            if image.filepath and rp(Path(bpy.path.abspath(image.filepath))) == path:
                image.colorspace_settings.name = colorspace
                return image
        except Exception:
            pass

    image = bpy.data.images.load(str(path), check_existing=True)
    image.colorspace_settings.name = colorspace
    return image


def _replace_material_with_bakes(mat, base_path: Path, rough_path: Path):
    mat.use_nodes = True
    nt = mat.node_tree
    if nt is None:
        raise PipelineError(f"{mat.name}: no se pudo crear node tree")

    nodes = nt.nodes
    links = nt.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    output.name = "Material Output"
    output.location = (700, 0)

    principled = nodes.new("ShaderNodeBsdfPrincipled")
    principled.name = "Principled BSDF"
    principled.location = (380, 0)

    base = nodes.new("ShaderNodeTexImage")
    base.name = PREFIX + "FINAL_BASECOLOR"
    base.label = "FINAL BAKED BASECOLOR"
    base.location = (-300, 180)
    base.image = _load_or_reuse_image(base_path, "sRGB")

    rough = nodes.new("ShaderNodeTexImage")
    rough.name = PREFIX + "FINAL_ROUGHNESS"
    rough.label = "FINAL BAKED ROUGHNESS"
    rough.location = (-300, -120)
    rough.image = _load_or_reuse_image(rough_path, "Non-Color")

    links.new(base.outputs["Color"], principled.inputs["Base Color"])
    links.new(rough.outputs["Color"], principled.inputs["Roughness"])
    links.new(principled.outputs["BSDF"], output.inputs["Surface"])

    principled.inputs["Metallic"].default_value = 0.0

    return {
        "material": mat.name,
        "basecolor": str(rp(base_path)),
        "roughness": str(rp(rough_path)),
        "nodes": [n.name for n in nodes],
    }


def _classify_helper_mesh(obj):
    if obj.type != "MESH":
        return False
    has_armature = any(m.type == "ARMATURE" for m in obj.modifiers)
    has_material = any(slot.material is not None for slot in obj.material_slots)
    has_groups = len(obj.vertex_groups) > 0
    return (
        not has_armature
        and not has_material
        and not has_groups
        and len(obj.data.vertices) <= 256
    )


def stage_finalize(workspace, profile, bake_report, allow_overwrite):
    replaced = []
    removed_helpers = []
    skipped = []

    for obj in list(bpy.context.scene.objects):
        if _classify_helper_mesh(obj):
            removed_helpers.append({
                "name": obj.name,
                "vertex_count": len(obj.data.vertices),
                "polygon_count": len(obj.data.polygons),
                "reason": "UNSKINNED_UNMATERIALLED_SMALL_MESH",
            })
            bpy.data.objects.remove(obj, do_unlink=True)

    for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        for slot_index, slot in enumerate(obj.material_slots):
            mat = slot.material
            if mat is None:
                continue

            record = _find_bake_record(bake_report, obj.name, mat.name)
            if record is None:
                skipped.append({
                    "object": obj.name,
                    "slot": slot_index,
                    "material": mat.name,
                    "reason": "NO_BAKE_RECORD",
                })
                continue

            info = _replace_material_with_bakes(
                mat,
                Path(record["basecolor"]),
                Path(record["roughness"]),
            )
            info["object"] = obj.name
            info["slot"] = slot_index
            replaced.append(info)

    if not replaced:
        raise PipelineError("FINALIZE: no se reemplazó ningún material por bakes")

    report = {
        "pipeline_version": PIPELINE_VERSION,
        "status": "FINALIZE_OK",
        "replaced_materials": replaced,
        "removed_helpers": removed_helpers,
        "skipped": skipped,
    }

    write_json(workspace / "reports" / "04_finalize_report.json", report)
    save_blend(workspace / "blend" / "04_finalized.blend", allow_overwrite)
    return report


def generate_character_art(workspace, discovery, export_report):
    armatures = discovery.get("armatures", [])
    meshes = discovery.get("meshes", [])
    actions = discovery.get("actions", [])

    armature_name = armatures[0]["name"] if armatures else None

    skinned_meshes = [
        m["name"]
        for m in meshes
        if m.get("armature_modifiers")
    ]

    action_names = [a["name"] for a in actions]

    idle_action = next(
        (name for name in action_names if "idle" in name.lower()),
        action_names[0] if action_names else None,
    )

    data = {
        "schema_version": "1.0",
        "pipeline_version": PIPELINE_VERSION,
        "character": {
            "id": workspace.name,
            "status": "prototype",
            "source_model": export_report["glb"],
        },
        "discovery": {
            "armature": armature_name,
            "skinned_meshes": skinned_meshes,
            "actions": action_names,
            "idle_action": idle_action,
        },
        "render": {
            "engine": "BLENDER_EEVEE_NEXT",
            "transparent": True,
            "resolution": [256, 320],
            "orthographic_scale": 2.353,
            "ground_anchor": [128, 261],
            "directions": ["S", "SW", "W", "NW", "N", "NE", "E", "SE"],
        },
        "animation": {
            "idle": {
                "enabled": idle_action is not None,
                "source_action": idle_action,
                "fps": 8,
            }
        },
        "output": {
            "processed_glb": export_report["glb"],
            "workspace": str(workspace),
        },
    }

    path = workspace / "character_art.json"
    write_json(path, data)
    return {"status": "CHARACTER_ART_OK", "path": str(rp(path)), "data": data}


def validate_final_scene(workspace):
    problems = []

    mesh_objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]

    if not mesh_objects:
        problems.append("NO_MESH_AFTER_FINALIZE")
    if not armatures:
        problems.append("NO_ARMATURE_AFTER_FINALIZE")

    material_checks = []
    for obj in mesh_objects:
        for slot in obj.material_slots:
            mat = slot.material
            if mat is None:
                continue
            principled = find_principled(mat)
            ok_base = bool(
                principled
                and principled.inputs["Base Color"].is_linked
                and principled.inputs["Base Color"].links[0].from_node.type == "TEX_IMAGE"
            )
            ok_rough = bool(
                principled
                and principled.inputs["Roughness"].is_linked
                and principled.inputs["Roughness"].links[0].from_node.type == "TEX_IMAGE"
            )
            material_checks.append({
                "object": obj.name,
                "material": mat.name,
                "basecolor_baked_image": ok_base,
                "roughness_baked_image": ok_rough,
            })
            if not ok_base or not ok_rough:
                problems.append(f"MATERIAL_NOT_FINAL:{obj.name}:{mat.name}")

    report = {
        "pipeline_version": PIPELINE_VERSION,
        "status": "QA_OK" if not problems else "QA_FAILED",
        "problems": problems,
        "materials": material_checks,
        "meshes": [o.name for o in mesh_objects],
        "armatures": [o.name for o in armatures],
        "actions": [a.name for a in bpy.data.actions],
    }
    write_json(workspace / "reports" / "06_qa_report.json", report)

    if problems:
        raise PipelineError("QA final falló: " + ", ".join(problems))

    return report



def stage_export(workspace, profile, allow_overwrite):
    out_glb = workspace / "export" / "npc_processed.glb"
    require_missing(out_glb, allow_overwrite, "GLB export")

    bpy.ops.export_scene.gltf(
        filepath=str(out_glb),
        export_format="GLB",
        use_selection=False,
        export_apply=False,
        export_animations=True,
        export_materials="EXPORT",
    )

    report = {
        "pipeline_version": PIPELINE_VERSION,
        "status": "EXPORT_OK",
        "glb": str(out_glb),
        "armatures": [o.name for o in bpy.context.scene.objects if o.type == "ARMATURE"],
        "meshes": [o.name for o in bpy.context.scene.objects if o.type == "MESH"],
        "actions": [a.name for a in bpy.data.actions],
    }
    write_json(workspace / "reports" / "05_export_report.json", report)
    return report


def open_blend(path: Path):
    path = rp(path)
    if not path.exists():
        raise PipelineError(f"No existe blend intermedio: {path}")
    bpy.ops.wm.open_mainfile(filepath=str(path))



def main():
    args = parse_args()
    input_glb = rp(args.input_glb)
    profile_path = rp(args.profile)
    workspace = rp(args.workspace)
    profile = load_json(profile_path)
    workspace.mkdir(parents=True, exist_ok=True)

    if profile.get("version") != PIPELINE_VERSION:
        raise PipelineError(
            f"Profile version {profile.get('version')} != {PIPELINE_VERSION}"
        )

    result = {}

    if args.stage in ("ingest", "all"):
        result["ingest"] = stage_ingest(
            input_glb, workspace, profile, args.allow_overwrite
        )

    if args.stage == "prepare":
        open_blend(workspace / "blend" / "01_ingested.blend")
        result["prepare"] = stage_prepare(workspace, profile, args.allow_overwrite)
    elif args.stage == "all":
        result["prepare"] = stage_prepare(workspace, profile, args.allow_overwrite)

    if args.stage == "bake":
        open_blend(workspace / "blend" / "02_prepared.blend")
        result["bake"] = stage_bake(workspace, profile, args.allow_overwrite)
    elif args.stage == "all":
        result["bake"] = stage_bake(workspace, profile, args.allow_overwrite)

    if args.stage == "export":
        open_blend(workspace / "blend" / "04_finalized.blend")
        result["export"] = stage_export(workspace, profile, args.allow_overwrite)
    elif args.stage == "all":
        result["finalize"] = stage_finalize(
            workspace, profile, result["bake"], args.allow_overwrite
        )
        result["export"] = stage_export(workspace, profile, args.allow_overwrite)
        result["character_art"] = generate_character_art(
            workspace, result["ingest"], result["export"]
        )
        result["qa"] = validate_final_scene(workspace)

    if args.report:
        write_json(args.report, result)

    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
