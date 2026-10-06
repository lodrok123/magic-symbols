"""Estilos de render (toon / contorno / luces) para render_npc_v2_5.py.

Se importa dentro de Blender. Todo va en try/except: si algo falla, el render
sigue con el aspecto base y el fallo queda anotado en el informe.
"""
from __future__ import annotations

import json
from pathlib import Path

import bpy

PREFIX = "MSS_"
DEFAULT = {
    "name": "base",
    "toon": None,      # {"bands": 2, "threshold": 0.45, "shadow_color": [0.55,0.5,0.7], "saturation": 1.0, "value": 1.0}
    "outline": None,   # {"px": 1.5, "color": [0.08,0.05,0.05]}
    "lights": {"energy_scale": 1.0},
    "color_management": None,  # "Standard"
}


def load_style(spec: str | None, styles_dir: Path) -> dict:
    if not spec or spec == "base":
        return dict(DEFAULT)
    p = Path(spec)
    if not p.exists():
        p = styles_dir / f"{spec}.json"
    if not p.exists():
        raise FileNotFoundError(f"No existe el estilo '{spec}' ({p})")
    data = json.loads(p.read_text(encoding="utf-8"))
    out = dict(DEFAULT)
    out.update(data)
    out.setdefault("name", p.stem)
    return out


def _principled(nt):
    return next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)


def _toon_material(mat, cfg):
    nt = mat.node_tree
    out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None)
    pr = _principled(nt)
    if out is None or pr is None:
        return False
    bc = pr.inputs["Base Color"]
    al = pr.inputs["Alpha"]
    nodes, links = nt.nodes, nt.links

    # Color base (conservar textura si la hay)
    hs = nodes.new("ShaderNodeHueSaturation")
    hs.inputs["Saturation"].default_value = float(cfg.get("saturation", 1.0))
    hs.inputs["Value"].default_value = float(cfg.get("value", 1.0))
    if bc.is_linked:
        links.new(bc.links[0].from_socket, hs.inputs["Color"])
    else:
        hs.inputs["Color"].default_value = bc.default_value

    # Luz recibida -> bandas
    diff = nodes.new("ShaderNodeBsdfDiffuse")
    diff.inputs["Color"].default_value = (1, 1, 1, 1)
    s2r = nodes.new("ShaderNodeShaderToRGB")
    links.new(diff.outputs["BSDF"], s2r.inputs["Shader"])
    bw = nodes.new("ShaderNodeRGBToBW")
    links.new(s2r.outputs["Color"], bw.inputs["Color"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    sh = [float(x) for x in cfg.get("shadow_color", [0.6, 0.55, 0.75])]
    thr = float(cfg.get("threshold", 0.45))
    bands = int(cfg.get("bands", 2))
    el = ramp.color_ramp.elements
    el[0].position = 0.0
    el[0].color = (sh[0], sh[1], sh[2], 1.0)
    el[1].position = thr
    el[1].color = (1, 1, 1, 1)
    if bands >= 3:
        mid = el.new(thr * 0.5)
        mid.color = tuple((c + 1.0) * 0.5 for c in sh) + (1.0,)
    links.new(bw.outputs["Val"], ramp.inputs["Fac"])

    mul = nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    links.new(hs.outputs["Color"], mul.inputs["A"])
    links.new(ramp.outputs["Color"], mul.inputs["B"])
    emi = nodes.new("ShaderNodeEmission")
    links.new(mul.outputs["Result"], emi.inputs["Color"])

    final = emi.outputs["Emission"]
    if al.is_linked or al.default_value < 0.999:
        tr = nodes.new("ShaderNodeBsdfTransparent")
        mix = nodes.new("ShaderNodeMixShader")
        if al.is_linked:
            links.new(al.links[0].from_socket, mix.inputs["Fac"])
        else:
            mix.inputs["Fac"].default_value = al.default_value
        links.new(tr.outputs["BSDF"], mix.inputs[1])
        links.new(emi.outputs["Emission"], mix.inputs[2])
        final = mix.outputs["Shader"]
    links.new(final, out.inputs["Surface"])
    return True


def _apply_toon(meshes, cfg):
    done, skipped = 0, []
    seen = set()
    for obj in meshes:
        for slot in obj.material_slots:
            m = slot.material
            if not m or m.name in seen or not m.use_nodes:
                continue
            seen.add(m.name)
            try:
                if _toon_material(m, cfg):
                    done += 1
                else:
                    skipped.append(m.name)
            except Exception as e:  # noqa: BLE001
                skipped.append(f"{m.name}: {e}")
    return {"materials_toon": done, "skipped": skipped}


def _apply_outline(meshes, cfg, camera, scene):
    px = float(cfg.get("px", 1.5))
    col = [float(x) for x in cfg.get("color", [0.08, 0.05, 0.05])]
    units_per_px = camera.data.ortho_scale / max(scene.render.resolution_y, 1)
    thick = px * units_per_px
    mat = bpy.data.materials.new(PREFIX + "Outline")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    emi = nt.nodes.new("ShaderNodeEmission")
    emi.inputs["Color"].default_value = (col[0], col[1], col[2], 1.0)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(emi.outputs["Emission"], out.inputs["Surface"])
    mat.use_backface_culling = True
    n = 0
    for obj in meshes:
        offset = len(obj.data.materials)
        obj.data.materials.append(mat)
        mod = obj.modifiers.new(PREFIX + "Outline", "SOLIDIFY")
        mod.thickness = thick
        mod.offset = 1.0
        mod.use_flip_normals = True
        mod.use_rim = False
        mod.material_offset = offset
        n += 1
    return {"outline_meshes": n, "thickness_units": thick}


def _apply_lights(cfg, target):
    scale = float(cfg.get("energy_scale", 1.0))
    n = 0
    for o in bpy.data.objects:
        if o.type == "LIGHT" and not o.name.startswith(PREFIX):
            o.data.energy *= scale
            n += 1
    fill = cfg.get("fill_energy")
    if fill:
        d = bpy.data.lights.new(PREFIX + "Fill", "AREA")
        d.energy = float(fill)
        d.size = 6.0
        d.color = tuple(cfg.get("fill_color", [1.0, 0.95, 0.9]))
        o = bpy.data.objects.new(PREFIX + "Fill", d)
        bpy.context.scene.collection.objects.link(o)
        o.location = target + type(target)((-3.0, -6.0, 3.0))
        direction = target - o.location
        o.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return {"lights_scaled": n, "fill": bool(fill)}


def apply_style(style: dict, scene, meshes, camera, target) -> dict:
    rep = {"name": style.get("name", "base"), "applied": [], "errors": []}
    cm = style.get("color_management")
    if cm:
        try:
            scene.view_settings.view_transform = cm
            rep["applied"].append(f"color_management={cm}")
        except Exception as e:  # noqa: BLE001
            rep["errors"].append(f"color_management: {e}")
    for key, fn in (
        ("toon", lambda c: _apply_toon(meshes, c)),
        ("outline", lambda c: _apply_outline(meshes, c, camera, scene)),
    ):
        cfg = style.get(key)
        if cfg:
            try:
                rep[key] = fn(cfg)
                rep["applied"].append(key)
            except Exception as e:  # noqa: BLE001
                rep["errors"].append(f"{key}: {e}")
    try:
        rep["lights"] = _apply_lights(style.get("lights") or {}, target)
        rep["applied"].append("lights")
    except Exception as e:  # noqa: BLE001
        rep["errors"].append(f"lights: {e}")
    print("[STYLE] " + json.dumps(rep, ensure_ascii=False), flush=True)
    return rep
