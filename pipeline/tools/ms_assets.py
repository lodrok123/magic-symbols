#!/usr/bin/env python3
"""Magic Symbols - orquestador unico de assets (solo stdlib).

    PROCESAR.cmd                      procesa todo lo pendiente de pipeline\\inbox
    PROCESAR.cmd nuevo <tipo> <id>    crea inbox\\<id>\\ con un asset.json de plantilla
    PROCESAR.cmd aprobar <id>         aprueba un asset "en revision" y lo exporta
    PROCESAR.cmd rehacer <id>         saca <id> del archivo y lo vuelve a procesar
    PROCESAR.cmd rapido <id> [a,b,c|todas]  re-renderiza solo esas animaciones (def. idle,walk,run; 'todas' = las 15) y re-exporta
    PROCESAR.cmd estado               tabla de todos los assets y escenas
    PROCESAR.cmd escena <id>          genera una escena (terreno) de pipeline\\scenes\\<id>
    PROCESAR.cmd migrar               ordena el paquete de terreno antiguo (pipeline\\output\\Terreno)
    PROCESAR.cmd demo                 reinstala la escena demo en export_godot\\demo
Opciones: --force (ignora "sin cambios")  --sin-arte  --dry-run

CAPAS:   inbox/<id>/ (GLB + asset.json) -> pipeline_output/<id>/ (trabajo, logs, REPORTE.md)
         -> export_godot/<tipo>/<id>/ (solo aprobados) ; archive/<id>/ (originales ya aprobados)
TIPOS:   character, enemy (idle/walk/run -> atlas 8 dir) | tree, prop, weapon (render iso por angulos)
ESTADOS: pendiente, procesado, en revision, aprobado, rechazado, error
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
ROOT = HERE.parents[1]
PIPE = ROOT / "pipeline"
INBOX = PIPE / "inbox"
ARCHIVE = PIPE / "archive"
SCENES = PIPE / "scenes"
CONFIG = PIPE / "config" / "ms.json"
CATALOG = PIPE / "catalogo.json"
WORK = ROOT / "pipeline_output"
EXPORT = ROOT / "export_godot"
TERRENO_TOOLS = HERE / "terreno"
DEMO_SRC = HERE / "godot_demo"

DEFAULT_CFG = {
    "blender": r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe",
    "auto_export": {"character": True, "enemy": True, "tree": False, "prop": False, "weapon": False, "scene": False},
    "export_dir": {"character": "characters", "enemy": "enemies", "tree": "trees", "prop": "props", "weapon": "weapons", "scene": "terrain"},
    "defaults": {"tree": {"height_px": 108, "angles": [0, 72, 144, 216, 288], "style": "anime_a"},
                 "prop": {"height_px": 64, "angles": [0], "style": "anime_a"},
                 "weapon": {"height_px": 64, "angles": [0], "style": "anime_a"}},
    "export_contract": "1.1",
}
TYPES = ("character", "enemy", "tree", "prop", "weapon")
STATES = ("pendiente", "procesado", "en revision", "aprobado", "rechazado", "error")


# ------------------------------------------------------------------ utilidades
def jload(p: Path, default=None):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:  # noqa: BLE001
        return default


def jsave(p: Path, d) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(d, indent=2, ensure_ascii=False), encoding="utf-8")


def cfg() -> dict:
    c = json.loads(json.dumps(DEFAULT_CFG))
    user = jload(CONFIG, {})
    for k, v in user.items():
        if isinstance(v, dict) and isinstance(c.get(k), dict):
            c[k].update(v)
        else:
            c[k] = v
    if not CONFIG.exists():
        jsave(CONFIG, DEFAULT_CFG)
    return c


def catalog() -> dict:
    return jload(CATALOG, {}) or {}


def set_status(aid: str, **kw) -> None:
    cat = catalog()
    e = cat.setdefault(aid, {})
    e.update(kw)
    e["actualizado"] = datetime.now().strftime("%Y-%m-%d %H:%M")
    jsave(CATALOG, cat)


def folder_hash(folder: Path) -> str:
    h = hashlib.sha256()
    for p in sorted(folder.iterdir()):
        if not p.is_file() or p.name in ("ERROR.txt",):
            continue
        h.update(p.name.encode())
        with p.open("rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
    return h.hexdigest()[:16]


def stable_id(name: str) -> str:
    from procesar_inbox import normalize_id
    return normalize_id(name)


def infer_type(folder: Path) -> str:
    from procesar_inbox import ROLES, classify
    try:
        cls = classify(folder)
        if any(cls["by_role"][r] for r in ROLES):
            return "character"
    except Exception:  # noqa: BLE001
        pass
    for g in folder.glob("*.glb"):   # con esqueleto y animaciones = personaje
        try:
            from procesar_inbox import glb_info
            i = glb_info(g)
            if i["bones"] > 0 and i["animations"]:
                return "enemy" if folder.name.lower().startswith(("enemy", "goblin")) else "character"
        except Exception:  # noqa: BLE001
            pass
    low = folder.name.lower()
    for t in ("tree", "enemy", "prop", "weapon"):
        if low.startswith(t):
            return t
    return "prop"


def read_asset(folder: Path) -> dict:
    """asset.json del inbox; si falta lo crea infiriendo el tipo."""
    f = folder / "asset.json"
    a = jload(f)
    if a is None:
        a = {"id": stable_id(folder.name), "nombre": folder.name, "tipo": infer_type(folder)}
        jsave(f, a)
        print(f"  (creado asset.json con tipo '{a['tipo']}': revisalo si no es correcto)")
    a.setdefault("id", stable_id(folder.name))
    a.setdefault("nombre", folder.name)
    a.setdefault("version", 1)
    a.setdefault("licencia", {"tipo": "", "autor": "", "fuente": "", "atribucion_requerida": False})
    return a


def template(tipo: str, aid: str) -> dict:
    d = cfg()["defaults"].get(tipo, {})
    a = {"id": aid, "nombre": aid, "tipo": tipo, "version": 1,
         "licencia": {"tipo": "", "autor": "", "fuente": "", "atribucion_requerida": False}, "notas": ""}
    if tipo in ("character", "enemy"):
        a["altura_unidades"] = 1.7
        a["estilo"] = "anime_a"
    else:
        a.update({"glb": "", "altura_px": d.get("height_px", 64), "angulos": d.get("angles", [0]),
                  "estilo": d.get("style", "anime_a"), "variantes_color": []})
    return a


def write_report(aid: str, verdict: str, a: dict, lines: list[str]) -> None:
    lic = a.get("licencia", {})
    L = [f"# {verdict}: {a.get('nombre', aid)}  (`{aid}`)", "", f"Fecha: {datetime.now():%Y-%m-%d %H:%M}",
         f"Tipo: {a.get('tipo')}  |  Version: {a.get('version')}", ""]
    L += lines
    if lic.get("atribucion_requerida"):
        L += ["", "## Licencia", "", f"- {lic.get('tipo')} - {lic.get('autor')} ({lic.get('fuente')}). **Atribucion obligatoria**."]
    d = WORK / aid
    d.mkdir(parents=True, exist_ok=True)
    (d / "REPORTE.md").write_text("\n".join(L) + "\n", encoding="utf-8")


def ensure_demo() -> None:
    dst = EXPORT / "demo"
    dst.mkdir(parents=True, exist_ok=True)
    for f in DEMO_SRC.glob("*"):
        shutil.copy2(f, dst / f.name)


def archive(folder: Path, aid: str) -> None:
    dst = ARCHIVE / aid
    if dst.exists():
        shutil.rmtree(dst)
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    shutil.move(str(folder), str(dst))


# ------------------------------------------------------------------ personajes
def run_character(folder: Path, a: dict, args, stamp: str) -> str:
    import procesar_inbox as pi
    pi.ensure_layout()
    # el motor existente nombra por carpeta: la carpeta ya ES el id estable
    display, verdict = pi.process(folder, args.dry_run, stamp, not args.sin_arte, move=False)
    return verdict


def export_character(aid: str, tipo: str) -> bool:
    folder = "enemies" if tipo == "enemy" else "characters"
    r = subprocess.run([sys.executable, str(HERE / "exportar_godot.py"), aid, "--tipo", folder], cwd=ROOT)
    return r.returncode == 0


# ------------------------------------------------------------------ arboles / props
def run_render(folder: Path, a: dict, args) -> tuple[str, list[str]]:
    c = cfg()
    glbs = sorted(folder.glob("*.glb"))
    name = a.get("glb") or (glbs[0].name if glbs else "")
    glb = folder / name if name else None
    if not glb or not glb.exists():
        return "ERROR", [f"- No hay .glb en {folder} (campo 'glb' de asset.json: '{name}')"]
    blender = os.environ.get("BLENDER_EXE") or c["blender"]
    if not Path(blender).exists():
        return "ERROR", [f"- No se encuentra Blender: {blender}  (ajusta pipeline/config/ms.json o BLENDER_EXE)"]
    d = c["defaults"].get(a["tipo"], {})
    angles = a.get("angulos") or d.get("angles", [0])
    out = WORK / a["id"] / "render"
    out.mkdir(parents=True, exist_ok=True)
    log = WORK / a["id"] / "render.log"
    cmd = [blender, "--background", "--factory-startup", "--python", str(TERRENO_TOOLS / "ms_render_tree.py"), "--",
           "--glb", str(glb), "--out-dir", str(out), "--angles", ",".join(str(x) for x in angles),
           "--height", str(a.get("altura_px") or d.get("height_px", 64)), "--style", a.get("estilo") or d.get("style", "anime_a"),
           "--config", str(TERRENO_TOOLS / "ms_terrain_config.json"), "--force"]
    with log.open("w", encoding="utf-8", errors="replace") as lf:
        code = subprocess.call(cmd, cwd=ROOT, stdout=lf, stderr=subprocess.STDOUT)
    pngs = sorted(out.glob("*.png"))
    if code != 0 or len(pngs) < len(angles):
        return "RECHAZADO", [f"- Blender termino con codigo {code} y hay {len(pngs)}/{len(angles)} renders (log: `{log}`)"]
    try:
        make_contact_sheet(pngs, WORK / a["id"] / "hoja_revision.png")
    except Exception as e:  # noqa: BLE001
        print("  (sin hoja de revision:", e, ")")
    return "EN REVISION", [f"- {len(pngs)} renders en `pipeline_output/{a['id']}/render/`", "- Revisa `hoja_revision.png`; si te gusta: `PROCESAR.cmd aprobar " + a["id"] + "`"]


def make_contact_sheet(pngs: list[Path], dst: Path) -> None:
    from PIL import Image  # opcional
    ims = [Image.open(p).convert("RGBA") for p in pngs]
    bbs = [im.getbbox() or (0, 0, 1, 1) for im in ims]
    crops = [im.crop(b) for im, b in zip(ims, bbs)]
    h = max(c.height for c in crops)
    w = sum(c.width for c in crops) + 12 * (len(crops) + 1)
    sheet = Image.new("RGBA", (w, h + 24), (150, 170, 140, 255))
    x = 12
    for c in crops:
        sheet.alpha_composite(c, (x, 12))
        x += c.width + 12
    sheet.save(dst)


def export_render(aid: str, a: dict) -> bool:
    c = cfg()
    src = WORK / aid / "render"
    pngs = sorted(src.glob("*.png"))
    if not pngs:
        print(f"ERROR: no hay renders de {aid}; procesalo antes")
        return False
    dst = EXPORT / c["export_dir"][a["tipo"]] / aid
    if dst.exists():
        shutil.rmtree(dst)
    (dst / "sprites").mkdir(parents=True)
    for p in pngs:
        shutil.copy2(p, dst / "sprites" / p.name)
    meta = {"id": aid, "nombre": a.get("nombre", aid), "tipo": a["tipo"], "version": a.get("version", 1),
            "altura_px": a.get("altura_px"), "angulos": a.get("angulos"),
            "sprites": [f"sprites/{p.name}" for p in pngs], "ancla": "base_centro",
            "licencia": a.get("licencia", {}), "aprobado": datetime.now().strftime("%Y-%m-%d"),
            "contrato": c["export_contract"]}
    jsave(dst / "meta.json", meta)
    rep = WORK / aid / "REPORTE.md"
    if rep.exists():
        shutil.copy2(rep, dst / "REPORTE.md")
    print(f"EXPORTADO: {dst}")
    return True


# ------------------------------------------------------------------ escenas (terreno)
def run_scene(sid: str, args) -> str:
    sd = SCENES / sid
    sj = jload(sd / "scene.json")
    if sj is None:
        print(f"ERROR: falta {sd / 'scene.json'}")
        return "ERROR"
    c = cfg()
    tcfg = sd / sj.get("config", "ms_terrain_config.json")
    if not tcfg.exists():
        tcfg = TERRENO_TOOLS / "ms_terrain_config.json"
    # los arboles de la escena son assets: sus renders se copian a <escena>/Output/trees
    trees = sj.get("arboles", [])
    if trees:
        dstt = sd / "Output" / "trees"
        dstt.mkdir(parents=True, exist_ok=True)
        t0 = trees[0]
        src = WORK / t0 / "render"
        pngs = sorted(src.glob("tree_a*.png"))
        if not pngs:
            print(f"ERROR: la escena usa el arbol '{t0}' pero no tiene renders. Procesalo y aprobalo antes.")
            return "ERROR"
        for p in pngs:
            shutil.copy2(p, dstt / p.name)
    cmd = [sys.executable, str(TERRENO_TOOLS / "ms_terrain_compose.py"), "--root", str(sd), "--config", str(tcfg),
           "--fire", sj.get("fuego", "on")]
    if sj.get("seed") is not None:
        cmd += ["--seed", str(sj["seed"])]
    code = subprocess.call(cmd, cwd=ROOT)
    if code != 0:
        set_status(sid, tipo="scene", estado="error")
        return "ERROR"
    out = sd / "Output"
    dst = EXPORT / c["export_dir"]["scene"] / sid
    if dst.exists():
        shutil.rmtree(dst)
    dst.mkdir(parents=True)
    for f in out.glob("map*.png"):
        shutil.copy2(f, dst / f.name)
    if (out / "sprites").is_dir():
        shutil.copytree(out / "sprites", dst / "sprites")
    for f in ("REPORTE.md", "report.json"):
        if (out / f).exists():
            shutil.copy2(out / f, dst / f)
    meta = {"id": sid, "tipo": "scene", "nombre": sj.get("nombre", sid), "arboles": trees,
            "tile_px": [128, 64], "contrato": c["export_contract"],
            "generado": datetime.now().strftime("%Y-%m-%d %H:%M")}
    jsave(dst / "meta.json", meta)
    set_status(sid, tipo="scene", estado="en revision" if not c["auto_export"]["scene"] else "aprobado")
    print(f"ESCENA: {dst}")
    return "OK"


def migrate() -> None:
    old = PIPE / "output" / "Terreno"
    if not old.is_dir():
        print("No hay pipeline\\output\\Terreno que migrar.")
        return
    dst = SCENES / "bosque_01"
    if dst.exists():
        print(f"Ya existe {dst}; no se toca.")
        return
    dst.mkdir(parents=True)
    for n in ("Assets", "Materials", "Terrain", "Output", "forest_map.json"):
        if (old / n).exists():
            shutil.move(str(old / n), str(dst / n))
    jsave(dst / "scene.json", {"id": "bosque_01", "nombre": "Bosque", "tipo": "scene", "mapa": "forest_map.json",
                               "fuego": "both", "seed": 7, "arboles": ["tree_ghibli_01"], "config": "ms_terrain_config.json"})
    shutil.copy2(TERRENO_TOOLS / "ms_terrain_config.json", dst / "ms_terrain_config.json")
    # el GLB del arbol pasa a ser un asset del inbox
    glbs = sorted((dst / "Materials").glob("*.glb")) if (dst / "Materials").is_dir() else []
    if glbs:
        t = INBOX / "tree_ghibli_01"
        t.mkdir(parents=True, exist_ok=True)
        shutil.move(str(glbs[0]), str(t / glbs[0].name))
        a = template("tree", "tree_ghibli_01")
        a.update({"nombre": "Arbol Ghibli", "glb": glbs[0].name,
                  "licencia": {"tipo": "CC-BY-4.0", "autor": "Alex Ace", "fuente": "Sketchfab", "atribucion_requerida": True}})
        jsave(t / "asset.json", a)
    print(f"Terreno migrado a {dst}. Scripts en pipeline\\tools\\terreno. Sobras antiguas en {old} (borralas si quieres).")


# ------------------------------------------------------------------ flujo principal
def flatten(folder: Path) -> None:
    """Un zip descomprimido deja los GLB en una subcarpeta: si arriba no hay ninguno, se suben."""
    if any(folder.glob("*.glb")):
        return
    for sub in sorted(p for p in folder.iterdir() if p.is_dir() and not p.name.startswith(("_", "."))):
        glbs = list(sub.rglob("*.glb"))
        if not glbs:
            continue
        for g in glbs:
            dst = folder / g.name
            if not dst.exists():
                shutil.move(str(g), str(dst))
        try:
            shutil.rmtree(sub)
        except OSError:
            pass
        print(f"  GLB subidos desde la subcarpeta {sub.name}")


def process_asset(folder: Path, args, stamp: str) -> tuple[str, str]:
    flatten(folder)
    a = read_asset(folder)
    aid = a["id"]
    tipo = a["tipo"]
    print(f"\n=== {aid} ({tipo}) ===")
    if tipo in ("prop", "weapon", "tree") and not a.get("glb") and infer_type(folder) in ("character", "enemy"):
        a["tipo"] = tipo = infer_type(folder)       # asset.json autogenerado con tipo mal inferido
        jsave(folder / "asset.json", a)
        print(f"  tipo corregido a '{tipo}'")
    if tipo not in TYPES:
        print(f"  tipo desconocido '{tipo}'. Validos: {', '.join(TYPES)}")
        return aid, "ERROR"
    if folder.name != aid and tipo in ("character", "enemy"):
        print(f"  AVISO: la carpeta '{folder.name}' deberia llamarse '{aid}' (el motor usa el nombre de la carpeta).")
    h = folder_hash(folder)
    prev = catalog().get(aid, {})
    if not args.force and prev.get("hash") == h and prev.get("estado") in ("en revision", "aprobado"):
        print(f"  sin cambios desde la ultima vez ({prev['estado']}). Usa --force para rehacer.")
        return aid, "SIN CAMBIOS"
    if args.dry_run:
        print("  [dry-run]")
        return aid, "DRY"
    set_status(aid, tipo=tipo, estado="pendiente", hash=h, version=a["version"], licencia=a["licencia"])
    c = cfg()
    if tipo in ("character", "enemy"):
        v = run_character(folder, a, args, stamp)
        if v == "APROBADO" and c["auto_export"].get(tipo, True):
            ok = export_character(aid, tipo)
            state = "aprobado" if ok else "error"
        else:
            state = {"APROBADO": "en revision"}.get(v, "rechazado" if v == "RECHAZADO" else "error")
        set_status(aid, estado=state)
        if state == "aprobado":
            ensure_demo()
            archive(folder, aid)
        return aid, state.upper()
    v, lines = run_render(folder, a, args)
    write_report(aid, "APROBADO" if v == "EN REVISION" else v, a, lines)
    state = {"EN REVISION": "en revision", "RECHAZADO": "rechazado"}.get(v, "error")
    set_status(aid, estado=state)
    print("  >>>", state, f"(pipeline_output/{aid}/REPORTE.md)")
    return aid, state.upper()


def cmd_aprobar(aid: str) -> int:
    folder = INBOX / aid
    a = jload(folder / "asset.json") or jload(ARCHIVE / aid / "asset.json")
    if not a:
        print(f"No encuentro el asset {aid}")
        return 1
    if a["tipo"] in ("character", "enemy"):
        ok = export_character(aid, a["tipo"])
    else:
        ok = export_render(aid, a)
    if ok:
        set_status(aid, estado="aprobado")
        ensure_demo()
        if folder.is_dir():
            archive(folder, aid)
    return 0 if ok else 1


def cmd_estado() -> None:
    cat = catalog()
    print(f"{'ID':32s} {'TIPO':10s} {'ESTADO':12s} ACTUALIZADO")
    for k, v in sorted(cat.items()):
        print(f"{k:32s} {v.get('tipo','?'):10s} {v.get('estado','?'):12s} {v.get('actualizado','')}")
    pend = [p.name for p in INBOX.iterdir() if p.is_dir() and not p.name.startswith(("_", ".")) and p.name not in cat] if INBOX.is_dir() else []
    for p in pend:
        print(f"{p:32s} {'?':10s} {'nuevo':12s}")
    if SCENES.is_dir():
        for s in sorted(SCENES.iterdir()):
            if (s / "scene.json").exists() and s.name not in cat:
                print(f"{s.name:32s} {'scene':10s} {'sin generar':12s}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("accion", nargs="?", default="procesar")
    ap.add_argument("resto", nargs="*")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--sin-arte", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args, _extra = ap.parse_known_args()
    cfg()
    for d in (INBOX, ARCHIVE, SCENES, WORK):
        d.mkdir(parents=True, exist_ok=True)
    acc = args.accion.lower()
    if acc == "nuevo":
        if len(args.resto) != 2 or args.resto[0] not in TYPES:
            print("Uso: nuevo <tipo> <id>   tipos:", ", ".join(TYPES))
            return 2
        tipo, name = args.resto
        aid = stable_id(name)
        if not aid.startswith(tipo):
            aid = f"{tipo}_{aid}"
        f = INBOX / aid
        f.mkdir(parents=True, exist_ok=True)
        if not (f / "asset.json").exists():
            jsave(f / "asset.json", template(tipo, aid))
        print(f"Creada {f}. Mete el/los .glb y ajusta asset.json; luego PROCESAR.cmd")
        return 0
    if acc == "cola":
        import ms_cola
        return ms_cola.run()
    if acc == "arte":
        import ms_arte
        return ms_arte.run(sys.argv[sys.argv.index(args.accion) + 1:] if args.accion in sys.argv else args.resto)
    if acc == "rapido":
        # PROCESAR.cmd rapido <id> [anim1,anim2,...]  -> re-renderiza SOLO esas animaciones con el character.json
        # y el estilo actuales (sin reensamblar ni tocar el manifiesto) y re-exporta a export_godot.
        if not args.resto:
            print("Uso: rapido <id> [idle,walk,run]")
            return 2
        aid = args.resto[0]
        anims = args.resto[1] if len(args.resto) > 1 else "idle,walk,run"
        if anims.lower() in ("todas", "todo", "all"):
            anims = "all"
        tipo = "enemies" if aid.startswith("enemy") else "characters"
        bc = [sys.executable, str(HERE / "build_character.py"), aid, "--animations", anims,
              "--force-renders", "--force-atlases"]
        print("  >", " ".join(bc), flush=True)
        rc = subprocess.call(bc, cwd=ROOT)
        if rc != 0:
            print(f"\nbuild_character termino con codigo {rc}: NO se exporta. Revisa pipeline_output\\{aid}\\reports")
            return rc
        ex = [sys.executable, str(HERE / "exportar_godot.py"), aid, "--tipo", tipo, "--forzar"]
        rc = subprocess.call(ex, cwd=ROOT)
        print("\nExportado. Abre res://export_godot/demo/demo.tscn en Godot." if rc == 0 else "\nFallo la exportacion.")
        return rc
    if acc == "estado":
        cmd_estado()
        return 0
    if acc == "migrar":
        migrate()
        return 0
    if acc == "demo":
        ensure_demo()
        print(f"Demo instalada en {EXPORT / 'demo'} (abre res://export_godot/demo/demo.tscn)")
        return 0
    if acc == "aprobar":
        return cmd_aprobar(args.resto[0]) if args.resto else 2
    if acc == "escena":
        rc = [run_scene(s, args) for s in (args.resto or [p.name for p in sorted(SCENES.iterdir()) if (p / "scene.json").exists()])]
        return 0 if all(r == "OK" for r in rc) else 1
    if acc == "rehacer":
        for aid in args.resto:
            src = ARCHIVE / aid
            if src.is_dir():
                shutil.move(str(src), str(INBOX / aid))
        args.force = True
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    targets = [INBOX / x for x in args.resto] if acc == "rehacer" else \
        sorted(p for p in INBOX.iterdir() if p.is_dir() and not p.name.startswith(("_", ".")))
    if not targets:
        print("Inbox vacio. Crea una carpeta con 'PROCESAR.cmd nuevo <tipo> <id>' o copia aqui carpeta+GLB.")
        return 0
    res = [process_asset(f, args, stamp) for f in targets]
    print("\n" + "=" * 60)
    for aid, v in res:
        print(f"  {v:12s} {aid}")
    print("=" * 60)
    return 0 if all(v in ("APROBADO", "EN REVISION", "SIN CAMBIOS", "DRY") for _, v in res) else 1


if __name__ == "__main__":
    sys.exit(main())
