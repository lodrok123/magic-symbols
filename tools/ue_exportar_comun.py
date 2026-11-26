# Funciones comunes para exportar de Unreal (sin abrir el editor) mallas, texturas y RECETAS de material, y llevarlas a Godot (26/11/2026).
# Las usan tools/ue_exportar_prueba_bosque.py y tools/ue_exportar_pure_nature.py. Se ejecutan DENTRO de Unreal (módulo `unreal`).
#
# Exportador(salida).malla(static_mesh) deja salida/mallas/<pack>__<malla>.fbx y anota en `informe`:
#   mallas[ruta]      = {fbx, materiales (por ranura), caja_cm}
#   materiales[clave] = {padre (material raíz), modo_mezcla, dos_caras, modelo, texturas{param: textura}, escalares, vectores, interruptores}
#   texturas[clave]   = [ancho, alto, compresión, srgb]   (y el archivo salida/texturas/<clave>.tga|png)
# Las claves llevan delante el pack (`PureNature_Meadows__MI_Stones`), porque los packs de BK repiten nombres.
import json, os
import unreal

mel = unreal.MaterialEditingLibrary


def clave(obj):
    partes = obj.get_path_name().split("/")
    return (partes[2] if partes[1] == "Game" else "Engine") + "__" + obj.get_name()


class Exportador:
    def __init__(self, salida):
        self.salida = salida
        os.makedirs(os.path.join(salida, "mallas"), exist_ok=True)
        os.makedirs(os.path.join(salida, "texturas"), exist_ok=True)
        self.informe = {"mallas": {}, "materiales": {}, "texturas": {}, "errores": []}

    def _exportar(self, obj, ruta):
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

    def textura(self, tx):
        if tx is None:
            return None
        n = clave(tx)
        if n not in self.informe["texturas"]:
            if not any(os.path.exists(os.path.join(self.salida, "texturas", n + e)) for e in (".tga", ".png")):
                if not any(self._exportar(tx, os.path.join(self.salida, "texturas", n + e)) for e in (".tga", ".png")):
                    self.informe["errores"].append(n)
            self.informe["texturas"][n] = [tx.blueprint_get_size_x(), tx.blueprint_get_size_y(), str(tx.get_editor_property("compression_settings")), bool(tx.get_editor_property("srgb"))]
        return n

    def material(self, mi):
        n = clave(mi)
        if n in self.informe["materiales"]:
            return n
        raiz = mi
        while isinstance(raiz, unreal.MaterialInstance):
            raiz = raiz.get_editor_property("parent")
        d = {"padre": raiz.get_name() if raiz else None, "texturas": {}, "escalares": {}, "vectores": {}, "interruptores": {}}
        if raiz:
            d["modo_mezcla"] = str(raiz.get_editor_property("blend_mode"))
            d["dos_caras"] = bool(raiz.get_editor_property("two_sided"))
            d["modelo"] = str(raiz.get_editor_property("shading_model"))
        inst = isinstance(mi, unreal.MaterialInstance)
        for p in mel.get_texture_parameter_names(mi):
            d["texturas"][str(p)] = self.textura(mel.get_material_instance_texture_parameter_value(mi, p) if inst else mel.get_material_default_texture_parameter_value(mi, p))
        for p in mel.get_scalar_parameter_names(mi):
            d["escalares"][str(p)] = mel.get_material_instance_scalar_parameter_value(mi, p) if inst else mel.get_material_default_scalar_parameter_value(mi, p)
        for p in mel.get_vector_parameter_names(mi):
            c = mel.get_material_instance_vector_parameter_value(mi, p) if inst else mel.get_material_default_vector_parameter_value(mi, p)
            d["vectores"][str(p)] = [c.r, c.g, c.b, c.a]
        if inst:
            for p in mel.get_static_switch_parameter_names(mi):
                d["interruptores"][str(p)] = mel.get_material_instance_static_switch_parameter_value(mi, p)
        # texturas que un material (no instancia) usa sin parámetro, p. ej. el suelo de la prueba
        if isinstance(mi, unreal.Material):
            try:
                for tx in mel.get_used_textures(mi):
                    nombre = self.textura(tx)
                    if nombre not in d["texturas"].values():
                        d["texturas"]["_usada_" + nombre] = nombre
            except Exception as e:
                self.informe["errores"].append("usadas " + n + ": " + str(e))
        self.informe["materiales"][n] = d
        return n

    def malla(self, obj, ruta=None):
        ruta = ruta or obj.get_path_name().split(".")[0]
        k = clave(obj)
        fbx = os.path.join(self.salida, "mallas", k + ".fbx")
        if not os.path.exists(fbx) and not self._exportar(obj, fbx):
            self.informe["errores"].append(k)
        mats = []
        for sm in obj.get_editor_property("static_materials"):
            mi = sm.get_editor_property("material_interface")
            mats.append(self.material(mi) if mi else None)
        b = obj.get_bounding_box()
        self.informe["mallas"][ruta] = {"fbx": k + ".fbx", "materiales": mats, "caja_cm": [b.min.x, b.min.y, b.min.z, b.max.x, b.max.y, b.max.z]}
        return k

    def guardar(self):
        with open(os.path.join(self.salida, "informe.json"), "w", encoding="utf-8") as f:
            json.dump(self.informe, f, indent=1, ensure_ascii=False)
