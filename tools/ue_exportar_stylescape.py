# UE_EXPORTAR_STYLESCAPE (25/11/2026, PRUEBA): se ejecuta DENTRO de Unreal 5.8, sin abrir el editor:
#   "E:\UE_5.8\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" "E:\ue_proyectos\StylescapeRuins\StylescapeRuins501.uproject" -run=pythonscript -script="E:\magic-symbols\tools\ue_exportar_stylescape.py" -unattended -nop4 -nosplash -NullRHI
# (el .uproject necesita los plugins PythonScriptPlugin y EditorScriptingUtilities activados).
# Exporta todas las mallas estáticas a FBX y las texturas a TGA (o PNG si el TGA falla, le pasa a la hiedra) en E:\ue_proyectos\StylescapeRuins_export,
# con informe.json (material de cada malla y texturas/números de cada material) e informe_padres.json (valores por defecto de los materiales padre).
# Después: python tools/preparar_stylescape.py "E:/ue_proyectos/StylescapeRuins_export"
import json, os
import unreal

SALIDA = r"E:\ue_proyectos\StylescapeRuins_export"
os.makedirs(os.path.join(SALIDA, "mallas"), exist_ok=True)
os.makedirs(os.path.join(SALIDA, "texturas"), exist_ok=True)

reg = unreal.AssetRegistryHelpers.get_asset_registry()
datos = reg.get_assets_by_path("/Game/Stylescape/Ruins", recursive=True)
informe = {"mallas": {}, "materiales": {}, "texturas": {}, "errores": []}


def exportar(obj, ruta):
    t = unreal.AssetExportTask()
    t.object = obj
    t.filename = ruta
    t.automated = True
    t.prompt = False
    t.replace_identical = True
    if isinstance(obj, unreal.StaticMesh):
        o = unreal.FbxExportOption()
        o.collision = False
        o.level_of_detail = False
        o.vertex_color = True
        t.options = o
    return unreal.Exporter.run_asset_export_task(t)


def info_material(mi):
    nombre = mi.get_name()
    if nombre in informe["materiales"]:
        return nombre
    d = {"padre": None, "texturas": {}, "escalares": {}, "vectores": {}}
    if isinstance(mi, unreal.MaterialInstance):
        p = mi.get_editor_property("parent")
        d["padre"] = p.get_name() if p else None
        for tp in mi.get_editor_property("texture_parameter_values") or []:
            v = tp.get_editor_property("parameter_value")
            d["texturas"][str(tp.get_editor_property("parameter_info").get_editor_property("name"))] = v.get_name() if v else None
        for sp in mi.get_editor_property("scalar_parameter_values") or []:
            d["escalares"][str(sp.get_editor_property("parameter_info").get_editor_property("name"))] = sp.get_editor_property("parameter_value")
        for vp in mi.get_editor_property("vector_parameter_values") or []:
            c = vp.get_editor_property("parameter_value")
            d["vectores"][str(vp.get_editor_property("parameter_info").get_editor_property("name"))] = [c.r, c.g, c.b, c.a]
    informe["materiales"][nombre] = d
    return nombre


for a in datos:
    clase = str(a.asset_class_path.asset_name)
    nombre = str(a.asset_name)
    if clase == "StaticMesh":
        m = unreal.EditorAssetLibrary.load_asset(str(a.package_name))
        if not exportar(m, os.path.join(SALIDA, "mallas", nombre + ".fbx")):
            informe["errores"].append(nombre)
        mats = []
        for sm in m.get_editor_property("static_materials"):
            mi = sm.get_editor_property("material_interface")
            mats.append(info_material(mi) if mi else None)
        b = m.get_bounding_box()
        informe["mallas"][nombre] = {"carpeta": str(a.package_path), "materiales": mats,
                                     "caja_cm": [b.min.x, b.min.y, b.min.z, b.max.x, b.max.y, b.max.z]}
    elif clase == "Texture2D":
        tx = unreal.EditorAssetLibrary.load_asset(str(a.package_name))
        if not any(exportar(tx, os.path.join(SALIDA, "texturas", nombre + ext)) for ext in (".tga", ".png")):
            informe["errores"].append(nombre)
        informe["texturas"][nombre] = [tx.blueprint_get_size_x(), tx.blueprint_get_size_y()]

with open(os.path.join(SALIDA, "informe.json"), "w", encoding="utf-8") as f:
    json.dump(informe, f, indent=1, ensure_ascii=False)

mel = unreal.MaterialEditingLibrary
padres = {"padres": {}}
for ruta in ["/Game/Stylescape/Ruins/Materials/Masters/M_RuinsMaster", "/Game/Stylescape/Ruins/Materials/Masters/M_Ivy"]:
    m = unreal.EditorAssetLibrary.load_asset(ruta)
    d = {"texturas": {}, "escalares": {}, "vectores": {}}
    for p in mel.get_texture_parameter_names(m):
        v = mel.get_material_default_texture_parameter_value(m, p)
        d["texturas"][str(p)] = v.get_name() if v else None
    for p in mel.get_scalar_parameter_names(m):
        d["escalares"][str(p)] = mel.get_material_default_scalar_parameter_value(m, p)
    for p in mel.get_vector_parameter_names(m):
        c = mel.get_material_default_vector_parameter_value(m, p)
        d["vectores"][str(p)] = [c.r, c.g, c.b, c.a]
    padres["padres"][m.get_name()] = d
with open(os.path.join(SALIDA, "informe_padres.json"), "w", encoding="utf-8") as f:
    json.dump(padres, f, indent=1, ensure_ascii=False)
unreal.log("EXPORT_STYLESCAPE_FIN mallas=%d errores=%d" % (len(informe["mallas"]), len(informe["errores"])))
