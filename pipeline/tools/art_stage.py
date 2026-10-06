#!/usr/bin/env python3
"""
FASE DE ARTE: encadena lo que antes se hacia a mano y lo convierte en veredicto.

    master.glb
      -> run_npc_e2e_v24.cmd   (look, bake de color/rugosidad, materiales limpios,
                                quitar helpers, GLB final)            [Blender]
      -> render_npc_v25.cmd    (8 direcciones con el Render Studio)   [Blender]
      -> audit_render_alpha.py (agujeros y alfa parcial)
      -> art_cardinal_check.py (S/E/N/W realmente distintas)
      -> art_review_sheet.py   (hojas de silueta/proporcion para mirar a ojo)
      -> puertas (pipeline/profiles/art_gates.json)  ->  APROBADO / RECHAZADO

Todo reutiliza las herramientas que ya existian; aqui solo se ejecutan en orden,
se leen sus JSON y se aplican umbrales. Los umbrales estan en art_gates.json
(calibrados con bookseller_girl, que pasaba); editalos sin tocar codigo.

Los atlas de build_character salen por defecto del master SIN este look. Para sacarlos del GLB
procesado que deja esta fase (pipeline_output/<id>/art/model/npc_processed.glb): "atlas_desde": "arte"
en pipeline/config/ms.json, o "modelo": "arte" en render de character.json (ver atlas_origen.py).
El resultado de cada ejecucion queda en pipeline_output/<id>/art/art_result.json (lo lee cerrar_build.py).
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PIPE = ROOT / "pipeline"
OUT = ROOT / "pipeline_output"
GATES_FILE = PIPE / "profiles" / "art_gates.json"
DIRS8 = "S,SW,W,NW,N,NE,E,SE"

DEFAULT_GATES = {
    "_nota": "Calibrado con bookseller_girl (aprobado): alfa parcial <=2.3%, "
             "huecos <=6 (mayor 125 px), diferencia entre cardinales >=11 RGBA.",
    "alpha": {"max_partial_alpha_ratio": 0.05, "max_holes_per_direction": 12,
              "max_largest_hole_px": 400},
    "cardinal": {"min_mean_abs_rgba": 3.0, "min_changed_bbox_area_ratio": 0.05},
    "render": {"max_ground_anchor_error_px": 8.0},
}


def load_gates() -> dict:
    if not GATES_FILE.exists():
        GATES_FILE.parent.mkdir(parents=True, exist_ok=True)
        GATES_FILE.write_text(json.dumps(DEFAULT_GATES, indent=2, ensure_ascii=False), encoding="utf-8")
        return DEFAULT_GATES
    return json.loads(GATES_FILE.read_text(encoding="utf-8"))


def run(cmd: list[str], log: Path) -> int:
    if os.name == "nt" and str(cmd[0]).lower().endswith((".cmd", ".bat")):
        # Los .cmd parten los argumentos por comas ("S,SW,W" llegaria como "S"):
        # hay que entrecomillarlos uno a uno y envolver todo para cmd /c.
        cmd = 'cmd /c "' + " ".join(f'"{x}"' for x in cmd) + '"'
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("a", encoding="utf-8", errors="replace") as lf:
        lf.write("\n$ " + (cmd if isinstance(cmd, str) else " ".join(map(str, cmd))) + "\n")
        p = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             text=True, encoding="utf-8", errors="replace")
        assert p.stdout is not None
        for line in p.stdout:
            sys.stdout.write(line)
            lf.write(line)
        return p.wait()


def jload(p: Path):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:  # noqa: BLE001
        return None


def free_test(cid: str) -> str:
    base = f"{cid}_art"
    t, n = base, 1
    while (OUT / "npc_e2e" / t).exists():
        n += 1
        t = f"{base}{n}"
    return t


def adapt_frames(flat_dir: Path, dest: Path) -> None:
    """render_npc_v25 guarda S.png; las herramientas de QA esperan S/<frame>.png."""
    if dest.exists():
        shutil.rmtree(dest)
    for png in flat_dir.glob("*.png"):
        d = dest / png.stem
        d.mkdir(parents=True, exist_ok=True)
        shutil.copy2(png, d / f"art_{png.stem}_000.png")


def check(name: str, ok: bool, detail: str = "") -> dict:
    return {"name": name, "ok": bool(ok), "detail": detail}


def clipping_bad(v) -> bool:
    if isinstance(v, bool):
        return v
    if isinstance(v, dict):
        return any(x is True for x in v.values())
    return False


def run_art_stage(cid: str, log: Path) -> dict:
    gates = load_gates()
    res = {"ran": True, "checks": [], "sheets": [], "artifacts": [], "notes": [], "verdict": "RECHAZADO"}
    C = res["checks"]
    master = PIPE / "characters" / cid / f"{cid}_master.glb"
    if not master.is_file():
        C.append(check("master.glb", False, f"no existe {master}"))
        return res

    test = free_test(cid)
    work = OUT / "npc_e2e" / test
    print(f"\n--- ARTE: {cid} (test {test}) ---")

    # 1) E2E: look + bake + materiales + GLB limpio
    code = run([str(PIPE / "run_npc_e2e_v24.cmd"), str(master), test], log)
    qa = jload(work / "reports" / "06_qa_report.json") or {}
    C.append(check("E2E (bake + materiales + GLB limpio)",
                   code == 0 and qa.get("status") == "QA_OK",
                   f"exit {code}; QA {qa.get('status')}; {', '.join(qa.get('problems', []))}"))
    if not C[-1]["ok"]:
        return res

    # 2) Render 8 direcciones
    code = run([str(PIPE / "render_npc_v25.cmd"), test, DIRS8], log)
    rq = (jload(work / "reports" / "07_render_qa_report.json") or {}).get("qa", {})
    err = rq.get("ground_anchor_error_px")
    err_max = gates["render"]["max_ground_anchor_error_px"]
    n_png = len(list((work / "renders" / "idle").glob("*.png")))
    C.append(check("Render 8 direcciones",
                   code == 0 and bool(rq) and rq.get("actual_render_count") == 8 and n_png == 8,
                   f"exit {code}; informe {rq.get('actual_render_count')}/{rq.get('expected_render_count')}; PNG en disco: {n_png} (esperadas 8)"))
    C.append(check("Aislamiento del personaje", rq.get("character_isolation") == "ISOLATION_OK", str(rq.get("character_isolation"))))
    C.append(check("Camara", rq.get("camera_qa") == "OK", str(rq.get("camera_qa"))))
    C.append(check("Sin recortes (clipping)", not clipping_bad(rq.get("clipping")), json.dumps(rq.get("clipping"))))
    if isinstance(err, dict):
        err = max(abs(float(err.get("x", 0))), abs(float(err.get("y", 0))))
    if isinstance(err, (int, float)):
        C.append(check("Ancla al suelo", abs(err) <= err_max, f"{err} px (max {err_max})"))
    if not all(c["ok"] for c in C if c["name"] != "Ancla al suelo"):
        return res

    # 2b) Aviso: el rango de frames cambia al exportar/importar el GLB?
    try:
        e2e = jload(work / "reports" / "e2e_report.json") or {}
        antes = {x["name"]: x["frame_range"][1] for x in e2e.get("ingest", {}).get("actions", [])}
        despues = {}
        full = jload(work / "reports" / "07_render_qa_report.json") or {}
        for x in full.get("action_diagnostics", {}).get("imported_actions", []):
            despues[re.sub(r"\.\d+$", "", x["name"])] = x["frame_range"][1]
        for n, f0 in antes.items():
            f1 = despues.get(n)
            if f1 and f0 and abs(f1 / f0 - 1.0) > 0.01:
                res["notes"].append(f"AVISO: '{n}' pasa de {f0:g} a {f1:g} frames al exportar (x{f1 / f0:.3f}). "
                                    "Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.")
    except Exception as e:  # noqa: BLE001
        res["notes"].append(f"(no se pudo comparar el rango de frames: {e})")

    # 3) Auditorias de imagen
    flat = work / "renders" / "idle"
    qa_dir = work / "reports" / "art_qa"
    frames = qa_dir / "frames"
    adapt_frames(flat, frames)
    py = sys.executable
    tools = PIPE / "tools"

    a_json = qa_dir / "alpha_audit.json"
    run([py, str(tools / "audit_render_alpha.py"), "--render-dir", str(frames), "--output", str(a_json),
         "--directions", DIRS8], log)
    al = jload(a_json)
    g = gates["alpha"]
    if al is None:
        C.append(check("Alfa (agujeros / parcial)", False, "no se generó el informe"))
    else:
        bad = []
        for d, v in al["directions"].items():
            if v["partial_alpha_ratio"] > g["max_partial_alpha_ratio"]:
                bad.append(f"{d}: alfa parcial {v['partial_alpha_ratio']:.2%}")
            if v["holes"]["count"] > g["max_holes_per_direction"]:
                bad.append(f"{d}: {v['holes']['count']} huecos")
            if v["holes"]["largest_area_px"] > g["max_largest_hole_px"]:
                bad.append(f"{d}: hueco de {v['holes']['largest_area_px']} px")
        C.append(check("Alfa (agujeros / parcial)", not bad, "; ".join(bad) or "dentro de umbrales"))

    c_dir = qa_dir / "cardinal"
    run([py, str(tools / "art_cardinal_check.py"), "--render-dir", str(frames), "--output", str(c_dir)], log)
    cm = jload(c_dir / "cardinal_direction_metrics.json")
    g = gates["cardinal"]
    if cm is None:
        C.append(check("Direcciones cardinales distintas", False, "no se generó el informe"))
    else:
        bad = [f"{k}: rgba {v['mean_abs_rgba']:.1f}, area {v['changed_bbox_area_ratio']:.2f}"
               for k, v in cm["differences"].items()
               if v["mean_abs_rgba"] < g["min_mean_abs_rgba"] or v["changed_bbox_area_ratio"] < g["min_changed_bbox_area_ratio"]]
        C.append(check("Direcciones cardinales distintas", not bad, "; ".join(bad) or "S/E/N/W se diferencian"))
        if (c_dir / "cardinal_SENW.png").exists():
            res["sheets"].append(str(c_dir / "cardinal_SENW.png"))

    # 4) Hojas de revision (a ojo; no bloquean)
    r_dir = qa_dir / "review"
    code = run([py, str(tools / "art_review_sheet.py"), "--character-json",
                str(PIPE / "characters" / cid / "character.json"), "--render-dir", str(frames),
                "--output", str(r_dir)], log)
    if code == 0 and r_dir.is_dir():
        res["sheets"] += [str(p) for p in sorted(r_dir.glob("*.png"))]
    else:
        res["notes"].append("art_review_sheet no generó hojas (no bloquea).")

    # 5) Entregables: todo bajo pipeline_output/<id>/art/
    #    model/    GLB procesado + character_art.json + texturas
    #    renders/  <accion>/<DIR>.png  (8 direcciones)
    #    review/   hojas para mirar a ojo (sprite_8dir, siluetas, ...)
    #    reports/  informes JSON de QA y metricas
    dest = OUT / cid / "art"
    if dest.exists():
        shutil.rmtree(dest, ignore_errors=True)
    (dest / "model").mkdir(parents=True, exist_ok=True)
    for src in (work / "export" / "npc_processed.glb", work / "character_art.json"):
        if src.exists():
            shutil.copy2(src, dest / "model" / src.name)
            res["artifacts"].append(str(dest / "model" / src.name))
    if (work / "textures").is_dir():
        shutil.copytree(work / "textures", dest / "model" / "textures", dirs_exist_ok=True)
        res["artifacts"].append(str(dest / "model" / "textures"))
    if (work / "renders").is_dir():
        shutil.copytree(work / "renders", dest / "renders", dirs_exist_ok=True)
        res["artifacts"].append(str(dest / "renders"))
    if r_dir.is_dir():
        shutil.copytree(r_dir, dest / "review", dirs_exist_ok=True)
        res["sheets"] = [str(dest / "review" / Path(x).name) if Path(x).parent == r_dir else x
                         for x in res["sheets"]]
    (dest / "reports").mkdir(exist_ok=True)
    if (work / "reports").is_dir():
        for j in (work / "reports").glob("*.json"):
            shutil.copy2(j, dest / "reports" / j.name)
    if qa_dir.is_dir():
        shutil.copytree(qa_dir, dest / "reports" / "art_qa", dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns("frames", "review"))
    card = qa_dir / "cardinal" / "cardinal_SENW.png"
    if card.exists():
        (dest / "review").mkdir(exist_ok=True)
        shutil.copy2(card, dest / "review" / card.name)
        res["sheets"] = [str(dest / "review" / card.name) if x == str(card) else x for x in res["sheets"]]
    res["artifacts"].append(str(dest / "review"))
    try:
        import atlas_origen
        cfg = json.loads((PIPE / "characters" / cid / "character.json").read_text(encoding="utf-8-sig"))
        res["notes"].append("Los atlas salen del " + ("GLB de esta fase de arte." if atlas_origen.eleccion(cfg) == "arte"
                            else "master, no de este GLB (para cambiarlo: \"atlas_desde\": \"arte\" en config/ms.json)."))
    except Exception:  # noqa: BLE001
        pass
    res["notes"].append("Mira las hojas de revision: las puertas detectan fallos tecnicos, no el gusto.")
    res["verdict"] = "APROBADO" if all(c["ok"] for c in C) else "RECHAZADO"
    try:
        (dest / "art_result.json").write_text(json.dumps(res, indent=2, ensure_ascii=False), encoding="utf-8")
    except OSError:
        pass
    return res


def art_section_lines(art: dict) -> list[str]:
    L = [f"## Arte: {art['verdict']}", ""]
    L += [f"- {'OK   ' if c['ok'] else 'FALLO'} {c['name']}: {c['detail']}" for c in art["checks"]]
    if art["sheets"]:
        L += ["", "Hojas para revisar a ojo:"] + [f"- `{x}`" for x in art["sheets"]]
    if art["artifacts"]:
        L += ["", "Entregables de arte:"] + [f"- `{x}`" for x in art["artifacts"]]
    L += [""] + [f"- {n}" for n in art["notes"]] + [""]
    return L


POR_QUE_ARTE = "- La parte técnica pasó, pero el ARTE no (ver sección Arte)."


def patch_report(cid: str, art: dict) -> None:
    """Tras repetir solo el arte, deja REPORTE.md al dia (seccion Arte + veredicto)."""
    p = OUT / cid / "REPORTE.md"
    if not p.exists():
        return
    t = p.read_text(encoding="utf-8")
    sec = "\n".join(art_section_lines(art)) + "\n"
    if re.search(r"## Arte.*?(?=\nSalida:)", t, re.S):
        t = re.sub(r"## Arte.*?(?=\nSalida:)", lambda m: sec, t, count=1, flags=re.S)
    # bloque "Por que"
    m = re.search(r"## Por que\n\n(.*?)\n\n(?=## )", t, re.S)
    otros = []
    if m:
        otros = [x for x in m.group(1).splitlines() if x.strip() and x.strip() != POR_QUE_ARTE]
        t = t.replace(m.group(0), "")
    if otros or art["verdict"] != "APROBADO":
        lineas = otros + ([POR_QUE_ARTE] if art["verdict"] != "APROBADO" and not any("técnica" in o for o in otros) and not otros else [])
        t = t.replace("\n\n## Archivos de entrada", "\n\n## Por que\n\n" + "\n".join(lineas) + "\n\n## Archivos de entrada", 1)
    final = "APROBADO" if (not otros and art["verdict"] == "APROBADO") else "RECHAZADO"
    t = re.sub(r"^# (APROBADO|RECHAZADO):", f"# {final}:", t, count=1)
    p.write_text(t, encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Uso: art_stage.py <id_personaje>   (solo la fase de arte, sobre un personaje ya procesado)")
        sys.exit(2)
    cid = sys.argv[1]
    r = run_art_stage(cid, OUT / cid / "art_stage.log")
    for c in r["checks"]:
        print(("OK   " if c["ok"] else "FALLO"), c["name"], "-", c["detail"])
    patch_report(cid, r)
    print("ARTE:", r["verdict"], f"(REPORTE.md actualizado: pipeline_output/{cid}/REPORTE.md)")
    for n in r["notes"]:
        print(" ", n)
    sys.exit(0 if r["verdict"] == "APROBADO" else 1)
