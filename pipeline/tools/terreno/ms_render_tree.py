"""Magic Symbols - render del arbol GLB a PNG con estilo toon (Blender 5.x, segundo plano).

  blender --background --factory-startup --python ms_render_tree.py -- [--root R] [--config C] [--force]

Busca el primer .glb de <raiz>/Materials (o cfg tree.glb) y escribe <raiz>/Output/<tree.render_pattern> (uno por angulo de tree.angles, RGBA transparente).
Camara ortografica isometrica (az 45 / el 30), mismo estilo que el resto (ms_style + styles/<estilo>.json).
Si el estilo falla el render sigue con el aspecto base y lo deja anotado en Output/trees/render_tree.log.json.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys
import traceback
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import ms_terrain_layout as L  # noqa: E402
import ms_style  # noqa: E402

SIZE = 512


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--root")
    p.add_argument("--config", default=str(HERE / "ms_terrain_config.json"))
    p.add_argument("--force", action="store_true")
    # modo asset (lo usa ms_assets.py): GLB y destino explicitos
    p.add_argument("--glb")
    p.add_argument("--out-dir")
    p.add_argument("--angles")
    p.add_argument("--height", type=float)
    p.add_argument("--style")
    return p.parse_args(argv)


def resolve_root(a, cfg) -> Path:
    if a.root:
        return Path(a.root)
    if os.environ.get("MS_TERRAIN_ROOT"):
        return Path(os.environ["MS_TERRAIN_ROOT"])
    if cfg.get("root"):
        return Path(cfg["root"])
    return HERE


def main():
    a = parse_args()
    cfg = json.loads(Path(a.config).read_text(encoding="utf-8"))
    root = resolve_root(a, cfg).resolve()
    tr = dict(cfg["tree"])
    if a.glb:
        tr["glb"] = str(Path(a.glb).resolve())
        tr["render_pattern"] = "tree_a{angle:03d}.png"
        if a.angles:
            tr["angles"] = [float(x) for x in a.angles.split(",")]
        if a.height:
            tr["height_px"] = a.height
        if a.style:
            tr["style"] = a.style
        cfg["folders"] = dict(cfg["folders"], output=str(Path(a.out_dir).resolve()))
    glb = Path(tr["glb"]) if tr.get("glb") else None
    if glb and not glb.is_absolute():
        glb = root / cfg["folders"]["materials"] / glb
    if not glb:
        found = sorted((root / cfg["folders"]["materials"]).glob("*.glb"))
        glb = found[0] if found else None
    if not glb or not glb.exists():
        print(f"[ARBOL] No hay .glb en {root / cfg['folders']['materials']}")
        sys.exit(3)
    angles = [float(x) for x in tr.get("angles", [0])]
    pattern = tr.get("render_pattern", "trees/tree_a{angle:03d}.png")
    outs = [(Path(cfg["folders"]["output"]) if a.glb else root / cfg["folders"]["output"]) / pattern.format(angle=int(an)) for an in angles]
    newest = max(glb.stat().st_mtime, Path(__file__).stat().st_mtime)
    if all(o.exists() and o.stat().st_mtime >= newest for o in outs) and not a.force:
        print(f"[ARBOL] {len(outs)} renders ya estan al dia (usa force para rehacerlos)")
        return
    outs[0].parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.resolution_x = sc.render.resolution_y = SIZE
    sc.render.resolution_percentage = 100
    w = bpy.data.worlds.new("MST_World")
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.055, 0.055, 0.055, 1.0)
    sc.world = w

    bpy.ops.import_scene.gltf(filepath=str(glb))
    # fuera lo que no es el arbol (emisores de particulas / mallas fuente del GLB de Sketchfab)
    excl = tuple(tr.get("exclude_prefixes", ["Particle Emitter", "Custom Normals"]))
    removed = []
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and o.name.startswith(excl):
            removed.append(o.name)
            bpy.data.objects.remove(o, do_unlink=True)
    print(f"[ARBOL] excluidas {len(removed)} mallas: {removed}")
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        print("[ARBOL] El GLB no tiene mallas")
        sys.exit(4)
    bpy.context.view_layer.update()
    # normaliza la escala: el GLB viene en cm (miles de unidades) y rompe luces/contorno/clip
    pts0 = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    ext0 = max(max(p[i] for p in pts0) - min(p[i] for p in pts0) for i in range(3))
    kn = 4.0 / ext0 if ext0 > 1e-6 else 1.0
    for o in [o for o in bpy.context.scene.objects if o.parent is None]:
        o.scale = (o.scale[0] * kn, o.scale[1] * kn, o.scale[2] * kn)
        o.location = o.location * kn
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    target = (lo + hi) / 2.0

    az, el = 45.0, 30.0
    r, u, f = (Vector(v) for v in L.iso_basis(az, el))

    def proj_sizes(angle_deg):
        ca, sa = math.cos(math.radians(angle_deg)), math.sin(math.radians(angle_deg))
        rot = [Vector((target.x + (p.x - target.x) * ca - (p.y - target.y) * sa,
                       target.y + (p.x - target.x) * sa + (p.y - target.y) * ca, p.z)) for p in pts]
        return (max(p.dot(u) for p in rot) - min(p.dot(u) for p in rot),
                max(p.dot(r) for p in rot) - min(p.dot(r) for p in rot))

    sizes = [proj_sizes(an) for an in angles]
    proj_h = max(sz[0] for sz in sizes)
    proj_w = max(sz[1] for sz in sizes)
    ortho = max(proj_h, proj_w) * 1.2

    # pivote en el centro del arbol: se gira el arbol (no la camara) para mantener la vista isometrica
    pivot = bpy.data.objects.new("MST_Pivot", None)
    sc.collection.objects.link(pivot)
    pivot.location = target
    bpy.context.view_layer.update()
    for o in [o for o in bpy.context.scene.objects if o.parent is None and o is not pivot]:
        o.parent = pivot
        o.matrix_parent_inverse = pivot.matrix_world.inverted()

    cd = bpy.data.cameras.new("MST_Cam")
    cd.type = "ORTHO"
    cd.ortho_scale = ortho
    dist = max(hi - lo) * 2.0 + 20.0
    cd.clip_start, cd.clip_end = 0.01, dist * 4.0   # el GLB viene en cm (miles de unidades): clip fijo = render vacio
    cam = bpy.data.objects.new("MST_Cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.location = target - f * dist
    cam.rotation_euler = f.to_track_quat("-Z", "Y").to_euler()

    ld = bpy.data.lights.new("MST_Sun", "SUN")
    ld.energy = 3.4
    ld.angle = math.radians(8)
    sun = bpy.data.objects.new("MST_Sun", ld)
    sc.collection.objects.link(sun)
    sun.rotation_euler = (-Vector((-3.0, -6.0, 8.0))).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()

    # el sprite final mide height_px y el render SIZE: se escala el grosor del contorno
    k = (proj_h / ortho * SIZE) / float(tr.get("height_px", 108))
    rep = {"scale_norm": kn, "excluded": removed, "bbox": [list(lo), list(hi)], "ortho": ortho, "dist": dist, "glb": str(glb), "style": tr.get("style"), "outline_scale": k}
    try:
        style = ms_style.load_style(tr.get("style", "anime_a"), HERE / "styles")
        new_mod = None
        o3 = tr.get("outline_3d", {"enabled": True, "px": 2.6, "dark_value": 0.22, "dark_sat": 1.1})
        newp = HERE.parent / "ms_style.py"
        if o3.get("enabled", True) and newp.exists():
            try:                                   # ms_style de pipeline/tools: contorno del color del material (como props y personajes)
                import importlib.util
                spec = importlib.util.spec_from_file_location("ms_style_pipeline", str(newp))
                new_mod = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(new_mod)
            except Exception as e:  # noqa: BLE001
                rep["outline3d_error"] = str(e)
                new_mod = None
        old_outline = style.get("outline")
        if new_mod is not None:
            style["outline"] = None
        elif old_outline:
            style["outline"] = dict(old_outline, px=float(old_outline.get("px", 1.5)) * k)
        rep["style_report"] = ms_style.apply_style(style, sc, meshes, cam, target)
        if new_mod is not None:
            ocfg = {"px": float(o3.get("px", 2.6)) * k, "color_mode": "material", "dark_value": float(o3.get("dark_value", 0.22)),
                    "dark_sat": float(o3.get("dark_sat", 1.1)), "color": (old_outline or {}).get("color", [0.08, 0.05, 0.05])}
            rep["outline3d"] = new_mod._apply_outline(meshes, ocfg, cam, sc)
    except Exception as e:  # noqa: BLE001
        rep["style_error"] = str(e)
        print("[STYLE:ERROR]", e, flush=True)

    print(f"[ARBOL] bbox {tuple(round(x,1) for x in lo)} .. {tuple(round(x,1) for x in hi)} ortho={ortho:.1f} dist={dist:.1f}", flush=True)
    for an, out in zip(angles, outs):
        pivot.rotation_euler = (0.0, 0.0, math.radians(an))
        bpy.context.view_layer.update()
        sc.render.filepath = str(out)
        bpy.ops.render.render(write_still=True)
        if not out.exists() or out.stat().st_size == 0:
            raise RuntimeError(f"No se creo {out}")
        print(f"[ARBOL] OK angulo {an:g} -> {out}", flush=True)
    rep["angles"] = angles
    (outs[0].parent / "render_tree.log.json").write_text(json.dumps(rep, indent=2, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:  # noqa: BLE001
        traceback.print_exc()
        sys.exit(1)
