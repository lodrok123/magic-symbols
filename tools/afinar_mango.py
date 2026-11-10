"""
Afina el MANGO de una pieza larga (la cruz de la Santa Compaña) sin tocar lo que lleva arriba:

    blender.exe -b --python tools/afinar_mango.py -- <entrada.glb> <salida.glb> [factor] [medir]

Para qué (Pablo, 11/11: «sí, afina el mango»): la mano del portador es pequeña (dedos de 0,05) y el mango de la cruz, a su escala en el
juego, tiene 0,029 de radio y 0,18 de contorno: los dedos solo lo abarcaban un cuarto de vuelta y, de frente, no se veian rodeandolo.
Escalar la pieza entera en X y Z no vale: encoge tambien el travesano y las campanillas.

Qué hace: mide el eje del mango (centro de las rebanadas de la parte baja) y a qué altura empieza el travesaño (la primera rebanada
cuyo radio maximo salta por encima de 2,2 veces el del mango), y encoge cada vertice HACIA EL EJE por `factor`, solo por debajo del
travesaño y con una rampa justo debajo de el para que el mango llegue a su union con el grosor de antes. El alto no cambia, y el pomo
de abajo se afina en la misma proporcion que el palo. Con `medir` solo imprime las medidas y no escribe nada.
"""
import sys

import bpy
from mathutils import Vector

FACTOR = 0.58            # radio nuevo / radio viejo del mango
N_REBANADAS = 40
SALTO_TRAVESANO = 2.2    # el travesaño empieza donde el radio maximo de la rebanada pasa de esto por el radio del mango
DESDE = 0.40             # ...buscando solo por encima de esta fraccion del alto (abajo esta el pomo, que tambien abulta)
F_RAMPA = 0.07           # fraccion del alto, justo bajo el travesaño, en la que el factor vuelve suavemente a 1


def argumentos():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


def main():
    a = argumentos()
    entrada, salida = a[0], a[1]
    factor = FACTOR
    solo_medir = "medir" in a
    for x in a[2:]:
        try:
            factor = float(x)
        except ValueError:
            pass

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=entrada)
    obj = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if obj.parent:
        bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    vs = [v.co.copy() for v in obj.data.vertices]
    z0 = min(v.z for v in vs)
    alto = max(v.z for v in vs) - z0
    # eje: centro en planta del tercio de abajo (ahi solo hay mango y pomo)
    bajo = [v for v in vs if v.z <= z0 + alto / 3.0]
    cx = sum(v.x for v in bajo) / len(bajo)
    cy = sum(v.y for v in bajo) / len(bajo)

    def radio(v):
        return ((v.x - cx) ** 2 + (v.y - cy) ** 2) ** 0.5

    # perfil: radio maximo por rebanada
    perfil = []
    for i in range(N_REBANADAS):
        za, zb = z0 + alto * i / N_REBANADAS, z0 + alto * (i + 1) / N_REBANADAS
        s = [radio(v) for v in vs if za <= v.z < zb]
        perfil.append(max(s) if s else 0.0)
    # radio del mango: la mediana de las rebanadas entre el 15 % y el 40 % del alto
    tramo = sorted(r for i, r in enumerate(perfil) if 0.15 <= (i + 0.5) / N_REBANADAS <= DESDE and r > 0.0)
    r_mango = tramo[len(tramo) // 2]
    f_corte = 1.0
    for i, r in enumerate(perfil):
        if (i + 0.5) / N_REBANADAS > DESDE and r > r_mango * SALTO_TRAVESANO:
            f_corte = float(i) / N_REBANADAS
            break
    print("eje del mango en planta (%.4f, %.4f) · alto %.3f · radio del mango %.4f · el travesaño empieza al %.0f %% del alto"
          % (cx, cy, alto, r_mango, f_corte * 100.0))
    print("perfil (radio maximo por rebanada, de abajo arriba): " + " ".join("%.3f" % r for r in perfil))
    if solo_medir:
        return

    # SIN RAMPA (medido el 11/11): entre el pomo (30 % del alto) y el travesaño (57 %) el mango de la cruz no tiene vertices, es un
    # tubo de caras largas. Con una rampa bajo el travesaño, esas caras irian del radio fino al grueso a lo largo de un cuarto del
    # alto: un CONO, justo donde agarra la mano (40 %). Se afina todo lo de debajo del travesaño y, ademas, el anillo por el que el
    # mango entra en el (lo que queda pegado al eje justo encima del corte), para que el tubo sea recto hasta arriba.
    z_corte = z0 + alto * f_corte
    z_anillo = z_corte + alto * F_RAMPA
    tocados = 0
    for v in obj.data.vertices:
        if v.co.z < z_corte or (v.co.z < z_anillo and radio(v.co) <= r_mango * 1.35):
            v.co.x = cx + (v.co.x - cx) * factor
            v.co.y = cy + (v.co.y - cy) * factor
            tocados += 1
    obj.data.update()
    print("afinado x%.2f: %d vertices por debajo del travesaño; radio del mango %.4f -> %.4f" % (factor, tocados, r_mango, r_mango * factor))

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=salida, export_format="GLB", use_selection=True,
                              export_animations=False, export_image_format="JPEG", export_yup=True)
    print("ESCRITO: %s" % salida)


main()
