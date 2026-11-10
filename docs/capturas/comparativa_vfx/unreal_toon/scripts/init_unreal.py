# Canal local de scripts: vigila Saved/cola_py y ejecuta cada .py que aparezca, dejando su salida en .out
import unreal, os, glob, traceback, io, contextlib
COLA = unreal.Paths.project_dir() + "Saved/cola_py/"
os.makedirs(COLA, exist_ok=True)
_estado = {"ocupado": False}
def _tick(dt):
    if _estado["ocupado"]:
        return  # el tick de Slate se reentra desde dentro del script; no ejecutar dos veces
    pend = sorted(glob.glob(COLA + "*.py"))
    if not pend:
        return
    f = pend[0]
    hecho = f[:-3] + ".hecho"
    if os.path.exists(hecho): os.remove(hecho)
    os.replace(f, hecho)  # se retira de la cola ANTES de ejecutar
    _estado["ocupado"] = True
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            with open(hecho, encoding="utf-8-sig") as fh:
                code = fh.read()
            exec(compile(code, f, "exec"), {"__name__": "__cola__", "__file__": f})
        buf.write("\n[OK]\n")
    except Exception:
        buf.write(traceback.format_exc() + "\n[FALLO]\n")
    finally:
        _estado["ocupado"] = False
        with open(f[:-3] + ".out", "w", encoding="utf-8") as fo:
            fo.write(buf.getvalue())
_h = unreal.register_slate_post_tick_callback(_tick)
unreal.log("cola_py vigilando " + COLA)