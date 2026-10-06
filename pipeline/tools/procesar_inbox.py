#!/usr/bin/env python3
"""
PROCESAR INBOX: una carpeta con GLBs  ->  personaje procesado de principio a fin.

Uso normal: doble clic en  pipeline\\PROCESAR_PERSONAJES.cmd

    1. Crea  pipeline\\inbox\\<Nombre del personaje>\\  y mete dentro sus .glb
       (uno por animacion: idle, walk, run... el nombre del archivo puede ser
       el de Meshy: "..._Animation_Idle_03_withSkin.glb", "..._Walking_withSkin.glb").
    2. Doble clic.
    3. Al terminar, mira  pipeline_output\\<id>\\REPORTE.md  (APROBADO / RECHAZADO).

Que hace por cada carpeta del inbox:
    - espera a que los archivos terminen de copiarse (tamano estable)
    - lee cada GLB por dentro (malla, huesos, animaciones) y decide su rol
    - normaliza el nombre ("Guarda Bosque" -> guarda_bosque)
    - si ese personaje ya existe NO lo pisa: crea guarda_bosque_v2, _v3...
    - lanza build_character.py (ensamblado, preflight, render, atlas, validacion)
    - escribe REPORTE.md y mueve la carpeta a inbox\\_procesados\\

No modifica ningun otro script del pipeline. Solo libreria estandar.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import struct
import subprocess
import sys
import time
import unicodedata
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
ROOT = Path(__file__).resolve().parents[2]
PIPE = ROOT / "pipeline"
INBOX = PIPE / "inbox"
CHARS = PIPE / "characters"
OUT = ROOT / "pipeline_output"

ROLES = ("idle", "walk", "run")
REQUIRED = ("idle", "walk")          # lo que activa el character.json de plantilla
ALIASES = {
    "idle": {"idle", "idling"},
    "walk": {"walk", "walking"},
    "run": {"run", "running"},
}


# ---------------------------------------------------------------- utilidades
def normalize_id(name: str) -> str:
    s = unicodedata.normalize("NFKD", name)
    s = "".join(c for c in s if not unicodedata.combining(c)).lower()
    s = re.sub(r"[^a-z0-9]+", "_", s).strip("_")
    return s


def tokens(text: str) -> set[str]:
    return {t for t in re.sub(r"[^a-z0-9]+", "_", text.lower()).split("_") if t}


def anim_base(entry: dict) -> str:
    """id base de una animacion no estandar: Animation_<Nombre>_withSkin.glb -> nombre en minusculas, sin indice final."""
    stem = entry["path"].stem
    m = re.search(r"Animation_(.+?)(?:_withSkin)?$", stem, re.I)
    raw = m.group(1) if m else (entry["info"]["animations"][0] if entry["info"]["animations"] else stem)
    base = normalize_id(raw)
    if re.match(r"^[0-9a-f]{8}_[0-9a-f]{4}_", base):  # nombre = UUID (Meshy sin titulo)
        return "anim_" + base[:8]
    return re.sub(r"_\d+$", "", base) or "anim"


def role_from_text(text: str) -> set[str]:
    t = tokens(text)
    return {role for role, names in ALIASES.items() if t & names}


def glb_info(path: Path) -> dict:
    """Lee solo la cabecera JSON del GLB (no carga la geometria)."""
    with path.open("rb") as f:
        head = f.read(20)
        if len(head) < 20 or head[:4] != b"glTF":
            raise ValueError("no es un GLB valido (cabecera)")
        clen, ctype = struct.unpack("<II", head[12:20])
        if ctype != 0x4E4F534A:  # 'JSON'
            raise ValueError("no es un GLB valido (primer bloque)")
        data = json.loads(f.read(clen).decode("utf-8"))
    skins = data.get("skins", [])
    return {
        "meshes": [m.get("name", "") for m in data.get("meshes", [])],
        "bones": max((len(s.get("joints", [])) for s in skins), default=0),
        "animations": [a.get("name", "") for a in data.get("animations", [])],
    }


def desplazamiento_final(path: Path) -> float | None:
    """Cuanto se ha movido la cadera al acabar la animacion, en ALTOS DE CADERA (sin unidades: vale para
    cualquier escala). ~0 en un ciclo en el sitio (Walking 0,00, Running 0,00); >1 si el personaje se va
    (Walk_Turn_Right 1,2, Dead 1,6, Roll_Dodge 4,5, Swim_Forward 6,2). None si no se puede medir."""
    try:
        d = path.read_bytes()
        jl = struct.unpack("<I", d[12:16])[0]
        j = json.loads(d[20:20 + jl])
        o = 20 + jl
        bl = struct.unpack("<I", d[o:o + 4])[0]
        b = d[o + 8:o + 8 + bl]
        hips = {i for i, n in enumerate(j.get("nodes", [])) if str(n.get("name", "")).lower().endswith("hips")}
        for an in j.get("animations", []):
            for ch in an.get("channels", []):
                t = ch.get("target", {})
                if t.get("node") not in hips or t.get("path") != "translation":
                    continue
                a = j["accessors"][an["samplers"][ch["sampler"]]["output"]]
                bv = j["bufferViews"][a["bufferView"]]
                base = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
                paso = bv.get("byteStride", 12)
                x0, y0, z0 = struct.unpack_from("<3f", b, base)
                x1, _, z1 = struct.unpack_from("<3f", b, base + (a["count"] - 1) * paso)
                return ((x1 - x0) ** 2 + (z1 - z0) ** 2) ** 0.5 / max(abs(y0), 1e-6)
    except Exception:  # noqa: BLE001
        return None
    return None


def wait_stable(files: list[Path], seconds: float = 3.0, tries: int = 40) -> bool:
    prev = None
    for _ in range(tries):
        cur = [(p.name, p.stat().st_size) for p in files]
        if cur == prev:
            return True
        prev = cur
        time.sleep(seconds)
    return False


def _taken(cid: str) -> bool:
    """Un id esta ocupado solo si ya tiene un personaje APROBADO; los intentos fallidos se reutilizan."""
    rep = OUT / cid / "REPORTE.md"
    try:
        return rep.read_text(encoding="utf-8").startswith("# APROBADO")
    except OSError:
        return False


def free_id(base: str) -> str:
    if not _taken(base):
        return base
    n = 2
    while _taken(f"{base}_v{n}"):
        n += 1
    return f"{base}_v{n}"


# ---------------------------------------------------------------- clasificar
def classify(folder: Path, rename: bool = False) -> dict:
    glbs = sorted(p for p in folder.glob("*.glb") if p.is_file())
    result = {"files": [], "by_role": {r: [] for r in ROLES},
              "ignored": [], "errors": [], "warnings": []}
    for p in glbs:
        entry = {"path": p, "name": p.name, "info": None, "role": None, "why": ""}
        try:
            entry["info"] = glb_info(p)
        except Exception as e:  # noqa: BLE001
            result["errors"].append(f"{p.name}: {e}")
            result["files"].append(entry)
            continue
        info = entry["info"]
        by_name = role_from_text(p.stem)
        by_anim: set[str] = set()
        for a in info["animations"]:
            by_anim |= role_from_text(a)
        if len(by_name) == 1:
            entry["role"], entry["why"] = next(iter(by_name)), "nombre de archivo"
        elif len(by_anim) == 1:
            entry["role"], entry["why"] = next(iter(by_anim)), "nombre de la animacion"
        elif by_name and by_anim and len(by_name & by_anim) == 1:
            entry["role"], entry["why"] = next(iter(by_name & by_anim)), "archivo + animacion"
        if len(by_anim) > 1 and not entry["role"]:
            result["errors"].append(
                f"{p.name}: un solo GLB con varias animaciones ({', '.join(info['animations'])}). "
                "Todavia no se separan solos: exporta un GLB por animacion.")
        if entry["role"]:
            if info["bones"] == 0:
                result["errors"].append(f"{p.name}: no tiene esqueleto (skin)")
            if not info["animations"]:
                result["errors"].append(f"{p.name}: no contiene ninguna animacion")
            result["by_role"][entry["role"]].append(entry)
        else:
            result["ignored"].append(entry)
        result["files"].append(entry)

    # animaciones repetidas: no es un fallo. Se renombran <rol>_001.glb, _002... (en disco)
    # y se usa la 001 como animacion principal; las demas quedan guardadas como variantes.
    result["variants"] = []
    for role, items in result["by_role"].items():
        if len(items) < 2:
            continue
        # principal = la mas "pura": animacion llamada solo como el rol (Walking antes que Spear_Walk), luego por nombre
        def _pure(e):
            anims = (e["info"] or {}).get("animations", [])
            return 0 if any(tokens(x) <= ALIASES[role] | {"1", "01", "001"} for x in anims) else 1
        items.sort(key=lambda e: (_pure(e), e["name"].lower()))
        targets = [f"{role}_{i:03d}.glb" for i in range(1, len(items) + 1)]
        if rename:
            tmp = []
            for e in items:                       # dos fases: evita choques de nombre (p.ej. ya existe idle_001.glb)
                t = e["path"].with_name(e["path"].name + ".ms_tmp")
                e["path"].rename(t)
                tmp.append(t)
            for e, t, new_name in zip(items, tmp, targets):
                dest = t.with_name(new_name)
                t.rename(dest)
                e["old_name"], e["path"], e["name"] = e["name"], dest, new_name
        else:
            for e, new_name in zip(items, targets):
                e["old_name"], e["name"] = e["name"], new_name
        for k, e in enumerate(items[1:], 2):
            e["anim_id"] = f"{role}_{k:03d}"
            e["why"] = (e["why"] + "; " if e["why"] else "") + f"variante -> animacion {e['anim_id']}"
            result["variants"].append(e)
        result["by_role"][role] = items[:1]
        result["warnings"].append(
            f"{len(items)} archivos para '{role}': renombrados "
            + ", ".join(f"{e['old_name']} -> {e['name']}" for e in items)
            + f". '{role}' = {items[0]['name']}; el resto son animaciones {role}_002, {role}_003...")
    for role in REQUIRED:
        if not result["by_role"][role]:
            result["errors"].append(
                f"Falta el GLB de '{role}' (el archivo o su animacion deben "
                f"llamarse algo como '{role}').")
    # coherencia entre archivos
    bones = {i["info"]["bones"] for r in ROLES for i in result["by_role"][r] if i["info"]}
    if len(bones) > 1:
        result["errors"].append(
            f"Los GLB no comparten esqueleto (huesos: {sorted(bones)}). "
            "Todos deben salir del mismo personaje.")
    if not result["by_role"]["run"]:
        result["warnings"].append("Sin 'run': se procesan idle, walk y las demas animaciones.")
    # animaciones "diferentes" (Animation_<Nombre>_withSkin.glb): se crean solas con ese nombre
    result["extras"] = []
    groups: dict[str, list] = {}
    for e in list(result["ignored"]):
        if not e["info"] or not e["info"]["animations"] or e["info"]["bones"] == 0:
            acts = ", ".join(e["info"]["animations"]) if e["info"] else "?"
            result["warnings"].append(f"Ignorado (sin esqueleto/animacion): {e['name']}  [animaciones: {acts}]")
            continue
        groups.setdefault(anim_base(e), []).append(e)
    for base, items in sorted(groups.items()):
        items.sort(key=lambda e: e["name"].lower())
        many = len(items) > 1
        for n, e in enumerate(items, 1):
            aid = f"{base}_{n:03d}" if many else base
            e["anim_id"], e["role"], e["why"] = aid, aid, "animacion nueva"
            result["extras"].append(e)
        if many:
            result["warnings"].append(f"{len(items)} animaciones parecidas '{base}': " + ", ".join(f"{e['name']} -> {e['anim_id']}" for e in items))
            if rename:
                tmp = []
                for e in items:
                    t = e["path"].with_name(e["path"].name + ".ms_tmp")
                    e["path"].rename(t)
                    tmp.append(t)
                for e, t in zip(items, tmp):
                    dest = t.with_name(f"{e['anim_id']}.glb")
                    t.rename(dest)
                    e["old_name"], e["path"], e["name"] = e["name"], dest, dest.name
    if result["extras"]:
        result["warnings"].append("Animaciones nuevas: " + ", ".join(e["anim_id"] for e in result["extras"]))
    return result


# ---------------------------------------------------------------- character.json
TEMPLATES = [PIPE / "templates" / "character.template.json",
             PIPE / "profiles" / "character.template.json",
             PIPE / "output" / "Characters" / "character.template.json"]


FRAME_DEFAULTS = {"idle": 16, "walk": 8, "run": 8, "default": 12, "max": 24}


def frame_limit(aid: str, base: str, asset: dict, current: int) -> int:
    """Fotogramas por direccion. Prioridad: asset.json "frames" > pipeline/config/ms.json "frames" > FRAME_DEFAULTS; tope "max"."""
    lim = dict(FRAME_DEFAULTS)
    try:
        lim.update(json.loads((PIPE / "config" / "ms.json").read_text(encoding="utf-8")).get("frames", {}))
    except Exception:  # noqa: BLE001
        pass
    lim.update(asset.get("frames", {}))
    n = lim.get(aid, lim.get(base, lim["default"]))
    return max(1, min(int(n), int(lim["max"])))


def write_manifest(cid: str, display: str, cls: dict, folder_asset: dict | None = None) -> None:
    folder_asset = folder_asset or {}
    """Crea pipeline/characters/<cid>/character.json desde la plantilla (si no existe) y
    pone en source_action el nombre REAL de la animacion de cada GLB (Idle_8, Walking...)."""
    target = CHARS / cid / "character.json"
    tpl = next((t for t in TEMPLATES if t.is_file()), None)
    if tpl is None:
        print("  AVISO: no hay character.template.json; build_character intentara su bootstrap.")
        return
    d = json.loads(tpl.read_text(encoding="utf-8").replace("template_character", cid))
    d.setdefault("character", {})["display_name"] = display.replace("_", " ").title()
    anims = d.setdefault("animations", {})
    canon = {"idle": "Idle", "walk": "Walking", "run": "Running"}   # = nombres canonicos de assemble_character_glb.py

    def canonical(key: str) -> str:
        return canon.get(key) or "".join(p.capitalize() for p in key.split("_"))

    ids = [r for r in ROLES if cls["by_role"][r]] + [e["anim_id"] for e in cls["variants"] + cls["extras"]]
    for aid in ids:
        base = aid.split("_")[0] if aid.split("_")[0] in ROLES and aid not in ROLES else aid
        proto = anims.get(base) or anims.get("walk") or {}
        entry = json.loads(json.dumps(proto)) if proto else {}
        locomotion = base in ROLES
        entry.update({"enabled": True, "source_action": canonical(aid), "loop": locomotion,
                      "atlas_basename": f"{aid}_8dir", "expect_in_place": locomotion})
        if aid not in anims:                   # animacion nueva: 12 fotogramas a 12 fps
            fps, n = (10, 8) if locomotion else (12, 12)
            entry.update({"output_fps": fps, "frame_count": n,
                          "timing": {"mode": "custom", "playback_fps": float(fps), "frame_count": n}})
        n = frame_limit(aid, base, folder_asset, entry.get("frame_count", 12))
        entry["frame_count"] = n
        entry.setdefault("timing", {"mode": "custom", "playback_fps": float(entry.get("output_fps", 10))})["frame_count"] = n
        anims[aid] = entry
    # AVISO ANTES DE ENSAMBLAR: animaciones que desplazan al personaje. Un walk_/run_ con desplazamiento
    # (Walk_Turn_Right) no es un ciclo en el sitio: la auditoria lo rechaza por el nombre DESPUES del render.
    # Y las que se van lejos (Dead, Roll_Dodge, Swim_Forward) se salen del encuadre y recortan. Se miden aqui,
    # en el GLB de cada animacion, y se desactivan con el motivo; se reactivan con "enabled": true.
    rutas = {r: cls["by_role"][r][0]["path"] for r in ROLES if cls["by_role"][r]}
    rutas.update({e["anim_id"]: e["path"] for e in cls["variants"] + cls["extras"]})
    try:
        lim = float(json.loads((PIPE / "config" / "ms.json").read_text(encoding="utf-8")).get("desplazamiento_max", 0.3))
    except Exception:  # noqa: BLE001
        lim = 0.3
    for aid, ruta in rutas.items():
        dz = desplazamiento_final(Path(ruta))
        if dz is None or dz <= lim:
            continue
        e = anims[aid]
        en_sitio = bool(e.get("expect_in_place"))
        if aid in ROLES:
            cls["warnings"].append(f"'{aid}' desplaza al personaje {dz:.2f} altos de cadera: no es un ciclo en el sitio; "
                                   "la auditoria la rechazara. Exporta la version 'in place' de Meshy/Mixamo.")
        elif en_sitio or dz > 1.0:
            e["enabled"] = False
            # El motivo va al REPORTE (warnings), no a character.json: el esquema no admite claves extra.
            que = "no es un ciclo en el sitio (empieza por walk/run)" if en_sitio else "se sale del encuadre"
            cls["warnings"].append(f"Animacion DESACTIVADA antes de renderizar '{aid}' ({Path(ruta).name}): se desplaza "
                                   f"{dz:.2f} altos de cadera y {que}. Para usarla: renombra el GLB (sin walk/run) o pon "
                                   f"\"enabled\": true en character.json y PROCESAR.cmd rapido <id> {aid}.")
            print(f"  AVISO: '{aid}' desactivada (se desplaza {dz:.2f} altos de cadera)")
        else:
            cls["warnings"].append(f"'{aid}' desplaza al personaje {dz:.2f} altos de cadera: puede salirse del encuadre.")
    # cierre de bucle: los GLB de Meshy no siempre cierran perfecto (Spear_Walk ~1.6); limite configurable
    try:
        ratio = float(json.loads((PIPE / "config" / "ms.json").read_text(encoding="utf-8")).get("loop_ratio_max", 2.0))
    except Exception:  # noqa: BLE001
        ratio = 2.0
    if cls["extras"] or cls["variants"]:    # ataques/golpes se salen del encuadre estandar: partir con mas margen
        d["render"]["ortho_scale"] = round(float(d["render"]["ortho_scale"]) * 1.25, 4)
    d.setdefault("validation", {}).setdefault("loop", {})["max_last_to_first_over_mean_step_ratio"] = ratio
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(d, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"  character.json creado desde {tpl.name}")


# ---------------------------------------------------------------- calibracion de altura
def calibrate_height(cid: str) -> bool:
    """Si el build fallo y el validador midio una altura distinta de la esperada (1.7), ajusta
    expected_height_units y ortho_scale (proporcional) del character.json. Devuelve True si cambio algo."""
    rep = OUT / cid / "reports" / "model_rig_validation.json"
    cj = CHARS / cid / "character.json"
    if not rep.is_file() or not cj.is_file():
        return False
    m = re.search(r"character height[^0-9]{0,40}([0-9]+\.[0-9]+)\s*units", rep.read_text(encoding="utf-8", errors="replace"), re.I)
    if not m:
        return False
    h = float(m.group(1))
    d = json.loads(cj.read_text(encoding="utf-8"))
    cur = float(d["model"].get("expected_height_units", 1.7))
    if h <= 0 or abs(h - cur) / cur < 0.05:
        return False
    # solo se ajusta la altura esperada; el encuadre (ortho_scale) NO se toca: el goblin midio 0.76 en reposo
    # pero renderiza como un personaje de ~1.7, y escalar el encuadre lo dejaba gigante y recortado.
    d["model"]["expected_height_units"] = round(h, 4)
    cj.write_text(json.dumps(d, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"  altura medida {h:.3f} (esperada {cur:.3f}): expected_height_units={h:.3f} (encuadre sin cambios)")
    return True


CORE_ANIMS = ("idle", "walk", "run")


def drop_failing(cid: str, dropped: dict, audit_only: bool) -> bool:
    """Desactiva (enabled=false) las animaciones NO basicas que no pasan la auditoria (movimiento de raiz...) o,
    con audit_only=False, la validacion de render. idle/walk/run nunca se omiten."""
    cj = CHARS / cid / "character.json"
    rdir = OUT / cid / "reports"
    if not cj.is_file() or not rdir.is_dir():
        return False
    bad: dict[str, str] = {}
    try:
        au = json.loads((rdir / "animation_audit.json").read_text(encoding="utf-8"))
        for aid, v in (au.get("animations") or {}).items():
            if isinstance(v, dict) and v.get("valid") is False:
                bad[aid] = "; ".join(map(str, v.get("errors") or ["auditoria no valida"]))
    except Exception:  # noqa: BLE001
        pass
    if not audit_only:
        for f in rdir.glob("*_render_validation.json"):
            try:
                v = json.loads(f.read_text(encoding="utf-8"))
            except Exception:  # noqa: BLE001
                continue
            if v.get("valid") is False:
                bad.setdefault(v.get("animation_id") or f.name.replace("_render_validation.json", ""),
                               "; ".join(map(str, (v.get("errors") or [])[:2])))
    bad = {k: w for k, w in bad.items() if k not in CORE_ANIMS and k not in dropped}
    if not bad:
        return False
    d = json.loads(cj.read_text(encoding="utf-8"))
    for aid, why in bad.items():
        if aid in d.get("animations", {}):
            d["animations"][aid]["enabled"] = False
            dropped[aid] = why
            print(f"  animacion omitida '{aid}': {why}")
        (rdir / f"{aid}_render_validation.json").unlink(missing_ok=True)
    cj.write_text(json.dumps(d, indent=2, ensure_ascii=False), encoding="utf-8")
    return True


def fit_margins(cid: str) -> bool:
    """Si las validaciones de render fallan por margen/recorte, recoloca el personaje en el frame:
    centra los margenes vertical (mueve ground_anchor_px y visual_offset_px) y, si no caben, agranda ortho_scale un 15%."""
    cj = CHARS / cid / "character.json"
    rdir = OUT / cid / "reports"
    if not cj.is_file() or not rdir.is_dir():
        return False
    mins = {"top": 10**6, "bottom": 10**6, "left": 10**6, "right": 10**6}
    failing = False
    for f in rdir.glob("*_render_validation.json"):
        try:
            v = json.loads(f.read_text(encoding="utf-8"))
        except Exception:  # noqa: BLE001
            continue
        failing = failing or v.get("valid") is False
        for dd in v.get("directions", {}).values():
            for side in mins:
                m = (dd.get("margins", {}).get(side) or {}).get("min")
                if m is not None:
                    mins[side] = min(mins[side], int(m))
    if not failing or min(mins.values()) >= 4:
        return False
    d = json.loads(cj.read_text(encoding="utf-8"))
    r = d["render"]
    w, h = r["frame_size_px"]
    ax, ay = r["ground_anchor_px"]
    locked = (CHARS / cid / "size_lock.json").is_file()
    if locked and (mins["top"] + mins["bottom"] < 12 or mins["left"] + mins["right"] < 12):
        print("  tamano BLOQUEADO (size_lock.json): no se cambia ortho_scale; revisa margenes a mano")
        return False
    if mins["top"] + mins["bottom"] < 12 or mins["left"] + mins["right"] < 12:
        k = 1.3 if min(mins.values()) <= 0 else 1.15
        r["ortho_scale"] = round(float(r["ortho_scale"]) * k, 4)
        msg = f"ortho_scale x{k} -> {r['ortho_scale']}"
    else:
        dy = round((mins["top"] - mins["bottom"]) / 2)
        if dy == 0:
            return False
        r["ground_anchor_px"] = [ax, ay - dy]
        d.setdefault("godot", {})["visual_offset_px"] = [round(w / 2 - ax), round(h / 2 - (ay - dy))]
        msg = f"ground_anchor_px y {ay} -> {ay - dy}"
    cj.write_text(json.dumps(d, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"  margenes minimos {mins}: {msg}")
    return True


# ---------------------------------------------------------------- ejecucion
def tee_run(cmd: list[str], log: Path) -> int:
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w", encoding="utf-8", errors="replace") as lf:
        p = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True,
                             encoding="utf-8", errors="replace")
        assert p.stdout is not None
        for line in p.stdout:
            sys.stdout.write(line)
            lf.write(line)
        return p.wait()


def collect_reports(cid: str) -> tuple[list[str], list[str], int]:
    """(lineas OK, lineas de fallo, n.o de informes)."""
    ok, bad, n = [], [], 0
    rdir = OUT / cid / "reports"
    if not rdir.is_dir():
        return ok, bad, 0
    # Los informes viejos de animaciones DESACTIVADAS (p. ej. dead tras ponerla enabled: false) no cuentan:
    # se quedan en reports/ de la ejecucion anterior y rechazarian un build que ya no las renderiza.
    apagadas: list[str] = []
    try:
        cfg = json.loads((CHARS / cid / "character.json").read_text(encoding="utf-8-sig"))
        apagadas = [aid for aid, a in cfg.get("animations", {}).items() if not a.get("enabled", True)]
    except Exception:  # noqa: BLE001
        pass
    for f in sorted(rdir.glob("*.json")):
        if any(f.name.startswith(aid + "_") and f.name[len(aid) + 1:] in ("render_validation.json", "atlas_validation.json")
               for aid in apagadas):
            continue
        try:
            d = json.loads(f.read_text(encoding="utf-8"))
        except Exception:  # noqa: BLE001
            bad.append(f"{f.name}: JSON ilegible")
            n += 1
            continue
        if not isinstance(d, dict) or "valid" not in d:
            continue
        n += 1
        if d["valid"] is True:
            ok.append(f.name)
            continue
        why = []
        for c in d.get("checks", []) or []:
            if str(c.get("status", "")).upper() not in ("PASS", "OK", "WARN"):
                why.append(f"{c.get('name')}: {c.get('details', '')}".strip())
        why += [str(e) for e in (d.get("errors") or [])][:5]
        why += [str(e) for e in (d.get("failures") or [])][:5]
        bad.append(f"{f.name}: " + ("; ".join(why) if why else "valid = false"))
    return ok, bad, n


def write_report(cid: str, display: str, cls: dict, exit_code: int,
                 final_id: str, log: Path | None, stage_note: str,
                 art: dict | None = None) -> str:
    ok, bad, n = collect_reports(final_id)
    atl = OUT / final_id / "atlases"
    n_atlas = len(list(atl.rglob("*.png"))) if atl.is_dir() else 0
    tech_ok = exit_code == 0 and n > 0 and not bad and n_atlas > 0
    art_ok = art is None or art["verdict"] == "APROBADO"
    approved = tech_ok and art_ok
    verdict = "APROBADO" if approved else "RECHAZADO"
    L = [f"# {verdict}: {display}  (`{final_id}`)", "",
         f"Fecha: {datetime.now():%Y-%m-%d %H:%M}", ""]
    if not approved:
        L += ["## Por que", ""]
        if stage_note:
            L.append(f"- {stage_note}")
        if exit_code != 0:
            L.append(f"- build_character.py termino con codigo {exit_code}"
                     + (f" (log: `{log}`)" if log else ""))
        if n == 0 and exit_code == 0:
            L.append("- No se generó ningún informe de validación.")
        if n_atlas == 0 and exit_code == 0:
            L.append("- No se generó ningún atlas.")
        for b in bad:
            L.append(f"- {b}")
        if tech_ok and art is not None and not art_ok:
            L.append("- La parte técnica pasó, pero el ARTE no (ver sección Arte).")
        L.append("")
    L += ["## Archivos de entrada", ""]
    for e in cls["files"]:
        i = e["info"] or {}
        L.append(f"- `{e['name']}` -> **{e['role'] or 'sin rol'}**"
                 + (f" ({e['why']})" if e["why"] else "")
                 + (f" | huesos {i.get('bones')}, animaciones: {', '.join(i.get('animations', []))}" if i else ""))
    L.append("")
    if cls["warnings"]:
        L += ["## Avisos", ""] + [f"- {w}" for w in cls["warnings"]] + [""]
    L += ["## Validaciones", ""]
    L += [f"- OK  {x}" for x in ok] + [f"- FALLO  {x}" for x in bad]
    L += ["", f"Atlas generados: {n_atlas}", ""]
    if art is None:
        L += ["## Arte", "", "- No se ha ejecutado (--sin-arte o fallo técnico previo).", ""]
    else:
        import art_stage
        L += art_stage.art_section_lines(art)
    L += [
          f"Salida: `pipeline_output/{final_id}/`  |  Config: `pipeline/characters/{final_id}/character.json`"]
    text = "\n".join(L) + "\n"
    out_dir = OUT / final_id
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "REPORTE.md").write_text(text, encoding="utf-8")
    return verdict


def process(folder: Path, dry: bool, stamp: str, with_art: bool = True, move: bool = True) -> tuple[str, str]:
    display = folder.name
    base = normalize_id(display)
    print(f"\n=== {display} ===")
    if not base:
        print("  ERROR: el nombre de la carpeta no contiene letras ni numeros.")
        return display, "ERROR"
    glbs = sorted(folder.glob("*.glb"))
    if not glbs:
        print("  (sin .glb todavia, se omite)")
        return display, "VACIA"
    if not dry and not wait_stable(glbs):
        print("  ERROR: los archivos siguen cambiando de tamano (copia sin terminar). Reintenta.")
        return display, "COPIANDO"

    cls = classify(folder, rename=not dry)
    for e in cls["files"]:
        i = e["info"] or {}
        print(f"  {e['name']}  ->  {e['role'] or 'sin rol'}"
              + (f"  [huesos {i.get('bones')}; anim: {', '.join(i.get('animations', []))}]" if i else ""))
    for w in cls["warnings"]:
        print("  aviso:", w)
    if cls["errors"]:
        for e in cls["errors"]:
            print("  ERROR:", e)
        if not dry:
            (folder / "ERROR.txt").write_text(
                "No se ha procesado:\n- " + "\n- ".join(cls["errors"]) + "\n", encoding="utf-8")
        return display, "ERROR"

    cid = free_id(base)
    if cid != base:
        print(f"  '{base}' ya existe: se crea '{cid}' (no se pisa nada).")
    if dry:
        print(f"  [dry-run] se crearia pipeline/characters/{cid}")
        return display, "DRY"

    incoming = CHARS / cid / "incoming"
    incoming.mkdir(parents=True, exist_ok=True)
    for role in ROLES:
        for e in cls["by_role"][role]:
            shutil.copy2(e["path"], incoming / f"{role}.glb")

    try:
        asset = json.loads((folder / "asset.json").read_text(encoding="utf-8"))
    except Exception:  # noqa: BLE001
        asset = {}
    write_manifest(cid, display, cls, asset)
    src_dir = CHARS / cid / "source"
    src_dir.mkdir(parents=True, exist_ok=True)
    for e in cls["variants"] + cls["extras"]:      # los roles idle/walk/run van por incoming/; el resto directo a source/
        shutil.copy2(e["path"], src_dir / f"{e['anim_id']}.glb")
    log = INBOX / "_logs" / f"{cid}_{stamp}.log"
    cmd = [sys.executable, str(PIPE / "tools" / "build_character.py"), cid, "--sin-reporte"]   # el REPORTE lo escribe esto
    print(f"  > {' '.join(cmd)}")
    code = tee_run(cmd, log)
    dropped: dict[str, str] = {}
    fits = 0
    for _ in range(6):                      # autoajuste: altura, encuadre, y omitir animaciones imposibles; reintenta
        if code == 0:
            break
        if calibrate_height(cid):
            pass
        elif drop_failing(cid, dropped, audit_only=True):
            pass
        elif fits < 2 and fit_margins(cid):
            fits += 1
        elif drop_failing(cid, dropped, audit_only=False):
            pass
        else:
            break
        print("  > reintento con los ajustes automaticos")
        code = tee_run(cmd, log)
    for aid, why in dropped.items():
        cls["warnings"].append(f"Animacion OMITIDA '{aid}': {why}")
    art = None
    if with_art and code == 0:
        _, bad0, n0 = collect_reports(cid)
        if n0 > 0 and not bad0:
            import art_stage
            art = art_stage.run_art_stage(cid, OUT / cid / "art_stage.log")
        else:
            print("  (arte omitido: la parte técnica no pasó)")
    verdict = write_report(cid, display, cls, code, cid, log, "", art)

    if move:   # ms_assets.py pasa move=False y archiva el solo segun el veredicto
        done = INBOX / "_procesados"
        done.mkdir(exist_ok=True)
        shutil.move(str(folder), str(done / f"{display}_{stamp}"))
    print(f"\n  >>> {verdict}: pipeline_output/{cid}/REPORTE.md")
    return display, verdict


def ensure_layout() -> None:
    INBOX.mkdir(parents=True, exist_ok=True)
    readme = INBOX / "LEEME.txt"
    if not readme.exists():
        readme.write_text(
            "Crea aqui una carpeta con el nombre del personaje y mete sus .glb\n"
            "(uno por animacion: idle, walk, run). Luego doble clic en\n"
            "pipeline\\PROCESAR_PERSONAJES.cmd. El resultado y el veredicto estan en\n"
            "pipeline_output\\<personaje>\\REPORTE.md\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="solo clasifica, no toca nada")
    ap.add_argument("--sin-arte", action="store_true", help="omite la fase de arte (E2E + render + QA de imagen)")
    args = ap.parse_args()
    ensure_layout()
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    folders = sorted(p for p in INBOX.iterdir()
                     if p.is_dir() and not p.name.startswith(("_", ".")))
    if not folders:
        print("No hay carpetas en pipeline\\inbox. Crea una con el nombre del personaje y sus .glb.")
        return 0
    results = [process(f, args.dry_run, stamp, not args.sin_arte) for f in folders]
    print("\n" + "=" * 60)
    for name, v in results:
        print(f"  {v:10s} {name}")
    print("=" * 60)
    return 0 if all(v in ("APROBADO", "DRY", "VACIA") for _, v in results) else 1


if __name__ == "__main__":
    sys.exit(main())
