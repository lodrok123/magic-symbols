# Prueba 2 (fuego toon): capturas en PIE del muro toon (tecla 5 = evento LanzarMuroToon): muro_cerca, cuatro fotogramas
# consecutivos (comprobación de los 12 fps), secuencia para el GIF (a cámara lenta, un fotograma por tick), muro_lejos,
# juego_muro, diez muros con stat fps. Máquina de estados sobre el tick de Slate, como 08_capturas.py.
import unreal as ue, os, traceback
LES = ue.get_editor_subsystem(ue.LevelEditorSubsystem)
UES = ue.get_editor_subsystem(ue.UnrealEditorSubsystem)
GS = ue.GameplayStatics
ESTADO = ue.Paths.project_dir() + "Saved/capturas2_estado.txt"
N_SEQ = int(os.environ.get("POC2_NSEQ", "40"))
_log = open(ESTADO, "w", encoding="utf-8")
def log(*a):
    s = " ".join(str(x) for x in a); _log.write(s + "\n"); _log.flush(); ue.log("[capturas2] " + s)

ctx = {"t": 0.0, "paso": 0, "fps": [], "seq": 0}
def mundo(): return UES.get_game_world()
def pawn(): return GS.get_player_pawn(mundo(), 0)
def pc(): return GS.get_player_controller(mundo(), 0)
def v(x, y, z): return ue.Vector(x, y, z)
def mirar(desde, hacia): return ue.MathLibrary.find_look_at_rotation(desde, hacia)
def consola(cmd): ue.SystemLibrary.execute_console_command(mundo(), cmd)
def tiempo(): return GS.get_time_seconds(mundo())
def captura(nombre, w=1920, h=1080):
    """Las capturas de alta resolución son asíncronas: si se encolan muchas se procesan tarde (en otra cámara y con
    el efecto ya muerto). Se guarda la tarea para esperar a que termine antes de la siguiente."""
    ctx["tarea"] = ue.AutomationLibrary.take_high_res_screenshot(w, h, nombre)
    log("captura", nombre, "t_juego=%.4f" % tiempo())
def captura_hecha():
    t = ctx.get("tarea")
    return True if (t is None or t.is_task_done()) else False
ESPERAR = (0.0, captura_hecha)
def teletransportar(x, y, yaw=0.0):
    p = pawn(); z = p.get_actor_location().z
    p.set_actor_location_and_rotation(v(x, y, z), ue.Rotator(0, 0, yaw), False, True)
    pc().set_control_rotation(ue.Rotator(0, 0, yaw))
def lanzar(evento):
    pawn().call_method(evento); log("evento", evento, "pawn en", pawn().get_actor_location())
def camara_en(desde, hacia):
    cam = ctx.get("cam")
    if cam is None:
        cam = [a for a in GS.get_all_actors_of_class(mundo(), ue.CameraActor) if a.actor_has_tag("CamaraCapturas")][0]; ctx["cam"] = cam
    cam.set_actor_location_and_rotation(desde, mirar(desde, hacia), False, True)
    pc().set_view_target_with_blend(cam, 0.0)
def vista_jugador(): pc().set_view_target_with_blend(pawn(), 0.0)
def actores(clase):
    c = ue.load_object(None, "/Game/POC2/BP/%s.%s_C" % (clase, clase))
    return list(GS.get_all_actors_of_class(mundo(), c))
def listar(clase):
    log("actores", clase, [str(a.get_actor_location()) for a in actores(clase)])
def info_sistema():
    for a in actores("BP_MuroFuegoToon"):
        c = a.get_component_by_class(ue.NiagaraComponent)
        log("niagara", a.get_name(), "activo", c.is_active(), "asset", c.get_asset().get_name(), "escala", c.get_editor_property("relative_scale3d"))
def seq_paso():
    """Una captura cada 1/12 s de tiempo de juego (el mundo no avanza en el fotograma en que se procesa una captura,
    así que los retardos se miden en tiempo de juego; ver _tick). Las 40 capturas son 3,3 s a 12 fps."""
    captura("seq_%03d" % ctx["seq"], 960, 540); ctx["seq"] += 1
    return True if ctx["seq"] >= N_SEQ else None
def pasos_secuencia():
    return [(1.0 / 12, seq_paso) for _ in range(N_SEQ)]

Z = {}
def esperar_pie():
    if not LES.is_in_play_in_editor(): return False
    try:
        p = pawn()
        if p is None: return False
    except Exception: return False
    Z["z"] = p.get_actor_location().z; log("PIE listo; pawn z =", Z["z"]); return True
def E(x, y, dz=-90): return v(x, y, Z["z"] + dz)

CERCA = (lambda: E(-400, 0) + v(-200, 0, 130), lambda: E(-400, 0) + v(0, 0, 60))
LEJOS = (lambda: E(-400, 0) + v(-1000, 0, 220), lambda: E(-400, 0) + v(0, 0, 60))

def contorno(valor):
    MEL = ue.MaterialEditingLibrary
    for n in ("MI_FuegoToon_Cuerpo", "MI_FuegoToon_Lengua"):
        mi = ue.load_asset("/Game/POC2/Materiales/" + n)
        MEL.set_material_instance_scalar_parameter_value(mi, "Contorno", float(valor))
        MEL.update_material_instance(mi)
    log("Contorno =", valor)
def sol(intensidad):
    for a in GS.get_all_actors_of_class(mundo(), ue.DirectionalLight):
        a.get_component_by_class(ue.DirectionalLightComponent).set_intensity(intensidad)

PASOS = [
    (0.0, lambda: LES.editor_request_begin_play()),
    (0.5, esperar_pie),
    # sin bloom ni viñeta: con ellos un color plano sale como degradado (viñeta en los bordes, halo del bloom) y la
    # paleta de la llama pasaba de 8 colores; un juego toon los apagaría igualmente
    (1.0, lambda: (consola("r.ScreenPercentage 100"), consola("showflag.bloom 0"), consola("showflag.vignette 0"))),
    # --- DIEZ MUROS primero, con stat fps (antes de que haya capturas en cola que frenen el editor)
    (0.3, lambda: [(teletransportar(-800, -900 + i * 200), lanzar("LanzarMuroToon")) for i in range(10)]),
    (0.2, lambda: (listar("BP_MuroFuegoToon"), info_sistema())),
    (0.0, lambda: (camara_en(v(-1800, 0, Z["z"] + 300), v(-600, 0, Z["z"] - 30)), consola("stat fps"), consola("stat unit"))),
    (0.8, lambda: (ctx.__setitem__("fps", []), ctx.__setitem__("medir", True))),
    (1.5, lambda: (ctx.__setitem__("medir", False), ctx.__setitem__("fpsmed", len(ctx["fps"]) / max(1e-6, sum(ctx["fps"]))), log("fps medio con diez muros (tick de Slate): %.1f (n=%d, dt max %.3f)" % (ctx["fpsmed"], len(ctx["fps"]), max(ctx["fps"]))))),
    (0.0, lambda: ue.SystemLibrary.print_string(mundo(), "FPS medidos (tick de Slate): %.1f" % ctx["fpsmed"], True, True, ue.LinearColor(1, 1, 0, 1), 6.0)),
    (0.2, lambda: consola("Shot showui")),
    (0.4, lambda: captura("diez_muros_1080p")), ESPERAR,
    (0.2, lambda: (consola("stat fps"), consola("stat unit"))),
    # --- MURO a 2 m; vista lateral (inclinación de los sprites); cuatro capturas a 1/24 s de juego (comprobación de
    #     los 12 fps: con el tiempo cuantizado, al menos un par consecutivo tiene que ser idéntico)
    (3.5, lambda: (teletransportar(-600, 0), lanzar("LanzarMuroToon"))),
    (0.2, lambda: listar("BP_MuroFuegoToon")),
    (0.0, lambda: camara_en(CERCA[0](), CERCA[1]())),
    (0.9, lambda: captura("muro_cerca")),
    (0.1, lambda: camara_en(E(-400, 0) + v(150, -520, 140), E(-400, 0) + v(0, -100, 60))),
    (0.1, lambda: captura("muro_lado")),
    (0.1, lambda: camara_en(CERCA[0](), CERCA[1]())),
    # a 0,1x: procesar una captura cuesta ~0,3 s reales = 0,03 s de juego, menos que 1/24; así los retardos de juego mandan.
    # Sin antialiasing temporal durante las cuatro capturas: el TSR mueve los bordes duros un subpíxel cada fotograma y
    # dos fotogramas del mismo paso de 1/12 s no saldrían idénticos.
    (0.0, lambda: (consola("slomo 0.1"), consola("r.AntiAliasingMethod 0"))),
    (0.1, lambda: captura("muro_q0")),
    (1.0 / 24, lambda: captura("muro_q1")),
    (1.0 / 24, lambda: captura("muro_q2")),
    (1.0 / 24, lambda: captura("muro_q3")),
    (1.0 / 24, lambda: captura("muro_q4")),
    (1.0 / 24, lambda: captura("muro_q5")),
    (0.0, lambda: (consola("r.AntiAliasingMethod 4"), consola("slomo 1"))),
    # --- muro nuevo para la secuencia del GIF (3,3 s a 12 fps, desde 0,5 s de vida), a cámara lenta
    (0.2, lambda: (teletransportar(-600, 0), lanzar("LanzarMuroToon"))),
    (0.5, lambda: consola("slomo 0.1")),
] + pasos_secuencia() + [
    (0.0, lambda: consola("slomo 1")),
    # --- tercer muro: 10 m, vista del jugador y sol apagado (la llama es unlit: no debe cambiar)
    (1.5, lambda: (teletransportar(-600, 0), lanzar("LanzarMuroToon"))),
    (0.0, lambda: camara_en(LEJOS[0](), LEJOS[1]())),
    (0.9, lambda: captura("muro_lejos")),
    (0.2, vista_jugador),
    (0.3, lambda: captura("juego_muro")),
    (0.2, lambda: camara_en(CERCA[0](), CERCA[1]())),
    (0.2, lambda: captura("muro_cerca_con_sol")),
    (0.0, lambda: sol(0.0)),
    (0.1, lambda: captura("muro_cerca_sin_sol")),
    (0.0, lambda: sol(4.0)),
    # --- mando Contorno a 1 en las dos instancias (se deja a 0 al terminar)
    (0.3, lambda: contorno(1.0)),
    (0.3, lambda: captura("muro_contorno")),
    (0.3, lambda: contorno(0.0)),
    (0.5, lambda: LES.editor_request_end_play()),
    (1.0, lambda: log("FIN")),
]

def tick(dt):
    if ctx.get("dentro"): return
    ctx["dentro"] = True
    try: _tick(dt)
    finally: ctx["dentro"] = False
def _tick(dt):
    if ctx["paso"] >= len(PASOS):
        ue.unregister_slate_post_tick_callback(ctx["h"]); _log.close(); return
    if LES.is_in_play_in_editor() and ctx.get("medir"): ctx["fps"].append(dt)
    # retardos en tiempo de juego dentro de PIE (una captura pendiente congela el mundo un fotograma; así los
    # retardos entre capturas son de verdad 1/24 s o 1/12 s de juego); fuera de PIE, tiempo de Slate
    if "z" in Z and LES.is_in_play_in_editor():
        try:
            tj = tiempo(); ctx["t"] += max(0.0, tj - ctx.get("tj", tj)); ctx["tj"] = tj
        except Exception: ctx["t"] += dt
    else:
        ctx["t"] += dt
    retardo, fn = PASOS[ctx["paso"]]
    if ctx["t"] < retardo: return
    try:
        r = fn()
        if r is False: return
    except Exception:
        log("ERROR paso", ctx["paso"], traceback.format_exc().strip().splitlines()[-1][:300])
    ctx["paso"] += 1; ctx["t"] = 0.0
ctx["h"] = ue.register_slate_post_tick_callback(tick)
log("capturas2: %d pasos registrados" % len(PASOS))
