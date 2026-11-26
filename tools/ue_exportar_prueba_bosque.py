# Exporta de Unreal SOLO lo que usa la escena de prueba «bosque con ruinas» (26/11/2026), para montarla igual en Godot.
# Requiere haber ejecutado antes tools/ue_montar_prueba_bosque.py (que deja docs/capturas/comparativa_ue_godot/escena.json).
#   "E:\UE_5.8\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" "E:\ue_proyectos\StylescapeRuins\StylescapeRuins501.uproject" -run=pythonscript -script="E:\magic-symbols\tools\ue_exportar_prueba_bosque.py" -unattended -nop4 -nosplash -NullRHI
# Deja en E:\ue_proyectos\PruebaBosque_export: mallas/*.fbx, texturas/*.tga|png e informe.json con, por malla, sus materiales
# y, por material, su padre y todos sus parámetros (los del padre por defecto + los que cambia la instancia).
import json, os
import unreal

ESCENA = r"E:\magic-symbols\docs\capturas\comparativa_ue_godot\escena.json"
SALIDA = r"E:\ue_proyectos\PruebaBosque_export"
os.makedirs(os.path.join(SALIDA, "mallas"), exist_ok=True)
os.makedirs(os.path.join(SALIDA, "texturas"), exist_ok=True)
mel = unreal.MaterialEditingLibrary

with open(ESCENA, encoding="utf-8") as f:
    escena = json.load(f)
rutas = sorted(set(p["malla"] for p in escena["piezas"]) | set(p["material"] for p in escena["piezas"] if p.get("material")))
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


def clave(obj):
    # Meadows y Mountains repiten nombres (MI_BK_Grass, MI_Stones, T_...): se antepone el pack. Lo del motor va con «Engine».
    partes = obj.get_path_name().split("/")
    return (partes[2] if partes[1] == "Game" else "Engine") + "__" + obj.get_name()


def textura(tx):
    if tx is None:
        return None
    n = clave(tx)
    if n not in informe["texturas"]:
        ok = any(exportar(tx, os.path.join(SALIDA, "texturas", n + ext)) for ext in (".tga", ".png"))
        if not ok:
            informe["errores"].append(n)
        informe["texturas"][n] = [tx.blueprint_get_size_x(), tx.blueprint_get_size_y(), str(tx.get_editor_property("compression_settings")), bool(tx.get_editor_property("srgb"))]
    return n


def material(mi):
    n = clave(mi)
    if n in informe["materiales"]:
        return n
    raiz = mi
    while isinstance(raiz, unreal.MaterialInstance):
        raiz = raiz.get_editor_property("parent")
    d = {"padre": raiz.get_name() if raiz else None, "texturas": {}, "escalares": {}, "vectores": {}, "interruptores": {}}
    if raiz:
        d["modo_mezcla"] = str(raiz.get_editor_property("blend_mode"))
        d["dos_caras"] = bool(raiz.get_editor_property("two_sided"))
        d["modelo"] = str(raiz.get_editor_property("shading_model"))
    for p in mel.get_texture_parameter_names(mi):
        d["texturas"][str(p)] = textura(mel.get_material_instance_texture_parameter_value(mi, p) if isinstance(mi, unreal.MaterialInstance) else mel.get_material_default_texture_parameter_value(mi, p))
    for p in mel.get_scalar_parameter_names(mi):
        d["escalares"][str(p)] = mel.get_material_instance_scalar_parameter_value(mi, p) if isinstance(mi, unreal.MaterialInstance) else mel.get_material_default_scalar_parameter_value(mi, p)
    for p in mel.get_vector_parameter_names(mi):
        c = mel.get_material_instance_vector_parameter_value(mi, p) if isinstance(mi, unreal.MaterialInstance) else mel.get_material_default_vector_parameter_value(mi, p)
        d["vectores"][str(p)] = [c.r, c.g, c.b, c.a]
    if isinstance(mi, unreal.MaterialInstance):
        for p in mel.get_static_switch_parameter_names(mi):
            d["interruptores"][str(p)] = mel.get_material_instance_static_switch_parameter_value(mi, p)
    # texturas que el material usa sin parámetro (p. ej. el suelo Grass01)
    try:
        for tx in (mel.get_used_textures(mi) if isinstance(mi, unreal.Material) else []):
            nombre = textura(tx)
            if nombre not in d["texturas"].values():
                d["texturas"]["_usada_" + nombre] = nombre
    except Exception as e:
        informe["errores"].append("usadas " + n + ": " + str(e))
    informe["materiales"][n] = d
    return n


for ruta in rutas:
    obj = unreal.load_asset(ruta)
    if obj is None:
        informe["errores"].append("no existe " + ruta)
        continue
    if isinstance(obj, unreal.StaticMesh):
        k = clave(obj)      # p. ej. PureNature_Meadows__SM_Oak2
        if not exportar(obj, os.path.join(SALIDA, "mallas", k + ".fbx")):
            informe["errores"].append(k)
        mats = []
        for sm in obj.get_editor_property("static_materials"):
            mi = sm.get_editor_property("material_interface")
            mats.append(material(mi) if mi else None)
        b = obj.get_bounding_box()
        informe["mallas"][ruta] = {"fbx": k + ".fbx", "materiales": mats, "caja_cm": [b.min.x, b.min.y, b.min.z, b.max.x, b.max.y, b.max.z]}
    else:
        material(obj)

with open(os.path.join(SALIDA, "informe.json"), "w", encoding="utf-8") as f:
    json.dump(informe, f, indent=1, ensure_ascii=False)
unreal.log("EXPORT_PRUEBA_BOSQUE_FIN mallas=%d materiales=%d texturas=%d errores=%d" % (len(informe["mallas"]), len(informe["materiales"]), len(informe["texturas"]), len(informe["errores"])))
