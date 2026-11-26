# Exporta de Unreal TODAS las mallas de los packs «Pure Nature» de BK (Fab) que haya en el proyecto, con sus recetas de material (26/11/2026).
#   "E:\UE_5.8\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" "E:\ue_proyectos\StylescapeRuins\StylescapeRuins501.uproject" -run=pythonscript -script="E:\magic-symbols\tools\ue_exportar_pure_nature.py" -unattended -nop4 -nosplash -NullRHI
# Busca las carpetas /Game/PureNature_* (las que se añaden desde Fab con «Añadir al proyecto»), así que un pack nuevo entra solo.
# Deja en E:\ue_proyectos\PureNature_export: mallas/*.fbx, texturas/*.tga|png e informe.json (ver tools/ue_exportar_comun.py).
# Lo ya exportado no se repite (para que añadir un pack no vuelva a exportar los demás).
# Después: python tools/preparar_pure_nature.py "E:/ue_proyectos/PureNature_export"
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import unreal
from ue_exportar_comun import Exportador

SALIDA = r"E:\ue_proyectos\PureNature_export"
## Lo que no es pieza de escenario: montañas de fondo (50 m), el cielo, la niebla, mariposas y partículas.
FUERA = ("/Mountains/", "/Clouds/", "/Fx/", "/Fog/")

reg = unreal.AssetRegistryHelpers.get_asset_registry()
packs = sorted(p for p in reg.get_sub_paths("/Game", False) if p.startswith("/Game/PureNature_"))
ex = Exportador(SALIDA)
por_pack = {}
for pack in packs:
    n = 0
    for d in reg.get_assets_by_path(pack, recursive=True):
        if str(d.asset_class_path.asset_name) != "StaticMesh":
            continue
        ruta = str(d.package_name)
        if any(f in ruta for f in FUERA):
            continue
        ex.malla(unreal.load_asset(ruta), ruta)
        n += 1
    por_pack[pack] = n
ex.informe["packs"] = por_pack
ex.guardar()
i = ex.informe
unreal.log("EXPORT_PURE_NATURE_FIN packs=%s mallas=%d materiales=%d texturas=%d errores=%d" % (por_pack, len(i["mallas"]), len(i["materiales"]), len(i["texturas"]), len(i["errores"])))
