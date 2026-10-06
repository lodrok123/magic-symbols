from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

VERSION = "2.5"
PREFIX = "MSR25_"

DIRECTION_DEGREES = {
    "S": 0.0,
    "SW": 45.0,
    "W": 90.0,
    "NW": 135.0,
    "N": 180.0,
    "NE": 225.0,
    "E": 270.0,
    "SE": 315.0,
}


class RenderPipelineError(RuntimeError):
    pass


def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    p = argparse.ArgumentParser(description="Magic Symbols NPC Render v2.5")
    p.add_argument("--character-json", required=True, type=Path)
    p.add_argument("--directions", default="S,W,E")
    p.add_argument("--output", required=True, type=Path)
    p.add_argument("--report", required=True, type=Path)
    p.add_argument("--style", default=None, help="nombre en pipeline/profiles/styles o ruta a un .json")
    return p.parse_args(argv)


def load_json(path: Path):
    path = path.expanduser().resolve()
    if not path.exists():
        raise RenderPipelineError(f"No existe JSON: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data):
    path = path.expanduser().resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def _is_studio_character_object(obj):
    # Never delete render infrastructure.
    if obj.type in {"CAMERA", "LIGHT"}:
        return False
    if obj.name.startswith(PREFIX):
        return False

    # Character rigs are unambiguous.
    if obj.type == "ARMATURE":
        return True

    # Remove geometry participating in a character rig, including T-pose
    # meshes already stored in the Render Studio.
    if obj.type == "MESH":
        if any(mod.type == "ARMATURE" for mod in obj.modifiers):
            return True
        if obj.parent and obj.parent.type == "ARMATURE":
            return True

    return False


def clean_studio_characters():
    candidates = [o for o in list(bpy.data.objects) if _is_studio_character_object(o)]

    # If an armature is being removed, also remove its descendant geometry,
    # even when that geometry itself has no Armature modifier.
    armatures = {o for o in candidates if o.type == "ARMATURE"}
    for obj in list(bpy.data.objects):
        parent = obj.parent
        while parent:
            if parent in armatures:
                if obj.type not in {"CAMERA", "LIGHT"}:
                    candidates.append(obj)
                break
            parent = parent.parent

    unique = []
    seen = set()
    for obj in candidates:
        if obj.name not in seen:
            seen.add(obj.name)
            unique.append(obj)

    report = [
        {"name": o.name, "type": o.type}
        for o in unique
    ]

    for obj in unique:
        if obj.name in bpy.data.objects:
            bpy.data.objects.remove(obj, do_unlink=True)

    print(
        "[STUDIO:CLEAN] removed="
        + ",".join(f"{x['name']}:{x['type']}" for x in report),
        flush=True,
    )
    return report


def validate_character_isolation(imported):
    imported_set = set(imported)
    imported_armatures = [o for o in imported if o.type == "ARMATURE"]
    imported_meshes = [o for o in imported if o.type == "MESH"]

    foreign_armatures = [
        o.name for o in bpy.context.scene.objects
        if o.type == "ARMATURE" and o not in imported_set
    ]

    foreign_skinned_meshes = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or obj in imported_set:
            continue
        if any(mod.type == "ARMATURE" for mod in obj.modifiers):
            foreign_skinned_meshes.append(obj.name)
        elif obj.parent and obj.parent.type == "ARMATURE":
            foreign_skinned_meshes.append(obj.name)

    problems = []
    if len(imported_armatures) != 1:
        problems.append(f"IMPORTED_ARMATURE_COUNT={len(imported_armatures)}")
    if not imported_meshes:
        problems.append("NO_IMPORTED_MESH")
    if foreign_armatures:
        problems.append("FOREIGN_ARMATURES=" + ",".join(foreign_armatures))
    if foreign_skinned_meshes:
        problems.append("FOREIGN_SKINNED_MESHES=" + ",".join(foreign_skinned_meshes))

    report = {
        "imported_armatures": [o.name for o in imported_armatures],
        "imported_meshes": [o.name for o in imported_meshes],
        "foreign_armatures": foreign_armatures,
        "foreign_skinned_meshes": foreign_skinned_meshes,
        "problems": problems,
        "status": "ISOLATION_OK" if not problems else "ISOLATION_FAILED",
    }

    if problems:
        raise RenderPipelineError(
            "CHARACTER_ISOLATION_QA: " + json.dumps(report, ensure_ascii=False)
        )

    print(
        f"[STUDIO:ISOLATION] OK armature={imported_armatures[0].name} "
        f"meshes={','.join(o.name for o in imported_meshes)}",
        flush=True,
    )
    return report



def import_character(glb_path: Path):
    glb_path = glb_path.expanduser().resolve()
    if not glb_path.exists():
        raise RenderPipelineError(f"No existe GLB procesado: {glb_path}")

    before = set(bpy.data.objects)
    before_actions = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=str(glb_path))
    imported = [o for o in bpy.data.objects if o not in before]
    imported_actions = [a for a in bpy.data.actions if a not in before_actions]

    if not imported:
        raise RenderPipelineError("El GLB no importó objetos")

    for obj in imported:
        obj["ms_render_imported"] = True

    print(
        "[IMPORT:ACTIONS] "
        + ",".join(
            f"{a.name}:{float(a.frame_range[0])}-{float(a.frame_range[1])}"
            for a in imported_actions
        ),
        flush=True,
    )

    return imported, imported_actions


def find_armature(imported, expected_name=None):
    arms = [o for o in imported if o.type == "ARMATURE"]
    if expected_name:
        exact = next((o for o in arms if o.name == expected_name), None)
        if exact:
            return exact
    if len(arms) == 1:
        return arms[0]
    if not arms:
        raise RenderPipelineError("No se encontró Armature importado")
    raise RenderPipelineError("Hay varios Armatures y no se pudo elegir uno")


def _action_frame_info(action):
    if action is None:
        return None
    return {
        "name": action.name,
        "frame_range": [float(action.frame_range[0]), float(action.frame_range[1])],
    }


def find_action(name, imported_action_names=None):
    if not name:
        return None

    imported_action_names = set(imported_action_names or [])

    # Prefer the action that came from this GLB. Render Studio can contain
    # stale Actions even after its old armature/mesh has been removed.
    candidates = [
        a for a in bpy.data.actions
        if a.name in imported_action_names
    ]

    exact = next((a for a in candidates if a.name == name), None)
    if exact:
        return exact

    lower = name.lower()
    ci = next((a for a in candidates if a.name.lower() == lower), None)
    if ci:
        return ci

    # Fallback only when import tracking cannot identify it.
    action = bpy.data.actions.get(name)
    if action:
        return action
    return next((a for a in bpy.data.actions if a.name.lower() == lower), None)



def assign_action(armature, action):
    if action is None:
        return
    if armature.animation_data is None:
        armature.animation_data_create()
    armature.animation_data.action = action


def imported_meshes(imported):
    return [o for o in imported if o.type == "MESH"]


def classify_character_meshes(imported, armature):
    meshes = imported_meshes(imported)
    character = []
    helpers = []

    for obj in meshes:
        armature_mods = [
            mod for mod in obj.modifiers
            if mod.type == "ARMATURE" and mod.object == armature
        ]
        parented_to_armature = obj.parent == armature
        weighted = len(obj.vertex_groups) > 0

        # Character geometry must actually participate in the rig. This keeps
        # helper meshes such as Icosphere out of framing/ground calculations.
        is_character = bool(armature_mods) or (parented_to_armature and weighted)

        item = {
            "name": obj.name,
            "vertex_count": len(obj.data.vertices),
            "polygon_count": len(obj.data.polygons),
            "vertex_groups": len(obj.vertex_groups),
            "armature_modifiers": [m.name for m in armature_mods],
            "parent": obj.parent.name if obj.parent else None,
        }

        if is_character:
            character.append(obj)
        else:
            helpers.append(item)

    if not character:
        raise RenderPipelineError(
            "MESH_CLASSIFICATION_QA: no se encontró geometría skinned del personaje"
        )

    print(
        "[MESH:CLASSIFY] character="
        + ",".join(o.name for o in character)
        + " helpers="
        + ",".join(x["name"] for x in helpers),
        flush=True,
    )
    return character, helpers


def world_bbox(meshes):
    points = []
    for obj in meshes:
        for corner in obj.bound_box:
            points.append(obj.matrix_world @ Vector(corner))
    if not points:
        raise RenderPipelineError("No hay geometría para encuadrar")
    mins = Vector((
        min(p.x for p in points),
        min(p.y for p in points),
        min(p.z for p in points),
    ))
    maxs = Vector((
        max(p.x for p in points),
        max(p.y for p in points),
        max(p.z for p in points),
    ))
    return mins, maxs


def ensure_camera():
    scene = bpy.context.scene
    if scene.camera and scene.camera.type == "CAMERA":
        return scene.camera

    cam_data = bpy.data.cameras.new(PREFIX + "Camera")
    cam = bpy.data.objects.new(PREFIX + "Camera", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def ensure_key_light(target: Vector):
    existing = bpy.data.objects.get(PREFIX + "Key")
    if existing and existing.type == "LIGHT":
        return existing

    data = bpy.data.lights.new(PREFIX + "Key", "AREA")
    data.energy = 900.0
    data.shape = "DISK"
    data.size = 5.0
    light = bpy.data.objects.new(PREFIX + "Key", data)
    bpy.context.scene.collection.objects.link(light)
    light.location = target + Vector((4.0, -5.0, 7.0))
    point_at(light, target)
    return light


def point_at(obj, target):
    direction = target - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def configure_scene(render_cfg):
    scene = bpy.context.scene

    requested_engine = render_cfg.get("engine", "BLENDER_EEVEE")
    # Blender 5.2 uses BLENDER_EEVEE. Older character JSON files may still
    # contain BLENDER_EEVEE_NEXT, so normalize that legacy value here.
    engine_aliases = {
        "BLENDER_EEVEE_NEXT": "BLENDER_EEVEE",
        "BLENDER_EEVEE": "BLENDER_EEVEE",
        "CYCLES": "CYCLES",
        "BLENDER_WORKBENCH": "BLENDER_WORKBENCH",
    }
    engine = engine_aliases.get(requested_engine, "BLENDER_EEVEE")

    try:
        scene.render.engine = engine
    except (TypeError, ValueError):
        scene.render.engine = "BLENDER_EEVEE"

    print(
        f"[RENDER:ENGINE] requested={requested_engine} active={scene.render.engine}",
        flush=True,
    )

    resolution = render_cfg.get("resolution", [256, 320])
    scene.render.resolution_x = int(resolution[0])
    scene.render.resolution_y = int(resolution[1])
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = bool(render_cfg.get("transparent", True))

    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"

    if scene.world:
        scene.world.color = (0.055, 0.055, 0.055)

    return scene


def _world_bbox_corners(meshes):
    points = []
    for obj in meshes:
        for corner in obj.bound_box:
            points.append(obj.matrix_world @ Vector(corner))
    if not points:
        raise RenderPipelineError("No hay geometría para encuadrar")
    return points


def _project_to_camera_pixels(scene, camera, world_point):
    # Orthographic camera projection in camera-local coordinates.
    local = camera.matrix_world.inverted() @ world_point
    scale_y = max(camera.data.ortho_scale, 1e-8)
    aspect = scene.render.resolution_x / max(scene.render.resolution_y, 1)
    scale_x = scale_y * aspect

    nx = 0.5 + (local.x / scale_x) - camera.data.shift_x
    ny = 0.5 + (local.y / scale_y) - camera.data.shift_y

    px = nx * scene.render.resolution_x
    py_from_bottom = ny * scene.render.resolution_y
    py_from_top = scene.render.resolution_y - py_from_bottom
    return Vector((px, py_from_top))


def _screen_bounds(scene, camera, meshes):
    projected = [
        _project_to_camera_pixels(scene, camera, p)
        for p in _world_bbox_corners(meshes)
    ]
    return {
        "left": min(p.x for p in projected),
        "right": max(p.x for p in projected),
        "top": min(p.y for p in projected),
        "bottom": max(p.y for p in projected),
    }


def _lowest_world_point(meshes):
    pts = _world_bbox_corners(meshes)
    min_z = min(p.z for p in pts)
    near = [p for p in pts if abs(p.z - min_z) < 1e-5]
    if not near:
        near = [min(pts, key=lambda p: p.z)]
    return sum(near, Vector()) / len(near)


def configure_camera(camera, meshes, render_cfg):
    scene = bpy.context.scene
    mins, maxs = world_bbox(meshes)
    center = (mins + maxs) * 0.5
    height = max(maxs.z - mins.z, 0.001)

    camera.data.type = "ORTHO"
    camera.data.shift_x = 0.0
    camera.data.shift_y = 0.0

    # Preserve the validated Magic Symbols framing scale as a minimum, but
    # automatically enlarge it if a taller/wider NPC would clip.
    requested_ortho = float(render_cfg.get("orthographic_scale", 2.353))
    camera.data.ortho_scale = requested_ortho

    distance = max(height * 4.0, 6.0)
    camera.location = center + Vector((distance * 0.72, -distance, distance * 0.72))
    point_at(camera, center)
    bpy.context.view_layer.update()

    # First fit pass in projected camera space.
    bounds = _screen_bounds(scene, camera, meshes)
    rw = float(scene.render.resolution_x)
    rh = float(scene.render.resolution_y)
    margin_x = 12.0
    margin_top = 10.0
    margin_bottom = 18.0

    projected_w = max(bounds["right"] - bounds["left"], 1.0)
    projected_h = max(bounds["bottom"] - bounds["top"], 1.0)
    fit_factor = max(
        projected_w / max(rw - 2.0 * margin_x, 1.0),
        projected_h / max(rh - margin_top - margin_bottom, 1.0),
        1.0,
    )
    if fit_factor > 1.0:
        camera.data.ortho_scale *= fit_factor * 1.02
        bpy.context.view_layer.update()

    # Anchor the lowest character point to the requested ground pixel.
    anchor = render_cfg.get("ground_anchor", [128, 261])
    target_x = float(anchor[0])
    target_y = float(anchor[1])
    foot_world = _lowest_world_point(meshes)

    # Iterate because Blender camera shift and projected pixels must agree
    # after any scale adjustment.
    for _ in range(3):
        foot_px = _project_to_camera_pixels(scene, camera, foot_world)
        dx_px = target_x - foot_px.x
        dy_px = target_y - foot_px.y
        camera.data.shift_x -= dx_px / rw
        camera.data.shift_y += dy_px / rh
        bpy.context.view_layer.update()

    final_bounds = _screen_bounds(scene, camera, meshes)
    foot_px = _project_to_camera_pixels(scene, camera, foot_world)

    tolerance = 3.0
    clipping = {
        "left": final_bounds["left"] < -tolerance,
        "right": final_bounds["right"] > rw + tolerance,
        "top": final_bounds["top"] < -tolerance,
        "bottom": final_bounds["bottom"] > rh + tolerance,
    }
    anchor_error = {
        "x": foot_px.x - target_x,
        "y": foot_px.y - target_y,
    }

    if any(clipping.values()):
        raise RenderPipelineError(
            "CAMERA_QA: personaje recortado: "
            + json.dumps({"bounds": final_bounds, "clipping": clipping})
        )

    if abs(anchor_error["x"]) > tolerance or abs(anchor_error["y"]) > tolerance:
        raise RenderPipelineError(
            "CAMERA_QA: ground anchor fuera de tolerancia: "
            + json.dumps(anchor_error)
        )

    return {
        "bbox_min": list(mins),
        "bbox_max": list(maxs),
        "center": list(center),
        "height": height,
        "requested_ortho_scale": requested_ortho,
        "ortho_scale": camera.data.ortho_scale,
        "camera_location": list(camera.location),
        "camera_shift_x": camera.data.shift_x,
        "camera_shift_y": camera.data.shift_y,
        "projected_bounds_px": final_bounds,
        "ground_point_px": list(foot_px),
        "ground_anchor_target_px": [target_x, target_y],
        "ground_anchor_error_px": anchor_error,
        "clipping": clipping,
        "camera_qa": "OK",
    }



def character_root(imported, armature):
    # Rotate the armature and any imported top-level meshes together.
    root = bpy.data.objects.new(PREFIX + "DirectionRoot", None)
    bpy.context.scene.collection.objects.link(root)
    root["ms_render_imported"] = True

    imported_set = set(imported)
    top = [o for o in imported if o.parent not in imported_set and o != root]
    for obj in top:
        mw = obj.matrix_world.copy()
        obj.parent = root
        obj.matrix_world = mw
    return root


def validate_directions(raw):
    directions = [x.strip().upper() for x in raw.split(",") if x.strip()]
    if not directions:
        raise RenderPipelineError("No hay direcciones")
    unknown = [d for d in directions if d not in DIRECTION_DEGREES]
    if unknown:
        raise RenderPipelineError(f"Direcciones no válidas: {unknown}")
    return directions


def render_direction(scene, root, direction, output_dir: Path):
    degrees = DIRECTION_DEGREES[direction]
    root.rotation_euler[2] = math.radians(degrees)
    bpy.context.view_layer.update()

    output_dir.mkdir(parents=True, exist_ok=True)
    path = output_dir / f"{direction}.png"
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)

    if not path.exists() or path.stat().st_size == 0:
        raise RenderPipelineError(f"No se creó render: {path}")

    return {
        "direction": direction,
        "degrees": degrees,
        "path": str(path.resolve()),
        "bytes": path.stat().st_size,
    }


def main():
    args = parse_args()
    cfg = load_json(args.character_json)
    output_dir = args.output.expanduser().resolve()

    render_cfg = cfg.get("render", {})
    discovery = cfg.get("discovery", {})
    character = cfg.get("character", {})
    animation = cfg.get("animation", {}).get("idle", {})

    glb_value = character.get("source_model") or cfg.get("output", {}).get("processed_glb")
    if not glb_value:
        raise RenderPipelineError("character_art.json no contiene source_model/processed_glb")

    glb_path = Path(glb_value)
    directions = validate_directions(args.directions)

    scene = configure_scene(render_cfg)
    studio_cleanup = clean_studio_characters()
    imported, imported_actions = import_character(glb_path)
    isolation = validate_character_isolation(imported)

    armature = find_armature(imported, discovery.get("armature"))
    meshes, helper_meshes = classify_character_meshes(imported, armature)

    requested_action_name = animation.get("source_action") or discovery.get("idle_action")
    action = find_action(
        requested_action_name,
        imported_action_names=[a.name for a in imported_actions],
    )
    assign_action(armature, action)

    if action:
        start = int(math.floor(action.frame_range[0]))
        end = int(math.ceil(action.frame_range[1]))
        scene.frame_start = start
        scene.frame_end = end
        scene.frame_set(start)
    else:
        start = end = scene.frame_current

    camera = ensure_camera()
    camera_info = configure_camera(camera, meshes, render_cfg)
    ensure_key_light(Vector(camera_info["center"]))

    style_report = {"name": "base", "applied": [], "errors": []}
    if args.style and args.style != "base":
        try:
            sys.path.insert(0, str(Path(__file__).resolve().parent))
            import ms_style
            styles_dir = Path(__file__).resolve().parent.parent / "profiles" / "styles"
            style = ms_style.load_style(args.style, styles_dir)
            style_report = ms_style.apply_style(style, scene, meshes, camera, Vector(camera_info["center"]))
        except Exception as e:  # noqa: BLE001
            style_report = {"name": args.style, "applied": [], "errors": [f"{type(e).__name__}: {e}"]}
            print(f"[STYLE:ERROR] {e}", flush=True)

    root = character_root(imported, armature)

    rendered = []
    for direction in directions:
        print(f"[RENDER:START] direction={direction}", flush=True)
        item = render_direction(scene, root, direction, output_dir)
        rendered.append(item)
        print(f"[RENDER:DONE] direction={direction} path={item['path']}", flush=True)

    report = {
        "version": VERSION,
        "status": "RENDER_QA_OK",
        "character_json": str(args.character_json.expanduser().resolve()),
        "processed_glb": str(glb_path.expanduser().resolve()),
        "studio_cleanup": studio_cleanup,
        "character_isolation": isolation,
        "mesh_classification": {
            "character_meshes": [o.name for o in meshes],
            "excluded_helpers": helper_meshes,
        },
        "armature": armature.name,
        "action": action.name if action else None,
        "action_diagnostics": {
            "requested_action": requested_action_name,
            "imported_actions": [_action_frame_info(a) for a in imported_actions],
            "selected_action": _action_frame_info(action),
            "character_json_ingest_note": "The render pipeline uses the frame range actually present in the exported/imported GLB action.",
        },
        "frame_range": [start, end],
        "directions": directions,
        "style": style_report,
        "camera": camera_info,
        "renders": rendered,
        "qa": {
            "expected_render_count": len(directions),
            "actual_render_count": len(rendered),
            "all_files_nonempty": all(r["bytes"] > 0 for r in rendered),
            "character_isolation": isolation.get("status"),
            "character_meshes_used_for_framing": [o.name for o in meshes],
            "helpers_excluded_from_framing": [x["name"] for x in helper_meshes],
            "camera_qa": camera_info.get("camera_qa"),
            "clipping": camera_info.get("clipping"),
            "ground_anchor_error_px": camera_info.get("ground_anchor_error_px"),
        },
    }

    if report["qa"]["actual_render_count"] != report["qa"]["expected_render_count"]:
        raise RenderPipelineError("QA: faltan renders")
    if not report["qa"]["all_files_nonempty"]:
        raise RenderPipelineError("QA: hay renders vacíos")

    write_json(args.report, report)
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
