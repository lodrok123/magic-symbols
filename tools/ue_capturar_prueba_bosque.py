# Saca las fotos de Unreal de la escena de prueba «bosque con ruinas» (26/11/2026). Necesita el editor CON ventana (para que renderice):
#   "E:\UE_5.8\Engine\Binaries\Win64\UnrealEditor.exe" "E:\ue_proyectos\StylescapeRuins\StylescapeRuins501.uproject" -ExecCmds="py E:/magic-symbols/tools/ue_capturar_prueba_bosque.py"
# (con -ExecutePythonScript el editor se cierra en cuanto acaba el script, antes de que dé tiempo a renderizar).
# Abre el mapa, se pone en cada cámara (Cam_Juego, Cam_Detalle), espera a que Lumen se asiente, saca una foto 1920x1080
# y cierra el editor. Las fotos acaban en docs/capturas/comparativa_ue_godot/unreal_<camara>.png
import unreal, os, shutil, glob, time

MAPA = "/Game/MagicSymbols/MS_PruebaBosque"
DESTINO = r"E:\magic-symbols\docs\capturas\comparativa_ue_godot"
CAMARAS = ["Cam_Juego", "Cam_Detalle"]
ESPERA = 25.0           # segundos por cámara antes de la foto (texturas, Lumen y la exposición automática tardan en asentarse)
ESPERA_CARGA = 40.0     # segundos tras cargar el mapa (la primera vez compila sombreadores y sube texturas)
DIR_FOTOS = os.path.join(unreal.Paths.project_saved_dir(), "Screenshots")

les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
sub = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
estado = {"paso": "cargar", "cam": 0, "t": time.time(), "antes": set()}
unreal.log("CAPTURA: script cargado")


def fotos():
    return set(glob.glob(os.path.join(DIR_FOTOS, "**", "*.png"), recursive=True))


def camara(nombre):
    for a in sub.get_all_level_actors():
        if a.get_actor_label() == nombre:
            return a
    return None


def tick(dt):
    e = estado
    pasado = time.time() - e["t"]
    if e["paso"] == "cargar":
        unreal.EditorLoadingAndSavingUtils.load_map(MAPA)
        les.editor_set_game_view(True)
        unreal.log("CAPTURA: mapa cargado")
        e.update(paso="asentar", t=time.time())
    elif e["paso"] == "asentar" and pasado >= ESPERA_CARGA:
        e.update(paso="apuntar", t=time.time())
    elif e["paso"] == "apuntar":
        nombre = CAMARAS[e["cam"]]
        les.pilot_level_actor(camara(nombre))
        unreal.log("CAPTURA: en " + nombre)
        e.update(paso="esperar", t=time.time())
    elif e["paso"] == "esperar" and pasado >= ESPERA:
        e["antes"] = fotos()
        unreal.SystemLibrary.execute_console_command(unreal.EditorLevelLibrary.get_editor_world(), "HighResShot 1920x1080")
        unreal.log("CAPTURA: HighResShot pedido")
        e.update(paso="guardar", t=time.time())
    elif e["paso"] == "guardar" and pasado >= 2.0:
        nuevas = sorted(fotos() - e["antes"], key=os.path.getmtime)
        if nuevas or pasado > 30.0:
            if nuevas:
                os.makedirs(DESTINO, exist_ok=True)
                shutil.copy(nuevas[-1], os.path.join(DESTINO, "unreal_" + CAMARAS[e["cam"]] + ".png"))
                unreal.log("FOTO " + CAMARAS[e["cam"]] + " -> " + nuevas[-1])
            else:
                unreal.log_warning("SIN FOTO para " + CAMARAS[e["cam"]])
            les.eject_pilot_level_actor()
            e["cam"] += 1
            e.update(paso="apuntar" if e["cam"] < len(CAMARAS) else "salir", t=time.time())
    elif e["paso"] == "salir" and pasado > 1.0:
        unreal.unregister_slate_post_tick_callback(manejador)
        unreal.SystemLibrary.quit_editor()


manejador = unreal.register_slate_post_tick_callback(tick)
