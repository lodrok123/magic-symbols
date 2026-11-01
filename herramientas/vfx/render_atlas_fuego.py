# ATLAS DE FUEGO Y HUMO 8×8 (1/11, Dirección, comparativa de VFX §1.2). Lo corre Blender 5.2 sin ventana:
#   "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b -P herramientas/vfx/render_atlas_fuego.py -- <carpeta_salida> [<carpeta_temporal>]
# Escribe <carpeta_salida>/fuego_8x8.png (llamas, con emisión) y <carpeta_salida>/humo_8x8.png (solo densidad, sin emisión), 2048×2048 RGBA,
# 64 fotogramas de 256×256 leídos de izquierda a derecha y de arriba abajo (lo que espera `particles_anim` de Godot y `flipbook_erosion.gdshader`).
# Qué simula: un dominio Mantaflow de gas con fuego desde un emisor en el suelo, cocido FOTOGRAMAS fotogramas; cámara ortográfica de frente, fondo transparente,
# EEVEE. Si la cocción falla (ocurre en algunos Blender sin ventana), cae al PLAN B: un volumen procedimental (ruido 4D que sube) con la misma rampa; se avisa en la salida.
# Todo lo que cambia el aspecto está en las constantes de arriba. No toca nada del proyecto de Godot: el atlas se importa como una textura más.

import bpy
import math
import os
import shutil
import sys

import numpy as np

COLUMNAS = 8
FILAS = 8
FOTOGRAMAS = COLUMNAS * FILAS          # 64
CELDA = 256                            # px por fotograma → atlas de 2048
RESOLUCION_DOMINIO = 96                # divisiones de Mantaflow (más = más detalle y más lento)
ALTO_DOMINIO = 4.0                     # m; la llama ocupa ~2/3
ANCHO_DOMINIO = 2.8
RADIO_EMISOR = 0.42
FUEGO_COMBUSTION = 1.6                 # cuánto arde el combustible (altura de llama)
VORTICIDAD = 0.15
FOTOGRAMAS_PREVIOS = 60                # se cuecen antes de empezar a grabar, para que la llama ya esté formada
TEMPERATURA_MAX = 0.7                  # intensidad del cuerpo negro en el volumen
TEMPERATURA_K = 1100.0                 # kelvin por unidad de «temperature» de Mantaflow (1,5 → 1650 K: naranja; más = más blanco)
ENCUADRE = 3.3                         # m de alto que ve la cámara (la llama llena la celda)
SUAVIZADO_ALFA = 3                     # px de desenfoque del alfa de cada fotograma (0 = ninguno)
LUZ_HUMO = 3.0                        # sol desde la cámara para que el humo (sin emisión) tenga volumen
RAMPA = [(0.00, (0.0, 0.0, 0.0, 1.0)), (0.25, (0.55, 0.02, 0.0, 1.0)), (0.55, (1.0, 0.35, 0.0, 1.0)),
         (0.80, (1.0, 0.8, 0.15, 1.0)), (1.00, (1.0, 1.0, 0.9, 1.0))]


def _args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    salida = os.path.abspath(a[0]) if a else os.path.abspath("presentacion/vfx/atlas")
    temporal = os.path.abspath(a[1]) if len(a) > 1 else os.path.join(salida, "_fotogramas")
    os.makedirs(salida, exist_ok=True)
    os.makedirs(temporal, exist_ok=True)
    return salida, temporal


def _escena_limpia():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT" if hasattr(bpy.types, "SceneEEVEE") and "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    sc.render.resolution_x = CELDA
    sc.render.resolution_y = CELDA
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "AgX" if "AgX" in [e.identifier for e in sc.view_settings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
    sc.eevee.taa_render_samples = 16
    if hasattr(sc.eevee, "volumetric_tile_size"):
        sc.eevee.volumetric_tile_size = "2"
    sc.frame_start = 1
    sc.frame_end = FOTOGRAMAS_PREVIOS + FOTOGRAMAS
    return sc


def _camara(sc):
    cam_d = bpy.data.cameras.new("Cam")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = ENCUADRE
    cam = bpy.data.objects.new("Cam", cam_d)
    sc.collection.objects.link(cam)
    cam.location = (0.0, -10.0, ENCUADRE * 0.5 - 0.1)
    cam.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    sc.camera = cam
    luz_d = bpy.data.lights.new("Sol", "SUN")
    luz_d.energy = LUZ_HUMO
    luz = bpy.data.objects.new("Sol", luz_d)
    sc.collection.objects.link(luz)
    luz.rotation_euler = (math.radians(60.0), 0.0, math.radians(-20.0))


def _material_volumen(nombre, con_fuego, procedimental):
    m = bpy.data.materials.new(nombre)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    nt.links.new(vol.outputs["Volume"], out.inputs["Volume"])
    vol.inputs["Density"].default_value = 1.0 if not procedimental else 0.0
    vol.inputs["Blackbody Intensity"].default_value = TEMPERATURA_MAX if con_fuego else 0.0
    vol.inputs["Temperature"].default_value = TEMPERATURA_K   # Mantaflow da «temperature» en 1–2: este factor lo pasa a kelvin
    vol.inputs["Color"].default_value = (0.45, 0.45, 0.45, 1.0)
    if procedimental:
        # Ruido 4D que sube con el tiempo y se estrecha con la altura: llama sin simulación (plan B).
        coord = nt.nodes.new("ShaderNodeTexCoord")
        mapa = nt.nodes.new("ShaderNodeMapping")
        ruido = nt.nodes.new("ShaderNodeTexNoise")
        ruido.noise_dimensions = "4D"
        ruido.inputs["Scale"].default_value = 2.2
        ruido.inputs["Detail"].default_value = 6.0
        ruido.inputs["Roughness"].default_value = 0.55
        grad = nt.nodes.new("ShaderNodeTexGradient")
        grad.gradient_type = "SPHERICAL"
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        rampa = nt.nodes.new("ShaderNodeValToRGB")
        rampa.color_ramp.elements[0].position = 0.45
        rampa.color_ramp.elements[1].position = 0.75
        nt.links.new(coord.outputs["Object"], mapa.inputs["Vector"])
        nt.links.new(mapa.outputs["Vector"], ruido.inputs["Vector"])
        nt.links.new(coord.outputs["Object"], grad.inputs["Vector"])
        nt.links.new(ruido.outputs["Fac"], mul.inputs[0])
        nt.links.new(grad.outputs["Fac"], mul.inputs[1])
        nt.links.new(mul.outputs["Value"], rampa.inputs["Fac"])
        nt.links.new(rampa.outputs["Color"], vol.inputs["Density"])
        densidad_x = nt.nodes.new("ShaderNodeMath")
        densidad_x.operation = "MULTIPLY"
        densidad_x.inputs[1].default_value = 6.0
        nt.links.new(rampa.outputs["Color"], densidad_x.inputs[0])
        nt.links.new(densidad_x.outputs["Value"], vol.inputs["Density"])
        if con_fuego:
            nt.links.new(rampa.outputs["Color"], vol.inputs["Temperature"])
        m["_mapa"] = mapa.name
        m["_ruido"] = ruido.name
    return m


def _montar_simulacion(sc):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, ALTO_DOMINIO * 0.5))
    dom = bpy.context.active_object
    dom.name = "Dominio"
    dom.scale = (ANCHO_DOMINIO, ANCHO_DOMINIO, ALTO_DOMINIO)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.modifier_add(type="FLUID")
    dom.modifiers["Fluid"].fluid_type = "DOMAIN"
    ds = dom.modifiers["Fluid"].domain_settings
    ds.domain_type = "GAS"
    ds.resolution_max = RESOLUCION_DOMINIO
    ds.use_adaptive_domain = False
    ds.vorticity = VORTICIDAD
    ds.burning_rate = 0.75
    ds.flame_smoke = 0.9
    ds.flame_max_temp = 1.75
    ds.flame_ignition = 1.5
    ds.use_noise = False                 # el reescalado por ruido mezcla cachés de distinta resolución y recorta la llama
    ds.cache_frame_start = 1
    ds.cache_frame_end = sc.frame_end
    ds.cache_type = "ALL"
    cache = os.path.join(os.environ.get("TEMP", "."), "ms_atlas_cache")
    shutil.rmtree(cache, ignore_errors=True)   # una caché de otra resolución recorta la llama
    os.makedirs(cache, exist_ok=True)
    ds.cache_directory = cache
    os.chdir(cache)                         # Mantaflow deja waveletNoiseTile.bin en el directorio actual: que caiga en la caché, no en el repo

    bpy.ops.mesh.primitive_uv_sphere_add(radius=RADIO_EMISOR, location=(0.0, 0.0, RADIO_EMISOR * 0.8))
    em = bpy.context.active_object
    em.name = "Emisor"
    em.scale = (1.0, 1.0, 0.5)
    bpy.ops.object.modifier_add(type="FLUID")
    em.modifiers["Fluid"].fluid_type = "FLOW"
    fs = em.modifiers["Fluid"].flow_settings
    fs.flow_type = "BOTH"
    fs.flow_behavior = "INFLOW"
    fs.fuel_amount = FUEGO_COMBUSTION
    fs.temperature = 1.5
    fs.density = 0.6
    fs.use_initial_velocity = True
    fs.velocity_normal = 1.6
    fs.surface_distance = 0.6
    em.hide_render = True
    return dom


def _cocer(dom):
    try:
        with bpy.context.temp_override(object=dom, active_object=dom, selected_objects=[dom]):
            bpy.ops.fluid.bake_all()
        ds = dom.modifiers["Fluid"].domain_settings
        ok = ds.cache_frame_pause_data if hasattr(ds, "cache_frame_pause_data") else 0
        return True
    except Exception as e:  # noqa: BLE001
        print("COCCION FALLIDA: %s" % e)
        return False


def _montar_procedimental(sc):
    bpy.ops.mesh.primitive_cylinder_add(radius=ANCHO_DOMINIO * 0.5, depth=ALTO_DOMINIO, location=(0.0, 0.0, ALTO_DOMINIO * 0.5))
    ob = bpy.context.active_object
    ob.name = "LlamaProcedimental"
    ob.scale = (1.0, 1.0, 1.0)
    return ob


def _render_tanda(sc, ob, material, temporal, prefijo, procedimental):
    ob.data.materials.clear()
    ob.data.materials.append(material)
    rutas = []
    for i in range(FOTOGRAMAS):
        f = FOTOGRAMAS_PREVIOS + 1 + i
        sc.frame_set(f)
        if procedimental:
            mapa = material.node_tree.nodes[material["_mapa"]]
            ruido = material.node_tree.nodes[material["_ruido"]]
            mapa.inputs["Location"].default_value = (0.0, 0.0, -i * 0.09)
            ruido.inputs["W"].default_value = i * 0.07
        ruta = os.path.join(temporal, "%s_%02d.png" % (prefijo, i))
        sc.render.filepath = ruta
        bpy.ops.render.render(write_still=True)
        rutas.append(ruta)
    return rutas


def _suavizar(a, radio):
    """Desenfoque de caja (dos pasadas) del alfa: la silueta de Mantaflow a baja resolución es dura y las partículas se leen como bloques."""
    if radio <= 0:
        return a
    for _ in range(2):
        acum = np.zeros_like(a)
        n = 0
        for dy in range(-radio, radio + 1):
            for dx in range(-radio, radio + 1):
                acum += np.roll(np.roll(a, dy, axis=0), dx, axis=1)
                n += 1
        a = acum / n
    return a


def _atlas(rutas, destino):
    tam = CELDA * COLUMNAS
    atlas = np.zeros((tam, tam, 4), dtype=np.float32)
    for i, r in enumerate(rutas):
        img = bpy.data.images.load(r)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
        px = px[::-1]  # Blender guarda de abajo arriba
        # La llama emite sin apenas densidad: su alfa sería ~0 y el shader (que recorta por alfa) la perdería. El alfa pasa a ser
        # max(densidad, luminancia) para que la silueta cubra también lo que brilla.
        lum = np.max(px[:, :, :3], axis=2)
        px[:, :, 3] = _suavizar(np.maximum(px[:, :, 3], np.clip(lum, 0.0, 1.0)), SUAVIZADO_ALFA)
        c = i % COLUMNAS
        fila = i // COLUMNAS
        atlas[fila * CELDA:(fila + 1) * CELDA, c * CELDA:(c + 1) * CELDA] = px
        bpy.data.images.remove(img)
    out = bpy.data.images.new("atlas", tam, tam, alpha=True, float_buffer=False)
    out.pixels = atlas[::-1].ravel().tolist()
    out.filepath_raw = destino
    out.file_format = "PNG"
    out.save()


def main():
    salida, temporal = _args()
    sc = _escena_limpia()
    _camara(sc)
    procedimental = False
    dom = _montar_simulacion(sc)
    if not _cocer(dom):
        procedimental = True
        for o in list(sc.collection.objects):
            if o.type == "MESH":
                bpy.data.objects.remove(o)
        dom = _montar_procedimental(sc)
        print("PLAN B: atlas procedimental (sin Mantaflow)")
    m_fuego = _material_volumen("Fuego", True, procedimental)
    m_humo = _material_volumen("Humo", False, procedimental)
    rutas_f = _render_tanda(sc, dom, m_fuego, temporal, "fuego", procedimental)
    _atlas(rutas_f, os.path.join(salida, "fuego_8x8.png"))
    rutas_h = _render_tanda(sc, dom, m_humo, temporal, "humo", procedimental)
    _atlas(rutas_h, os.path.join(salida, "humo_8x8.png"))
    print("ATLAS LISTO en %s (%s)" % (salida, "procedimental" if procedimental else "mantaflow"))


main()
