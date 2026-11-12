"""
Saca de un .blend de Pablo una PRENDA ya pesada a mano y la exporta como .glb de ropa del juego. NO guarda el .blend.

    blender.exe -b <archivo.blend> --python tools/exportar_prenda_blend.py -- <objeto de la prenda> <salida.glb> [textura=1024]

Para qué (Pablo, 12/11: «¿puedes hacer la prueba con este modelo? ya tiene integrado la ropa y el personaje»): probar en el juego una prenda
que él ha encajado y pesado en Blender sobre el esqueleto de la jugadora, sin pasar por herramientas/rig/encajar_ropa.py.

Qué hace con lo que el formato del juego (glTF, piel por huesos) no puede llevar tal cual, y lo dice por pantalla:
  - SHAPE KEYS: se funden en la malla con sus valores actuales (el exportador no aplica modificadores a una malla con shape keys).
  - Modificadores de ANTES de la armadura (Decimate…): se aplican.
  - Modificadores de DESPUES de la armadura (Corrective Smooth…): se PIERDEN. Corrigen la malla ya deformada, en cada fotograma, y eso en
    el juego no existe: lo que se vea en Blender gracias a ellos no se vera en Godot. Se avisa de cuales son.
  - Mas de 4 huesos por vertice: glTF se queda con los 4 de mas peso (se cuenta cuantos vertices lo sufren).
Solo se exportan la prenda y su armadura; el cuerpo y lo demas se quedan fuera.
"""
import sys

import bpy


def argumentos():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


def main():
    a = argumentos()
    nombre, salida = a[0], a[1]
    textura = 1024
    for x in a[2:]:
        if x.startswith("textura="):
            textura = int(x.split("=")[1])
    obj = bpy.data.objects.get(nombre)
    if obj is None or obj.type != "MESH":
        print("EXP *** no hay una malla llamada «%s». Mallas: %s" % (nombre, [o.name for o in bpy.data.objects if o.type == "MESH"]))
        return
    arm = None
    for m in obj.modifiers:
        if m.type == "ARMATURE" and m.object is not None:
            arm = m.object
    if arm is None:
        print("EXP *** la prenda no tiene modificador Armature")
        return
    me = obj.data
    print("EXP prenda «%s»: %d vertices, %d caras; armadura «%s» (%d huesos, escala %.1f)" % (
        obj.name, len(me.vertices), len(me.polygons), arm.name, len(arm.data.bones), arm.scale.x))

    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    # la armadura, en reposo: la prenda se exporta en la pose de reposo, no en la del fotograma de la accion que haya puesta
    if arm.animation_data is not None:
        print("EXP la armadura tenia puesta la accion «%s»: se quita para exportar en reposo" % (
            arm.animation_data.action.name if arm.animation_data.action else None))
        arm.animation_data.action = None
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()

    # shape keys
    if me.shape_keys is not None:
        ks = me.shape_keys.key_blocks
        print("EXP shape keys en el archivo: %s" % [(k.name, round(k.value, 3)) for k in ks])
        # Los valores del archivo son los del FOTOGRAMA que estuviera puesto: una shape key animada por una accion (p. ej. una
        # correctora solo para el lanzamiento) trae ahi un valor a medias que no es el del reposo. Se quita la animacion de las
        # shape keys y se ponen los valores pedidos con `clave:<nombre>=<valor>`; las no pedidas se quedan como estan.
        if me.shape_keys.animation_data is not None:
            me.shape_keys.animation_data_clear()
        for x in a[2:]:
            if x.startswith("clave:") and "=" in x:
                n, val = x[len("clave:"):].rsplit("=", 1)
                if n in ks:
                    ks[n].value = float(val)
        print("EXP shape keys que se funden:  %s" % [(k.name, round(k.value, 3)) for k in ks])
        obj.shape_key_add(name="__mezcla", from_mix=True)
        for k in list(ks):
            if k.name != "__mezcla":
                obj.shape_key_remove(k)
        obj.shape_key_remove(obj.data.shape_keys.key_blocks[0])
        print("EXP   -> fundidas en la malla con esos valores")

    # modificadores
    antes = True
    for m in list(obj.modifiers):
        if m.type == "ARMATURE":
            antes = False
            continue
        if antes:
            detalle = ""
            if m.type == "DECIMATE":
                detalle = " (%s, ratio %.3f)" % (m.decimate_type, m.ratio)
            tipo, nom = m.type, m.name          # antes de aplicarlo: despues el modificador ya no existe y leerlo da basura
            try:
                bpy.ops.object.modifier_apply(modifier=nom)
                print("EXP modificador %s «%s»%s: aplicado -> %d caras" % (tipo, nom, detalle, len(obj.data.polygons)))
            except RuntimeError as e:
                print("EXP *** no se pudo aplicar %s «%s»: %s" % (tipo, nom, e))
        else:
            detalle = ""
            if m.type == "CORRECTIVE_SMOOTH":
                detalle = " (factor %.2f, %d repeticiones, %s)" % (m.factor, m.iterations, m.smooth_type)
            print("EXP *** modificador %s «%s»%s va DESPUES de la armadura: en el juego NO existe, se pierde" % (m.type, m.name, detalle))
            obj.modifiers.remove(m)

    # pesos
    me = obj.data
    nombres = [g.name for g in obj.vertex_groups]
    huesos = set(b.name for b in arm.data.bones)
    mas_de_4 = sin_peso = 0
    suma = {}
    for v in me.vertices:
        gs = [(g.weight, nombres[g.group]) for g in v.groups if g.weight > 0.001 and nombres[g.group] in huesos]
        if not gs:
            sin_peso += 1
        if len(gs) > 4:
            mas_de_4 += 1
        for w, n in gs:
            suma[n] = suma.get(n, 0.0) + w
    tot = sum(suma.values()) or 1.0
    top = sorted(suma.items(), key=lambda x: -x[1])[:10]
    print("EXP pesos: %d vertices sin peso de ningun hueso, %d con mas de 4 huesos (glTF se queda con 4)" % (sin_peso, mas_de_4))
    print("EXP reparto: " + "  ".join("%s %.0f %%" % (n.replace("mixamorig_", ""), 100.0 * w / tot) for n, w in top))
    zs = [(obj.matrix_world @ v.co).z for v in me.vertices]
    print("EXP la prenda va de z %.3f a %.3f (la jugadora mide 1,70)" % (min(zs), max(zs)))

    for img in bpy.data.images:
        if img.size[0] > textura:
            img.scale(textura, textura)
    # A DOBLE CARA: una prenda de una sola pared (sin forro) se ve por dentro en la sisa, el cuello y el bajo; con las caras de
    # atras ocultas ahi se veria un hueco. El juego respeta lo que diga el material del .glb (Pj3D mira su cull_mode).
    for ranura in obj.material_slots:
        if ranura.material is not None:
            ranura.material.use_backface_culling = False

    arm.data.pose_position = "POSE"
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=salida, export_format="GLB", use_selection=True, export_animations=False, export_skins=True,
                              export_image_format="JPEG", export_yup=True, export_apply=False)
    print("EXP ESCRITO: %s" % salida)


main()
