"""PROCESAR.cmd cola  -  servidor de pruebas: ejecuta en TU PC los trabajos que se dejan en una carpeta.

Dejalo abierto en una ventana. Vigila pipeline_output/arte_QA/_cola/ y, por cada  <nombre>.job.json,
ejecuta una accion PERMITIDA y escribe <nombre>.resultado.json (+ <nombre>.log.txt) en la misma carpeta.
Se detiene con Ctrl+C o creando el archivo _cola/STOP.

Acciones permitidas (nada mas; no hay shell libre):
  {"accion": "ping"}
  {"accion": "arte",    "args": ["hero", "--estilos", "m1_toon_solo,m2_linea_color"]}
  {"accion": "blender", "script": "pipeline/tools/pruebas/mi_script.py", "blend": "Render Studio/MS_CHARACTER_RENDER_STUDIO.blend",
                         "args": ["--cualquier", "arg"], "timeout": 900}
      -> el script DEBE estar dentro de pipeline/tools/ ; el .blend (opcional) dentro del proyecto.
"""
from __future__ import annotations

import contextlib
import io
import json
import os
import subprocess
import sys
import time
import traceback
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PIPE = ROOT / "pipeline"
QUEUE = ROOT / "pipeline_output" / "arte_QA" / "_cola"
TOOLS = HERE.resolve()


def _inside(p: Path, base: Path) -> bool:
    try:
        p.resolve().relative_to(base.resolve())
        return True
    except ValueError:
        return False


def _blender() -> str:
    try:
        ms = json.loads((PIPE / "config" / "ms.json").read_text(encoding="utf-8"))
    except Exception:  # noqa: BLE001
        ms = {}
    return os.environ.get("BLENDER_EXE") or ms.get(
        "blender", r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe")


def _do_arte(job: dict) -> tuple[str, str]:
    import importlib
    import ms_arte
    importlib.reload(ms_arte)  # recoge cambios del codigo sin reiniciar el servidor
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = ms_arte.run([str(a) for a in job.get("args", [])])
    return ("OK" if rc == 0 else f"ERROR({rc})"), buf.getvalue()


def _do_blender(job: dict) -> tuple[str, str]:
    script = ROOT / str(job.get("script", ""))
    if not script.is_file() or not _inside(script, TOOLS):
        return "RECHAZADO", f"El script debe existir dentro de pipeline/tools/: {script}"
    cmd = [_blender()]
    if job.get("blend"):
        blend = ROOT / str(job["blend"])
        if not blend.is_file() or not _inside(blend, ROOT):
            return "RECHAZADO", f".blend no valido o fuera del proyecto: {blend}"
        cmd.append(str(blend))
    cmd += ["--background", "--python", str(script), "--"] + [str(a) for a in job.get("args", [])]
    r = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True, encoding="utf-8", errors="replace",
                       timeout=int(job.get("timeout", 900)))
    return ("OK" if r.returncode == 0 else f"ERROR({r.returncode})"), (r.stdout or "") + "\n" + (r.stderr or "")


def _run_job(f: Path) -> None:
    name = f.name[: -len(".job.json")]
    t0 = datetime.now()
    res = {"job": name, "inicio": t0.isoformat(timespec="seconds")}
    log = ""
    try:
        job = json.loads(f.read_text(encoding="utf-8"))
        acc = job.get("accion")
        res["accion"] = acc
        if acc == "ping":
            estado, log = "OK", f"pong {t0.isoformat(timespec='seconds')}"
        elif acc == "arte":
            estado, log = _do_arte(job)
        elif acc == "blender":
            estado, log = _do_blender(job)
        else:
            estado, log = "RECHAZADO", f"Accion no permitida: {acc!r}"
    except subprocess.TimeoutExpired:
        estado, log = "TIMEOUT", "El trabajo supero el tiempo maximo."
    except Exception:  # noqa: BLE001
        estado, log = "EXCEPCION", traceback.format_exc()
    res["estado"] = estado
    res["fin"] = datetime.now().isoformat(timespec="seconds")
    (QUEUE / f"{name}.log.txt").write_text(log[-200000:], encoding="utf-8")
    (QUEUE / f"{name}.resultado.json").write_text(json.dumps(res, indent=2, ensure_ascii=False), encoding="utf-8")
    f.rename(QUEUE / f"{name}.hecho.json")
    print(f"[{res['fin']}] {name}: {estado}", flush=True)


def run() -> int:
    QUEUE.mkdir(parents=True, exist_ok=True)
    stop = QUEUE / "STOP"
    if stop.exists():
        stop.unlink()
    print(f"Servidor de pruebas activo. Vigilando: {QUEUE}")
    print("Detener: Ctrl+C o crear el archivo STOP en esa carpeta.\n", flush=True)
    try:
        while not stop.exists():
            (QUEUE / "latido.txt").write_text(datetime.now().isoformat(timespec="seconds"), encoding="utf-8")
            for f in sorted(QUEUE.glob("*.job.json")):
                time.sleep(1.0)  # por si el archivo aun se esta escribiendo
                _run_job(f)
            time.sleep(3)
    except KeyboardInterrupt:
        pass
    print("Servidor detenido.")
    return 0
