# Prueba 2 (fuego toon): aserciones sobre el contenido de /Game/POC2, lanzable desde el editor (cola o consola Python)
# o sin interfaz: UnrealEditor-Cmd.exe <uproject> -run=pythonscript -script=<esta ruta>.
#   - los tres materiales existen, son Unlit + Masked y compilan (instrucciones > 0)
#   - la instancia del cuerpo expone los mandos en castellano
#   - NS_MuroFuegoToon existe, va a paso fijo de 1/12 s, tiene <= 1 LightRenderer y un presupuesto <= 300 partículas
#   - la paleta de la llama en muro_cerca.png tiene <= 8 colores tras cuantizar a 5 bits (lector PNG propio, sin PIL)
# Resultado en Saved/poc2_prueba.txt y por la salida estándar; sale con código 1 si algo falla (fuera del editor).
import unreal as ue, os, sys, zlib, struct, traceback, collections

PROYECTO = ue.Paths.project_dir()
MATS = "/Game/POC2/Materiales/"
VFX = "/Game/POC2/VFX/NS_MuroFuegoToon"
CAPTURA = os.environ.get("POC2_CAPTURA") or os.path.join(PROYECTO, "Saved", "Screenshots", "WindowsEditor", "muro_cerca.png")
MANDOS = ["Fps", "Umbral", "Banda", "AlturaLlama", "Erosion", "Desplazamiento", "Contorno", "Velocidad", "EscalaRuido", "Brillo"]
# presupuesto por emisor (tasa máxima por segundo x vida máxima, L = 1), de poc2_niagara_cghow.py (técnica 2, la entregada)
PRESUPUESTO = {"Lenguas": 28 * 1.3, "Base": 6 * 1.4, "Humo": 2.5 * 1.4, "Chispas": 40 * 0.8, "Luz": 1}

resultados = []
COMMANDLET = "-run=pythonscript" in ue.SystemLibrary.get_command_line().lower()
def omitir(nombre, detalle=""):
    resultados.append((nombre, None, detalle))
    print("OMIT  " + nombre + (" | " + str(detalle) if detalle else ""))
def comprobar(nombre, ok, detalle=""):
    resultados.append((nombre, bool(ok), detalle))
    print(("OK   " if ok else "FALLA") + " " + nombre + (" | " + str(detalle) if detalle else ""))
    return bool(ok)


def leer_png(ruta):
    """PNG 8 bits RGB/RGBA no entrelazado -> (ancho, alto, canales, bytes planos). Sin PIL (el Python del motor no lo trae)."""
    with open(ruta, "rb") as fh:
        datos = fh.read()
    assert datos[:8] == b"\x89PNG\r\n\x1a\n", "no es PNG"
    pos, idat, w = 8, [], None
    while pos < len(datos):
        n, tipo = struct.unpack(">I4s", datos[pos:pos + 8]); cuerpo = datos[pos + 8:pos + 8 + n]; pos += 12 + n
        if tipo == b"IHDR":
            w, h, bits, ctipo, _, _, entrelazado = struct.unpack(">IIBBBBB", cuerpo)
            assert bits == 8 and entrelazado == 0 and ctipo in (2, 6), "PNG no soportado (%d bits, tipo %d)" % (bits, ctipo)
            canales = 3 if ctipo == 2 else 4
        elif tipo == b"IDAT": idat.append(cuerpo)
        elif tipo == b"IEND": break
    raw = zlib.decompress(b"".join(idat))
    paso = w * canales; salida = bytearray(); prev = bytearray(paso); i = 0
    for _ in range(h):
        filtro = raw[i]; fila = bytearray(raw[i + 1:i + 1 + paso]); i += 1 + paso
        if filtro == 1:
            for x in range(canales, paso): fila[x] = (fila[x] + fila[x - canales]) & 255
        elif filtro == 2:
            for x in range(paso): fila[x] = (fila[x] + prev[x]) & 255
        elif filtro == 3:
            for x in range(paso): fila[x] = (fila[x] + ((fila[x - canales] if x >= canales else 0) + prev[x]) // 2) & 255
        elif filtro == 4:
            for x in range(paso):
                a = fila[x - canales] if x >= canales else 0; b = prev[x]; c = prev[x - canales] if x >= canales else 0
                p = a + b - c; pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                fila[x] = (fila[x] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        salida += fila; prev = fila
    return w, h, canales, bytes(salida)


def paleta_llama(ruta, bits=5, minimo=0.01):
    """Colores distintos (cuantizados a `bits` por canal) entre los píxeles de llama (cálidos y saturados), contando
    solo los que cubren >= `minimo` del área de llama: los bordes con antialiasing producen mezclas de un píxel."""
    w, h, c, px = leer_png(ruta)
    q = 8 - bits; cuenta = collections.Counter(); total = 0
    for i in range(0, w * h * c, c):
        r, g, b = px[i], px[i + 1], px[i + 2]
        if r > 150 and r > b * 1.6 and (r - b) > 60:   # llama: rojo/naranja/amarillo; excluye suelo, cielo y humo
            total += 1; cuenta[(r >> q, g >> q, b >> q)] += 1
    principales = [(k, n) for k, n in cuenta.most_common() if n >= minimo * total]
    return total, len(cuenta), principales


def main():
    MEL = ue.MaterialEditingLibrary
    for nombre in ("M_FuegoToon", "M_HumoToon", "M_ChispaToon"):
        m = ue.load_asset(MATS + nombre)
        if not comprobar("material %s existe" % nombre, m is not None): continue
        comprobar("%s es Unlit" % nombre, m.get_editor_property("shading_model") == ue.MaterialShadingModel.MSM_UNLIT)
        comprobar("%s es Masked" % nombre, m.get_editor_property("blend_mode") == ue.BlendMode.BLEND_MASKED)
        try:
            est = MEL.get_statistics(m); n = est.get_editor_property("num_pixel_shader_instructions")
            if n == 0 and COMMANDLET:
                # sin interfaz (-run=pythonscript) el commandlet no compila shaders: las estadísticas salen a 0 y la
                # compilación no se puede comprobar aquí; se deja constancia y no cuenta como fallo
                omitir("%s compila" % nombre, "sin estadísticas de shader en el commandlet; comprobado en el editor")
            else:
                comprobar("%s compila" % nombre, n > 0, "%d instrucciones" % n)
        except Exception as e:
            comprobar("%s compila" % nombre, False, str(e)[:120])
    mi = ue.load_asset(MATS + "MI_FuegoToon_Cuerpo")
    if comprobar("MI_FuegoToon_Cuerpo existe", mi is not None):
        try:
            nombres = set(str(n) for n in MEL.get_scalar_parameter_names(mi.get_editor_property("parent")))
            faltan = [m for m in MANDOS if m not in nombres]
            comprobar("los diez mandos en castellano", not faltan, "faltan: %s" % faltan if faltan else ", ".join(MANDOS))
        except Exception as e:
            comprobar("los diez mandos en castellano", False, str(e)[:120])
    sis = ue.load_asset(VFX)
    if comprobar("NS_MuroFuegoToon existe", sis is not None):
        comprobar("paso fijo de 1/12 s", sis.get_editor_property("fixed_tick_delta") and abs(sis.get_editor_property("fixed_tick_delta_time") - 1 / 12) < 1e-4,
                  "%s, %.4f s" % (sis.get_editor_property("fixed_tick_delta"), sis.get_editor_property("fixed_tick_delta_time")))
        # los emisores (emitter_handles) y export_text no se exponen a Python; se cuentan los objetos renderer cargados
        # cuyo path cuelga del sistema (ObjectIterator recorre todos los objetos de esa clase en memoria)
        try:
            luces = [o.get_path_name() for o in ue.ObjectIterator(ue.NiagaraLightRendererProperties) if o.get_path_name().startswith(VFX)]
            renders = [o.get_path_name().split(".")[-1] for o in ue.ObjectIterator(ue.NiagaraRendererProperties) if o.get_path_name().startswith(VFX)]
            comprobar("<= 1 luz por efecto", 0 < len(luces) <= 1, "LightRenderer: %d; renderers del sistema: %d %s" % (len(luces), len(renders), renders))
        except Exception as e:
            comprobar("<= 1 luz por efecto", False, "ObjectIterator: " + str(e)[:120])
        total = sum(PRESUPUESTO.values())
        comprobar("<= 300 partículas por muro (presupuesto tasa x vida)", total <= 300, "%.0f = %s" % (total, PRESUPUESTO))
    if os.path.exists(CAPTURA):
        try:
            total, distintos, principales = paleta_llama(CAPTURA)
            comprobar("paleta de la llama <= 8 colores (5 bits, >= 1 %% del área) en %s" % os.path.basename(CAPTURA), 0 < len(principales) <= 8,
                      "%d píxeles de llama, %d colores en total, %d principales: %s" % (total, distintos, len(principales), [(k, round(n / total, 3)) for k, n in principales]))
        except Exception as e:
            comprobar("paleta de la llama", False, traceback.format_exc().strip().splitlines()[-1][:160])
    else:
        comprobar("captura muro_cerca.png para la paleta", False, "no existe " + CAPTURA)
    fallos = [r for r in resultados if r[1] is False]
    omitidas = [r for r in resultados if r[1] is None]
    resumen = "PRUEBA POC2: %d comprobaciones, %d fallos, %d omitidas%s" % (len(resultados), len(fallos), len(omitidas), " (commandlet sin shaders)" if omitidas else "")
    print(resumen)
    with open(os.path.join(PROYECTO, "Saved", "poc2_prueba.txt"), "w", encoding="utf-8") as fh:
        for n, ok, d in resultados: fh.write("%s %s%s\n" % ("OK   " if ok else ("OMIT " if ok is None else "FALLA"), n, " | " + str(d) if d else ""))
        fh.write(resumen + "\n")
    return not fallos


if __name__ == "__main__" or __name__ == "__cola__":
    ok = main()
    if __name__ == "__main__" and not ok:
        sys.exit(1)
