# Monta en Unreal el MISMO muestrario de piezas Pure Nature que el de LabComparativaBosque (tecla 3), para comparar foto con foto (26/11/2026).
# Requiere docs/capturas/comparativa_ue_godot/muestrario.json, que deja el laboratorio con `-- --muestrario`.
#   "E:\UE_5.8\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" "E:\ue_proyectos\StylescapeRuins\StylescapeRuins501.uproject" -run=pythonscript -script="E:\magic-symbols\tools\ue_montar_muestrario.py" -unattended -nop4 -nosplash -NullRHI
# Las fotos: el editor con ventana y  -ExecCmds="py E:/magic-symbols/tools/ue_capturar_prueba_bosque.py muestrario"
#
# Igual que la prueba del bosque: el mapa es una copia del de demo de Meadows con SOLO su luz, las piezas son StaticMeshActor (sin editor
# spawn_actor_from_object no crea nada) y la hierba que toma el color del terreno se cambia por una copia que no lo hace (sin terreno sale negra).
# Godot (u del juego, Y arriba) -> Unreal (cm, Z arriba): (x, z, y) / escala × 100.
import unreal, json, math

ENTRADA = r"E:\magic-symbols\docs\capturas\comparativa_ue_godot\muestrario.json"
MAPA_ORIGEN = "/Game/PureNature_Meadows/Scenes/PureNature_Meadows_DemoScene"
MAPA_DESTINO = "/Game/MagicSymbols/MS_Muestrario"
SE_QUEDAN = ("SkyLight", "SkyAtmosphere", "ExponentialHeightFog", "DirectionalLight", "VolumetricCloud", "PostProcessVolume")
PARAM_TERRENO = "(0) Custom Color <> Terrain Color (1)"
SUELO_MAT = "/Game/MagicSymbols/M_SueloPrueba"     # lo crea tools/ue_montar_prueba_bosque.py

sub = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
mel = unreal.MaterialEditingLibrary
herramientas = unreal.AssetToolsHelpers.get_asset_tools()

with open(ENTRADA, encoding="utf-8") as f:
    datos = json.load(f)
k = 100.0 / float(datos["escala"])


def a_ue(v):
    return unreal.Vector(float(v[0]) * k, float(v[2]) * k, float(v[1]) * k)


_copias = {}


def arreglar_hierba(actor):
    comp = actor.static_mesh_component
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
        if ruta not in _copias:
            nombre = "MI_SinTerreno_" + ruta.split("/")[2] + "_" + mi.get_name()
            destino = "/Game/MagicSymbols/" + nombre
            if unreal.EditorAssetLibrary.does_asset_exist(destino):
                _copias[ruta] = unreal.load_asset(destino)
            else:
                copia = herramientas.create_asset(nombre, "/Game/MagicSymbols", unreal.MaterialInstanceConstant, unreal.MaterialInstanceConstantFactoryNew())
                mel.set_material_instance_parent(copia, mi)
                mel.set_material_instance_scalar_parameter_value(copia, PARAM_TERRENO, 0.0)
                mel.update_material_instance(copia)
                _copias[ruta] = copia
        comp.set_material(i, _copias[ruta])


if unreal.EditorAssetLibrary.does_asset_exist(MAPA_DESTINO):
    unreal.EditorAssetLibrary.delete_asset(MAPA_DESTINO)
unreal.EditorAssetLibrary.duplicate_asset(MAPA_ORIGEN, MAPA_DESTINO)
unreal.EditorLoadingAndSavingUtils.load_map(MAPA_DESTINO)
sub.destroy_actors([a for a in sub.get_all_level_actors() if a.get_class().get_name() not in SE_QUEDAN])

# suelo: un plano grande bajo todo, con la hierba de la prueba
xs = [float(p["pos"][0]) for p in datos["piezas"]]
zs = [float(p["pos"][2]) for p in datos["piezas"]]
cx, cz = (min(xs) + max(xs)) * 0.5, (min(zs) + max(zs)) * 0.5
lado = (max(max(xs) - min(xs), max(zs) - min(zs)) + 40.0) * k
suelo = sub.spawn_actor_from_class(unreal.StaticMeshActor, a_ue([cx, -0.01, cz]), unreal.Rotator(0, 0, 0))
suelo.static_mesh_component.set_static_mesh(unreal.load_asset("/Engine/BasicShapes/Plane"))
suelo.set_actor_scale3d(unreal.Vector(lado / 100.0, lado / 100.0, 1.0))
if unreal.EditorAssetLibrary.does_asset_exist(SUELO_MAT):
    suelo.static_mesh_component.set_material(0, unreal.load_asset(SUELO_MAT))

n = 0
for p in datos["piezas"]:
    m = unreal.load_asset(p["ruta_ue"]) if p.get("ruta_ue") else None
    if m is None:
        unreal.log_warning("no existe " + str(p.get("ruta_ue")))
        continue
    a = sub.spawn_actor_from_class(unreal.StaticMeshActor, a_ue(p["pos"]), unreal.Rotator(0, 0, 0))
    a.static_mesh_component.set_static_mesh(m)
    arreglar_hierba(a)
    a.set_folder_path("Muestrario")
    n += 1

for c in datos["camaras"]:
    d = c["dir"]
    ux, uy, uz = float(d[0]), float(d[2]), float(d[1])
    pitch = math.degrees(math.asin(max(-1.0, min(1.0, uz))))
    yaw = math.degrees(math.atan2(uy, ux))
    cam = sub.spawn_actor_from_class(unreal.CameraActor, a_ue(c["pos"]), unreal.Rotator(0.0, pitch, yaw))
    cam.set_actor_label(c["nombre"])
    cam.camera_component.set_editor_property("field_of_view", float(c["fov"]))
    cam.camera_component.set_editor_property("constrain_aspect_ratio", False)
    cam.set_folder_path("Camaras")

unreal.EditorLoadingAndSavingUtils.save_current_level()
unreal.EditorAssetLibrary.save_directory("/Game/MagicSymbols")
unreal.log("MUESTRARIO MONTADO: %d piezas, %d cámaras" % (n, len(datos["camaras"])))
