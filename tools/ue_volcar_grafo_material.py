# Vuelca a texto el GRAFO de nodos de materiales maestros de Unreal (26/11/2026): de qué nodos sale el color base, la opacidad, etc.
# Sirve para traducir un material a Godot sin adivinar (ver presentacion/fab_ue/materiales_ue.gd).
#   "E:\UE_5.8\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" "E:\ue_proyectos\StylescapeRuins\StylescapeRuins501.uproject" -run=pythonscript -script="E:\magic-symbols\tools\ue_volcar_grafo_material.py" -unattended -nop4 -nosplash -NullRHI
# Deja docs/fab_ue/grafos/<material>.txt: por cada salida del material, el árbol de nodos que la alimenta (con sus parámetros y constantes).
import os
import unreal

MATERIALES = [
    "/Game/PureNature_Meadows/MasterMaterials/MM_BK_VegetationLeaves",
    "/Game/PureNature_Meadows/MasterMaterials/MM_BK_Grass",
    "/Game/PureNature_Meadows/MasterMaterials/MM_BK_StandardLayered",
    "/Game/PureNature_Meadows/MasterMaterials/MM_BK_VegetationTrunk",
    "/Game/PureNature_Savanna/MasterMaterials/MM_BK_Banks",
]
SALIDA = r"E:\magic-symbols\docs\fab_ue\grafos"
PROPIEDADES = ["MP_MATERIAL_ATTRIBUTES", "MP_BASE_COLOR", "MP_OPACITY_MASK", "MP_ROUGHNESS", "MP_NORMAL", "MP_AMBIENT_OCCLUSION", "MP_SUBSURFACE_COLOR", "MP_EMISSIVE_COLOR"]
mel = unreal.MaterialEditingLibrary
CAMPOS = ["parameter_name", "r", "g", "b", "a", "constant", "default_value", "const_a", "const_b", "const_alpha", "texture", "coordinate_index",
          "u_tiling", "v_tiling", "input_name", "function", "material_function", "exponent", "r_mask", "g_mask", "b_mask", "a_mask", "blend_mode"]


def describir(e):
    partes = [e.get_class().get_name().replace("MaterialExpression", "")]
    for c in CAMPOS:
        try:
            v = e.get_editor_property(c)
        except Exception:
            continue
        if v is None or v == "" or (isinstance(v, bool) and not v and c.endswith("_mask")):
            continue
        if hasattr(v, "get_name"):
            v = v.get_name()
        elif hasattr(v, "r") and hasattr(v, "a"):
            v = "(%.3f, %.3f, %.3f, %.3f)" % (v.r, v.g, v.b, v.a)
        partes.append("%s=%s" % (c, v))
    return " ".join(str(p) for p in partes)


def arbol(mat, e, prof, vistos, lineas):
    if prof > 40:
        lineas.append("  " * prof + "…")
        return
    marca = "" if e not in vistos else "  (repetido)"
    lineas.append("  " * prof + describir(e) + marca)
    if e in vistos:
        return
    vistos.add(e)
    try:
        entradas = mel.get_inputs_for_material_expression(mat, e)
    except Exception as ex:
        lineas.append("  " * (prof + 1) + "?? " + str(ex))
        return
    try:
        nombres = mel.get_input_names_for_material_expression(mat, e) if hasattr(mel, "get_input_names_for_material_expression") else []
    except Exception:
        nombres = []
    for i, h in enumerate(entradas):
        if h is None:
            continue
        nombre = nombres[i] if i < len(nombres) else str(i)
        # de qué SALIDA del nodo de entrada viene (RGB, R, G, B, A…): importa en las texturas de máscara
        salida = ""
        try:
            salida = mel.get_input_node_output_name_for_material_expression(mat, e, str(nombre)) if nombres else ""
        except Exception:
            salida = ""
        lineas.append("  " * (prof + 1) + "<" + str(nombre) + ">" + ((" ← salida " + str(salida)) if salida else ""))
        arbol(mat, h, prof + 2, vistos, lineas)


os.makedirs(SALIDA, exist_ok=True)
for ruta in MATERIALES:
    mat = unreal.load_asset(ruta)
    if mat is None:
        unreal.log_warning("no existe " + ruta)
        continue
    lineas = ["# " + ruta, "two_sided=%s blend=%s shading=%s" % (mat.get_editor_property("two_sided"), mat.get_editor_property("blend_mode"), mat.get_editor_property("shading_model"))]
    for p in PROPIEDADES:
        try:
            nodo = mel.get_material_property_input_node(mat, getattr(unreal.MaterialProperty, p))
        except Exception as ex:
            lineas.append("== %s: ?? %s" % (p, ex))
            continue
        if nodo is None:
            continue
        lineas.append("== " + p)
        arbol(mat, nodo, 1, set(), lineas)
    with open(os.path.join(SALIDA, mat.get_name() + ".txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lineas))
    unreal.log("GRAFO %s: %d líneas" % (mat.get_name(), len(lineas)))
