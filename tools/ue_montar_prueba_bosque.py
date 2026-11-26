# Monta en Unreal la escena de prueba «bosque con ruinas» para comparar Unreal y Godot (26/11/2026).
#
# Se ejecuta SIN abrir el editor, sobre el proyecto E:\ue_proyectos\StylescapeRuins (que tiene Meadows, Mountains y Stylescape):
#   "E:\UE_5.8\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" "E:\ue_proyectos\StylescapeRuins\StylescapeRuins501.uproject" -run=pythonscript -script="E:\magic-symbols\tools\ue_montar_prueba_bosque.py" -unattended -nop4 -nosplash -NullRHI
#
# Qué hace:
#   1. Duplica el mapa de demo de Meadows y le deja SOLO la iluminación (sol, cielo, niebla, nubes y posproceso del pack).
#   2. Coloca encima una escena fija (semilla fija): suelo de hierba, sala en ruinas en el centro, árboles alrededor,
#      rocas, arbustos, hierba y flores, y un acantilado al fondo.
#   3. Pone dos cámaras: «Cam_Juego» (la vista del juego, 30° sobre el suelo) y «Cam_Detalle» (más baja y cerca).
#   4. Guarda la disposición en docs/capturas/comparativa_ue_godot/escena.json para montar EXACTAMENTE la misma en Godot.
#
# Todo en centímetros (unidades de Unreal). X hacia delante, Y a la derecha, Z arriba.
import unreal, json, random, math, os

MAPA_ORIGEN = "/Game/PureNature_Meadows/Scenes/PureNature_Meadows_DemoScene"
MAPA_DESTINO = "/Game/MagicSymbols/MS_PruebaBosque"
SALIDA_JSON = r"E:\magic-symbols\docs\capturas\comparativa_ue_godot\escena.json"
SEMILLA = 7

MEA = "/Game/PureNature_Meadows/Models/"
MON = "/Game/PureNature_Mountains/Models/"
RUI = "/Game/Stylescape/Ruins/Meshes/"
SUELO_MAT = "/Game/MagicSymbols/M_SueloPrueba"       # se crea aquí abajo (el Grass01 del pack es de terreno y en un plano sale azul)
SUELO_TEX = "/Game/PureNature_Meadows/Textures/Surfaces/T_Grass01_"
SUELO_REPETICION = 30.0                               # 60 m de plano / 30 = la textura se repite cada 2 m
# La hierba de BK toma el color del terreno (Runtime Virtual Texture); sin terreno sale negra. Copia con ese parámetro a 0.
PARAM_TERRENO = "(0) Custom Color <> Terrain Color (1)"
mel = unreal.MaterialEditingLibrary
herramientas = unreal.AssetToolsHelpers.get_asset_tools()

# Clases que se quedan del mapa de demo (la iluminación); lo demás se borra.
SE_QUEDAN = ("SkyLight", "SkyAtmosphere", "ExponentialHeightFog", "DirectionalLight", "VolumetricCloud", "PostProcessVolume")

sub = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
piezas = []   # lo que se guarda en el JSON


def poner(malla, x, y, z=0.0, giro=0.0, escala=1.0, etiqueta=None, material=None, escala_xyz=None):
    m = unreal.load_asset(malla)
    if m is None:
        unreal.log_warning("No existe: " + malla)
        return None
    # Sin editor (commandlet) spawn_actor_from_object no crea nada: se crea un StaticMeshActor y se le pone la malla.
    a = sub.spawn_actor_from_class(unreal.StaticMeshActor, unreal.Vector(x, y, z), unreal.Rotator(0.0, 0.0, giro))
    a.static_mesh_component.set_static_mesh(m)
    esc = escala_xyz if escala_xyz else (escala, escala, escala)
    a.set_actor_scale3d(unreal.Vector(*esc))
    if etiqueta:
        a.set_actor_label(etiqueta)
    if material:
        a.static_mesh_component.set_material(0, unreal.load_asset(material))
    cambiados = arreglar_hierba(a)
    a.set_folder_path("Escena")
    piezas.append({"malla": malla, "pos": [x, y, z], "giro": giro, "escala": list(esc), "material": material, "sin_terreno": cambiados})
    return a


_copias_hierba = {}


def arreglar_hierba(actor):
    """Cambia los materiales de hierba que tiran del color del terreno por una copia que usa su propio color."""
    comp = actor.static_mesh_component
    cambiados = []
    for i in range(comp.get_num_materials()):
        mi = comp.get_material(i)
        if not isinstance(mi, unreal.MaterialInstance):
            continue
        try:
            v = mel.get_material_instance_scalar_parameter_value(mi, PARAM_TERRENO)
        except Exception:
            continue
        if v <= 0.0:
            continue
        ruta = mi.get_path_name()
        if ruta not in _copias_hierba:
            nombre = "MI_SinTerreno_" + ruta.split("/")[2] + "_" + mi.get_name()
            destino = "/Game/MagicSymbols/" + nombre
            if unreal.EditorAssetLibrary.does_asset_exist(destino):
                unreal.EditorAssetLibrary.delete_asset(destino)
            copia = herramientas.create_asset(nombre, "/Game/MagicSymbols", unreal.MaterialInstanceConstant, unreal.MaterialInstanceConstantFactoryNew())
            mel.set_material_instance_parent(copia, mi)
            mel.set_material_instance_scalar_parameter_value(copia, PARAM_TERRENO, 0.0)
            mel.update_material_instance(copia)
            _copias_hierba[ruta] = copia
        comp.set_material(i, _copias_hierba[ruta])
        cambiados.append(i)
    return cambiados


def crear_suelo():
    """Material de suelo sencillo: la hierba de Meadows (color + normal) repetida cada 2 m, rugosidad 0,9."""
    if unreal.EditorAssetLibrary.does_asset_exist(SUELO_MAT):
        unreal.EditorAssetLibrary.delete_asset(SUELO_MAT)
    m = herramientas.create_asset("M_SueloPrueba", "/Game/MagicSymbols", unreal.Material, unreal.MaterialFactoryNew())
    uv = mel.create_material_expression(m, unreal.MaterialExpressionTextureCoordinate, -700, 0)
    uv.set_editor_property("u_tiling", SUELO_REPETICION)
    uv.set_editor_property("v_tiling", SUELO_REPETICION)
    color = mel.create_material_expression(m, unreal.MaterialExpressionTextureSample, -350, -150)
    color.set_editor_property("texture", unreal.load_asset(SUELO_TEX + "a"))
    normal = mel.create_material_expression(m, unreal.MaterialExpressionTextureSample, -350, 150)
    normal.set_editor_property("texture", unreal.load_asset(SUELO_TEX + "n"))
    normal.set_editor_property("sampler_type", unreal.MaterialSamplerType.SAMPLERTYPE_NORMAL)
    rug = mel.create_material_expression(m, unreal.MaterialExpressionConstant, -350, 400)
    rug.set_editor_property("r", 0.9)
    mel.connect_material_expressions(uv, "", color, "UVs")
    mel.connect_material_expressions(uv, "", normal, "UVs")
    mel.connect_material_property(color, "RGB", unreal.MaterialProperty.MP_BASE_COLOR)
    mel.connect_material_property(normal, "RGB", unreal.MaterialProperty.MP_NORMAL)
    mel.connect_material_property(rug, "", unreal.MaterialProperty.MP_ROUGHNESS)
    mel.recompile_material(m)


# 1. Mapa: copia del de Meadows, solo con su luz
if unreal.EditorAssetLibrary.does_asset_exist(MAPA_DESTINO):
    unreal.EditorAssetLibrary.delete_asset(MAPA_DESTINO)
unreal.EditorAssetLibrary.duplicate_asset(MAPA_ORIGEN, MAPA_DESTINO)
unreal.EditorLoadingAndSavingUtils.load_map(MAPA_DESTINO)
borrar = [a for a in sub.get_all_level_actors() if not any(k == a.get_class().get_name() for k in SE_QUEDAN)]
sub.destroy_actors(borrar)

luz = {}
for a in sub.get_all_level_actors():
    c = a.get_class().get_name()
    if c == "DirectionalLight":
        r = a.get_actor_rotation()
        comp = a.get_component_by_class(unreal.DirectionalLightComponent)
        luz["sol"] = {"pitch": r.pitch, "yaw": r.yaw, "intensidad": comp.get_editor_property("intensity")}

rnd = random.Random(SEMILLA)

# 2. Suelo: un plano de 60 x 60 m con la hierba de Meadows
crear_suelo()
poner("/Engine/BasicShapes/Plane", 0, 0, 0, 0, escala_xyz=(60.0, 60.0, 1.0), etiqueta="Suelo", material=SUELO_MAT)

# 2a. La sala en ruinas (8 x 8 m) en el centro: suelo de losas, muros rotos, pilares y un arco
for fx in (-200, 200):
    for fy in (-200, 200):
        poner(RUI + "Merged/SM_Floor_4x4_01", fx, fy, 0, 0, etiqueta="Losas")
poner(RUI + "SM_Wall_Dmg_02", -400, 0, 0, 0, etiqueta="MuroOeste")
poner(RUI + "SM_Wall_Dmg_03_Half_01", 0, -400, 0, 90, etiqueta="MuroNorte")
poner(RUI + "SM_Wall_Dmg_04_Alt", 300, 400, 0, 90, etiqueta="MuroSurRoto")
poner(RUI + "SM_Wall_Arch_01", 400, 0, 0, 0, etiqueta="Arco")
for (px, py) in ((-400, -400), (-400, 400), (400, -400)):
    poner(RUI + "SM_Pillar_01_Dmg", px, py, 0, rnd.choice((0, 90, 180, 270)), etiqueta="Pilar")
poner(RUI + "SM_Pillar_03", 400, 400, 0, 0, etiqueta="PilarBajo")
for i in range(5):
    poner(RUI + rnd.choice(("SM_Rubble_01", "SM_Rubble_02")), rnd.uniform(-350, 350), rnd.uniform(-350, 350), 0, rnd.uniform(0, 360), etiqueta="Escombro")
poner(RUI + "SM_HangingIvy_02", -375, 0, 120, 0, etiqueta="Hiedra")
poner(RUI + "SM_Crate_01", -250, 250, 0, 20, etiqueta="Caja")

# 2b. Árboles en corona (radio 9–20 m), mezcla de caducifolios (Meadows) y coníferas (Mountains)
ARBOLES = [MEA + "Trees/Meshes/Oak/Oak2/SM_Oak2", MEA + "Trees/Meshes/Oak/Oak3/SM_Oak3", MEA + "Trees/Meshes/Elm/Elm2/SM_Elm2",
           MEA + "Trees/Meshes/Birch/Birch3/SM_Birch3", MEA + "Trees/Meshes/Birch/Birch4/SM_Birch4",
           MON + "Trees/Meshes/Pine/Pine4/SM_Pine4", MON + "Trees/Meshes/Fir/Fir3/SM_Fir3", MON + "Trees/Meshes/Spruce/Spruce3/SM_Spruce3"]
for i in range(22):
    ang = i / 22.0 * 2 * math.pi + rnd.uniform(-0.12, 0.12)
    r = rnd.uniform(950, 2000)
    x, y = r * math.cos(ang), r * math.sin(ang)
    if x < -600 and abs(y) < 900:   # hueco delante de la cámara para ver la sala
        continue
    poner(ARBOLES[i % len(ARBOLES)], x, y, 0, rnd.uniform(0, 360), rnd.uniform(0.85, 1.15), etiqueta="Arbol")

# 2c. Arbustos y rocas
for i in range(14):
    ang, r = rnd.uniform(0, 2 * math.pi), rnd.uniform(600, 1600)
    malla = rnd.choice((MEA + "Trees/Meshes/Bush/Bush1/SM_Bush1", MEA + "Trees/Meshes/Bush/Bush2/SM_Bush2", MON + "Trees/Meshes/Bush/Bush3/SM_Bush3",
                        MON + "Rocks/Meshes/SM_Stone2", MON + "Rocks/Meshes/SM_Stone4", MON + "Rocks/Meshes/SM_Boulder2", MEA + "Rocks/Meshes/SM_Stone5"))
    poner(malla, r * math.cos(ang), r * math.sin(ang), 0, rnd.uniform(0, 360), rnd.uniform(0.7, 1.1), etiqueta="ArbustoRoca")

# 2d. Hierba, helechos, flores y setas (fuera de la sala)
MATAS = [MEA + "Plants/Meshes/SM_GrassMeadows1", MEA + "Plants/Meshes/SM_GrassMeadows3", MON + "Plants/Meshes/SM_Grass3",
         MON + "Plants/Meshes/SM_Fern1", MON + "Plants/Meshes/SM_Fern2", MEA + "Plants/Meshes/SM_FlowerMeadow1",
         MEA + "Plants/Meshes/SM_Lupin2", MEA + "Plants/Meshes/SM_Daisy", MEA + "Mushroom/Meshes/SM_Mushroom3"]
n = 0
while n < 260:
    x, y = rnd.uniform(-2400, 2400), rnd.uniform(-2400, 2400)
    if abs(x) < 470 and abs(y) < 470:
        continue
    poner(rnd.choice(MATAS), x, y, 0, rnd.uniform(0, 360), rnd.uniform(0.8, 1.3), etiqueta="Mata")
    n += 1

# 2e. Acantilado al fondo (detrás de la sala, mirando desde la cámara)
poner(MON + "Rocks/Meshes/SM_Cliff4", 3200, -400, -300, 200, 0.8, etiqueta="Acantilado")

# 3. Cámaras: la del juego (30° sobre el suelo) y una de detalle
def camara(nombre, x, y, z, pitch, yaw, fov):
    c = sub.spawn_actor_from_class(unreal.CameraActor, unreal.Vector(x, y, z), unreal.Rotator(0.0, pitch, yaw))
    c.set_actor_label(nombre)
    c.camera_component.set_editor_property("field_of_view", fov)
    c.camera_component.set_editor_property("constrain_aspect_ratio", False)
    c.set_folder_path("Camaras")
    return {"nombre": nombre, "pos": [x, y, z], "pitch": pitch, "yaw": yaw, "fov": fov}

DIST = 2600.0
camaras = [camara("Cam_Juego", -DIST * math.cos(math.radians(30)), 0, DIST * math.sin(math.radians(30)), -30.0, 0.0, 50.0),
           camara("Cam_Detalle", -1100, 450, 260, -10.0, -15.0, 60.0)]

unreal.EditorLoadingAndSavingUtils.save_current_level()
unreal.EditorAssetLibrary.save_directory("/Game/MagicSymbols")

os.makedirs(os.path.dirname(SALIDA_JSON), exist_ok=True)
with open(SALIDA_JSON, "w", encoding="utf-8") as f:
    json.dump({"mapa": MAPA_DESTINO, "unidad": "cm", "luz": luz, "suelo": {"textura": SUELO_TEX, "repeticion": SUELO_REPETICION, "rugosidad": 0.9}, "camaras": camaras, "piezas": piezas}, f, indent=1, ensure_ascii=False)
unreal.log("PRUEBA BOSQUE MONTADA: %d piezas" % len(piezas))
