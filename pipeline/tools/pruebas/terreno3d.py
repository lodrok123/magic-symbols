"""PRUEBA: bloques de terreno y una caja renderizados en 3D con el MISMO estudio, camara, luces y estilo que los personajes.

Uso (lo lanza la cola, accion "blender", con el .blend del Render Studio):
  blender Studio.blend --background --python terreno3d.py -- --out <carpeta> --src <carpeta de bloques pintados> --style <estilo.json>

Los bloques usan como textura el bloque PINTADO (128x102) proyectado sobre una caja 3D desde la camara; se recorta un 10 % del borde
de cada cara para no heredar el contorno pintado. Salidas: grass.png dirt.png stone.png crate.png (256x256) y cluster.png (3x2 mezclados,
un solo objeto: el contorno solo aparece en el borde exterior).
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

PPU = 64.0                       # px por unidad: la diagonal del tile (2 u) mide 128 px, como los bloques del juego
SIDE = math.sqrt(2.0)            # lado del tile: su diagonal es 2 u
ALTO = 0.6495                    # 36 px de canto en pantalla con elevacion 30 grados: 36 / 64 / cos(30)
SPR_W, SPR_H = 128.0, 102.0
SHRINK = 0.90


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    d = {"out": "pipeline_output/arte_QA/terreno3d", "src": "export_godot/terrain/bosque_01/sprites/blocks",
         "style": "pipeline/tools/estilos/personaje_toon.json"}
    for i in range(0, len(a) - 1, 2):
        d[a[i].lstrip("-")] = a[i + 1]
    return d


def cam_setup(cam, center: Vector, res_x: int, res_y: int):
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = res_x, res_y
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(res_x, res_y) / PPU
    cam.data.shift_x = cam.data.shift_y = 0.0
    cam.data.clip_start, cam.data.clip_end = 0.1, 200.0
    fwd = cam.matrix_world.to_3x3() @ Vector((0, 0, -1))
    cam.location = center - fwd * 40.0
    bpy.context.view_layer.update()


def make_image(name, arr):
    h, w = arr.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels[:] = np.ascontiguousarray(arr, dtype=np.float32).ravel().tolist()
    img.colorspace_settings.name = "sRGB"
    img.update()
    return img


def write_png(path, arr):
    import zlib, struct
    a8 = (np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8)
    h, w = a8.shape[:2]
    raw = b"".join(b"\x00" + a8[r].tobytes() for r in range(h))

    def ch(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + ch(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) + ch(b"IDAT", zlib.compress(raw)) + ch(b"IEND", b"")
    Path(path).write_bytes(png)


def wood_array(mult=1.0):
    n = 256
    y, x = np.mgrid[0:n, 0:n] / float(n - 1)
    base = np.array([0.62, 0.42, 0.22])
    col = np.ones((n, n, 3)) * base
    rng = np.random.default_rng(3)
    grain = (np.sin(x * 60 + rng.random() * 6) * 0.03 + np.sin(y * 9 + x * 3) * 0.02)[..., None]
    col = col + grain
    # tablas verticales
    for k in (0.25, 0.5, 0.75):
        m = (np.abs(x - k) < 0.012)[..., None]
        col = np.where(m, base * 0.55, col)
    # marco
    b = 0.09
    frame = ((x < b) | (x > 1 - b) | (y < b) | (y > 1 - b))[..., None]
    col = np.where(frame, np.array([0.50, 0.32, 0.16]), col)
    edge = ((np.abs(x - b) < 0.008) & (y > b) & (y < 1 - b)) | ((np.abs(x - (1 - b)) < 0.008) & (y > b) & (y < 1 - b)) \
        | ((np.abs(y - b) < 0.008) & (x > b) & (x < 1 - b)) | ((np.abs(y - (1 - b)) < 0.008) & (x > b) & (x < 1 - b))
    col = np.where(edge[..., None], base * 0.45, col)
    # lineas interiores como las del barril: finas y oscuras, en el borde de cada cara y entre tablas
    dark = np.array([0.20, 0.11, 0.06])
    col = np.where(((x < 0.04) | (x > 0.96) | (y < 0.04) | (y > 0.96))[..., None], dark, col)
    for k in (0.25, 0.5, 0.75):
        col = np.where(((np.abs(x - k) < 0.014) & (y > 0.04) & (y < 0.96))[..., None], base * 0.5, col)
    col = col * mult
    rgba = np.concatenate([np.clip(col, 0, 1), np.ones((n, n, 1))], axis=2)
    return rgba[::-1].copy()


def barrel_array():
    n = 256
    y, x = np.mgrid[0:n, 0:n] / float(n - 1)
    base = np.array([0.56, 0.36, 0.17])
    col = np.ones((n, n, 3)) * base
    col = col + (np.sin(x * 40) * 0.025 + np.sin(y * 7 + x * 2) * 0.015)[..., None]
    for k in np.linspace(0.0, 1.0, 11):
        col = np.where((np.abs(x - k) < 0.008)[..., None], base * 0.5, col)
    for lo, hi in ((0.08, 0.15), (0.85, 0.92)):
        hoop = ((y > lo) & (y < hi))[..., None]
        col = np.where(hoop, np.array([0.34, 0.34, 0.37]), col)
        edge = (((np.abs(y - lo) < 0.01) | (np.abs(y - hi) < 0.01)) & (y > lo - 0.01) & (y < hi + 0.01))[..., None]
        col = np.where(edge, np.array([0.18, 0.18, 0.2]), col)
    # lineas interiores: aros, bordes superior/inferior y duelas mas marcadas
    dark = np.array([0.16, 0.09, 0.05])
    col = np.where(((y < 0.03) | (y > 0.97))[..., None], dark, col)
    for k in np.linspace(0.0, 1.0, 11):
        col = np.where((np.abs(x - k) < 0.016)[..., None], base * 0.3, col)
    for edge in (0.08, 0.15, 0.85, 0.92):
        col = np.where((np.abs(y - edge) < 0.014)[..., None], dark, col)
    rgba = np.concatenate([np.clip(col, 0, 1), np.ones((n, n, 1))], axis=2)
    return rgba[::-1].copy()


def barrel_faces(radius: float, height: float, seg: int = 16):
    out = []
    rings = [0.0, 0.18, 0.5, 0.82, 1.0]

    def rad(t):
        return radius * (1.0 - 0.14 * (2.0 * t - 1.0) ** 2)

    def pt(i, t):
        a = 2.0 * math.pi * i / seg
        return Vector((math.cos(a) * rad(t), math.sin(a) * rad(t), t * height))
    for i in range(seg):
        for j in range(len(rings) - 1):
            t0, t1 = rings[j], rings[j + 1]
            q = [pt(i, t0), pt(i + 1, t0), pt(i + 1, t1), pt(i, t1)]
            out.append((q, 0, [(i / seg, t0), ((i + 1) / seg, t0), ((i + 1) / seg, t1), (i / seg, t1)]))
    top = [pt(i, 1.0) for i in range(seg)]
    uvt = [(0.5 + 0.18 * math.cos(2 * math.pi * i / seg), 0.5 + 0.18 * math.sin(2 * math.pi * i / seg)) for i in range(seg)]
    out.append((top, 0, uvt))
    return out


def bark_array():
    n = 256
    y, x = np.mgrid[0:n, 0:n] / float(n - 1)
    base = np.array([0.40, 0.26, 0.14])
    col = np.ones((n, n, 3)) * base
    col = col + (np.sin(x * 70 + np.sin(y * 9) * 2.0) * 0.04 + np.sin(x * 23) * 0.02)[..., None]
    for k in np.linspace(0.0, 1.0, 9):
        col = np.where((np.abs(x - k - 0.02 * np.sin(y * 12)) < 0.012)[..., None], base * 0.45, col)
    rgba = np.concatenate([np.clip(col, 0, 1), np.ones((n, n, 1))], axis=2)
    return rgba[::-1].copy()


def cut_array():
    n = 256
    y, x = np.mgrid[0:n, 0:n] / float(n - 1)
    r = np.hypot(x - 0.5, y - 0.5)
    tan = np.array([0.80, 0.62, 0.38])
    col = np.ones((n, n, 3)) * tan
    col = col + (np.sin(r * 70) * 0.06)[..., None]
    col = np.where((np.abs(np.sin(r * 70)) > 0.97)[..., None], tan * 0.6, col)
    col = np.where((r > 0.45)[..., None], np.array([0.40, 0.26, 0.14]), col)
    rgba = np.concatenate([np.clip(col, 0, 1), np.ones((n, n, 1))], axis=2)
    return rgba[::-1].copy()


def stone_array():
    n = 256
    y, x = np.mgrid[0:n, 0:n] / float(n - 1)
    base = np.array([0.56, 0.58, 0.60])
    col = np.ones((n, n, 3)) * base
    col = col + (np.sin(x * 37 + y * 11) * 0.03 + np.sin(y * 53 - x * 17) * 0.025)[..., None]
    for a, b in ((0.3, 0.1), (0.7, 0.55), (0.15, 0.8)):
        d = np.abs((x - a) * 0.8 - (y - b) * 0.6 + 0.04 * np.sin(y * 20))
        col = np.where(((d < 0.008) & (y > b - 0.2) & (y < b + 0.2))[..., None], base * 0.5, col)
    rgba = np.concatenate([np.clip(col, 0, 1), np.ones((n, n, 1))], axis=2)
    return rgba[::-1].copy()


def _rot_y(v, a):
    c, s = math.cos(a), math.sin(a)
    return Vector((v.x * c + v.z * s, v.y, -v.x * s + v.z * c))


def _rot_z(v, a):
    c, s = math.cos(a), math.sin(a)
    return Vector((v.x * c - v.y * s, v.x * s + v.y * c, v.z))


def cylinder_faces(radius, length, seg=14, taper=0.0, flare=0.0):
    """Cilindro vertical (base en z=0). Material 0 = corteza, 1 = corte. flare ensancha la base (tocon)."""
    out = []

    def rad(t):
        return radius * (1.0 - taper * t + flare * (1.0 - t) ** 3)

    def pt(i, t):
        a = 2.0 * math.pi * i / seg
        return Vector((math.cos(a) * rad(t), math.sin(a) * rad(t), t * length))
    rings = [0.0, 0.5, 1.0]
    for i in range(seg):
        for j in range(len(rings) - 1):
            t0, t1 = rings[j], rings[j + 1]
            q = [pt(i, t0), pt(i + 1, t0), pt(i + 1, t1), pt(i, t1)]
            out.append((q, 0, [(i / seg, t0), ((i + 1) / seg, t0), ((i + 1) / seg, t1), (i / seg, t1)]))
    top = [pt(i, 1.0) for i in range(seg)]
    out.append((top, 1, [(0.5 + 0.5 * math.cos(2 * math.pi * i / seg), 0.5 + 0.5 * math.sin(2 * math.pi * i / seg)) for i in range(seg)]))
    return out


def xform(faces, fn):
    return [([fn(v) for v in q], mi, uv) for q, mi, uv in faces]


def dome_faces(rx, ry, rz, seed=1, lon=12, lat=4):
    """Media elipsoide irregular apoyada en z=0 (roca). Material 0."""
    out = []

    def pt(i, j):
        th = (math.pi / 2.0) * i / lat
        ph = 2.0 * math.pi * j / lon
        k = 1.0 + 0.16 * math.sin(ph * 3 + seed) + 0.1 * math.sin(ph * 5 + th * 4 + seed * 2.0)
        return Vector((math.sin(th) * math.cos(ph) * rx * k, math.sin(th) * math.sin(ph) * ry * k, math.cos(th) * rz * (1.0 + 0.1 * math.sin(ph * 2 + seed))))
    for i in range(1, lat):
        for j in range(lon):
            q = [pt(i, j), pt(i, j + 1), pt(i + 1, j + 1), pt(i + 1, j)][::-1]
            out.append((q, 0, [((j + 1) / lon, i / lat), (j / lon, i / lat), (j / lon, (i + 1) / lat), ((j + 1) / lon, (i + 1) / lat)][::1]))
    cap = [pt(1, j) for j in range(lon)][::-1]
    out.append((cap, 0, [(0.5 + 0.5 * math.cos(2 * math.pi * j / lon), 0.5 + 0.5 * math.sin(2 * math.pi * j / lon)) for j in range(lon)][::-1]))
    return out


def material(name, img):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    pr = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    nt.links.new(tex.outputs["Color"], pr.inputs["Base Color"])
    pr.inputs["Roughness"].default_value = 1.0
    return m


def box_faces(center: Vector, sx: float, sy: float, sz: float, yaw: float):
    """Caras de una caja (lista de 4 vertices en mundo, con su normal) girada `yaw` sobre Z. Base en z = center.z - sz/2."""
    c, s = math.cos(yaw), math.sin(yaw)

    def w(x, y, z):
        return Vector((center.x + x * c - y * s, center.y + x * s + y * c, center.z + z))

    hx, hy, hz = sx / 2, sy / 2, sz / 2
    v = {(a, b, d): w(a * hx, b * hy, d * hz) for a in (-1, 1) for b in (-1, 1) for d in (-1, 1)}
    quads = [
        [v[(-1, -1, 1)], v[(1, -1, 1)], v[(1, 1, 1)], v[(-1, 1, 1)]],       # arriba
        [v[(-1, -1, -1)], v[(-1, 1, -1)], v[(1, 1, -1)], v[(1, -1, -1)]],   # abajo
        [v[(-1, -1, -1)], v[(1, -1, -1)], v[(1, -1, 1)], v[(-1, -1, 1)]],
        [v[(1, -1, -1)], v[(1, 1, -1)], v[(1, 1, 1)], v[(1, -1, 1)]],
        [v[(1, 1, -1)], v[(-1, 1, -1)], v[(-1, 1, 1)], v[(1, 1, 1)]],
        [v[(-1, 1, -1)], v[(-1, -1, -1)], v[(-1, -1, 1)], v[(-1, 1, 1)]],
    ]
    out = []
    for q in quads:                                   # orientar cada cara hacia fuera (las caras no comparten vertices)
        n = (q[1] - q[0]).cross(q[2] - q[1])
        cen = sum(q, Vector((0, 0, 0))) / 4.0
        out.append(q[::-1] if n.dot(cen - center) < 0 else q)
    return out


def build_mesh(name, faces, mats):
    """faces: lista de (verts[4], mat_index, uvs[4]). Devuelve el objeto."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UV")
    for verts, mi, uvs in faces:
        bv = [bm.verts.new(p) for p in verts]
        f = bm.faces.new(bv)
        f.material_index = mi
        for lp, t in zip(f.loops, uvs):
            lp[uv].uv = t
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def tile_uvs(cam_inv, ref_cs, quad, img_wh=(SPR_W, SPR_H)):
    """UV por proyeccion de camara sobre el sprite pintado (cara superior centrada en (64,34))."""
    pts = []
    for p in quad:
        cv = cam_inv @ p
        px = (cv.x - ref_cs.x) * PPU
        py = (cv.y - ref_cs.y) * PPU
        pts.append((64.0 + px, 34.0 - py))
    cx = sum(p[0] for p in pts) / 4
    cy = sum(p[1] for p in pts) / 4
    out = []
    for x, y in pts:
        x = cx + (x - cx) * SHRINK
        y = cy + (y - cy) * SHRINK
        out.append((x / img_wh[0], 1.0 - y / img_wh[1]))
    return out


def tile_faces(cam, center: Vector, yaw: float, mi: int, only_visible=True):
    cam_inv = cam.matrix_world.inverted()
    top_center = center + Vector((0, 0, ALTO / 2))
    ref = cam_inv @ top_center
    out = []
    quads = box_faces(center, SIDE, SIDE, ALTO, yaw)
    cam_dir = cam.matrix_world.to_3x3() @ Vector((0, 0, -1))
    for q in quads:
        n = (q[1] - q[0]).cross(q[2] - q[1]).normalized()
        if only_visible and n.dot(cam_dir) > 0.0:
            continue                                   # cara de espaldas
        out.append((q, mi, tile_uvs(cam_inv, ref, q)))
    return out


def crate_faces(center: Vector, size: float, yaw: float):
    out = []
    uv = [(0, 0), (1, 0), (1, 1), (0, 1)]
    for q in box_faces(center, size, size, size, yaw):
        n = (q[1] - q[0]).cross(q[2] - q[1])
        mi = 0 if n.z > 0.5 else (1 if n.x < 0 else 2)       # arriba / izquierda / derecha
        out.append((q, mi, uv))
    return out


def render(path, objs_visible):
    for o in bpy.data.objects:
        if o.name.startswith("MS3D_"):
            o.hide_render = o not in objs_visible
        elif o.type not in ("CAMERA", "LIGHT"):
            o.hide_render = True                       # personajes/props del estudio fuera
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    print("[T3D] render:", path, flush=True)


def sprites_mode(a, out, cam, sc, names, objs, mats):
    """Sprites listos para el compositor: bloques 128x102 (misma geometria que los pintados) y props."""
    (out / "blocks").mkdir(parents=True, exist_ok=True)
    (out / "props").mkdir(parents=True, exist_ok=True)
    zc = ALTO - 17.0 / (math.cos(math.radians(30)) * PPU)      # cara superior queda en (64,34) del marco
    cam_setup(cam, Vector((0, 0, zc)), 128, 102)
    for n in ([] if a.get("only") == "props" else names):
        render(out / "blocks" / f"{n}.png", [objs[n]])
    cam_setup(cam, Vector((0, 0, 0.35)), 128, 128)
    for n in ("crate", "barrel", "stump", "log", "boulder", "rocks"):
        if n in objs:
            render(out / "props" / f"{n}.png", [objs[n]])
    return 0


def main():
    a = args()
    out = Path(__file__).resolve().parents[3] / a["out"]
    out.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parents[3]
    src = root / a["src"]
    sc = bpy.context.scene
    cam = sc.camera
    if cam is None:
        print("[T3D] FAIL: el estudio no tiene camara")
        return 2

    cam.data.type = "ORTHO"
    bpy.context.view_layer.update()
    f0 = cam.matrix_world.to_3x3() @ Vector((0, 0, -1))
    h = Vector((f0.x, f0.y, 0))
    h = h.normalized() if h.length > 1e-6 else Vector((0, 1, 0))
    el = math.radians(30.0)
    fwd = Vector((h.x * math.cos(el), h.y * math.cos(el), -math.sin(el)))
    cam.rotation_mode = "XYZ"
    cam.rotation_euler = fwd.to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()
    right = cam.matrix_world.to_3x3() @ Vector((1, 0, 0))
    yaw = math.atan2(right.y, right.x) + math.pi / 4.0
    print("[T3D] elevacion 30 forzada; yaw bloque:", round(math.degrees(yaw), 1), flush=True)

    # --- materiales con el bloque pintado como textura
    names = ["grass", "dirt", "stone"] + [x for x in a.get("extra", "").split(",") if x]
    mats = []
    for n in names:
        srcmap = dict(kv.split("=") for kv in a.get("map", "").split(",") if "=" in kv)
        img = bpy.data.images.load(str(src / f"{srcmap.get(n, n)}.png"))
        img.colorspace_settings.name = "sRGB"
        mats.append(material(f"MS3D_{n}", img))
    wp = out / "_madera.png"
    crate_mats = []
    for k, mult in enumerate((1.12, 0.96, 0.78)):
        wp = out / f"_madera{k}.png"
        write_png(wp, wood_array(mult))
        crate_mats.append(material(f"MS3D_crate{k}", bpy.data.images.load(str(wp))))

    # centro del tile: su cara superior queda en z = ALTO, centrado en el origen
    base_center = Vector((0, 0, ALTO / 2))
    cam_setup(cam, Vector((0, 0, ALTO * 0.5)), 256, 256)

    objs = {}
    for i, n in enumerate(names):
        objs[n] = build_mesh(f"MS3D_{n}", tile_faces(cam, base_center, yaw, 0), [mats[i]])
    s = 0.9
    csz = 0.5 if a.get("sprites") else s
    objs["crate"] = build_mesh("MS3D_crate", crate_faces(Vector((0, 0, csz / 2)), csz, yaw + math.radians(8)), crate_mats)
    if a.get("sprites"):
        for nm, arr in (("bark", bark_array()), ("cut", cut_array()), ("stone", stone_array())):
            write_png(out / f"_{nm}.png", arr)
        mb = material("MS3D_bark", bpy.data.images.load(str(out / "_bark.png")))
        mc = material("MS3D_cut", bpy.data.images.load(str(out / "_cut.png")))
        ms_ = material("MS3D_stone", bpy.data.images.load(str(out / "_stone.png")))
        yw = yaw + math.radians(8)
        objs["stump"] = build_mesh("MS3D_stump", xform(cylinder_faces(0.2, 0.36, flare=0.35), lambda v: _rot_z(v, yw)), [mb, mc])
        objs["log"] = build_mesh("MS3D_log", xform(cylinder_faces(0.15, 0.8, taper=0.06), lambda v: _rot_z(_rot_y(v, math.pi / 2) + Vector((-0.4, 0, 0.15)), yw + 0.5)), [mb, mc])
        objs["boulder"] = build_mesh("MS3D_boulder", xform(dome_faces(0.36, 0.32, 0.3, 1), lambda v: _rot_z(v, yw)), [ms_])
        rocks = []
        for (ox, oy, rr, sd) in ((-0.18, 0.05, 0.16, 2), (0.12, -0.1, 0.12, 3), (0.14, 0.16, 0.09, 4)):
            rocks += xform(dome_faces(rr, rr * 0.9, rr * 0.7, sd, lon=10, lat=3), lambda v, ox=ox, oy=oy: v + Vector((ox, oy, 0)))
        objs["rocks"] = build_mesh("MS3D_rocks", rocks, [ms_])
    bp = out / "_barril.png"
    write_png(bp, barrel_array())
    bmat = material("MS3D_barrel", bpy.data.images.load(str(bp)))
    objs["barrel"] = build_mesh("MS3D_barrel", barrel_faces(0.29, 0.66), [bmat])

    # cluster 3x2 en un solo objeto (mezcla de materiales; las caras compartidas no tienen contorno entre si)
    faces = []
    layout = [["grass", "grass", "dirt"], ["stone", "grass", "dirt"]]
    ax_a = Vector((math.cos(yaw), math.sin(yaw), 0)) * SIDE       # eje del tile
    ax_b = Vector((-math.sin(yaw), math.cos(yaw), 0)) * SIDE
    for j, row in enumerate(layout):
        for i, n in enumerate(row):
            c = base_center + ax_a * (i - 1.0) + ax_b * (j - 0.5)
            faces += tile_faces(cam, c, yaw, names.index(n))
    objs["cluster"] = build_mesh("MS3D_cluster", faces, mats)

    # --- estilo (el mismo que los personajes)
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    import ms_style
    spec = a["style"]
    p = Path(spec)
    style = ms_style.load_style(str(p), p.parent) if p.is_file() else ms_style.load_style(spec, Path("pipeline/tools/estilos"))
    cam_setup(cam, Vector((0, 0, ALTO * 0.5)), 256, 256)
    rep = ms_style.apply_style(style, sc, list(objs.values()), cam, Vector((0, 0, 0)))
    print("[T3D] estilo:", rep.get("name"), rep.get("errors"), flush=True)

    if a.get("sprites"):
        return sprites_mode(a, out, cam, sc, names, objs, mats)
    for n in names + ["crate"]:
        render(out / f"{n}.png", [objs[n]])
    cam_setup(cam, Vector((0, 0, ALTO * 0.5)), 640, 448)
    render(out / "cluster.png", [objs["cluster"]])
    (out / "info.json").write_text(json.dumps({"ppu": PPU, "alto": ALTO, "yaw_deg": math.degrees(yaw), "style": rep.get("name")}, indent=2), encoding="utf-8")
    return 0


sys.exit(main())
