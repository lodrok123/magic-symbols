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


def _simplify_texture(nt, node, cfg):
    """Baja la resolucion de la textura de color (equivale a desenfocarla) para quitar
    detalle fino. Solo en memoria: no se guarda nada en disco."""
    scale = float(cfg.get("texture_scale", 1.0))
    if scale >= 0.999 or node is None or node.type != "TEX_IMAGE" or node.image is None:
        return
    img = node.image.copy()
    w, h = img.size
    if w < 4 or h < 4:
        return
    img.scale(max(4, int(w * scale)), max(4, int(h * scale)))
    node.image = img
    node.interpolation = "Cubic" if cfg.get("texture_smooth", True) else "Closest"


def _recolor_texture(node, rules, max_side=2048, space="auto"):
    """Recolorea zonas de la textura por rango de brillo/saturacion (p. ej. piel gris -> verde).
    Trabaja sobre una COPIA en memoria. Cada regla: v_range [lo,hi] (brillo sRGB), s_max, s_min, soft,
    color [r,g,b] sRGB objetivo, vref (brillo de referencia: el color se escala por v/vref para
    conservar el sombreado de la textura)."""
    import numpy as np
    if node is None or node.type != "TEX_IMAGE" or node.image is None:
        return "sin textura"
    img = node.image.copy()
    w, h = img.size
    if max(w, h) > max_side:
        k = max_side / float(max(w, h))
        img.scale(max(4, int(w * k)), max(4, int(h * k)))
        w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    a = px.reshape(-1, 4)

    def to_srgb(x):
        x = np.clip(x, 0.0, 1.0)
        return np.where(x <= 0.0031308, x * 12.92, 1.055 * np.power(x, 1 / 2.4) - 0.055)

    def to_lin(x):
        x = np.clip(x, 0.0, 1.0)
        return np.where(x <= 0.04045, x / 12.92, np.power((x + 0.055) / 1.055, 2.4))

    def masks(srgb):
        mx = srgb.max(1)
        mn = srgb.min(1)
        sat = (mx - mn) / np.maximum(mx, 1e-6)
        res = []
        for r in rules:
            lo, hi = [float(x) for x in r.get("v_range", [0.0, 1.0])]
            soft = max(float(r.get("soft", 0.04)), 1e-6)
            smax = float(r.get("s_max", 1.0))
            smin = float(r.get("s_min", 0.0))
            m = np.clip((mx - (lo - soft)) / soft, 0, 1) * np.clip(((hi + soft) - mx) / soft, 0, 1)
            m = m * np.clip(((smax + soft) - sat) / soft, 0, 1) * np.clip((sat - (smin - soft)) / soft, 0, 1)
            res.append(m)
        return mx, res

    raw = a[:, :3]
    cand = {"raw_srgb": raw, "lineal": to_srgb(raw)}
    best, best_cov = "raw_srgb", -1.0
    if space in cand or space == "raw":
        cand = {"raw_srgb": raw}
    for name, srgb in cand.items():
        _mx, ms = masks(srgb)
        cov = float(sum(m.mean() for m in ms))
        if cov > best_cov:
            best, best_cov = name, cov
    srgb = cand[best]
    mx, ms = masks(srgb)
    out = srgb.copy()
    for r, m in zip(rules, ms):
        lo, hi = [float(x) for x in r.get("v_range", [0.0, 1.0])]
        vref = max(float(r.get("vref", (lo + hi) / 2.0)), 1e-6)
        col = np.array([float(x) for x in r["color"]], dtype=np.float32)
        tgt = np.clip(col[None, :] * (mx / vref)[:, None], 0.0, 1.0)
        out = out * (1.0 - m)[:, None] + tgt * m[:, None]
    a[:, :3] = to_lin(out) if best == "lineal" else out
    img.pixels.foreach_set(a.reshape(-1))
    img.update()
    node.image = img
    return "%s cobertura=%.3f" % (best, best_cov)


def _posterize(nt, src_sock, bc, levels):
    """Reduce los niveles por canal en espacio perceptual (gamma 2.2); en lineal destruye los oscuros."""
    nodes, links = nt.nodes, nt.links
    levels = max(2, levels)
    sep = nodes.new("ShaderNodeSeparateColor")
    sep.mode = "RGB"
    com = nodes.new("ShaderNodeCombineColor")
    com.mode = "RGB"
    if src_sock is not None:
        links.new(src_sock, sep.inputs["Color"])
    else:
        sep.inputs["Color"].default_value = bc.default_value
    for ch in ("Red", "Green", "Blue"):
        g1 = nodes.new("ShaderNodeMath"); g1.operation = "POWER"; g1.inputs[1].default_value = 1.0 / 2.2
        mul = nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = float(levels)
        rnd = nodes.new("ShaderNodeMath"); rnd.operation = "ROUND"
        div = nodes.new("ShaderNodeMath"); div.operation = "DIVIDE"; div.inputs[1].default_value = float(levels)
        g2 = nodes.new("ShaderNodeMath"); g2.operation = "POWER"; g2.inputs[1].default_value = 2.2
        links.new(sep.outputs[ch], g1.inputs[0])
        links.new(g1.outputs["Value"], mul.inputs[0])
        links.new(mul.outputs["Value"], rnd.inputs[0])
        links.new(rnd.outputs["Value"], div.inputs[0])
        links.new(div.outputs["Value"], g2.inputs[0])
        links.new(g2.outputs["Value"], com.inputs[ch])
    return com.outputs["Color"]


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
    src_sock = bc.links[0].from_socket if bc.is_linked else None
    if bc.is_linked and cfg.get("recolor"):
        try:
            print("[STYLE] recolor:", _recolor_texture(bc.links[0].from_node, cfg["recolor"], int(cfg.get("recolor_max_side", 2048)), str(cfg.get("recolor_space", "auto"))), flush=True)
        except Exception as e:  # noqa: BLE001
            print("[STYLE] recolor FALLO:", e, flush=True)
    if bc.is_linked:
        _simplify_texture(nt, bc.links[0].from_node, cfg)
    if cfg.get("posterize"):
        src_sock = _posterize(nt, src_sock, bc, int(cfg["posterize"]))
    hs = nodes.new("ShaderNodeHueSaturation")
    hs.inputs["Saturation"].default_value = float(cfg.get("saturation", 1.0))
    hs.inputs["Value"].default_value = float(cfg.get("value", 1.0))
    if src_sock is not None:
        links.new(src_sock, hs.inputs["Color"])
    else:
        hs.inputs["Color"].default_value = bc.default_value

    # Correccion de verdes (opcional): mascara por tono (H en HSV) -> mezcla con una version desplazada.
    gf = cfg.get("green_fix")
    if gf:
        lo, hi = [float(x) for x in gf.get("hue_range", [0.22, 0.52])]
        sep = nodes.new("ShaderNodeSeparateColor")
        sep.mode = "HSV"
        links.new(hs.outputs["Color"], sep.inputs["Color"])
        mr = nodes.new("ShaderNodeValToRGB")
        mr.color_ramp.interpolation = "LINEAR"
        me = mr.color_ramp.elements
        me[0].position = max(lo - 0.04, 0.0)
        me[0].color = (0, 0, 0, 1)
        me[1].position = lo + 0.04
        me[1].color = (1, 1, 1, 1)
        m3 = me.new(hi - 0.04)
        m3.color = (1, 1, 1, 1)
        m4 = me.new(min(hi + 0.04, 1.0))
        m4.color = (0, 0, 0, 1)
        links.new(sep.outputs[0], mr.inputs["Fac"])
        adj = nodes.new("ShaderNodeHueSaturation")
        adj.inputs["Hue"].default_value = 0.5 + float(gf.get("hue_shift", 0.0))
        adj.inputs["Saturation"].default_value = float(gf.get("sat", 1.0))
        adj.inputs["Value"].default_value = float(gf.get("val", 1.0))
        links.new(hs.outputs["Color"], adj.inputs["Color"])
        gmix = nodes.new("ShaderNodeMix")
        gmix.data_type = "RGBA"
        gmix.blend_type = "MIX"
        links.new(mr.outputs["Color"], gmix.inputs["Factor"])  # color ramp -> factor (usa canal medio)
        links.new(hs.outputs["Color"], gmix.inputs["A"])
        links.new(adj.outputs["Color"], gmix.inputs["B"])
        hs2 = nodes.new("ShaderNodeHueSaturation")
        links.new(gmix.outputs["Result"], hs2.inputs["Color"])
        hs = hs2

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
        mid = el.new(float(cfg.get('threshold_low', thr * 0.5)))
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
    if cfg.get("debug_raw"):
        # luminancia cruda de la luz recibida (x factor) para calibrar el threshold
        sc = nodes.new("ShaderNodeMath")
        sc.operation = "MULTIPLY"
        sc.inputs[1].default_value = float(cfg["debug_raw"])
        links.new(bw.outputs["Val"], sc.inputs[0])
        links.new(sc.outputs["Value"], emi.inputs["Color"])
    if cfg.get("debug_bands"):
        # muestra solo el mapa de luz/sombra (para ajustar threshold/bands)
        links.new(ramp.outputs["Color"], emi.inputs["Color"])
        cfg = dict(cfg, shadow_value=None)

    # Modo "sombra con tono propio": en vez de multiplicar por un gris/violeta, la zona de
    # sombra es el color base mas oscuro y saturado y con un tinte (evita el aspecto plastificado).
    if cfg.get("shadow_value") is not None:
        shade = nodes.new("ShaderNodeHueSaturation")
        shade.inputs["Saturation"].default_value = float(cfg.get("shadow_sat", 1.2))
        shade.inputs["Value"].default_value = float(cfg.get("shadow_value", 0.72))
        links.new(hs.outputs["Color"], shade.inputs["Color"])
        tint = nodes.new("ShaderNodeMix")
        tint.data_type = "RGBA"
        tint.blend_type = "MULTIPLY"
        tint.inputs["Factor"].default_value = 1.0
        links.new(shade.outputs["Color"], tint.inputs["A"])
        tc = [float(x) for x in cfg.get("shadow_tint", [0.9, 0.86, 1.0])]
        tint.inputs["B"].default_value = (tc[0], tc[1], tc[2], 1.0)
        ramp2 = nodes.new("ShaderNodeValToRGB")
        ramp2.color_ramp.interpolation = "CONSTANT"
        e2 = ramp2.color_ramp.elements
        e2[0].position = 0.0
        e2[0].color = (0, 0, 0, 1)
        e2[1].position = thr
        e2[1].color = (1, 1, 1, 1)
        if bands >= 3:
            m2 = e2.new(float(cfg.get('threshold_low', thr * 0.5)))
            m2.color = (0.5, 0.5, 0.5, 1)
        links.new(bw.outputs["Val"], ramp2.inputs["Fac"])
        bw2 = nodes.new("ShaderNodeRGBToBW")
        links.new(ramp2.outputs["Color"], bw2.inputs["Color"])
        lit = nodes.new("ShaderNodeMix")
        lit.data_type = "RGBA"
        lit.blend_type = "MIX"
        links.new(bw2.outputs["Val"], lit.inputs["Factor"])
        links.new(tint.outputs["Result"], lit.inputs["A"])
        links.new(hs.outputs["Color"], lit.inputs["B"])
        links.new(lit.outputs["Result"], emi.inputs["Color"])

    # Gradacion final de color (todo opcional): lit_tint (multiplica), grade_color/grade_amount
    # (mezcla hacia un color con blend grade_blend), lift (sube negros), grade_sat/grade_val.
    if emi.inputs["Color"].is_linked and not cfg.get("debug_raw"):
        cur = emi.inputs["Color"].links[0].from_socket
        def _mix(blend, color, fac, cur):
            m = nodes.new("ShaderNodeMix")
            m.data_type = "RGBA"
            m.blend_type = blend
            m.inputs["Factor"].default_value = float(fac)
            links.new(cur, m.inputs["A"])
            m.inputs["B"].default_value = (float(color[0]), float(color[1]), float(color[2]), 1.0)
            return m.outputs["Result"]
        if cfg.get("lit_tint"):
            cur = _mix("MULTIPLY", cfg["lit_tint"], 1.0, cur)
        if cfg.get("grade_color"):
            cur = _mix(cfg.get("grade_blend", "SOFT_LIGHT"), cfg["grade_color"], cfg.get("grade_amount", 0.3), cur)
        if cfg.get("lift"):
            cur = _mix("SCREEN", cfg.get("lift_color", [0.5, 0.45, 0.35]), cfg["lift"], cur)
        if cfg.get("grade_sat") is not None or cfg.get("grade_val") is not None:
            g = nodes.new("ShaderNodeHueSaturation")
            g.inputs["Saturation"].default_value = float(cfg.get("grade_sat", 1.0))
            g.inputs["Value"].default_value = float(cfg.get("grade_val", 1.0))
            links.new(cur, g.inputs["Color"])
            cur = g.outputs["Color"]
        links.new(cur, emi.inputs["Color"])

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


def _outline_material_for(src_mat, col, cfg):
    """Material de contorno. Si cfg.color_mode == 'material' usa el color base del
    material original oscurecido (contorno que 'pertenece' a cada zona); si no, un color fijo."""
    mat = bpy.data.materials.new(PREFIX + "Outline")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    emi = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(emi.outputs["Emission"], out.inputs["Surface"])
    emi.inputs["Color"].default_value = (col[0], col[1], col[2], 1.0)
    if cfg.get("color_mode") == "material" and src_mat is not None and src_mat.use_nodes:
        pr = _principled(src_mat.node_tree)
        if pr is not None:
            bc = pr.inputs["Base Color"]
            hs = nt.nodes.new("ShaderNodeHueSaturation")
            hs.inputs["Saturation"].default_value = float(cfg.get("dark_sat", 1.1))
            hs.inputs["Value"].default_value = float(cfg.get("dark_value", 0.28))
            if bc.is_linked and bc.links[0].from_node.type == "TEX_IMAGE" and bc.links[0].from_node.image:
                tex = nt.nodes.new("ShaderNodeTexImage")
                tex.image = bc.links[0].from_node.image
                tex.interpolation = "Linear"
                nt.links.new(tex.outputs["Color"], hs.inputs["Color"])
            else:
                hs.inputs["Color"].default_value = bc.default_value
            nt.links.new(hs.outputs["Color"], emi.inputs["Color"])
    mat.use_backface_culling = True
    return mat


def _apply_outline(meshes, cfg, camera, scene):
    px = float(cfg.get("px", 1.5))
    col = [float(x) for x in cfg.get("color", [0.08, 0.05, 0.05])]
    units_per_px = camera.data.ortho_scale / max(scene.render.resolution_y, 1)
    thick = px * units_per_px
    n = 0
    for obj in meshes:
        originals = [slot.material for slot in obj.material_slots]
        offset = len(originals)
        if offset == 0:
            originals = [None]
            offset = 0
        per_slot = cfg.get("color_mode") == "material"
        if per_slot:
            for src in originals:
                obj.data.materials.append(_outline_material_for(src, col, cfg))
        else:
            obj.data.materials.append(_outline_material_for(None, col, cfg))
        mod = obj.modifiers.new(PREFIX + "Outline", "SOLIDIFY")
        mod.thickness = thick
        mod.offset = 1.0
        mod.use_flip_normals = True
        mod.use_rim = False
        mod.material_offset = offset
        n += 1
    return {"outline_meshes": n, "thickness_units": thick, "color_mode": cfg.get("color_mode", "fijo")}


def _apply_lines(meshes, cfg, scene):
    """Lineas interiores (pliegues/bordes) con Freestyle."""
    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = "ABSOLUTE"
    scene.render.line_thickness = float(cfg.get("px", 1.2))
    vl = bpy.context.view_layer
    vl.use_freestyle = True
    fs = vl.freestyle_settings
    for ls in list(fs.linesets):
        fs.linesets.remove(ls)
    ls = fs.linesets.new(PREFIX + "Lines")
    ls.select_silhouette = bool(cfg.get("silhouette", False))
    ls.select_border = bool(cfg.get("border", False))
    ls.select_crease = True
    ls.select_by_visibility = True
    fs.crease_angle = __import__("math").radians(float(cfg.get("crease_angle", 110)))
    col = [float(x) for x in cfg.get("color", [0.18, 0.11, 0.07])]
    ls.linestyle.color = (col[0], col[1], col[2])
    ls.linestyle.alpha = float(cfg.get("alpha", 0.9))
    ls.linestyle.thickness = float(cfg.get("px", 1.2))
    return {"crease_angle": cfg.get("crease_angle", 110), "px": cfg.get("px", 1.2)}


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
        ("lines", lambda c: _apply_lines(meshes, c, scene)),
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
