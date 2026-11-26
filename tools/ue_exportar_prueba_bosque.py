# Exporta de Unreal SOLO lo que usa la escena de prueba «bosque con ruinas» (26/11/2026), para montarla igual en Godot.
# Requiere haber ejecutado antes tools/ue_montar_prueba_bosque.py (que deja docs/capturas/comparativa_ue_godot/escena.json).
#   "E:\UE_5.8\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" "E:\ue_proyectos\StylescapeRuins\StylescapeRuins501.uproject" -run=pythonscript -script="E:\magic-symbols\tools\ue_exportar_prueba_bosque.py" -unattended -nop4 -nosplash -NullRHI
# Deja en E:\ue_proyectos\PruebaBosque_export: mallas/*.fbx, texturas/*.tga|png e informe.json (ver tools/ue_exportar_comun.py).
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import unreal
from ue_exportar_comun import Exportador

ESCENA = r"E:\magic-symbols\docs\capturas\comparativa_ue_godot\escena.json"
SALIDA = r"E:\ue_proyectos\PruebaBosque_export"

with open(ESCENA, encoding="utf-8") as f:
    escena = json.load(f)
rutas = sorted(set(p["malla"] for p in escena["piezas"]) | set(p["material"] for p in escena["piezas"] if p.get("material")))
ex = Exportador(SALIDA)
for ruta in rutas:
    obj = unreal.load_asset(ruta)
    if obj is None:
        ex.informe["errores"].append("no existe " + ruta)
    elif isinstance(obj, unreal.StaticMesh):
        ex.malla(obj, ruta)
    else:
        ex.material(obj)
ex.guardar()
i = ex.informe
unreal.log("EXPORT_PRUEBA_BOSQUE_FIN mallas=%d materiales=%d texturas=%d errores=%d" % (len(i["mallas"]), len(i["materiales"]), len(i["texturas"]), len(i["errores"])))
